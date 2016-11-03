using System;
using System.Data;
using System.Configuration;
using System.Web;
using System.Web.Security;
using System.Web.UI;
using System.Web.UI.WebControls;
using System.Web.UI.WebControls.WebParts;
using System.Web.UI.HtmlControls;
using System.Collections;
using System.Web.Caching;
using System.Security.Permissions;

namespace CAESDO
{
    /// <summary>
    /// AD419DataAccess does BLL for the AD419 project.  To be used in ObjectDataSources
    /// as well as in page data calls
    /// </summary>
    public class AD419DataAccess
    {
        private DataOps dops;
        
        public AD419DataAccess()
        {
            //
            // TODO: Add constructor logic here
            //
            dops = new DataOps();
            //dops.ConnectionString = System.Web.Configuration.WebConfigurationManager.ConnectionStrings["MainDB"].ToString();
        }

        /// <summary>
        /// Returns all distinct departments in the dbo.departments table
        /// </summary>
        /// <returns>CRISDeptCd, deptname</returns>
        public DataSet getAllDepartments()
        {
            dops.ResetDops();
            dops.Sproc = "usp_getAllDepartments";

            return dops.get_dataset();
        }

        /// <summary>
        /// Returns all interdepartmental projects from the db
        /// </summary>
        /// <remarks>Uses a SQL LIKE statement to find XXX projects.  In the future
        /// we might want to create an 'IsInterdepartmental' field for cleaner querying</remarks>
        public DataSet getInterdepartmentalProjects()
        {
            dops.ResetDops();
            dops.Sproc = "usp_getInterdepartmentalProjects";

            return dops.get_dataset();
        }

        /// <summary>
        /// Given the accession number, gets information about that project.
        /// Uses out strings to return the project and title
        /// </summary>
        /// <returns>arraylist of investigators</returns>
        public ArrayList getInterdepartmentalProjectInfo(string accession, out string project, out string title)
        {
            dops.ResetDops();
            dops.Sproc = "usp_getInterdepartmentalProjectInfo";

            dops.SetParameter("@Accession", accession, "IN");

            //Put everything in a dataset so we can use it to populate the array list that we want
            DataSet ds = dops.get_dataset();

            if (ds.Tables[0].Rows.Count == 0)
            {
                project = null;
                title = null;
                return null;
            }

            DataRow dr = ds.Tables[0].Rows[0];
            ArrayList results = new ArrayList();

            project = (string)dr["Project"];
            title = (string)dr["Title"];

            //Now create a list of investigators (don't include nulls)
            ArrayList investigators = new ArrayList();
            investigators.Add(((string)dr["inv1"]).Trim());

            if (!string.IsNullOrEmpty(GetNullSafeString(dr["inv2"]).Trim()))
                investigators.Add((string)dr["inv2"]);
            if (!string.IsNullOrEmpty(GetNullSafeString(dr["inv3"]).Trim()))
                investigators.Add((string)dr["inv3"]);
            if (!string.IsNullOrEmpty(GetNullSafeString(dr["inv4"]).Trim()))
                investigators.Add((string)dr["inv4"]);
            if (!string.IsNullOrEmpty(GetNullSafeString(dr["inv5"]).Trim()))
                investigators.Add((string)dr["inv5"]);
            if (!string.IsNullOrEmpty(GetNullSafeString(dr["inv6"]).Trim()))
                investigators.Add((string)dr["inv6"]);
            //Now run through the array list and remove null entries
            

            return investigators;
        }

        /// <summary>
        /// Returns a dataset with all the CRISDeptCds and corresponding department names associated with the accession number
        /// </summary>
        /// <param name="accession"></param>
        /// <returns>CRISDeptCd, deptname from dbo.departments</returns>
        public DataSet getSecondaryDepartments(string accession)
        {
            if (string.IsNullOrEmpty(accession))
                return null;

            dops.ResetDops();
            dops.Sproc = "usp_getSecondaryDepartments";

            dops.SetParameter("@Accession", accession, "IN");

            return dops.get_dataset();
        }

