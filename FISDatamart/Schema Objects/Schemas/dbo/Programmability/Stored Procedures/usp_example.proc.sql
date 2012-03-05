 
 create procedure [dbo].[usp_example] 
	@spids tt_example READONLY 
 AS
	 SELECT * 
	 FROM @spids
