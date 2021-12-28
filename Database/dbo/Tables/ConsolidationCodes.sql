CREATE TABLE [dbo].[ConsolidationCodes] (
    [Obj_Consolidatn_Num]        VARCHAR (4)   NULL,
    [Obj_Consolidatn_Name]       VARCHAR (255) NULL,
    [IncludeInFTECalc]           BIT           NULL,
    [IncludeInLaborTransactions] BIT           NULL
);




GO
CREATE NONCLUSTERED INDEX [ConsolidationCodes_IncludeInFTECalc_NCLIDX]
    ON [dbo].[ConsolidationCodes]([IncludeInFTECalc] ASC);

