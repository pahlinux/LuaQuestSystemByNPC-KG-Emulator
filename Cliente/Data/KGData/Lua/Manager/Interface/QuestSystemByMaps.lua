---Quest System 1.0
-------------------
---INICIO CONFIG
-------------------
---IMPORTANTE: La Config debe ser igual en server y cliente.

QUEST_SYSTEM_MAPS_SWITCH = 1

QUEST_SYSTEM_MAPS_ONLY_ACCOUNT = 1 
QUEST_SYSTEM_MAPS_REMOVE_RESETS = 0
QUEST_SYSTEM_MAPS_REMOVE_MRESETS = 0
QUEST_SYSTEM_MAPS_REMOVE_COIN1 = 0
QUEST_SYSTEM_MAPS_REMOVE_COIN2 = 0
QUEST_SYSTEM_MAPS_REMOVE_COIN3 = 0
QUEST_SYSTEM_MAPS_REMOVE_COIN4 = 0

QUEST_SYSTEM_MAPS_USE_GREMORY = 0
QUEST_SYSTEM_MAPS_SPACE_INVENTORY = 50

-- Packets
QUEST_SYSTEM_MAPS_PACKET = 0x06
QUEST_SYSTEM_MAPS_PACKET_OPEN_NAME = 'QuestSystemByMapsOpen'
QUEST_SYSTEM_MAPS_HUD_UPDATE_NAME = 'QuestSystemByMapsHUDUpdate'
QUEST_SYSTEM_MAPS_PACKET_START_NAME = 'QuestSystemByMapsStartQuest'
QUEST_SYSTEM_MAPS_PACKET_GET_REWARD_NAME = 'QuestSystemByMapsGetReward'
QUEST_SYSTEM_MAPS_PACKET_CONTINUE_QUEST_NAME = 'QuestSystemByMapsContinueQuest'
QUEST_SYSTEM_MAPS_PACKET_ABANDON_NAME = 'QuestSystemByMapsAbandon'
QUEST_DEBUG_MODE = false -- Cambiá a true cuando quieras ver los logs

-- Lista de NPCs permitidos para abrir el Quest System
-- Puedes añadir todos los que quieras: { [748] = true, [746] = true, [500] = true }
QUEST_SYSTEM_MAPS_ALLOWED_NPCS = { 
    [748] = true,
	[741] = true,	
}
-- Por si acaso, definimos esta para evitar errores de nil
QUEST_SYSTEM_MAPS_NPC_CLASS = 0
---------------------------------------------------------
-- [NUEVO] ESTRUCTURA POR MAPA
---------------------------------------------------------
-- Usaremos QUEST_SYSTEM_BY_MAP[MapID] QuestIdentidication debe cambiar por cada mapa (ej: 1-99 para lorencia 100-199 para Dungeon).
-- Agregamos IsOneTime = 0 (Para quest Diarias) IsOneTime = 1 (Para Quest por unica ves) Las Quest diarias aparecen en Verde y las IsOnTime en naranja.
QUEST_SYSTEM_BY_MAP = {}

QUEST_SYSTEM_BY_MAP[0] = {
    { QuestIdentification = 1, QuestName = 'Kill Spider on Fire!', IsOneTime = 1, Level = 20, Reset = 0, MReset = 0, Zen = 0, Coin1 = 0, Coin2 = 0, Coin3 = 0, Coin4 = 0,  Vip = 0, Kills = 0, Validity = '01/06/2036' },
	{ QuestIdentification = 2, QuestName = 'Kill Budge Dragon on Fire!', IsOneTime = 1, Level = 30, Reset = 0, MReset = 0, Zen = 0, Coin1 = 0, Coin2 = 0, Coin3 = 0, Coin4 = 0,  Vip = 0, Kills = 0, Validity = '01/06/2036' },
	{ QuestIdentification = 3, QuestName = 'Kill Skeleton on Fire!', IsOneTime = 1, Level = 50, Reset = 0, MReset = 0, Zen = 0, Coin1 = 0, Coin2 = 0, Coin3 = 0, Coin4 = 0,  Vip = 0, Kills = 0, Validity = '01/06/2036' },
	{ QuestIdentification = 50, QuestName = 'Kill Golden Budge Dragon!', IsOneTime = 0, Level = 50, Reset = 0, MReset = 0, Zen = 0, Coin1 = 0, Coin2 = 0, Coin3 = 0, Coin4 = 0,  Vip = 0, Kills = 0, Validity = '01/06/2036' },

}

-- MAPA 1: Dungeon (Misiones que el NPC de Quest en Dungeon)
QUEST_SYSTEM_BY_MAP[1] = {
    { QuestIdentification = 200, QuestName = 'Kill Monster Dungeon', IsOneTime = 0, Level = 220, Reset = 0, MReset = 0, Zen = 0, Coin1 = 0, Coin2 = 0, Coin3 = 0, Coin4 = 0,  Vip = 0, Kills = 0, Validity = '01/06/2036' },
}

-- MAPA 2: DEVIAS (Misiones que el NPC de Quest en Devias)
QUEST_SYSTEM_BY_MAP[2] = {
    { QuestIdentification = 100, QuestName = 'Kill Monster Devias Ruins', IsOneTime = 0, Level = 220, Reset = 0, MReset = 0, Zen = 0, Coin1 = 0, Coin2 = 0, Coin3 = 0, Coin4 = 0,  Vip = 0, Kills = 0, Validity = '01/06/2036' },
}

-- MAPA 37: KANTURU (Misiones que dará cualquier NPC de Quest en Kanturu)
QUEST_SYSTEM_BY_MAP[37] = {
    { QuestIdentification = 300, QuestName = 'Kill Monster Kanturu', IsOneTime = 0, Level = 220, Reset = 0, MReset = 0, Zen = 0, Coin1 = 0, Coin2 = 0, Coin3 = 0, Coin4 = 0, Vip = 0, Kills = 0, Validity = '01/06/2036' },
}
-- MAPA 84: ARKANIA (Mision dentro de Arkania)
QUEST_SYSTEM_BY_MAP[84] = {
    { QuestIdentification = 800, QuestName = 'Survival Arkania Quest', IsOneTime = 0, Level = 220, Reset = 0, MReset = 0, Zen = 0, Coin1 = 0, Coin2 = 0, Coin3 = 0, Coin4 = 0, Vip = 0, Kills = 0, Validity = '01/06/2036' },
}
-- MAPA 40: Silent (Mision dentro del evento Silent)
QUEST_SYSTEM_BY_MAP[40] = {
    { QuestIdentification = 400, QuestName = 'Survival Silent Quest', IsOneTime = 0, Level = 220, Reset = 0, MReset = 0, Zen = 0, Coin1 = 0, Coin2 = 0, Coin3 = 0, Coin4 = 0, Vip = 0, Kills = 0, Validity = '01/06/2036' },
}
---------------------------------------------------------
-- COMPATIBILIDAD Y LLAVES
---------------------------------------------------------
-- Mantenemos QKey pero ahora la lógica del script la usará con MapID en lugar de NPC
if QKey == nil then
    function QKey(npc_id, map_id, qid) 
        -- Genera una llave única: "748_2_100"
        return string.format("%d_%d_%d", 
            tonumber(npc_id) or 0, 
            tonumber(map_id) or 0, 
            tonumber(qid) or 0) 
    end
end

-- Tablas de Requisitos y Recompensas
QUEST_SYSTEM_MAPS_REQUIREMENTS_ITEMS = {}
QUEST_SYSTEM_MAPS_REQUIREMENTS_MONSTER = {}
QUEST_SYSTEM_MAPS_REWARD_ITEMS = {}
QUEST_SYSTEM_MAPS_REWARD_COINS = {}
QUEST_SYSTEM_MAPS_REWARD_BUFF = {}
QUEST_SYSTEM_MAPS_REWARD_EXP = {}
QUEST_SYSTEM_MAPS_POINTS_REWARDS = {}

------------------------------------------------------------
-- CONFIGURACIÓN MAPA 0 (Lorencia) - Quest 1 (One-Time)
-- Importane: Si hay mas de una mision por mapa el KEY 
-- debe ir cambiado como se muestra en las quest de Lorencia
------------------------------------------------------------
local KEY_LR1 = QKey(748, 0, 1)

QUEST_SYSTEM_MAPS_REQUIREMENTS_MONSTER[ KEY_LR1 ] = {
    { MonsterIndex = 3, Quantity = 10, MonsterName = 'Spider' },
}
--------------------------------------------------------------------------------
								--Reward--
--CoinIdentification: 1 = WcoinP, 2 = WcoinC, 3 = GlobinPoint, 4 = Ruud, 5 = Zen
--Exp Identification: 1 = Normal Exp, 2 = MasterExp 3=LVL-UP 4=Master LVL-UP
-- EffectTime = time in seconds Example EffectID = 29 Seal Ascencion
--------------------------------------------------------------------------------
QUEST_SYSTEM_MAPS_REWARD_COINS[ KEY_LR1 ] = {
    { CoinName = 'Zen', CoinAmount = 10000000, CoinIdentification = 5 },
}
QUEST_SYSTEM_MAPS_REWARD_EXP[ KEY_LR1 ] = {
    { ExpId = 3, Amount = 1, ExpName = "LVL UP" },
}
---------------------------------------------------------
-- CONFIGURACIÓN MAPA 0 (Lorencia) - Quest 2 (One-Time)
---------------------------------------------------------
local KEY_LR2 = QKey(748, 0, 2)

QUEST_SYSTEM_MAPS_REQUIREMENTS_MONSTER[ KEY_LR2 ] = {
    { MonsterIndex = 2, Quantity = 10, MonsterName = 'Budge Dragon' },
}
--------------------------------------------------------------------------------
								--Reward--
--------------------------------------------------------------------------------
QUEST_SYSTEM_MAPS_REWARD_COINS[ KEY_LR2 ] = {
    { CoinName = 'Zen', CoinAmount = 20000000, CoinIdentification = 5 },
}
QUEST_SYSTEM_MAPS_REWARD_EXP[ KEY_LR2 ] = {
    { ExpId = 3, Amount = 1, ExpName = "LVL UP" },
}
---------------------------------------------------------
-- CONFIGURACIÓN MAPA 0 (Lorencia) - Quest 3 (One-Time)
---------------------------------------------------------
local KEY_LR3 = QKey(748, 0, 3)

QUEST_SYSTEM_MAPS_REQUIREMENTS_MONSTER[ KEY_LR3 ] = {
    { MonsterIndex = 14, Quantity = 10, MonsterName = 'Skeleton' },
}
--------------------------------------------------------------------------------
								--Reward--
