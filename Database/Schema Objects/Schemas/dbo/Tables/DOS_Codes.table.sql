CREATE TABLE [dbo].[DOS_Codes] (
    [DOS_Code]          VARCHAR (3)    NOT NULL,
    [Description]       NVARCHAR (255) NULL,
    [IncludeInAD419FTE] BIT            NULL,
    [IsNewInUCP]        INT            NULL,
    CONSTRAINT [PK_DOS_Codes_1] PRIMARY KEY CLUSTERED ([DOS_Code] ASC)
);





