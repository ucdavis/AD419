CREATE TABLE [dbo].[EmploymentStatusCodes] (
    [Code]        CHAR (1)     NOT NULL,
    [Description] VARCHAR (50) NOT NULL,
    CONSTRAINT [PK_EmployeeStatusCodes] PRIMARY KEY CLUSTERED ([Code] ASC)
);




GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Reference table containing all the possible codes that indicate individuals university employment status. (values are A=active, I=inactive, N=leave without pay, P=leave with pay, S=separated) 
(Taken from the PPS data dictionary EMP_STATUS field description.)', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'EmploymentStatusCodes';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Description: Translation of what the employment status code stands for.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'EmploymentStatusCodes', @level2type = N'COLUMN', @level2name = N'Description';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Employment status code: The code indicating an individual''s university employment status. (values are A=active, I=inactive, N=leave without pay, P=leave with pay, S=separated) ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'EmploymentStatusCodes', @level2type = N'COLUMN', @level2name = N'Code';

