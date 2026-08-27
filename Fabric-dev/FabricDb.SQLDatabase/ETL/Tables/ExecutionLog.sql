CREATE TABLE [ETL].[ExecutionLog] (
    [ExecutionId]        INT            IDENTITY (1, 1) NOT NULL,
    [ProcessId]          INT            NOT NULL,
    [BatchId]            INT            NOT NULL,
    [ExternalHandlerId]  VARCHAR (1024) NULL,
    [WorkspaceId]        VARCHAR (1024) NULL,
    [PipelineName]       VARCHAR (1024) NOT NULL,
    [LogDescription]     VARCHAR (1024) NOT NULL,
    [ExecutionStartTime] DATETIME       CONSTRAINT [DF__ETL_ExecutionLog_ExecutionStartTime] DEFAULT (getutcdate()) NOT NULL,
    [ExecutionEndTime]   DATETIME       NULL,
    [InitialWatermark]   VARCHAR (255)  NULL,
    [UpdatedWatermark]   VARCHAR (255)  NULL,
    [FinalStatus]        VARCHAR (50)   NOT NULL,
    [ErrorDetail]        VARCHAR (MAX)  NULL,
    CONSTRAINT [PK__ETL_ExecutionLog] PRIMARY KEY CLUSTERED ([ExecutionId] ASC)
);


GO

