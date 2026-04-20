CREATE TABLE [dbo].[DimResourcedActivityType] (

	[ResourcedActivityTypeSk] bigint IDENTITY NOT NULL, 
	[ResourcedActivityTypeBk] varchar(18) NOT NULL, 
	[Name] varchar(80) NOT NULL, 
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
ALTER TABLE [dbo].[DimResourcedActivityType] ADD CONSTRAINT PK__dbo_DimResourcedActivityType primary key NONCLUSTERED ([ResourcedActivityTypeSk]);
GO
ALTER TABLE [dbo].[DimResourcedActivityType] ADD CONSTRAINT UQ__dbo_DimResourcedActivityType unique NONCLUSTERED ([ResourcedActivityTypeBk], [_crda_ActiveFromDate]);