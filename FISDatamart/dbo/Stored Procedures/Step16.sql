CREATE PROCEDURE [dbo].[Step16]
AS
BEGIN
--Start time for usp_LoadTableUsingSwapPartitions: 11:07:38:907
--2009's partition number is 2

	TRUNCATE TABLE TransLogLoad

	EXEC	[dbo].[usp_LoadNamedTransLogTable]
			@FirstDateString = '2010-07-01',
			@LastDateString = '2011',
			@GetUpdatesOnly = 0,
			@TableName = 'TransLogLoad',
			@IsDebug = 0
	
	ALTER TABLE TransLog
	SWITCH PARTITION 4 TO TransLogEmpty PARTITION 4
	ALTER TABLE TransLogLoad
	SWITCH PARTITION 4 TO TransLog PARTITION 4
	TRUNCATE TABLE TransLogEmpty
--Execution time for usp_LoadTableUsingSwapPartitions: 00:00:00:000

				--Making call to download TransLog records:
				--EXEC usp_LoadTransLog @FirstDateString = '2009', @LastDateString = '2010', @GetUpdatesOnly = 0, @TableName = TransLog, @IsDebug = 1
				  
/*
			EXEC usp_LoadTableUsingSwapPartitions 
				@FirstDateString = '2011-07-01', 
				@LastDateString = '2012', 
				@GetUpdatesOnly = 0, 
				@TableName = 'TransLog',
				@IsDebug = 1
			
*/
--Start time for usp_LoadTableUsingSwapPartitions: 11:07:39:053
--2010's partition number is 3

	TRUNCATE TABLE TransLogLoad

	EXEC	[dbo].[usp_LoadNamedTransLogTable]
			@FirstDateString = '2011-07-01',
			@LastDateString = '2012',
			@GetUpdatesOnly = 0,
			@TableName = 'TransLogLoad',
			@IsDebug = 0
	
	ALTER TABLE TransLog
	SWITCH PARTITION 1 TO TransLogEmpty PARTITION 1
	ALTER TABLE TransLogLoad
	SWITCH PARTITION 1 TO TransLog PARTITION 1
	TRUNCATE TABLE TransLogEmpty
--Execution time for usp_LoadTableUsingSwapPartitions: 00:00:00:000
--Set @LastDateString = NULL

				--Making call to download TransLog records:
				--EXEC usp_LoadTransLog @FirstDateString = '2010', @LastDateString = '    ', @GetUpdatesOnly = 0, @TableName = TransLog, @IsDebug = 1
				  
/*
			EXEC usp_LoadTableUsingSwapPartitions 
				@FirstDateString = '2012-07-01', 
				@LastDateString = '    ', 
				@GetUpdatesOnly = 0, 
				@TableName = 'TransLog',
				@IsDebug = 1
			
*/
--Start time for usp_LoadTableUsingSwapPartitions: 11:07:39:197
--2011's partition number is 4

	TRUNCATE TABLE TransLogLoad

	EXEC	[dbo].[usp_LoadNamedTransLogTable]
			@FirstDateString = '2012-07-01',
			@LastDateString = '    ',
			@GetUpdatesOnly = 0,
			@TableName = 'TransLogLoad',
			@IsDebug = 0
	
	ALTER TABLE TransLog
	SWITCH PARTITION 2 TO TransLogEmpty PARTITION 2
	ALTER TABLE TransLogLoad
	SWITCH PARTITION 2 TO TransLog PARTITION 2
	TRUNCATE TABLE TransLogEmpty
END