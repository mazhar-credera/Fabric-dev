CREATE TABLE [dbo].[DimContact] (

	[ContactSk] int NOT NULL, 
	[ContactBk] varchar(18) NOT NULL, 
	[ContactType] varchar(80) NOT NULL, 
	[ContactStatus] varchar(80) NOT NULL, 
	[AccountSk] bigint NOT NULL, 
	[OwnerSk] bigint NOT NULL, 
	[Description] varchar(255) NOT NULL, 
	[CurrencyIsoCode] varchar(3) NOT NULL, 
	[FirstName] varchar(80) NOT NULL, 
	[LastName] varchar(80) NOT NULL, 
	[Name] varchar(255) NOT NULL, 
	[Department] varchar(80) NOT NULL, 
	[CoreAssociate] bit NOT NULL, 
	[Title] varchar(255) NOT NULL, 
	[Salutation] varchar(80) NOT NULL, 
	[IsCurrentEmployee] bit NOT NULL, 
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
ALTER TABLE [dbo].[DimContact] ADD CONSTRAINT PK__dbo_DimContact primary key NONCLUSTERED ([ContactSk]);
GO
ALTER TABLE [dbo].[DimContact] ADD CONSTRAINT UQ__dbo_DimContact unique NONCLUSTERED ([ContactBk], [_crda_ActiveFromDate]);