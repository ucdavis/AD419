
-- Author: Ken Taylor
-- Modified On: 2020-07-31
-- Purpose: To update the PPS Datamart Persons table with data from UC Path
-- Usage:
/*

	EXEC [dbo].[usp_UpdatePersons]
		@FirstDate = null,
		@GetUpdatesOnly = 0,
		@IsDebug = 1

	GO

*/

-- Modifications:
-- 2020-07-31 by kjt: Modified for use with UCP_Persons view as datasource.
-- 2021-02-23 by kjt: Modified to use UCP_PersonsV2 view as datasource.

CREATE Procedure [dbo].[usp_UpdatePersons]
(
	@FirstDate varchar(16) = null,
		--earliest date to download (UCP_Persons.LastChangeDate) 
		--optional, defaults to highest date in dbo.Persons table
	@GetUpdatesOnly bit = 1, -- set to 0 if you want all the records since the first date.
							 --Only valid if a firstdate is provided.
	@IsDebug bit = 0 -- Set to 1 just print the SQL and not actually execute. 
)
AS
--local:
DECLARE @TSQL varchar(MAX)	--Holds T-SQL code to be run with EXEC() function.

DECLARE @MaxDate DATETIME
SELECT @MaxDate = (SELECT MAX(LastChangeDate) FROM PPSDataMart.dbo.Persons)

DECLARE @TableIsEmpty bit = 0
IF @MaxDate IS NULL 
	Select @TableIsEmpty = 1

declare @MyDate smalldatetime	--temp holder of dates as type smalldatetime
		-- Note regarding date formats: Need to pass date to Oracle using it's conversion
		-- function TO_DATE, for which a string type is need.  I'm using a varchar for the
		-- parameters here, but convert to a smalldatetime in order to make use of the
		-- DateAdd() function and formatting options in the conversion function CONVERT.
		
--If no parameters passed, default to day after greatest date in Persons table, else use param value(s):
	if @FirstDate IS NULL 
		--Attempt to read highest date in table currently and use this as @FirstDate value:
		IF @MaxDate IS NOT NULL
			BEGIN
				SELECT @MyDate = (SELECT cast(@MaxDate as smalldatetime))
				SELECT @FirstDate = convert(varchar(30), @MyDate, 102)
				--SELECT @FirstDate = convert(varchar(30),DateAdd(dd,1,@MyDate), 102)
			END
		ELSE
			BEGIN
				--Table is empty; download everything
				Select @GetUpdatesOnly = 0
			END
	else
		BEGIN
			SELECT @MyDate = convert(smalldatetime,@FirstDate)
			SELECT @MaxDate = @MyDate
			SELECT @FirstDate = convert(varchar(30), @MyDate, 102)
		END
		
	print '-- Downloading Persons records...'
	IF @GetUpdatesOnly = 1
	BEGIN
		print '-- Selecting records from UCP_PersonsV2 where UCP_PersonsV2.LastChangeDate >= ' + convert(varchar(30),convert(smalldatetime,@FirstDate),102) + ' (Earliest Date)'
		print '-- Update any matching records in the persons table where none have been updated previously'
		print '--  or where the UCP_PersonsV2.LastChangeDate > ' + Convert(varchar(30), @MaxDate, 110) + '.'
	END
	ELSE
		print '-- Selecting all records from UCP_PersonsV2.LastChangeDate'
		
	print '-- IsDebug = ' + CASE @IsDebug WHEN 1 THEN 'True (Just display SQL. Don''t update anything)' ELSE 'False (Run script)' END
	print '-------------------------------------------------------------------------'
	