        /// <summary>
        /// Deletes the link between current accession number and CRISDeptCd.
        /// </summary>
        /// <param name="accession">Selected Value of the project gridview</param>
        /// <param name="CRISDeptCd">DataKeys property of the departments gridview</param>
        [PrincipalPermission(SecurityAction.Demand, Role = "Admin")]
        public int removeSecondaryDepartments(string accession, string CRISDeptCd)
        {
            dops.ResetDops();
            dops.Sproc = "usp_deleteSecondaryDepartment";

            dops.SetParameter("@Accession", accession, "IN");
            dops.SetParameter("@CRISDeptCd", CRISDeptCd, "IN");
            dops.SetParameter("RETURN_VALUE", 1, "return");

            dops.Execute_Sql();

            return (int)dops.GetOutputVariable("RETURN_VALUE");
        }

        /// <summary>
        /// Establish a db entry with the current accession number and the CRISDeptCd
        /// </summary>
        /// <param name="accession">Selected Value of the project gridview</param>
        /// <param name="CRISDeptCd">Selected Value of the dlist of departments </param>
        [PrincipalPermission(SecurityAction.Demand, Role = "Admin")]
        public void insertSecondaryDepartments(string accession, string CRISDeptCd)
        {
            dops.ResetDops();
            dops.Sproc = "usp_insertSecondaryDepartments";

            dops.SetParameter("@Accession", accession, "IN");
            dops.SetParameter("@CRISDeptCd", CRISDeptCd, "IN");

            dops.Execute_Sql();
        }

        /// <summary>
        /// Get a dataset containing the SFN and its description.
        /// </summary>
        /// <returns>SFN, Description from dbo.SFN</returns>
        public DataSet getSFN()
        {
            dops.ResetDops();
            dops.Sproc = "usp_getSFN";

            return dops.get_dataset();
        }

        /// <summary>
        /// Returns the reporting orgs from the departments table
        /// </summary>
        /// <returns>OrgR, Org-Dept (which is a mashing of orgR plus deptabbr</returns>
        public DataSet getReportingOrg()
        {
            dops.ResetDops();
            dops.Sproc = "usp_getReportingOrg";

            return dops.get_dataset();
        }

        /// <summary>
        /// Gets a filtered list of ReportingOrgs (depts) that the given employee has access to.
        /// </summary>
        /// <param name="loginID">The loginID of the current employee</param>
        /// <returns>If the user is an admin, all departments are returned (by calling getReportingOrg()),
        /// else the departments that the user has explicit access to are returned</returns>
        public DataSet getReportingOrgFiltered(string loginID)
        {
            string[] roles = Roles.GetRolesForUser();
                        
            if (roles.Length == 1)
            {
                if (roles[0] == "Admin")
                    return getReportingOrg();
                else
                {
                    string _loginID = HttpContext.Current.User.Identity.Name;
                    dops.ResetDops();
                    dops.Sproc = "usp_GetReportingOrgByUser";
                    dops.SetParameter("@LoginID", loginID, "input");
                    return dops.get_dataset();
                }
            }
            else
            {
                // Find admin role in the roles list
                for (int i = 0; i < roles.Length; i++)
                {
                    if (roles[i] == "Admin")
                    {
                        return getReportingOrg();
                    }
                }

                // If this is reached admin was not found
                dops.ResetDops();
                dops.Sproc = "usp_GetReportingOrgByUser";
                dops.SetParameter("@LoginID", loginID, "input");
                return dops.get_dataset();
            }

            
        }

