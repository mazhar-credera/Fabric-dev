CREATE TABLE [Meta].[ProcessGroup] (
    [GroupId]    INT           NOT NULL,
    [GroupStage] VARCHAR (255) NOT NULL,
    [IsActive]   BIT           NOT NULL,
    CONSTRAINT [PK__Meta_ProcessGroup] PRIMARY KEY CLUSTERED ([GroupId] ASC),
    CONSTRAINT [UQ__Meta_ProcessGroup] UNIQUE NONCLUSTERED ([GroupId] ASC, [GroupStage] ASC)
);


GO

