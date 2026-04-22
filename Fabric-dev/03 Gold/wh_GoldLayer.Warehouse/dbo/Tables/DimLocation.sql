CREATE TABLE [dbo].[DimLocation] (

	[LocationSk] int NOT NULL, 
	[LocationBk] varchar(18) NOT NULL, 
	[Name] varchar(80) NOT NULL, 
	[CurrencyIsoCode] varchar(3) NOT NULL, 
	[Code] varchar(80) NULL, 
	[Latitude] decimal(18,7) NULL, 
	[Longitude] decimal(18,7) NULL, 
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
ALTER TABLE [dbo].[DimLocation] ADD CONSTRAINT PK__dbo_DimLocation primary key NONCLUSTERED ([LocationSk]);
GO
ALTER TABLE [dbo].[DimLocation] ADD CONSTRAINT UQ__dbo_DimLocation unique NONCLUSTERED ([LocationBk], [_crda_ActiveFromDate]);