CREATE TABLE [dbo].[TransDocTypes] (
    [DocumentType]         VARCHAR (4)   NOT NULL,
    [Description]          VARCHAR (200) NULL,
    [IncludeInFTECalc]     BIT           NULL,
    [IncludeInFISExpenses] BIT           NULL,
    CONSTRAINT [PK_TransDocTypes] PRIMARY KEY CLUSTERED ([DocumentType] ASC)
);

