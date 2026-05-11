-- QuestSystemByMaps.lua (limpio y ordenado)
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
QuestSystemByMaps = QuestSystemByMaps or {}
QuestSystemByMaps.PlayerActive = QuestSystemByMaps.PlayerActive or {} -- cache
QuestSystemByMaps.CompletedHistory = QuestSystemByMaps.CompletedHistory or {}
QuestSystemByMaps.CompletedToday = QuestSystemByMaps.CompletedToday or {}
QuestSystemByMaps.LoadingAccounts = QuestSystemByMaps.LoadingAccounts or {}
QuestSystemByMaps.IsDataLoaded = QuestSystemByMaps.IsDataLoaded or {}

-- pending buffers: flags y contadores acumulados mientras no exista la fila DB
QuestSystemByMaps.PendingInserts = QuestSystemByMaps.PendingInserts or {}
QuestSystemByMaps.PendingCounters = QuestSystemByMaps.PendingCounters or {}

local function Split(s, delimiter)
    local result = {}
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match)
    end
    return result
end

function QuestSystemByMaps.SendLoadingPacket(player, npc_id)
    if not player then return end
    local name = player:getName()
    local packetName = string.format("%s_%s", QUEST_SYSTEM_MAPS_PACKET_OPEN_NAME, name)
    local function SD(v) return tonumber(v) or 0 end

    CreatePacket(packetName, QUEST_SYSTEM_MAPS_PACKET)
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

function QuestSystemByMaps.SafeCreateAsync(name, sql, aIndex, flag)
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
function QuestSystemByMaps.DumpPlayerActiveForAcc(acc)
    if not acc or not QuestSystemByMaps.PlayerActive then
        LogAddC(2, "QuestSystemByMaps.Dump: PlayerActive nil or acc nil")
        return
    end
    
    local t = QuestSystemByMaps.PlayerActive[acc]
    if not t then
        LogAddC(2, string.format("QuestSystemByMaps.Dump: No hay datos activos para la cuenta: [%s]", tostring(acc)))
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
function QuestSystemByMaps.GetQuestIdentification(npc_id, id)
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

function QuestSystemByMaps.OnPlayerMove(aIndex)
    local player = User.new(aIndex)
    if not player then return end
    local acc = player:getAccountID()

    -- [SEGURIDAD] No borramos QuestSystemByMaps.PlayerActive ni CompletedToday
    -- Solo reseteamos el estado de "Ventana Abierta" para que el sistema 
    -- se vea obligado a consultar el nuevo mapa al hablar con un NPC.
    player:setCacheInt("QuestSystemByMapsNPC", 0)
    
    -- Si el jugador tiene una misión activa (Status 1), la restauramos al cambiar de mapa
    -- para que el HUD siga funcionando correctamente en la nueva zona.
    QuestSystemByMaps.RestorePlayerCacheFromMemory(player)
end

-- Helper: restore cache from in-memory PlayerActive
function QuestSystemByMaps.RestorePlayerCacheFromMemory(player)
    if not player then return end
    local acc = player:getAccountID()
    if not acc or not QuestSystemByMaps.PlayerActive[acc] then return end
    
    for npc_id, quests in pairs(QuestSystemByMaps.PlayerActive[acc]) do
        for qk, qv in pairs(quests) do
            if tonumber(qv.Status) == 1 then
                player:setCacheInt("QuestSystemByMapsNPC", tonumber(npc_id))
                player:setCacheInt("QuestSystemByMapsIdentification", tonumber(qk))
                player:setCacheInt("QuestSystemByMapsKills", tonumber(qv.Kills) or 0)
                player:setCacheInt("QuestSystemByMapsStatus", 1)
                player:setCacheInt("QuestSystemByMapsCanCollect", tonumber(qv.CanCollect) or 0)
                player:setCacheInt("QuestSystemByMapsFinished", 0)
                
                -- Sincronizar monstruos individuales
                if qv.KillsMonster then
                    for i = 1, 9 do
                        player:setCacheInt("QuestSystemByMapsKillsMonster"..i, tonumber(qv.KillsMonster[i]) or 0)
                    end
                end

                -- Flag Started: si ya puede cobrar es 0, si está matando es 1
                player:setCacheInt("QuestSystemByMapsStarted", (tonumber(qv.CanCollect) == 1) and 0 or 1)
                
                LogAddC(2, string.format("[QS-CACHE] RAM -> C++: %s (QID:%d Kills:%d)", acc, tonumber(qk), tonumber(qv.Kills)))
                return 
            end
        end
    end
end

-- DB helper: InsertPlayer (marca pending y ejecuta insert preferente por DataBaseAsync.Query/CreateQuery o async)
function QuestSystemByMaps.InsertPlayer(account, name, npc_id, questIdentification, playerIndex, mapId)
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

    QuestSystemByMaps.SafeCreateAsync('QS_Upsert', query, playerIndex, 0)
    
    -- RAM Sync inmediata para que el HUD responda YA
    QuestSystemByMaps.PlayerActive[account] = QuestSystemByMaps.PlayerActive[account] or {}
    QuestSystemByMaps.PlayerActive[account][npc_id] = QuestSystemByMaps.PlayerActive[account][npc_id] or {}
    QuestSystemByMaps.PlayerActive[account][npc_id][tostring(questIdentification)] = { 
        Finished = 0, Kills = 0, KillsMonster = {0,0,0,0,0,0,0,0,0}, 
        CanCollect = 0, MapNumber = mapId, Status = 1 
    }
end

-- Flush pending counters for an account/npc/qid (aplica INSERT si necesario y acumula increments)
function QuestSystemByMaps.FlushPending(account, npc_id, questIdentification, map_id, aIndex)
    if not account or not npc_id or not questIdentification then return end
    local acc, qk = tostring(account), tostring(questIdentification)
    local ram = QuestSystemByMaps.PlayerActive[acc] and QuestSystemByMaps.PlayerActive[acc][npc_id] and QuestSystemByMaps.PlayerActive[acc][npc_id][qk]

    if ram then
        local query = string.format(
            "UPDATE QUEST_SYSTEM_ACTIVE SET Kills=%d, KillsMonster1=%d, KillsMonster2=%d, KillsMonster3=%d, KillsMonster4=%d, KillsMonster5=%d, KillsMonster6=%d, KillsMonster7=%d, KillsMonster8=%d, KillsMonster9=%d, Status=1 " ..
            "WHERE AccountID='%s' AND NPC=%d AND QuestIdentification=%d",
            ram.Kills, ram.KillsMonster[1], ram.KillsMonster[2], ram.KillsMonster[3], ram.KillsMonster[4], 
            ram.KillsMonster[5], ram.KillsMonster[6], ram.KillsMonster[7], ram.KillsMonster[8], ram.KillsMonster[9],
            acc, npc_id, tonumber(qk)
        )

        QuestSystemByMaps.SafeCreateAsync('QS_Update', query, aIndex, 0)
    end
end

