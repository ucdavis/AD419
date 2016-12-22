CREATE TABLE [dbo].[AllCfdaNumbers] (
    [CFDA_Num]          NVARCHAR (255)  NULL,
    [ProgramTitle]      NVARCHAR (2048) NULL,
    [Agency/Office]     NVARCHAR (2048) NULL,
    [TypesOfAssistance] NVARCHAR (4000) NULL,
    [DateModified]      DATETIME        NULL,
    [DatePublished]     DATETIME        NULL,
    [Agency]            VARCHAR (1024)  NULL,
    [Office]            VARCHAR (1024)  NULL,
    [Code]              VARCHAR (50)    NULL
);

