CREATE TABLE [dbo].[DimResourcedActivityName] (

	[ResourcedActivityNameSk] int NOT NULL, 
	[ResourcedActivityName] varchar(255) NOT NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL
);


GO
ALTER TABLE [dbo].[DimResourcedActivityName] ADD CONSTRAINT PK__dbo_DimResourcedActivityName primary key NONCLUSTERED ([ResourcedActivityNameSk]);
GO
ALTER TABLE [dbo].[DimResourcedActivityName] ADD CONSTRAINT UQ__dbo_DimResourcedActivityName unique NONCLUSTERED ([ResourcedActivityName]);