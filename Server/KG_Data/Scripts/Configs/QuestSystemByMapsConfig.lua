QUEST_SYSTEM_SWITCH = 1

QUEST_SYSTEM_ONLY_ACCOUNT = 1 
QUEST_SYSTEM_REMOVE_RESETS = 0
QUEST_SYSTEM_REMOVE_MRESETS = 0
QUEST_SYSTEM_REMOVE_COIN1 = 0
QUEST_SYSTEM_REMOVE_COIN2 = 0
QUEST_SYSTEM_REMOVE_COIN3 = 0
QUEST_SYSTEM_REMOVE_COIN4 = 0

QUEST_SYSTEM_USE_GREMORY = 0
QUEST_SYSTEM_SPACE_INVENTORY = 50

-- Packets
QUEST_SYSTEM_PACKET = 0x04
QUEST_SYSTEM_PACKET_OPEN_NAME = 'QuestSystemOpen'
QUEST_SYSTEM_HUD_UPDATE_NAME = 'QuestSystemHUDUpdate'
QUEST_SYSTEM_PACKET_START_NAME = 'QuestSystemStartQuest'
QUEST_SYSTEM_PACKET_GET_REWARD_NAME = 'QuestSystemGetReward'
QUEST_SYSTEM_PACKET_CONTINUE_QUEST_NAME = 'QuestSystemContinueQuest'
QUEST_SYSTEM_PACKET_ABANDON_NAME = 'QuestSystemAbandon'
QUEST_DEBUG_MODE = false -- Cambiá a true cuando quieras ver los logs

-- Lista de NPCs permitidos para abrir el Quest System
-- Puedes añadir todos los que quieras: { [748] = true, [746] = true, [500] = true }
QUEST_SYSTEM_ALLOWED_NPCS = { 
    [748] = true, 
--    [746] = true 
}
---------------------------------------------------------
-- [NUEVO] ESTRUCTURA POR MAPA
---------------------------------------------------------
-- Usaremos QUEST_SYSTEM_BY_MAP[MapID] QuestIdentidication debe cambiar por cada mapa (ej: 1-99 para lorencia 100-199 para devias)
-- Agregamos IsOneTime = 0 (Para quest Diarias) IsOneTime = 1 (Para Quest por unica ves)
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
QUEST_SYSTEM_REQUIREMENTS_ITEMS = {}
QUEST_SYSTEM_REQUIREMENTS_MONSTER = {}
QUEST_SYSTEM_REWARD_ITEMS = {}
QUEST_SYSTEM_REWARD_COINS = {}
QUEST_SYSTEM_REWARD_BUFF = {}
QUEST_SYSTEM_REWARD_EXP = {}
QUEST_SYSTEM_POINTS_REWARDS = {}

---------------------------------------------------------
-- CONFIGURACIÓN MAPA 0 (Lorencia) - Quest 1 (One-Time)
---------------------------------------------------------
local KEY_LR1 = QKey(748, 0, 1)

QUEST_SYSTEM_REQUIREMENTS_MONSTER[ KEY_LR1 ] = {
    { MonsterIndex = 3, Quantity = 10, MonsterName = 'Spider' },
}
--------------------------------------------------------------------------------
								--Reward--
--CoinIdentification: 1 = WcoinP, 2 = WcoinC, 3 = GlobinPoint, 4 = Ruud, 5 = Zen
--Exp Identification: 1 = Normal Exp, 2 = MasterExp 3=LVL-UP 4=Master LVL-UP
-- EffectTime = time in seconds Example EffectID = 29 Seal Ascencion
--------------------------------------------------------------------------------
QUEST_SYSTEM_REWARD_COINS[ KEY_LR1 ] = {
    { CoinName = 'Zen', CoinAmount = 10000000, CoinIdentification = 5 },
}
QUEST_SYSTEM_REWARD_EXP[ KEY_LR1 ] = {
    { ExpId = 3, Amount = 1, ExpName = "LVL UP" },
}
---------------------------------------------------------
-- CONFIGURACIÓN MAPA 0 (Lorencia) - Quest 2 (One-Time)
---------------------------------------------------------
local KEY_LR2 = QKey(748, 0, 2)

