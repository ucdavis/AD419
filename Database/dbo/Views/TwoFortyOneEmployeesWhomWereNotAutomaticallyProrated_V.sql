
/*
--========================================================================================
-- Author: Ken Taylor
-- Created: 2021-12-20
-- Description: This should give us enough info to be able to make an informed decision about how to prorate
--	241 employees whom were not automatically prorated by the system, meaning those
--	whom do not have a project (or projects) in the same OrgR as the expense.
-- Usage:

	USE [AD419]
	GO

	SELECT * FROM [dbo].[TwoFortyOneEmployeesWhomWereNotAutomaticallyProrated_V]

-- Modifications:
--	
--========================================================================================
*/
CREATE VIEW [dbo].[TwoFortyOneEmployeesWhomWereNotAutomaticallyProrated_V]
AS
SELECT TOP (10000)        
	t1.OrgR ExpenseOrgR, 
	t4.Chart, 
	t4.Account, 
	t4.PI_Name Account_PI, 
	FullName EmployeeName,  
	t1.EID, 
	CASE WHEN REPLACE(PI_Name,', ', ',') LIKE FullName THEN 1 ELSE 
		CASE WHEN REPLACE(PI_Name,', ', ',') LIKE  SUBSTRING( FullName, 1, CHARINDEX(' ', FullName, CHARINDEX(',', FullName))+1) THEN 1 ELSE 0 
		END 
	END AS AccountPI_EmpNameMatch, 
	ProjectOrgR, 
	t1.Accession, 
	Project, 
	Inv1 PI, 
	SUM(Expenses) Expenses
FROM Combined241EmployeesV2 T1 
INNER JOIN PPSDataMart.dbo.Persons t2 ON t1.EID = t2.EmployeeID
LEFT OUTER JOIN Project t3 ON t1.Accession = t3.Accession
INNER JOIN Expenses t4 ON t1.EID = t4.EID AND t1.OrgR = t4.OrgR
WHERE IsProrated = 1
GROUP BY t1.OrgR, FullName, t4.PI_Name, t4.Chart, t4.Account, ProjectOrgR, t1.EID, t1.Accession, Project, Inv1 
ORDER BY t1.OrgR, FullName, t4.PI_Name, t4.Chart, t4.Account, ProjectOrgR, t1.EID, t1.Accession, Project, Inv1