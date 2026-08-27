CREATE TABLE [ETL].[Bc365ColumnMetadata] (
    [ApiPublisher]     VARCHAR (255) NULL,
    [ApiGroup]         VARCHAR (255) NULL,
    [EntityName]       VARCHAR (255) NULL,
    [ApiEntitySetName] VARCHAR (255) NULL,
    [ColumnName]       VARCHAR (255) NULL,
    [DataType]         VARCHAR (255) NULL,
    [IsNullable]       BIT           NULL,
    [IsKeyColumn]      BIT           NULL,
    [LoadDateTime]     DATETIME2 (7) CONSTRAINT [def__ETL_Bc365ColumnMetadata_LoadDateTime] DEFAULT (sysutcdatetime()) NULL
);


GO