-- QueryAsyncProcess: manejo de callbacks (GetActiveQuests, Insert completions, QuestInc/QuestCan)
function QuestSystemByMaps.QueryAsyncProcess(queryName, identification, aIndex)
    if not queryName then return 0 end
    
    -- Log de auditoría para verificar respuesta del motor asíncrono
    LogAddC(2, string.format("QuestSystemByMaps.QueryAsyncProcess: CALLBACK RECEIVED name=%s id=%s", tostring(queryName), tostring(identification)))

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
            QuestSystemByMaps.IsDataLoaded[db_acc] = true
            if QuestSystemByMaps.LoadingAccounts then QuestSystemByMaps.LoadingAccounts[db_acc] = nil end

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
                    
                    QuestSystemByMaps.PlayerActive[db_acc] = QuestSystemByMaps.PlayerActive[db_acc] or {}
                    QuestSystemByMaps.PlayerActive[db_acc][npc] = QuestSystemByMaps.PlayerActive[db_acc][npc] or {}
                    
                    local km = {}
                    for i = 1, 9 do 
                        km[i] = tonumber(QueryAsyncGetValue(identification, 'KillsMonster'..i)) or 0 
                    end

                    QuestSystemByMaps.PlayerActive[db_acc][npc][tostring(qid)] = {
                        Status = 1, MapNumber = mid, Finished = 0,
                        Kills = k0, CanCollect = can, KillsMonster = km
                    }
                    
                    -- Re-hidratación C++ (HUD)
                    if player then 
                        QuestSystemByMaps.RestorePlayerCacheFromMemory(player) 
                        Timer.TimeOut(3.0, function()
                            local p_check = User.new(aIndex)
                            if p_check and p_check:getConnected() >= 3 then
                                QuestSystemByMaps.SendHUDUpdate(p_check, npc)
                            end
                        end)
                    end
                end

            -- [B] PROCESAMIENTO DE HISTORIAL Y DIARIAS (GeFIN)
            elseif string.sub(queryName, 1, 5) == "GeFIN" then
                local packData = tostring(QueryAsyncGetValue(identification, 'Pack') or "")
                
                -- Inicialización de mochilas
                QuestSystemByMaps.CompletedHistory[db_acc] = QuestSystemByMaps.CompletedHistory[db_acc] or {}
                QuestSystemByMaps.CompletedToday[db_acc] = QuestSystemByMaps.CompletedToday[db_acc] or {}

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
                            QuestSystemByMaps.CompletedHistory[db_acc][qid_p] = { 
                                isToday = (diff == 0) 
                            }

                            -- Si se hizo hoy (diff 0), lo guardamos en CONTROL DIARIO (Para IsOneTime=0)
                            if diff == 0 then
                                QuestSystemByMaps.CompletedToday[db_acc][npc_p] = QuestSystemByMaps.CompletedToday[db_acc][npc_p] or {}
                                QuestSystemByMaps.CompletedToday[db_acc][npc_p][mid_p] = QuestSystemByMaps.CompletedToday[db_acc][npc_p][mid_p] or {}
                                QuestSystemByMaps.CompletedToday[db_acc][npc_p][mid_p][qid_p] = today
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
function QuestSystemByMaps.BuildQuestPacket(player, npc_id, packetName, providedQuestsList)
    if not player then return end

    -- Función SD para manejar Números y Booleanos (true -> 1, false -> 0)
    local function SD(v) 
        if v == true then return 1 end
        if v == false then return 0 end
        return tonumber(v) or 0 
    end

    packetName = packetName or string.format("%s_%s", QUEST_SYSTEM_MAPS_PACKET_OPEN_NAME, player:getName())
    local isHUDUpdate = (packetName:find("HUDUpdate")) and true or false
    local acc = player:getAccountID()
    local today = os.date("%Y-%m-%d")
    local current_map = player:getMapNumber()

    -- Aseguramos que las llaves sean números
    local npcKey = SD(npc_id)
    local mapKey = SD(current_map)

    -- Sincronizar NPC en Cache
    if npc_id ~= nil then 
        player:setCacheInt("QuestSystemByMapsNPC", npcKey) 
    else 
        npcKey = player:getCacheInt("QuestSystemByMapsNPC") or 0 
    end

    local qid_active = 0
    local finished_to_send = 0
    local can_collect_to_send = 0
    local kills_monster = {0,0,0,0,0,0,0,0,0}
    local items_to_send = {0,0,0,0,0,0,0,0,0,0} 
    
    local allItemsDone = true

    -- [A] BUSCAR MISIÓN ACTIVA (Filtrado por Mapa)
    if QuestSystemByMaps.PlayerActive[acc] then
        for n_id, npcs in pairs(QuestSystemByMaps.PlayerActive[acc]) do
            for q_id, q_v in pairs(npcs) do
                -- Solo procesamos si no está marcada como finalizada (Status 1)
                if SD(q_v.Finished) == 0 then
                    local check_qid = SD(q_id)
                    local quest_map_owner = SD(q_v.MapNumber)

                    -- Si es HUD, forzamos la llave del NPC para que el cliente la encuentre
                    if isHUDUpdate then npcKey = SD(n_id) end

                    -- Validamos si la misión activa es del mapa actual
                    if quest_map_owner == mapKey then
                        qid_active = check_qid
                        can_collect_to_send = SD(q_v.CanCollect)
                        
                        -- 1. Cargamos Kills de Monstruos
                        if q_v.KillsMonster then
                            for i = 1, 9 do kills_monster[i] = SD(q_v.KillsMonster[i]) end
                        end

                        -- 2. CONTEO DE ITEMS EN TIEMPO REAL (Escaneo de Mochila)
                        local itemReq = QUEST_SYSTEM_MAPS_REQUIREMENTS_ITEMS[string.format("%d_%d_%d", n_id, mapKey, qid_active)] 
                                        or QUEST_SYSTEM_MAPS_REQUIREMENTS_ITEMS[qid_active]
                        
                        if itemReq then
                            local pInv = Inventory.new(player:getIndex())
                            for idx, req in ipairs(itemReq) do
                                if idx > 10 then break end
                                local currentCount = 0
                                for i = 12, 203 do -- Slots del inventario
                                    if pInv:isItem(i) ~= 0 and pInv:getIndex(i) == req.ItemIndex then
                                        -- Validar Level, Skill y Luck (Compatibilidad Base)
                                        local lvOk = (req.Level == -1 or pInv:getLevel(i) == req.Level)
                                        local skOk = (req.Skill == -1 or pInv:getItemTable(i, 2) == (req.Skill or 0))
                                        local lkOk = (req.Luck == -1 or pInv:getItemTable(i, 3) == (req.Luck or 0))
                                        
                                        if lvOk and skOk and lkOk then
                                            if GetStackItem(pInv:getIndex(i)) <= 0 then
                                                currentCount = currentCount + 1
                                            else
                                                currentCount = currentCount + (pInv:getDurability(i) > 0 and pInv:getDurability(i) or 1)
                                            end
                                        end
                                    end
                                end
                                items_to_send[idx] = currentCount
                                -- Si falta un solo ítem de la lista, marcamos como incompleto
                                if currentCount < (req.Quantity or 1) then allItemsDone = false end
                            end
                        end

                        -- 3. VALIDACIÓN CRUZADA (Monstruos + Ítems)
                        -- Si el servidor dice que puede cobrar (porque mató los bichos) pero NO tiene los ítems
                        -- forzamos can_collect_to_send a 0 para que el HUD no muestre el Check verde erróneo.
                        if can_collect_to_send == 1 and not allItemsDone then
                            can_collect_to_send = 0
                        end

                    else
                        -- Si tiene una misión en OTRO mapa, la marcamos como Remota
                        qid_active = check_qid
                        can_collect_to_send = 2 -- Flag de "Remoto"
                    end
                    break
                end
            end
            if qid_active > 0 then break end
        end
    end

    -- [B] DETERMINAR SI MOSTRAR CARTEL "COMPLETED" (Finished Today)
    local questsList = providedQuestsList or {}
    if qid_active == 0 and #questsList == 0 and not isHUDUpdate then
        if QuestSystemByMaps.CompletedToday[acc] and QuestSystemByMaps.CompletedToday[acc][npcKey] then
            if QuestSystemByMaps.CompletedToday[acc][npcKey][mapKey] then
                for qid_done, date_done in pairs(QuestSystemByMaps.CompletedToday[acc][npcKey][mapKey]) do
                    if date_done == today then
                        finished_to_send = 1
                        qid_active = SD(qid_done)
                        break
                    end
                end
            end
        end
    end

    -- [C] ENVÍO DE PAQUETE (HEADER Y STATS)
    CreatePacket(packetName, QUEST_SYSTEM_MAPS_PACKET)
    SetDwordPacket(packetName, npcKey)
    SetDwordPacket(packetName, mapKey)
    SetDwordPacket(packetName, SD(qid_active))

    -- Stats (9 Dwords)
    SetDwordPacket(packetName, SD(player:getLevel()))
    SetDwordPacket(packetName, SD(player:getReset()))
    SetDwordPacket(packetName, SD(player:getMasterReset()))
    SetDwordPacket(packetName, SD(player:getMoney()))
    SetDwordPacket(packetName, SD(player:getCoin1()))
    SetDwordPacket(packetName, SD(player:getCoin2()))
    SetDwordPacket(packetName, SD(player:getCoin3()))
    
    local ruud = 0
    if acc ~= "" and DataBase and DataBase.GetValue then 
        ruud = DataBase.GetValue('CashShopData', 'Ruud', 'AccountID', acc) or 0 
    end
    SetDwordPacket(packetName, SD(ruud))
    SetDwordPacket(packetName, SD(player:getVip()))
    
    -- Dword 10 de Stats (Control Flag): 0=Incomp, 1=Reward, 2=Remote
    SetDwordPacket(packetName, SD(can_collect_to_send))

    -- Flags y Arrays
    SetBytePacket(packetName, SD(finished_to_send)) 
    for i = 1, 9 do SetDwordPacket(packetName, SD(kills_monster[i])) end
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
            local list_kills = {0,0,0,0,0,0,0,0,0}
            
            -- Verificamos si esta misión de la lista está ACTIVA en RAM
            if QuestSystemByMaps.PlayerActive[acc] and QuestSystemByMaps.PlayerActive[acc][npcKey] and QuestSystemByMaps.PlayerActive[acc][npcKey][tostring(qid_l)] then
                local st = QuestSystemByMaps.PlayerActive[acc][npcKey][tostring(qid_l)]
                f, c = SD(st.Finished), SD(st.CanCollect)
                if st.KillsMonster then
                    for j = 1, 9 do list_kills[j] = SD(st.KillsMonster[j]) end
                end
            end

            -- Verificamos si ya se TERMINÓ hoy en este mapa
            if f == 0 and QuestSystemByMaps.CompletedToday[acc] and QuestSystemByMaps.CompletedToday[acc][npcKey] and QuestSystemByMaps.CompletedToday[acc][npcKey][mapKey] then
                if QuestSystemByMaps.CompletedToday[acc][npcKey][mapKey][tostring(qid_l)] == today then
                    local config = QuestSystemByMaps.GetQuestIdentification(qid_l)
                    if config and config.IsOneTime == 0 then f = 1 end
                end
            end

            SetDwordPacket(packetName, qid_l)
            SetDwordPacket(packetName, f)
            SetDwordPacket(packetName, c)
            for j = 1, 9 do SetDwordPacket(packetName, list_kills[j]) end 
        end
    end

    SendPacket(packetName, player:getIndex())
    ClearPacket(packetName)
