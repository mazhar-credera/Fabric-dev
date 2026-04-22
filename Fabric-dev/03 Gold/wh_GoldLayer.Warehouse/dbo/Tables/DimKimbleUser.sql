CREATE TABLE [dbo].[DimKimbleUser] (

	[KimbleUserSk] int NOT NULL, 
	[KimbleUserBk] varchar(18) NOT NULL, 
	[Username] varchar(80) NOT NULL, 
	[FirstName] varchar(50) NOT NULL, 
	[LastName] varchar(50) NOT NULL, 
	[Name] varchar(255) NOT NULL, 
	[Title] varchar(80) NOT NULL, 
	[Email] varchar(255) NOT NULL, 
	[Alias] varchar(8) NOT NULL, 
	[ProfileId] varchar(18) NOT NULL, 
	[ManagerSk] int NOT NULL, 
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
ALTER TABLE [dbo].[DimKimbleUser] ADD CONSTRAINT PK__dbo_DimKimbleUser primary key NONCLUSTERED ([KimbleUserSk]);
GO
ALTER TABLE [dbo].[DimKimbleUser] ADD CONSTRAINT UQ__dbo_DimKimbleUser unique NONCLUSTERED ([KimbleUserBk], [_crda_ActiveFromDate]);
GO
ALTER TABLE [dbo].[DimKimbleUser] ADD CONSTRAINT FK__dbo_DimKimbleUser__crda_ActiveFromDateSk_dbo_DimDate FOREIGN KEY ([_crda_ActiveFromDateSk]) REFERENCES [dbo].[DimDate]([DateSk]);
GO
ALTER TABLE [dbo].[DimKimbleUser] ADD CONSTRAINT FK__dbo_DimKimbleUser__crda_ActiveToDateSk_dbo_DimDate FOREIGN KEY ([_crda_ActiveToDateSk]) REFERENCES [dbo].[DimDate]([DateSk]);