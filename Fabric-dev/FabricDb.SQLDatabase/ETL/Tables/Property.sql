CREATE TABLE [ETL].[Property] (
    [PropertyName]  VARCHAR (128) NOT NULL,
    [PropertyValue] VARCHAR (MAX) NOT NULL,
    [DataType]      VARCHAR (128) NOT NULL,
    [Description]   VARCHAR (512) NOT NULL,
    [_crda_Hash]    BINARY (64)   CONSTRAINT [DF__ETL_Property_Hash] DEFAULT (0x00) NOT NULL,
    CONSTRAINT [PK__ETL_Property] PRIMARY KEY CLUSTERED ([PropertyName] ASC)
);


GO