--------------------------------------------------------------------------------
QUEST_SYSTEM_MAPS_REWARD_COINS[ KEY_LR3 ] = {
    { CoinName = 'Zen', CoinAmount = 50000000, CoinIdentification = 5 },
}
QUEST_SYSTEM_MAPS_REWARD_EXP[ KEY_LR3 ] = {
    { ExpId = 3, Amount = 1, ExpName = "LVL UP" },
}
---------------------------------------------------------
-- CONFIGURACIÓN MAPA 0 (Lorencia) - Quest 50 (One-Time)
---------------------------------------------------------
local KEY_LR50 = QKey(748, 0, 50)

QUEST_SYSTEM_MAPS_REQUIREMENTS_MONSTER[ KEY_LR50 ] = {
    { MonsterIndex = 43, Quantity = 1, MonsterName = 'Golden Budge Dragon' },
}
--------------------------------------------------------------------------------
								--Reward--
--------------------------------------------------------------------------------
QUEST_SYSTEM_MAPS_REWARD_ITEMS[ KEY_LR50 ] = {
    { ItemIndex = GET_ITEM(12,30), Level = 0, Op1=0, Op2=0, Life=0, Exc=0, Ancient=0, JoH=0, SockCount=0, ItemTime=0, DaysExpire=0, Flag=0, Name='Jewel Of Chaos x1', Count=1, Class = -1 }
}
QUEST_SYSTEM_MAPS_REWARD_COINS[ KEY_LR50 ] = {
    { CoinName = 'Zen', CoinAmount = 50000000, CoinIdentification = 5 },
}
QUEST_SYSTEM_MAPS_REWARD_EXP[ KEY_LR50 ] = {
    { ExpId = 3, Amount = 1, ExpName = "LVL UP" },
}

---------------------------------------------------------
-- CONFIGURACIÓN MAPA 1 (DUNGEON) - Quest 200
---------------------------------------------------------
local KEY_DUN = QKey(748, 1, 200)

QUEST_SYSTEM_MAPS_REQUIREMENTS_MONSTER[ KEY_DUN ] = {
    { MonsterIndex = 14, Quantity = 10, MonsterName = 'Skeleton' },
}
QUEST_SYSTEM_MAPS_REQUIREMENTS_ITEMS[ KEY_DUN ] = {
    { ItemIndex = GET_ITEM(14, 113), Level = -1, Luck = -1, Skill = -1, Quantity = 5 },
}
QUEST_SYSTEM_MAPS_REWARD_COINS[ KEY_DUN ] = {
    { CoinName = 'Ruud', CoinAmount = 150, CoinIdentification = 4 },
}
QUEST_SYSTEM_MAPS_REWARD_COINS[ KEY_DUN ] = {
    { CoinName = 'Zen', CoinAmount = 50000000, CoinIdentification = 5 },
}
---------------------------------------------------------
-- CONFIGURACIÓN MAPA 2 (DEVIAS) - Quest 100
---------------------------------------------------------
local KEY_DVS = QKey(748, 2, 100)

QUEST_SYSTEM_MAPS_REQUIREMENTS_MONSTER[ KEY_DVS ] = {
    { MonsterIndex = 562, Quantity = 10, MonsterName = 'Dark Mammoth' },
    { MonsterIndex = 563, Quantity = 10, MonsterName = 'Dark Giant' },
    { MonsterIndex = 564, Quantity = 10, MonsterName = 'Dark Coolutin' },
    { MonsterIndex = 565, Quantity = 10, MonsterName = 'Dark Iron Knight' },
}

QUEST_SYSTEM_MAPS_REWARD_COINS[ KEY_DVS ] = {
    { CoinName = 'Ruud', CoinAmount = 150, CoinIdentification = 4 },
}

QUEST_SYSTEM_MAPS_REWARD_ITEMS[ KEY_DVS ] = {
    { ItemIndex = GET_ITEM(12,15), Level = 0, Op1=0, Op2=0, Life=0, Exc=0, Ancient=0, JoH=0, SockCount=0, ItemTime=0, DaysExpire=0, Flag=0, Name='Jewel Of Chaos x1', Count=1, Class = -1 }
}

QUEST_SYSTEM_MAPS_REWARD_EXP[ KEY_DVS ] = {
    { ExpId = 3, Amount = 1, ExpName = "LVL UP" },
}

QUEST_SYSTEM_MAPS_REWARD_BUFF[ KEY_DVS ] = {
    { EffectID = 29, EffectTime = 3600, BuffName = 'Seal Ascencion' }
}

QUEST_SYSTEM_MAPS_POINTS_REWARDS[ KEY_DVS ] = {
    {PtsID = 1, Amount = 10, StatName = "Free Points"},
}

---------------------------------------------------------
-- CONFIGURACIÓN MAPA 37 (KANTURU) - Quest 300
---------------------------------------------------------
local KEY_KT = QKey(748, 37, 300)

QUEST_SYSTEM_MAPS_REQUIREMENTS_MONSTER[ KEY_KT ] = {
    { MonsterIndex = 353, Quantity = 5, MonsterName = 'Satyros' },
    { MonsterIndex = 354, Quantity = 5, MonsterName = 'Blade Hunter' },
    { MonsterIndex = 355, Quantity = 5, MonsterName = 'Kentauros' },
    { MonsterIndex = 356, Quantity = 5, MonsterName = 'Gigantis' },
	{ MonsterIndex = 350, Quantity = 5, MonsterName = 'Berserker' },
	{ MonsterIndex = 357, Quantity = 5, MonsterName = 'Genocider' },
}

QUEST_SYSTEM_MAPS_REWARD_COINS[ KEY_KT ] = {
    { CoinName = 'Ruud', CoinAmount = 100, CoinIdentification = 4 },
}

QUEST_SYSTEM_MAPS_REWARD_ITEMS[ KEY_KT ] = {
    { ItemIndex = GET_ITEM(14,13), Level = 0, Op1=0, Op2=0, Life=0, Exc=0, Ancient=0, JoH=0, SockCount=0, ItemTime=0, DaysExpire=0, Flag=0, Name='Jewel Of Bless x1', Count=1, Class = -1 },
}

QUEST_SYSTEM_MAPS_REWARD_EXP[ KEY_KT ] = {
    { ExpId = 3, Amount = 1, ExpName = "LVL UP" },
}

---------------------------------------------------------
-- CONFIGURACIÓN MAPA 84 (ARKANIA) - Quest 800 Master
---------------------------------------------------------
local KEY_ARK = QKey(748, 84, 800)

QUEST_SYSTEM_MAPS_REQUIREMENTS_MONSTER[ KEY_ARK ] = {
    { MonsterIndex = 820, Quantity = 1, MonsterName = 'Brave' },
    { MonsterIndex = 821, Quantity = 1, MonsterName = 'Lava Demon' },
    { MonsterIndex = 822, Quantity = 1, MonsterName = 'Lizard Men' },
    { MonsterIndex = 823, Quantity = 1, MonsterName = 'Red Centaurus' },
	{ MonsterIndex = 824, Quantity = 1, MonsterName = 'Mutant Golem' },
}

QUEST_SYSTEM_MAPS_REWARD_COINS[ KEY_ARK ] = {
    { CoinName = 'WCoins', CoinAmount = 100, CoinIdentification = 1 },
}

QUEST_SYSTEM_MAPS_REWARD_EXP[ KEY_ARK ] = {
    { ExpId = 4, Amount = 1, ExpName = "LVL UP" },
}
---------------------------------------------------------
-- CONFIGURACIÓN MAPA 40 (Silent) - Quest 400 Master
---------------------------------------------------------
local KEY_SIL = QKey(748, 40, 400)

QUEST_SYSTEM_MAPS_REQUIREMENTS_MONSTER[ KEY_SIL ] = {
    { MonsterIndex = 515, Quantity = 1, MonsterName = 'Grand Wizard' },
    { MonsterIndex = 836, Quantity = 1, MonsterName = 'Blue Centaurus' },
    { MonsterIndex = 835, Quantity = 1, MonsterName = 'Cerberus' },
    { MonsterIndex = 801, Quantity = 1, MonsterName = 'Abbadon' },
}

QUEST_SYSTEM_MAPS_REWARD_COINS[ KEY_SIL ] = {
    { CoinName = 'WCoins', CoinAmount = 100, CoinIdentification = 1 },
}

QUEST_SYSTEM_MAPS_REWARD_EXP[ KEY_SIL ] = {
    { ExpId = 3, Amount = 1, ExpName = "LVL UP" },
}
----------------
---FIN Config---
----------------

QUEST_SYSTEM_MAPS_VIP_NAME = {}

QUEST_SYSTEM_MAPS_VIP_NAME[0] = 'Free'
QUEST_SYSTEM_MAPS_VIP_NAME[1] = 'Vip Silver'
QUEST_SYSTEM_MAPS_VIP_NAME[2] = 'Vip Gold'
QUEST_SYSTEM_MAPS_VIP_NAME[3] = 'Vip Plantinum'

--Estos menjajes no tocarlos en el cliente son distintos.
QUEST_SYSTEM_MAPS_MESSAGES = {}

QUEST_SYSTEM_MAPS_MESSAGES['Por'] = {
[1] = 'Sistema de quest',
[2] = 'V�lida at� o dia: %s',
[3] = 'Voc� ainda n�o iniciou nenhuma quest',
[4] = 'Gostaria de iniciar a quest?',
[5] = 'Come�ar Quest',
[6] = 'Recolher recompensa',
[7] = 'Requisitos:',
[8] = '- %d Level',
[9] = '- %d Resets',
[10] = '- %d MResets',
[11] = '- %d Zen',
[12] = '- %d WcoinC',
[13] = '- %d WcoinP',
[14] = '- %d GlobinPoint',
[15] = '- %d Ruud',
[16] = '- %d Kills',
[17] = '- %s',
[18] = '- Matar %s (%d/%d)',
[19] = '- Obter %dx %s',
[20] = 'Pr�mios:',
[21] = 'A miss�o foi conclu�da!',
[22] = 'Continuar',
[23] = 'Fechar',
}

QUEST_SYSTEM_MAPS_MESSAGES['Eng'] = {
[1] = 'Quest system',
[2] = 'Valid until day: %s',
[3] = 'You havent started any quests yet',
[4] = 'Would you like to start the quest?',
[5] = 'Start Quest',
[6] = 'Collect reward',
[7] = 'Requirements:',
[8] = '-%d Level',
[9] = '-%d Resets',
[10] = '-%d MResets',
[11] = '-%d Zen',
[12] = '- %d WcoinC',
[13] = '- %d WcoinP',
[14] = '- %d GlobinPoint',
[15] = '- %d Ruud',
[16] = '-%d Kills',
[17] = '-%s',
[18] = '- Kill %s (%d/%d)',
[19] = '- Get %dx %s',
[20] = 'Awards:',
[21] = 'The mission has been completed!',
[22] = 'Continue',
[23] = 'Close',
}

