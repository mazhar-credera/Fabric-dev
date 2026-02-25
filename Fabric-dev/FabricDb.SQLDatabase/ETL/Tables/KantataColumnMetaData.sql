CREATE TABLE [ETL].[KantataColumnMetaData] (
    [TableApiName]          VARCHAR (255) NOT NULL,
    [ColumnName]            VARCHAR (255) NOT NULL,
    [ColumnDataType]        VARCHAR (255) NOT NULL,
    [DurableId]             VARCHAR (255) NOT NULL,
    [IsCaseSensitive]       BIT           NOT NULL,
    [Length]                INT           NOT NULL,
    [Precision]             INT           NOT NULL,
    [Scale]                 INT           NOT NULL,
    [RelationshipName]      VARCHAR (255) NULL,
    [_crda_CreatedDateTime] DATETIME2 (7) CONSTRAINT [DF__ETL_KantataColumnMetaData___crda_CreatedDateTime] DEFAULT (getutcdate()) NOT NULL,
    CONSTRAINT [PK__ETL_KantataColumnMetaData] PRIMARY KEY CLUSTERED ([TableApiName] ASC, [ColumnName] ASC)
);


GO

