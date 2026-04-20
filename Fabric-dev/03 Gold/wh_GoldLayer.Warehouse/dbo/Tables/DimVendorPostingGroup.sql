CREATE TABLE [dbo].[DimVendorPostingGroup] (

	[VendorPostingGroupSk] bigint IDENTITY NOT NULL, 
	[VendorPostingGroupName] varchar(40) NOT NULL, 
	[BcCompanySk] int NOT NULL, 
	[Description] varchar(100) NULL, 
	[PayablesAccount] varchar(40) NULL, 
	[_crda_Hash] varbinary(16) NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL
);


GO
ALTER TABLE [dbo].[DimVendorPostingGroup] ADD CONSTRAINT PK__dbo_DimVendorPostingGroup primary key NONCLUSTERED ([VendorPostingGroupSk]);
GO
ALTER TABLE [dbo].[DimVendorPostingGroup] ADD CONSTRAINT UQ__dbo_DimVendorPostingGroup unique NONCLUSTERED ([VendorPostingGroupName], [BcCompanySk]);