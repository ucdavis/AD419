CREATE FUNCTION [dbo].[string_split]
(
	@ItemList varchar(MAX), @Separator varchar(5)
)
RETURNS 
@ParsedList table
(
	[value] varchar(100)
)
AS
BEGIN
	DECLARE @Item varchar(100), @Pos int

	SET @ItemList = LTRIM(RTRIM(@ItemList))+ @Separator
	SET @Pos = CHARINDEX(@Separator, @ItemList, 1)

	IF REPLACE(@ItemList, @Separator, '') <> ''
	BEGIN
		WHILE @Pos > 0
		BEGIN
			SET @Item = LTRIM(RTRIM(LEFT(@ItemList, @Pos - 1)))
			IF @Item <> ''
			BEGIN
				INSERT INTO @ParsedList ([value]) 
				VALUES (@Item) --Use Appropriate conversion
			END
			SET @ItemList = RIGHT(@ItemList, LEN(@ItemList) - @Pos)
			SET @Pos = CHARINDEX(@Separator, @ItemList, 1)

		END
	END	
	RETURN
END