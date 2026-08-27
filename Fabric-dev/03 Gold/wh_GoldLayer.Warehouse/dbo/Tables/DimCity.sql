CREATE TABLE [dbo].[DimCity] (

	[CitySk] bigint IDENTITY NOT NULL, 
	[CityName] varchar(255) NOT NULL, 
	[CountryName] varchar(255) NOT NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL
);


GO
ALTER TABLE [dbo].[DimCity] ADD CONSTRAINT PK__dbo_DimCity primary key NONCLUSTERED ([CitySk]);
GO
ALTER TABLE [dbo].[DimCity] ADD CONSTRAINT UQ__dbo_DimCity unique NONCLUSTERED ([CityName], [CountryName]);