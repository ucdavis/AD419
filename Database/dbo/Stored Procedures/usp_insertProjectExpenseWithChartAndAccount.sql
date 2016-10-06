-- =============================================
-- Author:		Ken Taylor
-- Create date: August 9, 2016
-- Description:	Insert a 20x record into AllExpensesNew, and then into AssociationsNew
-- =============================================
CREATE PROCEDURE usp_insertProjectExpenseWithChartAndAccount 
	-- Add the parameters for the stored procedure here
	@SFN varchar(4) ,
	@OrgR char(4) ,
	@Chart varchar(2),
	@Account varchar(7) ,
	@Accession char(7) ,
	@Expenses decimal(16,2),
	@FTE decimal (16,4) = 0,
	@IsSalaryExpense bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    declare @ProjXOrgRCount int = 0
	declare @IsAINT bit = 0
	declare @IsAIND bit = 0

	select @ProjXOrgRCount = (SELECT COUNT(*)
	FROM         ProjXOrgR INNER JOIN
						  ReportingOrg ON ProjXOrgR.OrgR = ReportingOrg.OrgR
	WHERE     (ProjXOrgR.Accession = @Accession) AND 
			  (ProjXOrgR.OrgR = @OrgR) AND 
			  (ReportingOrg.IsActive = 1 OR ReportingOrg.OrgR IN ('AINT', 'XXXX'))
			)
	If @ProjXOrgRCount = 0 
	Begin
		Select @IsAINT = (
			Select CASE WHEN OrgR IN ('AINT', 'XXXX') THEN 1 ELSE 0 END
			from ReportingOrg where OrgR = (select OrgR from Project where Accession = @Accession)
		)
		If @IsAINT = 1 
			Begin
				Insert into ProjXOrgR(Accession, OrgR)
				values (@Accession, @OrgR)
			End
		Else
			Begin
				Select @IsAIND = (
					Select CASE OrgR WHEN 'AIND' THEN 1 ELSE 0 END
					from ProjXOrgR where Accession = @Accession
				)
				If @IsAIND = 1
					Begin
						Select @OrgR = 'AIND'
					End
				Else
					Begin
						RETURN -1
					End
			End
	End

	-- First find out the Exp_SFN from the Sub_Exp_SFN (SFN)
	DECLARE @Exp_SFN char(3)

	Declare @DataSource varchar(4) = '20x'
	SET @Exp_SFN = @SFN

	INSERT INTO AllExpensesNew
			   (OrgR, Chart, Account, Exp_SFN, Expenses, isAssociated, isAssociable, isNonEmpExp, Sub_Exp_SFN, DataSource)
	VALUES     (@OrgR, @Chart, @Account, @Exp_SFN,@Expenses, 1, 0, CASE WHEN @IsSalaryExpense = 1 THEN 0 ELSE 1 END, @SFN+(CASE WHEN @IsSalaryExpense = 1 THEN 's' ELSE 'f' END), @DataSource)

	-- Now insert the newly created ExpenseID into Associations.  Set FTE = 0
	INSERT INTO AssociationsNew
						  (ExpenseID, OrgR, Expenses, Accession, FTE)
	VALUES     (SCOPE_IDENTITY(),@OrgR,@Expenses,@Accession, @FTE)
END