end

-- 1. FUNCIÓN PARA EL NPC (Abre la ventana)
function QuestSystemByMaps.OpenQuest(player, npc_id)
    if not player then return end
    local acc = player:getAccountID()
    local map_id = player:getMapNumber()
    player:setCacheInt("QuestSystemByMapsNPC", npc_id)

    if QuestSystemByMaps.IsDataLoaded[acc] == false then return end

    local fullList = {}
    if QUEST_SYSTEM_BY_MAP and QUEST_SYSTEM_BY_MAP[map_id] then
        fullList = QUEST_SYSTEM_BY_MAP[map_id]
    elseif QUEST_SYSTEM_MAPS_INFO_BY_NPC and QUEST_SYSTEM_MAPS_INFO_BY_NPC[npc_id] then
        fullList = QUEST_SYSTEM_MAPS_INFO_BY_NPC[npc_id]
    end

    local filteredList = {}
    local oneTimeFound = false
    local anyActive = false

    for _, config in ipairs(fullList) do
        local qid = tostring(config.QuestIdentification)
        local isOneTime = (config.IsOneTime == 1)
        
        -- 1. Estado en RAM (Activa)
        local isActive = (QuestSystemByMaps.PlayerActive[acc] and QuestSystemByMaps.PlayerActive[acc][npc_id] and QuestSystemByMaps.PlayerActive[acc][npc_id][qid]) ~= nil
        
        -- 2. Estado en Historial (Terminada alguna vez)
        local history = QuestSystemByMaps.CompletedHistory[acc] and QuestSystemByMaps.CompletedHistory[acc][qid]
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
    QuestSystemByMaps.BuildQuestPacket(player, npc_id, nil, filteredList, finishedFlag)
end

function QuestSystemByMaps.GetQuestIdentification(qid)
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
    if QUEST_SYSTEM_MAPS_INFO then
        for _, q in pairs(QUEST_SYSTEM_MAPS_INFO) do
            if tonumber(q.QuestIdentification) == searchId then 
                return q 
            end
        end
    end

    return nil
end

-- 2. FUNCIÓN PARA EL HUD (Actualización silenciosa)
function QuestSystemByMaps.SendHUDUpdate(player, npc_id) 
	if not player then return end 
	local packetName = string.format("QuestSystemByMapsHUDUpdate_%s", player:getName()) QuestSystemByMaps.BuildQuestPacket(player, npc_id, packetName) 
end

function QuestSystemByMaps.SendOpenContinue(player, npc_id, qid, map_id)
    -- 1. Validaciones iniciales de objeto y estado
    if type(player) == "number" then player = User.new(player) end
    if not player then return end
    
    local acc = player:getAccountID()
    local name = player:getName()
    local packetName = string.format("%s_%s", QUEST_SYSTEM_MAPS_PACKET_OPEN_NAME, name)
    
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
    CreatePacket(packetName, QUEST_SYSTEM_MAPS_PACKET)
    
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

function QuestSystemByMaps.ForceCloseClient(player, npc_id)
    if type(player) == "number" then player = User.new(player) end
    if not player then return end

    local name = player:getName()
    local acc = player:getAccountID()
    -- Usamos el paquete de HUD Update para forzar el cierre visual
    local packetName = string.format("QuestSystemByMapsHUDUpdate_%s", name)
    
    local function SD(v) return tonumber(v) or 0 end

    CreatePacket(packetName, QUEST_SYSTEM_MAPS_PACKET)

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
    LogAddC(2, string.format("QuestSystemByMaps.ForceCloseClient: [HUD RESET] npc=%d acc=%s", SD(npc_id), acc))
    SendPacket(packetName, player:getIndex())
    ClearPacket(packetName)
end

function QuestSystemByMaps.SendHUDContinue(player, npc_id, qid)
    if type(player) == "number" then player = User.new(player) end
    if not player then return end

    local acc = player:getAccountID()
    local name = player:getName()
    local mapId = player:getMapNumber() -- Obtenemos mapa actual
    local packetName = string.format("QuestSystemByMapsHUDUpdate_%s", name)
    
    local function SD(v) return tonumber(v) or 0 end

    CreatePacket(packetName, QUEST_SYSTEM_MAPS_PACKET)

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

    LogAddC(2, string.format("QuestSystemByMaps.SendHUDContinue: Sincronizado con MapID %d", mapId))
    SendPacket(packetName, player:getIndex())
    ClearPacket(packetName)
end

