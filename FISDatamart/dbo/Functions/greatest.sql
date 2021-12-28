/****** Object:  UserDefinedFunction [dbo].[greatest]    Script Date: 08/23/2012 01:00:56 ******/
/*Author: Rakesh
Description: This works good for numbers and alphabet.
Usage: select dbo.greatest(10,100) GREATEST_OF_TWO, dbo.greatest('a','z') GREATEST_OF_TWO_ALPHABET 
*/
CREATE FUNCTION [dbo].[greatest] (@str1 nvarchar(max),@str2 nvarchar(max))
RETURNS nvarchar(max)
BEGIN

   DECLARE @retVal nvarchar(max);

   set @retVal = (select case when @str1<=@str2 then @str2 ELSE @str1 end as retVal)

   RETURN @retVal;
END;