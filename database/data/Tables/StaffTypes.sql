CREATE TABLE [data].[StaffTypes]
(
    -- Staff type classification from the legacy ad419.dbo.staff_type table.
    -- FteSfn is the FTE report line (for example 241) that UCPath rows
    -- with a title of this staff type report under. Loaded once per
    -- environment outside source control, like OrgRs; a classification UI may
    -- come later. No seed: gaps surface in the unmatched job code review data.
    [StaffTypeCode] NVARCHAR(10)  NOT NULL,
    [FteSfn]       NVARCHAR(10)  NULL,
    [Description]   NVARCHAR(200) NULL,
    CONSTRAINT [PK_StaffTypes] PRIMARY KEY CLUSTERED ([StaffTypeCode])
);
