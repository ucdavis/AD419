CREATE TABLE [dbo].[NifaProjectAccessionNumberImport] (
    [Id]              INT           IDENTITY (1, 1) NOT NULL,
    [ProjectNumber]   VARCHAR (24)  NOT NULL,
    [AccessionNumber] VARCHAR (7)   NOT NULL,
    [UcpEmployeeId]   VARCHAR (11)  NULL,
    [Notes]           VARCHAR (MAX) NULL
);