-- StartQuest
function QuestSystemByMaps.StartQuest(player, questID)
    if not player then return end
    
    local Language = player:getLanguage()
    local mapId = player:getMapNumber()
    local acc = player:getAccountID()
    local index = player:getIndex()
    local name = player:getName() 
    local npc_id = player:getCacheInt("QuestSystemByMapsNPC") or 0
    local qid = tonumber(questID) or 0
    
    -- 1. VALIDACIONES DE ESTADO
    if qid <= 0 then return end

    if player:getState() == 32 or player:getDieRegen() ~= 0 or player:getTeleport() ~= 0 then
        SendMessage(string.format(QUEST_SYSTEM_MAPS_MESSAGES[Language][1]), index, 1)
        return
    end

    -- [BLOQUEO GLOBAL] Evitar múltiples misiones activas
    if QuestSystemByMaps.PlayerActive[acc] then
        for n_k, npcs in pairs(QuestSystemByMaps.PlayerActive[acc]) do
            for q_k, q_v in pairs(npcs) do
                if tonumber(q_v.Finished or 0) == 0 then
                    SendMessage("Ya tienes una misión activa en otro mapa. Termínala primero.", index, 1)
                    return
                end
            end
        end
    end

    local getQuest = QuestSystemByMaps.GetQuestIdentification(qid)
    if getQuest == nil then 
        LogAddC(2, string.format("QuestSystemByMaps Error: No se encontro ID %d en Config", qid))
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
    if QuestSystemByMaps.CompletedToday[acc] and QuestSystemByMaps.CompletedToday[acc][npc_id] and QuestSystemByMaps.CompletedToday[acc][npc_id][mapId] then
        if QuestSystemByMaps.CompletedToday[acc][npc_id][mapId][tostring(qid)] == today then
            SendMessage("Ya completaste esta misión el día de hoy.", index, 1)
            QuestSystemByMaps.SendOpenContinue(player, npc_id, qid, mapId)
            return
        end
    end

    -- 3. HIDRATACIÓN DE CACHÉ (C++)
    player:setCacheInt("QuestSystemByMapsStarted", 1)
    player:setCacheInt("QuestSystemByMapsStatus", 1)
    player:setCacheInt("QuestSystemByMapsIdentification", qid)
    player:setCacheInt("QuestSystemByMapsNPC", npc_id)
    player:setCacheInt("QuestSystemByMapsCanCollect", 0)
    player:setCacheInt("QuestSystemByMapsFinished", 0)
    for i = 1, 9 do player:setCacheInt(string.format('QuestSystemByMapsKillsMonster%d', i), 0) end

    -- 4. HIDRATACIÓN DE RAM (LUA)
    QuestSystemByMaps.PlayerActive[acc] = QuestSystemByMaps.PlayerActive[acc] or {}
    QuestSystemByMaps.PlayerActive[acc][npc_id] = QuestSystemByMaps.PlayerActive[acc][npc_id] or {}
    QuestSystemByMaps.PlayerActive[acc][npc_id][tostring(qid)] = {
        Finished = 0,
        Kills = 0,
        CanCollect = 0,
        KillsMonster = {0,0,0,0,0,0,0,0,0},
        CompletedDate = "",
        MapNumber = mapId,
        Status = 1
    }

    -- 5. BASE DE DATOS
    QuestSystemByMaps.InsertPlayer(acc, name, npc_id, qid, index, mapId)

    -- 6. LANZAMIENTO DE HUD Y CIERRE DE INTERFAZ
    player:setInterfaceUse(0)
    player:setInterfaceType(0)
    
    QuestSystemByMaps.RestorePlayerCacheFromMemory(player)
    
    Timer.TimeOut(0.5, function()
        local p_check = User.new(index)
        if p_check and p_check:getConnected() >= 3 then
            QuestSystemByMaps.SendHUDUpdate(p_check, npc_id)
            SendMessage(string.format(QUEST_SYSTEM_MAPS_MESSAGES[Language][3], getQuest.QuestName or "Quest"), index, 1)
        end
    end)
    
    LogAddC(2, string.format("[QS] %s inició Quest %d en Mapa %d (Lvl req: %d)", name, qid, mapId, getQuest.Level or 0))
end

-- CheckQuestProgress
-- (kept as in your cleaned implementation)
function QuestSystemByMaps.CheckQuestProgress(member, monster)
    if not member or not monster then return end
    
    -- Validaciones de estado ByMaps
    local currentStatus = member:getCacheInt("QuestSystemByMapsStatus") or 0
    if currentStatus ~= 1 then return end 
    if member:getCacheInt("QuestSystemByMapsFinished") == 1 then return end
    
    local acc = member:getAccountID()
    local qid = member:getCacheInt("QuestSystemByMapsIdentification") or 0
    local npc_id = member:getCacheInt("QuestSystemByMapsNPC") or 0
    local map_id = member:getMapNumber()

    if qid == 0 then return end

    -- Acceso a tu tabla RAM original (Asegúrate que el nombre de la tabla sea este)
    local q_s = tostring(qid)
    local pEntry = QuestSystemByMaps.PlayerActive and QuestSystemByMaps.PlayerActive[acc] and QuestSystemByMaps.PlayerActive[acc][npc_id] and QuestSystemByMaps.PlayerActive[acc][npc_id][q_s]
    
    local key = string.format("%d_%d_%d", npc_id, map_id, qid)
    local memberQuestInfo = QUEST_SYSTEM_MAPS_REQUIREMENTS_MONSTER[key] or QUEST_SYSTEM_MAPS_REQUIREMENTS_MONSTER[qid]
    
    if memberQuestInfo == nil then return end

    for count, monsterInfo in ipairs(memberQuestInfo) do
        if count > 9 then break end
        
        -- Si el monstruo coincide
        if tonumber(monsterInfo.MonsterIndex) == monster:getClass() then
            local kills = member:getCacheInt(string.format('QuestSystemByMapsKillsMonster%d', count)) or 0
            
            if kills < (monsterInfo.Quantity or 0) then
                local newKills = kills + 1
                
                -- 1. Actualizamos Caché del C++ (Lo que lee el HUD)
                member:setCacheInt(string.format('QuestSystemByMapsKillsMonster%d', count), newKills)
                
                -- 2. RECONSTRUCCIÓN: Actualizamos tu RAM (pEntry) como lo tenías antes
                if pEntry then
                    pEntry.KillsMonster[count] = newKills
                    pEntry.Kills = (pEntry.Kills or 0) + 1
                    member:setCacheInt("QuestSystemByMapsKills", pEntry.Kills)
                end

                -- 3. Guardado físico en DB
                QuestSystemByMaps.FlushPending(acc, npc_id, qid, map_id, member:getIndex())
                
                -- 4. Verificación de "Misión Completa" (Solo para la notificación)
                local allMonstersDone = true
                for idx, req in ipairs(memberQuestInfo) do
                    local cur = member:getCacheInt(string.format('QuestSystemByMapsKillsMonster%d', idx)) or 0
                    if cur < (req.Quantity or 0) then allMonstersDone = false; break end
                end
                
                -- SI TERMINÓ MONSTRUOS, REVISAMOS ÍTEMS Y NOTIFICAMOS
                if allMonstersDone then
                    local alreadyDone = member:getCacheInt("QuestSystemByMapsCanCollect") or 0
                    if alreadyDone == 0 and QuestSystemByMaps.IsQuestFullyCompleted(member) then
                        member:setCacheInt("QuestSystemByMapsCanCollect", 1)
                        if pEntry then pEntry.CanCollect = 1 end

                        -- Enviar el paquete del Cartel Dorado
                        local pName = string.format("QuestGoalMet_%s", member:getName())
                        CreatePacket(pName, QUEST_SYSTEM_MAPS_PACKET)
                        SetDwordPacket(pName, tonumber(qid) or 0) 
                        SendPacket(pName, member:getIndex())
                        ClearPacket(pName)
                        
                        -- Update de estado en DB
                        local queryCan = string.format(
                            "UPDATE QUEST_SYSTEM_ACTIVE SET CanCollect = 1 WHERE AccountID='%s' AND NPC=%d AND QuestIdentification=%d AND MapNumber=%d",
                            acc, npc_id, qid, map_id)
                        QuestSystemByMaps.SafeCreateAsync('CanQ', queryCan, -1, 0)
                        
                        SendMessage("¡Misión Completada! Vuelve con el NPC.", member:getIndex(), 1)
                    end
                end
                
                -- 5. Actualización de HUD y Mensaje (Sigue funcionando igual)
                QuestSystemByMaps.SendHUDUpdate(member, npc_id)
                SendMessage(string.format('[Quest] %s: %d/%d', monsterInfo.MonsterName or "Monster", newKills, monsterInfo.Quantity or 0), member:getIndex(), 1)
                
                break
            end
        end
    end
end