QUEST_SYSTEM_MAPS_MESSAGES['Spn'] = {
[1] = 'Sistema de misiones',
[2] = 'V�lido hasta el d�a: %s',
[3] = 'A�n no has comenzado ninguna misi�n',
[4] = '�Te gustar�a comenzar la misi�n?',
[5] = 'Iniciar misi�n',
[6] = 'Recoger recompensa',
[7] = 'Requisitos:',
[8] = '- %d nivel',
[9] = '- %d reinicia',
[10] = '- %d MResets',
[11] = '- %d Zen',
[12] = '- %d WcoinC',
[13] = '- %d WcoinP',
[14] = '- %d GlobinPoint',
[15] = '- %d Ruud',
[16] = '- %d muertes',
[17] = '- %s',
[18] = '- Mata a %s (%d/%d)',
[19] = '- Obtener %dx %s',
[20] = 'Premios:',
[21] = '�La misi�n ha sido completada!',
[22] = 'Continuar',
[23] = 'Cerrar',
}


QuestSystemByMaps = {}

-- [TABLA DE NOMBRES - SOLO CLIENTE]
QuestSystemByMaps.MapNames = {
    [0] = "Lorencia",
    [1] = "Dungeon",
    [2] = "Devias",
    [3] = "Noria",
    [4] = "LostTower",
    [6] = "Arena",
    [7] = "Atlans",
    [8] = "Tarkan",
    [10] = "Icarus",
    [31] = "Land of Trials",
    [33] = "Aida",
    [37] = "Kanturu",
}

QuestSystemByMaps.OpenedByPlayer = 0
QuestSystemByMaps.AlwaysContinue = QuestSystemByMaps.AlwaysContinue or {}
local QuestSystemByMapsInfo = {}
local QuestSystemByMapsInfoMonsterKill = {}
local QuestSystemByMapsInfoItensCount = {}
local QuestSystemByMapsFinishedQuest = 0
local lastAccountName = "" -- Variable para rastrear el cambio de cuenta
local QuestSystemByMapsPlayerStats = {}
QuestSystemByMaps.ShowAbandonConfirm = false
QuestSystemByMaps.IsLoading = false
QuestSystemByMapsCanStart = false
local QuestSystemByMapsVisible = 0

QuestSystemByMaps.FinishAnim = {
    Active = false,
    StartTime = 0,
    QuestName = "",
    Duration = 10.0, -- Duración total en segundos
}
local function GetItemRealName(index)
    if not index or index <= 0 then return "Unknown Item" end
    
    local itemName = "Item " .. index -- Fallback por defecto
    
    -- Intentamos obtener el nombre real de la DLL
    if type(GetNameByIndex) == "function" then
        local name = GetNameByIndex(index)
        -- Si el nombre no es nil, ni vacío, ni la palabra genérica "Item"
        if name and name ~= "" and name ~= "Item" then
            return name
        end
    end
    
    -- Si falla GetNameByIndex, probamos con ItemNameGet (común en KG)
    if type(ItemNameGet) == "function" then
        local name = ItemNameGet(index)
        if name and name ~= "" then return name end
    end

    return itemName
end
-- Posición de la ventana principal (se autogestiona)
local m_Pos = { x = 0, y = 0 } 

-- Botón del HUD para abrir el sistema (mantenlo si lo usas)
local m_BtnQuest = { x = 610, y = 240, w = 25, h = 25}

local WinW = 250
local WinH = 270

function QuestSystemByMaps.GetCenterPos()
    local x = (640 / 2) - (WinW / 2) + ReturnWideScreenX()
    local y = (500 / 2) - (WinH / 2)
    return x, y
end

function QuestSystemByMaps.IsMouseOver()
    if QuestSystemByMapsVisible ~= 1 then return false end
    
    local x, y = QuestSystemByMaps.GetCenterPos()
    local MouseX, MouseY = MousePosX(), MousePosY()
    -- Usamos WinW y WinH que ya tienes definidos (250x270)
    
    return MouseX >= x and MouseX <= x + WinW and MouseY >= y and MouseY <= y + WinH
end

function QuestSystemByMaps.RenderLoading()
    local x, y = m_Pos.x, m_Pos.y
    local WinW, WinH = 250, 270

    -- Texto principal (Brillante)
    SetFontType(1)
    SetTextColor(255, 255, 100, 255) -- Amarillo
    RenderText3(x, y + (WinH / 2) - 10, "LOADING...", WinW, 3)

    -- Subtexto (Más suave)
    SetTextColor(150, 150, 150, 255)
    RenderText3(x, y + (WinH / 2) + 5, "Checking data status...", WinW, 3)
end

function QuestSystemByMaps.Render()
    -- IMPORTANTE: La animación va PRIMERO para que no la tape nada
    QuestSystemByMaps.RenderFinishNotification()

    -- Luego lo demás (Ventana principal de Quests)
    QuestSystemByMaps.RenderQuest()

    -- [ACÁ VA] Dibujamos la confirmación por encima de la ventana principal
    QuestSystemByMaps.RenderAbandonConfirm()

    -- Si la ventana está abierta, no limpiamos el blend todavía
    if QuestSystemByMapsVisible == 1 then return end

    if Utils.CheckWindow() then return end

    EnableAlphaTest()
    glColor4f(1.0, 1.0, 1.0, 1.0)
    DisableAlphaBlend()
end

function QuestSystemByMaps.RenderQuest()
    if QuestSystemByMapsVisible ~= 1
    then
        return
    end

    EnableAlphaTest()

    glColor4f(1.0, 1.0, 1.0, 1.0)
	
	QuestSystemByMaps.RenderFrame()
	QuestSystemByMaps.RenderTexts()
    DisableAlphaBlend()
end

function QuestSystemByMaps.RenderFrame()
    local x, y = QuestSystemByMaps.GetCenterPos()
    m_Pos.x, m_Pos.y = x, y 

    EnableAlphaTest(); EnableAlphaBlend(); SetBlend()
    
    -- 1. Fondo Oscuro Principal
    glColor4f(0.0, 0.0, 0.0, 0.85) -- 85% opacidad para que se vea apenas el juego de fondo
    DrawBar(x, y, WinW, WinH)
    
    -- 2. Marco perimetral (Reemplaza las imágenes 40024-40029)
    -- El color está en gris plomo (0.3, 0.3, 0.3). dorado (0.8, 0.7, 0.2)
    glColor4f(0.823, 0.411, 0.117, 1.0) 
    DrawBar(x - 1, y - 1, WinW + 2, 1)    -- Línea Superior
    DrawBar(x - 1, y + WinH, WinW + 2, 1) -- Línea Inferior
    DrawBar(x - 1, y, 1, WinH)            -- Línea Izquierda
    DrawBar(x + WinW, y, 1, WinH)         -- Línea Derecha
    EndDrawBar()
    
    glColor3f(1.0, 1.0, 1.0) -- Reseteamos color de brocha a blanco puro
    
    -- Botón de salida (X)
    local closeX, closeY = x + WinW - 25, y + 10
    SetFontType(1) 
    SetTextBg(0, 0, 0, 0) -- Aseguramos fondo transparente para la X
    if MousePosX() >= closeX and MousePosX() <= closeX + 15 and MousePosY() >= closeY and MousePosY() <= closeY + 15 then
        SetTextColor(255, 50, 50, 255)
    else
        SetTextColor(200, 200, 200, 255)
    end
    RenderText3(closeX, closeY, "❎", 15, 3)

    if QuestSystemByMaps.IsLoading then DisableAlphaBlend(); return end

    -- LÓGICA DE BOTÓN DE ACCIÓN
    local isStarted = (QuestSystemByMapsInfo and tonumber(QuestSystemByMapsInfo.Started or 0) == 1)
    local canCollectState = (QuestSystemByMapsInfo and tonumber(QuestSystemByMapsInfo.CanCollectLocal or 0)) or 0
    local hasActiveID = (QuestSystemByMaps.CurrentQuestID or 0) > 0

    if QuestSystemByMaps.OpenedByPlayer == 1 or canCollectState == 2 or QuestSystemByMapsFinishedQuest == 1 or hasActiveID then
        local btnText = ""
        local subText = "" 
        local isClickable = true

        if QuestSystemByMapsFinishedQuest == 1 then
            btnText = "CONTINUAR"
        elseif canCollectState == 2 then
            btnText = "MISIÓN EN CURSO"
            local qMap = QuestSystemByMaps.CurrentMapID or 0
            local mapName = QuestSystemByMaps.MapNames[qMap] or ("Mapa " .. qMap)
            subText = "(Vuelve a " .. mapName .. ")"
            isClickable = false
        elseif canCollectState == 1 then
            btnText = "COLLECT REWARD"
        elseif isStarted then
            btnText = "INCOMPLETO"; isClickable = false
        else
            btnText = "START"
            if not QuestSystemByMapsCanStart then
                isClickable = false
            end
        end

        local actionX, actionY = x, y + WinH - 32
        local textY = (subText ~= "") and (actionY - 6) or actionY

        local isHoverAction = MousePosX() >= x + 20 and MousePosX() <= x + WinW - 20 and MousePosY() >= actionY - 5 and MousePosY() <= actionY + 15
        
        if not isClickable then 
            SetTextColor(80, 80, 80, 255) 
        elseif isHoverAction then 
            SetTextColor(255, 255, 100, 255) 
        else 
            SetTextColor(0, 250, 154, 255) 
        end

        -- Forzamos al motor a limpiar el fondo antes de renderizar las etiquetas del botón
        SetFontType(1)
        SetTextBg(0, 0, 0, 0) 
        
        -- Renderizamos el texto principal
        RenderText3(actionX, textY, btnText, WinW, 3)

        -- Renderizamos la segunda línea solo si existe (El mapa)
        if subText ~= "" then
            SetTextColor(255, 140, 0, 255) 
            RenderText3(actionX, textY + 12, subText, WinW, 3)
        end
    end

    glColor3f(1.0, 1.0, 1.0)
end

function QuestSystemByMaps.RenderButtom(x, y, width, height, text)
    -- Detectamos si el mouse está sobre el botón
    local isHover = MousePosX() >= x and MousePosX() <= x + width and MousePosY() >= y and MousePosY() <= y + height

    if isHover then
        -- Textura de iluminación (Hover)
        RenderImage2(31326, x, y, width, height, 0, 0.2264566, 1.0, 0.2245212, 1, 1, 1.0)
        SetTextColor(255, 255, 160, 255) -- Un tono amarillento para resaltar el texto
    else
        -- Textura Normal
        RenderImage2(31326, x, y, width, height, 0, 0, 1.0, 0.2245212, 1, 1, 1.0)
        SetTextColor(225, 225, 225, 255) -- Blanco estándar
    end
    
    SetFontType(1)
    SetTextBg(0, 0, 0, 0)
    
    -- Centrado dinámico:
    -- Usamos el 'width' total del botón y el modo '3' para que el motor lo centre solo.
    -- El ajuste 'y + 5' (o height/2 - 5) asegura que quede centrado verticalmente.
    RenderText3(x, y + 5, text, width, 3)
