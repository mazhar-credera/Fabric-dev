CREATE TABLE [dbo].[DimGlBalAccount] (

	[GlBalAccountSk] bigint IDENTITY NOT NULL, 
	[BalAccountNo] varchar(255) NOT NULL, 
	[BalAccountType] varchar(255) NOT NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL
);


GO
ALTER TABLE [dbo].[DimGlBalAccount] ADD CONSTRAINT PK__dbo_DimGlBalAccount primary key NONCLUSTERED ([GlBalAccountSk]);
GO
ALTER TABLE [dbo].[DimGlBalAccount] ADD CONSTRAINT UQ__dbo_DimGlBalAccount unique NONCLUSTERED ([BalAccountNo], [BalAccountType]);