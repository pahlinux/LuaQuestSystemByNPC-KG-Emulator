-- QuestSystem.lua (limpio y ordenado)
-- Soporte multi-quest por cuenta (tabla dbo.QUEST_SYSTEM_ACTIVE)

-- fallbacks / helpers globales
if GetMonsterName == nil then
    function GetMonsterName(id) return tostring(id) end
end

if QKey == nil then
    function QKey(npc_id, qid)
        return string.format("%d_%d", tonumber(npc_id) or 0, tonumber(qid) or 0)
    end
end

-- Namespace / estado
QuestSystem = QuestSystem or {}
QuestSystem.PlayerActive = QuestSystem.PlayerActive or {} -- cache
QuestSystem.CompletedHistory = QuestSystem.CompletedHistory or {}
QuestSystem.CompletedToday = QuestSystem.CompletedToday or {}
QuestSystem.LoadingAccounts = QuestSystem.LoadingAccounts or {}
QuestSystem.IsDataLoaded = QuestSystem.IsDataLoaded or {}

-- pending buffers: flags y contadores acumulados mientras no exista la fila DB
QuestSystem.PendingInserts = QuestSystem.PendingInserts or {}
QuestSystem.PendingCounters = QuestSystem.PendingCounters or {}

local function Split(s, delimiter)
    local result = {}
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match)
    end
    return result
end

function QuestSystem.SendLoadingPacket(player, npc_id)
    if not player then return end
    local name = player:getName()
    local packetName = string.format("%s_%s", QUEST_SYSTEM_PACKET_OPEN_NAME, name)
    local function SD(v) return tonumber(v) or 0 end

    CreatePacket(packetName, QUEST_SYSTEM_PACKET)
    SetDwordPacket(packetName, SD(npc_id))
    SetDwordPacket(packetName, SD(player:getMapNumber()))
    SetDwordPacket(packetName, 0xFFFFFFFF) -- Enviamos un ID especial (-1) como señal de carga
    
    -- Llenamos el resto con ceros (10 stats + 1 byte + 9 kills + 10 items + 1 lista count)
    for i = 1, 10 do SetDwordPacket(packetName, 0) end
    SetBytePacket(packetName, 0)
    for i = 1, 19 do SetDwordPacket(packetName, 0) end
    SetDwordPacket(packetName, 0) -- 0 misiones en la lista

    SendPacket(packetName, player:getIndex())
    ClearPacket(packetName)
    LogAddC(2, string.format("[QS] Signal LOADING enviado a %s", name))
end

function QuestSystem.SafeCreateAsync(name, sql, aIndex, flag)
    -- Usamos nombres de consulta fijos y cortos.
    -- flag 1 para lecturas, flag 0 para grabaciones (fire and forget).
    local ok = pcall(CreateAsyncQuery, name, sql, aIndex or -1, flag or 0)
    
    -- Dejamos este log solo para que veas qué se mandó si algo falla
    --if sql:find("INSERT") or sql:find("UPDATE") then
    --    LogAddC(2, ">> SQL_SAVE: " .. name)
    --end
    return ok
end

-- Helper: dump
function QuestSystem.DumpPlayerActiveForAcc(acc)
    if not acc or not QuestSystem.PlayerActive then
        LogAddC(2, "QuestSystem.Dump: PlayerActive nil or acc nil")
        return
    end
    
    local t = QuestSystem.PlayerActive[acc]
    if not t then
        LogAddC(2, string.format("QuestSystem.Dump: No hay datos activos para la cuenta: [%s]", tostring(acc)))
        return
    end
    
    LogAddC(2, string.format("======= DEBUG QUEST SYSTEM: %s =======", tostring(acc)))
    local count = 0
    for npc_k, quests in pairs(t) do
        for qid, data in pairs(quests) do
            count = count + 1
            LogAddC(2, string.format("Entry %d: NPC: %s | QID: %s | Map: %s | Kills: %d | Ready: %s", 
                count, 
                tostring(npc_k), 
                tostring(qid), 
                tostring(data.MapNumber or "N/A"), -- Mostramos el mapa
                tonumber(data.Kills or 0),
                (data.CanCollect == 1 and "SI" or "NO") -- Mostramos si ya puede cobrar
            ))
        end
    end
    LogAddC(2, "==============================================")
end

-- Helper: GetQuestIdentification
function QuestSystem.GetQuestIdentification(npc_id, id)
    -- Validación básica de entrada
    if not id or id == 0 then return nil end

    -- 1. BUSCAR POR NPC (Estructura preferida)
    if npc_id and npc_id ~= 0 then
        if QUEST_SYSTEM_INFO_BY_NPC and QUEST_SYSTEM_INFO_BY_NPC[npc_id] then
            for _, q in ipairs(QUEST_SYSTEM_INFO_BY_NPC[npc_id]) do
                if q.QuestIdentification == id then return q end
            end
        end
    end

    -- 2. BUSCAR POR MAPA (Estructura secundaria)
    -- Agregamos esto por si el NPC no tiene la tabla pero el mapa sí
    if QUEST_SYSTEM_BY_MAP then
        for mapId, quests in pairs(QUEST_SYSTEM_BY_MAP) do
            for _, q in ipairs(quests) do
                if q.QuestIdentification == id then return q end
            end
        end
    end

    -- 3. BUSCAR EN TABLA GLOBAL (Con protección contra nil)
    -- Aquí es donde daba el error. Agregamos "or {}" para que si es nil, no crashee.
    local globalInfo = QUEST_SYSTEM_INFO or {}
    for _, q in pairs(globalInfo) do
        if q.QuestIdentification == id then return q end
    end

    return nil
end

function QuestSystem.OnPlayerMove(aIndex)
    local player = User.new(aIndex)
    if not player then return end
    local acc = player:getAccountID()

    -- [SEGURIDAD] No borramos QuestSystem.PlayerActive ni CompletedToday
    -- Solo reseteamos el estado de "Ventana Abierta" para que el sistema 
    -- se vea obligado a consultar el nuevo mapa al hablar con un NPC.
    player:setCacheInt("QuestSystemNPC", 0)
    
    -- Si el jugador tiene una misión activa (Status 1), la restauramos al cambiar de mapa
    -- para que el HUD siga funcionando correctamente en la nueva zona.
    QuestSystem.RestorePlayerCacheFromMemory(player)
end

-- Helper: restore cache from in-memory PlayerActive
function QuestSystem.RestorePlayerCacheFromMemory(player)
    if not player then return end
    local acc = player:getAccountID()
    if not acc or not QuestSystem.PlayerActive[acc] then return end
    
    for npc_id, quests in pairs(QuestSystem.PlayerActive[acc]) do
        for qk, qv in pairs(quests) do
            if tonumber(qv.Status) == 1 then
                player:setCacheInt("QuestSystemNPC", tonumber(npc_id))
                player:setCacheInt("QuestSystemIdentification", tonumber(qk))
                player:setCacheInt("QuestSystemKills", tonumber(qv.Kills) or 0)
                player:setCacheInt("QuestSystemStatus", 1)
                player:setCacheInt("QuestSystemCanCollect", tonumber(qv.CanCollect) or 0)
                player:setCacheInt("QuestSystemFinished", 0)
                
                -- Sincronizar monstruos individuales
                if qv.KillsMonster then
                    for i = 1, 9 do
                        player:setCacheInt("QuestSystemKillsMonster"..i, tonumber(qv.KillsMonster[i]) or 0)
                    end
                end

                -- Flag Started: si ya puede cobrar es 0, si está matando es 1
                player:setCacheInt("QuestSystemStarted", (tonumber(qv.CanCollect) == 1) and 0 or 1)
                
                LogAddC(2, string.format("[QS-CACHE] RAM -> C++: %s (QID:%d Kills:%d)", acc, tonumber(qk), tonumber(qv.Kills)))
                return 
            end
        end
    end
end

-- DB helper: InsertPlayer (marca pending y ejecuta insert preferente por DataBaseAsync.Query/CreateQuery o async)
function QuestSystem.InsertPlayer(account, name, npc_id, questIdentification, playerIndex, mapId)
    if not account or not questIdentification then return end
    
    -- Lógica de "Si existe actualiza, si no inserta"
    local query = string.format(
        "IF EXISTS (SELECT 1 FROM QUEST_SYSTEM_ACTIVE WHERE AccountID='%s' AND QuestIdentification=%d AND MapNumber=%d) " ..
        "UPDATE QUEST_SYSTEM_ACTIVE SET Status=1, Finished=0, CanCollect=0, Kills=0, " ..
        "KillsMonster1=0,KillsMonster2=0,KillsMonster3=0,KillsMonster4=0,KillsMonster5=0,KillsMonster6=0,KillsMonster7=0,KillsMonster8=0,KillsMonster9=0 " ..
        "WHERE AccountID='%s' AND QuestIdentification=%d AND MapNumber=%d " ..
        "ELSE " ..
        "INSERT INTO QUEST_SYSTEM_ACTIVE (AccountID, Name, NPC, QuestIdentification, Finished, Kills, KillsMonster1, KillsMonster2, KillsMonster3, KillsMonster4, KillsMonster5, KillsMonster6, KillsMonster7, KillsMonster8, KillsMonster9, CanCollect, Status, MapNumber) " ..
        "VALUES ('%s','%s',%d,%d,0,0,0,0,0,0,0,0,0,0,0,0,1,%d)",
        account, questIdentification, mapId,
        account, questIdentification, mapId,
        account, name or '', npc_id, questIdentification, mapId
    )

    QuestSystem.SafeCreateAsync('QS_Upsert', query, playerIndex, 0)
    
    -- RAM Sync inmediata para que el HUD responda YA
    QuestSystem.PlayerActive[account] = QuestSystem.PlayerActive[account] or {}
    QuestSystem.PlayerActive[account][npc_id] = QuestSystem.PlayerActive[account][npc_id] or {}
    QuestSystem.PlayerActive[account][npc_id][tostring(questIdentification)] = { 
        Finished = 0, Kills = 0, KillsMonster = {0,0,0,0,0,0,0,0,0}, 
        CanCollect = 0, MapNumber = mapId, Status = 1 
    }
end

