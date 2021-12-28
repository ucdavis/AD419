
CREATE VIEW [dbo].[ARCCodes]
AS
SELECT        TOP (100) PERCENT ARC_Cd AS ARCCode, ARC_Name AS ARCName
FROM            dbo.ARC_Codes
WHERE        (isAES = 1)
ORDER BY ARCCode

GO



GO


