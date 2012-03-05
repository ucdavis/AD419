/*
PROGRAM: usp_PopulateProjectsFromProjectsDownload
BY:	Mike Ransom
USAGE:	
	--EXEC usp_PopulateProjectsFromProjectsDownload(<stringEarliestValidTerminationDate>, <stringLastValidBeginDate>, [<stringLastValidBeginDateFor204s>])

	EXEC usp_PopulateProjectsFromProjectsDownload '7/1/2005','9/30/2006','7/1/2006'

DESCRIPTION: 

CURRENT STATUS:
[11/1/06] Wed
	Working.
NOTES:
CALLED BY:
CLIENTS/RELATED FILES/DEPENDENCIES:
TODO LIST:
MODIFICATIONS: see bottom
*/
-------------------------------------------------------------------------
CREATE PROCEDURE [dbo].[usp_PopulateProjectsFromProjectsDownload]
	@stringEarliestValidTerminationDate varchar(16),
	@stringLastValidBeginDate varchar(16)

AS
BEGIN
-------------------------------------------------------------------------

---------------------------------------
--Clear out old records:
DELETE FROM Project
PRINT 'DELETED ' + convert(varchar,@@RowCount) + ' records from Project table.'

---------------------------------------
--Insert new:
INSERT INTO Project 
	(
	Accession,
	Project,
	Title,
	RegionalProjNum,
	CSREES_ContractNo,
	CRIS_DeptID,
	ProjTypeCd,
	BeginDate,
	TermDate,
	--UpdateDate,
	StatusCd,
	inv1,
	inv2,
	inv3,
	inv4,
	inv5,
	inv6,
	isInterdepartmental
	)
SELECT 
	accession	Accession,          
	RTRIM(project)		Project,            
	RTRIM(title)		Title,              
	RTRIM(regional)	RegionalProjNum,    
	RTRIM(fundtype)	CSREES_ContractNo,  
	dept		CRIS_DeptID,        
	projtype	ProjTypeCd,         
	begindate	BeginDate,          
	termdate	TermDate,           
	--dbo.FixFoxNullDates(chdate)		UpdateDate,         
	status		StatusCd,           
	RTRIM(inv1)		inv1,               
	RTRIM(inv2)		inv2,               
	RTRIM(inv3)		inv3,               
	RTRIM(inv4)		inv4,               
	RTRIM(inv5)		inv5,               
	RTRIM(inv6)		inv6,               
	CASE 
		WHEN PATINDEX('%XXX%',Project) > 0 THEN 1
		ELSE 0
	END		AS isInterdepartmental 
FROM ProjectsRaw
WHERE 
	accession Is Not Null 
	AND termdate Is Not Null 
	And termdate >= convert(datetime, @stringEarliestValidTerminationDate)
	AND begindate <= convert(datetime, @stringLastValidBeginDate)

PRINT 'Inserted ' + convert(varchar,@@RowCount) + ' records in Project table.'

END



-------------------------------------------------------------------------
/*
MODIFICATIONS:
[11/1/06] Wed
	Created


*/
