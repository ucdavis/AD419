CREATE TABLE [dbo].[ExpiredProjectCrossReference] (
    [FromAccession] VARCHAR (50) NULL,
    [IsActive]      BIT          NULL,
    [RemapID]       INT          IDENTITY (1, 1) NOT NULL,
    [ToAccession]   VARCHAR (50) NULL,
    CONSTRAINT [PK_ExpiredProjectCrossReference] PRIMARY KEY CLUSTERED ([RemapID] ASC)
);




GO
CREATE UNIQUE NONCLUSTERED INDEX [NonClusteredIndex-20160908-142931]
    ON [dbo].[ExpiredProjectCrossReference]([FromAccession] ASC, [ToAccession] ASC);

