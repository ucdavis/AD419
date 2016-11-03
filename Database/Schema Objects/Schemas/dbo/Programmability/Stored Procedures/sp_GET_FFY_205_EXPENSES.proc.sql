

GO
EXECUTE sp_addextendedproperty @name = N'Description', @value = N'This procedure gets the 205 Expenses for the Federal Fiscal year and attempts to associate them with their  accession numbers using the award number or  the 4-digit numeric component of the project number if the association cannot be made using the full project/award number.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'PROCEDURE', @level1name = N'sp_GET_FFY_205_EXPENSES';


GO
EXECUTE sp_addextendedproperty @name = N'Parameter 1', @value = N'@FiscalYear: The Federal fiscal year for the current reporting period.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'PROCEDURE', @level1name = N'sp_GET_FFY_205_EXPENSES';


GO
EXECUTE sp_addextendedproperty @name = N'Parameter 2', @value = N'@IsDebug: Set this bit to 1 to not execute, but only print the SQL instead.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'PROCEDURE', @level1name = N'sp_GET_FFY_205_EXPENSES';