-- Flush pending counters for an account/npc/qid (aplica INSERT si necesario y acumula increments)
function QuestSystem.FlushPending(account, npc_id, questIdentification, map_id, aIndex)
    if not account or not npc_id or not questIdentification then return end
    local acc, qk = tostring(account), tostring(questIdentification)
    local ram = QuestSystem.PlayerActive[acc] and QuestSystem.PlayerActive[acc][npc_id] and QuestSystem.PlayerActive[acc][npc_id][qk]

    if ram then
        local query = string.format(
            "UPDATE QUEST_SYSTEM_ACTIVE SET Kills=%d, KillsMonster1=%d, KillsMonster2=%d, KillsMonster3=%d, KillsMonster4=%d, KillsMonster5=%d, KillsMonster6=%d, KillsMonster7=%d, KillsMonster8=%d, KillsMonster9=%d, Status=1 " ..
            "WHERE AccountID='%s' AND NPC=%d AND QuestIdentification=%d",
            ram.Kills, ram.KillsMonster[1], ram.KillsMonster[2], ram.KillsMonster[3], ram.KillsMonster[4], 
            ram.KillsMonster[5], ram.KillsMonster[6], ram.KillsMonster[7], ram.KillsMonster[8], ram.KillsMonster[9],
            acc, npc_id, tonumber(qk)
        )

        QuestSystem.SafeCreateAsync('QS_Update', query, aIndex, 0)
    end
end

-- QueryAsyncProcess: manejo de callbacks (GetActiveQuests, Insert completions, QuestInc/QuestCan)
function QuestSystem.QueryAsyncProcess(queryName, identification, aIndex)
    if not queryName then return 0 end
    
    -- Log de auditoría para verificar respuesta del motor asíncrono
    LogAddC(2, string.format("QuestSystem.QueryAsyncProcess: CALLBACK RECEIVED name=%s id=%s", tostring(queryName), tostring(identification)))

    -- Extraemos el nombre de la cuenta del nombre de la query por seguridad
    local acc_from_name = string.sub(queryName, 7) 
    local player = (aIndex and aIndex >= 0) and User.new(aIndex) or nil

    ---------------------------------------------------------
    -- 1. CARGA INICIAL Y RE-HIDRATACIÓN (Prefix "Ge")
    ---------------------------------------------------------
    if string.sub(queryName, 1, 2) == "Ge" then
        -- Leemos AccountID primero para avanzar el puntero (Orden Sagrado)
        local rowAcc = QueryAsyncGetValue(identification, 'AccountID')
        local db_acc = tostring(rowAcc or "")
        
        -- Fallback de cuenta si la DB devuelve nulo
        if db_acc == "" or db_acc == "nil" then
            db_acc = acc_from_name
        end

        if db_acc ~= "" then
            QuestSystem.IsDataLoaded[db_acc] = true
            if QuestSystem.LoadingAccounts then QuestSystem.LoadingAccounts[db_acc] = nil end

            -- [A] PROCESAMIENTO DE MISIÓN ACTIVA (GeACT)
            if string.sub(queryName, 1, 5) == "GeACT" then
                local npc = tonumber(QueryAsyncGetValue(identification, 'NPC')) or 0
                local qid = tonumber(QueryAsyncGetValue(identification, 'QuestIdentification')) or 0
                
                if qid > 0 then
                    local st  = tonumber(QueryAsyncGetValue(identification, 'Status')) or 0
                    local mid = tonumber(QueryAsyncGetValue(identification, 'MapNumber')) or 0
                    local can = tonumber(QueryAsyncGetValue(identification, 'CanCollect')) or 0
                    local k0  = tonumber(QueryAsyncGetValue(identification, 'Kills')) or 0
                    
                    LogAddC(2, string.format("[QS-LOAD] %s: Misión ACTIVA recuperada QID:%d", db_acc, qid))
                    
                    QuestSystem.PlayerActive[db_acc] = QuestSystem.PlayerActive[db_acc] or {}
                    QuestSystem.PlayerActive[db_acc][npc] = QuestSystem.PlayerActive[db_acc][npc] or {}
                    
                    local km = {}
                    for i = 1, 9 do 
                        km[i] = tonumber(QueryAsyncGetValue(identification, 'KillsMonster'..i)) or 0 
                    end

                    QuestSystem.PlayerActive[db_acc][npc][tostring(qid)] = {
                        Status = 1, MapNumber = mid, Finished = 0,
                        Kills = k0, CanCollect = can, KillsMonster = km
                    }
                    
                    -- Re-hidratación C++ (HUD)
                    if player then 
                        QuestSystem.RestorePlayerCacheFromMemory(player) 
                        Timer.TimeOut(3.0, function()
                            local p_check = User.new(aIndex)
                            if p_check and p_check:getConnected() >= 3 then
                                QuestSystem.SendHUDUpdate(p_check, npc)
                            end
                        end)
                    end
                end

            -- [B] PROCESAMIENTO DE HISTORIAL Y DIARIAS (GeFIN)
            elseif string.sub(queryName, 1, 5) == "GeFIN" then
                local packData = tostring(QueryAsyncGetValue(identification, 'Pack') or "")
                
                -- Inicialización de mochilas
                QuestSystem.CompletedHistory[db_acc] = QuestSystem.CompletedHistory[db_acc] or {}
                QuestSystem.CompletedToday[db_acc] = QuestSystem.CompletedToday[db_acc] or {}

                if packData ~= "" and packData ~= "nil" then
                    local today = os.date("%Y-%m-%d")
                    local items = Split(packData, "|")
                    for _, item in ipairs(items) do
                        local parts = Split(item, ":")
                        local qid_p = parts[1]
                        local npc_p = tonumber(parts[2])
                        local mid_p = tonumber(parts[3])
                        local diff  = tonumber(parts[4]) or 999 -- Días desde completar

                        if qid_p and npc_p and mid_p then
                            -- REPARACIÓN CRÍTICA: Guardamos como tabla para evitar el error de "boolean value"
                            QuestSystem.CompletedHistory[db_acc][qid_p] = { 
                                isToday = (diff == 0) 
                            }

                            -- Si se hizo hoy (diff 0), lo guardamos en CONTROL DIARIO (Para IsOneTime=0)
                            if diff == 0 then
                                QuestSystem.CompletedToday[db_acc][npc_p] = QuestSystem.CompletedToday[db_acc][npc_p] or {}
                                QuestSystem.CompletedToday[db_acc][npc_p][mid_p] = QuestSystem.CompletedToday[db_acc][npc_p][mid_p] or {}
                                QuestSystem.CompletedToday[db_acc][npc_p][mid_p][qid_p] = today
                                LogAddC(2, string.format("[QS-LOAD] %s: Terminada HOY QID:%s", db_acc, qid_p))
                            else
                                LogAddC(2, string.format("[QS-LOAD] %s: Historial antiguo QID:%s (Días: %d)", db_acc, qid_p, diff))
                            end
                        end
                    end
                end
            end
        end

        QueryAsyncDelete(identification)
        return 1
    end

    ---------------------------------------------------------
    -- 2. CALLBACKS DE ESCRITURA Y MANTENIMIENTO
    ---------------------------------------------------------
    local isSystemCallback = string.sub(queryName, 1, 3) == "QS_" or 
                             string.find(queryName, "AbandonQuest") or 
                             string.find(queryName, "FinalizeQuest") or
                             string.find(queryName, "InsertQuest") or
                             string.find(queryName, "CanQ") or
                             string.find(queryName, "SetStatus")

    if isSystemCallback then
        QueryAsyncDelete(identification)
        return 1
    end

    ---------------------------------------------------------
    -- 3. LIMPIADOR DE SEGURIDAD (Anti-Atasco)
    ---------------------------------------------------------
    local prefix = string.sub(queryName, 1, 2)
    local writeOps = { ["In"]=true, ["SV"]=true, ["Up"]=true, ["Fi"]=true, ["QS"]=true, ["Ch"]=true }
    
    if writeOps[prefix] or string.find(queryName, "Quest") then
        QueryAsyncDelete(identification)
        return 1
    end

    return 0
end

