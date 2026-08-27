CREATE TABLE [dbo].[DimActivityAssignmentNotes] (

	[ActivityAssignmentNotesSk] int NOT NULL, 
	[ActivityAssignmentBk] varchar(18) NOT NULL, 
	[ActivityAssignmentLogNotes] varchar(4000) NOT NULL, 
	[_crda_Hash] varbinary(16) NOT NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL
);


GO
ALTER TABLE [dbo].[DimActivityAssignmentNotes] ADD CONSTRAINT PK__dbo_DimActivityAssignmentNotes primary key NONCLUSTERED ([ActivityAssignmentNotesSk]);