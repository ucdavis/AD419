CREATE TABLE [dbo].[FieldStationExpenseListImport] (
    [ProjectAccessionNum] VARCHAR (11)  NULL,
    [FieldStationCharge]  MONEY         NULL,
    [ProjectDirector]     VARCHAR (200) NULL,
    [Id]                  INT           IDENTITY (1, 1) NOT NULL,
    CONSTRAINT [PK_FieldStationExpenseListImport] PRIMARY KEY CLUSTERED ([Id] ASC)
);

