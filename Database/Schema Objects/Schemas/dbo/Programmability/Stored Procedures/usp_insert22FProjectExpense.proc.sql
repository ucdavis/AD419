-- =============================================
-- Author:		Ken Taylor
-- Create date: 12/21/2009
-- Description:	Used to programatically insert 22F project expenses.
--
-- Modifications: 
-- [12/17/2010] by kjt: Revised to use AllExpenses, table (formerly Expenses) instead of new Expenses view.
--
-- =============================================
CREATE PROCEDURE [dbo].[usp_insert22FProjectExpense] 
	-- Add the parameters for the stored procedure here
	@SFN varchar(4),
	@OrgR char(4),
	@Accession char(7),
	@PI_Name varchar(50),
	@Expenses decimal(16,2)

AS
BEGIN
	declare @ProjXOrgRCount int = 0
	declare @IsAINT bit = 0
	declare @IsAIND bit = 0

	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

select @ProjXOrgRCount = (SELECT COUNT(*)
FROM         ProjXOrgR INNER JOIN
                      ReportingOrg ON ProjXOrgR.OrgR = ReportingOrg.OrgR
WHERE     (ProjXOrgR.Accession = @Accession) AND (ProjXOrgR.OrgR = @OrgR) AND (ReportingOrg.IsActive = 1))

If @ProjXOrgRCount = 0 
	Begin
		Select @IsAINT = (
			Select CASE OrgR WHEN 'AINT' THEN 1 ELSE 0 END
			from ReportingOrg where CRISDeptCd = (select CRIS_DeptID from Project where Accession = @Accession)
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
SET @Exp_SFN = @SFN

-- Insert values into Expenses.  Chart = 3, isAssociated = 1, isAssociable = 0.
INSERT INTO AllExpenses
                      (OrgR, Chart, Exp_SFN, PI_Name, Expenses, isAssociated, isAssociable, Sub_Exp_SFN, DataSource)
VALUES     (@OrgR, '3',@Exp_SFN, @PI_Name, @Expenses, 1, 0,@SFN,'22F')

-- Now insert the newly created ExpenseID into Associations.  Set FTE = 0
INSERT INTO Associations
                      (ExpenseID, OrgR, Expenses, Accession, FTE)
VALUES     (SCOPE_IDENTITY(),@OrgR,@Expenses,@Accession,0)

/* ----- Old Version Inserted Into Expenses_CSREES --------- 
INSERT INTO Expenses_CSREES
                      (OrgR, Accession, Expenses, SFN)
VALUES     (@OrgR,@Accession,@Expenses,@SFN)
*/

END
