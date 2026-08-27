CREATE TABLE [dbo].[DimProposition] (

	[PropositionSk] int NOT NULL, 
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
	[_crda_isDeleted] bit NOT NULL
);


GO
ALTER TABLE [dbo].[DimProposition] ADD CONSTRAINT PK__dbo_DimProposition primary key NONCLUSTERED ([PropositionSk]);
GO
ALTER TABLE [dbo].[DimProposition] ADD CONSTRAINT UQ__dbo_DimProposition unique NONCLUSTERED ([PropositionBk], [_crda_ActiveFromDate]);
GO
ALTER TABLE [dbo].[DimProposition] ADD CONSTRAINT FK__dbo_DimProposition__crda_ActiveFromDateSk_dbo_DimDate FOREIGN KEY ([_crda_ActiveFromDateSk]) REFERENCES [dbo].[DimDate]([DateSk]);
GO
ALTER TABLE [dbo].[DimProposition] ADD CONSTRAINT FK__dbo_DimProposition__crda_ActiveToDateSk_dbo_DimDate FOREIGN KEY ([_crda_ActiveToDateSk]) REFERENCES [dbo].[DimDate]([DateSk]);