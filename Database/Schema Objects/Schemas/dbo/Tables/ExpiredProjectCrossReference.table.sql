CREATE TABLE [dbo].[ExpiredProjectCrossReference] (
    [RemapID]       INT          IDENTITY (1, 1) NOT NULL,
    [FromAccession] VARCHAR (50) NULL,
    [ToAccession]   VARCHAR (50) NULL,
    [IsActive]      BIT          NULL
);

