-- Department segment of the NIFA project number (characters 6-8, e.g.
-- CA-D-ARE-2868-H gives ARE) to OrgR. NULL OrgR = needs review.
CREATE TABLE [data].[OrgRNifaDepartments]
(
    [NifaDepartment] NVARCHAR(3)  NOT NULL,
    [OrgR]           NVARCHAR(10) NULL,
    CONSTRAINT [PK_OrgRNifaDepartments] PRIMARY KEY CLUSTERED ([NifaDepartment]),
    CONSTRAINT [FK_OrgRNifaDepartments_OrgRs] FOREIGN KEY ([OrgR]) REFERENCES [data].[OrgRs] ([Code])
);
