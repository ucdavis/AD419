﻿




GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'CRIS-assigned project ID', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'AllProjects', @level2type = N'COLUMN', @level2name = N'Accession';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Station-assigned project ID', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'AllProjects', @level2type = N'COLUMN', @level2name = N'Project';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'was named Regional', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'AllProjects', @level2type = N'COLUMN', @level2name = N'RegionalProjNum';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'CRIS Dept Cd (4 digit #).  WARNING: inconsistent correspondence with UCD  Org', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'AllProjects', @level2type = N'COLUMN', @level2name = N'CRIS_DeptID';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'CSREES contract no (was named FundType)', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'AllProjects', @level2type = N'COLUMN', @level2name = N'CSREES_ContractNo';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Investigator (PI Name)  (should normalize this and other INVx columns)', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'AllProjects', @level2type = N'COLUMN', @level2name = N'inv1';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'autogenerated unique Project ID (identity column)', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'AllProjects', @level2type = N'COLUMN', @level2name = N'idProject';

