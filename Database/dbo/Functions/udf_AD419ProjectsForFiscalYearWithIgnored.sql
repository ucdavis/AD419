
-- =============================================
-- Author:		Ken Taylor
-- Create date: September 8, 2016
-- Description:	Uses AllProjectsNew as main datasource and returns a list of 
-- all non-expired projects for fiscal year,
-- with the names remapped and Inv2 thru Inv7 populated from the CoProjectDirectors
-- column, plus .CRISDeptCd populated from ReportingOrg so that the results are
-- compatable with the AD-419 application, and may be loaded into the project table.
--
-- Note that this function also includes ignored projects that will not be included
-- in the AD-419 project list for the purposes of association; however, they will show up
-- on the final reports.
--
-- Usage:
/*
	SELECT * FROM udf_AD419ProjectsForFiscalYearWithIgnored(2021)
*/
--
-- Modifications:
--	20171026 by kjt: Revised to use ProjectStatus table for determining which projects to include
--		instead of hard coding.
--	20211108 by kjt: Revised to add employeeID field to output variable.
--
-- =============================================
CREATE FUNCTION [dbo].[udf_AD419ProjectsForFiscalYearWithIgnored] 
(
	@FiscalYear int = 2017
)
RETURNS 
@Table_Var TABLE 
(
	 [Accession] varchar(7)
	,[Project] varchar(24)
	,[IsInterdepartmental] bit
	,[IsValid] bit
	,[BeginDate] datetime2
	,[TermDate] datetime2
	,[ProjTypeCd] int
	,[RegionalProjNum] int
    ,[OrgR] varchar(4)
    ,[CRIS_DeptID] varchar(4)
    ,[CSREES_ContractNo] varchar(20)
    ,[StatusCd] varchar(1)
    ,[Title] varchar(512)
    ,[UpdateDate] datetime2
	,EmployeeID varchar(10)
    ,[inv1] varchar(100)
    ,[inv2] varchar(100)
    ,[Inv3] varchar(100)
    ,[inv4] varchar(100)
    ,[inv5] varchar(100)
    ,[inv6] varchar(100)
    ,[inv7] varchar(100)
    ,[Is204] bit
    ,[idProject] int
	,[IsIgnored] bit
)
AS
BEGIN

--DECLARE @FiscalYear int = (SELECT FiscalYear FROM [dbo].[CurrentFiscalYear])

INSERT INTO @Table_Var (
       [Accession]
      ,[Project]
      ,[IsInterdepartmental]
      ,[isValid]
      ,[BeginDate]
      ,[TermDate]
      ,[ProjTypeCd]
      ,[RegionalProjNum]
      ,[OrgR]
      ,[CRIS_DeptID]
      ,[CSREES_ContractNo]
      ,[StatusCd]
      ,[Title]
      ,[UpdateDate]
	  ,EmployeeID
	  ,[Inv1]
	  ,[Is204]
      ,[idProject]
	  ,[IsIgnored])
select 
	   t1.AccessionNumber [Accession]
      ,t1.ProjectNumber [Project]
      ,t1.[IsInterdepartmental]
      ,CONVERT(bit, CASE WHEN t1.[IsIgnored] = 1 THEN 0 ELSE 1 END) AS [isValid]
      ,t1.ProjectStartDate [BeginDate]
      ,t1.ProjectEndDate [TermDate]
      ,NULL AS [ProjTypeCd]
      ,NULL AS [RegionalProjNum]
      ,t1.[OrgR]
      ,t8.CRISDeptCd AS [CRIS_DeptID]
      ,t1.AwardNumber AS [CSREES_ContractNo]
      ,CASE WHEN RTRIM(t1.[ProjectStatus]) LIKE 'Complete Without Final Report' 
			THEN 'B' ELSE LEFT(RTRIM(t1.[ProjectStatus]), 1) END [StatusCd]
      ,t1.[Title]
      ,NULL AS [UpdateDate]
	  ,t3.UcpEmployeeId AS EmployeeID
      ,t1.ProjectDirector AS [inv1]
      ,t1.[Is204]
      ,t1.Id [idProject]
	  ,t1.[IsIgnored]

 FROM  [dbo].[udf_AllProjectsNewForFiscalYear](@FiscalYear) t1
  INNER JOIN [dbo].[NifaProjectAccessionNumberImport] t3 ON t1.AccessionNumber = t3.AccessionNumber
  LEFT OUTER JOIN dbo.ReportingOrg AS t8 ON 
		t1.OrgR = t8.OrgR AND 
		(t8.IsActive = 1 OR t8.OrgR IN ('XXXX', 'AINT'))
 WHERE  
	 (t1.IsUCD = 1) AND (t1.IsExpired = 0) AND 
	 (t1.AccessionNumber NOT LIKE '0000000') AND
	 (RTRIM(t1.ProjectStatus) NOT IN (
		SELECT [Status]
		FROM [dbo].[ProjectStatus]
		WHERE IsExcluded = 1)
	 )

 -- Populate the various Inv_ from data present in the CoProjectDirectors column:
 update @Table_Var
 set Inv2 = t2.Name
 FROM @Table_Var t1
 INNER JOIN dbo.PrincipalInvestigatorsPerProjectV AS t2 ON t1.[idProject] = t2.ProjectId AND t2.InvNum = 1
 
 update @Table_Var
 set Inv3 = t3.Name
 FROM @Table_Var t1
 INNER JOIN  dbo.PrincipalInvestigatorsPerProjectV AS t3 ON t1.[idProject] = t3.ProjectId AND t3.InvNum = 2

 update @Table_Var
 set Inv4 = t4.Name
 FROM @Table_Var t1
 INNER JOIN dbo.PrincipalInvestigatorsPerProjectV AS t4 ON t1.[idProject] = t4.ProjectId AND t4.InvNum = 3 
						
 update @Table_Var
 set Inv5 = t5.Name
 FROM @Table_Var t1
 INNER JOIN dbo.PrincipalInvestigatorsPerProjectV AS t5 ON t1.[idProject] = t5.ProjectId AND t5.InvNum = 4
						
 update @Table_Var
 set Inv6 = t6.Name
 FROM @Table_Var t1
 INNER JOIN dbo.PrincipalInvestigatorsPerProjectV AS t6 ON t1.[idProject] = t6.ProjectId AND t6.InvNum = 5 
						
 update @Table_Var
 set Inv7 = t7.Name
 FROM @Table_Var t1
 INNER JOIN dbo.PrincipalInvestigatorsPerProjectV AS t7 ON t1.[idProject] = t7.ProjectId AND t7.InvNum = 6
	
	RETURN 
END