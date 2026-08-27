CREATE TABLE [dbo].[DimSharePointUser] (

	[SharePointUserSk] int NOT NULL, 
	[SharePointUserBk] int NOT NULL, 
	[Email] varchar(255) NULL, 
	[DisplayName] varchar(255) NULL, 
	[SharePointId] varchar(255) NULL, 
	[_crda_ActiveFromDate] datetime2(6) NOT NULL, 
	[_crda_ActiveToDate] datetime2(6) NOT NULL, 
	[_crda_ActiveFromDateSk] int NOT NULL, 
	[_crda_ActiveToDateSk] int NOT NULL, 
	[IsCurrent] bit NOT NULL, 
	[_crda_Hash] varbinary(16) NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL, 
	[_crda_CreatedExecutionId] int NOT NULL
);


GO
ALTER TABLE [dbo].[DimSharePointUser] ADD CONSTRAINT PK__dbo_DimSharePointUser primary key NONCLUSTERED ([SharePointUserSk]);
GO
ALTER TABLE [dbo].[DimSharePointUser] ADD CONSTRAINT UQ__dbo_DimSharePointUser unique NONCLUSTERED ([SharePointUserBk]);