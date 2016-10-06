-- =============================================
-- Author:		Ken Taylor
-- Create date: August 11, 2016
-- Description:	Repopulate the AD419 204 or 20x PPS, i.e. Labor Replated Expenses depending on the DataSource provided.
-- Usage:
/*
	-- for populating 20x PPS records:
	USE [AD419]
	GO

	DECLARE	@return_value int

	EXEC	@return_value = [dbo].[sp_Repopulate_AD419_20x_PPS_Expenses]
			@FiscalYear = 2015,
			@IsDebug = 0,
			@TableName = N'AllExpenses',
			@DataSource = '20x'

	SELECT	'Return Value' = @return_value

	GO

	--------------------------------------------------------------------

	-- for populating 204 PPS records:
	USE [AD419]
	GO

	DECLARE	@return_value int

	EXEC	@return_value = [dbo].[sp_Repopulate_AD419_20x_PPS_Expenses]
			@FiscalYear = 2015,
			@IsDebug = 0,
			@TableName = N'AllExpenses',
			@DataSource = '204'

	SELECT	'Return Value' = @return_value

	GO

	-- For populating all other non-204, non 20x FIS Expenses:
	USE [AD419]
	GO

	DECLARE	@return_value int

	EXEC	@return_value = [dbo].[sp_Repopulate_AD419_20x_PPS_Expenses]
			@FiscalYear = 2015,
			@IsDebug = 0,
			@TableName = N'AllExpenses',
			@DataSource = 'PPS'

	SELECT	'Return Value' = @return_value

	GO

*/
-- Dependencies:
--	 PPS_ExpensesFor204Projects (or PPS_ExpensesForNon204Projects*), and *20x data PPS data comes from here.
--	 FFY_SFN_Entries must be loaded first.
--
-- Modifications:
--	20160812 by kjt: Revised to let  @isAssociated bit = 1, @isAssociable bit = 0, @isNonEmpExp bit = 0 be populated from the 
--	underlying views
--	20160813 by kjt: Added square brackets around table name because sproc was failing when trying to display 
--		table name beginning with numbers, i.e. 20...
--		Also revised to use IsNonEmpExp instead of Sub_Exp_SFN field for determining whether an expense came from FIS or PPS data.
--	20160912 by kjt: Revised to use the project's department.
--	20160914 by kjt: Added RAISEERROR to return exceptions back to caller. 
--	20160921 by kjt: Removed RETURN -1 statement as it could not be used in this context.
-- =============================================
CREATE PROCEDURE [dbo].[sp_Repopulate_AD419_20x_PPS_Expenses] 
	-- Add the parameters for the stored procedure here
	@FiscalYear int = 2015,  -- Not used by kept here for consistancy in parameter signature with other sprocs 
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
		WHERE DataSource = @DataSource AND DataType = 'PPS'
	)
	IF @IsDebug = 1
		PRINT '-- DataTableName: ' +@DataTableName

	-- First check if their are any expense without OrgRs:
	SELECT @TSQL = '
	BEGIN
		DECLARE @NumBlankOrgs int = 0
		SELECT @NumBlankOrgs = (SELECT COUNT(*) 
		FROM [' + @DataTableName + ']
		WHERE OrgR IS NULL)
		IF @NumBlankOrgs > 0
		BEGIN
			DECLARE @ErrorMessage varchar(200) =  ''Not all PPS Expenses have OrgR assigned.  Assign departments beore proceeding!''
			'
			IF @IsDebug = 1
				SELECT @TSQL += 'PRINT ''-- '' + @ErrorMessage '  
	SELECT @TSQL += '
			RAISERROR(@ErrorMessage, 16, 1)
		END
	END
'
	SELECT @TSQL += '
	-- Delete old records first:
	DELETE FROM Associations WHERE ExpenseId IN (SELECT ExpenseId FROM ['+@TableName+'] WHERE DataSource = '''+ @DataSource + ''' AND [IsNonEmpExp] = 0)
	DELETE FROM ['+@TableName+'] WHERE DataSource = '''+ @DataSource + ''' AND [IsNonEmpExp] = 0
