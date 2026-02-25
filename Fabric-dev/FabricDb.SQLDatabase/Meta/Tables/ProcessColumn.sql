CREATE TABLE [Meta].[ProcessColumn] (
    [StagingProjection]  VARCHAR (512)  NOT NULL,
    [ColumnName]         VARCHAR (128)  NOT NULL,
    [ColumnOrdinal]      INT            NOT NULL,
    [SqlType]            VARCHAR (128)  NOT NULL,
    [PkOrdinal]          INT            CONSTRAINT [DF_ProcessColumn_PkOrdinal] DEFAULT ((0)) NOT NULL,
    [SourceColumnPath]   VARCHAR (1024) NOT NULL,
    [IsCaseSensitive]    BIT            CONSTRAINT [DF__ProcessColumn_IsCaseSensitive] DEFAULT ((0)) NOT NULL,
    [IncludeInDigest]    BIT            CONSTRAINT [DF__ProcessColumn_IncludeInDigest] DEFAULT ((1)) NOT NULL,
    [IsMasked]           BIT            CONSTRAINT [DF__ProcessColumn_IsMasked] DEFAULT ((0)) NOT NULL,
    [IncludeInStagingCi] BIT            CONSTRAINT [DF__Meta_ProcessColumn_IncludeInStagingCi] DEFAULT ((0)) NOT NULL,
    [StagingCiOrder]     VARCHAR (5)    NULL,
    [ExcludeFromMapping] BIT            NULL,
    [IsComputed]         BIT            CONSTRAINT [DF__ProcessColumn_IsComputed] DEFAULT ((0)) NOT NULL,
    [_crda_Hash]         BINARY (16)    CONSTRAINT [DF__ProcessColumn__crda_Hash] DEFAULT (0x00) NOT NULL,
    CONSTRAINT [PK__Meta_ProcessColumn] PRIMARY KEY CLUSTERED ([StagingProjection] ASC, [ColumnName] ASC),
    CONSTRAINT [FK__Meta_ProcessColumn_Stg_Process] FOREIGN KEY ([StagingProjection]) REFERENCES [Meta].[Process] ([StagingProjection])
);


GO

