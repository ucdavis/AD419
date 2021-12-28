

-- =============================================
-- Author:		Ken Taylor
-- Create date: August 11, 2016
-- Description:	Repopulate the AD419 204 or 20x FIS Expenses depending on the DataSource provided.
-- Usage:
/*
	-- for populating 20x FIS records:
	USE [AD419]
	GO

	DECLARE	@return_value int

	EXEC	@return_value = [dbo].[sp_Repopulate_AD419_20x_FIS_Expenses]
			@FiscalYear = 2021,
			@IsDebug = 0,
			@TableName = N'AllExpenses',
			@DataSource = '20x'

	SELECT	'Return Value' = @return_value

	GO

	--------------------------------------------------------------------

	-- for populating 204 FIS records:
	USE [AD419]
	GO

	DECLARE	@return_value int

	EXEC	@return_value = [dbo].[sp_Repopulate_AD419_20x_FIS_Expenses]
			@FiscalYear = 2016,
			@IsDebug = 1,
			@TableName = N'AllExpenses',
			@DataSource = '204'

	SELECT	'Return Value' = @return_value

	GO

	--------------------------------------------------------------------

	-- for populating non-204, non-20x FIS records:
	USE [AD419]
	GO

	DECLARE	@return_value int

	EXEC	@return_value = [dbo].[sp_Repopulate_AD419_20x_FIS_Expenses]
			@FiscalYear = 2016,
			@IsDebug = 1,
			@TableName = N'AllExpenses',
			@DataSource = 'FIS'

	SELECT	'Return Value' = @return_value

	GO
*/
-- Dependencies:
--	 FIS_ExpensesFor204Projects (or FIS_ExpensesForNon204Projects*), and *20x data FIS data comes from here.
--	 FFY_SFN_Entries must be loaded first.
--
-- Modifications:
--	20160812 by kjt: Revised to only associate is Accession is not null, plus use @isAssociated, @isAssociable, and @IsNonEmpExp
--	provided by source view.
--	20160813 by kjt: Fixed issue with not updating SQL to use @TableName provided.
--		Revised filtering to use [isNonEmpExp] = 1 Vs. Sub_Exp_SFN
--	20160912 by kjt: Revised to use the project's department.
--	20160914 by kjt: Added RAISEERROR to return exceptions back to caller.
--	20160921 by kjt: Removed RETURN -1 statement as it could not be used in this context.
--	20171016 by kjt: Added ProjXOrgR remapping so we'd not attempt to add another entry to ProjXorgR
--		when the remapped OrgR was present and not the expense OrgR.
--	20201120 by kjt: Added check to see if the AINT orgR was already in ProjXOrgR before 
--	attempting to insert it (again), in order to avoid primary key violation.
--	20211111 by kjt: Removed the old logic that added an OrgR to the ProjXOrgR table, as we've already added
--		all the records in a previous, so this step is no longer necessary.  Also, according to Shannon, PIs
--		share their grant money with other researchers in other departments to help work on their projects.  
--		Therefore, the project's department(s) may not be correct for the expense, so we're just keeping the
--		original expenses OrgR with any OrgR remapping, and not changing it over to the project's department.
--		What this means, is we'll only see the expense in the final report, not in any of the UIs related to the 
--		department's expenses, since the project does not map to the expense's department, 
-- 
-- =============================================
CREATE PROCEDURE [dbo].[sp_Repopulate_AD419_20x_FIS_Expenses] 
	-- Add the parameters for the stored procedure here
	@FiscalYear int = 2016,  -- Not used by kept here for consistency in parameter signature with other sprocs 
	@IsDebug bit = 0,
	@TableName varchar(100) = 'AllExpenses',
	@DataSource varchar(5) = '204' -- This needs to be either '204' or '20x'
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	--DECLARE @DataSource varchar(5) = '204'
    DECLARE @TSQL varchar(MAX) = ''

	-- Lookup table name based on datasource provided:
	DECLARE @DataTableName varchar(100) = ''
	SELECT @DataTableName = (
		SELECT DataTableName
		FROM [dbo].[DataSourceTableNameLookup]
		WHERE DataSource = @DataSource AND DataType = 'FIS'
	)
	IF @IsDebug = 1
		PRINT '-- DataTableName: ' +@DataTableName + '
