-- PIs who hold an appointment in a department other than the one their
-- projects sit under. Entered by hand in the OrgR Review stage from the
-- faculty roster; nothing in the imported data identifies them. Every
-- non-204 project the PI directs appears on this OrgR's screen in addition
-- to its default OrgR (see [data].[v_ProjXOrgR]).
--
-- PiName is the director name at the time the row was added. It is only a
-- display fallback for a PI who has no projects in the current cycle.
CREATE TABLE [data].[OrgRPiAppointments]
(
    [UcpEmployeeId] NVARCHAR(8)   NOT NULL,
    [OrgR]          NVARCHAR(10)  NOT NULL,
    [PiName]        NVARCHAR(200) NULL,
    CONSTRAINT [PK_OrgRPiAppointments] PRIMARY KEY CLUSTERED ([UcpEmployeeId], [OrgR]),
    CONSTRAINT [FK_OrgRPiAppointments_OrgRs] FOREIGN KEY ([OrgR]) REFERENCES [data].[OrgRs] ([Code])
);
