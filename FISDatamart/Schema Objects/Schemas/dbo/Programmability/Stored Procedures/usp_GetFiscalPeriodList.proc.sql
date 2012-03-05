-- =============================================
-- Author:		Ken Taylor
-- Create date: Jun-01-2010
-- Description:	Creates and populates a FiscalPeriod table
-- =============================================
CREATE PROCEDURE [dbo].[usp_GetFiscalPeriodList]
	-- Add the parameters for the stored procedure here
	@AddWildcard bit = 0 -- 0: Do NOT add wildcard ('%') (default); 1: Add wildcard.
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	DECLARE @MyTable TABLE (
		Period char(2), 
		FiscalPeriod varchar(20)
	)
	
	If @AddWildcard = 1
		BEGIN
			Insert into @MyTable (
				Period, 
				FiscalPeriod
				) VALUES ('%', '%')
		END

	INSERT INTO @MyTable (
		Period, 
		FiscalPeriod
	) VALUES
	 ('01', 'July'), 
	 ('02', 'August'), 
	 ('03','September'), 
	 ('04', 'October'), 
	 ('05', 'November'), 
	 ('06','December'), 
	 ('07','January'), 
	 ('08','February'), 
	 ('09','March'), 
	 ('10','April'), 
	 ('11','May'), 
	 ('12','June'), 
	 ('13','Junal Final')

	SELECT * FROM @MyTable

END
