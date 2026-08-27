CREATE TABLE [dbo].[CandidateResource] (

	[CandidateResourceBk] varchar(18) NOT NULL, 
	[Name] varchar(80) NOT NULL, 
	[FirstName] varchar(80) NOT NULL, 
	[LastName] varchar(80) NOT NULL, 
	[CandidateNotSetUp] int NOT NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL
);


GO
ALTER TABLE [dbo].[CandidateResource] ADD CONSTRAINT UQ__dbo_DimCandidateResource unique NONCLUSTERED ([CandidateResourceBk]);