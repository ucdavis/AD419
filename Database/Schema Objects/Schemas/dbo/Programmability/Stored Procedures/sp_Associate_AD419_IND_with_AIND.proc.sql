
-- =============================================
-- Author:		Ken Taylor
-- Create date: 02/04/2010
-- Description:	Changes independent expenses' OrgR (identified by account
-- AGARGAA) from whatever they are, probably ADNO, to AIND so that they can
-- show up under department AIND and can be associated from the UI.
--
-- Usage:
/*
	USE [AD419]
	GO

	EXEC [dbo].[sp_Associate_AD419_IND_with_AIND] @IsDebug = 1
	GO

*/
-- Modifications:
--
-- [12/17/2010] by kjt: Revised to use AllExpenses, table (formerly Expenses) instead of new Expenses view.
-- [11/21/2019] by kjt: Revised to also change orgs on  SFN 202 accounts L-ADOCT01 and L-ADOCT02 that we use
--	 to charge a portion of Cary’s payroll as per Shannon Tanguay.
-- =============================================
CREATE PROCEDURE [dbo].[sp_Associate_AD419_IND_with_AIND] 
	-- Add the parameters for the stored procedure here
	@IsDebug bit = 0 -- set this to 1 if you just want to print the SQL.
AS
BEGIN
	declare @TSQL varchar(max) = ''
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	--Update the OrgR of all FIS-sourced and PPS-sourced expense records
	-- that have an Account of 'AGARGAA' from ADNO to AIND.
	-- This allows Steve the ability to associate these expenses from the GUI.

	Select @TSQL = '
	UPDATE AllExpenses 
	SET OrgR = ''AIND'' 
	WHERE Account = ''AGARGAA'' OR
	(Chart = ''L'' AND Account IN (''ADOCT01'', ''ADOCT02''))
	'
	If @IsDebug = 1
		Begin
			PRINT '-- Updating OrgR from ADNO to AIND...'
			Print @TSQL
		End
	ELSE
		Begin
			EXEC(@TSQL)
		End
END
