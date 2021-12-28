-- =============================================
-- Author:		Ken Taylor
-- Create date: September 20, 2017
-- Description:	Changes Associate Dean's Title code 1010 expenses' OrgR from
-- the account's expense OrgR to ADNO, so that they can prorated 
-- across the entire college's projects as per conversation with Shannon Tanguay
-- and Brian McElliot, Wednesday, September 20, 2017 due to the new NIFA rules.
--	 
-- Note that these expenses will now longer be pre associated or show up under 
-- the account department expenses that can be associated from the UI.
--
-- Usage: 
/*
	USE [AD419]
	GO

	EXEC [dbo].[usp_RemapAssociateDeansExpenseDepartmentsToADNO] @IsDebug = 0

*/
--
-- Modifications:
--
-- =============================================
CREATE PROCEDURE [dbo].[usp_RemapAssociateDeansExpenseDepartmentsToADNO] 
	-- Add the parameters for the stored procedure here
	@IsDebug bit = 0 -- set this to 1 if you just want to print the SQL.
AS
BEGIN
	declare @TSQL varchar(max) = ''
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	-- Update the OrgR of all PPS-sourced expense records
	-- that have a title code of 1010 from their expense's department to ADNO.
	-- This allows the AD-419 program the ability to prorate these expenses, and
	-- hide them from the GUI.

	Select @TSQL = 'UPDATE AllExpenses set OrgR = ''ADNO'' where TitleCd = ''1010''
	'
	If @IsDebug = 1
		Begin
			PRINT '-- Updating OrgR from Expense''s Department to ADNO for Associate Deans (TitleCd 1010)...'
			Print @TSQL
		End
	ELSE
		Begin
			EXEC(@TSQL)
		End
END