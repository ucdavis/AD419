-- =============================================
-- Author:		Alan Lai
-- Create date: 10/10/2006
-- Description:	Inserts a single entry for a PI
--	into CESList, and a single entry per project
--	association into CESXProject
-- =============================================
CREATE PROCEDURE [dbo].[usp_insertCES]

		@EID varchar(9),  
		@AccountPIName nvarchar(50),
		@Title_Code varchar(4),
        @Accession char(7),
        @OrgR char(4),
        @PctEffort float,
        @CESSalaryExpenses float,
        @PctFTE tinyint

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    
IF NOT EXISTS ( SELECT * FROM CESList WHERE EID = @EID )
    INSERT INTO CESList
                          (EID, AccountPIName, Title_Code)
    VALUES     (@EID,@AccountPIName,@Title_Code)

INSERT INTO CESXProjects (EID, Accession, OrgR, PctEffort, CESSalaryExpenses, PctFTE)
VALUES (@EID, @Accession, @OrgR, @PctEffort, @CESSalaryExpenses, @PctFTE)

END