QUEST_SYSTEM_REQUIREMENTS_MONSTER[ KEY_LR2 ] = {
    { MonsterIndex = 2, Quantity = 10, MonsterName = 'Budge Dragon' },
}
--------------------------------------------------------------------------------
								--Reward--
--------------------------------------------------------------------------------
QUEST_SYSTEM_REWARD_COINS[ KEY_LR2 ] = {
    { CoinName = 'Zen', CoinAmount = 20000000, CoinIdentification = 5 },
}
QUEST_SYSTEM_REWARD_EXP[ KEY_LR2 ] = {
    { ExpId = 3, Amount = 1, ExpName = "LVL UP" },
}
---------------------------------------------------------
-- CONFIGURACIÓN MAPA 0 (Lorencia) - Quest 3 (One-Time)
---------------------------------------------------------
local KEY_LR3 = QKey(748, 0, 3)

QUEST_SYSTEM_REQUIREMENTS_MONSTER[ KEY_LR3 ] = {
    { MonsterIndex = 14, Quantity = 10, MonsterName = 'Skeleton' },
}
--------------------------------------------------------------------------------
								--Reward--
--------------------------------------------------------------------------------
QUEST_SYSTEM_REWARD_COINS[ KEY_LR3 ] = {
    { CoinName = 'Zen', CoinAmount = 50000000, CoinIdentification = 5 },
}
QUEST_SYSTEM_REWARD_EXP[ KEY_LR3 ] = {
    { ExpId = 3, Amount = 1, ExpName = "LVL UP" },
}
---------------------------------------------------------
-- CONFIGURACIÓN MAPA 0 (Lorencia) - Quest 50 (One-Time)
---------------------------------------------------------
local KEY_LR50 = QKey(748, 0, 50)

QUEST_SYSTEM_REQUIREMENTS_MONSTER[ KEY_LR50 ] = {
    { MonsterIndex = 43, Quantity = 1, MonsterName = 'Golden Budge Dragon' },
}
--------------------------------------------------------------------------------
								--Reward--
--------------------------------------------------------------------------------
QUEST_SYSTEM_REWARD_ITEMS[ KEY_LR50 ] = {
    { ItemIndex = GET_ITEM(12,30), Level = 0, Op1=0, Op2=0, Life=0, Exc=0, Ancient=0, JoH=0, SockCount=0, ItemTime=0, DaysExpire=0, Flag=0, Name='Jewel Of Chaos x1', Count=1, Class = -1 }
}
QUEST_SYSTEM_REWARD_COINS[ KEY_LR50 ] = {
    { CoinName = 'Zen', CoinAmount = 50000000, CoinIdentification = 5 },
}
QUEST_SYSTEM_REWARD_EXP[ KEY_LR50 ] = {
    { ExpId = 3, Amount = 1, ExpName = "LVL UP" },
}

---------------------------------------------------------
-- CONFIGURACIÓN MAPA 1 (DUNGEON) - Quest 200
---------------------------------------------------------
local KEY_DUN = QKey(748, 1, 200)

QUEST_SYSTEM_REQUIREMENTS_MONSTER[ KEY_DUN ] = {
    { MonsterIndex = 14, Quantity = 10, MonsterName = 'Skeleton' },
}

QUEST_SYSTEM_REWARD_COINS[ KEY_DUN ] = {
    { CoinName = 'Ruud', CoinAmount = 150, CoinIdentification = 4 },
}
QUEST_SYSTEM_REWARD_COINS[ KEY_DUN ] = {
    { CoinName = 'Zen', CoinAmount = 50000000, CoinIdentification = 5 },
}
---------------------------------------------------------
-- CONFIGURACIÓN MAPA 2 (DEVIAS) - Quest 100
---------------------------------------------------------
local KEY_DVS = QKey(748, 2, 100)

