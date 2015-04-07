CREATE TABLE [dbo].[ArcCodeAccountExclusions] (
    [Year]             INT           NOT NULL,
    [Chart]            VARCHAR (2)   NOT NULL,
    [Account]          VARCHAR (7)   NOT NULL,
    [AnnualReportCode] CHAR (6)      NOT NULL,
    [Comments]         VARCHAR (MAX) NULL
);

