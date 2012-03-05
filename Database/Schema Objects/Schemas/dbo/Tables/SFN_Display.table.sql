CREATE TABLE [dbo].[SFN_Display] (
    [GroupDisplayOrder]     TINYINT      NULL,
    [LineDisplayOrder]      TINYINT      NULL,
    [LineDisplayDescriptor] VARCHAR (48) NULL,
    [SFN]                   CHAR (3)     NULL,
    [SumToLine]             CHAR (3)     NULL,
    [LineTypeCode]          VARCHAR (20) NULL,
    [idDisplayLine]         INT          NOT NULL
);