end

function QuestSystemByMaps.RenderTexts()
    EnableAlphaTest(); SetFontType(1); SetTextBg(0, 0, 0, 0)
    local x, y = m_Pos.x, m_Pos.y
    local WinW = 250

    -- Título Magenta (Siempre se ve)
    SetTextColor(255, 0, 255, 255)
    RenderText3(x, y + 11, QUEST_SYSTEM_MAPS_MESSAGES[GetLanguage()][1], WinW, 3)

    -- [NUEVO] Si está cargando, dibujamos el loading y salimos
    if QuestSystemByMaps.IsLoading then
        QuestSystemByMaps.RenderLoading()
        return
    end

    -- Pantalla de "Ya terminaste por hoy"
    if QuestSystemByMapsFinishedQuest == 1 then
        SetTextColor(225, 225, 225, 255)
        RenderText3(x, y + 100, QUEST_SYSTEM_MAPS_MESSAGES[GetLanguage()][21], WinW, 3)
        return
    end

    -- LÓGICA DE DIBUJO: DETALLE vs LISTA (Solo si no está cargando)
    if QuestSystemByMaps.OpenedByPlayer == 1 and QuestSystemByMapsInfo and QuestSystemByMapsInfo.QuestIdentification then
        -- MUESTRA PROGRESO
        SetTextColor(255, 200, 50, 255)
        RenderText3(x, y + 40, QuestSystemByMapsInfo.QuestName or "Misión", WinW, 3)
        local requirementsOffset = QuestSystemByMaps.RenderTextRequirements(QuestSystemByMapsInfo)
        QuestSystemByMaps.RenderTextReward(QuestSystemByMapsInfo, requirementsOffset)
    else
        -- MUESTRA LISTA
        SetTextColor(255, 255, 100, 255)
        RenderText3(x, y + 65, QUEST_SYSTEM_MAPS_MESSAGES[GetLanguage()][3], WinW, 3)
        
        local displayList = QuestSystemByMapsAvailableList or {}
        if #displayList == 0 then
            SetTextColor(150, 150, 150, 255)
            RenderText3(x, y + 100, "No hay misiones disponibles aquí.", WinW, 3)
        else
            local listY = y + 90
            for idx, q in ipairs(displayList) do
                local ly = listY + ((idx-1) * 14)
                
                -- Buscamos la configuración local para saber si es OneTime
                local qDef = QuestSystemByMaps.GetQuestIdentification(q.QuestIdentification)
                local isOneTime = (qDef and qDef.IsOneTime == 1)
                
                -- LÓGICA DE COLORES Y PREFIJO
                local questPrefix = ""
                if isOneTime then
                    questPrefix = "[!] " -- Signo de admiración para únicas
                    if MousePosX() >= x + 20 and MousePosX() <= x + WinW - 20 and MousePosY() >= ly and MousePosY() <= ly + 12 then
                        SetTextColor(255, 180, 50, 255) -- Naranja brillante (Hover)
                    else
                        SetTextColor(255, 140, 0, 255)  -- Naranja oscuro (Normal)
                    end
                else
                    questPrefix = "[!] " 
                    if MousePosX() >= x + 20 and MousePosX() <= x + WinW - 20 and MousePosY() >= ly and MousePosY() <= ly + 12 then
                        SetTextColor(255, 255, 150, 255) -- Amarillo (Hover)
                    else
                        SetTextColor(0, 250, 154, 255)   -- Verde menta original (Normal)
                    end
                end
                
                RenderText3(x + 20, ly, string.format("%s%s", questPrefix, q.QuestName), WinW - 40, 3)
            end
        end
    end
    DisableAlphaBlend()
end

function QuestSystemByMaps.RenderTextRequirements(questInfo)
    local WinW = 250
    local x, y = m_Pos.x, m_Pos.y
    local titleY, m_Y = y + 65, y + 80
    local addY = 0
    
    QuestSystemByMapsCanStart = true
    if not questInfo or not questInfo.QuestIdentification then QuestSystemByMapsCanStart = false; return 0 end

    local qDef = QuestSystemByMaps.GetQuestIdentification(questInfo.QuestIdentification)
    if not qDef then QuestSystemByMapsCanStart = false; return 0 end

    SetTextColor(255, 255, 255, 255); RenderText3(x, titleY, QUEST_SYSTEM_MAPS_MESSAGES[GetLanguage()][7], WinW, 3)
    
    local function RenderReqLine(text, isMet, blocksStart)
        if isMet then SetTextColor(172, 255, 56, 255) 
        else SetTextColor(255, 50, 50, 255); if blocksStart then QuestSystemByMapsCanStart = false end end
        RenderText3(x, m_Y + addY, "[!] " .. text:gsub("^%- ", ""), WinW, 3)
        addY = addY + 11
    end
    
    local lang = GetLanguage()
    if (qDef.Level or 0) > 0 then RenderReqLine(string.format(QUEST_SYSTEM_MAPS_MESSAGES[lang][8], qDef.Level), (QuestSystemByMapsPlayerStats.Level or 0) >= qDef.Level, true) end
    if (qDef.Reset or 0) > 0 then RenderReqLine(string.format(QUEST_SYSTEM_MAPS_MESSAGES[lang][9], qDef.Reset), (QuestSystemByMapsPlayerStats.Resets or 0) >= qDef.Reset, true) end
    if (qDef.Zen or 0) > 0 then RenderReqLine(string.format(QUEST_SYSTEM_MAPS_MESSAGES[lang][11], qDef.Zen), (QuestSystemByMapsPlayerStats.Zen or 0) >= qDef.Zen, true) end
    if (qDef.Coin4 or 0) > 0 then RenderReqLine(string.format(QUEST_SYSTEM_MAPS_MESSAGES[lang][15], qDef.Coin4), (QuestSystemByMapsPlayerStats.Coin4 or 0) >= qDef.Coin4, true) end

	-- 4. REQUISITOS DE MONSTRUOS (Con Check ✔️)
    local npc = QuestSystemByMapsCurrentNPC or 0
    local map = QuestSystemByMaps.CurrentMapID or 0
    local mKey = string.format("%d_%d_%d", npc, map, questInfo.QuestIdentification)
    local monsterList = QUEST_SYSTEM_MAPS_REQUIREMENTS_MONSTER[mKey] or QUEST_SYSTEM_MAPS_REQUIREMENTS_MONSTER[questInfo.QuestIdentification]
    
    if monsterList then
        for idx, mon in ipairs(monsterList) do
            if idx > 5 then break end
            local reqQty = mon.Quantity or 0
            local curKills = (questInfo.KillsMonster and questInfo.KillsMonster[idx]) or 0
            local met = (curKills >= reqQty)
            
            if met then 
                -- COLOR: Verde Lima (172, 255, 56) + CHECK
                SetTextColor(172, 255, 56, 255) 
                RenderText3(x, m_Y + addY, string.format("[!] %s: %d ✔️", mon.MonsterName or "Monster", reqQty), WinW, 3)
            else 
                -- COLOR: Blanco (225, 225, 225) para progreso
                SetTextColor(225, 225, 225, 255) 
                RenderText3(x, m_Y + addY, string.format("[!] %s: %d/%d", mon.MonsterName or "Monster", curKills, reqQty), WinW, 3)
            end
            addY = addY + 11
        end
    end

    -- 5. REQUISITOS DE ÍTEMS (Sincronizado con HUD)
    local itemKey = string.format("%d_%d_%d", npc, map, questInfo.QuestIdentification)
    local itemReqList = QUEST_SYSTEM_MAPS_REQUIREMENTS_ITEMS[itemKey] or QUEST_SYSTEM_MAPS_REQUIREMENTS_ITEMS[questInfo.QuestIdentification]

    if itemReqList then
        for idx, it in ipairs(itemReqList) do
            if idx > 5 then break end
            local reqQty = it.Quantity or 0
            local haveQty = (questInfo.ItemsCount and questInfo.ItemsCount[idx]) or (QuestSystemByMaps.HUD_Data.Items and QuestSystemByMaps.HUD_Data.Items[idx]) or 0
            local met = (haveQty >= reqQty)
            
            -- LÓGICA DE NOMBRE
            local name = it.ItemName or it.Name or GetItemRealName(it.ItemIndex)

            if met then 
                -- COLOR: Aqua Marine (127, 255, 212) + CHECK
                SetTextColor(127, 255, 212, 255) 
                RenderText3(x, m_Y + addY, string.format("[!] %s: %d ✔️", name, reqQty), WinW, 3)
            else 
                -- COLOR: Blanco 
                SetTextColor(255, 20, 147, 255) 
                RenderText3(x, m_Y + addY, string.format("❎ %s: %d/%d", name, haveQty, reqQty), WinW, 3)
            end
            addY = addY + 11
        end
    end
    
    return addY
end

