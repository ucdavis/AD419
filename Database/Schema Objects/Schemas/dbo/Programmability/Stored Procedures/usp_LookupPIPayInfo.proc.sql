-- =============================================
-- Author:		Alan Lai
-- Create date: 9/28/2006
-- Description:	For the CE entry, this goes out to
--	PPS to looking the payrate and percent full time
--	of a PI at a specific department
-- =============================================
CREATE PROCEDURE [dbo].[usp_LookupPIPayInfo]

	@EmployeeName nvarchar(50)

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    DECLARE @TSQL nvarchar(4000)

	SET @EmployeeName = '%' + @EmployeeName + '%'

	SET @TSQL = 'SELECT * FROM OPENQUERY(PAY_PERS_EXTR, ''SELECT 
		DISTINCT APT.EMPLOYEE_ID, Title_Code, ROUND(Pay_Rate,6) Pay_Rate, ROUND(Percent_Fulltime,6) Percent_Fulltime, APT.emp_name, APT.Home_Dept

	FROM
		PAYROLL.UCDAPTDIS_V APT, PAYROLL.EDBPER_V PER
	WHERE
		APT.EMPLOYEE_ID = PER.EMPLOYEE_ID AND
		PER.EMP_NAME LIKE '''+char(39)+@EmployeeName+char(39)+'''
		'')'

	EXEC (@TSQL)
	

END
