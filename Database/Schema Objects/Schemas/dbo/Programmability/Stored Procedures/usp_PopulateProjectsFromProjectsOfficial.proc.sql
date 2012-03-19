/*
PROGRAM: usp_PopulateProjectsFromProjectsOfficial
BY:	Scott Kirkland

Moves projects from the ProjectsOffical table into Project.  Takes no parameters and 
thus moves every project over
*/
-------------------------------------------------------------------------
CREATE PROCEDURE [dbo].[usp_PopulateProjectsFromProjectsOfficial]

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
FROM ProjectsOfficial
WHERE 
	accession Is Not Null

PRINT 'Inserted ' + convert(varchar,@@RowCount) + ' records in Project table.'

END



-------------------------------------------------------------------------
/*
MODIFICATIONS:
[11/1/06] Wed
	Created


*/
