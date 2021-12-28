CREATE TABLE [dbo].[ERN_Codes] (
    [ERNCD]                 NVARCHAR (255) NOT NULL,
    [UC_EARNCD_DESCR]       NVARCHAR (255) NULL,
    [Include in AD-419 FTE] BIT            NULL,
    [Ken Choice]            NVARCHAR (255) NULL,
    [Employee Name]         NVARCHAR (255) NULL,
    [Empl ID]               NVARCHAR (255) NULL,
    [Notes]                 NVARCHAR (MAX) NULL,
    CONSTRAINT [PK_ERN_Codes] PRIMARY KEY CLUSTERED ([ERNCD] ASC)
);

