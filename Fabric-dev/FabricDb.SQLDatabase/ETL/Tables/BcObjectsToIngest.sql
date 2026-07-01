CREATE TABLE [ETL].[BcObjectsToIngest] (
    [ApiGroup]         VARCHAR (255) NOT NULL,
    [ApiEntitySetName] VARCHAR (255) NOT NULL,
    [IsEnabled]        BIT           CONSTRAINT [DF__Etl_BcObjectsToIngest_IsEnabled] DEFAULT ((1)) NOT NULL,
    CONSTRAINT [UQ__ETL_BcObjectsToIngest] UNIQUE CLUSTERED ([ApiGroup] ASC, [ApiEntitySetName] ASC)
);


GO

