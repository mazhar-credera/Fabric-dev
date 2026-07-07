CREATE TABLE [ETL].[BcCompanyName] (
    [CompanyName]   VARCHAR (100) NOT NULL,
    [IsEnabled]     BIT           CONSTRAINT [DF__Etl_BcCompanyName_IsEnabled] DEFAULT ((1)) NOT NULL,
    [BcEnvironment] VARCHAR (255) NULL,
    CONSTRAINT [PK__ETL__BcCompanyId] PRIMARY KEY CLUSTERED ([CompanyName] ASC)
);


GO

