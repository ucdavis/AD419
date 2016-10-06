CREATE FUNCTION [dbo].[udf_RoundTime] (@Time datetime, @RoundTo float)
RETURNS datetime
AS
BEGIN
   DECLARE @RoundedTime smalldatetime
   DECLARE @Multiplier float

   SET @Multiplier= 24.0/@RoundTo

   SET @RoundedTime= ROUND(CAST(CAST(CONVERT(varchar,@Time,121) AS datetime) AS float) * @Multiplier,0)/@Multiplier

   RETURN @RoundedTime
END