-- Función para procesar el Drop de ítems de Quest
function QuestSystemByMaps.HandleQuestDrop(player, monster)
    local mClass = monster:getClass()
    local drop = QUEST_SYSTEM_MAPS_DROP[mClass]

    if not drop then return end

    local playerQid = player:getCacheInt("QuestSystemByMapsIdentification") or 0
    if playerQid ~= drop.qid then return end

    -- --- NUEVO BLOQUE DE SEGURIDAD ---
    -- Buscamos cuántos pide la misión exactamente para este ítem
    local npc_id = player:getCacheInt("QuestSystemByMapsNPC") or 0
    local map_id = player:getMapNumber()
    local key = string.format("%d_%d_%d", npc_id, map_id, playerQid)
    local itemReqList = QUEST_SYSTEM_MAPS_REQUIREMENTS_ITEMS[key] or QUEST_SYSTEM_MAPS_REQUIREMENTS_ITEMS[playerQid]

    if itemReqList then
        local targetItemID = GET_ITEM(drop.s, drop.i)
        for _, it in ipairs(itemReqList) do
            -- Si este requisito coincide con lo que el bicho va a soltar...
            if it.ItemIndex == targetItemID then
                local currentCount = QuestSystemByMaps.GetCurrentItemCount(player, it.ItemIndex, drop.lvl)
                -- Si ya tenemos lo que pide (o más), salimos sin dropear nada
                if currentCount >= (it.Quantity or 1) then 
                    return 
                end
            end
        end
    end
    -- --------------------------------

    -- Si pasó el filtro anterior, calculamos probabilidad y dropeamos
    if math.random(1, 100) <= drop.rate then
        local aIndex = player:getIndex()
        local map = player:getMapNumber()
        local x, y = monster:getX(), monster:getY()
        local itemID = GET_ITEM(drop.s, drop.i)

        CreateItemMap(aIndex, map, x, y, itemID, drop.lvl, 0, 0, 0, 0, 0, 0, 0, 0)
        SendMessage("[Quest] ¡Has encontrado un objeto de misión!", aIndex, 1)
    end
end

function QuestSystemByMaps.GetCurrentItemCount(player, targetIndex, targetLevel)
    local pInv = Inventory.new(player:getIndex())
    local count = 0
    -- Escaneamos la mochila (slots 12 al 203)
    for i = 12, 203 do
        if pInv:isItem(i) ~= 0 and pInv:getIndex(i) == targetIndex then
            if targetLevel == -1 or pInv:getLevel(i) == targetLevel then
                local dur = pInv:getDurability(i)
                -- Si es apilable (Jewel/Misc), sumamos durabilidad. Si no, sumamos 1.
                count = count + (dur > 0 and targetIndex >= 7168 and dur or 1)
            end
        end
    end
    return count
end

-- MonsterDie: party-aware wrapper
function QuestSystemByMaps.MonsterDie(PlayerIndex, MonsterIndex)
    local player = User.new(PlayerIndex)
    local monster = User.new(MonsterIndex) -- Mantenemos User.new por compatibilidad
    if not player or not monster then return end

    local acc = player:getAccountID()
    local qid = player:getCacheInt("QuestSystemByMapsIdentification") or 0

    -- Re-hidratación (Por si el jugador cambió de servidor/mapa y el caché está vacío)
    if qid == 0 and QuestSystemByMaps.PlayerActive and QuestSystemByMaps.PlayerActive[acc] then
        for npcId, npcTable in pairs(QuestSystemByMaps.PlayerActive[acc]) do
            for qIdStr, data in pairs(npcTable) do
                if tonumber(data.Finished or 0) == 0 then
                    qid = tonumber(qIdStr)
                    player:setCacheInt("QuestSystemByMapsIdentification", qid)
                    player:setCacheInt("QuestSystemByMapsNPC", tonumber(npcId))
                    player:setCacheInt("QuestSystemByMapsStarted", 1)
                    player:setCacheInt("QuestSystemByMapsStatus", 1)
                    
                    if data.KillsMonster then
                        for i=1, 9 do 
                            player:setCacheInt("QuestSystemByMapsKillsMonster"..i, data.KillsMonster[i] or 0) 
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
                    QuestSystemByMaps.CheckQuestProgress(member, monster)
                end
            end
        end
    else
	-- 1. Procesar el conteo de muertes (Tu lógica de siempre)
    QuestSystemByMaps.CheckQuestProgress(player, monster)

    -- 2. Procesar el posible drop del ítem de misión (Nueva lógica)
    QuestSystemByMaps.HandleQuestDrop(player, monster)
    end 
end

-- GetReward: give rewards and mark finished
function QuestSystemByMaps.GetReward(player)
    if not player then return end
    
    local Language = player:getLanguage()
    local acc = player:getAccountID()
    local name = player:getName()
    local today = os.date("%Y-%m-%d")
    local currentMap = player:getMapNumber()
    local npc_id = player:getCacheInt("QuestSystemByMapsNPC") or 0
    local qid = player:getCacheInt("QuestSystemByMapsIdentification") or 0
    
    -- 1. VALIDACIÓN DE ESTADO (Antifraude y Persistencia)
    -- Si Status es 2 o Finished es 1, ya cobró hoy.
    local currentStatus = player:getCacheInt("QuestSystemByMapsStatus") or 0
    if currentStatus == 2 or player:getCacheInt("QuestSystemByMapsFinished") == 1 then
        SendMessage(string.format(QUEST_SYSTEM_MAPS_MESSAGES[Language][8] or "Ya completaste esta misión hoy."), player:getIndex(), 1)
        return
    end

    -- Validación de estado del personaje (Si está tradeando, muriendo, etc.)
    if player:getInterfaceUse() ~= 0 or player:getInterfaceType() ~= 0 or player:getState() == 32 or player:getDieRegen() ~= 0 or player:getTeleport() ~= 0 then
        SendMessage(string.format(QUEST_SYSTEM_MAPS_MESSAGES[Language][1]), player:getIndex(), 1)
        return
    end

    -- 2. RECUPERACIÓN DE DATOS (Caché -> RAM)
    -- Si por alguna razón el caché se perdió, intentamos recuperar desde la memoria RAM
    if npc_id == 0 or qid == 0 then
        if QuestSystemByMaps.PlayerActive and QuestSystemByMaps.PlayerActive[acc] then
            for n_k, quests in pairs(QuestSystemByMaps.PlayerActive[acc]) do
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

    local questInfo = QuestSystemByMaps.GetQuestIdentification(qid)
    if not questInfo then return end

    -- 3. VALIDACIÓN DIARIA (SOPORTE MULTIMAPA)
    if QuestSystemByMaps.CompletedToday[acc] and QuestSystemByMaps.CompletedToday[acc][npc_id] then
        local record = QuestSystemByMaps.CompletedToday[acc][npc_id][currentMap] and QuestSystemByMaps.CompletedToday[acc][npc_id][currentMap][tostring(qid)]
        if record == today then
            SendMessage(string.format(QUEST_SYSTEM_MAPS_MESSAGES[Language][8]), player:getIndex(), 1)
            player:setCacheInt("QuestSystemByMapsFinished", 1)
            player:setCacheInt("QuestSystemByMapsStatus", 2)
            return
        end
    end

    -- 4. VALIDACIÓN Y CONSUMO DE REQUISITOS (Items, Resets, Coins)
    local questItemInfo = findInTable(QUEST_SYSTEM_MAPS_REQUIREMENTS_ITEMS)
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
                SendMessage(string.format(QUEST_SYSTEM_MAPS_MESSAGES[Language][6]), player:getIndex(), 1)
                return
            end
        end
        -- Consumo de items tras validación exitosa
        for _, req in pairs(questItemInfo) do 
            DeleteItemCount(player:getIndex(), req.ItemIndex, req.Level, req.Quantity) 
        end
    end

    -- Consumo de Resets y Coins (Si está configurado para remover)
    if QUEST_SYSTEM_MAPS_REMOVE_RESETS == 1 and (questInfo.Reset or 0) > 0 then player:setReset(player:getReset() - questInfo.Reset) end
    if QUEST_SYSTEM_MAPS_REMOVE_MRESETS == 1 and (questInfo.MReset or 0) > 0 then player:setMasterReset(player:getMasterReset() - questInfo.MReset) end
    
    local c1r, c2r, c3r, c4r = 0, 0, 0, 0
    if QUEST_SYSTEM_MAPS_REMOVE_COIN1 == 1 and (questInfo.Coin1 or 0) > 0 then c1r = questInfo.Coin1 end
    if (c1r+c2r+c3r+c4r) > 0 then RemoveCoins(player:getIndex(), c1r, c2r, c3r, c4r) end

    -- 5. ENTREGA DE RECOMPENSAS
    --SendMessage("--------------------------------------------------", player:getIndex(), 1)
    SendMessage(string.format(" [Quest System] ¡%s Finalizada!", questInfo.QuestName or "Misión"), player:getIndex(), 1)

    -- [ Items Reward ]
    local rewardItems = findInTable(QUEST_SYSTEM_MAPS_REWARD_ITEMS)
    if rewardItems then
        for _, it in pairs(rewardItems) do
            if it.Class == -1 or it.Class == player:getClass() then
                local count = it.Count or 1
                for i = 1, count do
                    if QUEST_SYSTEM_MAPS_USE_GREMORY == 1 then
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
    local rewardCoins = findInTable(QUEST_SYSTEM_MAPS_REWARD_COINS)
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
	local expR = findInTable(QUEST_SYSTEM_MAPS_REWARD_EXP)
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
    local ptsR = findInTable(QUEST_SYSTEM_MAPS_POINTS_REWARDS)
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
	QuestSystemByMaps.SafeCreateAsync('FinalizeQuest_'..acc, q_update, -1, 0)
	
	-- [MOLDE RAM] Aseguramos que las estructuras existan
	QuestSystemByMaps.CompletedToday[acc] = QuestSystemByMaps.CompletedToday[acc] or {}
	QuestSystemByMaps.CompletedToday[acc][npc_id] = QuestSystemByMaps.CompletedToday[acc][npc_id] or {}
	QuestSystemByMaps.CompletedToday[acc][npc_id][currentMap] = QuestSystemByMaps.CompletedToday[acc][npc_id][currentMap] or {}
	
	QuestSystemByMaps.CompletedHistory[acc] = QuestSystemByMaps.CompletedHistory[acc] or {}
	
	-- 1. RAM: Registro de completado hoy (Para las Diarias)
	QuestSystemByMaps.CompletedToday[acc][npc_id][currentMap][tostring(qid)] = today
	
	-- 2. RAM: Registro de Historial Eterno (ESTA ES LA QUE FALTA PARA LAS ONE-TIME)
	-- Al agregarla acá, OpenQuest la verá inmediatamente sin necesidad de reloguear.
	QuestSystemByMaps.CompletedHistory[acc][tostring(qid)] = { isToday = true }
	
	-- 3. RAM: Limpieza de la misión de la lista de activos
	if QuestSystemByMaps.PlayerActive[acc] and QuestSystemByMaps.PlayerActive[acc][npc_id] then
		QuestSystemByMaps.PlayerActive[acc][npc_id][tostring(qid)] = nil
	end
	
	-- CACHÉ: Sincronización final con el jugador
	player:setCacheInt("QuestSystemByMapsStatus", 2)
	player:setCacheInt("QuestSystemByMapsFinished", 1)
	player:setCacheInt("QuestSystemByMapsCanCollect", 0)
	player:setCacheInt("QuestSystemByMapsStarted", 0)
	player:setCacheInt("QuestSystemByMapsIdentification", 0)
	for i = 1, 9 do player:setCacheInt(string.format('QuestSystemByMapsKillsMonster%d', i), 0) end
	
	-- Sincronizar con el cliente
	RefreshCharacter(player:getIndex())
	QuestSystemByMaps.SendHUDUpdate(player, npc_id)
	
	LogAddC(2, string.format("QuestSystemByMaps.GetReward: %s [MAP:%d] cobró recompensa satisfactoriamente y RAM actualizada.", acc, currentMap))
