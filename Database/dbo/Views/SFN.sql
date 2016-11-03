CREATE VIEW dbo.SFN
AS
SELECT        SFN, Description
FROM            dbo.AllSFN
WHERE        (DisplayInApp = 1)