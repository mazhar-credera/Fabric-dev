CREATE TABLE [Meta].[ProcessType] (
    [ProcessType] VARCHAR (10)  NOT NULL,
    [Description] VARCHAR (255) NULL,
    [HasHandler]  BIT           CONSTRAINT [DF_Meta_ProcessType_HasHandler] DEFAULT ((0)) NOT NULL,
    CONSTRAINT [PK__Meta_ProcessType] PRIMARY KEY CLUSTERED ([ProcessType] ASC)
);


GO

