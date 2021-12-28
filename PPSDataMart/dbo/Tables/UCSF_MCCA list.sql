CREATE TABLE [dbo].[UCSF_MCCA list] (
    [Title_Code] INT            NOT NULL,
    [Title_Name] NVARCHAR (100) NOT NULL,
    [Type]       NVARCHAR (50)  NOT NULL,
    CONSTRAINT [PK_UCSF_MCCA list] PRIMARY KEY CLUSTERED ([Title_Code] ASC)
);

