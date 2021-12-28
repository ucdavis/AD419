CREATE TABLE [dbo].[UCPath_JobDepartmentPrecidence] (
    [EMPLID]   INT          NULL,
    [HomeDept] VARCHAR (10) NULL,
    [AltDept1] VARCHAR (10) NULL,
    [AltDept2] VARCHAR (10) NULL,
    [AltDept3] VARCHAR (10) NULL,
    [AltDept4] VARCHAR (10) NULL,
    [AltDept5] VARCHAR (10) NULL
);


GO
CREATE UNIQUE CLUSTERED INDEX [UCPath_JobDepartmentPrecidence_EMPLID_CLINDX]
    ON [dbo].[UCPath_JobDepartmentPrecidence]([EMPLID] ASC);

