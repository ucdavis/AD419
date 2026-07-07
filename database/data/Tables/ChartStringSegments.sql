CREATE TABLE [data].[ChartStringSegments]
(
    [SegmentType]     NVARCHAR(20)  NOT NULL,  -- FinancialDepartment | Account | Fund | Activity | Ern
    [Code]            NVARCHAR(50)  NOT NULL,
    [Description]     NVARCHAR(300) NULL,
    [IncludeInReport] BIT           NULL,       -- NULL = unclassified, needs review
    [Sfn]             NVARCHAR(3)   NULL,        -- only meaningful for Fund
    CONSTRAINT [PK_ChartStringSegments] PRIMARY KEY CLUSTERED ([SegmentType], [Code]),
    CONSTRAINT [CK_ChartStringSegments_Sfn] CHECK ([Sfn] IS NULL OR [SegmentType] = 'Fund')
);
