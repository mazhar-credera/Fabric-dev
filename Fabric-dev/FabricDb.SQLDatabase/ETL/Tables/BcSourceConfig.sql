CREATE TABLE [ETL].[BcSourceConfig] (
    [CompanyName]      VARCHAR (255) NOT NULL,
    [ApiGroup]         VARCHAR (255) NOT NULL,
    [ApiEntitySetName] VARCHAR (255) NOT NULL,
    [IsEnabled]        BIT           CONSTRAINT [DF__Etl_BcSourceConfig_IsEnabled] DEFAULT ((1)) NOT NULL,
    CONSTRAINT [UQ__ETL_BcSourceConfig] UNIQUE CLUSTERED ([CompanyName] ASC, [ApiGroup] ASC, [ApiEntitySetName] ASC)
);


GO

