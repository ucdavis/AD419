-- =============================================
-- Author:		Ken Taylor
-- Create date: 31-Aug-2010
-- Description:	Returns a list of Level 3 Organizations, i.e. Departments and their
-- corresponding details for use with Report Builder, etc.
-- =============================================
CREATE PROCEDURE [dbo].[usp_GetDepartmentsList] 
	-- Add the parameters for the stored procedure here
	@AddWildcard bit = 0, -- 0: Do NOT add wildcard ('%') (default); 1: Add wildcard.
	@ReturnInactiveAlso bit = 1 -- 1: Return ALL records (default); 0: Return only those records where the 
	-- LevelActiveInd = 'Y'.
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	DECLARE @MyTable TABLE (
		DepartmentOrgIdValue varchar(4), 
		DepartmentName varchar(40), 
		DepartmentOrgIDNameLabel varchar(100), 
		DepartmentActiveInd char(1)
	)

	If @AddWildcard = 1
		BEGIN
			Insert into @MyTable (
				DepartmentOrgIdValue , 
				DepartmentName , 
				DepartmentOrgIDNameLabel , 
				DepartmentActiveInd
			) VALUES ('%', '%', '%','Y')
		END
		
	Insert into @MyTable (
		DepartmentOrgIdValue , 
		DepartmentName , 
		DepartmentOrgIDNameLabel , 
		DepartmentActiveInd
		)
	SELECT DISTINCT TOP 100 PERCENT  
	 CASE WHEN CHART = '3' THEN Org6 ELSE Org7 END AS DepartmentOrgIdValue,
	  Name AS DepartmentName, (Org + ' - ' + Name) AS DepartmentOrgIDNameLabel,
	  ActiveIndicator AS DepartmentActiveInd
	FROM            dbo.Organizations
	WHERE        ((Chart = '3' AND Org4 = 'AAES') OR
                         (Chart = 'L' AND Org5 = 'AAES')) AND (Year = 9999 AND PERIOD = '--') AND ((Chart = '3' AND Org6 IS NOT NULL) OR
                         (Chart = 'L' AND Org7 IS NOT NULL)) AND LEVEL = '6'
	ORDER BY DepartmentOrgIdValue

	If @ReturnInactiveAlso = 1
		BEGIN
			Select * from @MyTable
		END
	Else
		BEGIN
			Select * from @MyTable where DepartmentActiveInd = 'Y'
		END
END
