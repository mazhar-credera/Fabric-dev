CREATE TABLE [Meta].[ProcessMap] (
    [ProcessId]              INT           IDENTITY (1, 1) NOT NULL,
    [GroupId]                INT           NOT NULL,
    [StagingProjection]      VARCHAR (512) NOT NULL,
    [ProcessPath]            VARCHAR (512) NOT NULL,
    [ProcessType]            VARCHAR (10)  NOT NULL,
    [RunStatus]              VARCHAR (10)  CONSTRAINT [DF__Meta_ProcessMap_RunStatus] DEFAULT ('Done') NOT NULL,
    [SourceSystem]           VARCHAR (255) NOT NULL,
    [DefaultWatermark]       VARCHAR (255) NOT NULL,
    [BronzeWatermark]        VARCHAR (255) NOT NULL,
    [SilverWatermark]        VARCHAR (255) NOT NULL,
    [LastExecutionId]        INT           CONSTRAINT [DF__Meta_ProcessMap_LastExecutionId] DEFAULT ((-1)) NOT NULL,
    [LastFileLoadedDateTime] DATETIME2 (7) NULL,
    [IsActive]               BIT           CONSTRAINT [DF__Meta_ProcessMap__IsActive] DEFAULT ((1)) NOT NULL,
    CONSTRAINT [PK__Meta_ProcessMap] PRIMARY KEY CLUSTERED ([ProcessId] ASC),
    CONSTRAINT [UQ__Meta_ProcessMap] UNIQUE NONCLUSTERED ([GroupId] ASC, [StagingProjection] ASC)
);


GO

