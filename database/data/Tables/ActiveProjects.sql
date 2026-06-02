CREATE TABLE [data].[ActiveProjects]
(
    [ProjectNumber] NVARCHAR(50) NOT NULL,
    [AccessionNumber] NVARCHAR(50) NOT NULL,
    [UcpEmployeeId] NVARCHAR(50) NOT NULL,
    [UcPathName] NVARCHAR(200) NOT NULL,
    [Is204] BIT NOT NULL,
    [ExcludeFromUi] BIT NULL,
    [Notes] NVARCHAR(MAX) NULL,
    [ProjectDirector] NVARCHAR(200) NOT NULL,
    [PdEmailAddress] NVARCHAR(320) NOT NULL,
    CONSTRAINT [PK_ActiveProjects] PRIMARY KEY CLUSTERED ([ProjectNumber], [AccessionNumber])
);
