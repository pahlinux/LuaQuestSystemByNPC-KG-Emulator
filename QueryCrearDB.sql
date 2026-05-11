IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[QUEST_SYSTEM_ACTIVE]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[QUEST_SYSTEM_ACTIVE](
        [AccountID] [varchar](10) NOT NULL,
        [Name] [varchar](10) NOT NULL,
        [NPC] [int] NOT NULL,
        [QuestIdentification] [int] NOT NULL,
        [MapNumber] [int] NOT NULL DEFAULT 0,
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
        [CompletedDate] [date] DEFAULT GETDATE(),
        
        -- Esta llave primaria evita duplicados y acelera las búsquedas (SELECT/UPDATE)
        CONSTRAINT [PK_QUEST_SYSTEM_ACTIVE] PRIMARY KEY CLUSTERED 
        (
            [AccountID] ASC, 
            [QuestIdentification] ASC,
            [MapNumber] ASC
        )
    ) ON [PRIMARY];
    
    PRINT 'Tabla QUEST_SYSTEM_ACTIVE configurada correctamente.';
END