end

-- NpcTalk: open UI when clicking NPC
function QuestSystemByMaps.NpcTalk(NpcIndex, PlayerIndex)
    local npc = User.new(NpcIndex)
    local player = User.new(PlayerIndex)
    if not npc or not player then return 0 end

    local npcClass = tonumber(npc:getClass())
    local mapId = tonumber(player:getMapNumber())
    local acc = player:getAccountID()
    local today = os.date("%Y-%m-%d")

    if QUEST_SYSTEM_MAPS_ALLOWED_NPCS[npcClass] or npcClass == QUEST_SYSTEM_MAPS_NPC_CLASS then
        player:setCacheInt("QuestSystemByMapsNPC", npcClass)
        QuestSystemByMaps.SendLoadingPacket(player, npcClass)

        local tAcc, tMap, tNpc = acc, mapId, npcClass

        Timer.TimeOut(1.2, function()
            local p = User.new(PlayerIndex)
            if not p or p:getConnected() < 3 then return end

            QuestSystemByMaps.IsDataLoaded[tAcc] = true 

            -- 1. Buscamos solo misiones DIARIAS terminadas hoy
            local showCompletedWindow = false
            if QuestSystemByMaps.CompletedToday[tAcc] and 
               QuestSystemByMaps.CompletedToday[tAcc][tNpc] and 
               QuestSystemByMaps.CompletedToday[tAcc][tNpc][tMap] then
               
                for qid, date_ram in pairs(QuestSystemByMaps.CompletedToday[tAcc][tNpc][tMap]) do
                    if date_ram == today then
                        local config = QuestSystemByMaps.GetQuestIdentification(tonumber(qid))
                        -- REGLA: Cartel de éxito solo para DIARIAS
                        if config and config.IsOneTime == 0 then
                            QuestSystemByMaps.SendOpenContinue(p, tNpc, tonumber(qid), tMap)
                            showCompletedWindow = true
                            break
                        end
                    end
                end
            end

            -- 2. Si no es una diaria hecha hoy, mostramos la lista (incluyendo la siguiente One-Time)
            if not showCompletedWindow then
                QuestSystemByMaps.OpenQuest(p, tNpc)
            end
        end)
        return 1
    end
    return 0
end

-- Protocol: packet handler
function QuestSystemByMaps.Protocol(aIndex, Packet, PacketName)
    if Packet ~= QUEST_SYSTEM_MAPS_PACKET then return end
    
    local player = User.new(aIndex)
    if not player then return end

    local pName = player:getName()

    -- [LOG DE ENTRADA] Detectar cualquier paquete que llegue de este sistema
    -- LogAddC(2, string.format("QuestSystemByMaps: Packet Recibido [%s] de %s", PacketName, pName))

    -- [1] ABRIR NPC / SOLICITAR LISTA
    if string.format("%s_%s", QUEST_SYSTEM_MAPS_PACKET_OPEN_NAME, pName) == PacketName then
        local mapId_enviado = GetDwordPacket(PacketName, -1) or 0 
        local npc_id = player:getCacheInt("QuestSystemByMapsNPC") or 0
        
        LogAddC(2, string.format("QuestSystemByMaps: [OPEN] Jugador %s solicita lista NPC %d (Mapa: %d)", pName, npc_id, mapId_enviado))
        
        ClearPacket(PacketName)
        QuestSystemByMaps.OpenQuest(player, npc_id)

    -- [2] DAR CLICK EN "ACEPTAR" (START)
    elseif string.format("%s_%s", QUEST_SYSTEM_MAPS_PACKET_START_NAME, pName) == PacketName then
        local questID = GetDwordPacket(PacketName, -1) or 0
        LogAddC(2, string.format("QuestSystemByMaps: [START] %s inició Quest ID %d", pName, questID))
        
        ClearPacket(PacketName)
        QuestSystemByMaps.StartQuest(player, questID)

    -- [3] DAR CLICK EN "COBRAR RECOMPENSA"
    elseif string.format("%s_%s", QUEST_SYSTEM_MAPS_PACKET_GET_REWARD_NAME, pName) == PacketName then
        LogAddC(2, string.format("QuestSystemByMaps: [REWARD] %s intenta cobrar recompensa", pName))
        ClearPacket(PacketName)
        QuestSystemByMaps.GetReward(player)

    -- [4] BOTON CONTINUAR / CERRAR
    elseif string.format("%s_%s", QUEST_SYSTEM_MAPS_PACKET_CONTINUE_QUEST_NAME, pName) == PacketName then
        local npc_id = player:getCacheInt("QuestSystemByMapsNPC")
        
        -- Solo forzamos el cierre del HUD si el jugador NO tiene una misión activa
        -- Esto evita que el HUD "pestañee" cuando abres el NPC estando terminada la misión
        local hasActive = false
        if QuestSystemByMaps.PlayerActive[acc] then
            for _, npcs in pairs(QuestSystemByMaps.PlayerActive[acc]) do
                for _, q_v in pairs(npcs) do
                    if tonumber(q_v.Status or 0) == 1 then hasActive = true; break end
                end
            end
        end

        if not hasActive then
            QuestSystemByMaps.ForceCloseClient(player, npc_id)
        end
        
        ClearPacket(PacketName)

    -- [NUEVO / REVISIÓN] SI TUVIERAS UN PAQUETE DE HUD UPDATE ENTRANDO
    -- Generalmente el HUD Update se envía del Servidor -> Cliente (no entra por aquí)
    -- Pero si tienes una respuesta del cliente, la verías así:
    elseif string.find(PacketName, "QuestSystemByMapsHUDUpdate") then
        LogAddC(2, string.format("QuestSystemByMaps: [HUD_SYNC] Recibido feedback de HUD de %s", pName))
    end
