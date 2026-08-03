CREATE TABLE [data].[ReportingCycle]
(
    -- Single-row snapshot of the confirmed reporting cycle from Project
    -- Identification (the WorkflowRun table in the application database, which
    -- EF owns). The server syncs it whenever the setup is read or the fiscal
    -- period is confirmed, so
    -- DataDb views can window on the confirmed cycle instead of deriving it
    -- from GETDATE(), which is wrong whenever the cycle being processed is
    -- not the calendar-current fiscal year.
    [Id]         INT          NOT NULL CONSTRAINT [DF_ReportingCycle_Id] DEFAULT (1),
    [FiscalYear] NVARCHAR(16) NOT NULL,
    [CycleStart] DATE         NOT NULL,
    [CycleEnd]   DATE         NOT NULL,
    [UpdatedAt]  DATETIME2(3) NOT NULL CONSTRAINT [DF_ReportingCycle_UpdatedAt] DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT [PK_ReportingCycle] PRIMARY KEY CLUSTERED ([Id]),
    CONSTRAINT [CK_ReportingCycle_SingleRow] CHECK ([Id] = 1)
);
