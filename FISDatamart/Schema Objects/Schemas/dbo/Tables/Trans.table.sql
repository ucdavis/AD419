CREATE TABLE [dbo].[Trans] (
    [PKTrans]           VARCHAR (200)   NOT NULL,
    [Year]              INT             NOT NULL,
    [Period]            CHAR (2)        NOT NULL,
    [Chart]             VARCHAR (2)     NOT NULL,
    [OrgID]             CHAR (4)        NULL,
    [AccountType]       CHAR (2)        NULL,
    [Account]           CHAR (7)        NOT NULL,
    [SubAccount]        CHAR (5)        NOT NULL,
    [ObjectTypeCode]    CHAR (2)        NULL,
    [Object]            CHAR (4)        NOT NULL,
    [SubObject]         VARCHAR (5)     NOT NULL,
    [BalType]           CHAR (2)        NOT NULL,
    [DocType]           CHAR (4)        NOT NULL,
    [DocOrigin]         CHAR (2)        NOT NULL,
    [DocNum]            VARCHAR (14)    NOT NULL,
    [DocTrackNum]       CHAR (10)       NULL,
    [InitrID]           CHAR (8)        NULL,
    [InitDate]          SMALLDATETIME   NULL,
    [LineSquenceNumber] DECIMAL (7)     NOT NULL,
    [LineDesc]          VARCHAR (40)    NULL,
    [LineAmount]        DECIMAL (15, 2) NULL,
    [Project]           CHAR (10)       NULL,
    [OrgRefNum]         CHAR (8)        NULL,
    [PriorDocTypeNum]   CHAR (4)        NULL,
    [PriorDocOriginCd]  CHAR (2)        NULL,
    [PriorDocNum]       VARCHAR (14)    NULL,
    [EncumUpdtCd]       CHAR (1)        NULL,
    [CreationDate]      SMALLDATETIME   NOT NULL,
    [PostDate]          SMALLDATETIME   NOT NULL,
    [ReversalDate]      SMALLDATETIME   NULL,
    [ChangeDate]        SMALLDATETIME   NULL,
    [SrcTblCd]          CHAR (1)        NULL,
    [OrganizationFK]    VARCHAR (14)    NULL,
    [AccountsFK]        VARCHAR (17)    NULL,
    [ObjectsFK]         VARCHAR (11)    NULL,
    [SubObjectFK]       VARCHAR (28)    NULL,
    [SubAccountFK]      VARCHAR (23)    NULL,
    [ProjectFK]         VARCHAR (21)    NULL,
    [IsCAES]            TINYINT         NULL,
    CONSTRAINT [PK_Trans] PRIMARY KEY CLUSTERED ([Year] ASC, [Period] ASC, [Chart] ASC, [Account] ASC, [SubAccount] ASC, [Object] ASC, [SubObject] ASC, [BalType] ASC, [DocType] ASC, [DocOrigin] ASC, [DocNum] ASC, [LineSquenceNumber] ASC, [PostDate] ASC)
);




GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Financial General Ledger Applied Transaction: This record contains General Ledger transactions that have been applied.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Trans';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Primary Key: Unique identifier for performing FK joins from other tables comprised of Year, Period, Chart, Account, SubAccount, ObjectTypeCode, Object, SubObject, BalType, DocType, DocOrigin, DocNum, DocTrackNum, LineSquenceNumber, and PostDate.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Trans', @level2type = N'COLUMN', @level2name = N'PKTrans';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Fiscal Year: Identifies a 12 month accounting period', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Trans', @level2type = N'COLUMN', @level2name = N'Year';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Fiscal Period Code: The fiscal period within the fiscal year. This can be 1 through 13 where 1 through 12 are the months July through June and 13 is for transactions applied to the prior fiscal year.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Trans', @level2type = N'COLUMN', @level2name = N'Period';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Chart Of Accounts Number: Identifier of a Chart of Accounts', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Trans', @level2type = N'COLUMN', @level2name = N'Chart';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Organization Identifier: Identifier of an Organization', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Trans', @level2type = N'COLUMN', @level2name = N'OrgID';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Account Type Code: This code is used to identify the account as income, expenditure, etc.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Trans', @level2type = N'COLUMN', @level2name = N'AccountType';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Account Number: Organization chosen identifier used to classify financial resources for accounting and reporting purposes.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Trans', @level2type = N'COLUMN', @level2name = N'Account';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Sub Account Number: Organization chosen identifier used to subdivide accounts for more detailed analysis and reporting.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Trans', @level2type = N'COLUMN', @level2name = N'SubAccount';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Object Type Code: Identifies the type of object for which transactions are being summarized as an asset, liability, expenditure, fund balance', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Trans', @level2type = N'COLUMN', @level2name = N'ObjectTypeCode';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Object Number: Identifier used to classify accounting transactions by type. Examples are academic salaries, in-state travel, Reg Fee income.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Trans', @level2type = N'COLUMN', @level2name = N'Object';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Sub_Object Number: Organization chosen identifier used to subdivide Object identified transaction types within an account. E.g. Meals/incidentals for a Travel object.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Trans', @level2type = N'COLUMN', @level2name = N'SubObject';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Balance Type Code: Designates the type of transactions summarized in the balance and transaction total amount fields (actual, budget, encumbrance).', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Trans', @level2type = N'COLUMN', @level2name = N'BalType';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'DaFIS Document Type Number: Identifies a Financial Information System (FIS) document type (i.e. Expense transfer, budget adjustment, journal vouchers, purchase requisitions, purchase orders, etc.).', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Trans', @level2type = N'COLUMN', @level2name = N'DocType';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'DaFIS Document Origin Code: An identifier used to determine the source of a transaction. In TP, it is the server id, for the feeder systems, it is the service unit.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Trans', @level2type = N'COLUMN', @level2name = N'DocOrigin';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'DaFIS Document Number: System (either TP or service unit feeder) assigned unique FIS document number. ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Trans', @level2type = N'COLUMN', @level2name = N'DocNum';




GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Organization Document Tracking Number: An optional organization internal tracking number provided by the initiator for the whole document: a cross reference.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Trans', @level2type = N'COLUMN', @level2name = N'DocTrackNum';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'DaFIS Document Initiator Id: The user id of the individual who created this document and started it on the approval cycle.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Trans', @level2type = N'COLUMN', @level2name = N'InitrID';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Transaction Initiation Date: The ledger date on a transaction', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Trans', @level2type = N'COLUMN', @level2name = N'InitDate';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Transaction Line Entry Sequence Number: A unique identifier for each detail entry for a given document number', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Trans', @level2type = N'COLUMN', @level2name = N'LineSquenceNumber';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Transaction Line Description: The ledger description on a transaction', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Trans', @level2type = N'COLUMN', @level2name = N'LineDesc';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Transaction Line Amount: The Dollar Amount on a transaction , a signed field. (This field has had the appropriate sign set, when the balance type indicates that offsets are generated, based on a comparison of the debit/credit code in the original GL transaction to the normal debit/credit code indicated for the object type - if the two codes are not the same, the sign is reversed from what is carried in the actual transaction in the general ledger)', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Trans', @level2type = N'COLUMN', @level2name = N'LineAmount';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Transaction Line Project Number: Code used to track and accumulate transactions across multiple charts, accounts and fund groups.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Trans', @level2type = N'COLUMN', @level2name = N'Project';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Organization Reference Number: An optional organization internal tracking number provided by the initiator for an individual entry in the transaction: a cross reference.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Trans', @level2type = N'COLUMN', @level2name = N'OrgRefNum';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Transaction Line Prior Document Type Number: The Document Type used to identify a related document; a cross reference.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Trans', @level2type = N'COLUMN', @level2name = N'PriorDocTypeNum';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Transaction Line Prior Document Origin Code: The Document Origin Code used to identify a related document; a cross reference.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Trans', @level2type = N'COLUMN', @level2name = N'PriorDocOriginCd';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Transaction Line Prior Document Number: The Document Number used to identify a related document; a cross reference.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Trans', @level2type = N'COLUMN', @level2name = N'PriorDocNum';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Transaction Encumbrance Update Code: An indicator for the GLE to designate how and when to update open encumbrances', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Trans', @level2type = N'COLUMN', @level2name = N'EncumUpdtCd';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Creation Date: Same value as PostDate; although, that was probably not the original intention for the field''s value.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Trans', @level2type = N'COLUMN', @level2name = N'CreationDate';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Transaction General Ledger Posted Date: The date the transaction was posted to the General Ledger.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Trans', @level2type = N'COLUMN', @level2name = N'PostDate';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Transaction Reversal Date: Used on selected documents to indicate a reversal date. On the Accrual Voucher or Journal Voucher, it identifies the date that the accounting entry will be automatically reversed.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Trans', @level2type = N'COLUMN', @level2name = N'ReversalDate';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'DaFIS Last Update Date: The date-time-stamp of the last update of this record.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Trans', @level2type = N'COLUMN', @level2name = N'ChangeDate';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Source Table Code: Used by TransV to identify source of transaction, meaning either "A" for applied transactions or "P" for pending transactions.  Note that this will always be set to "A" for records present in this table.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Trans', @level2type = N'COLUMN', @level2name = N'SrcTblCd';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Organization Foreign Key: FK used to perform joins with record''s corresponding Organization.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Trans', @level2type = N'COLUMN', @level2name = N'OrganizationFK';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Account Foreign Key: FK used to perform joins with record''s corresponding Account.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Trans', @level2type = N'COLUMN', @level2name = N'AccountsFK';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Object Foreign Key: FK used to perform joins with record''s corresponding Object.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Trans', @level2type = N'COLUMN', @level2name = N'ObjectsFK';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Sub Object Foreign Key: FK used to perform joins with record''s corresponding SubObject.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Trans', @level2type = N'COLUMN', @level2name = N'SubObjectFK';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Sub Account Foreign Key: FK used to perform joins with record''s corresponding SubAccount.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Trans', @level2type = N'COLUMN', @level2name = N'SubAccountFK';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Is Trans Record CA&ES?: Flag to easily indicate if a record "belongs" to CA&ES for base budget purposes, etc.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Trans', @level2type = N'COLUMN', @level2name = N'IsCAES';


