CREATE TABLE [dbo].[DimDeskReservation] (

	[DeskReservationSk] bigint IDENTITY NOT NULL, 
	[DeskReservationBk] int NOT NULL, 
	[LinkTitle] varchar(255) NULL, 
	[Status] varchar(255) NULL, 
	[DeskText] varchar(255) NULL, 
	[Location] varchar(255) NULL, 
	[ReservedByBase] varchar(255) NULL, 
	[eTag] varchar(255) NULL, 
	[webUrl] varchar(255) NULL, 
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
ALTER TABLE [dbo].[DimDeskReservation] ADD CONSTRAINT PK__dbo_DimDeskReservation primary key NONCLUSTERED ([DeskReservationSk]);
GO
ALTER TABLE [dbo].[DimDeskReservation] ADD CONSTRAINT UQ__dbo_DimDeskReservation unique NONCLUSTERED ([DeskReservationBk], [_crda_ActiveFromDate]);