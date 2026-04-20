CREATE TABLE [dbo].[DimDeliveryProgram] (

	[DeliveryProgramSk] bigint IDENTITY NOT NULL, 
	[DeliveryProgramBk] varchar(18) NOT NULL, 
	[Name] varchar(80) NOT NULL, 
	[OwnerSk] bigint NOT NULL, 
	[AccountSk] bigint NOT NULL, 
	[CurrencyIsoCode] varchar(3) NOT NULL, 
	[StatusSummaryTemplateInternal] varchar(80) NOT NULL, 
	[RelatedDeliveryProgramSk] int NOT NULL, 
	[UrlToKanataRecord] varchar(255) NOT NULL, 
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
ALTER TABLE [dbo].[DimDeliveryProgram] ADD CONSTRAINT PK__dbo_DimDeliveryProgram primary key NONCLUSTERED ([DeliveryProgramSk]);
GO
ALTER TABLE [dbo].[DimDeliveryProgram] ADD CONSTRAINT UQ__dbo_DimDeliveryProgram unique NONCLUSTERED ([DeliveryProgramBk], [_crda_ActiveFromDate]);