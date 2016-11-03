CREATE TABLE [dbo].[ArcCodeAccountExclusions] (
    [Year]             INT           NOT NULL,
    [Chart]            VARCHAR (2)   NOT NULL,
    [Account]          VARCHAR (7)   NOT NULL,
    [AnnualReportCode] CHAR (6)      NOT NULL,
    [Comments]         VARCHAR (MAX) NULL,
    [Is204]            BIT           NULL,
    [AwardNumber]      VARCHAR (20)  NULL,
    [ProjectNumber]    VARCHAR (24)  NULL,
    CONSTRAINT [PK_ArcCodeAccountExclusions] PRIMARY KEY CLUSTERED ([Year] ASC, [Chart] ASC, [Account] ASC, [AnnualReportCode] ASC)
);



