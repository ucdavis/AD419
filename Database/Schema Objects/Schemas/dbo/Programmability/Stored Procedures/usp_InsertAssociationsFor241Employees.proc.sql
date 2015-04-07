-- =============================================
-- Author:		Ken Taylor
-- Create date: November 26, 2014
-- Description:	Insert associations for all 241 employees 
-- using the Expenses, PI_Match and PI_Names tables.
-- =============================================
CREATE PROCEDURE [dbo].[usp_InsertAssociationsFor241Employees] 
	@IsDebug bit = 0 -- Set this to 1 to print SQL statements created by procedure only.
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

  --DECLARE @IsDebug bit = 0
  -- Preparation for Step 1:
  -- Use this for getting expenses for each PI in an OrgR
  DECLARE @ExpensesTable TABLE (OrgR varchar(4),Expenses float, FTE float, EID varchar(20),ExpenseID int)

  -- This will get all the 241 expenses with PI name matches.
  INSERT INTO @ExpensesTable
  select t1.OrgR, t1.expenses, t1.FTE, t1.eid, t1.expenseId from expenses t1
  INNER JOIN PI_Names t2 ON t1.EID = t2.EID AND t1.OrgR = T2.OrgR 
  WHERE t1.FTE_sfn = '241' and (t1.OrgR NOT LIKE 'ACL%'  AND t1.OrgR NOT LIKE 'ADNO') AND t1.isAssociated = 0
  group by t1.OrgR, t1.EID, t1.ExpenseId, t1.Expenses, t1.FTE
  Order BY t1.OrgR, t1.EID, t1.ExpenseId, t1.Expenses, t1.FTE

   IF @IsDebug = 1
	SELECT t1.* FROM @ExpensesTable t1

  -- Use this for getting the OrgR, EID, accession, and num projects per EID
  DECLARE @PI_Accession TABLE (OrgR varchar(4), EID varchar(20), Accession varchar(20), NumProjects int )
  INSERT INTO @PI_Accession
  SELECT t1.OrgR, t1.EID, t1.Accession, NumProjects
  FROM [dbo].PI_Match T1
  LEFT OUTER JOIN (
	SELECT  OrgR, EID, Count(*) NumProjects
	FROM [dbo].PI_Match
	WHERE PI_Match IS NOT NULL AND (OrgR NOT LIKE 'ACL%'  AND OrgR NOT LIKE 'ADNO')
	GROUP BY OrgR, EID
  ) T2 ON t1.OrgR = t2.OrgR AND T1.EID = t2.EID
  WHERE t1.EID IS NOT NULL AND (t1.OrgR NOT LIKE 'ACL%'  AND t1.OrgR NOT LIKE 'ADNO')
  ORDER BY t1.OrgR, t1.EID, t1.Accession

  IF @IsDebug = 1
	SELECT * FROM @PI_Accession

   PRINT '
   ----------------------------------------------------------------------------------
   -- Step 1: 241 PI Expense Associations:
   ----------------------------------------------------------------------------------'
  /*
  Foreach expense get the projects for the matching EID
  divide the expense and FTE by the count per the EID
  and call usp_insertAssociation for the appropriate amount.
  */
 
  DECLARE expenseCursor CURSOR FOR SELECT * FROM @ExpensesTable
  OPEN expenseCursor
  DECLARE @OrgR varchar(4),@Expenses float , @FTE float, @EID varchar(20), @ExpenseID int
  FETCH NEXT FROM expenseCursor INTO @OrgR, @Expenses, @FTE, @EID, @ExpenseID
  WHILE @@FETCH_STATUS <> -1
  BEGIN
	 DECLARE projectCursor CURSOR FOR SELECT * FROM @PI_Accession WHERE EID = @EID AND OrgR = @OrgR
	 OPEN projectCursor
	 DECLARE @OrgR2 varchar(4), @EID2 varchar(20), @Accession varchar(20), @NumProjects int
	 FETCH NEXT FROM projectCursor INTO @OrgR2, @EID2, @Accession, @NumProjects
	 WHILE @@FETCH_STATUS <> -1
	 BEGIN
		DECLARE @TSQL varchar(MAX) = ''
		SELECT @TSQL = '
		-- Num Projects: ' + CONVERT(varchar(10), @NumProjects) + '
		-- Expenses: ' + CONVERT(varchar(20), @Expenses) + '
		-- FTE: ' + CONVERT(varchar(20), @FTE) + '
		EXEC [dbo].[usp_insertAssociation]
		@ExpenseID = ' + CONVERT(varchar(100), @ExpenseID) + ',
		@OrgR = ''' + @OrgR + ''',
		@Accession = ''' + @Accession + ''',
		@Expenses = ' + CONVERT(varchar(20), @Expenses / @NumProjects) + ',
		@FTE = ' + CONVERT(varchar(20), @FTE / @NumProjects) + ''

		IF @IsDebug = 1
			PRINT @TSQL
		ELSE
			BEGIN
				PRINT @TSQL
				EXEC (@TSQL)
			END

		FETCH NEXT FROM projectCursor INTO @OrgR2, @EID2, @Accession, @NumProjects
	 END
	 CLOSE projectCursor
	 DEALLOCATE projectCursor

	 FETCH NEXT FROM expenseCursor INTO @OrgR, @Expenses, @FTE, @EID, @ExpenseID
  END
  CLOSE expenseCursor
  DEALLOCATE expenseCursor

  -- Preparation for Step 2:
  -- Setup the OrgR table, PI_Names table, OrgR_Projects table, and Expenses table for 
  -- 241 NON-PI expenses to be pro-rated equally across all of an organization's projects:
  --
    -- Get a list of all organizations:
  	DECLARE @OrgRTable TABLE (OrgR varchar(4), [Org-Dept] varchar(200))
	INSERT INTO @OrgRTable
	EXEC [dbo].[usp_getReportingOrg]

	-- Remove those not normally associated, meaning the ones that are not administrativly prorated.
	DELETE FROM @OrgRTable WHERE OrgR  LIKE 'ACL%'  OR OrgR  LIKE 'ADNO' 

	DECLARE @PI_Names TABLE (OrgR varchar(4), EmployeeName varchar(200), EID varchar(10), PI varchar(100))
	DECLARE @OrgProjects TABLE (OrgR varchar(4), Project Varchar(50), Accession varchar(50), PI varchar(100), NumProjects int )

	DECLARE OrgR_Cursor CURSOR FOR SELECT OrgR FROM @OrgRTable

	-- Populate the PI_Names and OrgR_Projects tables: 
	--DECLARE @OrgR varchar(4)
	OPEN OrgR_Cursor
	FETCH NEXT FROM OrgR_Cursor INTO @OrgR
	WHILE @@FETCH_STATUS <> -1
	BEGIN
		-- Insert all the employees for a particular org:
		INSERT INTO @PI_Names
		SELECT TOP 1000 [OrgR]
			  ,[EmployeeName]
			  ,[EID]
			  ,[PI]
		  FROM [AD419].[dbo].[PI_Names]
		  where OrgR = @OrgR

		  -- Insert all the projects for a particular org:
		  INSERT INTO @OrgProjects (Project, Accession, PI)
		  EXEC usp_getProjectsByDept @OrgR = @OrgR

		  -- Set the Org's name:
		  UPDATE @OrgProjects
		  SET OrgR = @OrgR
		  WHERE OrgR IS NULL

		  FETCH NEXT FROM OrgR_Cursor INTO @OrgR
	END
	  IF @IsDebug = 1
	  BEGIN
		SELECT 'List of Non-PI 241 Employees:'
		SELECT t1.*, t2.PI_Match FROM @PI_NAMES t1
		LEFT OUTER JOIN PI_Match t2 ON t1.EID = t2.EID AND t1.OrgR = T2.OrgR
		WHERE PI_Match IS NULL
	  END

	  -- Clear out PI expenses inserted from Step 1:
	  DELETE @ExpensesTable

	  -- Populate the list of expenses for 241 employees whom do not have projects in the corresponding orgs,
	  -- meaning there is no PI match for the given org:
	  -- These employees are the ones that will need to have their expenses prorated across all of their org's 
	  -- projects.
	  INSERT INTO @ExpensesTable
	  select t1.OrgR, t1.expenses, t1.FTE, t1.eid, t1.expenseId from expenses t1
	  LEFT OUTER JOIN PI_Match t2 ON t1.EID = t2.EID AND t1.OrgR = T2.OrgR
	  WHERE PI_Match IS NULL AND t1.FTE_sfn = '241' and (t1.OrgR NOT LIKE 'ACL%'  AND t1.OrgR NOT LIKE 'ADNO') AND t1.isAssociated = 0
	  group by t1.OrgR, t1.EID, t1.ExpenseId, t1.Expenses, t1.FTE
	  Order BY t1.OrgR, t1.EID, t1.ExpenseId, t1.Expenses, t1.FTE

	   IF @IsDebug = 1
		 BEGIN
			SELECT * FROM @ExpensesTable
			SELECT * FROM @OrgProjects
			SELECT OrgR, Count(*) NumProjects 
			FROM @OrgProjects
			GROUP BY OrgR
		 END

		  -- Update the OrgProjects table with the number of projects for each org:
		  -- We'll use this value later as a divisor for the individual expenses per org.
		  UPDATE @OrgProjects
		  SET NumProjects = t2.NumProjects
		  FROM @OrgProjects t1
		  INNER JOIN (
		  SELECT OrgR, Count(*) NumProjects 
		  FROM @OrgProjects
		  GROUP BY OrgR
		  ) t2 ON t1.OrgR = T2.OrgR
		  WHERE t1.OrgR = t2.OrgR

   PRINT '
   ----------------------------------------------------------------------------------
   -- Step 2: 241 Non-PI Expense Associations:
   ----------------------------------------------------------------------------------'
  /*
  This portion handles associating expenses for each non-project PI
  Foreach Non-PI 241/OrgR expense insert an association for each OrgR project / num OrgR projects 
  meaning loop through and  each expense the number of OrgR project times and associate 1/number of OrgR Projects of the expense for each on the OrgR projects.
  */
	  DECLARE @OrgR3 varchar(4),@Expenses3 float , @FTE3 float, @EID3 varchar(20), @ExpenseID3 int
	  DECLARE nonProjectExpenseCursor CURSOR FOR SELECT * FROM @ExpensesTable
	  OPEN nonProjectExpenseCursor
	  FETCH NEXT FROM nonProjectExpenseCursor INTO @OrgR3, @Expenses3, @FTE3, @EID3, @ExpenseID3
	  WHILE @@FETCH_STATUS <> -1
	  BEGIN
		 DECLARE allProjectsCursor CURSOR FOR 
			SELECT Accession, NumProjects 
			FROM @OrgProjects 
			WHERE OrgR = @OrgR3
		 OPEN allProjectsCursor
		 DECLARE @Accession2 varchar(20), @NumProjects2 int
		 FETCH NEXT FROM allProjectsCursor INTO @Accession2, @NumProjects2
		 WHILE @@FETCH_STATUS <> -1
		 BEGIN
			--DECLARE @TSQL varchar(MAX) = ''
			SELECT @TSQL = '
			-- Num Projects: ' + CONVERT(varchar(10), @NumProjects2) + '
			-- Expenses: ' + CONVERT(varchar(20), @Expenses3) + '
			-- FTE: ' + CONVERT(varchar(20), @FTE3) + '
			EXEC [dbo].[usp_insertAssociation]
			@ExpenseID = ' + CONVERT(varchar(100), @ExpenseID3) + ',
			@OrgR = ''' + @OrgR3 + ''',
			@Accession = ''' + @Accession2 + ''',
			@Expenses = ' + CONVERT(varchar(20), @Expenses3 / @NumProjects2) + ',
			@FTE = ' + CONVERT(varchar(20), @FTE3 / @NumProjects2) + ''

			IF @IsDebug = 1
				PRINT @TSQL
			ELSE
				BEGIN
					PRINT @TSQL
					EXEC (@TSQL)
				END

			FETCH NEXT FROM allProjectsCursor INTO @Accession2, @NumProjects2
		 END
		 CLOSE allProjectsCursor
		 DEALLOCATE allProjectsCursor

		 FETCH NEXT FROM nonProjectExpenseCursor INTO @OrgR3, @Expenses3, @FTE3, @EID3, @ExpenseID3
	  END
	  CLOSE nonProjectExpenseCursor
	  DEALLOCATE nonProjectExpenseCursor

	SET NOCOUNT OFF;
END