        /// <summary>
        /// Gets the project expenses from the SFN and OrgR filtering criterion
        /// </summary>
        /// <param name="SFN">3 or 4 digit code, or 'All' for all</param>
        /// <param name="OrgR">4 digit code, or 'All' for all</param>
        /// <returns>idExpense, SFN, OrgR, project, Expenses, OK, PI (principle investigator), Accession</returns>
        public DataSet getProjectExpenses(string SFN, string OrgR)
        {
            dops.ResetDops();
            dops.Sproc = "usp_getProjectExpenses";

            dops.SetParameter("@SFN", SFN, "IN");
            dops.SetParameter("@OrgR", OrgR, "IN");

            return dops.get_dataset();
        }

        /// <summary>
        /// Changes the expenses for a given idExpense
        /// </summary>
        /// <remarks>Cast of Expenses from decimal to double necessary to work with DataOps</remarks>
        [PrincipalPermission(SecurityAction.Demand, Role = "Admin")]
        public void changeProjectExpense(int ExpenseID, decimal Expenses)
        {
            dops.ResetDops();
            dops.Sproc = "usp_changeProjectExpense";

            dops.SetParameter("@ExpenseID", ExpenseID, "IN");
            //convert to a double because dops doesn't have decimal functionality built in
            dops.SetParameter("@Expenses", (double)Expenses, "IN");

            dops.Execute_Sql();
        }

        /// <summary>
        /// Gets the running SFN subtotals for the given Reporting Org
        /// </summary>
        /// <param name="OrgR">The reporting org</param>
        /// <returns>SFN, SumOfExpenses</returns>
        public DataSet getSFNSubtotals(string OrgR)
        {
            dops.ResetDops();
            dops.Sproc = "usp_getSFNSubtotals";

            dops.SetParameter("@OrgR", OrgR, "IN");

            return dops.get_dataset();
        }

        /// <summary>
        /// Gets the expense summary, grouped by SFN, for the given OrgR and AssociationStatus
        /// </summary>
        /// <param name="OrgR">The Reporting Org</param>
        /// <param name="AssociationStatus">The AssociationStatus as an integer for which columns
        /// you want back.  0 = All, 1 = Total, 2 = Associated, 3 = Unassociated</param>
        public DataSet getExpensesBySFN(string OrgR, string Accession, int AssociationStatus)
        {
            if (string.IsNullOrEmpty(Accession))
                Accession = string.Empty;

            dops.ResetDops();
            dops.Sproc = "usp_GetExpensesBySFN";

            dops.SetParameter("@OrgR", OrgR, "IN");
            dops.SetParameter("@Accession", Accession, "IN");
            dops.SetParameter("@intAssociationStatus", AssociationStatus, "IN");

            return dops.get_dataset();
        }

        /// <summary>
        /// Deletes the given idExpense
        /// </summary>
        /// <param name="idExpense">The unique expense ID</param>
        [PrincipalPermission(SecurityAction.Demand, Role = "Admin")]
        public void deleteProjectExpense(int ExpenseID)
        {
            dops.ResetDops();
            dops.Sproc = "usp_deleteProjectExpense";

            dops.SetParameter("@ExpenseID", ExpenseID, "IN");

            dops.Execute_Sql();
        }

        /// <summary>
        /// Deletes all associations from the grouping identified by the two pieces of criteria
        /// </summary>
        /// <param name="OrgR">Reporting Org</param>
        /// <param name="Grouping">Possible Values: Organization, Sub-Account, 
        /// PI, Account, Employee</param>
        /// <param name="Criterion">The Code criterion</param>
        /// <param name="Chart">Chart for this grouping -- 3 or L</param>
        [PrincipalPermission(SecurityAction.Demand, Role = "Admin"),
        PrincipalPermission(SecurityAction.Demand, Role = "User")]
        public void deleteAssociationsByGrouping(string OrgR, string Grouping, string Criterion, string Chart)
        {
            dops.ResetDops();
            dops.Sproc = "usp_deleteAssociationsByGrouping";

            dops.SetParameter("OrgR", OrgR, "IN");
            dops.SetParameter("@Grouping", Grouping, "IN");
            dops.SetParameter("@Criterion", Criterion, "IN");
            dops.SetParameter("@Chart", Chart, "IN");

            dops.Execute_Sql();
        }

