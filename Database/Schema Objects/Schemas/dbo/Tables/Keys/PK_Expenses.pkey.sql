﻿ALTER TABLE [dbo].[AllExpenses]
    ADD CONSTRAINT [PK_Expenses] PRIMARY KEY CLUSTERED ([ExpenseID] ASC) WITH (ALLOW_PAGE_LOCKS = ON, ALLOW_ROW_LOCKS = ON, PAD_INDEX = OFF, IGNORE_DUP_KEY = OFF, STATISTICS_NORECOMPUTE = OFF);

