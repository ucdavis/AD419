CREATE TABLE [dbo].[OrgR_Lookup] (
    [Chart] VARCHAR (2) NOT NULL,
    [Org1]  VARCHAR (4) NULL,
    [OrgR]  VARCHAR (4) NULL,
    [Org]   VARCHAR (4) NOT NULL,
    CONSTRAINT [PK_OrgR_Lookup] PRIMARY KEY CLUSTERED ([Chart] ASC, [Org] ASC)
);



