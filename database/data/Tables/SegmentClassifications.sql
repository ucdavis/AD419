CREATE TABLE [data].[SegmentClassifications]
(
    [SegmentType]     NVARCHAR(20)  NOT NULL,  -- FinancialDepartment | Account | Fund | Activity | Ern
    [Code]            NVARCHAR(50)  NOT NULL,
    [Description]     NVARCHAR(300) NULL,
    [IncludeInReport] BIT           NULL,       -- NULL = unclassified, needs review
    [Sfn]             NVARCHAR(10)  NULL,        -- SFN code (201..223) or 'Multiple'; only for Fund
    CONSTRAINT [PK_SegmentClassifications] PRIMARY KEY CLUSTERED ([SegmentType], [Code]),
    CONSTRAINT [CK_SegmentClassifications_Sfn] CHECK ([Sfn] IS NULL OR [SegmentType] = 'Fund')
);