'
	SELECT @TSQL += '
	DECLARE PpsExpenseCursor CURSOR FOR
  SELECT 
	   [Accession]
      ,[Exp_SFN]
      ,[OrgR]
      ,[Org]
      ,[EID]
      ,[Employee_Name]
      ,[TitleCd]
      ,[Title_Code_Name]
      ,[Chart]
      ,[Account]
      ,[SubAcct]
      ,[PI_Name]
      ,[Expenses]
	  ,[IsAssociated]
	  ,[isAssociable]
	  ,[IsNonEmpExp]
      ,[Sub_Exp_SFN]
      ,[FTE]
      ,[FTE_SFN]
      ,[Staff_Grp_Cd]
  FROM [AD419].[dbo].[' + @DataTableName +'] FOR READ ONLY

  DECLARE 
	  @DataSource varchar(5) = '''+@DataSource+''',
	  @Accession varchar(10),
      @OrgR varchar(5),
      @Chart varchar(2),
      @Account varchar(7),
      @SubAcct varchar(5),
      @PI_Name varchar(50),
      @Org varchar(4),
      @EID varchar(9),
      @Employee_Name varchar(50),
      @TitleCd varchar(4),
      @Title_Code_Name varchar(50),
      @Exp_SFN varchar(5),
      @Expenses decimal(16,2),
      @FTE_SFN varchar(5),
      @FTE decimal(16,4),
      @isAssociated bit,
      @isAssociable bit,
      @isNonEmpExp bit,
      @Sub_Exp_SFN varchar(5),
      @Staff_Grp_Cd varchar(50),
	  @AccessionOrgR varchar(4)

	declare @ProjXOrgRCount int
	declare @IsAINT bit
	declare @IsAIND bit

	  OPEN PpsExpenseCursor
	  FETCH NEXT FROM PpsExpenseCursor INTO 
	      @Accession,
		  @Exp_SFN,
	      @OrgR,
		  @Org,
		  @EID,
		  @Employee_Name,
		  @TitleCd,
		  @Title_Code_Name,
		  @Chart,
		  @Account,
		  @SubAcct,
		  @PI_Name,
		  @Expenses,
		  @isAssociated,
		  @isAssociable,
		  @isNonEmpExp,
		  @Sub_Exp_SFN,
		  @FTE,
		  @FTE_SFN,
		  @Staff_Grp_Cd

	WHILE @@FETCH_STATUS <> -1
	BEGIN
		IF @Accession IS NOT NULL AND @Accession NOT LIKE ''''  -- This is not a 20x or 204 expense so do not perform orgR check
		BEGIN
			select @ProjXOrgRCount = 0
			select @IsAINT = 0
			select @IsAIND = 0
			select @AccessionOrgR = @OrgR

			select @ProjXOrgRCount = (SELECT COUNT(*)
			FROM         ProjXOrgR INNER JOIN
								  ReportingOrg ON ProjXOrgR.OrgR = ReportingOrg.OrgR
			WHERE     (ProjXOrgR.Accession = @Accession) AND 
					  (ProjXOrgR.OrgR = @OrgR) AND 
					  (ReportingOrg.IsActive = 1 OR ReportingOrg.OrgR IN (''AINT'', ''XXXX''))
					)
			If @ProjXOrgRCount = 0 
			Begin
				Select @IsAINT = (
					Select CASE WHEN -- Project''s OrgR IN (''AINT'', ''XXXX'')
					OrgR IN (''AINT'', ''XXXX'') THEN 1 ELSE 0 END
					from ReportingOrg where OrgR = (select OrgR from Project where Accession = @Accession)
				)
				If @IsAINT = 1 
					Begin
						Insert into ProjXOrgR(Accession, OrgR)
						values (@Accession, @OrgR)
					End
				Else
					Begin
						Select @IsAIND = (
							Select CASE OrgR WHEN ''AIND'' THEN 1 ELSE 0 END
							from ProjXOrgR where Accession = @Accession
						)
						If @IsAIND = 1
							Begin
								Select @OrgR = ''AIND''
							End

						Else --- The Expense''s department is different from the project''s department,
						-- so use the project''s department:
							Begin
								--RETURN -1
								--GOTO Fetch_Next
								-- Use the project''s Department:
								SELECT @AccessionOrgR = (SELECT OrgR FROM ProjXOrgR WHERE Accession = @Accession)
								IF @AccessionOrgR IS NULL
									GOTO Fetch_Next
							End
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
		  ,[EID]
		  ,[Employee_Name]
		  ,[TitleCd]
		  ,[Title_Code_Name]
		  ,[Exp_SFN]
		  ,[Expenses]
		  ,[FTE_SFN]
		  ,[FTE]
		  ,[isAssociated]
		  ,[isAssociable]
		  ,[isNonEmpExp]
		  ,[Sub_Exp_SFN]
		  ,[Staff_Grp_Cd]
		 )
		VALUES(
		  '''+ @DataSource +''', 
		   @OrgR,
		  @Chart,
		  @Account,
		  @SubAcct,
		  @PI_Name,
		  @Org,
		  @EID,
		  @Employee_Name,
		  @TitleCd,
		  @Title_Code_Name,
		  @Exp_SFN,
		  @Expenses,
		  @FTE_SFN,
		  @FTE,
		  @isAssociated,
		  @isAssociable,
		  @isNonEmpExp,
		  @Sub_Exp_SFN,
		  @Staff_Grp_Cd
		  )

		IF @Accession IS NOT NULL AND @Accession NOT LIKE ''''  -- This is not a 20x or 204 expense, so do not automatically associate
		BEGIN
			INSERT INTO Associations (ExpenseID, OrgR, Expenses, Accession, FTE)
			VALUES (SCOPE_IDENTITY(),@AccessionOrgR,@Expenses,@Accession, @FTE)
		END

		Fetch_Next:
		FETCH NEXT FROM PpsExpenseCursor INTO 
	      @Accession,
		  @Exp_SFN,
	      @OrgR,
		  @Org,
		  @EID,
		  @Employee_Name,
		  @TitleCd,
		  @Title_Code_Name,
		  @Chart,
		  @Account,
		  @SubAcct,
		  @PI_Name,
		  @Expenses,
		  @isAssociated,
		  @isAssociable,
		  @isNonEmpExp,
		  @Sub_Exp_SFN,
		  @FTE,
		  @FTE_SFN,
		  @Staff_Grp_Cd
	END

	CLOSE PpsExpenseCursor
	DEALLOCATE PpsExpenseCursor
'
	SELECT @TSQL += '
	UPDATE    [' + @TableName + ']
	SET              SubAcct = NULL
	WHERE     (SubAcct = ''-----'') AND DataSource = ''' + @DataSource + ''' AND [IsNonEmpExp] = 0

	UPDATE    [' + @TableName + ']
	SET              FTE = 0
	WHERE     (FTE IS NULL) AND DataSource = ''' + @DataSource + ''' AND [IsNonEmpExp] = 0

	UPDATE    [' + @TableName + ']
	SET              FTE_SFN = ''244'', Staff_Grp_Cd = ''Other''
	WHERE     (Staff_Grp_Cd IS NULL) AND DataSource = ''' + @DataSource + ''' AND [IsNonEmpExp] = 0
'
	SELECT @TSQL += '
	SELECT * from ['+@TableName+'] where DataSource = ''' + @DataSource +''' AND [IsNonEmpExp] = 0
	SELECT * FROM Associations where ExpenseID IN (select ExpenseID from [' + @TableName + '] where DataSource = ''' + @DataSource +''' AND [IsNonEmpExp] = 0)
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