function QuestSystemByMaps.RenderTextReward(questInfo, offsetY)
    if QuestSystemByMapsVisible ~= 1 then return end
    
    local WinW = 250
    local x, y = m_Pos.x, m_Pos.y
    local titleY = y + 80 + offsetY + 15 
    local m_Y = titleY + 15
    local addY = 0
    
    -- TÍTULO: PREMIOS (Ya estaba centrado)
    SetTextColor(255, 189, 25, 255)
    RenderText3(x, titleY, QUEST_SYSTEM_MAPS_MESSAGES[GetLanguage()][20], WinW, 3)
    
    SetFontType(1)
    SetTextColor(225, 225, 225, 255)
    
    local qid = (questInfo and questInfo.QuestIdentification) or QuestSystemByMaps.CurrentQuestID or 0
    local currentMap = QuestSystemByMaps.CurrentMapID or UserGetMap() or 0
    local currentNPC = QuestSystemByMapsCurrentNPC or QuestSystemByMaps.ActiveQuestNPC or 0
    
    local serverKey = string.format("%d_%d_%d", currentNPC, currentMap, qid)
    local mapKey    = string.format("%d_%d", currentMap, qid)
    local npcKey    = string.format("%d_%d", currentNPC, qid)
    
    local function findInTable(tbl)
        if not tbl then return nil end
        if tbl[serverKey] then return tbl[serverKey] end
        if tbl[mapKey] then return tbl[mapKey] end
        if tbl[npcKey] then return tbl[npcKey] end
        if tbl[qid] then return tbl[qid] end
        
        for k, v in pairs(tbl) do
            if type(k) == "string" then
                local last = tonumber((string.match(k, "([^_]+)$")))
                if last and last == tonumber(qid) then return v end
            elseif type(k) == "number" and k == tonumber(qid) then
                return v
            end
        end
        return nil
    end
    
    local rewards = {
        {d = findInTable(QUEST_SYSTEM_MAPS_REWARD_ITEMS), t = "item"},
        {d = findInTable(QUEST_SYSTEM_MAPS_REWARD_COINS), t = "coin"},
        {d = findInTable(QUEST_SYSTEM_MAPS_REWARD_BUFF),  t = "buff"},
        {d = findInTable(QUEST_SYSTEM_MAPS_REWARD_EXP),   t = "exp"},
        {d = findInTable(QUEST_SYSTEM_MAPS_POINTS_REWARDS), t = "pts"}
    }
    
    local any = false
    for _, res in ipairs(rewards) do
        if res.d and next(res.d) then
            any = true
            for _, v in pairs(res.d) do
                local txt = ""
                -- Cambio de prefijo "-" por "[!]" y lógica de centrado
                if res.t == "item" and (v.Class == -1 or v.Class == UserGetClass()) then
                    txt = string.format("* %s", v.Name or (GetNameByIndex and GetNameByIndex(v.ItemIndex)) or "Item")
                elseif res.t == "coin" then
                    txt = string.format("* %d %s", v.CoinAmount, v.CoinName or "Coins")
                elseif res.t == "buff" then
                    txt = string.format("* %s", v.BuffName or "Buff")
                elseif res.t == "exp" then
                    local expNames = {"Exp", "Master Exp", "Level Up", "Master Level Up"}
                    txt = string.format("* %d %s", v.Amount, v.ExpName or expNames[v.ExpId] or "Exp")
                elseif res.t == "pts" and (v.Amount or 0) > 0 then
                    local statNames = {"Puntos Libres", "Fuerza", "Agilidad", "Vitalidad", "Energia", "Comando"}
                    txt = string.format("* %d %s", v.Amount, v.StatName or statNames[v.PtsID] or "Puntos")
                end
                
                if txt ~= "" then
                    -- Centrado: x directo, WinW completo y modo 3
                    RenderText3(x, m_Y + addY, txt, WinW, 3)
                    addY = addY + 10
                end
            end
        end
    end
    
    if not any then
        SetTextColor(150, 150, 150, 255)
        -- También centramos el mensaje de "No hay recompensas"
        RenderText3(x, m_Y + addY, '[!] No hay recompensas visibles', WinW, 3)
    end
end

function QuestSystemByMaps.UpdateMouse()
    if QuestSystemByMaps.IsLoading then return 1 end 
    
    local MouseX, MouseY = MousePosX(), MousePosY()

    -- ===================================================================== --
    -- PRIORIDAD 1: VENTANA EMERGENTE DE ABANDONAR QUEST
    -- ===================================================================== --
    if QuestSystemByMaps.ShowAbandonConfirm then
        local WinW, WinH = 180, 80
        local x = (640 / 2) - (WinW / 2) + ReturnWideScreenX()
        local y = (480 / 2) - (WinH / 2)
        local btnYesY = y + 55
        
        -- Bloqueamos el click al piso para que el PJ no camine
        if type(DisableClickClient) == "function" then DisableClickClient() end
        if type(MouseLButtonPush) == "function" then MouseLButtonPush(0) end

        -- Bloqueo de ráfaga de clicks
        if QuestSystemByMaps.ClickLock then
            if CheckPressedKey(Keys.LButton) == 0 then QuestSystemByMaps.ClickLock = false end
            return 1 
        end

        if CheckPressedKey(Keys.LButton) == 1 then
            -- Click en YES
            if MouseX >= x + 20 and MouseX <= x + 80 and MouseY >= btnYesY and MouseY <= btnYesY + 15 then
                QuestSystemByMaps.ShowAbandonConfirm = false
                
                -- MANDAMOS EL PAQUETE DE ABANDONO AL SERVIDOR
                local packetStr = string.format("QuestAbandon_%s", UserGetName())
                
                CreatePacket(packetStr, QUEST_SYSTEM_MAPS_PACKET)
                SetBytePacket(packetStr, 3) 
                SetDwordPacket(packetStr, QuestSystemByMaps.HUD_ID or 0) 
                SendPacket(packetStr)
                ClearPacket(packetStr)
                
                -- Limpiamos el HUD localmente de inmediato
                QuestSystemByMaps.HUD_ID = 0
                QuestSystemByMaps.HUD_Data = {}
                QuestSystemByMapsHUDVisible = 0 -- Apagamos el flag del HUD para que no parpadee
                QuestSystemByMaps.ClickLock = true
                return 1
            end
            
            -- Click en NO
            if MouseX >= x + 100 and MouseX <= x + 160 and MouseY >= btnYesY and MouseY <= btnYesY + 15 then
                QuestSystemByMaps.ShowAbandonConfirm = false
                QuestSystemByMaps.ClickLock = true
                return 1
            end
        end
        return 1 -- Interceptamos todos los clics mientras esté abierta
    end

    -- ===================================================================== --
    -- PRIORIDAD 2: CLICK EN LA 'X' DEL HUD FLOTANTE
    -- ===================================================================== --
    -- [CORREGIDO] Blindaje anti-nil con (QuestSystemByMaps.HUD_ID or 0)
    if (QuestSystemByMaps.HUD_ID or 0) > 0 and QuestSystemByMapsVisible ~= 1 and not QuestSystemByMaps.IsAnyWindowOpen() then
        local hudWidth = 160
        local startX = (720 - hudWidth - 42) + (ReturnWideScreenX() * 2)
        local startY = 180 
        
        local btnX_X = startX + 110
        local btnX_Y = startY + 3
        
        if MouseX >= btnX_X and MouseX <= btnX_X + 12 and MouseY >= btnX_Y and MouseY <= btnX_Y + 12 then
            if type(DisableClickClient) == "function" then DisableClickClient() end
            if type(MouseLButtonPush) == "function" then MouseLButtonPush(0) end

            if QuestSystemByMaps.ClickLock then
                if CheckPressedKey(Keys.LButton) == 0 then QuestSystemByMaps.ClickLock = false end
                return 1 
            end

            if CheckPressedKey(Keys.LButton) == 1 then
                QuestSystemByMaps.ShowAbandonConfirm = true
                QuestSystemByMaps.ClickLock = true
                return 1
            end
        end
    end

    -- ===================================================================== --
    -- PRIORIDAD 3: VENTANA PRINCIPAL DE MISIONES
    -- ===================================================================== --
    if QuestSystemByMapsVisible ~= 1 then return 0 end
    
    if QuestSystemByMaps.IsMouseOver() then
        if type(DisableClickClient) == "function" then DisableClickClient() end
        if type(MouseLButtonPush) == "function" then MouseLButtonPush(0) end

        if QuestSystemByMaps.ClickLock then
            if CheckPressedKey(Keys.LButton) == 0 then QuestSystemByMaps.ClickLock = false end
            return 1 
        end

        local x, y = QuestSystemByMaps.GetCenterPos()

        -- 1. BOTÓN CERRAR (X)
        if MouseX >= x + 215 and MouseX <= x + 250 and MouseY >= y and MouseY <= y + 30 then
            if CheckPressedKey(Keys.LButton) == 1 then 
                QuestSystemByMaps.CloseAll()
                QuestSystemByMaps.ClickLock = true
                return 1
            end
        end

        -- 2. LISTA DE MISIONES
        if QuestSystemByMaps.OpenedByPlayer == 0 and (QuestSystemByMapsFinishedQuest or 0) ~= 1 then
            local listY = y + 90
            local displayList = QuestSystemByMapsAvailableList or {}
            for idx, q in ipairs(displayList) do
                local ly = listY + ((idx - 1) * 14)
                if MouseX >= x + 20 and MouseX <= x + 230 and MouseY >= ly and MouseY <= ly + 14 then
                    if CheckPressedKey(Keys.LButton) == 1 then
                        QuestSystemByMaps.OpenedByPlayer = 1
                        QuestSystemByMaps.CurrentQuestID = tonumber(q.QuestIdentification)
                        QuestSystemByMapsInfo = {}
                        for k, v in pairs(q) do QuestSystemByMapsInfo[k] = v end
                        
                        -- [CORREGIDO] Más blindaje anti-nil
                        if (QuestSystemByMaps.HUD_ID or 0) > 0 and QuestSystemByMaps.CurrentQuestID == QuestSystemByMaps.HUD_ID then
                            QuestSystemByMapsInfo.Started = 1
                            QuestSystemByMapsInfo.CanCollectLocal = tonumber(QuestSystemByMaps.HUD_Data.CanCollect or 0)
                        else
                            QuestSystemByMapsInfo.Started = 0
                            QuestSystemByMapsInfo.CanCollectLocal = ((QuestSystemByMaps.HUD_ID or 0) > 0) and 2 or 0
                        end
                        QuestSystemByMaps.ClickLock = true
                        return 1 
                    end
                end
            end
        else
            -- 3. BOTÓN DE ACCIÓN
            local actionY = y + 238
            if MouseX >= x + 20 and MouseX <= x + 230 and MouseY >= actionY - 5 and MouseY <= actionY + 15 then
                if CheckPressedKey(Keys.LButton) == 1 then
                    local canCollect = tonumber(QuestSystemByMapsInfo and QuestSystemByMapsInfo.CanCollectLocal or 0)
                    
                    if QuestSystemByMapsFinishedQuest == 1 then
                        QuestSystemByMaps.ContinueQuest()
                    elseif canCollect == 1 then
                        QuestSystemByMaps.GetReward()
                    elseif tonumber(QuestSystemByMapsInfo and QuestSystemByMapsInfo.Started or 0) == 0 then
                        if QuestSystemByMapsCanStart then
                            QuestSystemByMaps.StartQuest(QuestSystemByMapsInfo.QuestIdentification)
                        end
                    end
                    QuestSystemByMaps.ClickLock = true
                    return 1 
                end
            end
        end
        return 1 
    end
    return 0 
end

function QuestSystemByMaps.TriggerFinishNotification(questName)
    QuestSystemByMaps.FinishAnim.QuestName = questName or "Misión"
    QuestSystemByMaps.FinishAnim.StartTime = os.clock() -- Captura el tiempo actual
    QuestSystemByMaps.FinishAnim.Active = true
end

