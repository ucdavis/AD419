CREATE VIEW dbo.DOSCodes
AS
SELECT        DOS_Code, MAX(Description) AS Description
FROM            dbo.DOS_Codes
WHERE        (IncludeInAD419FTE = 1)
GROUP BY DOS_Code