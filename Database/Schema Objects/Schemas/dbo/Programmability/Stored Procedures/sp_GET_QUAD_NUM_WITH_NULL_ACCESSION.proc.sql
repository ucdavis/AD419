-- =============================================
-- Author:		Ken Taylor
-- Create date: November 19, 2009
-- Description:	This procedure gets the 202 Expenses for the Federal
-- Fiscal year and attempts to associate them with their
-- accession numbers using the award number or
-- the 4-digit numeric component of the project number
-- if the association cannot be made using the full 
-- project/award number.
-- =============================================
CREATE PROCEDURE [dbo].[sp_GET_QUAD_NUM_WITH_NULL_ACCESSION]
	-- Add the parameters for the stored procedure here
	@FiscalYear int = 2009, -- Note: Federal Fiscal Year, i.e. (Oct-June Final 2009 and July-Sept 2010)
	@InputTableName varchar(50) = 'Project',  -- Defaults to the Project table.
	@OutputTableName varchar(50) = 'SFN_PROJECT_QUAD_NUM', -- Defaults to 
	@IsDebug bit = 0 -- Set to 1 to print SQL only.
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	declare @TSQL varchar(MAX) = '';
	declare @QuadNums varchar(max) = '';
	declare @temp varchar(20) = '';

	-- This section builds a list of "QuadNumbers" from the projects that have null accession numbers
	-- in the FFY_xxxx_SFN_ENTRIES table.

	declare @TableName varchar(50) = 'FFY_' + Convert(char(4), @FiscalYear) + '_SFN_ENTRIES'
 
	Select @TSQL = 'declare MyCursor Cursor for 

	SELECT distinct SUBSTRING(AWARDNUM, 10, 4) as QuadNum 
	FROM [AD419].[dbo].[' + @TableName + ']
	where accession is null and CONVERT(int, SUBSTRING(AWARDNUM, 10, 4)) > 0 
 
	UNION
  
	SELECT distinct SUBSTRING(AWARDNUM, 11, 4) as QuadNum 
	FROM [AD419].[dbo].[' + @TableName + ']
	where accession is null and SUBSTRING(AWARDNUM, 10, 4) NOT IN 
		(
			SELECT distinct SUBSTRING(AWARDNUM, 10, 4) as QuadNum
			FROM [AD419].[dbo].[' + @TableName + ']
			where accession is null and CONVERT(int, SUBSTRING(AWARDNUM, 10, 4)) > 0 
		)
	order by 1
	for READ ONLY'
	IF @IsDebug = 1 
		BEGIN
			print @TSQL
		END
	ELSE
		BEGIN
			EXEC(@TSQL)
		
	Select @QuadNums = 'Where '

	open MyCursor

	fetch next from MyCursor into @temp

	while @@FETCH_STATUS = 0
	begin
		select @QuadNums += 'Project like ' + '''%' + @temp + '%'''
		FETCH NEXT FROM MyCursor
		INTO @temp
    
		if @@FETCH_STATUS = 0
		Begin
			select @QuadNums += ' OR '
		End
	end

	close MyCursor
	deallocate MyCursor
	
	IF @IsDebug = 1
	begin
		print @QuadNums
	end
	
	Select @TSQL =
	'SELECT Project, Accession,
		(CASE 
			WHEN SUBSTRING(PROJECT, 11, 4) NOT LIKE ''%-'' THEN  SUBSTRING(PROJECT, 11, 4)
			ELSE SUBSTRING(PROJECT, 10, 4)
		 END) as QuadNum
	INTO AD419.DBO.' + @OutputTableName + '
	from [AD419].[dbo].' + @InputTableName + '
	' + @QuadNums;

	IF @IsDebug = 1 
		BEGIN
			print @TSQL
		END
	ELSE
		BEGIN
			EXEC(@TSQL)
		END
	END
END
