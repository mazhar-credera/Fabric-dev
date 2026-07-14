CREATE TABLE [Meta].[Process] (
    [StagingProjection]               VARCHAR (512)  NOT NULL,
    [IngestPattern]                   VARCHAR (20)   CONSTRAINT [df__Meta_Process__IngestPattern] DEFAULT ('DeltaTrack') NOT NULL,
    [DeltaLakeSourceFolder]           VARCHAR (1024) NOT NULL,
    [TableSchema]                     VARCHAR (128)  NOT NULL,
    [TableNameRoot]                   VARCHAR (128)  NOT NULL,
    [SourceFormat]                    VARCHAR (20)   NOT NULL,
    [ApiEndPoint]                     VARCHAR (255)  NULL,
    [SourceCollectionReference]       VARCHAR (255)  NULL,
    [ModificationTimeStampExpression] VARCHAR (255)  NULL,
    [DateTimeConversionExpression]    VARCHAR (128)  NULL,
    [WatermarkColumnName]             VARCHAR (255)  NULL,
    [BronzeDataLoadWatermarkColumn]   VARCHAR (255)  NULL,
    [PrimaryKeys]                     VARCHAR (255)  NULL,
    [IsActive]                        BIT            CONSTRAINT [df__Meta_Process__IsActive] DEFAULT ((1)) NOT NULL,
    [IngestFirstTime]                 BIT            NULL,
    CONSTRAINT [PK__Meta_Process] PRIMARY KEY CLUSTERED ([StagingProjection] ASC, [TableSchema] ASC, [TableNameRoot] ASC),
    CONSTRAINT [UQ__Meta_Process_StagingProjection] UNIQUE NONCLUSTERED ([StagingProjection] ASC)
);


GO

