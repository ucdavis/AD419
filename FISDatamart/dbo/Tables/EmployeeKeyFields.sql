﻿CREATE TABLE [dbo].[EmployeeKeyFields] (
    [EMPLID]       NVARCHAR (11) NOT NULL,
    [EMPL_RCD]     NUMERIC (38)  NOT NULL,
    [EFFDT]        DATETIME2 (7) NOT NULL,
    [POSITION_NBR] NVARCHAR (8)  NOT NULL,
    [EFFSEQ]       NUMERIC (38)  NOT NULL,
    [JOBCODE]      NVARCHAR (6)  NOT NULL,
    [DML_IND]      NCHAR (1)     NOT NULL
);

