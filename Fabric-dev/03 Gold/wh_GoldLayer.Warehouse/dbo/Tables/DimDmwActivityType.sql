CREATE TABLE [dbo].[DimDmwActivityType] (

	[DmwActivityTypeSk] bigint IDENTITY NOT NULL, 
	[DmwActivityType] varchar(255) NOT NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL
);


GO
ALTER TABLE [dbo].[DimDmwActivityType] ADD CONSTRAINT PK__dbo_DimDmwActivityType primary key NONCLUSTERED ([DmwActivityTypeSk]);
GO
ALTER TABLE [dbo].[DimDmwActivityType] ADD CONSTRAINT UQ__dbo_DimDmwActivityType unique NONCLUSTERED ([DmwActivityType]);