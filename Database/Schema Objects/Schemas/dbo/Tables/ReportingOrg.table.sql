CREATE TABLE [dbo].[ReportingOrg] (
    [OrgR]                            CHAR (4)     NOT NULL,
    [OrgName]                         VARCHAR (40) NULL,
    [OrgShortName]                    VARCHAR (20) NULL,
    [CRISDeptCd]                      CHAR (4)     NULL,
    [OrgCd3Char]                      CHAR (3)     NULL,
    [IsLocked]                        BIT          NULL,
    [IsActive]                        BIT          NULL,
    [SecondAndThirdAcctNumCharacters] VARCHAR (2)  NULL,
    [IsAdminCluster]                  BIT          NULL,
    [AdminClusterOrgR]                VARCHAR (4)  NULL,
    CONSTRAINT [PK_ReportingOrg] PRIMARY KEY CLUSTERED ([OrgR] ASC)
);




GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'IsAdminCluster: Is this org an administrative cluster?  true/1 is yes; false otherwise.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'ReportingOrg', @level2type = N'COLUMN', @level2name = N'IsAdminCluster';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'AdminClusterOrgR: The Administrative cluster''s OrgR for this org', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'ReportingOrg', @level2type = N'COLUMN', @level2name = N'AdminClusterOrgR';