        /// <summary>
        /// Returns a dataset that groups all of the expense records for a 
        /// specific department together depending on what is given in the
        /// grouping parameter
        /// </summary>
        /// <param name="Grouping">Possible Values: Organization, Sub-Account, 
        /// PI, Account, Employee </param>
        /// <param name="OrgR">The Reporting Org</param>
        public DataSet getExpenseRecordGrouping(string Grouping, string OrgR, bool Associated, bool Unassocaited )
        {
            if (Associated == false && Unassocaited == false)
            {
                DataSet ds = new DataSet();
                ds.Tables.Add();
                return ds;
            }

            dops.ResetDops();
            dops.Sproc = "usp_getExpenseRecordGrouping";

            dops.SetParameter("@Grouping", Grouping, "IN");
            dops.SetParameter("@OrgR", OrgR, "IN");
            dops.SetParameter("@Associated", Associated, "IN");
            dops.SetParameter("@Unassociated", Unassocaited, "IN");

            return dops.get_dataset();
        }

        /// <summary>
        /// Returns an ArrayList with all of the Expenses for a specific grouping as defined by the parameters
        /// </summary>
        /// <param name="Grouping">The Grouping Type</param>
        /// <param name="OrgR">Reporting Org</param>
        /// <param name="Chart">Chart-- 3 or L</param>
        /// <param name="Criterion">The unique criterion associated with the specific grouping</param>
        /// <param name="isAssociated">whether the records we want are already associated or not</param>
        /// <returns>ExpenseID, Expenses, FTE</returns>
        public ArrayList getExpensesByRecordGrouping(string Grouping, string OrgR, string Chart, string Criterion, string isAssociated)
        {
            bool bool_isAssociated = false;
            
            if (isAssociated == "0")
                bool_isAssociated = false;
            else if (isAssociated == "1")
                bool_isAssociated = true;
            else
                throw new Exception("isAssociated not 1 or 0");

            dops.ResetDops();
            dops.Sproc = "usp_getExpensesByRecordGrouping";

            ArrayList fields = new ArrayList();
            
            fields.Add("ExpenseID");
            fields.Add("Expenses");
            fields.Add("FTE");

            dops.SetParameter("@Grouping", Grouping, "IN");
            dops.SetParameter("OrgR", OrgR, "IN");
            dops.SetParameter("Chart", Chart, "IN");
            dops.SetParameter("Criterion", Criterion.Replace("'", "''"), "IN");
            dops.SetParameter("isAssociated", bool_isAssociated, "IN");

            return dops.get_arrayList(fields);
        }

        /// <summary>
        /// Pulls out the associations information for records defined by Criterion and Criterion2 in the context
        /// of the current Grouping and OrgR
        /// </summary>
        /// <param name="Grouping">Possible Values: Organization, Sub-Account, 
        /// PI, Account, Employee</param>
        /// <param name="OrgR">The Reporting Org</param>
        /// <param name="Criterion">The Code for this grouping</param>
        /// <param name="Chart">Chart -- 3 or L</param>
        /// <returns>Project, Spent, FTE</returns>
        public DataSet getAssociationsByGrouping(string Grouping, string OrgR, string Criterion, string Chart, string isAssociated)
        {
            //Don't return any associations for unassocaited records
            if (isAssociated == "0")
            {
                DataSet ds = new DataSet();
                ds.Tables.Add();
                return ds;
            }

            dops.ResetDops();
            dops.Sproc = "usp_getAssociationsByGrouping";

            dops.SetParameter("OrgR", OrgR, "IN");
            dops.SetParameter("@Grouping", Grouping, "IN");
            dops.SetParameter("@Criterion", Criterion.Replace("'","''"), "IN");
            dops.SetParameter("@Chart", Chart, "IN");
            dops.SetParameter("@isAssociated", isAssociated, "IN");

            return dops.get_dataset();
        }

