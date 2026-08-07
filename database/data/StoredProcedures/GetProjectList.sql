CREATE PROCEDURE [data].[GetProjectList]
    @CycleStart DATE,
    @CycleEnd DATE
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        NifaProject,
        Accession,
        AwardNumber,
        Ae,
        Is204,
        Notes,
        Pi,
        PdEmailAddress,
        UcpEmployeeId,
        UcPathName,
        Department,
        Sfn,
        [Status]
    FROM [data].[ProjectListForCycle](@CycleStart, @CycleEnd);
END
