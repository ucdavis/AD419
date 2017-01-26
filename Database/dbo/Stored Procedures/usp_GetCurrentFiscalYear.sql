-- =============================================
-- Author:		Ken Taylor
-- Create date: November 2, 2016
-- Description:	Returns the Current Fiscal Year for the AD-419 Reporting Year
-- Usage:
/*
	DECLARE @FiscalYear int
	EXECUTE dbo.usp_GetCurrentFiscalYear @CurrentFiscalYear = @FiscalYear OUTPUT
	print 'Current Fiscal year: ' + CONVERT(varchar(4), @FiscalYear)
*/
-- Modifications:
--
-- =============================================
CREATE PROCEDURE usp_GetCurrentFiscalYear 
	-- Add the parameters for the stored procedure here
	@CurrentFiscalYear int output
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	SELECT @CurrentFiscalYear = FiscalYear 
	FROM [dbo].[CurrentFiscalYear]

	RETURN_VALUE
END
GO
