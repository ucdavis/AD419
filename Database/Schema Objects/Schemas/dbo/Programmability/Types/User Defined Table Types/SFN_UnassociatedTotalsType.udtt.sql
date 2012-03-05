CREATE TYPE [dbo].[SFN_UnassociatedTotalsType] AS  TABLE (
    [SFN]               VARCHAR (4)     NULL,
    [ProjCount]         INT             DEFAULT ((0)) NULL,
    [UnassociatedTotal] DECIMAL (16, 2) DEFAULT ((0.0)) NULL,
    [ProjectsTotal]     DECIMAL (16, 2) DEFAULT ((0.0)) NULL);

