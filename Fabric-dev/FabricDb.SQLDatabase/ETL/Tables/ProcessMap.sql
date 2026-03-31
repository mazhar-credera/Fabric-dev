CREATE TABLE [ETL].[ProcessMap] (
    [ProcessId]              INT           IDENTITY (1, 1) NOT NULL,
    [GroupId]                INT           NOT NULL,
    [StagingProjection]      VARCHAR (512) NOT NULL,
    [ProcessPath]            VARCHAR (512) NOT NULL,
    [ProcessType]            VARCHAR (10)  NOT NULL,
    [RunStatus]              VARCHAR (10)  CONSTRAINT [DF__ETL_ProcessMap_RunStatus] DEFAULT ('Done') NOT NULL,
    [SourceSystem]           VARCHAR (255) NOT NULL,
    [DefaultWatermarkValue]  VARCHAR (255) NOT NULL,
    [BronzeWatermarkValue]   VARCHAR (255) NOT NULL,
    [SilverWatermarkvalue]   VARCHAR (255) NOT NULL,
    [LastExecutionId]        INT           CONSTRAINT [DF__ETL_ProcessMap_LastExecutionId] DEFAULT ((-1)) NOT NULL,
    [LastFileLoadedDateTime] DATETIME2 (7) NULL,
    [IsActive]               BIT           CONSTRAINT [DF__ETL_ProcessMap__IsActive] DEFAULT ((1)) NOT NULL,
    [CurrentWatermark]       VARCHAR (255) CONSTRAINT [DF__ETL_ProcessMap_CurrentWatermark] DEFAULT ('2000-01-01') NOT NULL,
    CONSTRAINT [PK__ETL_ProcessMap] PRIMARY KEY CLUSTERED ([ProcessId] ASC),
    CONSTRAINT [UQ__ETL_ProcessMap] UNIQUE NONCLUSTERED ([GroupId] ASC, [StagingProjection] ASC)
);


GO

