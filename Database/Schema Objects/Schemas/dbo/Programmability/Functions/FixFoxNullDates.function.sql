--[9/9/04] Thu
CREATE FUNCTION [dbo].[FixFoxNullDates] (
	@OldDate datetime
	)
	RETURNS datetime
	AS  
BEGIN 
	
	RETURN CASE
		WHEN Datepart(yyyy,@OldDate)='1899' THEN NULL
		ELSE @OldDate
	END
END
