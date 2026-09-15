CREATE TABLE [data].[ad419_FieldStationExpenses]
(
    [ProjectAccessionNum] NVARCHAR(7) NOT NULL,
    [ProjectDirector] NVARCHAR(200) NULL,
    [FieldStationCharge] DECIMAL(19, 4) NOT NULL,
    CONSTRAINT [PK_ad419_FieldStationExpenses] PRIMARY KEY CLUSTERED ([ProjectAccessionNum])
);
