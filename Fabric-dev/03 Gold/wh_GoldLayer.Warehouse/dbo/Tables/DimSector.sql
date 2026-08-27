CREATE TABLE [dbo].[DimSector] (

	[SectorSk] int NOT NULL, 
	[SectorBk] varchar(18) NOT NULL, 
	[Name] varchar(80) NOT NULL, 
	[CurrencyIsoCode] varchar(3) NOT NULL, 
	[StartDate] datetime2(6) NOT NULL, 
	[EndDate] datetime2(6) NOT NULL, 
	[SectorGroups] varchar(255) NOT NULL, 
	[_crda_ActiveFromDate] datetime2(6) NOT NULL, 
	[_crda_ActiveToDate] datetime2(6) NOT NULL, 
	[_crda_ActiveFromDateSk] int NOT NULL, 
	[_crda_ActiveToDateSk] int NOT NULL, 
	[IsCurrent] bit NOT NULL, 
	[_crda_Hash] varbinary(16) NOT NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL, 
	[_crda_isDeleted] bit NOT NULL
);


GO
ALTER TABLE [dbo].[DimSector] ADD CONSTRAINT PK__dbo_DimSector primary key NONCLUSTERED ([SectorSk]);
GO
ALTER TABLE [dbo].[DimSector] ADD CONSTRAINT UQ__dbo_DimSector unique NONCLUSTERED ([SectorBk], [_crda_ActiveFromDate]);