function QuestSystemByMaps.RenderFinishNotification()
    if not QuestSystemByMaps.FinishAnim.Active then return end

    local elapsed = os.clock() - QuestSystemByMaps.FinishAnim.StartTime
    local duration = QuestSystemByMaps.FinishAnim.Duration

    if elapsed > duration then
        QuestSystemByMaps.FinishAnim.Active = false
        return
    end

    -- 1. Alpha para el desvanecimiento de TODO
    local alpha = 1.0
    if elapsed < 0.5 then 
        alpha = elapsed / 0.5
    elseif elapsed > (duration - 1.0) then 
        alpha = (duration - elapsed) / 1.0 
    end
    
    -- Alpha normal para el texto y Alpha al 70% para las sombras
    local aInt = math.floor(alpha * 255)
    local shadowA = math.floor(alpha * 178) 
    
    -- 2. Coordenadas base de la pantalla
    local screenWidth = 640
    local fullX = ReturnWideScreenX()
    local startY = 150 

    ---------------------------------------------------------
    -- PREPARACIÓN DEL MOTOR GRÁFICO
    ---------------------------------------------------------
    EnableAlphaTest()
    EnableAlphaBlend()
    SetBlend() 
    
    ---------------------------------------------------------
    -- TEXTOS CON BORDE (Posicionados donde iba la imagen)
    ---------------------------------------------------------
    local currentY = startY -- Arranca directo en la coordenada Y=150
    local renderWidth = 300 
    local renderX = (screenWidth / 2) - (renderWidth / 2) + fullX

    SetTextBg(0, 0, 0, 0)
    SetFontType(1)
    
    local function DrawTextWithShadow(text, r, g, b)
        -- DIBUJAMOS EL BORDE NEGRO
        SetTextColor(0, 0, 0, shadowA)
        
        -- Cruz cardinal (1px arriba, abajo, izquierda, derecha)
        RenderText3(renderX - 1, currentY, text, renderWidth, 3)
        RenderText3(renderX + 1, currentY, text, renderWidth, 3)
        RenderText3(renderX, currentY - 1, text, renderWidth, 3)
        RenderText3(renderX, currentY + 1, text, renderWidth, 3)
        
        -- Diagonales para pintar el borde aún más grueso y cerrado
        RenderText3(renderX - 1, currentY - 1, text, renderWidth, 3)
        RenderText3(renderX + 1, currentY + 1, text, renderWidth, 3)
        RenderText3(renderX - 1, currentY + 1, text, renderWidth, 3)
        RenderText3(renderX + 1, currentY - 1, text, renderWidth, 3)
        
        -- TEXTO PRINCIPAL EN EL CENTRO EXACTO
        SetTextColor(r, g, b, aInt)
        RenderText3(renderX, currentY, text, renderWidth, 3)

        -- Separación vertical entre líneas de texto
        currentY = currentY + 10
    end

    -- Dibujamos las 3 líneas
    DrawTextWithShadow("Quest System", 255, 215, 0)
    
    local questNameUpper = string.upper(QuestSystemByMaps.FinishAnim.QuestName or "")
    DrawTextWithShadow(questNameUpper, 200, 200, 200)
    
    DrawTextWithShadow("Completed!", 50, 255, 50)

    -- Limpiamos el estado del motor
    DisableBlend(); GLSwitch(); DisableAlphaBlend()
end

function QuestSystemByMaps.UpdateKeyEvent()
    if QuestSystemByMapsVisible ~= 1
    then
        return
    end

    if (CheckPressedKey(Keys.Escape) == 1)
	then
		QuestSystemByMaps.Close()
	end
end

function QuestSystemByMaps.UpdateProc()
    local currentName = UserGetName()
    if lastAccountName ~= currentName then
        QuestSystemByMaps.ResetAllData()
        lastAccountName = currentName
    end

    m_BtnQuest.x = (610 + (ReturnWideScreenX() * 2))

    if QuestSystemByMapsVisible ~= 1 then
        -- Opcional: Desbloquear el caminar si se cerró por una ventana del juego
        if type(UnlockPlayerWalk) == "function" then UnlockPlayerWalk() end
        return
    end

    -- Auto-cierre de la ventana si se abren otras interfaces
    local windows = {
        UIInventory, UIFriendList, UIMoveList, UIParty, UIQuest, UIGuild, UITrade,
        UIWarehouse, UIChaosBox, UICommandWindow, UIPetInfo, UIShop, UIStore,
        UIOtherStore, UICharacter, UIOptions, UIHelp, UIFastDial, UISkillTree,
        UINPC_Titus, UICashShop, UIFullMap, UINPC_Dialog, UIGensInfo, UINPC_Julia,
        UIExpandInventory, UIExpandWarehouse, UIMuHelper
    }

    for _, winID in ipairs(windows) do
        if CheckWindowOpen(winID) == 1 then 
            QuestSystemByMaps.Close() 
            break
        end
    end
    
    -- Bloqueo físico de movimiento (si el emulador lo soporta)
    if type(LockPlayerWalk) == "function" then LockPlayerWalk() end
end

function QuestSystemByMaps.ResetAllData()
    QuestSystemByMapsVisible = 0
    QuestSystemByMapsHUDVisible = 0
    QuestSystemByMapsFinishedQuest = 0
    QuestSystemByMaps.CurrentQuestID = 0
    QuestSystemByMaps.HUD_ID = 0
    QuestSystemByMaps.OpenedByPlayer = 0
    QuestSystemByMapsInfo = nil
    QuestSystemByMapsInfoMonsterKill = nil
    QuestSystemByMapsAvailableList = {}
    QuestSystemByMaps.HUD_Data = { Kills = {0,0,0,0,0,0,0,0,0}, CanCollect = 0 }
    QuestSystemByMaps.ClickLock = nil
end

function QuestSystemByMaps.CheckOpen()
    return QuestSystemByMapsVisible
end

function QuestSystemByMaps.GetQuestIdentification(id)
    if not id or id == 0 then return nil end
    
    local searchId = tonumber(id)

    -- 1. Buscar en la tabla por MAPAS (Nueva estructura)
    if QUEST_SYSTEM_BY_MAP then
        for mapId, questList in pairs(QUEST_SYSTEM_BY_MAP) do
            for _, q in ipairs(questList) do
                if tonumber(q.QuestIdentification) == searchId then 
                    return q 
                end
            end
        end
    end

    -- 2. Buscar en la tabla por NPC
    if QUEST_SYSTEM_MAPS_INFO_BY_NPC then
        for npcId, questList in pairs(QUEST_SYSTEM_MAPS_INFO_BY_NPC) do
            for _, q in ipairs(questList) do
                if tonumber(q.QuestIdentification) == searchId then 
                    return q 
                end
            end
        end
    end

    -- 3. Buscar en la tabla plana/global
    if QUEST_SYSTEM_MAPS_INFO then
        for _, q in pairs(QUEST_SYSTEM_MAPS_INFO) do
            if tonumber(q.QuestIdentification) == searchId then 
                return q 
            end
        end
    end

    return nil
end

function QuestSystemByMaps.Close()
    QuestSystemByMapsVisible = 0
    QuestSystemByMapsFinishedQuest = 0 -- Resetear esto para que no quede trabado en "Continuar"
    QuestSystemByMapsInfo = nil
    QuestSystemByMapsInfoMonsterKill = nil
    QuestSystemByMapsInfoItensCount = nil
end

-- Nueva función para cierre TOTAL (Ventana + HUD)
function QuestSystemByMaps.CloseAll()
    QuestSystemByMaps.Close()
    QuestSystemByMapsHUDVisible = 0 -- Apagamos el HUD magenta
    QuestSystemByMaps.HUD_ID = 0    -- Limpiamos el ID del HUD
    if type(ShowAllInterface) == "function" then ShowAllInterface() end
end

function QuestSystemByMaps.OpenNPC(PacketName)
    local npc_id_in = GetDwordPacket(PacketName, -1) or 0
    local map_id_in = GetDwordPacket(PacketName, -1) or 0
    local qid_in    = GetDwordPacket(PacketName, -1) or 0

    if qid_in == 0xFFFFFFFF then
        QuestSystemByMaps.IsLoading = true; QuestSystemByMapsVisible = 1; return 
    end

    QuestSystemByMaps.IsLoading = false
    QuestSystemByMapsInfo = {}
    QuestSystemByMapsInfoMonsterKill = {}
    QuestSystemByMapsInfoItensCount = {}
    QuestSystemByMapsAvailableList = {}

    QuestSystemByMapsCurrentNPC = npc_id_in
    QuestSystemByMaps.CurrentMapID = map_id_in
    local qid_active_server = qid_in

    -- Leer Stats
    QuestSystemByMapsPlayerStats.Level = GetDwordPacket(PacketName, -1) or 0
    QuestSystemByMapsPlayerStats.Resets = GetDwordPacket(PacketName, -1) or 0
    QuestSystemByMapsPlayerStats.MResets = GetDwordPacket(PacketName, -1) or 0
    QuestSystemByMapsPlayerStats.Zen = GetDwordPacket(PacketName, -1) or 0
    QuestSystemByMapsPlayerStats.Coin1 = GetDwordPacket(PacketName, -1) or 0
    QuestSystemByMapsPlayerStats.Coin2 = GetDwordPacket(PacketName, -1) or 0
    QuestSystemByMapsPlayerStats.Coin3 = GetDwordPacket(PacketName, -1) or 0
    QuestSystemByMapsPlayerStats.Coin4 = GetDwordPacket(PacketName, -1) or 0
    QuestSystemByMapsPlayerStats.Vip = GetDwordPacket(PacketName, -1) or 0
    
    local controlFlag = GetDwordPacket(PacketName, -1) or 0 
    
    -- [REPARACIÓN CRÍTICA] 
    -- Asignamos el valor del paquete directamente a la variable GLOBAL
    QuestSystemByMapsFinishedQuest = GetBytePacket(PacketName, -1) or 0

    -- Leer Progreso Principal
    for i = 1, 9 do QuestSystemByMapsInfoMonsterKill[i] = GetDwordPacket(PacketName, -1) or 0 end
    for i = 1, 10 do QuestSystemByMapsInfoItensCount[i] = GetDwordPacket(PacketName, -1) or 0 end

    -- Leer Lista
    local questCount = GetDwordPacket(PacketName, -1) or 0
    for i = 1, questCount do
        local q_id = GetDwordPacket(PacketName, -1) or 0
        local q_f = GetDwordPacket(PacketName, -1) or 0
        local q_c = GetDwordPacket(PacketName, -1) or 0
        local kills_list = {}
        for j = 1, 9 do kills_list[j] = GetDwordPacket(PacketName, -1) or 0 end
        
        local qDef = QuestSystemByMaps.GetQuestIdentification(q_id) or { QuestIdentification = q_id }
        table.insert(QuestSystemByMapsAvailableList, {
            QuestIdentification = q_id,
            QuestName = qDef.QuestName or "Misión "..q_id,
            Finished = q_f,
            CanCollect = q_c,
            KillsMonster = kills_list
        })
    end

    -- Determinación de Vista
    -- Si la misión está terminada hoy (QuestSystemByMapsFinishedQuest == 1), NO entramos en modo detalle
    if qid_active_server > 0 and QuestSystemByMapsFinishedQuest == 0 and controlFlag ~= 2 then
        QuestSystemByMaps.OpenedByPlayer = 1
        QuestSystemByMaps.CurrentQuestID = qid_active_server
        QuestSystemByMapsInfo.Started = 1
        QuestSystemByMapsInfo.CanCollectLocal = controlFlag
        local base = QuestSystemByMaps.GetQuestIdentification(qid_active_server)
        if base then for k,v in pairs(base) do QuestSystemByMapsInfo[k] = v end end
        QuestSystemByMapsInfo.QuestIdentification = qid_active_server
        QuestSystemByMapsInfo.KillsMonster = QuestSystemByMapsInfoMonsterKill
        QuestSystemByMapsInfo.ItemsCount = QuestSystemByMapsInfoItensCount
    else
        -- Modo Lista o modo "Misión Concluida"
        QuestSystemByMaps.OpenedByPlayer = 0
        QuestSystemByMaps.CurrentQuestID = 0
        QuestSystemByMapsInfo = { Started = 0, CanCollectLocal = controlFlag }
    end

    QuestSystemByMapsVisible = 1
    if type(HideAllInterface) == "function" then HideAllInterface() end
