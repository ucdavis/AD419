CREATE TABLE [dbo].[PI_Match] (
    [Id]         INT           IDENTITY (1, 1) NOT NULL,
    [OrgR]       VARCHAR (4)   NULL,
    [Accession]  VARCHAR (20)  NOT NULL,
    [PI]         VARCHAR (200) NULL,
    [EID]        VARCHAR (10)  NULL,
    [PI_Match]   VARCHAR (200) NULL,
    [IsProrated] BIT           NULL,
    CONSTRAINT [PK_PI_Match] PRIMARY KEY CLUSTERED ([Id] ASC)
);






GO
CREATE UNIQUE NONCLUSTERED INDEX [PI_Match_OrgAccessionEID_UDX]
    ON [dbo].[PI_Match]([OrgR] ASC, [Accession] ASC, [EID] ASC);

