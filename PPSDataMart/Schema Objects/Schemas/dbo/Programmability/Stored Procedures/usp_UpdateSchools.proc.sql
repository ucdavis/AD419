create Procedure [dbo].[usp_UpdateSchools]
(
	@IsDebug bit = 0 -- Set to 1 just print the SQL and not actually execute.
)

AS

--local:
DECLARE @TSQL varchar(MAX)	--Holds T-SQL code to be run with EXEC() function.


select @TSQL = 
	'merge PPSDataMart.dbo.Schools Schools
	using
	(
	SELECT 
		SCH_CODE, 
		SCH_SHORT_DESC, 
		SCH_LONG_DESC, 
		SCH_ABBRV 
	FROM OPENQUERY(PAY_PERS_EXTR, ''
		SELECT 
			SCH_CODE, 
			SCH_SHORT_DESC, 
			SCH_LONG_DESC, 
			SCH_ABBRV 
		FROM PAYROLL.DVTSCH	
'')
) DVTSCH on Schools.SchoolCode = DVTSCH.SCH_CODE

	WHEN MATCHED THEN UPDATE set
		 [ShortDescription] = SCH_SHORT_DESC
		,[LongDescription] = SCH_LONG_DESC
		,[Abbreviation] = SCH_ABBRV
		
	 WHEN NOT MATCHED BY TARGET THEN INSERT VALUES 
      (
		SCH_CODE, 
		SCH_SHORT_DESC, 
		SCH_LONG_DESC, 
		SCH_ABBRV 
	  )
	  
--	WHEN NOT MATCHED BY SOURCE THEN DELETE
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
