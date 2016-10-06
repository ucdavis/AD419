CREATE TABLE [dbo].[AllSFN] (
    [SFN]          VARCHAR (4)    NOT NULL,
    [Description]  NVARCHAR (100) NOT NULL,
    [DisplayInApp] BIT            NULL,
    CONSTRAINT [PK_SFN] PRIMARY KEY CLUSTERED ([SFN] ASC)
);