-- OpenQuest: send npc_id, player state, started flag, quest list and per-quest player state
function QuestSystem.BuildQuestPacket(player, npc_id, packetName, providedQuestsList)
    if not player then return end

    -- Función SD para manejar Números y Booleanos (true -> 1, false -> 0)
    local function SD(v) 
        if v == true then return 1 end
        if v == false then return 0 end
        return tonumber(v) or 0 
    end

    packetName = packetName or string.format("%s_%s", QUEST_SYSTEM_PACKET_OPEN_NAME, player:getName())
    local isHUDUpdate = (packetName:find("HUDUpdate")) and true or false
    local acc = player:getAccountID()
    local today = os.date("%Y-%m-%d")
    local current_map = player:getMapNumber()

    -- Aseguramos que las llaves sean números
    local npcKey = SD(npc_id)
    local mapKey = SD(current_map)

    -- Sincronizar NPC en Cache
    if npc_id ~= nil then 
        player:setCacheInt("QuestSystemNPC", npcKey) 
    else 
        npcKey = player:getCacheInt("QuestSystemNPC") or 0 
    end

    local qid_active = 0
    local finished_to_send = 0
    local can_collect_to_send = 0
    local kills_monster = {0,0,0,0,0,0,0,0,0}
    local items_to_send = {0,0,0,0,0,0,0,0,0,0} -- [AGREGADO] Para que el HUD reciba items
    local isRemoteQuest = false

    -- [A] BUSCAR MISIÓN ACTIVA (Filtrado por Mapa)
    if QuestSystem.PlayerActive[acc] then
        for n_id, npcs in pairs(QuestSystem.PlayerActive[acc]) do
            for q_id, q_v in pairs(npcs) do
                -- Solo procesamos si no está marcada como finalizada (Status 1)
                if SD(q_v.Finished) == 0 then
                    local check_qid = SD(q_id)
                    local quest_map_owner = SD(q_v.MapNumber)

                    -- [AGREGADO] Si es HUD, forzamos la llave del NPC para que el cliente la encuentre
                    if isHUDUpdate then npcKey = SD(n_id) end

                    -- Validamos si la misión activa es del mapa actual
                    if quest_map_owner == mapKey then
                        qid_active = check_qid
                        can_collect_to_send = SD(q_v.CanCollect)
                        isRemoteQuest = false
                        
                        -- Cargamos kills y items solo si es la misión local
                        if q_v.KillsMonster then
                            for i = 1, 9 do kills_monster[i] = SD(q_v.KillsMonster[i]) end
                        end
                        if q_v.ItemsCount then
                            for i = 1, 10 do items_to_send[i] = SD(q_v.ItemsCount[i]) end
                        end
                    else
                        -- Si tiene una misión en OTRO mapa, la marcamos como Remota
                        qid_active = check_qid
                        can_collect_to_send = 2 -- Flag de "Remoto"
                        isRemoteQuest = true
                    end
                    break
                end
            end
            if qid_active > 0 then break end
        end
    end

    -- [B] DETERMINAR SI MOSTRAR CARTEL "COMPLETED" (Finished)
    local questsList = providedQuestsList or {}

    if qid_active == 0 and #questsList == 0 and not isHUDUpdate then
        if QuestSystem.CompletedToday[acc] and QuestSystem.CompletedToday[acc][npcKey] then
            if QuestSystem.CompletedToday[acc][npcKey][mapKey] then
                for qid_done, date_done in pairs(QuestSystem.CompletedToday[acc][npcKey][mapKey]) do
                    if date_done == today then
                        -- Activamos flag de finalizado porque ya no hay nada más que hacer aquí hoy
                        finished_to_send = 1
                        qid_active = SD(qid_done)
                        break
                    end
                end
            end
        end
    end

    -- [C] ENVÍO DE PAQUETE (HEADER Y STATS)
    CreatePacket(packetName, QUEST_SYSTEM_PACKET)
    SetDwordPacket(packetName, npcKey)
    SetDwordPacket(packetName, mapKey)
    SetDwordPacket(packetName, SD(qid_active))

    -- Stats (9 Dwords iniciales + 1 de Control)
    SetDwordPacket(packetName, SD(player:getLevel()))
    SetDwordPacket(packetName, SD(player:getReset()))
    SetDwordPacket(packetName, SD(player:getMasterReset()))
    SetDwordPacket(packetName, SD(player:getMoney()))
    SetDwordPacket(packetName, SD(player:getCoin1()))
    SetDwordPacket(packetName, SD(player:getCoin2()))
    SetDwordPacket(packetName, SD(player:getCoin3()))

    -- [FIX RUUD] Validación de seguridad
    local ruud = 0
    if acc ~= nil and acc ~= "" then
        if DataBase and DataBase.GetValue then 
            ruud = DataBase.GetValue('CashShopData', 'Ruud', 'AccountID', acc) or 0 
        end
    end
    SetDwordPacket(packetName, SD(ruud))
    SetDwordPacket(packetName, SD(player:getVip()))
    
    -- Dword 10 de Stats (Control Flag): 0=Incomp, 1=Reward, 2=Remote
    SetDwordPacket(packetName, SD(can_collect_to_send))

    -- Flags y Arrays
    SetBytePacket(packetName, SD(finished_to_send))
    for i = 1, 9 do SetDwordPacket(packetName, SD(kills_monster[i])) end
    
    -- [AGREGADO] Enviamos items_to_send en lugar de 0s fijos
    for i = 1, 10 do SetDwordPacket(packetName, SD(items_to_send[i])) end

    -- [D] LISTA DE MISIONES
    if finished_to_send == 1 then
        SetDwordPacket(packetName, 0)
    else
        SetDwordPacket(packetName, #questsList)
        for i = 1, #questsList do
            local q = questsList[i]
            local qid_l = SD(q.QuestIdentification)
            local f, c = 0, 0
            local list_kills = {0,0,0,0,0,0,0,0,0} -- [AGREGADO]
            
            -- 1. Verificamos si esta misión de la lista está ACTIVA en RAM
            if QuestSystem.PlayerActive[acc] and QuestSystem.PlayerActive[acc][npcKey] and QuestSystem.PlayerActive[acc][npcKey][tostring(qid_l)] then
                local st = QuestSystem.PlayerActive[acc][npcKey][tostring(qid_l)]
                f, c = SD(st.Finished), SD(st.CanCollect)
                
                -- [AGREGADO] Rescatamos los kills si está activa
                if st.KillsMonster then
                    for j = 1, 9 do list_kills[j] = SD(st.KillsMonster[j]) end
                end
            end

            -- 2. Verificamos si ya se TERMINÓ hoy en este mapa
            if f == 0 and QuestSystem.CompletedToday[acc] and QuestSystem.CompletedToday[acc][npcKey] and QuestSystem.CompletedToday[acc][npcKey][mapKey] then
                if QuestSystem.CompletedToday[acc][npcKey][mapKey][tostring(qid_l)] == today then
                    local config = QuestSystem.GetQuestIdentification(qid_l)
                    if config and config.IsOneTime == 0 then
                        f = 1 
                    end
                end
            end

            SetDwordPacket(packetName, qid_l)
            SetDwordPacket(packetName, f)
            SetDwordPacket(packetName, c)
            
            -- [AGREGADO] Enviamos los kills guardados en list_kills en lugar de 0s
            for j = 1, 9 do SetDwordPacket(packetName, list_kills[j]) end 
        end
    end

    SendPacket(packetName, player:getIndex())
    ClearPacket(packetName)
end

-- 1. FUNCIÓN PARA EL NPC (Abre la ventana)
function QuestSystem.OpenQuest(player, npc_id)
    if not player then return end
    local acc = player:getAccountID()
    local map_id = player:getMapNumber()
    player:setCacheInt("QuestSystemNPC", npc_id)

    if QuestSystem.IsDataLoaded[acc] == false then return end

    local fullList = {}
    if QUEST_SYSTEM_BY_MAP and QUEST_SYSTEM_BY_MAP[map_id] then
        fullList = QUEST_SYSTEM_BY_MAP[map_id]
    elseif QUEST_SYSTEM_INFO_BY_NPC and QUEST_SYSTEM_INFO_BY_NPC[npc_id] then
        fullList = QUEST_SYSTEM_INFO_BY_NPC[npc_id]
    end

    local filteredList = {}
    local oneTimeFound = false
    local anyActive = false

    for _, config in ipairs(fullList) do
        local qid = tostring(config.QuestIdentification)
        local isOneTime = (config.IsOneTime == 1)
        
        -- 1. Estado en RAM (Activa)
        local isActive = (QuestSystem.PlayerActive[acc] and QuestSystem.PlayerActive[acc][npc_id] and QuestSystem.PlayerActive[acc][npc_id][qid]) ~= nil
        
        -- 2. Estado en Historial (Terminada alguna vez)
        local history = QuestSystem.CompletedHistory[acc] and QuestSystem.CompletedHistory[acc][qid]
        local isDoneEver = (history ~= nil)
        local isDoneToday = (type(history) == "table" and history.isToday == true)

        if isOneTime then
            -- [ LÓGICA ONE-TIME ]
            -- Si ya la está haciendo, tiene prioridad absoluta
            if isActive then
                table.insert(filteredList, config)
                oneTimeFound = true
                anyActive = true
            -- Si NO se hizo nunca y no hemos mostrado otra única en este NPC todavía
            elseif not isDoneEver and not oneTimeFound then
                table.insert(filteredList, config)
                oneTimeFound = true
            end
            -- Si isDoneEver es true y no está activa, el sistema la ignora (pasa a la siguiente)
        else
            -- [ LÓGICA DIARIA ]
            -- Se muestra si está activa o si NO se hizo hoy
            if isActive or not isDoneToday then
                table.insert(filteredList, config)
                if isActive then anyActive = true end
            end
        end
    end

    -- Si el mapa no tiene nada para el jugador, avisamos al cliente
    local finishedFlag = (#filteredList == 0 and not anyActive) and 1 or 0
    
    LogAddC(2, string.format("[QS-DEBUG] %s Map:%d | Misiones Enviadas: %d | Finished: %d", acc, map_id, #filteredList, finishedFlag))
    QuestSystem.BuildQuestPacket(player, npc_id, nil, filteredList, finishedFlag)
end

function QuestSystem.GetQuestIdentification(qid)
    if not qid or qid == 0 then return nil end
    local searchId = tonumber(qid)

    -- Buscamos en la nueva estructura por MAPAS
    if QUEST_SYSTEM_BY_MAP then
        for mapId, questList in pairs(QUEST_SYSTEM_BY_MAP) do
            for _, q in ipairs(questList) do
                if tonumber(q.QuestIdentification) == searchId then 
                    return q 
                end
            end
        end
    end

    -- Si no está en mapas, buscamos en la tabla global (compatibilidad)
    if QUEST_SYSTEM_INFO then
        for _, q in pairs(QUEST_SYSTEM_INFO) do
            if tonumber(q.QuestIdentification) == searchId then 
                return q 
            end
        end
    end

    return nil
end

-- 2. FUNCIÓN PARA EL HUD (Actualización silenciosa)
function QuestSystem.SendHUDUpdate(player, npc_id) 
	if not player then return end 
	local packetName = string.format("QuestSystemHUDUpdate_%s", player:getName()) QuestSystem.BuildQuestPacket(player, npc_id, packetName) 
end

function QuestSystem.SendOpenContinue(player, npc_id, qid, map_id)
    -- 1. Validaciones iniciales de objeto y estado
    if type(player) == "number" then player = User.new(player) end
    if not player then return end
    
    local acc = player:getAccountID()
    local name = player:getName()
    local packetName = string.format("%s_%s", QUEST_SYSTEM_PACKET_OPEN_NAME, name)
    
    -- Helper para asegurar que siempre enviamos números al paquete
    local function SD(v) return tonumber(v) or 0 end
    
    -- 2. Determinación del Mapa (Map-Aware)
    -- Prioridad 1: El map_id que viene de la DB (el parámetro de la función)
    -- Prioridad 2: El mapa actual del jugador si el anterior es 0 o nil
    local mid_to_send = SD(map_id)
    if mid_to_send == 0 then 
        mid_to_send = SD(player:getMapNumber()) 
    end

    -- 3. Inicio y construcción del Paquete
    CreatePacket(packetName, QUEST_SYSTEM_PACKET)
    
    -- [HEADER] Sincronización estricta: NPC -> MAPA -> QID
    SetDwordPacket(packetName, SD(npc_id))
    SetDwordPacket(packetName, mid_to_send) -- Mapa real donde se terminó la misión
    SetDwordPacket(packetName, SD(qid))
    
    -- [STATS] (9 Dwords en total)
    SetDwordPacket(packetName, SD(player:getLevel()))
    SetDwordPacket(packetName, SD(player:getReset()))
    SetDwordPacket(packetName, SD(player:getMasterReset()))
    SetDwordPacket(packetName, SD(player:getMoney()))
    SetDwordPacket(packetName, SD(player:getCoin1()))
    SetDwordPacket(packetName, SD(player:getCoin2()))
    SetDwordPacket(packetName, SD(player:getCoin3()))
    
    -- [CORRECCIÓN RUUD] Validación de AccountID para evitar errores de SQL en el log
    local ruud = 0
    if acc ~= nil and acc ~= "" then
        if DataBase and DataBase.GetValue then 
            local res = DataBase.GetValue('CashShopData', 'Ruud', 'AccountID', acc)
            ruud = tonumber(res) or 0
        end
    end
    SetDwordPacket(packetName, SD(ruud))
    SetDwordPacket(packetName, SD(player:getVip()))
    
    -- [CONTROL EXTRA] Kills globales (Dword previo al byte de estado)
    SetDwordPacket(packetName, 0)
    
    -- [FLAG FINALIZADO] El Byte de estado (1 = Mostrar ventana de recompensa/continuar)
    SetBytePacket(packetName, 1)
    
    -- [RELLENO REQUISITOS] 
    -- 9 Dwords para slots de monstruos (en 0 porque ya terminó)
    for i = 1, 9 do
        SetDwordPacket(packetName, 0)
    end
    
    -- 10 Dwords para slots de items (en 0 porque ya terminó)
    for i = 1, 10 do 
        SetDwordPacket(packetName, 0) 
    end
    
    -- [LISTA DINÁMICA] Obligatorio para que el NPC marque la misión en verde
    SetDwordPacket(packetName, 1)    -- Cantidad de misiones en la lista (1)
    SetDwordPacket(packetName, SD(qid)) -- ID de la misión
    SetDwordPacket(packetName, 1)    -- Estado: Finished (1)
    SetDwordPacket(packetName, 0)    -- Kills actuales (0)
    for i = 1, 9 do 
        SetDwordPacket(packetName, 0) -- Slots de monstruos de la lista
    end
    
    -- 4. Envío al cliente y liberación de memoria del buffer
    SendPacket(packetName, player:getIndex())
    ClearPacket(packetName)
    
    -- Log de auditoría para verificar la sincronización de mapas
    LogAddC(2, string.format("[QS-SEND] Continue enviado a %s: NPC:%d QID:%d MAP:%d", acc, SD(npc_id), SD(qid), mid_to_send))
end

function QuestSystem.ForceCloseClient(player, npc_id)
    if type(player) == "number" then player = User.new(player) end
    if not player then return end

    local name = player:getName()
    local acc = player:getAccountID()
    -- Usamos el paquete de HUD Update para forzar el cierre visual
    local packetName = string.format("QuestSystemHUDUpdate_%s", name)
    
    local function SD(v) return tonumber(v) or 0 end

    CreatePacket(packetName, QUEST_SYSTEM_PACKET)

    -- 1. HEADER CON VALORES NULOS
    -- Al enviar QuestIdentification = 0 y estadísticas en 0, el cliente no tiene qué dibujar
    SetDwordPacket(packetName, SD(npc_id))
    SetDwordPacket(packetName, 0) -- QuestIdentification
    SetDwordPacket(packetName, 0) -- Level
    SetDwordPacket(packetName, 0) -- Resets
    SetDwordPacket(packetName, 0) -- MasterResets
    SetDwordPacket(packetName, 0) -- Zen
    SetDwordPacket(packetName, 0) -- Coin1
    SetDwordPacket(packetName, 0) -- Coin2
    SetDwordPacket(packetName, 0) -- Coin3
    SetDwordPacket(packetName, 0) -- Coin4 (Ruud)
    SetDwordPacket(packetName, 0) -- Vip
    SetDwordPacket(packetName, 0) -- Kills Globales

    -- 2. FLAG DE FINALIZADO EN 0
    -- Evita que se active el botón de "Continue"
    SetBytePacket(packetName, 0)

    -- 3. RESET DE MONSTRUOS (9 SLOTS)
    for i = 1, 9 do 
        SetDwordPacket(packetName, 0) 
    end

    -- 4. RESET DE ITEMS (10 SLOTS)
    for i = 1, 10 do 
        SetDwordPacket(packetName, 0) 
    end

    -- 5. LISTA DE QUESTS VACÍA
    -- Al enviar 0 misiones, el cliente limpia cualquier lista previa en pantalla
    SetDwordPacket(packetName, 0)

    -- ENVÍO Y LOG
    LogAddC(2, string.format("QuestSystem.ForceCloseClient: [HUD RESET] npc=%d acc=%s", SD(npc_id), acc))
    SendPacket(packetName, player:getIndex())
    ClearPacket(packetName)
end

function QuestSystem.SendHUDContinue(player, npc_id, qid)
    if type(player) == "number" then player = User.new(player) end
    if not player then return end

    local acc = player:getAccountID()
    local name = player:getName()
    local mapId = player:getMapNumber() -- Obtenemos mapa actual
    local packetName = string.format("QuestSystemHUDUpdate_%s", name)
    
    local function SD(v) return tonumber(v) or 0 end

    CreatePacket(packetName, QUEST_SYSTEM_PACKET)

    -- [HEADER] Sincronizado con tu DLL: NPC -> MAP -> QID
    SetDwordPacket(packetName, SD(npc_id))
    SetDwordPacket(packetName, SD(mapId)) -- <--- Agregado para que coincida con tu BuildPacket
    SetDwordPacket(packetName, SD(qid))

    -- [STATS] (10 Dwords)
    SetDwordPacket(packetName, SD(player:getLevel()))
    SetDwordPacket(packetName, SD(player:getReset()))
    SetDwordPacket(packetName, SD(player:getMasterReset()))
    SetDwordPacket(packetName, SD(player:getMoney()))
    SetDwordPacket(packetName, SD(player:getCoin1()))
    SetDwordPacket(packetName, SD(player:getCoin2()))
    SetDwordPacket(packetName, SD(player:getCoin3()))

    local coin4 = 0
    if DataBase and DataBase.GetValue then 
        coin4 = DataBase.GetValue('CashShopData', 'Ruud', 'AccountID', acc) or 0 
    end
    SetDwordPacket(packetName, SD(coin4))
    SetDwordPacket(packetName, SD(player:getVip()))
    SetDwordPacket(packetName, 0) -- Kills Globales en 0

    -- [FLAG BYTE]
    SetBytePacket(packetName, 1) -- Finished = 1 (Para que el cliente sepa que terminó)

    -- [KILLS MONSTRUOS] (9 slots)
    for i = 1, 9 do SetDwordPacket(packetName, 0) end

    -- [ITEMS] (10 slots)
    for i = 1, 10 do SetDwordPacket(packetName, 0) end

    -- [LISTA DINÁMICA] (Para que el NPC se refresque al cobrar)
    SetDwordPacket(packetName, 1) 
    SetDwordPacket(packetName, SD(qid))
    SetDwordPacket(packetName, 1) -- State: Finished
    SetDwordPacket(packetName, 0) -- Kills: 0
    for i = 1, 9 do SetDwordPacket(packetName, 0) end

    LogAddC(2, string.format("QuestSystem.SendHUDContinue: Sincronizado con MapID %d", mapId))
    SendPacket(packetName, player:getIndex())
    ClearPacket(packetName)
end

-- StartQuest
function QuestSystem.StartQuest(player, questID)
    if not player then return end
    
    local Language = player:getLanguage()
    local mapId = player:getMapNumber()
    local acc = player:getAccountID()
    local index = player:getIndex()
    local name = player:getName() 
    local npc_id = player:getCacheInt("QuestSystemNPC") or 0
    local qid = tonumber(questID) or 0
    
    -- 1. VALIDACIONES DE ESTADO
    if qid <= 0 then return end

    if player:getState() == 32 or player:getDieRegen() ~= 0 or player:getTeleport() ~= 0 then
        SendMessage(string.format(QUEST_SYSTEM_MESSAGES[Language][1]), index, 1)
        return
    end

    -- [BLOQUEO GLOBAL] Evitar múltiples misiones activas
    if QuestSystem.PlayerActive[acc] then
        for n_k, npcs in pairs(QuestSystem.PlayerActive[acc]) do
            for q_k, q_v in pairs(npcs) do
                if tonumber(q_v.Finished or 0) == 0 then
                    SendMessage("Ya tienes una misión activa en otro mapa. Termínala primero.", index, 1)
                    return
                end
            end
        end
    end

    local getQuest = QuestSystem.GetQuestIdentification(qid)
    if getQuest == nil then 
        LogAddC(2, string.format("QuestSystem Error: No se encontro ID %d en Config", qid))
        SendMessage(string.format("Error: Quest %d no configurada.", qid), index, 1)
        return 
    end

    ---------------------------------------------------------
    -- [NUEVO] VALIDACIÓN DE REQUISITOS TÉCNICOS
    ---------------------------------------------------------
    -- Validación de Nivel
    if player:getLevel() < (getQuest.Level or 0) then
        SendMessage(string.format("Necesitas nivel %d para iniciar esta misión.", getQuest.Level), index, 1)
        return
    end

    -- Validación de Resets
    if player:getReset() < (getQuest.Reset or 0) then
        SendMessage(string.format("Necesitas %d resets para iniciar esta misión.", getQuest.Reset), index, 1)
        return
    end

    -- Validación de Master Resets
    if (getQuest.MReset or 0) > 0 and player:getMasterReset() < getQuest.MReset then
        SendMessage(string.format("Necesitas %d Master Resets para iniciar.", getQuest.MReset), index, 1)
        return
    end

    -- Validación de Zen
    if player:getMoney() < (getQuest.Zen or 0) then
        SendMessage("No tienes suficiente Zen para iniciar esta misión.", index, 1)
        return
    end

    -- Validación de Monedas (WCoins/GP/Ruud)
    if player:getCoin1() < (getQuest.Coin1 or 0) or 
       player:getCoin2() < (getQuest.Coin2 or 0) or 
       player:getCoin3() < (getQuest.Coin3 or 0) then
        SendMessage("No tienes suficientes monedas para iniciar esta misión.", index, 1)
        return
    end

    -- Validación de VIP
    if (getQuest.Vip or 0) > 0 and player:getVip() < getQuest.Vip then
        SendMessage("Esta misión es exclusiva para miembros VIP.", index, 1)
        return
    end

    ---------------------------------------------------------
    -- 2. VERIFICACIÓN DIARIA (RAM)
    ---------------------------------------------------------
    local today = os.date("%Y-%m-%d")
    if QuestSystem.CompletedToday[acc] and QuestSystem.CompletedToday[acc][npc_id] and QuestSystem.CompletedToday[acc][npc_id][mapId] then
        if QuestSystem.CompletedToday[acc][npc_id][mapId][tostring(qid)] == today then
            SendMessage("Ya completaste esta misión el día de hoy.", index, 1)
            QuestSystem.SendOpenContinue(player, npc_id, qid, mapId)
            return
        end
    end

    -- 3. HIDRATACIÓN DE CACHÉ (C++)
    player:setCacheInt("QuestSystemStarted", 1)
    player:setCacheInt("QuestSystemStatus", 1)
    player:setCacheInt("QuestSystemIdentification", qid)
    player:setCacheInt("QuestSystemNPC", npc_id)
    player:setCacheInt("QuestSystemCanCollect", 0)
    player:setCacheInt("QuestSystemFinished", 0)
    for i = 1, 9 do player:setCacheInt(string.format('QuestSystemKillsMonster%d', i), 0) end

    -- 4. HIDRATACIÓN DE RAM (LUA)
    QuestSystem.PlayerActive[acc] = QuestSystem.PlayerActive[acc] or {}
    QuestSystem.PlayerActive[acc][npc_id] = QuestSystem.PlayerActive[acc][npc_id] or {}
    QuestSystem.PlayerActive[acc][npc_id][tostring(qid)] = {
        Finished = 0,
        Kills = 0,
        CanCollect = 0,
        KillsMonster = {0,0,0,0,0,0,0,0,0},
        CompletedDate = "",
        MapNumber = mapId,
        Status = 1
    }

    -- 5. BASE DE DATOS
    QuestSystem.InsertPlayer(acc, name, npc_id, qid, index, mapId)

    -- 6. LANZAMIENTO DE HUD Y CIERRE DE INTERFAZ
    player:setInterfaceUse(0)
    player:setInterfaceType(0)
    
    QuestSystem.RestorePlayerCacheFromMemory(player)
    
    Timer.TimeOut(0.5, function()
        local p_check = User.new(index)
        if p_check and p_check:getConnected() >= 3 then
            QuestSystem.SendHUDUpdate(p_check, npc_id)
            SendMessage(string.format(QUEST_SYSTEM_MESSAGES[Language][3], getQuest.QuestName or "Quest"), index, 1)
        end
    end)
    
    LogAddC(2, string.format("[QS] %s inició Quest %d en Mapa %d (Lvl req: %d)", name, qid, mapId, getQuest.Level or 0))
end

-- CheckQuestProgress
-- (kept as in your cleaned implementation)
function QuestSystem.CheckQuestProgress(member, monster)
    if not member or not monster then return end
    
    local currentStatus = member:getCacheInt("QuestSystemStatus") or 0
    if currentStatus ~= 1 then return end 
    if member:getCacheInt("QuestSystemFinished") == 1 then return end
    
    local acc = member:getAccountID()
    local qid = member:getCacheInt("QuestSystemIdentification") or 0
    local npc_id = member:getCacheInt("QuestSystemNPC") or 0
    local map_id = member:getMapNumber()

    if qid == 0 then return end

    local q_s = tostring(qid)
    local pEntry = QuestSystem.PlayerActive[acc] and QuestSystem.PlayerActive[acc][npc_id] and QuestSystem.PlayerActive[acc][npc_id][q_s]
    
    -- Buscamos los requisitos de la misión
    local key = string.format("%d_%d_%d", npc_id, map_id, qid)
    local memberQuestInfo = QUEST_SYSTEM_REQUIREMENTS_MONSTER[key] or QUEST_SYSTEM_REQUIREMENTS_MONSTER[qid]
    
    if memberQuestInfo == nil then return end

    for count, monsterInfo in ipairs(memberQuestInfo) do
        if count > 9 then break end
        
        -- Si el monstruo que murió coincide con el de la quest
        if tonumber(monsterInfo.MonsterIndex) == monster:getClass() then
            local kills = member:getCacheInt(string.format('QuestSystemKillsMonster%d', count)) or 0
            
            if kills < (monsterInfo.Quantity or 0) then
                local newKills = kills + 1
                
                -- 1. Actualizamos Caché del C++ (Para que el juego sepa)
                member:setCacheInt(string.format('QuestSystemKillsMonster%d', count), newKills)
                
                -- 2. Actualizamos la RAM Principal
                if pEntry then
                    pEntry.KillsMonster[count] = newKills
                    pEntry.Kills = (pEntry.Kills or 0) + 1
                    member:setCacheInt("QuestSystemKills", pEntry.Kills)
                end

                -- 3. [BLOQUEO ANTI-PÉRDIDA] 
                -- Llamamos a FlushPending EN CADA MUERTE. 
                -- Como ahora usamos el Procedure corto (usp_QuestSystem_SaveProgress), no da lag.
                QuestSystem.FlushPending(acc, npc_id, qid, map_id, member:getIndex())
                
				-- 4. Verificamos si completó la misión
                local allDone = true
                for idx, req in ipairs(memberQuestInfo) do
                    local cur = member:getCacheInt(string.format('QuestSystemKillsMonster%d', idx)) or 0
                    if cur < (req.Quantity or 0) then allDone = false; break end
                end
                
				if allDone then
                    member:setCacheInt("QuestSystemCanCollect", 1)
                    if pEntry then pEntry.CanCollect = 1 end

                    -- [1] AVISO AL CLIENTE PARA EL EFECTO VISUAL
                    -- Usamos 'qid' que es la variable definida al inicio de CheckQuestProgress
                    local pName = string.format("QuestGoalMet_%s", member:getName())
                    CreatePacket(pName, QUEST_SYSTEM_PACKET)
                    
                    -- CORRECCIÓN AQUÍ: Cambiamos memberQuestID por qid
                    SetDwordPacket(pName, tonumber(qid) or 0) 
                    
                    SendPacket(pName, member:getIndex())
                    ClearPacket(pName)
                    
                    -- Actualizamos estado a "Puede Cobrar" en la DB
                    local queryCan = string.format(
                        "UPDATE QUEST_SYSTEM_ACTIVE SET CanCollect = 1 WHERE AccountID='%s' AND NPC=%d AND QuestIdentification=%d AND MapNumber=%d",
                        acc, npc_id, qid, map_id)
                    
                    QuestSystem.SafeCreateAsync('CanQ', queryCan, -1, 0)
                    
                    SendMessage("¡Misión Completada! Vuelve con el NPC.", member:getIndex(), 1)
                end
                
                -- 5. HUD y Mensaje en pantalla
                QuestSystem.SendHUDUpdate(member, npc_id)
                SendMessage(string.format('[Quest System] %s: %d/%d', monsterInfo.MonsterName or "Monster", newKills, monsterInfo.Quantity or 0), member:getIndex(), 1)
                
                --LogAddC(2, string.format("[QS-KILL] %s mató %d (%d/%d). SQL Actualizado.", acc, monster:getClass(), newKills, monsterInfo.Quantity))
                break
            end
        end
    end
end

-- MonsterDie: party-aware wrapper
function QuestSystem.MonsterDie(PlayerIndex, MonsterIndex)
    local player = User.new(PlayerIndex)
    local monster = User.new(MonsterIndex) -- Mantenemos User.new por compatibilidad
    if not player or not monster then return end

    local acc = player:getAccountID()
    local qid = player:getCacheInt("QuestSystemIdentification") or 0

    -- Re-hidratación (Por si el jugador cambió de servidor/mapa y el caché está vacío)
    if qid == 0 and QuestSystem.PlayerActive and QuestSystem.PlayerActive[acc] then
        for npcId, npcTable in pairs(QuestSystem.PlayerActive[acc]) do
            for qIdStr, data in pairs(npcTable) do
                if tonumber(data.Finished or 0) == 0 then
                    qid = tonumber(qIdStr)
                    player:setCacheInt("QuestSystemIdentification", qid)
                    player:setCacheInt("QuestSystemNPC", tonumber(npcId))
                    player:setCacheInt("QuestSystemStarted", 1)
                    player:setCacheInt("QuestSystemStatus", 1)
                    
                    if data.KillsMonster then
                        for i=1, 9 do 
                            player:setCacheInt("QuestSystemKillsMonster"..i, data.KillsMonster[i] or 0) 
                        end
                    end
                    break
                end
            end
            if qid > 0 then break end
        end
    end

    if qid <= 0 then return end

    -- Lógica de Party / Solo
    local partyNumber = player:getPartyNumber()
    if partyNumber ~= -1 then
        for i = 0, 4 do
            local mIdx = GetMemberIndexParty(partyNumber, i)
            if mIdx ~= -1 then
                local member = User.new(mIdx)
                if member and member:getMapNumber() == monster:getMapNumber() then
                    QuestSystem.CheckQuestProgress(member, monster)
                end
            end
        end
    else
        QuestSystem.CheckQuestProgress(player, monster)
    end 
end

-- GetReward: give rewards and mark finished
function QuestSystem.GetReward(player)
    if not player then return end
    
    local Language = player:getLanguage()
    local acc = player:getAccountID()
    local name = player:getName()
    local today = os.date("%Y-%m-%d")
    local currentMap = player:getMapNumber()
    local npc_id = player:getCacheInt("QuestSystemNPC") or 0
    local qid = player:getCacheInt("QuestSystemIdentification") or 0
    
    -- 1. VALIDACIÓN DE ESTADO (Antifraude y Persistencia)
    -- Si Status es 2 o Finished es 1, ya cobró hoy.
    local currentStatus = player:getCacheInt("QuestSystemStatus") or 0
    if currentStatus == 2 or player:getCacheInt("QuestSystemFinished") == 1 then
        SendMessage(string.format(QUEST_SYSTEM_MESSAGES[Language][8] or "Ya completaste esta misión hoy."), player:getIndex(), 1)
        return
    end

    -- Validación de estado del personaje (Si está tradeando, muriendo, etc.)
    if player:getInterfaceUse() ~= 0 or player:getInterfaceType() ~= 0 or player:getState() == 32 or player:getDieRegen() ~= 0 or player:getTeleport() ~= 0 then
        SendMessage(string.format(QUEST_SYSTEM_MESSAGES[Language][1]), player:getIndex(), 1)
        return
    end

    -- 2. RECUPERACIÓN DE DATOS (Caché -> RAM)
    -- Si por alguna razón el caché se perdió, intentamos recuperar desde la memoria RAM
    if npc_id == 0 or qid == 0 then
        if QuestSystem.PlayerActive and QuestSystem.PlayerActive[acc] then
            for n_k, quests in pairs(QuestSystem.PlayerActive[acc]) do
                for q_k, q_v in pairs(quests) do
                    if tonumber(q_v.CanCollect) == 1 then
                        npc_id, qid = tonumber(n_k), tonumber(q_k)
                        break
                    end
                end
            end
        end
    end

    if qid == 0 then return end

    -- [ FUNCIÓN INTERNA DE BÚSQUEDA DE CONFIG ]
    local function findInTable(tbl)
        if not tbl then return nil end
        local k1 = string.format("%d_%d_%d", npc_id, currentMap, qid)
        local k2 = string.format("%d_%d", currentMap, qid)
        local k3 = string.format("%d_%d", npc_id, qid)
        return tbl[k1] or tbl[k2] or tbl[k3] or tbl[qid]
    end

    local questInfo = QuestSystem.GetQuestIdentification(qid)
    if not questInfo then return end

    -- 3. VALIDACIÓN DIARIA (SOPORTE MULTIMAPA)
    if QuestSystem.CompletedToday[acc] and QuestSystem.CompletedToday[acc][npc_id] then
        local record = QuestSystem.CompletedToday[acc][npc_id][currentMap] and QuestSystem.CompletedToday[acc][npc_id][currentMap][tostring(qid)]
        if record == today then
            SendMessage(string.format(QUEST_SYSTEM_MESSAGES[Language][8]), player:getIndex(), 1)
            player:setCacheInt("QuestSystemFinished", 1)
            player:setCacheInt("QuestSystemStatus", 2)
            return
        end
    end

    -- 4. VALIDACIÓN Y CONSUMO DE REQUISITOS (Items, Resets, Coins)
    local questItemInfo = findInTable(QUEST_SYSTEM_REQUIREMENTS_ITEMS)
    if questItemInfo ~= nil then
        local pInv = Inventory.new(player:getIndex())
        for _, req in pairs(questItemInfo) do
            local found = 0
            for slot = 12, 203 do
                if pInv:isItem(slot) ~= 0 and pInv:getIndex(slot) == req.ItemIndex then
                    if (req.Level == -1 or pInv:getLevel(slot) == req.Level)
                       and (req.Skill == -1 or pInv:getItemTable(slot, 2) == req.Skill)
                       and (req.Luck == -1 or pInv:getItemTable(slot, 3) == req.Luck) then
                        found = found + (GetStackItem(pInv:getIndex(slot)) <= 0 and 1 or pInv:getDurability(slot))
                    end
                end
            end
            if found < (req.Quantity or 1) then
                SendMessage(string.format(QUEST_SYSTEM_MESSAGES[Language][6]), player:getIndex(), 1)
                return
            end
        end
        -- Consumo de items tras validación exitosa
        for _, req in pairs(questItemInfo) do 
            DeleteItemCount(player:getIndex(), req.ItemIndex, req.Level, req.Quantity) 
        end
    end

    -- Consumo de Resets y Coins (Si está configurado para remover)
    if QUEST_SYSTEM_REMOVE_RESETS == 1 and (questInfo.Reset or 0) > 0 then player:setReset(player:getReset() - questInfo.Reset) end
    if QUEST_SYSTEM_REMOVE_MRESETS == 1 and (questInfo.MReset or 0) > 0 then player:setMasterReset(player:getMasterReset() - questInfo.MReset) end
    
    local c1r, c2r, c3r, c4r = 0, 0, 0, 0
    if QUEST_SYSTEM_REMOVE_COIN1 == 1 and (questInfo.Coin1 or 0) > 0 then c1r = questInfo.Coin1 end
    if (c1r+c2r+c3r+c4r) > 0 then RemoveCoins(player:getIndex(), c1r, c2r, c3r, c4r) end

    -- 5. ENTREGA DE RECOMPENSAS
    --SendMessage("--------------------------------------------------", player:getIndex(), 1)
    SendMessage(string.format(" [Quest System] ¡%s Finalizada!", questInfo.QuestName or "Misión"), player:getIndex(), 1)

    -- [ Items Reward ]
    local rewardItems = findInTable(QUEST_SYSTEM_REWARD_ITEMS)
    if rewardItems then
        for _, it in pairs(rewardItems) do
            if it.Class == -1 or it.Class == player:getClass() then
                local count = it.Count or 1
                for i = 1, count do
                    if QUEST_SYSTEM_USE_GREMORY == 1 then
                        GremoryCase.InsertItem(player:getAccountID(), player:getName(), questInfo.QuestName, it.Flag, it.ItemIndex, it.Level, it.Op1, it.Op2, it.Life, it.Exc, it.Ancient, it.JoH, it.SockCount, it.DaysExpire, it.ItemTime)
                    else
                        CreateItemInventory2(player:getIndex(), it.ItemIndex, it.Level, it.Op1, it.Op2, it.Life, it.Exc, it.Ancient, it.JoH, it.SockCount, (it.ItemTime or 0) * 86400)
                    end
                end
                SendMessage(string.format(" > Recibiste: %s x%d", it.Name or "Item", count), player:getIndex(), 1)
            end
        end
    end

    -- [ Coins & Ruud Reward ]
    local rewardCoins = findInTable(QUEST_SYSTEM_REWARD_COINS)
    if rewardCoins then
        local AddC = {0, 0, 0, 0, 0}
        for _, cn in pairs(rewardCoins) do
            local idx = cn.CoinIdentification
            if idx >= 1 and idx <= 5 then AddC[idx] = AddC[idx] + cn.CoinAmount end
            SendMessage(string.format(" > Recibiste: %d %s", cn.CoinAmount, cn.CoinName or "Monedas"), player:getIndex(), 1)
        end
        if AddC[4] > 0 then
            if type(player.setCoin4) == "function" then player:setCoin4(player:getCoin4() + AddC[4])
            elseif type(player.setRuud) == "function" then player:setRuud(player:getRuud() + AddC[4]) end
        end
        if (AddC[1]+AddC[2]+AddC[3]+AddC[4]) > 0 then 
            AddCoins(player:getIndex(), AddC[1], AddC[2], AddC[3], AddC[4]) 
            if type(GDCustomUpdateSend) == "function" then GDCustomUpdateSend(player:getIndex()) 
            elseif type(UpdateCashShopCoins) == "function" then UpdateCashShopCoins(player:getIndex()) end
        end
        if AddC[5] > 0 then player:setMoney(player:getMoney() + AddC[5]); MoneySend(player:getIndex()) end
    end

    -- [ Buffs Reward ]
	-- [ Exp y Niveles Reward ]
	local expR = findInTable(QUEST_SYSTEM_REWARD_EXP)
	if expR then
		local MAX_LEVEL = 400
		local MAX_MASTER_LEVEL = 400
		
		for _, ex in pairs(expR) do
			-- 1. Recompensa de Nivel Normal
			if ex.ExpId == 3 then 
				local currentLvl = player:getLevel()
				if currentLvl < MAX_LEVEL then
					local newLevel = math.min(MAX_LEVEL, currentLvl + ex.Amount)
					player:setLevel(newLevel)
					
					-- Sincronizar Nivel con el Cliente (Esto suele activar el efecto de Level Up)
					if type(LevelSend) == "function" then 
						LevelSend(player:getIndex()) 
					elseif type(GCLevelUpSend) == "function" then
						GCLevelUpSend(player:getIndex())
					end
	
					SendMessage(string.format(" > ¡Subiste de Nivel! Nuevo nivel: %d", newLevel), player:getIndex(), 1)
				end
				
			-- 2. Recompensa de Master Level
			elseif ex.ExpId == 4 then 
				local currentML = player:getMasterLevel()
				if currentML < MAX_MASTER_LEVEL then
					local newML = math.min(MAX_MASTER_LEVEL, currentML + ex.Amount)
					player:setMasterLevel(newML)
					
					-- Sincronizar Master Level
					if type(MasterLevelSend) == "function" then 
						MasterLevelSend(player:getIndex()) 
					end
	
					SendMessage(string.format(" > ¡Subiste de Nivel Master! Nuevo nivel: %d", newML), player:getIndex(), 1)
				end
				
			-- 3. Recompensa de Experiencia Normal
			elseif ex.ExpId == 1 then 
				player:setExp(player:getExp() + ex.Amount) 
				SendMessage(string.format(" > Recibiste: %d de Experiencia", ex.Amount), player:getIndex(), 1)
			end
		end
	end

    -- [ Puntos Stats Reward ]
    local ptsR = findInTable(QUEST_SYSTEM_POINTS_REWARDS)
    if ptsR then
        for _, pts in pairs(ptsR) do
            local amt = pts.Amount or 0
            if pts.PtsID == 1 then player:setLevelUpPoint(player:getLevelUpPoint() + amt)
            elseif pts.PtsID == 2 then player:setStrength(player:getStrength() + amt)
            elseif pts.PtsID == 3 then player:setDexterity(player:getDexterity() + amt)
            elseif pts.PtsID == 4 then player:setVitality(player:getVitality() + amt); player:setMaxLife(math.floor(player:getVitalityToLife() * player:getVitality()))
            elseif pts.PtsID == 5 then player:setEnergy(player:getEnergy() + amt); player:setMaxMana(math.floor(player:getEnergyToMana() * player:getEnergy())) end
        end
        if type(GCLevelUpMsgSend) == "function" then GCLevelUpMsgSend(player:getIndex()) end
    end

    --SendMessage("--------------------------------------------------", player:getIndex(), 1)

    -- 6. ACTUALIZACIÓN FINAL DE BASE DE DATOS Y ESTADOS
	local q_update = string.format(
		"UPDATE dbo.QUEST_SYSTEM_ACTIVE SET Status = 2, Finished = 1, CanCollect = 0, CompletedDate = GETDATE(), MapNumber = %d WHERE AccountID='%s' AND NPC=%d AND QuestIdentification=%d", 
		currentMap, acc, npc_id, qid
	)
	QuestSystem.SafeCreateAsync('FinalizeQuest_'..acc, q_update, -1, 0)
	
	-- [MOLDE RAM] Aseguramos que las estructuras existan
	QuestSystem.CompletedToday[acc] = QuestSystem.CompletedToday[acc] or {}
	QuestSystem.CompletedToday[acc][npc_id] = QuestSystem.CompletedToday[acc][npc_id] or {}
	QuestSystem.CompletedToday[acc][npc_id][currentMap] = QuestSystem.CompletedToday[acc][npc_id][currentMap] or {}
	
	QuestSystem.CompletedHistory[acc] = QuestSystem.CompletedHistory[acc] or {}
	
	-- 1. RAM: Registro de completado hoy (Para las Diarias)
	QuestSystem.CompletedToday[acc][npc_id][currentMap][tostring(qid)] = today
	
	-- 2. RAM: Registro de Historial Eterno (ESTA ES LA QUE FALTA PARA LAS ONE-TIME)
	-- Al agregarla acá, OpenQuest la verá inmediatamente sin necesidad de reloguear.
	QuestSystem.CompletedHistory[acc][tostring(qid)] = { isToday = true }
	
	-- 3. RAM: Limpieza de la misión de la lista de activos
	if QuestSystem.PlayerActive[acc] and QuestSystem.PlayerActive[acc][npc_id] then
		QuestSystem.PlayerActive[acc][npc_id][tostring(qid)] = nil
	end
	
	-- CACHÉ: Sincronización final con el jugador
	player:setCacheInt("QuestSystemStatus", 2)
	player:setCacheInt("QuestSystemFinished", 1)
	player:setCacheInt("QuestSystemCanCollect", 0)
	player:setCacheInt("QuestSystemStarted", 0)
	player:setCacheInt("QuestSystemIdentification", 0)
	for i = 1, 9 do player:setCacheInt(string.format('QuestSystemKillsMonster%d', i), 0) end
	
	-- Sincronizar con el cliente
	RefreshCharacter(player:getIndex())
	QuestSystem.SendHUDUpdate(player, npc_id)
	
	LogAddC(2, string.format("QuestSystem.GetReward: %s [MAP:%d] cobró recompensa satisfactoriamente y RAM actualizada.", acc, currentMap))
end

-- NpcTalk: open UI when clicking NPC
function QuestSystem.NpcTalk(NpcIndex, PlayerIndex)
    local npc = User.new(NpcIndex)
    local player = User.new(PlayerIndex)
    if not npc or not player then return 0 end

    local npcClass = tonumber(npc:getClass())
    local mapId = tonumber(player:getMapNumber())
    local acc = player:getAccountID()
    local today = os.date("%Y-%m-%d")

    if QUEST_SYSTEM_ALLOWED_NPCS[npcClass] or npcClass == QUEST_SYSTEM_NPC_CLASS then
        player:setCacheInt("QuestSystemNPC", npcClass)
        QuestSystem.SendLoadingPacket(player, npcClass)

        local tAcc, tMap, tNpc = acc, mapId, npcClass

        Timer.TimeOut(1.2, function()
            local p = User.new(PlayerIndex)
            if not p or p:getConnected() < 3 then return end

            QuestSystem.IsDataLoaded[tAcc] = true 

            -- 1. Buscamos solo misiones DIARIAS terminadas hoy
            local showCompletedWindow = false
            if QuestSystem.CompletedToday[tAcc] and 
               QuestSystem.CompletedToday[tAcc][tNpc] and 
               QuestSystem.CompletedToday[tAcc][tNpc][tMap] then
               
                for qid, date_ram in pairs(QuestSystem.CompletedToday[tAcc][tNpc][tMap]) do
                    if date_ram == today then
                        local config = QuestSystem.GetQuestIdentification(tonumber(qid))
                        -- REGLA: Cartel de éxito solo para DIARIAS
                        if config and config.IsOneTime == 0 then
                            QuestSystem.SendOpenContinue(p, tNpc, tonumber(qid), tMap)
                            showCompletedWindow = true
                            break
                        end
                    end
                end
            end

            -- 2. Si no es una diaria hecha hoy, mostramos la lista (incluyendo la siguiente One-Time)
            if not showCompletedWindow then
                QuestSystem.OpenQuest(p, tNpc)
            end
        end)
        return 1
    end
    return 0
end

-- Protocol: packet handler
function QuestSystem.Protocol(aIndex, Packet, PacketName)
    if Packet ~= QUEST_SYSTEM_PACKET then return end
    
    local player = User.new(aIndex)
    if not player then return end

    local pName = player:getName()

    -- [LOG DE ENTRADA] Detectar cualquier paquete que llegue de este sistema
    -- LogAddC(2, string.format("QuestSystem: Packet Recibido [%s] de %s", PacketName, pName))

    -- [1] ABRIR NPC / SOLICITAR LISTA
    if string.format("%s_%s", QUEST_SYSTEM_PACKET_OPEN_NAME, pName) == PacketName then
        local mapId_enviado = GetDwordPacket(PacketName, -1) or 0 
        local npc_id = player:getCacheInt("QuestSystemNPC") or 0
        
        LogAddC(2, string.format("QuestSystem: [OPEN] Jugador %s solicita lista NPC %d (Mapa: %d)", pName, npc_id, mapId_enviado))
        
        ClearPacket(PacketName)
        QuestSystem.OpenQuest(player, npc_id)

    -- [2] DAR CLICK EN "ACEPTAR" (START)
    elseif string.format("%s_%s", QUEST_SYSTEM_PACKET_START_NAME, pName) == PacketName then
        local questID = GetDwordPacket(PacketName, -1) or 0
        LogAddC(2, string.format("QuestSystem: [START] %s inició Quest ID %d", pName, questID))
        
        ClearPacket(PacketName)
        QuestSystem.StartQuest(player, questID)

    -- [3] DAR CLICK EN "COBRAR RECOMPENSA"
    elseif string.format("%s_%s", QUEST_SYSTEM_PACKET_GET_REWARD_NAME, pName) == PacketName then
        LogAddC(2, string.format("QuestSystem: [REWARD] %s intenta cobrar recompensa", pName))
        ClearPacket(PacketName)
        QuestSystem.GetReward(player)

    -- [4] BOTON CONTINUAR / CERRAR
    elseif string.format("%s_%s", QUEST_SYSTEM_PACKET_CONTINUE_QUEST_NAME, pName) == PacketName then
        local npc_id = player:getCacheInt("QuestSystemNPC")
        
        -- Solo forzamos el cierre del HUD si el jugador NO tiene una misión activa
        -- Esto evita que el HUD "pestañee" cuando abres el NPC estando terminada la misión
        local hasActive = false
        if QuestSystem.PlayerActive[acc] then
            for _, npcs in pairs(QuestSystem.PlayerActive[acc]) do
                for _, q_v in pairs(npcs) do
                    if tonumber(q_v.Status or 0) == 1 then hasActive = true; break end
                end
            end
        end

        if not hasActive then
            QuestSystem.ForceCloseClient(player, npc_id)
        end
        
        ClearPacket(PacketName)

    -- [NUEVO / REVISIÓN] SI TUVIERAS UN PAQUETE DE HUD UPDATE ENTRANDO
    -- Generalmente el HUD Update se envía del Servidor -> Cliente (no entra por aquí)
    -- Pero si tienes una respuesta del cliente, la verías así:
    elseif string.find(PacketName, "QuestSystemHUDUpdate") then
        LogAddC(2, string.format("QuestSystem: [HUD_SYNC] Recibido feedback de HUD de %s", pName))
    end
end

function QuestSystem.PlayerJoin(aIndex)
    if not aIndex or aIndex < 0 then return 0 end
    local player = User.new(aIndex)
    if not player then return 0 end
    local acc = player:getAccountID()
    
    QuestSystem.IsDataLoaded[acc] = false
    QuestSystem.LoadingAccounts = QuestSystem.LoadingAccounts or {}
    QuestSystem.LoadingAccounts[acc] = true
    QuestSystem.PlayerActive[acc] = {}
    QuestSystem.CompletedHistory[acc] = {} -- Cambiamos Today por History para ser más claros

    LogAddC(2, string.format("[QS] Iniciando carga empaquetada para %s...", acc))

    -- GeACT: Misión activa (Status 1) - Sin cambios
    local q_act = string.format(
        "SELECT AccountID, NPC, QuestIdentification, Status, MapNumber, CanCollect, Kills, " ..
        "KillsMonster1, KillsMonster2, KillsMonster3, KillsMonster4, KillsMonster5, " ..
        "KillsMonster6, KillsMonster7, KillsMonster8, KillsMonster9 " ..
        "FROM dbo.QUEST_SYSTEM_ACTIVE WHERE AccountID='%s' AND Status=1", acc
    )
    QuestSystem.SafeCreateAsync('GeACT_' .. acc, q_act, aIndex, 1)

    -- GeFIN: Misiones terminadas (Status 2). 
    -- Agregamos el DATEDIFF al paquete para saber si se hizo hoy (0) o antes (>0)
    local q_fin = string.format(
        "SELECT AccountID, STUFF((SELECT '|' + CAST(QuestIdentification AS VARCHAR) + ':' + CAST(NPC AS VARCHAR) + ':' + CAST(MapNumber AS VARCHAR) + ':' + CAST(DATEDIFF(day, CompletedDate, GETDATE()) AS VARCHAR) " ..
        "FROM QUEST_SYSTEM_ACTIVE WHERE AccountID = t.AccountID AND Status = 2 " ..
        "FOR XML PATH('')), 1, 1, '') as Pack " ..
        "FROM QUEST_SYSTEM_ACTIVE t WHERE AccountID = '%s' GROUP BY AccountID", acc
    )
    QuestSystem.SafeCreateAsync('GeFIN_' .. acc, q_fin, aIndex, 1)

    -- Timer de seguridad
    Timer.TimeOut(1.5, function()
        QuestSystem.IsDataLoaded[acc] = true
        QuestSystem.LoadingAccounts[acc] = nil
    end)

    return 1
end

function QuestSystem.OnPlayerLogout(aIndex)
    local player = User.new(aIndex)
    if player then
        local acc = player:getAccountID()
        if acc and acc ~= "" then
            
            -- [RESCATE CRÍTICO] Antes de borrar la RAM, salvamos los pendientes al SQL
            if QuestSystem.PendingCounters and QuestSystem.PendingCounters[acc] then
                for npc_id, quests in pairs(QuestSystem.PendingCounters[acc]) do
                    for qid_str, data in pairs(quests) do
                        local mid = 0
                        -- Obtenemos el mapa real de la misión activa
                        if QuestSystem.PlayerActive[acc] and QuestSystem.PlayerActive[acc][npc_id] and QuestSystem.PlayerActive[acc][npc_id][qid_str] then
                            mid = QuestSystem.PlayerActive[acc][npc_id][qid_str].MapNumber or 0
                        end
                        QuestSystem.FlushPending(acc, npc_id, tonumber(qid_str), mid)
                    end
                end
            end

            -- Limpieza de RAM
            QuestSystem.PlayerActive[acc] = nil
            QuestSystem.LoadingAccounts[acc] = nil
            QuestSystem.IsDataLoaded[acc] = nil
            QuestSystem.PendingCounters[acc] = nil
            
            -- Limpieza de Caché C++
            player:clearCacheInt("QuestSystemIdentification")
            player:clearCacheInt("QuestSystemNPC")
            player:clearCacheInt("QuestSystemStarted")
            player:clearCacheInt("QuestSystemStatus")
            player:clearCacheInt("QuestSystemCanCollect")
            for i = 1, 9 do player:clearCacheInt("QuestSystemKillsMonster"..i) end
            
            LogAddC(2, string.format("QuestSystem: Datos salvados y sesión cerrada para %s", acc))
        end
    end
end

function QuestSystem.CheckDatabase()
    LogAddC(2, "[QS] Verificando tablas en la Base de Datos...")

    -- Script para crear la TABLA si no existe
    local tableQuery = [[
        IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[QUEST_SYSTEM_ACTIVE]') AND type in (N'U'))
        BEGIN
            CREATE TABLE [dbo].[QUEST_SYSTEM_ACTIVE](
                [AccountID] [varchar](10) NOT NULL,
                [Name] [varchar](10) NULL,
                [NPC] [int] NOT NULL,
                [QuestIdentification] [int] NOT NULL,
                [Finished] [tinyint] DEFAULT 0,
                [Kills] [int] DEFAULT 0,
                [KillsMonster1] [int] DEFAULT 0,
                [KillsMonster2] [int] DEFAULT 0,
                [KillsMonster3] [int] DEFAULT 0,
                [KillsMonster4] [int] DEFAULT 0,
                [KillsMonster5] [int] DEFAULT 0,
                [KillsMonster6] [int] DEFAULT 0,
                [KillsMonster7] [int] DEFAULT 0,
                [KillsMonster8] [int] DEFAULT 0,
                [KillsMonster9] [int] DEFAULT 0,
                [CanCollect] [tinyint] DEFAULT 0,
                [Status] [int] DEFAULT 1,
                [MapNumber] [int] DEFAULT 0,
                [CompletedDate] [datetime] DEFAULT GETDATE()
            ) ON [PRIMARY];
            PRINT 'Tabla QUEST_SYSTEM_ACTIVE creada.';
        END
    ]]

    -- Ejecutamos la creación de la tabla
    QuestSystem.SafeCreateAsync('QS_InstallTable', tableQuery, -1, 0)

    -- Nota: Los Procedures son más complejos de crear vía Lua por el comando 'GO'.
    -- Como actualmente tu sistema usa "SafeCreateAsync" con Queries directas (INSERT/UPDATE/DELETE),
    -- ¡Ya NO necesitás los Procedures! El código actual es independiente de ellos.
end

-- Init: register hooks
function QuestSystem.Init()
    LogAddC(2, "QuestSystem: Init called (start)")
    if QUEST_SYSTEM_SWITCH ~= 1 then
        LogAddC(2, "QuestSystem: switch disabled")
        return
    end
	-- [INSTALADOR] Ejecutamos el chequeo de DB antes que nada
    --QuestSystem.CheckDatabase() --Descomentar ACA
	
    -- DEBUG: show DB API availability
    LogAddC(2, string.format("QuestSystem.DEBUG: CreateQuery=%s QuestSystem.SafeCreateAsync=%s DataBaseAsync.Query=%s DataBaseAsync.SetAddValue=%s",
        tostring(CreateQuery ~= nil), tostring(QuestSystem.SafeCreateAsync ~= nil),
        tostring(DataBaseAsync ~= nil and DataBaseAsync.Query ~= nil),
        tostring(DataBaseAsync ~= nil and DataBaseAsync.SetAddValue ~= nil)
    ))

    if not GameServerFunctions then
        LogAddC(2, "QuestSystem: GameServerFunctions is nil")
        return
    end

    -- safe registrar: evita pasar nil callbacks al engine y protege con pcall
    local function safe_register(funcRegister, cb)
        if not funcRegister then return end
        if type(cb) ~= "function" then
            funcRegister(function(...) return 0 end)
        else
            funcRegister(function(...)
                local ok, res = pcall(cb, ...)
                if not ok then
                    LogAddC(2, string.format("QuestSystem: handler error: %s", tostring(res)))
                end
                return res
            end)
        end
    end

    safe_register(GameServerFunctions.GameServerProtocol, QuestSystem.Protocol)
    safe_register(GameServerFunctions.EnterCharacter, QuestSystem.PlayerJoin)
    safe_register(GameServerFunctions.MonsterDie, QuestSystem.MonsterDie)
    safe_register(GameServerFunctions.QueryAsyncProcess, QuestSystem.QueryAsyncProcess)
    safe_register(GameServerFunctions.NpcTalk, QuestSystem.NpcTalk)
    safe_register(GameServerFunctions.PlayerLogout, QuestSystem.OnPlayerLogout)

    LogAddC(2, "QuestSystem: Init registered handlers")

    -- [ ESCUDO DE REINICIO: RE-HIDRATACIÓN GLOBAL ]
    -- Si recargás el script mientras hay gente online, esto restaura su RAM
    if type(gObjIsConnectedGP) == "function" then
        local count = 0
        -- Los emuladores MuEmu/Louis suelen ubicar a los usuarios a partir del index 8000
        for i = 8000, 12000 do
            if gObjIsConnectedGP(i) ~= 0 then
                QuestSystem.PlayerJoin(i)
                count = count + 1
            end
        end
        if count > 0 then
            LogAddC(2, string.format("QuestSystem: [Reload Shield] Se re-hidrataron %d jugadores online.", count))
        end
    end
end

-- Compatibility shims
function QuestSystem.OpenContinueQuest(player)
    if type(player) == "number" then player = User.new(player) end
    if not player then return end
    local packetString = string.format("%s_%s", QUEST_SYSTEM_PACKET_CONTINUE_QUEST_NAME, player:getName())
    CreatePacket(packetString, QUEST_SYSTEM_PACKET)
    SendPacket(packetString, player:getIndex())
    ClearPacket(packetString)
end

function QuestSystem.AbandonQuest(player)
    if type(player) == "number" then player = User.new(player) end
    if not player then return end

    local acc = player:getAccountID()
    local npc_id = player:getCacheInt("QuestSystemNPC") or 0
    local questID = player:getCacheInt("QuestSystemIdentification") or 0
    local mapId = player:getMapNumber() -- [NUEVO] Obtener mapa actual

    -- 1. Limpiar Caché del Personaje (C++)
    player:clearCacheInt("QuestSystemIdentification")
    player:clearCacheInt("QuestSystemStarted")
    player:clearCacheInt("QuestSystemCanCollect")
    player:clearCacheInt("QuestSystemKills")
    for i = 1, 9 do 
        player:clearCacheInt(string.format("QuestSystemKillsMonster%d", i)) 
    end

    -- 2. Actualizar Base de Datos (Con MapNumber)
    if acc and questID and questID > 0 then
        -- [ACTUALIZADO] Añadimos MapNumber al WHERE para ser precisos
        local where = string.format("AccountID='%s' AND NPC=%d AND QuestIdentification=%d AND MapNumber=%d", 
            acc, npc_id, questID, mapId)
        
        -- En lugar de solo UPDATE, podrías usar un DELETE si prefieres que la misión desaparezca, 
        -- pero el UPDATE a 0 está bien si quieres mantener el registro.
        local q = string.format("UPDATE dbo.QUEST_SYSTEM_ACTIVE SET Finished = 0, Kills = 0, KillsMonster1=0,KillsMonster2=0,KillsMonster3=0,KillsMonster4=0,KillsMonster5=0,KillsMonster6=0,KillsMonster7=0,KillsMonster8=0,KillsMonster9=0 WHERE %s", where)
        
        QuestSystem.SafeCreateAsync('AbandonQuest_'..acc..'_'..tostring(questID), q, -1, 1)

        -- 3. Limpiar Memoria RAM (Lua)
        if QuestSystem.PlayerActive[acc] and QuestSystem.PlayerActive[acc][npc_id] then
            QuestSystem.PlayerActive[acc][npc_id][tostring(questID)] = nil
            LogAddC(2, string.format("QuestSystem: %s abandonó quest %d en mapa %d (RAM limpia)", acc, questID, mapId))
        end
    end

    -- 4. Refrescar la ventana del NPC
    QuestSystem.OpenQuest(player, npc_id)
end

QuestSystem.LastCheckDate = os.date("%Y-%m-%d")

function QuestSystem.MidnightControl()
    local currentDate = os.date("%Y-%m-%d")
    
    -- Si la fecha cambió (pasó la medianoche)
    if currentDate ~= QuestSystem.LastCheckDate then
        LogAddC(2, "--------------------------------------------------")
        LogAddC(2, "[QS] CAMBIO DE DÍA DETECTADO. Reseteando misiones...")
        LogAddC(2, "--------------------------------------------------")
        
        -- 1. Limpiamos la RAM de misiones terminadas
        QuestSystem.CompletedToday = {}
        
        -- 2. Actualizamos la fecha de referencia
        QuestSystem.LastCheckDate = currentDate
        
        -- 3. (Opcional) Avisar a los jugadores online
        -- GlobalMessage("Las misiones diarias han sido reiniciadas.")
    end
end

-- Registramos el Timer para que corra cada 60 segundos
Timer.TimeOut(60, QuestSystem.MidnightControl, -1)

-- start
QuestSystem.Init()