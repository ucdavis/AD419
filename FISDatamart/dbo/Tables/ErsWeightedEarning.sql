CREATE TABLE [dbo].[ErsWeightedEarning] (
    [PayrollImportSequenceNum] NUMERIC (9)    NOT NULL,
    [ErnWeightedPct]           NUMERIC (5, 4) NULL,
    CONSTRAINT [PK_ErsWeightedEarning] PRIMARY KEY CLUSTERED ([PayrollImportSequenceNum] ASC)
);