end

function QuestSystemByMaps.PlayerJoin(aIndex)
    if not aIndex or aIndex < 0 then return 0 end
    local player = User.new(aIndex)
    if not player then return 0 end
    local acc = player:getAccountID()
    
    QuestSystemByMaps.IsDataLoaded[acc] = false
    QuestSystemByMaps.LoadingAccounts = QuestSystemByMaps.LoadingAccounts or {}
    QuestSystemByMaps.LoadingAccounts[acc] = true
    QuestSystemByMaps.PlayerActive[acc] = {}
    QuestSystemByMaps.CompletedHistory[acc] = {} -- Cambiamos Today por History para ser más claros

    LogAddC(2, string.format("[QS] Iniciando carga empaquetada para %s...", acc))

    -- GeACT: Misión activa (Status 1) - Sin cambios
    local q_act = string.format(
        "SELECT AccountID, NPC, QuestIdentification, Status, MapNumber, CanCollect, Kills, " ..
        "KillsMonster1, KillsMonster2, KillsMonster3, KillsMonster4, KillsMonster5, " ..
        "KillsMonster6, KillsMonster7, KillsMonster8, KillsMonster9 " ..
        "FROM dbo.QUEST_SYSTEM_ACTIVE WHERE AccountID='%s' AND Status=1", acc
    )
    QuestSystemByMaps.SafeCreateAsync('GeACT_' .. acc, q_act, aIndex, 1)

    -- GeFIN: Misiones terminadas (Status 2). 
    -- Agregamos el DATEDIFF al paquete para saber si se hizo hoy (0) o antes (>0)
    local q_fin = string.format(
        "SELECT AccountID, STUFF((SELECT '|' + CAST(QuestIdentification AS VARCHAR) + ':' + CAST(NPC AS VARCHAR) + ':' + CAST(MapNumber AS VARCHAR) + ':' + CAST(DATEDIFF(day, CompletedDate, GETDATE()) AS VARCHAR) " ..
        "FROM QUEST_SYSTEM_ACTIVE WHERE AccountID = t.AccountID AND Status = 2 " ..
        "FOR XML PATH('')), 1, 1, '') as Pack " ..
        "FROM QUEST_SYSTEM_ACTIVE t WHERE AccountID = '%s' GROUP BY AccountID", acc
    )
    QuestSystemByMaps.SafeCreateAsync('GeFIN_' .. acc, q_fin, aIndex, 1)

    -- Timer de seguridad
    Timer.TimeOut(1.5, function()
        QuestSystemByMaps.IsDataLoaded[acc] = true
        QuestSystemByMaps.LoadingAccounts[acc] = nil
    end)

    return 1
end

function QuestSystemByMaps.OnPlayerLogout(aIndex)
    local player = User.new(aIndex)
    if player then
        local acc = player:getAccountID()
        if acc and acc ~= "" then
            
            -- [RESCATE CRÍTICO] Antes de borrar la RAM, salvamos los pendientes al SQL
            if QuestSystemByMaps.PendingCounters and QuestSystemByMaps.PendingCounters[acc] then
                for npc_id, quests in pairs(QuestSystemByMaps.PendingCounters[acc]) do
                    for qid_str, data in pairs(quests) do
                        local mid = 0
                        -- Obtenemos el mapa real de la misión activa
                        if QuestSystemByMaps.PlayerActive[acc] and QuestSystemByMaps.PlayerActive[acc][npc_id] and QuestSystemByMaps.PlayerActive[acc][npc_id][qid_str] then
                            mid = QuestSystemByMaps.PlayerActive[acc][npc_id][qid_str].MapNumber or 0
                        end
                        QuestSystemByMaps.FlushPending(acc, npc_id, tonumber(qid_str), mid)
                    end
                end
            end

            -- Limpieza de RAM
            QuestSystemByMaps.PlayerActive[acc] = nil
            QuestSystemByMaps.LoadingAccounts[acc] = nil
            QuestSystemByMaps.IsDataLoaded[acc] = nil
            QuestSystemByMaps.PendingCounters[acc] = nil
            
            -- Limpieza de Caché C++
            player:clearCacheInt("QuestSystemByMapsIdentification")
            player:clearCacheInt("QuestSystemByMapsNPC")
            player:clearCacheInt("QuestSystemByMapsStarted")
            player:clearCacheInt("QuestSystemByMapsStatus")
            player:clearCacheInt("QuestSystemByMapsCanCollect")
            for i = 1, 9 do player:clearCacheInt("QuestSystemByMapsKillsMonster"..i) end
            
            LogAddC(2, string.format("QuestSystemByMaps: Datos salvados y sesión cerrada para %s", acc))
        end
    end
end

function QuestSystemByMaps.IsQuestFullyCompleted(player)
    local qid = player:getCacheInt("QuestSystemByMapsIdentification") or 0
    if qid <= 0 then return false end

    local npc_id = player:getCacheInt("QuestSystemByMapsNPC") or 0
    local map_id = player:getMapNumber()
    local key = string.format("%d_%d_%d", npc_id, map_id, qid)

    -- 1. Validar Monstruos (¿Están todos los grupos en su cantidad?)
    local monsterList = QUEST_SYSTEM_MAPS_REQUIREMENTS_MONSTER[key] or QUEST_SYSTEM_MAPS_REQUIREMENTS_MONSTER[qid]
    if monsterList then
        for idx, mon in ipairs(monsterList) do
            local curKills = player:getCacheInt(string.format("QuestSystemByMapsKillsMonster%d", idx)) or 0
            if curKills < (mon.Quantity or 0) then return false end
        end
    end

    -- 2. Validar Ítems (¿Están todos en la mochila?)
    local itemReqList = QUEST_SYSTEM_MAPS_REQUIREMENTS_ITEMS[key] or QUEST_SYSTEM_MAPS_REQUIREMENTS_ITEMS[qid]
    if itemReqList then
        local pInv = Inventory.new(player:getIndex())
        for idx, it in ipairs(itemReqList) do
            local count = 0
            for i = 12, 203 do
                if pInv:isItem(i) ~= 0 and pInv:getIndex(i) == it.ItemIndex then
                    if it.Level == -1 or pInv:getLevel(i) == it.Level then
                        -- Contamos durabilidad si es apilable (Jewels), sino 1
                        local dur = pInv:getDurability(i)
                        count = count + (dur > 0 and it.ItemIndex >= 7168 and dur or 1)
                    end
                end
            end
            if count < (it.Quantity or 1) then return false end
        end
    end

    return true
end

