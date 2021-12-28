
/* Return a list of Project PIs that we were unable to match with an employee ID so 
the ID can be added manually by looking it up in PPS.  */
CREATE VIEW [dbo].[ProjectPIsWithMissingIds]
AS
SELECT        TOP (100) PERCENT PI, LastName, FirstInitial, OrgR
FROM            dbo.ProjectPI
WHERE        (EmployeeID IS NULL)
ORDER BY OrgR, LastName, FirstInitial