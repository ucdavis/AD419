------------------------------------------------------------------------
/*
PROGRAM: usp_getInterdepartmentalProjects
BY:	Mike Ransom
USAGE:	
	EXEC usp_getInterdepartmentalProjects

DESCRIPTION: 
	Used to present list of interdepartmental projects in "Interdepartmental Associations" form of UI.
	Only lists for Project.isInterdepartmental = 1	(the only valid projects)
	Count comes from sub-query so only the projects associated with departments are counted.
	ProjXOrgR association table *does not* include any OrgR values for AINT (interdepartmental), get null Ct from outer join.
	ISNULL function neatly presents the nulls as zeros.

CURRENT STATUS:
[10/6/06] Fri 
	Recoded original SProc from Scott which was based on depricated table ProjXDept and Project.project LIKE '%XXX%' 
	Now based on ProjXOrgR association table and Project.isInterdepartmental = 1
	Deleted records in ProjXOrgR for OrgR = 'AINT' (Interdepartmental). The only valid associations are to valid reporting orgs. (gives correct count too)
NOTES:
CALLED BY:
	Used in UI for associating interdepartmental projects to departments. This query supplies the list of projects on the left.
CLIENTS/RELATED FILES/DEPENDENCIES:
TODO LIST:
MODIFICATIONS: see bottom
*/
-------------------------------------------------------------------------
CREATE PROCEDURE [dbo].[usp_getInterdepartmentalProjects]
AS
-------------------------------------------------------------------------
BEGIN
	SELECT 
		Project.Accession, 
		Project.Project, 
		ISNULL(Ct, 0) Ct
	FROM 
		Project 
		LEFT OUTER JOIN
		(	/* sub-query to ProjXOrgR for counts. ProjXOrgR does not contain OrgR for Interdepartmental so they aren't included) */
			SELECT Accession, Count(Accession) AS Ct
			FROM ProjXOrgR 
			GROUP BY Accession
		) DeptCount ON
			Project.Accession = DeptCount.Accession
	WHERE 
		Project.isInterdepartmental = 1	AND Project.isValid = 1 /* Restricts to valid projects for association with other departments */
	ORDER BY 
		Project.Project
END
-------------------------------------------------------------------------
/*
MODIFICATIONS:

2010-10-28 by kjt: Added check for Project.IsValid = 1 to where clause.


*/