function QuestSystemByMaps.PlayerHUDTimer(aIndex)
    local player = User.new(aIndex)
    if not player or player:getConnected() < 3 then return end

    local qid = player:getCacheInt("QuestSystemByMapsIdentification") or 0
    
    if qid > 0 then
        local npc_id = player:getCacheInt("QuestSystemByMapsNPC") or 0
        
        -- Sincronizamos el HUD
        QuestSystemByMaps.SendHUDUpdate(player, npc_id)

        -- Verificamos si pasó de 0 a 1 por recoger items
        local status = player:getCacheInt("QuestSystemByMapsCanCollect") or 0
        
        if status == 0 and QuestSystemByMaps.IsQuestFullyCompleted(player) then
            player:setCacheInt("QuestSystemByMapsCanCollect", 1)

            -- [ SOLUCIÓN AQUÍ ] Actualizamos la RAM (pEntry) para que el NPC lo sepa de inmediato
            local acc = player:getAccountID()
            local q_s = tostring(qid)
            local pEntry = QuestSystemByMaps.PlayerActive and QuestSystemByMaps.PlayerActive[acc] and QuestSystemByMaps.PlayerActive[acc][npc_id] and QuestSystemByMaps.PlayerActive[acc][npc_id][q_s]
            
            if pEntry then 
                pEntry.CanCollect = 1 
            end
            -------------------------------------------------------------------------

            -- Notificación visual (Cartel "COMPLETED!")
            local pName = string.format("QuestGoalMet_%s", player:getName())
            CreatePacket(pName, QUEST_SYSTEM_MAPS_PACKET)
            SetDwordPacket(pName, tonumber(qid) or 0)
            SendPacket(pName, aIndex)
            ClearPacket(pName)

            -- Sincronizamos DB ByMaps
            local map_id = player:getMapNumber()
            local queryT = string.format(
                "UPDATE QUEST_SYSTEM_MAPS_ACTIVE SET CanCollect = 1 WHERE AccountID='%s' AND QuestIdentification=%d AND MapNumber=%d",
                acc, qid, map_id)
            QuestSystemByMaps.SafeCreateAsync('CanQTimerByMaps', queryT, -1, 0)

            SendMessage("¡Objetivos listos! Ve por tu recompensa.", aIndex, 1)
        end
    end

    Timer.TimeOut(1.0, function() 
        QuestSystemByMaps.PlayerHUDTimer(aIndex) 
    end)
end

-- Init: register hooks
function QuestSystemByMaps.Init()
    LogAddC(2, "QuestSystemByMaps: Iniciando sistema...")
    
    if QUEST_SYSTEM_MAPS_SWITCH ~= 1 then
        LogAddC(2, "QuestSystemByMaps: Switch desactivado.")
        return
    end

    -- Helper interno para registros seguros
    local function safe_register(funcRegister, cb)
        if not funcRegister then return end
        funcRegister(function(...)
            local ok, res = pcall(cb, ...)
            if not ok then LogAddC(2, "QuestSystemByMaps Error: " .. tostring(res)) end
            return res
        end)
    end

    -- Registro de Funciones Core
    safe_register(GameServerFunctions.GameServerProtocol, QuestSystemByMaps.Protocol)
    safe_register(GameServerFunctions.MonsterDie, QuestSystemByMaps.MonsterDie)
    safe_register(GameServerFunctions.QueryAsyncProcess, QuestSystemByMaps.QueryAsyncProcess)
    safe_register(GameServerFunctions.NpcTalk, QuestSystemByMaps.NpcTalk)
    safe_register(GameServerFunctions.PlayerLogout, QuestSystemByMaps.OnPlayerLogout)

    -- Registro de entrada de personaje (Carga datos + Inicia Reloj HUD)
    safe_register(GameServerFunctions.EnterCharacter, function(aIndex)
        QuestSystemByMaps.PlayerJoin(aIndex)
        QuestSystemByMaps.PlayerHUDTimer(aIndex)
    end)

    LogAddC(2, "QuestSystemByMaps: Hooks y Sincronizador HUD listos.")

    -- [ ESCUDO DE REINICIO ]
    -- Si recargás el script con gente online, esto les activa el HUD inmediatamente
    if type(gObjIsConnectedGP) == "function" then
        local count = 0
        for i = 0, 12000 do -- Ajustá el rango según tu servidor
            if gObjIsConnectedGP(i) ~= 0 then
                QuestSystemByMaps.PlayerJoin(i)
                QuestSystemByMaps.PlayerHUDTimer(i) -- Iniciamos su reloj personal
                count = count + 1
            end
        end
        if count > 0 then
            LogAddC(2, string.format("QuestSystemByMaps: [Reload Shield] %d jugadores sincronizados.", count))
        end
    end
end


-- Compatibility shims
function QuestSystemByMaps.OpenContinueQuest(player)
    if type(player) == "number" then player = User.new(player) end
    if not player then return end
    local packetString = string.format("%s_%s", QUEST_SYSTEM_MAPS_PACKET_CONTINUE_QUEST_NAME, player:getName())
    CreatePacket(packetString, QUEST_SYSTEM_MAPS_PACKET)
    SendPacket(packetString, player:getIndex())
    ClearPacket(packetString)
end

function QuestSystemByMaps.AbandonQuest(player)
    if type(player) == "number" then player = User.new(player) end
    if not player then return end

    local acc = player:getAccountID()
    local npc_id = player:getCacheInt("QuestSystemByMapsNPC") or 0
    local questID = player:getCacheInt("QuestSystemByMapsIdentification") or 0
    local mapId = player:getMapNumber() -- [NUEVO] Obtener mapa actual

    -- 1. Limpiar Caché del Personaje (C++)
    player:clearCacheInt("QuestSystemByMapsIdentification")
    player:clearCacheInt("QuestSystemByMapsStarted")
    player:clearCacheInt("QuestSystemByMapsCanCollect")
    player:clearCacheInt("QuestSystemByMapsKills")
    for i = 1, 9 do 
        player:clearCacheInt(string.format("QuestSystemByMapsKillsMonster%d", i)) 
    end

    -- 2. Actualizar Base de Datos (Con MapNumber)
    if acc and questID and questID > 0 then
        -- [ACTUALIZADO] Añadimos MapNumber al WHERE para ser precisos
        local where = string.format("AccountID='%s' AND NPC=%d AND QuestIdentification=%d AND MapNumber=%d", 
            acc, npc_id, questID, mapId)
        
        -- En lugar de solo UPDATE, podrías usar un DELETE si prefieres que la misión desaparezca, 
        -- pero el UPDATE a 0 está bien si quieres mantener el registro.
        local q = string.format("UPDATE dbo.QUEST_SYSTEM_ACTIVE SET Finished = 0, Kills = 0, KillsMonster1=0,KillsMonster2=0,KillsMonster3=0,KillsMonster4=0,KillsMonster5=0,KillsMonster6=0,KillsMonster7=0,KillsMonster8=0,KillsMonster9=0 WHERE %s", where)
        
        QuestSystemByMaps.SafeCreateAsync('AbandonQuest_'..acc..'_'..tostring(questID), q, -1, 1)

        -- 3. Limpiar Memoria RAM (Lua)
        if QuestSystemByMaps.PlayerActive[acc] and QuestSystemByMaps.PlayerActive[acc][npc_id] then
            QuestSystemByMaps.PlayerActive[acc][npc_id][tostring(questID)] = nil
            LogAddC(2, string.format("QuestSystemByMaps: %s abandonó quest %d en mapa %d (RAM limpia)", acc, questID, mapId))
        end
    end

    -- 4. Refrescar la ventana del NPC
    QuestSystemByMaps.OpenQuest(player, npc_id)
end

QuestSystemByMaps.LastCheckDate = os.date("%Y-%m-%d")

function QuestSystemByMaps.MidnightControl()
    local currentDate = os.date("%Y-%m-%d")
    
    -- Si la fecha cambió (pasó la medianoche)
    if currentDate ~= QuestSystemByMaps.LastCheckDate then
        LogAddC(2, "--------------------------------------------------")
        LogAddC(2, "[QS] CAMBIO DE DÍA DETECTADO. Reseteando misiones...")
        LogAddC(2, "--------------------------------------------------")
        
        -- 1. Limpiamos la RAM de misiones terminadas
        QuestSystemByMaps.CompletedToday = {}
        
        -- 2. Actualizamos la fecha de referencia
        QuestSystemByMaps.LastCheckDate = currentDate
        
        -- 3. (Opcional) Avisar a los jugadores online
        -- GlobalMessage("Las misiones diarias han sido reiniciadas.")
    end
end

-- Registramos el Timer para que corra cada 60 segundos
Timer.TimeOut(60, QuestSystemByMaps.MidnightControl, -1)

-- start
QuestSystemByMaps.Init()
