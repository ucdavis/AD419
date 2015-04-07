-- =============================================
-- Author:		Scott Kirkland
-- Create date: 9/26/06
-- Description:	Used to programatically insert a project expense.
-- Modifications: 
-- by Ken Taylor:
-- Removed 201t and 201p logic as Steve said they're all only 201's now.
-- Added changeable DataSource so this proc could also be used with 22F expenses from the UI.
--	2013-11-21 by kjt: Revised to bypass adding entry to ProjXOrgR for AINT if accession 
--	already present.
-- =============================================
CREATE PROCEDURE [dbo].[usp_insertProjectExpense] 
	-- Add the parameters for the stored procedure here
	@SFN varchar(4),
	@OrgR char(4),
	@Accession char(7),
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
WHERE     (ProjXOrgR.Accession = @Accession) AND (ProjXOrgR.OrgR = @OrgR) AND (ReportingOrg.IsActive = 1 OR ReportingOrg.OrgR = 'AINT'))

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

--IF @SFN = '201t'
--	SET @Exp_SFN = '201'
--ELSE IF @SFN = '201p'
--	SET @Exp_SFN = '201'
--ELSE
SET @Exp_SFN = @SFN

--Minor mod to allow manual entries of 22F expenses from UI:
Declare @DataSource varchar(4) = '20x' -- Default as most of the manual entries will be 201, 202 or 205 -> 20x
If @SFN like '22F'
	Begin 
		Select @DataSource = '22F'
	End

-- Insert values into Expenses.  Chart = 3, isAssociated = 1, isAssociable = 0.
INSERT INTO AllExpenses
                      (OrgR, Chart, Exp_SFN, Expenses, isAssociated, isAssociable, Sub_Exp_SFN, DataSource)
VALUES     (@OrgR, '3',@Exp_SFN,@Expenses, 1, 0, @SFN, @DataSource)

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
