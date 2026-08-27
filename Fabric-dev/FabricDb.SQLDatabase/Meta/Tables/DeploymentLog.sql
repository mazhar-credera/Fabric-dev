CREATE TABLE [Meta].[DeploymentLog] (
    [LogId]          INT           IDENTITY (1, 1) NOT NULL,
    [DeploymentType] VARCHAR (255) NOT NULL,
    [LogMessage]     VARCHAR (MAX) NOT NULL,
    [CreateDateTime] DATETIME2 (7) CONSTRAINT [PK__Meta_DeploymentLog_CreateDateTime] DEFAULT (getutcdate()) NOT NULL,
    CONSTRAINT [PK__Meta_DeploymentLog] PRIMARY KEY CLUSTERED ([LogId] ASC)
);


GO

