CREATE TABLE [ETL].[Bc365ColumnMetadataRaw] (
    [LoadDateTime] DATETIME2 (7) CONSTRAINT [def__ETL_Bc365ColumnMetadataRaw_LoadDateTime] DEFAULT (sysutcdatetime()) NULL,
    [MetadataXML]  XML           NULL,
    [ApiPublisher] VARCHAR (255) NULL,
    [ApiGroup]     VARCHAR (255) NULL,
    [ApiVersion]   VARCHAR (20)  NULL
);


GO

