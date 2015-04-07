CREATE VIEW dbo.DOSCodes
AS
SELECT        DOS_Code
FROM            dbo.DOS_Codes
WHERE        (IncludeInAD419FTE = 1)