﻿CREATE TABLE [dbo].[Organizations_UFY] (
    [Year]           NUMERIC (4)   NOT NULL,
    [Period]         NVARCHAR (2)  NOT NULL,
    [Org]            NVARCHAR (4)  NOT NULL,
    [Chart]          NVARCHAR (2)  NOT NULL,
    [Level]          NUMERIC (2)   NULL,
    [Name]           NVARCHAR (40) NULL,
    [Type]           NVARCHAR (4)  NULL,
    [BeginDate]      NVARCHAR (19) NULL,
    [EndDate]        NVARCHAR (19) NULL,
    [HomeDeptNum]    NVARCHAR (6)  NULL,
    [HomeDeptName]   NVARCHAR (40) NULL,
    [UpdateDate]     NVARCHAR (19) NULL,
    [Chart1]         NVARCHAR (2)  NULL,
    [Org1]           NVARCHAR (4)  NULL,
    [Name1]          NVARCHAR (40) NULL,
    [Chart2]         NVARCHAR (2)  NULL,
    [Org2]           NVARCHAR (4)  NULL,
    [Name2]          NVARCHAR (40) NULL,
    [Chart3]         NVARCHAR (2)  NULL,
    [Org3]           NVARCHAR (4)  NULL,
    [Name3]          NVARCHAR (40) NULL,
    [Chart4]         NVARCHAR (2)  NULL,
    [Org4]           NVARCHAR (4)  NULL,
    [Name4]          NVARCHAR (40) NULL,
    [Chart5]         NVARCHAR (2)  NULL,
    [Org5]           NVARCHAR (4)  NULL,
    [Name5]          NVARCHAR (40) NULL,
    [Chart6]         NVARCHAR (2)  NULL,
    [Org6]           NVARCHAR (4)  NULL,
    [Name6]          NVARCHAR (40) NULL,
    [Chart7]         NVARCHAR (2)  NULL,
    [Org7]           NVARCHAR (4)  NULL,
    [Name7]          NVARCHAR (40) NULL,
    [Chart8]         NVARCHAR (2)  NULL,
    [Org8]           NVARCHAR (4)  NULL,
    [Name8]          NVARCHAR (40) NULL,
    [Chart9]         NVARCHAR (2)  NULL,
    [Org9]           NVARCHAR (4)  NULL,
    [Name9]          NVARCHAR (40) NULL,
    [Chart10]        NVARCHAR (2)  NULL,
    [Org10]          NVARCHAR (4)  NULL,
    [Name10]         NVARCHAR (40) NULL,
    [Chart11]        NVARCHAR (2)  NULL,
    [Org11]          NVARCHAR (4)  NULL,
    [Name11]         NVARCHAR (40) NULL,
    [Chart12]        NVARCHAR (2)  NULL,
    [Org12]          NVARCHAR (4)  NULL,
    [Name12]         NVARCHAR (40) NULL,
    [ActiveInd]      NVARCHAR (1)  NULL,
    [OrganizationPK] NVARCHAR (51) NULL,
    [LastUpdateDate] DATETIME2 (7) NULL
);