        /// <summary>
        /// Returns the SFN 204 projects information associated with the given OrgR, 
        /// only the projects ending with CG, OG, or SG, as per Steve Pesis. 
        /// 
        /// </summary>
        /// <param name="OrgR">The org to filter on, or 'All' for all</param>
        /// <returns>Project, Accession</returns>
        public DataSet get204ProjectsByDept(string OrgR)
        {
            dops.ResetDops();
            dops.Sproc = "usp_get204ProjectsByDept";

            dops.SetParameter("@OrgR", OrgR, "IN");

            return dops.get_dataset();
        }

        /// <summary>
        /// Returns the project information associated with the given OrgR
        /// </summary>
        /// <param name="OrgR">The org to filter on, or 'All' for all</param>
        /// <returns>Project, Accession</returns>
        public DataSet getProjectsByDept(string OrgR)
        {
            dops.ResetDops();
            dops.Sproc = "usp_getProjectsByDept";

            dops.SetParameter("@OrgR", OrgR, "IN");

            return dops.get_dataset();
        }

        /// <summary>
        /// Return project information in a data set for the given project
        /// </summary>
        /// <param name="ProjectID">The project ID</param>
        /// <returns>DataSet with the Accession, inv1-6, BeginDate, TermDate, ProjTypeCd, RegionalProjNum, StatusCd, Title</returns>
        public DataSet getProjectInfoByID(string ProjectID)
        {
            dops.ResetDops();
            dops.Sproc = "usp_getProjectInfoByID";

            dops.SetParameter("@ProjectID", ProjectID, "IN");

            return dops.get_dataset();
        }

        /// <summary>
        /// Returns a string dictionary relating the project status.  Status can be Active, Expired, or Total
        /// </summary>
        /// <param name="OrgR">Reporting Org</param>
        /// <returns>Dictionary["Status"] ==> Count</returns>
        public System.Collections.Specialized.StringDictionary getActiveProjectsCount(string OrgR)
        {
            dops.ResetDops();
            dops.Sproc = "usp_getActiveProjectsCount";

            dops.SetParameter("@OrgR", OrgR, "IN");

            return dops.get_dictionary("ProjectStatus", "StatusCount");
        }

        /// <summary>
        /// Pulls out Account information for the selected department
        /// </summary>
        /// <param name="OrgR">OrgR or 'All'</param>
        /// <returns>pk, Chart, AccountID, Expenses, AccountName, AwardNum, Principal_Incestigator_Name, Project, TermDate</returns>
        /// <remarks>Queries the FIS database on the same server-- 
        /// so an account to that db needs to be added (with datareader permissions)</remarks>
        public DataSet getProjectAssociations(string OrgR)
        {
            dops.ResetDops();
            dops.Sproc = "usp_getProjectAssociations";

            dops.SetParameter("@OrgR", OrgR, "IN");

            return dops.get_dataset();
        }

        /// <summary>
        /// Changes the association between a project and an account
        /// </summary>
        /// <param name="AccountID">The account</param>
        /// <param name="Project">Project number, which is resolved to Accession number</param>
        [PrincipalPermission(SecurityAction.Demand, Role = "Admin")]
        public void changeProjectAssociation(string AccountID, string Project)
        {
            dops.ResetDops();
            dops.Sproc = "usp_changeProjectAssociation";

            dops.SetParameter("@AccountID", AccountID, "IN");
            dops.SetParameter("@Project", Project, "IN");

            dops.Execute_Sql();
        }