'

	-- First check if their are any expense without OrgRs:
	SELECT @TSQL = '
	BEGIN
		DECLARE @NumBlankOrgs int = 0
		SELECT @NumBlankOrgs = (SELECT COUNT(*) 
		FROM [' + @DataTableName + ']
		WHERE OrgR IS NULL)
		IF @NumBlankOrgs > 0
		BEGIN
			DECLARE @ErrorMessage varchar(200) =  ''Not all FIS Expenses have OrgR assigned.  Assign departments before proceeding!''
			'
			IF @IsDebug = 1
				SELECT @TSQL += 'PRINT ''-- '' + @ErrorMessage + ''
'''  
	SELECT @TSQL += '
			RAISERROR(@ErrorMessage, 16, 1)
		END
	END
'
	SELECT @TSQL += '
	-- Delete old records first:
	DELETE FROM Associations WHERE ExpenseId IN (SELECT ExpenseId FROM [' + @TableName + '] WHERE DataSource = '''+ @DataSource + ''' AND [isNonEmpExp] = 1)
	DELETE FROM [' + @TableName + ']  WHERE DataSource = '''+ @DataSource + ''' AND [isNonEmpExp] = 1
'
	SELECT @TSQL += '
	DECLARE FisExpenseCursor CURSOR FOR
	SELECT 
	   [Accession]
      ,[Exp_SFN]
      ,[OrgR]
	  ,[AD419OrgR]
      ,[Org]
      ,[' + @DataTableName +'].[Chart]
      ,[Account]
      ,[SubAcct]
      ,[PI_Name]
      ,[Expenses]
	  ,[isAssociated]
	  ,[isAssociable]
	  ,[isNonEmpExp]
      ,[Sub_Exp_SFN]
  FROM [dbo].[' + @DataTableName +'] 
  LEFT OUTER JOIN [dbo].[ExpenseOrgR_X_AD419OrgR] ON [dbo].[' + @DataTableName +'].Chart = [dbo].[ExpenseOrgR_X_AD419OrgR].Chart AND
	[dbo].[' + @DataTableName +'].Org =  [dbo].[ExpenseOrgR_X_AD419OrgR].ExpenseOrg FOR READ ONLY

  DECLARE 
	  @DataSource varchar(5) = '''+@DataSource+''',
	  @Accession varchar(10),
      @OrgR varchar(5),
	  @AD419OrgR varchar(4),
      @Chart varchar(2),
      @Account varchar(7),
      @SubAcct varchar(5),
      @PI_Name varchar(50),
      @Org varchar(4),
      @Exp_SFN varchar(5),
      @Expenses decimal(16,2),
      @isAssociated bit,
      @isAssociable bit,
      @isNonEmpExp bit,
      @Sub_Exp_SFN varchar(5),
	  @FTE decimal(16,4) = 0,
	  @AccessionOrgR varchar(4)

	declare @ProjXOrgRCount int
	declare @IsAINT bit
	declare @IsAIND bit

	  OPEN FisExpenseCursor
	  FETCH NEXT FROM FisExpenseCursor INTO 
	      @Accession,
		  @Exp_SFN,
	      @OrgR,
		  @AD419OrgR,
		  @Org,
		  @Chart,
		  @Account,
		  @SubAcct,
		  @PI_Name,
		  @Expenses,
		  @isAssociated,
		  @isAssociable,
		  @isNonEmpExp,
		  @Sub_Exp_SFN

	WHILE @@FETCH_STATUS <> -1
	BEGIN
		IF @Accession IS NOT NULL AND @Accession NOT LIKE ''''
		BEGIN 
			select @ProjXOrgRCount = 0
			select @IsAIND = 0
			select @AccessionOrgR = @OrgR

			select @ProjXOrgRCount = (SELECT COUNT(*)
			FROM         ProjXOrgR INNER JOIN
								  ReportingOrg ON ProjXOrgR.OrgR = ReportingOrg.OrgR
			WHERE     (ProjXOrgR.Accession = @Accession) AND 
					  (ProjXOrgR.OrgR = COALESCE(@Ad419OrgR,@OrgR)) AND 
					  (ReportingOrg.IsActive = 1 OR ReportingOrg.OrgR IN (''AINT'', ''XXXX''))
					)
			If @ProjXOrgRCount = 0 
			Begin
				Select @IsAIND = (
						Select DISTINCT CASE OrgR WHEN ''AIND'' THEN 1 ELSE 0 END
						from ProjXOrgR where Accession = @Accession
				)
				If @IsAIND = 1
					Begin
						Select @OrgR = ''AIND'' --We''re updating the Expense''s OrgR since ''AIND'' is only valid for AD-419 purposes.
					End
				Else 
					Begin
							
						SELECT @AccessionOrgR = (COALESCE(@Ad419OrgR,@OrgR))
						IF @AccessionOrgR IS NULL
							GOTO Fetch_Next
					End
			End
		END

		INSERT INTO [' + @TableName + '] (
		   [DataSource]
		  ,[OrgR]
		  ,[Chart]
		  ,[Account]
		  ,[SubAcct]
		  ,[PI_Name]
		  ,[Org]
		  ,[Exp_SFN]
		  ,[Expenses]
		  ,[isAssociated]
		  ,[isAssociable]
		  ,[isNonEmpExp]
		  ,[Sub_Exp_SFN]
		 )
		VALUES(
		  '''+ @DataSource +''', 
		  @OrgR,
		  @Chart,
		  @Account,
		  @SubAcct,
		  @PI_Name,
		  @Org,
		  @Exp_SFN,
		  @Expenses,
		  @isAssociated,
		  @isAssociable,
		  @isNonEmpExp,
		  @Sub_Exp_SFN
		  )

		IF @Accession IS NOT NULL AND @Accession NOT LIKE ''''
		BEGIN
			INSERT INTO Associations (ExpenseID, OrgR, Expenses, Accession, FTE)
			VALUES (SCOPE_IDENTITY(),@AccessionOrgR,@Expenses,@Accession, @FTE)
		END

		Fetch_Next:
		FETCH NEXT FROM FisExpenseCursor INTO 
	      @Accession,
		  @Exp_SFN,
	      @OrgR,
		  @AD419OrgR,
		  @Org,
		  @Chart,
		  @Account,
		  @SubAcct,
		  @PI_Name,
		  @Expenses,
		  @isAssociated,
		  @isAssociable,
		  @isNonEmpExp,
		  @Sub_Exp_SFN
	END

	CLOSE FisExpenseCursor
	DEALLOCATE FisExpenseCursor
'
	SELECT @TSQL += '
	UPDATE    [' + @TableName + ']
	SET              SubAcct = NULL
	WHERE     (SubAcct = ''-----'') AND DataSource = ''' + @DataSource + ''' AND [isNonEmpExp] = 1

	UPDATE    [' + @TableName + ']
	SET              FTE = 0
	WHERE     (FTE IS NULL) AND DataSource = ''' + @DataSource + ''' AND [isNonEmpExp] = 1

	UPDATE    [' + @TableName + ']
	SET              FTE_SFN = ''244'', Staff_Grp_Cd = ''Other''
	WHERE     (Staff_Grp_Cd IS NULL) AND DataSource = ''' + @DataSource + ''' AND [isNonEmpExp] = 1 ;
'
	SELECT @TSQL += '
	SELECT * from [' + @TableName + '] where DataSource = ''' + @DataSource +''' AND [isNonEmpExp] = 1
	SELECT * FROM Associations where ExpenseID IN (select ExpenseID from [' + @TableName + '] where DataSource = ''' + @DataSource +''' AND [isNonEmpExp] = 1)
'
	IF @IsDebug = 1
		BEGIN
			SET NOCOUNT ON
			Print @TSQL
		END
	ELSE
		BEGIN
			EXEC(@TSQL)
		END
END