CREATE TABLE [dbo].[DimBcUser] (

	[BcUserSk] int NOT NULL, 
	[BcUserID] varchar(100) NOT NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL
);


GO
ALTER TABLE [dbo].[DimBcUser] ADD CONSTRAINT PK__dbo_DimBcUser primary key NONCLUSTERED ([BcUserSk]);
GO
ALTER TABLE [dbo].[DimBcUser] ADD CONSTRAINT UQ__dbo_DimBcUser unique NONCLUSTERED ([BcUserID]);