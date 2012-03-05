-- =============================================
-- Author:		Ken Taylor
-- Create date: 02/26/2010
-- Description:	This gets the expenses from Expenses_CAES
-- that have an Acct_SFN of 204, plus attempts to associate 
-- them to a project either by account award/project CSREES contract number
-- or account Principal Investigator Name/project inv1-6.  
-- The results are then inserted into the 204AcctXProj; those
-- that remain unmatched requiring manual association to a project.
-- =============================================
CREATE PROCEDURE [dbo].[sp_Repopulate_AD419_204] (
	-- Add the parameters for the stored procedure here
	@FiscalYear int = 2009,
	@IsDebug bit = 0
)
AS
BEGIN
	DECLARE @TSQL varchar(max) = ''
	
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	-- Delete all the records from the 204AcctXProj table:
	Select @TSQL = 'DELETE from [204AcctXProj];'
	
	IF @IsDebug = 1
		BEGIN
			Print @TSQL
		END
	ELSE
		BEGIN
			EXEC(@TSQL)
		END
	----------------------------------------------------------------------------------------------------------
	
	Select @TSQL = '
	INSERT INTO [204AcctXProj] 
	(
		Chart,
		AccountID,
		Expenses,
		DividedAmount,
		Accession,
		Is219,
		CSREES_ContractNo,
		IsCurrentProject
	)
	SELECT     
		Expenses_CAES.Chart, 
		Expenses_CAES.Account, 
		SUM(Expenses_CAES.ExpenseSum) AS SumOfExpenseSum, 
		SUM(Expenses_CAES.ExpenseSum) AS DividedAmount, 
		Project.Accession,
		null as Is219,
		null as CSREES_ContractNo,
		IsCurrentAD419Project as IsCurrentProject
		
	FROM Expenses_CAES 
	INNER JOIN Acct_SFN ON Expenses_CAES.Account = Acct_SFN.acct_id 
		AND Expenses_CAES.Chart = Acct_SFN.chart 
	INNER JOIN FISDataMart.dbo.Accounts AS A ON Expenses_CAES.Chart = A.Chart 
		AND Expenses_CAES.Account = A.Account 
		AND A.Year = ' + Convert(char(4),@FiscalYear) + '
		AND A.Period = ''--''
	LEFT OUTER JOIN AllProjects Project ON A.AwardNum = Project.CSREES_ContractNo
	WHERE Acct_SFN.SFN = ''204''
		AND A.AwardNum NOT IN  --Remove 204s in Exclusions by award num
		(
			SELECT AwardNumber FROM [204Exclusions]
		)
	GROUP BY 
		Expenses_CAES.Chart, 
		Expenses_CAES.Account, 
		Project.Accession,
		IsCurrentAD419Project
	HAVING      
		Expenses_CAES.Chart = ''3''
		;'
		
	IF @IsDebug = 1
		BEGIN
			Print @TSQL
		END
	ELSE
		BEGIN
			EXEC(@TSQL)
		END
	-----------------------------------------------------------------------------------------------------
	-- Try to remove any prefix or suffixes from the contract numbers:
	
	Select @TSQL = '
	declare @MyCSREESTable TABLE (
		Account varchar(7), 
		CSREES_ContractNo varchar(20), 
		AwardNum varchar(20))

  insert into @MyCSREESTable
  SELECT  
      [Account]
      ,CASE 
      WHEN  NAME like ''%USDA%CSREES%'' OR NAME like ''%USDA%NIFA%'' THEN 
		CASE
			WHEN CHARINDEX(''-'',REPLACE(REPLACE(REPLACE(SUBSTRING(Name, 13,50),''GRAD '', ''''), ''#'', ''''), '' MCA UCR'', ''''),1) = 3 then
				''20'' + REPLACE(REPLACE(REPLACE(SUBSTRING(Name, 13,50),''GRAD '', ''''), ''#'', ''''), '' MCA UCR'', '''')
			ELSE 
				REPLACE(REPLACE(REPLACE(SUBSTRING(Name, 13,50),''GRAD '', ''''), ''#'', ''''), '' MCA UCR'', '''')
            END
		ELSE
			Name
     END as CSRESS_ContractNo
      ,[AwardNum]
  FROM [FISDataMart].[dbo].[Accounts] accounts
  inner join FISDataMart.dbo.OPFundNumbers OPFundNumbers on accounts.OpFundNum = OPFundNumbers.FundNum
	and OPFundNumbers.Chart = accounts.Chart and OPFundNumbers.Year = accounts .Year 
	and (
		Name like ''%USDA%CSREES%'' 
	 or Name like ''%USDA%NIFA%'' )
  where accounts.Year = ' + Convert(char(4),@FiscalYear) + ' 
	and Period = ''--'' and accounts.Chart = ''3''
	and Account in (
		Select  accountID 
		from [204AcctXProj] 
		where Accession is null) 
  /*
  USDA CSREES;  USDA CSREES #; USDA CSREES GRAD
  USDA/CSRESS; USDA/CSRESS % MCA UCR
  */
  
  -----------------------------------------------------------------------------------------------------
  -- Try to fix any contract numbers where they inadvertantly left off a digit
  -- by comparing against contract numbers in projects table:
  
   declare @MyBadLengthContractNumbers TABLE (AccountID varchar(7), ContractNo varchar(20))
   insert into @MyBadLengthContractNumbers
   select Account, CSREES_ContractNo from @MyCSREESTable 
   where CSREES_ContractNo is not null 
   group by Account, CSREES_ContractNo 
   having LEN(CSREES_ContractNo) != 16
 
  declare MyCursor cursor for select distinct AccountID, ContractNo from @MyBadLengthContractNumbers 
  
  open MyCursor
  
  declare @Account varchar(7), @CSREES_ContractNo varchar(20)
  fetch next from MyCursor into @Account, @CSREES_ContractNo
  while @@FETCH_STATUS <> -1
	begin
  
    declare @NumProjectsFound int = (
		select COUNT(*) 
        from Project
        where CSREES_ContractNo like @CSREES_ContractNo 
			or CSREES_ContractNo like ''%'' + SUBSTRING(@CSREES_ContractNo,6,11) 
			or CSREES_ContractNo like ''%'' + SUBSTRING(@CSREES_ContractNo,6,5)+''%''
			or CSREES_ContractNo like ''%'' + SUBSTRING(@CSREES_ContractNo,12,5) 
			or CSREES_ContractNo like SUBSTRING(@CSREES_ContractNo,1,11)+''%'')
		if @NumProjectsFound = 1
			update @MyCSREESTable
			set CSREES_ContractNo = (
				select CSREES_ContractNo  
				from Project 
				where CSREES_ContractNo like @CSREES_ContractNo 
				   or CSREES_ContractNo like ''%'' + SUBSTRING(@CSREES_ContractNo,6,11) 
				   or CSREES_ContractNo like ''%'' +  SUBSTRING(@CSREES_ContractNo,6,5)+''%''
				   or CSREES_ContractNo like ''%'' + SUBSTRING(@CSREES_ContractNo,12,5) 
				   or CSREES_ContractNo like SUBSTRING(@CSREES_ContractNo,1,11)+''%'' )
			where CSREES_ContractNo = @CSREES_ContractNo
  
			fetch next from MyCursor into @Account, @CSREES_ContractNo						
	END --while have more unassociated SFNs to prorate
						
  close MyCursor
  deallocate MyCursor

  select * from @MyCSREESTable 
  
 -----------------------------------------------------------------------------------------------------
 -- Now update the table with the corrected contract numbers:
 
  update [204AcctXProj]
  set CSREES_ContractNo = (
	select CSREES_ContractNo 
	from @MyCSREESTable 
	where AccountID = Account) 
  '
  IF @IsDebug = 1
		BEGIN
			Print @TSQL
		END
	ELSE
		BEGIN
			EXEC(@TSQL)
		END
 -----------------------------------------------------------------------------------------------------
 -- Update the accession numbers based on the newly found and corrected contract numbers:
 
 Select @TSQL = '
  declare MyCursor cursor for select distinct Accession, CSREES_ContractNo, IsCurrentAD419Project from [AD419].[dbo].[AllProjects] Projects
  where CSREES_ContractNo in (Select distinct CSREES_ContractNo from 
  [204AcctXProj] where CSREES_ContractNo is not null)
 
  open MyCursor
  
  declare @Accession varchar(7), @CSREES_ContractNo2 varchar(20), @IsCurrentProject bit
  fetch next from MyCursor into @Accession, @CSREES_ContractNo2, @IsCurrentProject
  while @@FETCH_STATUS <> -1
	begin
		update [204AcctXProj]
		set Accession = @Accession, IsCurrentProject = @IsCurrentProject 
		where CSREES_ContractNo = @CSREES_ContractNo2 and Accession is null
  
		fetch next from MyCursor into @Accession, @CSREES_ContractNo2, @IsCurrentProject
							
	END --while have more unassociated SFNs to prorate
						
  close MyCursor
  deallocate MyCursor
  '
  IF @IsDebug = 1
		BEGIN
			Print @TSQL
		END
	ELSE
		BEGIN
			EXEC(@TSQL)
		END
-----------------------------------------------------------------------------------------------------
-- Assign expenses based on matching PI Names having ''%G'' projects:

Select @TSQL = '
declare @MyTable TABLE ([AccountID] varchar(7)
      ,[Expenses] float
      ,[Accession] varchar(7)
      ,Project varchar(24)
      ,[Chart] varchar(1)
      ,PrincipalInvestigatorName varchar(30)
      ,inv1 varchar(30)
      ,OrgR varchar(4)
      )
      
      declare @MyTableA TABLE ([AccountID] varchar(7)
      ,[Expenses] float
      ,[Accession] varchar(7)
      ,Project varchar(24)
      ,[Chart] varchar(1)
      ,PrincipalInvestigatorName varchar(30)
      ,inv1 varchar(30)
      ,OrgR varchar(4)
      )

insert into @MyTable
select  distinct [AccountID]
      ,[Expenses]
      ,Project.[Accession]
      ,Project
      ,AcctXProj.[Chart]
      ,PrincipalInvestigatorName
      ,inv1
      ,OrgR
    
  FROM [204AcctXProj] AcctXProj
  inner join FISDataMart.dbo.accounts accounts on AcctXProj.AccountID = accounts.Account
  inner join AD419.dbo.OrgXOrgR OrgXOrgR on accounts.Org = OrgXOrgR.Org
  inner join AD419.dbo.Project Project on 
     UPPER(Substring(inv1, 1, charindex('','',inv1, 1) -1) + '','' + 
  Substring(inv1, charindex('','',inv1, 1) + 2,1)) like  Substring(PrincipalInvestigatorName , 1, charindex('','',PrincipalInvestigatorName, 1)+1 )  
 or  UPPER(Substring(inv2, 1, charindex('','',inv2, 1) -1) + '','' + 
  Substring(inv2, charindex('','',inv2, 1) + 2,1)) like  Substring(PrincipalInvestigatorName , 1, charindex('','',PrincipalInvestigatorName, 1)+1 )  
 or  UPPER(Substring(inv3, 1, charindex('','',inv3, 1) -1) + '','' + 
  Substring(inv3, charindex('','',inv3, 1) + 2,1)) like  Substring(PrincipalInvestigatorName , 1, charindex('','',PrincipalInvestigatorName, 1)+1 )  
 or  UPPER(Substring(inv4, 1, charindex('','',inv4, 1) -1) + '','' + 
  Substring(inv4, charindex('','',inv4, 1) + 2,1)) like  Substring(PrincipalInvestigatorName , 1, charindex('','',PrincipalInvestigatorName, 1)+1 )  
 or  UPPER(Substring(inv5, 1, charindex('','',inv5, 1) -1) + '','' + 
  Substring(inv5, charindex('','',inv5, 1) + 2,1)) like  Substring(PrincipalInvestigatorName , 1, charindex('','',PrincipalInvestigatorName, 1)+1 )  
  or  UPPER(Substring(inv6, 1, charindex('','',inv6, 1) -1) + '','' + 
  Substring(inv6, charindex('','',inv6, 1) + 2,1)) like  Substring(PrincipalInvestigatorName , 1, charindex('','',PrincipalInvestigatorName, 1)+1 )  
 
  where accounts.Chart = ''3'' and Period = ''--'' and Year = ' + Convert(char(4),@FiscalYear) + ' and Project like ''%G''
  and AcctXProj.Accession is null 
  
  and Project.Accession  not in (Select AcctXProj.Accession from [AD419].[dbo].[204AcctXProj] AcctXProj
  where AcctXProj.Accession is not null)
  
	insert into @MyTableA
	select distinct [AccountID]
		,[Expenses]
		,Project.[Accession]
		,Project
		,AcctXProj.[Chart]
		,PrincipalInvestigatorName
		,inv1
		,OrgR
	FROM [204AcctXProj] AcctXProj
	  inner join FISDataMart.dbo.accounts accounts on AcctXProj.AccountID = accounts.Account
	  inner join AD419.dbo.OrgXOrgR OrgXOrgR on accounts.Org = OrgXOrgR.Org
	  inner join AD419.dbo.Project Project on  ( 
	  UPPER(Substring(inv1, 1, charindex('','',inv1, 1) -1) + '','' + 
	  Substring(inv1, charindex('','',inv1, 1) + 2,1)) like  Substring(PrincipalInvestigatorName , 1, charindex('','',PrincipalInvestigatorName, 1)+1 )  
	  or
	  UPPER(Substring(inv2, 1, charindex('','',inv2, 1) -1) + '','' + 
	  Substring(inv2, charindex('','',inv2, 1) + 2,1)) like  Substring(PrincipalInvestigatorName , 1, charindex('','',PrincipalInvestigatorName, 1)+1 )  
	   or
	  UPPER(Substring(inv3, 1, charindex('','',inv3, 1) -1) + '','' + 
	  Substring(inv3, charindex('','',inv3, 1) + 2,1)) like  Substring(PrincipalInvestigatorName , 1, charindex('','',PrincipalInvestigatorName, 1)+1 )  
	   or
	  UPPER(Substring(inv4, 1, charindex('','',inv4, 1) -1) + '','' + 
	  Substring(inv4, charindex('','',inv4, 1) + 2,1)) like  Substring(PrincipalInvestigatorName , 1, charindex('','',PrincipalInvestigatorName, 1)+1 )  
	   or
	  UPPER(Substring(inv5, 1, charindex('','',inv5, 1) -1) + '','' + 
	  Substring(inv5, charindex('','',inv5, 1) + 2,1)) like  Substring(PrincipalInvestigatorName , 1, charindex('','',PrincipalInvestigatorName, 1)+1 )  
	   or
	  UPPER(Substring(inv6, 1, charindex('','',inv6, 1) -1) + '','' + 
	  Substring(inv6, charindex('','',inv6, 1) + 2,1)) like  Substring(PrincipalInvestigatorName , 1, charindex('','',PrincipalInvestigatorName, 1)+1 )  
	  )
	  where accounts.Chart = ''3'' and Period = ''--'' and Year = ' + Convert(char(4),@FiscalYear) + ' and Project like ''%G''
	  and AcctXProj.Accession is null 
	  
	   declare @MyTable3 TABLE (AccountID varchar(7), Expenses float, NumRecs smallint)
	  insert into @MyTable3 select Distinct AccountID, Expenses, COUNT(*) as NumRecs 
	   FROM @MyTableA where [AccountID] not in 
	  (select [AccountID] from @MyTable) and Expenses > 0
	  group by AccountID, Expenses
	  order by AccountID, Expenses
	  
	  declare @MyTable2 TABLE (AccountID varchar(7), Expenses float, NumRecs smallint)
	  insert into @MyTable2 select Distinct AccountID, Expenses, COUNT(*) as NumRecs from @MyTable
	  group by AccountID, Expenses
	  order by AccountID, Expenses
	  
	  declare @MyResultTable TABLE (Accession varchar(7), Project varchar(24), Chart char(1), AccountID varchar(7), OrgR varchar(4), PrincipalInvestigatorName varchar(30), Expenses float, divided_amount float)
	  
	  declare @MaxNumRecs int = (select MAX(NumRecs) from @MyTable2)
	  declare @RecCount int = 1
	  while @RecCount <= @MaxNumRecs
		begin
			insert into @MyResultTable select Accession, Project, Chart, AccountID, OrgR, PrincipalInvestigatorName, expenses, Expenses/@RecCount divided_amount  from @MyTable where AccountID in
			(Select AccountID from @MyTable2 where NumRecs = @RecCount ) order by AccountID, Project 
			select @RecCount = @RecCount + 1
		End
	  
		select @MaxNumRecs  = (select MAX(NumRecs) from @MyTable3)
		select @RecCount = 1
	  while @RecCount <= @MaxNumRecs
		begin
			insert into @MyResultTable select Accession, Project, Chart, AccountID, OrgR, PrincipalInvestigatorName, expenses, Expenses/@RecCount divided_amount  from @MyTableA where AccountID in
			(Select AccountID from @MyTable3 where NumRecs = @RecCount ) order by AccountID, Project 
			select @RecCount = @RecCount + 1
		End
	  
	  select * from @MyResultTable 
	  order by PrincipalInvestigatorName 
	  
	  select SUM(divided_amount) from @MyResultTable 

	-- delete the records we''re going to replace:
	select COUNT(*) before from [204AcctXProj] where accession is null

	delete from [204AcctXProj] where AccountID in
	(select distinct AccountID from @MyResultTable)

	-- re-insert them into the table, including the additional duplicates with the divided
	-- expense amounts:
	insert into [204AcctXProj] (AccountID, Expenses, DividedAmount, Accession, Chart, IsCurrentProject)
	select AccountID, Expenses, divided_amount as DividedAmount, Accession, Chart, 1 as IsCurrentProject
	from @MyResultTable

	select COUNT(*) after from [204AcctXProj] where accession is null
'
IF @IsDebug = 1
		BEGIN
			Print @TSQL
		END
	ELSE
		BEGIN
			EXEC(@TSQL)
		END
		
	-----------------------------------------------------------------------------------------------------
	-- This last part is going to look at non-current projects to try to find a match.
	-- The assumption is that any "Name" matches will be on non-current projects, since the name
	-- matches on current projects has already been performed.

Select @TSQL = '
	declare @PI_Names_Table TABLE (PrincipalInvestigatorName varchar(20), AccountID varchar(7))

	insert into @PI_Names_Table (PrincipalInvestigatorName, AccountID)
	select Substring(PrincipalInvestigatorName , 1, charindex('','',PrincipalInvestigatorName, 1) ) + '' '' + 
	Substring(PrincipalInvestigatorName , charindex('','',PrincipalInvestigatorName) + 1, 1 )
	 PrincipalInvestigatorName,  AcctXProj.AccountID from FISDataMart .dbo.Accounts accounts
	  inner join [204AcctXProj] AcctXProj on accounts.Account  = AcctXProj.AccountID
	  where Accession is null 
	  and accounts.Chart = ''3'' and Year = ' + Convert(char(4),@FiscalYear) + ' and Period = ''--''
	  
	  declare @PrincipalInvestigatorName varchar(20), @AccountID varchar(7)
	  declare MyCursor CURSOR for select PrincipalInvestigatorName, AccountID  from @PI_Names_Table
	  
	  open MyCursor
	  
	  fetch  MyCursor into @PrincipalInvestigatorName, @AccountID
	  
	  while @@FETCH_STATUS <> -1
	  begin
		declare @MyProjectsTable TABLE (Accession varchar(20), Project varchar(50), IsCurrentAD419Project bit);
		insert into @MyProjectsTable 
		select ACCESSION, PROJECT, IsCurrentAD419Project 
		from [AD419].[dbo].[AllProjects] 
		where inv1 like @PrincipalInvestigatorName + ''%''
		   or inv2 like @PrincipalInvestigatorName + ''%'' 
		   or inv3 like @PrincipalInvestigatorName + ''%'' 
		   or inv4 like @PrincipalInvestigatorName + ''%'' 
		   or inv5 like @PrincipalInvestigatorName + ''%'' 
		   or inv6 like @PrincipalInvestigatorName + ''%''
		
		declare @TotalProjectCount int = (select distinct COUNT(*)  from @MyProjectsTable)
		declare @MyCgOgSgProjectCount int = (select distinct COUNT(*) from @MyProjectsTable where Project like ''%G'')
		select ''total proj count: '' +  CONVERT(varchar(20), @TotalProjectCount) + ''; CgOgSg proj count: '' +  CONVERT(varchar(20), @MyCgOgSgProjectCount)
		
		-- if @TotalProjectCount = 0: leave as 204 for manual review and association.
		if @TotalProjectCount >= 1 and @MyCgOgSgProjectCount = 1
		-- assume 204 and assign accession number.
		begin
			update [204AcctXProj]
			set Accession = (Select Accession from @MyProjectsTable where Project like ''%G'')
			, IsCurrentProject = (Select IsCurrentAD419Project from @MyProjectsTable where Project like ''%G'')
			where AccountID = @AccountID;
		end
		else if @TotalProjectCount >= 1 and @MyCgOgSgProjectCount = 0
		-- assume inaccurately placed as 204; should be 219: set Is219 = 1.
		begin
			update [204AcctXProj]
			set Is219  = 1 
			where AccountID = @AccountID;
		end
		else if @TotalProjectCount >= 1 and @MyCgOgSgProjectCount > 1
		begin
			select @PrincipalInvestigatorName
				declare @MyUnassociatedCount int = (
					select count(*) 
					from [204AcctXProj] AcctXProj
					inner join FISDataMart.dbo.Accounts on AccountID = Account
					where PrincipalInvestigatorName like (REPLACE(@PrincipalInvestigatorName, '', '', '','') +''%'')
						AND AcctXProj.Accession is null and Is219 is null
						and Year = ' + Convert(char(4),@FiscalYear) + ' and AcctXProj.Chart = ''3'' and Period = ''--'')
						
			select ''@MyUnassociatedCount: '' + CONVERT(varchar(20),  @MyUnassociatedCount)
		end
		
		select distinct 
			myProjects.Accession,  
			myProjects.Project, 
			@AccountID AccountID, 
			@PrincipalInvestigatorName PI_Name 
		from @MyProjectsTable myProjects
		-- else if @TotalProjectCount >= 1 and @MyCgOgSgProjectCount = 0: assume inaccurately placed as 204; should be 219: set Is219 = 1.
		-- else if @TotalProjectCount >= 1 and @MyCgOgSgProjectCount > 1:
			-- if all G projects have expenses assigned: divide by number of G projects and distribute.
			-- else if some G projects have no expenses assigned divide by number of G projects with 0 expenses and distribute.
		
		fetch   MyCursor into @PrincipalInvestigatorName, @AccountID
		delete from @MyProjectsTable
	  end
	  
	  close MyCursor
	  deallocate MyCursor
	'

	IF @IsDebug = 1
		BEGIN
			Print @TSQL
		END
	ELSE
		BEGIN
			EXEC(@TSQL)
		END
		
--Remove all the 204s that are in the 204 Exclusions table
/*
DELETE FROM [204AcctXProj] where AccountID in
	(
		SELECT Account from [204Exclusions]
	)
*/

END