end

function QuestSystemByMaps.SyncHUD(PacketName)
    -- Inicialización segura de tablas
    QuestSystemByMaps.HUD_Data = QuestSystemByMaps.HUD_Data or {}
    QuestSystemByMaps.HUD_Data.Kills = QuestSystemByMaps.HUD_Data.Kills or {}
    QuestSystemByMaps.HUD_Data.Items = QuestSystemByMaps.HUD_Data.Items or {}
    QuestSystemByMapsPlayerStats = QuestSystemByMapsPlayerStats or {}

    -- 1. HEADER (Vital para saber qué misión es y de qué NPC)
    local npc_id_in = GetDwordPacket(PacketName, -1) or 0
    QuestSystemByMapsCurrentNPC = npc_id_in -- Guardamos el NPC para que el Render sepa qué buscar
    
    QuestSystemByMaps.CurrentMapID = GetDwordPacket(PacketName, -1) or 0
    local qid = GetDwordPacket(PacketName, -1) or 0
    
    -- 2. ACTUALIZACIÓN DE STATS (Para que los requisitos en rojo/verde cambien en vivo)
    QuestSystemByMapsPlayerStats.Level = GetDwordPacket(PacketName, -1) or 0
    QuestSystemByMapsPlayerStats.Resets = GetDwordPacket(PacketName, -1) or 0
    QuestSystemByMapsPlayerStats.MResets = GetDwordPacket(PacketName, -1) or 0
    QuestSystemByMapsPlayerStats.Zen = GetDwordPacket(PacketName, -1) or 0
    QuestSystemByMapsPlayerStats.Coin1 = GetDwordPacket(PacketName, -1) or 0
    QuestSystemByMapsPlayerStats.Coin2 = GetDwordPacket(PacketName, -1) or 0
    QuestSystemByMapsPlayerStats.Coin3 = GetDwordPacket(PacketName, -1) or 0
    QuestSystemByMapsPlayerStats.Coin4 = GetDwordPacket(PacketName, -1) or 0
    QuestSystemByMapsPlayerStats.Vip = GetDwordPacket(PacketName, -1) or 0
    
    -- 3. ESTADOS DE FINALIZACIÓN
    local controlState = GetDwordPacket(PacketName, -1) or 0 
    local isFinished = GetBytePacket(PacketName, -1) or 0
    
    -- Guardamos el estado puro (0=Incomp, 1=Listo, 2=Remoto)
    QuestSystemByMaps.HUD_Data.State = controlState 
    -- Mantenemos CanCollect por compatibilidad de otras funciones (1 o 2 cuentan como "objetivos de bicho listos")
    QuestSystemByMaps.HUD_Data.CanCollect = (controlState >= 1 and 1 or 0)
    
    -- Si la ID es 0, significa que no hay misión activa: apagamos HUD
    if qid == 0 then
        QuestSystemByMapsHUDVisible = 0
        QuestSystemByMaps.HUD_ID = 0
        return
    end

    -- 4. GUARDAR PROGRESO PARA EL DIBUJO DEL HUD
    QuestSystemByMaps.HUD_ID = qid

    -- Leemos los 9 slots de Monstruos
    for i = 1, 9 do 
        QuestSystemByMaps.HUD_Data.Kills[i] = GetDwordPacket(PacketName, -1) or 0 
    end
    
    -- Leemos los 10 slots de Ítems
    for i = 1, 10 do 
        QuestSystemByMaps.HUD_Data.Items[i] = GetDwordPacket(PacketName, -1) or 0 
    end

    -- Encendemos el HUD
    QuestSystemByMapsHUDVisible = 1
end

function QuestSystemByMaps.SendOpenQuest()
    local currentMap = (type(GetMapNumber) == "function") and GetMapNumber() or 0
    
    -- Limpieza visual inmediata
    QuestSystemByMaps.IsLoading = true
    QuestSystemByMapsVisible = 1
    QuestSystemByMapsInfo = {}
    QuestSystemByMapsAvailableList = {}
    QuestSystemByMapsFinishedQuest = 0
    
    local packetString = string.format("%s_%s", QUEST_SYSTEM_MAPS_PACKET_OPEN_NAME, UserGetName())
    CreatePacket(packetString, QUEST_SYSTEM_MAPS_PACKET)
    SetDwordPacket(packetString, currentMap)
    SendPacket(packetString)
    ClearPacket(packetString)
    
    -- [MUY IMPORTANTE] Bloqueamos la interfaz del cliente.
    -- Esto envía una señal al servidor de que el jugador está "ocupado".
    if type(HideAllInterface) == "function" then HideAllInterface() end
end

function QuestSystemByMaps.StartQuest(questID)
    local ok, err = xpcall(function()
        local pName = UserGetName()
		
		-- [NUEVO] Limpiamos el bloqueo diario para que el HUD pueda aparecer
        if QuestSystemByMaps.AlwaysContinue then 
            QuestSystemByMaps.AlwaysContinue[pName] = nil 
        end
		
        local packetString = string.format("%s_%s", QUEST_SYSTEM_MAPS_PACKET_START_NAME, pName)
        CreatePacket(packetString, QUEST_SYSTEM_MAPS_PACKET)
        SetDwordPacket(packetString, questID or 0)
        SendPacket(packetString)
        ClearPacket(packetString)
    
        -- [ ACTIVACIÓN INMEDIATA DEL HUD ]
        QuestSystemByMaps.HUD_ID = questID or 0        -- Seteamos la ID para el HUD
        QuestSystemByMapsHUDVisible = 1               -- Forzamos visibilidad del HUD
        QuestSystemByMaps.HUD_Data = QuestSystemByMaps.HUD_Data or { Kills = {}, Info = {} }
        QuestSystemByMaps.HUD_Data.Kills = {0,0,0,0,0,0,0,0,0} -- Limpiamos contadores
        QuestSystemByMaps.HUD_Data.CanCollect = 0
        
        -- Datos de compatibilidad
        QuestSystemByMaps.CurrentQuestID = questID or 0
        QuestSystemByMapsPlayerKills = {0,0,0,0,0,0,0,0,0}
        
        QuestSystemByMapsVisible = 0 -- Cerramos ventana NPC
        QuestSystemByMaps.ClickLock = true
    end, debug.traceback)
    
    if not ok then
        LogAddC(2, "QuestSystemByMaps.StartQuest ERROR: "..tostring(err))
    end
end

function QuestSystemByMaps.GetReward()
    if not QuestSystemByMapsInfo or tonumber(QuestSystemByMapsInfo.CanCollectLocal or 0) ~= 1 then
        return
    end

    local qid = tonumber(QuestSystemByMapsInfo.QuestIdentification or 0)
    if qid == 0 then return end

    local packetString = string.format("%s_%s", QUEST_SYSTEM_MAPS_PACKET_GET_REWARD_NAME, UserGetName())
    CreatePacket(packetString, QUEST_SYSTEM_MAPS_PACKET)
    SetDwordPacket(packetString, qid)
    SendPacket(packetString)
    ClearPacket(packetString)
    
    -- Limpieza total inmediata para que el HUD no "parpadee"
    QuestSystemByMapsHUDVisible = 0
    QuestSystemByMaps.HUD_ID = 0
    
    QuestSystemByMaps.CloseAll()
    QuestSystemByMaps.OpenedByPlayer = 0
    QuestSystemByMaps.ClickLock = true
end

function QuestSystemByMaps.ContinueQuest()
    QuestSystemByMaps.CurrentQuestID = 0
    QuestSystemByMaps.ActiveQuestNPC = 0 
    QuestSystemByMapsPlayerKills = {}
    
    local packetString = string.format("%s_%s", QUEST_SYSTEM_MAPS_PACKET_CONTINUE_QUEST_NAME, UserGetName())
    CreatePacket(packetString, QUEST_SYSTEM_MAPS_PACKET)
    SendPacket(packetString)
    ClearPacket(packetString)
    
    -- Cerramos todo
    QuestSystemByMaps.CloseAll()
end

function QuestSystemByMaps.OpenContinueQuest()
    HideAllInterface()

    QuestSystemByMapsFinishedQuest = 1

    QuestSystemByMapsVisible = 1
end

function QuestSystemByMaps.Protocol(Packet, PacketName)
    if Packet ~= QUEST_SYSTEM_MAPS_PACKET then return end
    
    -- 1. APERTURA DESDE NPC
    if string.find(PacketName, "QuestSystemByMapsOpen") then
        QuestSystemByMaps.OpenNPC(PacketName)
        ClearPacket(PacketName)
        return
    end
    
    -- 2. ACTUALIZACIÓN SILENCIOSA (HUD)
    if string.find(PacketName, "QuestSystemByMapsHUDUpdate") then
        QuestSystemByMaps.SyncHUD(PacketName)
        ClearPacket(PacketName)
        return
    end
    
    -- 3. OBJETIVOS CUMPLIDOS (Cartel de aviso)
    if string.find(PacketName, "QuestGoalMet") then
        local qid = GetDwordPacket(PacketName, -1)
        local qData = QuestSystemByMaps.GetQuestIdentification(qid)
        local name = qData and qData.QuestName or "Misión"
    
        -- DISPARAMOS EL CARTEL VISUAL
        QuestSystemByMaps.TriggerFinishNotification(name)
                
        ClearPacket(PacketName)
        return
    end
    
    -- 4. COBRO DE RECOMPENSA (Solo si el server manda este paquete al terminar)
    if string.find(PacketName, "QuestSystemByMapsContinue") then
        QuestSystemByMaps.Close()
        QuestSystemByMaps.OpenContinueQuest()
        ClearPacket(PacketName)
        return
    end
