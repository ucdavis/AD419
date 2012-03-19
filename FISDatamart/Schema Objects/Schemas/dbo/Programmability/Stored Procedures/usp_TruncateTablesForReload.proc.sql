-- =============================================
-- Author:		Ken Taylor
-- Create date: 2011-02-03
-- Description:	Truncate all the non-manually loaded tables to allow programatic reload.
-- Modifications:
--	20110301 by kjt:
--		Added Trans, TransLog and PendingTrans to tables truncated.
--	20110420 by kjt:
--		Replaced GeneralLedgerPeriodBalances with GeneralLedgerProjectBalanceForAllPeriods
-- =============================================
CREATE PROCEDURE [dbo].[usp_TruncateTablesForReload] 
	-- Add the parameters for the stored procedure here
	@IsDebug bit = 0 --Set this to 1 to not execute, and just print SQL only
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	DECLARE @TSQL varchar(MAX) = ''

    -- Insert statements for procedure here
	SELECT @TSQL = '	TRUNCATE  TABLE dbo.Accounts

	TRUNCATE TABLE dbo.AccountType

	TRUNCATE TABLE dbo.BalanceTypes

	TRUNCATE TABLE dbo.BillingIDConversions

	TRUNCATE TABLE dbo.DocumentOriginCodes

	TRUNCATE TABLE dbo.DocumentTypes

	TRUNCATE TABLE dbo.FundGroups

	TRUNCATE TABLE dbo.GeneralLedgerProjectBalanceForAllPeriods

	TRUNCATE TABLE dbo.HigherEducationFunctionCodes

	TRUNCATE TABLE dbo.Objects

	TRUNCATE TABLE dbo.ObjectSubTypes

	TRUNCATE TABLE dbo.ObjectTypes

	TRUNCATE TABLE dbo.OPFund

	TRUNCATE TABLE dbo.Projects

	TRUNCATE TABLE dbo.SubAccounts

	TRUNCATE TABLE dbo.SubFundGroups

	TRUNCATE TABLE dbo.SubFundGroupTypes

	TRUNCATE TABLE dbo.SubObjects

	IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N''[dbo].[FK_Accounts_Organizations]'') AND parent_object_id = OBJECT_ID(N''[dbo].[Accounts]''))
	ALTER TABLE [dbo].[Accounts] DROP CONSTRAINT [FK_Accounts_Organizations]

	TRUNCATE TABLE dbo.Organizations

	ALTER TABLE [dbo].[Accounts]  WITH NOCHECK ADD  CONSTRAINT [FK_Accounts_Organizations] FOREIGN KEY([Year], [Period], [Org], [Chart])
	REFERENCES [dbo].[Organizations] ([Year], [Period], [Org], [Chart])
	NOT FOR REPLICATION 

	ALTER TABLE [dbo].[Accounts] NOCHECK CONSTRAINT [FK_Accounts_Organizations]
	
	TRUNCATE TABLE dbo.Trans
	
	TRUNCATE TABLE dbo.PendingTrans
	
	TRUNCATE TABLE dbo.TransLog
'

	IF @IsDebug = 1
		BEGIN
			PRINT @TSQL
		END
	ELSE
		BEGIN
			EXEC (@TSQL)		
		END
END