QUEST_SYSTEM_REQUIREMENTS_MONSTER[ KEY_DVS ] = {
    { MonsterIndex = 562, Quantity = 1, MonsterName = 'Dark Mammoth' },
    { MonsterIndex = 563, Quantity = 1, MonsterName = 'Dark Giant' },
    { MonsterIndex = 564, Quantity = 1, MonsterName = 'Dark Coolutin' },
    { MonsterIndex = 565, Quantity = 1, MonsterName = 'Dark Iron Knight' },
}

QUEST_SYSTEM_REWARD_COINS[ KEY_DVS ] = {
    { CoinName = 'Ruud', CoinAmount = 150, CoinIdentification = 4 },
}

QUEST_SYSTEM_REWARD_ITEMS[ KEY_DVS ] = {
    { ItemIndex = GET_ITEM(12,15), Level = 0, Op1=0, Op2=0, Life=0, Exc=0, Ancient=0, JoH=0, SockCount=0, ItemTime=0, DaysExpire=0, Flag=0, Name='Jewel Of Chaos x1', Count=1, Class = -1 }
}

QUEST_SYSTEM_REWARD_EXP[ KEY_DVS ] = {
    { ExpId = 3, Amount = 1, ExpName = "LVL UP" },
}

QUEST_SYSTEM_REWARD_BUFF[ KEY_DVS ] = {
    { EffectID = 29, EffectTime = 3600, BuffName = 'Seal Ascencion' }
}

QUEST_SYSTEM_POINTS_REWARDS[ KEY_DVS ] = {
    {PtsID = 1, Amount = 10, StatName = "Free Points"},
}

---------------------------------------------------------
-- CONFIGURACIÓN MAPA 37 (KANTURU) - Quest 300
---------------------------------------------------------
local KEY_KT = QKey(748, 37, 300)

QUEST_SYSTEM_REQUIREMENTS_MONSTER[ KEY_KT ] = {
    { MonsterIndex = 353, Quantity = 5, MonsterName = 'Satyros' },
    { MonsterIndex = 354, Quantity = 5, MonsterName = 'Blade Hunter' },
    { MonsterIndex = 355, Quantity = 5, MonsterName = 'Kentauros' },
    { MonsterIndex = 356, Quantity = 5, MonsterName = 'Gigantis' },
	{ MonsterIndex = 350, Quantity = 5, MonsterName = 'Berserker' },
	{ MonsterIndex = 357, Quantity = 5, MonsterName = 'Genocider' },
}

QUEST_SYSTEM_REWARD_COINS[ KEY_KT ] = {
    { CoinName = 'Ruud', CoinAmount = 100, CoinIdentification = 4 },
}

QUEST_SYSTEM_REWARD_ITEMS[ KEY_KT ] = {
    { ItemIndex = GET_ITEM(14,13), Level = 0, Op1=0, Op2=0, Life=0, Exc=0, Ancient=0, JoH=0, SockCount=0, ItemTime=0, DaysExpire=0, Flag=0, Name='Jewel Of Bless x1', Count=1, Class = -1 },
}

QUEST_SYSTEM_REWARD_EXP[ KEY_KT ] = {
    { ExpId = 3, Amount = 1, ExpName = "LVL UP" },
}

QUEST_SYSTEM_MESSAGES = {}
QUEST_SYSTEM_MESSAGES['Eng'] = {
    [1] = 'You are busy at the moment!',
    [2] = 'We havent found any quests available at the moment!',
    [3] = 'You have started quest %s!',
    [4] = 'We cant identify your quest!',
    [5] = 'You already have an active quest!',
    [6] = 'You must complete all requirements!',
    [7] = 'You have received %d %s',
    [8] = 'You have already completed all the quests!',
    [9] = '%s - %s (%d/%d)',
    [10] = 'You need space in your inventory',
	[11] = 'Congratulations! You have gained %d level(s).',
	[12] = 'Congratulations! You have gained %d Master level(s).',
    [21] = 'The mission has been completed!',
	[22] = 'You already have an active quest with another NPC!',
}
-- Fin QuestSystemConfig.lua (server)