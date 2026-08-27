CREATE TABLE [ETL].[SilverTransformations] (
    [StagingProjection]   VARCHAR (1024) NOT NULL,
    [TransformationsJson] VARCHAR (MAX)  NOT NULL,
    CONSTRAINT [UQ__ETL__SilverTransformations] UNIQUE NONCLUSTERED ([StagingProjection] ASC)
);


GO

