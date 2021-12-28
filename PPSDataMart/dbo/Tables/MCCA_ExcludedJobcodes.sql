CREATE TABLE [dbo].[MCCA_ExcludedJobcodes] (
    [JOBCODE]               NVARCHAR (6)  NOT NULL,
    [DESCR]                 VARCHAR (150) NULL,
    [Source]                VARCHAR (10)  NOT NULL,
    [IsPresentOn_UCSF_List] BIT           NULL
);