select @TSQL = 
	'merge PPSDataMart.dbo.Persons Persons -- At this point the old persons table has been renamed to Persons_PPS.
											-- so we''re using reusing Persons for the UCP Personnel data.
	using
	(
	SELECT
	   [EmployeeID]
      ,[FirstName]
      ,[MiddleName]
      ,[LastName]
	  ,[FullName]
      ,[Suffix]
      ,[BirthDate]
      ,[UCDMailID]
      ,[UCDLoginID]
      ,[HomeDepartment]
      ,[AlternateDepartment]
      ,[AdministrativeDepartment]
      ,[SchoolDivision]
      ,[PrimaryTitle]
      ,[PrimaryApptNo]
      ,[PrimaryDistNo]
      ,[JobGroupID]
      ,[HireDate]
      ,[OriginalHireDate]
      ,[EmployeeStatus]
      ,[StudentStatus]
      ,[EducationLevel]
      ,[BarganingUnit]
      ,[LeaveServiceCredit]
      ,[Supervisor]
      ,[LastChangeDate]
      ,[IsInPPS]
      ,[PPS_ID]
      ,[UCP_EMPLID]
      ,[HasUcpEmplId]
 FROM [dbo].[UCP_PersonsV2]	
 '
	IF @GetUpdatesOnly = 1
		SELECT @TSQL += '
WHERE (LastChangeDate IS NULL OR LastChangeDate >= ''' + Convert(varchar(30), @MaxDate, 101) + ''')
 '
		
SELECT @TSQL += '
) UcpPersons on Persons.EmployeeID = UcpPersons.EmployeeID

	WHEN MATCHED THEN UPDATE set
	   [FirstName] = UcpPersons.FirstName
      ,[MiddleName] = UcpPersons.MiddleName
      ,[LastName] = UcpPersons.LastName
      ,[FullName] = UcpPersons.FullName
      ,[Suffix] = UcpPersons.Suffix
      ,[BirthDate] = UcpPersons.BirthDate
      ,[UCDMailID] = UcpPersons.UCDMailID
      ,[UCDLoginID] = UcpPersons.UCDLoginID
      ,[HomeDepartment] = UcpPersons.HomeDepartment
      ,[AlternateDepartment] = UcpPersons.AlternateDepartment
      ,[AdministrativeDepartment] = UcpPersons.AdministrativeDepartment
      ,[SchoolDivision] = UcpPersons.SchoolDivision
      ,[PrimaryTitle] = UcpPersons.PrimaryTitle
      ,[PrimaryApptNo] = UcpPersons.PrimaryApptNo
      ,[PrimaryDistNo] = UcpPersons.PrimaryDistNo
      ,[JobGroupID] = UcpPersons.JobGroupID
      ,[HireDate] = UcpPersons.HireDate
      ,[OriginalHireDate] = UcpPersons.OriginalHireDate
      ,[EmployeeStatus] = UcpPersons.EmployeeStatus
      ,[StudentStatus] = UcpPersons.StudentStatus
      ,[EducationLevel] = UcpPersons.EducationLevel
      ,[BarganingUnit] = UcpPersons.BarganingUnit
      ,[LeaveServiceCredit] = UcpPersons.LeaveServiceCredit
      ,[Supervisor] = UcpPersons.Supervisor
      ,[LastChangeDate] = UcpPersons.LastChangeDate
      ,[IsInPPS] = UcpPersons.IsInPPS
	  ,[UCP_EMPLID] = UcpPersons.[UCP_EMPLID]
	  ,[HasUcpEmplId] = 1
      
    WHEN NOT MATCHED BY TARGET THEN INSERT VALUES 
      (
      [EmployeeID]
      ,[FirstName]
      ,[MiddleName]
      ,[LastName]
	  ,[FullName]
      ,[Suffix]
      ,[BirthDate]
      ,[UCDMailID]
      ,[UCDLoginID]
      ,[HomeDepartment]
      ,[AlternateDepartment]
      ,[AdministrativeDepartment]
      ,[SchoolDivision]
      ,[PrimaryTitle]
      ,[PrimaryApptNo]
      ,[PrimaryDistNo]
      ,[JobGroupID]
      ,[HireDate]
      ,[OriginalHireDate]
      ,[EmployeeStatus]
      ,[StudentStatus]
      ,[EducationLevel]
      ,[BarganingUnit]
      ,[LeaveServiceCredit]
      ,[Supervisor]
      ,[LastChangeDate]
      ,[IsInPPS]
      ,[PPS_ID]
      ,[UCP_EMPLID]
      ,[HasUcpEmplId]
      )
	WHEN NOT MATCHED BY SOURCE THEN 
		UPDATE
		SET IsInPPS = 0
	;'
	
	-------------------------------------------------------------------------
	
	if @IsDebug = 1
		BEGIN
			--used for testing
			PRINT @TSQL	
		END
	else
		BEGIN
			--Execute the command:
			EXEC(@TSQL)
		END
		
	 print '-------------------------------------------------------------------------'
