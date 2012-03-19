ALTER DATABASE [$(DatabaseName)]
    ADD LOG FILE (NAME = [AD419_2011_log], FILENAME = '$(Path1)$(DatabaseName)_2011_log.ldf', MAXSIZE = 2097152 MB, FILEGROWTH = 10 %);

