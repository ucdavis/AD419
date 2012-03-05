﻿CREATE TABLE [dbo].[ARC_Codes] (
    [ARC_Cd]              CHAR (6)      NOT NULL,
    [ARC_Name]            VARCHAR (40)  NULL,
    [OP_Func_Name]        VARCHAR (40)  NULL,
    [DS_Last_Update_Date] SMALLDATETIME NULL,
    [isAES]               BIT           NULL
);


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Annual report codes used for creating the financial schedules', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'ARC_Codes';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Annual Report Code: Could also be considered a departmental report code for the Campus Financial Schedules. Code used to map individual accounts into one.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'ARC_Codes', @level2type = N'COLUMN', @level2name = N'ARC_Cd';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Annual Report Code Name: Name of this Annual Reporting Code.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'ARC_Codes', @level2type = N'COLUMN', @level2name = N'ARC_Name';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'OP Function Name: Most likely the function this ARC Code serves in relationship to the UC Office of the President.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'ARC_Codes', @level2type = N'COLUMN', @level2name = N'OP_Func_Name';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'DaFIS Last Update Date: The date this record was last loaded from transaction processing.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'ARC_Codes', @level2type = N'COLUMN', @level2name = N'DS_Last_Update_Date';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Is ARC Code [C]AES?: Is this ARC Code one that needs to be included in the CA&ES AD419 Annual Report?', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'ARC_Codes', @level2type = N'COLUMN', @level2name = N'isAES';