end

function QuestSystemByMaps.IsAnyWindowOpen()
    local windows = {
        UIInventory, UIFriendList, UIParty, UIQuest, UIGuild, UITrade,
        UIWarehouse, UIChaosBox, UICommandWindow, UIPetInfo, UIShop, UIStore,
        UIOtherStore, UICharacter, UIOptions, UIHelp, UIFastDial, UISkillTree,
        UIFullMap, UINPC_Dialog, UIGensInfo, UIExpandInventory, UIExpandWarehouse, UIMuHelper
    }
    for _, winID in ipairs(windows) do
        if CheckWindowOpen(winID) == 1 then return true end
    end
    return false
end

function QuestSystemByMaps.RenderMonsterHUD()
    -- 1. VALIDACIONES
    local uname = UserGetName()
    local always = QuestSystemByMaps.AlwaysContinue and QuestSystemByMaps.AlwaysContinue[uname]
    if always and always.date == os.date("%Y-%m-%d") then return end

    local qid = QuestSystemByMaps.HUD_ID or 0
    if QuestSystemByMapsVisible == 1 or QuestSystemByMapsHUDVisible == 0 or qid <= 0 or QuestSystemByMaps.IsAnyWindowOpen() then
        return
    end
    
    -- 2. RECUPERACIÓN DE DATOS
    local key = string.format("%d_%d_%d", QuestSystemByMapsCurrentNPC or 0, QuestSystemByMaps.CurrentMapID or 0, qid)
    local monsterList = QUEST_SYSTEM_MAPS_REQUIREMENTS_MONSTER[key] or QUEST_SYSTEM_MAPS_REQUIREMENTS_MONSTER[qid]
    if not monsterList then return end
    
    local itemReqList = QUEST_SYSTEM_MAPS_REQUIREMENTS_ITEMS[key] or QUEST_SYSTEM_MAPS_REQUIREMENTS_ITEMS[qid]
    
    -- 3. DIMENSIONES MAESTRAS
    local hudWidth = 160
    local rowH = 14 
    local startX = (720 - hudWidth - 42) + (ReturnWideScreenX() * 2)
    local startY = 180 
    
    EnableAlphaTest(); EnableAlphaBlend(); SetBlend()
    
    -- =========================================================
    -- TÍTULO: Fondo, Borde y Textos
    -- =========================================================
    glColor4f(1.0, 1.0, 1.0, 0.3) --Blanco 0.3 es la transparencia (30% opaco)
    DrawBar(startX, startY, hudWidth, rowH)
    
    glColor4f(0.2, 0.2, 0.2, 1.0)
    DrawBar(startX - 1, startY - 1, hudWidth + 2, 1)
    DrawBar(startX - 1, startY + rowH, hudWidth + 2, 1)
    DrawBar(startX - 1, startY, 1, rowH)
    DrawBar(startX + hudWidth, startY, 1, rowH)
    EndDrawBar() 
    
    glColor3f(1.0, 1.0, 1.0)
    SetFontType(1); SetTextBg(0, 0, 0, 0)
    
    -- Símbolo Izquierda ▼ (Posición: X + 5)
    SetTextColor(255, 255, 255, 255)
    RenderText3(startX + 5, startY + 2, "▼", 15, 1)

    -- Texto Medio (Posición: X + 22, alineado a la izquierda para que respete su lugar)
    SetTextColor(255, 215, 0, 255) --Amarillo
	RenderText3(startX + 22, startY + 2, "Quest System", 100, 1)

    -- Botón "X" a la Derecha (Traído a X + 140 para que sea 100% visible)
    local btnX_X = startX + 110
    local btnX_Y = startY + 2
	SetTextColor(150, 150, 150, 255) -- Color Gris metalizado para el divisor
    RenderText3(btnX_X - 8, btnX_Y, "║", 15, 1)
	local isHoverX = MousePosX() >= btnX_X and MousePosX() <= btnX_X + 12 and MousePosY() >= btnX_Y and MousePosY() <= btnX_Y + 12
    
    if isHoverX then 
        SetTextColor(255, 50, 50, 255) 
    else 
        SetTextColor(200, 200, 200, 255) 
    end
	RenderText3(btnX_X, btnX_Y, "X", 15, 1) 

    -- =========================================================
    -- FILAS: Monstruos e Items
    -- =========================================================
    local currentY = startY + rowH + 4

    local function DrawDrawer(text, cur, max)
        EnableAlphaTest(); EnableAlphaBlend(); SetBlend()

        glColor4f(0.0, 0.0, 0.0, 0.7) 
        DrawBar(startX, currentY, hudWidth, rowH)
        
        glColor4f(0.2, 0.2, 0.2, 1.0) 
        DrawBar(startX - 1, currentY - 1, hudWidth + 2, 1)
        DrawBar(startX - 1, currentY + rowH, hudWidth + 2, 1)
        DrawBar(startX - 1, currentY, 1, rowH)
        DrawBar(startX + hudWidth, currentY, 1, rowH)
        EndDrawBar()

        glColor3f(1.0, 1.0, 1.0)
        SetFontType(0); SetTextBg(0, 0, 0, 0)
        
        -- Símbolo Izquierda ► 
        SetTextColor(200, 200, 200, 255)
        RenderText3(startX + 5, currentY + 3, "►", 15, 1)
        
        -- Empujamos el texto para que arranque después del símbolo
        local textX = startX + 18 
        local textWidth = hudWidth - 25

        if cur >= max then
            SetTextColor(100, 255, 100, 255)
            RenderText3(textX, currentY + 3, text .. " ✔️", textWidth, 1) -- Verde
        elseif cur > 0 then
            SetTextColor(255, 120, 0, 255) --Naranja
            RenderText3(textX, currentY + 3, text, textWidth, 1)
        else
            SetTextColor(255, 255, 255, 255)
            RenderText3(textX, currentY + 3, text, textWidth, 1) -- Blanco
        end
        
        currentY = currentY + rowH + 4 
    end

    -- 4. DIBUJAR MONSTRUOS
    if monsterList then
        for idx, mon in ipairs(monsterList) do
            local cur = (QuestSystemByMaps.HUD_Data.Kills and QuestSystemByMaps.HUD_Data.Kills[idx]) or 0
            local txt = string.format("%s: %d/%d", mon.MonsterName, cur, mon.Quantity)
            DrawDrawer(txt, cur, mon.Quantity)
        end
    end

    -- 5. DIBUJAR ITEMS
    if itemReqList then
        for idx, it in ipairs(itemReqList) do
            local cur = (QuestSystemByMaps.HUD_Data.Items and QuestSystemByMaps.HUD_Data.Items[idx]) or 0
            local name = it.ItemName or GetItemRealName(it.ItemIndex)
            local txt = string.format("%s: %d/%d", name, cur, it.Quantity)
            DrawDrawer(txt, cur, it.Quantity)
        end
    end

    DisableBlend(); GLSwitch(); DisableAlphaBlend()
end

function QuestSystemByMaps.RenderAbandonConfirm()
    if not QuestSystemByMaps.ShowAbandonConfirm then return end
    
    local WinW, WinH = 180, 80
    local x = (640 / 2) - (WinW / 2) + ReturnWideScreenX()
    local y = (480 / 2) - (WinH / 2)

    EnableAlphaTest(); EnableAlphaBlend(); SetBlend()
    
    -- Fondo Oscuro
    glColor4f(0.0, 0.0, 0.0, 0.8)
    DrawBar(x, y, WinW, WinH)
    
    -- Borde simple (para no complicar los texturas acá)
    glColor4f(0.5, 0.0, 0.0, 1.0)
    DrawBar(x - 1, y - 1, WinW + 2, 1) -- Top
    DrawBar(x - 1, y + WinH, WinW + 2, 1) -- Bottom
    DrawBar(x - 1, y, 1, WinH) -- Left
    DrawBar(x + WinW, y, 1, WinH) -- Right
    EndDrawBar()
    
    glColor3f(1.0, 1.0, 1.0)
    
    -- Textos
    SetFontType(1); SetTextBg(0, 0, 0, 0)
    SetTextColor(255, 50, 50, 255)
    RenderText3(x, y + 10, "ABANDON QUEST", WinW, 3)
    
    SetFontType(0)
    SetTextColor(255, 255, 255, 255)
    RenderText3(x, y + 30, "¿Seguro que deseas abandonar?", WinW, 3)
    
    -- Botón YES
    local btnYesY = y + 55
    local isHoverYes = MousePosX() >= x + 20 and MousePosX() <= x + 80 and MousePosY() >= btnYesY and MousePosY() <= btnYesY + 15
    if isHoverYes then SetTextColor(255, 255, 100, 255) else SetTextColor(0, 250, 154, 255) end
    RenderText3(x + 20, btnYesY, "[ YES ]", 60, 3)
    
    -- Botón NO
    local isHoverNo = MousePosX() >= x + 100 and MousePosX() <= x + 160 and MousePosY() >= btnYesY and MousePosY() <= btnYesY + 15
    if isHoverNo then SetTextColor(255, 255, 100, 255) else SetTextColor(255, 100, 100, 255) end
    RenderText3(x + 100, btnYesY, "[ NO ]", 60, 3)
    
    DisableAlphaBlend()
end

function QuestSystemByMaps.IsMouseOver()
    if QuestSystemByMapsVisible ~= 1 then return false end
    
    local x, y = QuestSystemByMaps.GetCenterPos()
    local MouseX, MouseY = MousePosX(), MousePosY()
    local WinW, WinH = 250, 270 -- Tus medidas actuales
    
    -- Retorna true si el mouse está dentro del cuadrado de la ventana
    return MouseX >= x and MouseX <= x + WinW and MouseY >= y and MouseY <= y + WinH
end

function QuestSystemByMaps.Init()
    if QUEST_SYSTEM_MAPS_SWITCH ~= 1 then return end

    -- [1] Protocolo primero
    InterfaceController.ClientProtocol(QuestSystemByMaps.Protocol)
    
    -- [2] EL MOUSE PRIMERO (Fundamental para bloquear movimiento)
    InterfaceController.UpdateMouse(QuestSystemByMaps.UpdateMouse)
    
    -- [3] Las demás actualizaciones
    InterfaceController.UpdateKey(QuestSystemByMaps.UpdateKeyEvent)
    InterfaceController.UpdateProc(QuestSystemByMaps.UpdateProc)
    
    -- [4] El dibujo al final
	InterfaceController.MainProc(QuestSystemByMaps.RenderMonsterHUD)
    InterfaceController.MainProc(QuestSystemByMaps.Render)
end

QuestSystemByMaps.Init()

return QuestSystemByMaps
