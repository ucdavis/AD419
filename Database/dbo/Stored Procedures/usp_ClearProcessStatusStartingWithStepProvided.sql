
-- =============================================
-- Author:		Ken Taylor
-- Create date: December 18, 2021
-- Description:	Using the AD419 DataHelper Status page, select the step you wish to 
-- do again, and provide that parameter to the procedure.  You may also provide an
-- optional parameter should you wish to reset all the steps following the one provided;
-- otherwise, only that one single step will be reset.

-- Usage:
/*
--------------------------------------------------
-- Reset only step 30:

USE [AD419]
GO

DECLARE	@return_value int

EXEC	@return_value = [dbo].[usp_ClearProcessStatusStartingWithStepProvided]
		@CategorySequence = 30, -- Reset only step 30
		@ResetAllStepsFollowing = 0

SELECT	'Return Value' = @return_value

GO

--------------------------------------------------
-- Reset step 30 and all steps following:

USE [AD419]
GO

DECLARE	@return_value int

EXEC	@return_value = [dbo].[usp_ClearProcessStatusStartingWithStepProvided]
		@CategorySequence = 30, -- Reset step 30 and all steps following.
		@ResetAllStepsFollowing = 1

SELECT	'Return Value' = @return_value

GO

*/
-- Modifications:
--
-- =============================================
CREATE PROCEDURE [dbo].[usp_ClearProcessStatusStartingWithStepProvided] 
	@CategorySequence int,
	@ResetAllStepsFollowing bit = 0
AS
BEGIN
	IF @ResetAllStepsFollowing = 1
	BEGIN
		UPDATE ProcessStatus
		SET IsCompleted = 0
		WHERE CategoryID IN (
			SELECT ID
			FROM ProcessCategory
			WHERE SequenceOrder >= @CategorySequence
		)

		UPDATE ProcessCategory
		SET IsCompleted = 0
		WHERE SequenceOrder >= @CategorySequence
	END

	ELSE
	BEGIN
		UPDATE ProcessStatus
		SET IsCompleted = 0
		WHERE CategoryID IN (
			SELECT ID
			FROM ProcessCategory
			WHERE SequenceOrder = @CategorySequence
		)

		UPDATE ProcessCategory
		SET IsCompleted = 0
		WHERE SequenceOrder = @CategorySequence
	END
END