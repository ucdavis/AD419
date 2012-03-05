ALTER DATABASE [$(DatabaseName)]
    ADD FILE (NAME = [AD419_2011], FILENAME = '$(DefaultDataPath)$(DatabaseName)_2011.mdf', FILEGROWTH = 1024 KB) TO FILEGROUP [PRIMARY];

