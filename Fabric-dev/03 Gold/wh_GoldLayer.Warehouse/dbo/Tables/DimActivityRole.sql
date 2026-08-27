CREATE TABLE [dbo].[DimActivityRole] (

	[ActivityRoleSk] int NOT NULL, 
	[ActivityRoleBk] varchar(18) NOT NULL, 
	[PracticeSk] bigint NOT NULL, 
	[ActivityRole] varchar(255) NOT NULL, 
	[_crda_Hash] varbinary(16) NOT NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL
);


GO
ALTER TABLE [dbo].[DimActivityRole] ADD CONSTRAINT PK__dbo_DimActivityRole primary key NONCLUSTERED ([ActivityRoleSk]);
GO
ALTER TABLE [dbo].[DimActivityRole] ADD CONSTRAINT UQ__dbo_DimActivityRole unique NONCLUSTERED ([ActivityRoleBk], [PracticeSk]);