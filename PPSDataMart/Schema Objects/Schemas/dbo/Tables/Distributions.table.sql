﻿CREATE TABLE [dbo].[Distributions] (
    [EmployeeID]           CHAR (9)       NOT NULL,
    [DistNo]               SMALLINT       NOT NULL,
    [ApptNo]               SMALLINT       NOT NULL,
    [Chart]                CHAR (1)       NULL,
    [Account]              CHAR (7)       NULL,
    [SubAccount]           VARCHAR (5)    NULL,
    [Object]               VARCHAR (4)    NULL,
    [SubObject]            VARCHAR (3)    NULL,
    [Project]              VARCHAR (10)   NULL,
    [OPFund]               VARCHAR (6)    NULL,
    [SubFundGroupTypeCode] VARCHAR (2)    NULL,
    [SubFundGroupCode]     VARCHAR (6)    NULL,
    [DepartmentNo]         CHAR (6)       NULL,
    [OrgCode]              VARCHAR (4)    NULL,
    [FTE]                  DECIMAL (3, 2) NULL,
    [PayBegin]             DATETIME       NULL,
    [PayEnd]               DATETIME       NULL,
    [Percent]              DECIMAL (5, 4) NULL,
    [PayRate]              DECIMAL (9, 4) NULL,
    [DOSCode]              CHAR (3)       NULL,
    [ADCCode]              CHAR (1)       NULL,
    [Step]                 VARCHAR (4)    NULL,
    [OffScaleCode]         CHAR (1)       NULL,
    [WorkStudyPGM]         CHAR (1)       NULL,
    [IsInPPS]              BIT            NULL
);