GO
CREATE NONCLUSTERED INDEX [Trans_YearChartObjectBalType_CVIDX]
    ON [dbo].[Trans]([Year] ASC, [Chart] ASC, [Object] ASC, [BalType] ASC)
    INCLUDE([PKTrans], [Period], [OrgID], [Account], [SubAccount], [SubObject], [DocType], [DocOrigin], [DocNum], [DocTrackNum], [InitrID], [InitDate], [LineSquenceNumber], [LineDesc], [LineAmount], [Project], [OrgRefNum], [PriorDocTypeNum], [PriorDocOriginCd], [PriorDocNum], [EncumUpdtCd], [CreationDate], [PostDate], [ReversalDate], [ChangeDate], [SrcTblCd], [OrganizationFK], [AccountsFK], [ObjectsFK], [SubObjectFK], [SubAccountFK], [ProjectFK], [IsCAES]);


GO
CREATE NONCLUSTERED INDEX [Trans_ChartObjectBalType_CVINDX]
    ON [dbo].[Trans]([Chart] ASC, [Object] ASC, [BalType] ASC)
    INCLUDE([Year], [Account], [LineAmount]);


GO
CREATE NONCLUSTERED INDEX [Trans_ChartIsCAESYearObjectBalType_CVIDX]
    ON [dbo].[Trans]([Chart] ASC, [IsCAES] ASC, [Year] ASC, [Object] ASC, [BalType] ASC)
    INCLUDE([Account], [SubAccount], [SubObject], [LineAmount], [Project], [AccountsFK], [ObjectsFK]);


GO
CREATE NONCLUSTERED INDEX [Trans_ChartBalType_CVIDX]
    ON [dbo].[Trans]([Chart] ASC, [BalType] ASC)
    INCLUDE([PKTrans], [Year], [Period], [OrgID], [Account], [SubAccount], [Object], [SubObject], [DocType], [DocOrigin], [DocNum], [DocTrackNum], [InitrID], [InitDate], [LineSquenceNumber], [LineDesc], [LineAmount], [Project], [OrgRefNum], [PriorDocTypeNum], [PriorDocOriginCd], [PriorDocNum], [EncumUpdtCd], [CreationDate], [PostDate], [ReversalDate], [ChangeDate], [SrcTblCd], [OrganizationFK], [AccountsFK], [ObjectsFK], [SubObjectFK], [SubAccountFK], [ProjectFK], [IsCAES]);