        /// <summary>
        /// Adds the given expense for the specified project to the reporting org
        /// </summary>
        /// <param name="SFN">The SFN Type</param>
        /// <param name="OrgR">OrgR to add the expense to</param>
        /// <param name="Accession">The accession number of the project</param>
        /// <param name="Expense">Total Cost for this Expense</param>
        [PrincipalPermission(SecurityAction.Demand, Role = "Admin")]
        public int insertProjectExpense(string SFN, string OrgR, string Accession, decimal Expense)
        {
            if (string.IsNullOrEmpty(Accession))
                return -1;

            dops.ResetDops();
            dops.Sproc = "usp_insertProjectExpense";

            dops.SetParameter("@SFN", SFN, "IN");
            dops.SetParameter("@OrgR", OrgR, "IN");
            dops.SetParameter("@Accession", Accession, "IN");
            dops.SetParameter("@Expenses", (double)Expense, "IN");
            dops.SetParameter("RETURN_VALUE", 1, "return");

            dops.Execute_Sql();

            return (int)dops.GetOutputVariable("RETURN_VALUE");
        }

        /// <summary>
        ///  Obtains a list of PI names based on the OrgR code.
        /// </summary>
        /// <param name="OrgR">The department org code</param>
        public DataSet getPINames(string OrgR)
        {
            dops.ResetDops();
            dops.Sproc = "usp_GetPINames";
            dops.SetParameter("@OrgR", OrgR, "IN");

            return dops.get_dataset();
        }

        /// <summary>
        /// Gets the line expenses for SFN Totals.  Includes headers, sums, and totals
        /// </summary>
        /// <param name="OrgR">The OrgR to filter by, or 'All' for all</param>
        /// <returns>GroupDisplayOrder, LineDisplayOrder, LineTypeCode, LineDisplayDescriptor, SFN, Total</returns>
        public DataSet getSFNTotalExpenses(string OrgR)
        {
            dops.ResetDops();
            dops.Sproc = "usp_GetSFNTotalExpenses";
            dops.SetParameter("@OrgR", OrgR, "IN");

            return dops.get_dataset();
        }

        /// <summary>
        /// Within a transaction, this function runs through the transactionArray and deletes all associations
        /// for any ExpenseID in the transaction array
        /// </summary>
        /// <param name="transactionArray">2D Array of ExpenseIDs (ExpenseID must be in pos[i][0]</param>
        /// <param name="OrgR">Reporting Org</param>
        [PrincipalPermission(SecurityAction.Demand, Role = "Admin"),
        PrincipalPermission(SecurityAction.Demand, Role = "User")]
        public void deleteAssociationsTransaction(ArrayList transactionArray, string OrgR)
        {
            string connectionString = System.Web.Configuration.WebConfigurationManager.ConnectionStrings["MainDB"].ConnectionString;
            string sprocDelete = "usp_deleteAssociation";

            //Open the SQL connection
            System.Data.SqlClient.SqlConnection connection = new System.Data.SqlClient.SqlConnection(connectionString);

            System.Data.SqlClient.SqlTransaction transaction = null;
            //Whole execution cycle is in try...catch block so the transaction can be rolled back if there is an exception thrown
            try
            {
                connection.Open();

                //Begin the transaction
                transaction = connection.BeginTransaction();

                //Build the command
                System.Data.SqlClient.SqlCommand dbCommand = new System.Data.SqlClient.SqlCommand();
                dbCommand.Connection = connection;

                //First run the delete command to wipe out all associations before re-associating
                dbCommand.CommandText = sprocDelete;
                dbCommand.CommandType = CommandType.StoredProcedure;
                dbCommand.Transaction = transaction;

                dbCommand.Parameters.Clear();

                //Delete the associations for this OrgR, ExpenseID combination (which show never change within this function)
                dbCommand.Parameters.AddWithValue("@OrgR", OrgR);
                dbCommand.Parameters.Add("@ExpenseID", SqlDbType.Int);
                
                for (int i = 0; i < transactionArray.Count; i++)
                {
                    ArrayList currentTransaction = (ArrayList)transactionArray[i];

                    dbCommand.Parameters["@ExpenseID"].Value = (int)currentTransaction[0];

                    dbCommand.ExecuteNonQuery();
                }

                //If we made it here, no exceptions were thrown and we executed all of our db queries, so commit the transaction
                transaction.Commit();
            }
            catch (Exception ex)
            {
                //Rollback on error and throw the exception
                transaction.Rollback();
                throw;
            }
            finally
            {
                connection.Close();
            }
        }

