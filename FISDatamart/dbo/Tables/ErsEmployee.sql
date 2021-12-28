CREATE TABLE [dbo].[ErsEmployee] (
    [EmployeeId]   NCHAR (9)     NOT NULL,
    [PiInd]        NCHAR (1)     NULL,
    [EmployeeName] NVARCHAR (26) NOT NULL
);


GO
CREATE NONCLUSTERED INDEX [ErsEmployee_EmployeeID_NCI]
    ON [dbo].[ErsEmployee]([EmployeeId] ASC);

