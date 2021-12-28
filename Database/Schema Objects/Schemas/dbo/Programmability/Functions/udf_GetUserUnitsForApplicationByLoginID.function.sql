
-- =============================================
-- Author:		Ken Taylor
-- Create date: 2009-10-28
-- Description: Replacement of Catbert usp_GetUserUnits
-- Usage:
/*
	USE [AD419]
	GO

	SELECT * FROM [dbo].[udf_GetUserUnitsForApplicationByLoginID]('postit', 'AD419')
	GO

*/
-- Modifications:
--	20191021by kjt: Added Usage to comments section for testing.
--
-- =============================================
CREATE FUNCTION [dbo].[udf_GetUserUnitsForApplicationByLoginID]
(
	-- Add the parameters for the function here
	@LoginID varchar(10) = null,
	@ApplicationName varchar(50) = null
)
RETURNS 
@UserUnits TABLE 
(
	-- Add the column definitions for the TABLE variable here
	   UserID int not null
      ,UnitID int not null
      ,FullName varchar(50) not null
      ,ShortName varchar(50) not null
      ,PPS_Code char(9) null
      ,FIS_Code char(4) not null
      ,SchoolCode varchar(2) not null
)
AS
BEGIN
	INSERT INTO @UserUnits
	SELECT Users.[UserID]
      , Units.[UnitID]
      ,[FullName]
      ,[ShortName]
      ,[PPS_Code]
      ,[FIS_Code]
      ,[SchoolCode]
  FROM [Catbert3].[dbo].[Unit] Units
  INNER JOIN 
[Catbert3].[dbo].[UnitAssociations] UnitAssociations
ON Units.UnitID =  UnitAssociations.UnitID
INNER JOIN [Catbert3].[dbo].[Users] Users
ON UnitAssociations.UserID = Users.UserID
INNER JOIN [Catbert3].[dbo].[Applications] Applications 
ON UnitAssociations.ApplicationID = Applications.ApplicationID
WHERE Applications.Name = @ApplicationName AND Users.LoginID = @LoginID
AND UnitAssociations.Inactive = 0
	
	RETURN 
END