        /// <summary>
        /// Inserts Associations for a record grouping into the database in a transaction
        /// </summary>
        /// <param name="transactionArray">2D Array which is an array of parameter arrays</param>
        /// <param name="OrgR">The Reporting Org creating the associations</param>
        /// <remarks>This transaction will have static parameter names that correspond with a specific order for the
        /// insertAssociations action -- ExpenseID, Accession, Expense (Spent), FTE.
        /// All associations associated with an ExpenseID contained in the transaction array will be deleted before
        /// any work is to begin</remarks>
        [PrincipalPermission(SecurityAction.Demand, Role = "Admin"),
        PrincipalPermission(SecurityAction.Demand, Role = "User")]
        public void insertAssociationsTransaction(ArrayList transactionArray, string OrgR)
        {
            string connectionString = System.Web.Configuration.WebConfigurationManager.ConnectionStrings["MainDB"].ConnectionString;
            string sproc = "usp_insertAssociation";
            string sprocDelete = "usp_deleteAssociation";

            //Open the SQL connection
            System.Data.SqlClient.SqlConnection connection = new System.Data.SqlClient.SqlConnection(connectionString);

            System.Data.SqlClient.SqlTransaction transaction = null;
            //Whole execution cycle is in try...catch block so the transaction can be rolled back if there is an exception thrown
            try
            {
                connection.Open();

                //Begin the transaction
                transaction = connection.BeginTransaction();

                //Build the command
                System.Data.SqlClient.SqlCommand dbCommand = new System.Data.SqlClient.SqlCommand();
                dbCommand.Connection = connection;

                //First run the delete command to wipe out all associations before re-associating
                dbCommand.CommandText = sprocDelete;
                dbCommand.CommandType = CommandType.StoredProcedure;
                dbCommand.Transaction = transaction;

                dbCommand.Parameters.Clear();

                //Delete the associations for this OrgR, ExpenseID combination (which show never change within this function)
                dbCommand.Parameters.AddWithValue("@OrgR", OrgR);
                dbCommand.Parameters.Add("@ExpenseID", SqlDbType.Int);

                for (int i = 0; i < transactionArray.Count; i++)
                {
                    ArrayList currentTransaction = (ArrayList)transactionArray[i];

                    dbCommand.Parameters["@ExpenseID"].Value = (int)currentTransaction[0];

                    dbCommand.ExecuteNonQuery();
                }

                //Now that we deleted the association and are starting fresh, insert the proper associations
                
                dbCommand.CommandText = sproc;
                dbCommand.CommandType = CommandType.StoredProcedure;
                dbCommand.Transaction = transaction;

                //For each entry in the transaction array
                for (int i = 0; i < transactionArray.Count; i++)
                {
                    //We are expecing 4 parameters
                    if (((ArrayList)transactionArray[i]).Count == 4)
                    {
                        //Clear the parameters from the previous execution
                        dbCommand.Parameters.Clear();

                        //Add all of the parameters here for this row in the transaction array
                        dbCommand.Parameters.AddWithValue("@OrgR", OrgR);
                        dbCommand.Parameters.AddWithValue("@ExpenseID", (int)((ArrayList)transactionArray[i])[0]);
                        dbCommand.Parameters.AddWithValue("@Accession", (string)((ArrayList)transactionArray[i])[1]);
                        dbCommand.Parameters.AddWithValue("@Expenses", (double)((ArrayList)transactionArray[i])[2]);
                        dbCommand.Parameters.AddWithValue("@FTE", (double)((ArrayList)transactionArray[i])[3]);

                        //Execute
                        dbCommand.ExecuteNonQuery();
                    }
                }

                //If we made it here, no exceptions were thrown and we executed all of our db queries, so commit the transaction
                transaction.Commit();
            }
            catch (Exception ex)
            {
                //Rollback on error and throw the exception
                transaction.Rollback();
                throw;
            }
            finally
            {
                connection.Close();
            }

        }

