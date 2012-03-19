CREATE TABLE [dbo].[Expenses_204] (
    [ExpenseID]       INT             IDENTITY (1, 1) NOT NULL,
    [DataSource]      VARCHAR (50)    NULL,
    [OrgR]            VARCHAR (4)     NULL,
    [Chart]           CHAR (1)        NOT NULL,
    [Account]         CHAR (7)        NULL,
    [SubAcct]         VARCHAR (5)     NULL,
    [PI_Name]         NVARCHAR (50)   NULL,
    [Org]             VARCHAR (50)    NULL,
    [EID]             CHAR (9)        NULL,
    [Employee_Name]   NVARCHAR (50)   NULL,
    [TitleCd]         VARCHAR (4)     NULL,
    [Title_Code_Name] NVARCHAR (35)   NULL,
    [Exp_SFN]         CHAR (3)        NULL,
    [Expenses]        DECIMAL (16, 2) NULL,
    [FTE_SFN]         CHAR (3)        NULL,
    [FTE]             DECIMAL (16, 4) NULL,
    [isAssociated]    TINYINT         NULL,
    [isAssociable]    TINYINT         NULL,
    [isNonEmpExp]     INT             NULL,
    [Sub_Exp_SFN]     VARCHAR (4)     NULL,
    [Staff_Grp_Cd]    VARCHAR (16)    NULL
);

