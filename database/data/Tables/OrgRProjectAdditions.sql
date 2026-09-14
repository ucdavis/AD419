-- Manual interdepartmental project placements: a project appears on this
-- OrgR's screen in addition to its default OrgR from the NIFA department.
CREATE TABLE [data].[OrgRProjectAdditions]
(
    [AccessionNumber] NVARCHAR(7)  NOT NULL,
    [OrgR]            NVARCHAR(10) NOT NULL,
    CONSTRAINT [PK_OrgRProjectAdditions] PRIMARY KEY CLUSTERED ([AccessionNumber], [OrgR]),
    CONSTRAINT [FK_OrgRProjectAdditions_OrgRs] FOREIGN KEY ([OrgR]) REFERENCES [data].[OrgRs] ([Code])
);
