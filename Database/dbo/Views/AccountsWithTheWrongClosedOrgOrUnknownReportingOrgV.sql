



CREATE VIEW [dbo].[AccountsWithTheWrongClosedOrgOrUnknownReportingOrgV]
AS
select * from [dbo].[AccountsWithTheWrongClosedOrgsV]
union
select * from [dbo].[AccountsWithUnknownReportingOrgsV]