CREATE TABLE [dbo].[NewAccountSFN] (
    [Chart]                    VARCHAR (2)  NULL,
    [Account]                  CHAR (7)     NULL,
    [Org]                      CHAR (4)     NULL,
    [isCE]                     INT          NULL,
    [SFN]                      VARCHAR (5)  NULL,
    [CFDANum]                  CHAR (6)     NULL,
    [OpFundGroupCode]          CHAR (6)     NULL,
    [OpFundNum]                VARCHAR (6)  NULL,
    [FederalAgencyCode]        CHAR (2)     NULL,
    [NIHDocNum]                CHAR (12)    NULL,
    [SponsorCategoryCode]      CHAR (2)     NULL,
    [SponsorCode]              CHAR (4)     NULL,
    [Accounts_AwardNum]        VARCHAR (50) NULL,
    [OpFund_AwardNum]          VARCHAR (50) NULL,
    [ExpirationDate]           DATETIME     NULL,
    [AwardEndDate]             DATETIME     NULL,
    [IsAccountInFinancialData] BIT          NULL
);

