-- =============================================
-- Author:		Alan Lai
-- Create date: 10/10/2006
-- Description:	Inserts a single entry for a PI
--	into CESList, and a single entry per project
--	association into CESXProject
-- Modifications:
--	2016-08-01 by kjt: Added Chart and Account
-- =============================================
CREATE PROCEDURE [dbo].[usp_insertCES]

		@EID varchar(9),  
		@AccountPIName nvarchar(50),
		@Title_Code varchar(4),
        @Accession char(7),
        @OrgR char(4),
        @PctEffort float,
        @CESSalaryExpenses float,
        @PctFTE tinyint,
		@Chart varchar(2) = null,
		@Account varchar(7) = null,
		@SubAccount varchar(5) = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    
IF NOT EXISTS ( SELECT * FROM CESList WHERE EID = @EID )
    INSERT INTO CESList
                          (EID, AccountPIName, Title_Code)
    VALUES     (@EID,@AccountPIName,@Title_Code)

INSERT INTO CESXProjects (EID, Accession, OrgR, PctEffort, CESSalaryExpenses, PctFTE, Chart, Account, SubAccount)
VALUES (@EID, @Accession, @OrgR, @PctEffort, @CESSalaryExpenses, @PctFTE, @Chart, @Account, @SubAccount)

END
