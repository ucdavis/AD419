/*Author: Rakesh
Description: This works good for numbers and alphabet.
Usage: 
Usage: select dbo.least(10,100) LEAST_OF_TWO,  dbo.least('R','S') LEAST_OF_TWO_ALPHABET
*/
CREATE FUNCTION [dbo].[least] (@str1 nvarchar(max),@str2 nvarchar(max))
RETURNS nvarchar(max)
BEGIN

   DECLARE @retVal nvarchar(max);

   set @retVal = (select case when @str1<=@str2 then @str1 ELSE @str2 end as retVal)

   RETURN @retVal;
END;