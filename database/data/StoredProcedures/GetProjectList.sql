CREATE PROCEDURE [data].[GetProjectList]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        NifaProject,
        Accession,
        AwardNumber,
        Ae,
        Pi,
        UcpEmployeeId,
        UcPathName,
        Department,
        Sfn,
        [Status]
    FROM [data].[v_ProjectList];
END
