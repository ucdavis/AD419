CREATE PROCEDURE [data].[GetProjectList]
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
    FROM [data].[v_ProjectList];
END
