CREATE TABLE [dbo].[DimProposition] (

	[PropositionSk] bigint IDENTITY NOT NULL, 
	[PropositionBk] varchar(18) NOT NULL, 
	[Name] varchar(80) NOT NULL, 
	[CurrencyIsoCode] varchar(3) NOT NULL, 
	[Description] varchar(255) NOT NULL, 
	[DefaultForecastDetailedLevel] bit NOT NULL, 
	[IsRestricted] bit NOT NULL, 
	[_crda_ActiveFromDate] datetime2(6) NOT NULL, 
	[_crda_ActiveToDate] datetime2(6) NOT NULL, 
	[_crda_ActiveFromDateSk] int NOT NULL, 
	[_crda_ActiveToDateSk] int NOT NULL, 
	[IsCurrent] bit NOT NULL, 
	[_crda_Hash] varbinary(16) NOT NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL, 
	[_crda_IsActive] bit NOT NULL
);


GO
ALTER TABLE [dbo].[DimProposition] ADD CONSTRAINT PK__dbo_DimProposition primary key NONCLUSTERED ([PropositionSk]);
GO
ALTER TABLE [dbo].[DimProposition] ADD CONSTRAINT UQ__dbo_DimProposition unique NONCLUSTERED ([PropositionBk], [_crda_ActiveFromDate]);