        /// <summary>
        /// Get the pay info for any employees who's names contain the EmployeeName we are searching for
        /// </summary>
        /// <param name="EmployeeName">Any portion of the Employee's name (usually last name)</param>
        /// <returns>EmployeeID, Title_Code, Pay_Rate, Percent_Fulltime, Emp_name, Home_Dept</returns>
        public DataSet getPIPayInfo(string EmployeeName)
        {
            dops.ResetDops();
            dops.Sproc = "usp_LookupPIPayInfo";
            dops.SetParameter("@EmployeeName", EmployeeName, "input");

            return dops.get_dataset();
        }

        /// <summary>
        /// Inserts a CE entry into the database.
        /// </summary>
        /// <param name="EID">EmployeeID</param>
        /// <param name="AccountPIName">PI on the Account</param>
        /// <param name="Title_Code">Title Code</param>
        /// <param name="Accession">Accession of the Project to associate this entry with</param>
        /// <param name="OrgR">Reporting Org to group against</param>
        /// <param name="PctEffort">Percent effort of CE on this project</param>
        /// <param name="CESSalaryExpenses">The CEs salary for the chosen appointment</param>
        /// <param name="PctFTE">Percent FTE of CE on this project</param>
        [PrincipalPermission(SecurityAction.Demand, Role = "Admin")]
        public void insertCES(string EID, string AccountPIName, string Title_Code, string Accession, string OrgR, double PctEffort, double CESSalaryExpenses, double PctFTE)
        {
            dops.ResetDops();
            dops.Sproc = "usp_InsertCES";
            dops.SetParameter("@EID", EID, "input");
            dops.SetParameter("@AccountPIName", AccountPIName, "input");
            dops.SetParameter("@Title_Code", Title_Code, "input");
            dops.SetParameter("@Accession", Accession, "input");
            dops.SetParameter("@OrgR", OrgR, "input");
            dops.SetParameter("@PctEffort", PctEffort, "input");
            dops.SetParameter("@CESSalaryExpenses", CESSalaryExpenses, "input");
            //dops.SetParameter("@CESNonSalaryExpenses", CESNonSalaryExpenses, "input");
            dops.SetParameter("@PctFTE", PctFTE, "input");
            dops.Execute_Sql();
        }

        /// <summary>
        /// Returns all of the current CE <-> Project associations
        /// </summary>
        /// <returns>PI Name, Project, Percent Effort</returns>
        public DataSet getCEAssociations()
        {
            dops.ResetDops();
            dops.Sproc = "usp_getCEAssociations";

            return dops.get_dataset();
        }

        /// <summary>
        /// Gets the data on total expenses for a department.
        /// </summary>
        /// <param name="OrgR">The org code</param>
        /// <returns></returns>
        public DataSet getTotalExpensesByDept(string OrgR)
        {
            dops.ResetDops();
            dops.Sproc = "usp_getTotalExpensesByDept";
            dops.SetParameter("@OrgR", OrgR, "input");
            return dops.get_dataset();
        }

        /// <summary>
        /// Gets the current fiscal year for the AD-419 Reporting Period from the AD-419
        /// database instead of the web.config file, allowing the application to use the value 
        /// set by the user in the AD-419 Data Helper application.
        /// </summary>
        /// <returns>Current Fiscal Year string</returns>
        public string getCurrentFiscalYear()
        {
            dops.ResetDops();
            dops.Sproc = "usp_GetCurrentFiscalYear";
            
            dops.SetParameter("@CurrentFiscalYear", 0, "output");
           
            dops.Execute_Sql();

            var fiscalYear = (int)dops.GetOutputVariable("@CurrentFiscalYear");
            
            return fiscalYear.ToString();
        }

        /// <summary>
        /// Returns the object as a string or string.empty if it is null
        /// </summary>
        private string GetNullSafeString(object obj)
        {
            return obj as string ?? string.Empty;
        }
    } 
}
