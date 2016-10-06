CREATE TABLE [dbo].[DOS_Codes] (
    [DOS_Code]          CHAR (3)      NOT NULL,
    [Description]       VARCHAR (200) NULL,
    [IncludeInAD419FTE] BIT           NULL,
    CONSTRAINT [PK_DOS_Codes] PRIMARY KEY CLUSTERED ([DOS_Code] ASC)
);



