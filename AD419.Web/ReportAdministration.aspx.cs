using System;
using System.Data;
using System.Configuration;
using System.Collections;
using System.Web;
using System.Web.Security;
using System.Web.UI;
using System.Web.UI.WebControls;
using System.Web.UI.WebControls.WebParts;
using System.Web.UI.HtmlControls;
using System.Data.SqlClient;

namespace CAESDO
{
    public partial class ReportAdministration : ApplicationPage
    {
#region Page Methods

        /// <summary>
        /// Page Load.  Sets the initial type of report that we want to look at.
        /// </summary>
        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack)
            {
                AD419Configuration.ReportAdministrationType primaryType = AD419Configuration.ReportAdministrationType.Expense;
                setupReportAdministrationType(primaryType);
            }
        }

#endregion

#region Object Callbacks
        /// <summary>
        /// Populates the textboxes, Investigators and departments when a Project is selected
        /// </summary>
        protected void gviewProjects_SelectedIndexChanged(object sender, EventArgs e)
        {
            //Grab the Accession Number for the select project from the datakeys
            string SelectedAccession = ((GridView)sender).SelectedDataKey["Accession"].ToString();

            string project = null;
            string title = null;

            //User the data access class to get back the project info
            AD419DataAccess daccess = new AD419DataAccess();
            ArrayList investigators = null;

            try
            {
                investigators = daccess.getInterdepartmentalProjectInfo(SelectedAccession, out project, out title);
            }
            catch (SqlException ex)
            {
                AD419ErrorReporting.ReportError(ex, "gviewProjects_SelectedIndexChanged");
                Response.Redirect(AD419Configuration.ErrorPage(AD419Configuration.ErrorType.DATA));
            }

            //Show the investigators and departments
            pnlDepartment.Visible = true;
            pnlInvestigator.Visible = true;

            //Populate the text boxes
            txtAccession.Text = SelectedAccession;
            txtProject.Text = project;
            txtTitle.Text = title;

            //Bind the investigators to the grid
            gviewInvestigators.DataSource = investigators;
            gviewInvestigators.DataBind();


        }

        /// <summary>
        /// Adds a department to the interdepartmental grid.
        /// </summary>
        protected void lbtnAddDepartment_Click(object sender, EventArgs e)
        {
            //Get the accession number
            string Accession = gviewProjects.SelectedDataKey["Accession"].ToString();
            //get the CRISDeptCd from the footer row
            string CRISDeptCd = ((DropDownList)gViewDepartments.FooterRow.FindControl("dlistAllDepartments")).SelectedValue;

            //Now insert them into the db using the data access business layer
            AD419DataAccess data = new AD419DataAccess();

            try
            {
                data.insertSecondaryDepartments(Accession, CRISDeptCd);
            }
            catch (SqlException ex)
            {
                //Catch Error
                AD419ErrorReporting.ReportError(ex, "lbtnAddDepartment");
                Response.Redirect(AD419Configuration.ErrorPage(AD419Configuration.ErrorType.DATA));
            }

            //Rebind only the depts grid to show the newly added entry
            gViewDepartments.DataBind();
            gViewProjectAssociations.DataBind();
            dlistAddExpenseProject.DataBind();
            DDL_Project.Items.Clear();
            DDL_Project.DataBind();
            DDL_Project.Items.Insert(0, new ListItem("-- Select Project --", "0"));

            //Also rebind the Project table to update the count, but keep the selected index
            rebindGrid(gviewProjects);
        }

        /// <summary>
        /// Adds the first department to the interdepartmental grid.  This is called from the
        /// empty data template and not the footer template
        /// </summary>
        /// <remarks>GridView.Controls[0].Controls[0] represents the empty data template when it exists</remarks>
        protected void lbtnAddFirstDepartment_Click(object sender, EventArgs e)
        {
            //Make sure an entry is selected
            if (gviewProjects.SelectedIndex < 0)
                return;

            //Get the accession number
            string Accession = (string)gviewProjects.SelectedDataKey["Accession"];
            //get the CRISDeptCd from the empty data row
            string CRISDeptCd = ((DropDownList)gViewDepartments.Controls[0].Controls[0].FindControl("dlistAddFirstDepartment")).SelectedValue;

            AD419DataAccess data = new AD419DataAccess();

            try
            {
                data.insertSecondaryDepartments(Accession, CRISDeptCd);
            }
            catch (SqlException ex)
            {
                AD419ErrorReporting.ReportError(ex, "lbtnAddFirstDepartment_Click");
                Response.Redirect(AD419Configuration.ErrorPage(AD419Configuration.ErrorType.DATA));
            }

            //Rebind the grid to deplay the item template instead of the empty data template
            gViewDepartments.DataBind();
            gViewProjectAssociations.DataBind();
            dlistAddExpenseProject.DataBind();
            DDL_Project.Items.Clear();
            DDL_Project.DataBind();
            DDL_Project.Items.Insert(0, new ListItem("-- Select Project --", "0"));

            //Also rebind the Project table to update the count, but keep the selected index
            rebindGrid(gviewProjects);

        }

        /// <summary>
        /// Rebinds the project grid when a delete occurs so that the count is up to date
        /// </summary>
        protected void lbtnRemoveDepartment_Click(object sender, EventArgs e)
        {
            ImageButton lbtn = (ImageButton)sender;

            //Make sure an entry is selected
            if (gviewProjects.SelectedIndex < 0)
                return;

            //Get CRISDeptCd from the lbtn's command argument
            string CRISDeptCd = lbtn.CommandArgument;
            //Get the accession number
            string Accession = (string)gviewProjects.SelectedDataKey["Accession"];
            //Now we have a valid CRISDeptCd, so do the deletion from the accession number and CRISDeptCd

            int returnValue = 0;
            AD419DataAccess data = new AD419DataAccess();

            try
            {
                returnValue = data.removeSecondaryDepartments(Accession, CRISDeptCd);
            }
            catch (SqlException ex)
            {
                AD419ErrorReporting.ReportError(ex, "lbtnRemoveDepartment_Click");
                Response.Redirect(AD419Configuration.ErrorPage(AD419Configuration.ErrorType.DATA));
            }

            if (returnValue != 0)
            {
                //If there is an error with the deletion
                lblInterdepartmentalError.Text = "Department not removed:  Would cause 204 association to be orphaned";
            }
            else
            {
                lblInterdepartmentalError.Text = string.Empty;

                //Rebind the departments table to reflect the deletion
                gViewDepartments.DataBind();
                gViewProjectAssociations.DataBind();
                dlistAddExpenseProject.DataBind();
                DDL_Project.Items.Clear();
                DDL_Project.DataBind();
                DDL_Project.Items.Insert(0, new ListItem("-- Select Project --", "0"));

                //Rebind the project grid
                rebindGrid(gviewProjects);
            }
        }

        /// <summary>
        /// Hack to get the dlistProject in the ProjectAssociations grid to bind to the chosen project.
        /// This gets around the fact that some projects can be null and thus unbindable.
        /// </summary>
        /// <remarks>The hack is to insert a blank row in case there are nulls, and then remove that row
        /// once databinding is complete.  See the reference for more info.</remarks>
        /// <see cref="http://aspzone.com/blogs/john/archive/2006/05/09/1775.aspx"/>
        protected void dlistProject_DataBound(object sender, EventArgs e)
        {
            DropDownList dlist = (DropDownList)sender;

            ListItem blank = dlist.Items.FindByValue("");
            if (blank != null)
            {
                blank.Text = "-- Choose a Project --";
             //   dlist.Items.Remove(blank);
            }

        }

        /// <summary>
        /// Ensures that the selected value of the dropdownlist will get entered into the database
        /// </summary>
        /// <param name="sender">The dropdownlist</param>
        /// <param name="e">e.NewValues stores the values to be updated</param>
        /// <remarks>Because of Database inconsistencies, we are using this instead of Bind("") in the aspx code.
        /// The selected values of the project DDL are not always the </remarks>
        protected void gViewProjectAssociations_RowUpdating(object sender, GridViewUpdateEventArgs e)
        {
            GridViewRow row = gViewProjectAssociations.Rows[e.RowIndex];

            DropDownList dlist = (DropDownList)row.FindControl("dlistProject");

            e.NewValues["Project"] = dlist.SelectedValue;
        }

        /// <summary>
        /// Temporary method that changes the report type depending on the dlist's choice
        /// </summary>
        protected void dlistSelectAdminType_SelectedIndexChanged(object sender, EventArgs e)
        {
            DropDownList dlist = (DropDownList)sender;

            switch (dlist.SelectedValue)
            {
                case "Expenses": setupReportAdministrationType(AD419Configuration.ReportAdministrationType.Expense); break;
                case "Interdepartmental": setupReportAdministrationType(AD419Configuration.ReportAdministrationType.Interdepartmental); break;
                case "Associations": setupReportAdministrationType(AD419Configuration.ReportAdministrationType.Association); break;
            }
        }

        /// <summary>
        /// Customizes drop down lists in the add expense panel depending on which department is chosen
        /// </summary>
        protected void dlistFilterReportingOrg_SelectedIndexChanged(object sender, EventArgs e)
        {
            DropDownList dlist = (DropDownList)sender;

            // Make the user choose a department before adding an expense
            if (dlist.SelectedValue == "All")
            {
                btnConfirmAddExpense.Enabled = false;
                lblAddExpenseInfo.Text = "You Must Choose a Department and SFN Before Adding An Expense";
                return;
            }
            else
            {
                //make the text be equal to the selected value of the sender
                txtAddExpenseOrgR.Text = dlist.SelectedValue;

                //Enable add features if an SFN is selected as well
                if ( dlistFilterSFN.SelectedValue != "All" )
                {
                    btnConfirmAddExpense.Enabled = true;
                    lblAddExpenseInfo.Text = string.Empty;
                }
            }
        }

        /// <summary>
        /// Customizes the Add Expense panel depending on which department is chosen
        /// </summary>
        protected void dlistFilterSFN_SelectedIndexChanged(object sender, EventArgs e)
        {
            DropDownList dlist = (DropDownList)sender;

            if (dlist.SelectedValue == "All")
            {
                btnConfirmAddExpense.Enabled = false;
                lblAddExpenseInfo.Text = "You Must Choose a Department and SFN Before Adding An Expense";
                return;
            }
            else
            {
                //make the text be equal to the selected value of the sender
                txtAddExpenseSFN.Text = dlist.SelectedValue;

                //Enable add features if a department is selected as well
                if ( dlistFilterReportingOrg.SelectedValue != "All" )
                {
                    btnConfirmAddExpense.Enabled = true;
                    lblAddExpenseInfo.Text = string.Empty;
                }
            }
        }

        /// <summary>
        /// Adds an Expense to the Expense List
        /// </summary>
        protected void btnConfirmAddExpense_Click(object sender, EventArgs e)
        {
            //Get the SFN and OrgR
            string SFN = txtAddExpenseSFN.Text;
            string OrgR = txtAddExpenseOrgR.Text;

            //Now get the Accession number for the project to be associated
            string Accession = dlistAddExpenseProject.SelectedValue;

            //Get the expense, and parse it into a decimal number using the Currency rules built in to .NET
            decimal expense = 0;

            //Check that the Accession has a value
            if (string.IsNullOrEmpty(Accession))
            {
                lblAddExpense.Text = "Expense Not Added";
                return;
            }

            //Make sure the expense is a valid number
            if (!decimal.TryParse(txtAddExpenseExpenses.Text, System.Globalization.NumberStyles.Currency, null, out expense))
            {
                lblAddExpense.Text = "Expense Not Added";
                return;
            }
            else
            {
                lblAddExpense.Text = string.Empty;
            }

            //Now we have all the parameters, so we'll insert the expense into the DB
            AD419DataAccess data = new AD419DataAccess();
            int returnValue = 0;

            try
            {
                returnValue = data.insertProjectExpense(SFN, OrgR, Accession, expense);
            }
            catch (SqlException ex)
            {
                AD419ErrorReporting.ReportError(ex, "btnConfirmAddExpense_Click");
                Response.Redirect(AD419Configuration.ErrorPage(AD419Configuration.ErrorType.DATA));
            }

            if (returnValue == 0)
            {
                //Now rebind the project expenses datagrid and the subtotals grid to reflect the change
                gViewProjectExpenses.DataBind();
                gViewSFNSubtotals.DataBind();
                lblAddExpense.Text = string.Empty;
            }
            else
            {
                lblAddExpense.Text = "Expense Not Added: Please Choose a Valid Project";
            }
        }

        /// <summary>
        /// Rebind the subtotals datagrid when any row is updated
        /// </summary>
        protected void gViewProjectExpenses_RowUpdated(object sender, GridViewUpdatedEventArgs e)
        {
            gViewSFNSubtotals.DataBind();
        }

        /// <summary>
        /// Rebind the subtotals datagrid when any row is deleted
        /// </summary>
        protected void gViewProjectExpenses_RowDeleted(object sender, GridViewDeletedEventArgs e)
        {
            gViewSFNSubtotals.DataBind();
        }

#endregion

#region Private Methods

        /// <summary>
        /// Sets the type of report selected
        /// </summary>
        /// <param name="currentType">Enum of the type of report (AD419Configuration construct)</param>
        private void setupReportAdministrationType(AD419Configuration.ReportAdministrationType currentType)
        {
            if (currentType == AD419Configuration.ReportAdministrationType.Expense)
            {
                //Show the correct panel
                pnlProjectExpenses.Visible = true;
                pnlInterdepartmentalAssociations.Visible = false;
                pnlProjectAssociations.Visible = false;
                pnl_CEEntry.Visible = false;
            }
            else if (currentType == AD419Configuration.ReportAdministrationType.Association)
            {
                //Show the correct panel
                pnlProjectAssociations.Visible = true;
                pnlProjectExpenses.Visible = false;
                pnlInterdepartmentalAssociations.Visible = false;
                pnl_CEEntry.Visible = false;
            }
            else if (currentType == AD419Configuration.ReportAdministrationType.Interdepartmental)
            {
                //Show the correct panel
                pnlInterdepartmentalAssociations.Visible = true;
                pnlProjectExpenses.Visible = false;
                pnlProjectAssociations.Visible = false;
                pnl_CEEntry.Visible = false;
            }
            else if (currentType == AD419Configuration.ReportAdministrationType.CEEntry)
            {
                pnl_CEEntry.Visible = true;
                pnlInterdepartmentalAssociations.Visible = false;
                pnlProjectExpenses.Visible = false;
                pnlProjectAssociations.Visible = false;
            }
        }

        /// <summary>
        /// Rebinds the given GridView, keeping track of its selected index
        /// </summary>
        /// <param name="grid">The grid that should be re-bound</param>
        private void rebindGrid(GridView grid)
        {
            //keep the selected index
            int Selected = grid.SelectedIndex;

            //Rebind
            grid.DataBind();

            //Reset the selected index
            grid.SelectedIndex = Selected;
        }

#endregion

        protected void ImageButton2_Click(object sender, ImageClickEventArgs e)
        {
            ibutExpenses.ImageUrl = "Images/ad419b_05.gif";
            ibutInterdept.ImageUrl = "Images/ad419b_06.gif";
            ibutProject.ImageUrl = "Images/ad419_07.gif";
            ibutCoop.ImageUrl = "Images/ad419_08.gif";
            AD419Configuration.ReportAdministrationType type = AD419Configuration.ReportAdministrationType.Interdepartmental;
            setupReportAdministrationType(type);
        }
        protected void ibutExpenses_Click(object sender, ImageClickEventArgs e)
        {   
            ibutExpenses.ImageUrl = "Images/ad419_05.gif";
            ibutInterdept.ImageUrl = "Images/ad419_06.gif";
            ibutProject.ImageUrl = "Images/ad419_07.gif";
            ibutCoop.ImageUrl = "Images/ad419_08.gif";
            AD419Configuration.ReportAdministrationType type = AD419Configuration.ReportAdministrationType.Expense;
            setupReportAdministrationType(type);
        }
        protected void ibutProject_Click(object sender, ImageClickEventArgs e)
        {
            ibutExpenses.ImageUrl = "Images/ad419b_05.gif";
            ibutInterdept.ImageUrl = "Images/ad419_06.gif";
            ibutProject.ImageUrl = "Images/ad419b_07.gif";
            ibutCoop.ImageUrl = "Images/ad419_08.gif";
            AD419Configuration.ReportAdministrationType type = AD419Configuration.ReportAdministrationType.Association;
            setupReportAdministrationType(type);
        }
        protected void ibutCoop_Click(object sender, ImageClickEventArgs e)
        {
            ibutExpenses.ImageUrl = "Images/ad419b_05.gif";
            ibutInterdept.ImageUrl = "Images/ad419_06.gif";
            ibutProject.ImageUrl = "Images/ad419_07.gif";
            ibutCoop.ImageUrl = "Images/ad419b_08.gif";
            setupReportAdministrationType(AD419Configuration.ReportAdministrationType.CEEntry);
        }

        #region CE Entry
        protected void DDL_Department_SelectedIndexChanged(object sender, EventArgs e)
        {
            if (DDL_Department.SelectedIndex != 0)
            {
                Panel_SearchPI.Visible = false;

                lbl_PayRate.Text = "";
                lbl_percentFullTime.Text = "";
                TextBox_EID.Text = "";
                TextBox_EID.Enabled = false;
                TextBox_Title_Code.Enabled = false;
                TextBox_Title_Code.Text = string.Empty;
                DDL_Project.Enabled = false;
                if (DDL_Project.Items.Count != 0)
                {
                    DDL_Project.Items.Clear();
                    DDL_Project.DataBind();
                    DDL_Project.Items.Insert(0, new ListItem("-- Select Project --", "0"));
                    DDL_Project.SelectedIndex = 0;
                }
                TextBox_PercentEffort.Text = "";
                TextBox_PercentEffort.Enabled = false;

                DDL_PI.Items.Clear();
                DDL_PI.Items.Add(new ListItem("-- Select PI --", "0"));
                DDL_PI.DataBind();

                AD419DataAccess DA = new AD419DataAccess();

                DDL_PI.Enabled = true;
                btn_SearchPI.Enabled = true;

                try
                {
                    DDL_PI.DataSource = DA.getPINames(DDL_Department.SelectedItem.Value);
                }
                catch (SqlException ex)
                {
                    AD419ErrorReporting.ReportError(ex, "DDL_Department_SelectedIndexChanged");
                    Response.Redirect(AD419Configuration.ErrorPage(AD419Configuration.ErrorType.DATA));
                }

                DDL_PI.DataBind();
            }
            else
            {
                resetCEEntry();
            }
        }
        protected void DDL_PI_SelectedIndexChanged(object sender, EventArgs e)
        {
            lbl_PayRate.Text = "";
            lbl_percentFullTime.Text = "";
            TextBox_EID.Text = "";
            TextBox_EID.Enabled = false;
            TextBox_Title_Code.Text = string.Empty;
            TextBox_Title_Code.Enabled = false;
            if (DDL_Project.Items.Count != 0)
            {
                DDL_Project.SelectedIndex = 0;
            }
            DDL_Project.Enabled = false;
            TextBox_PercentEffort.Text = "";
            TextBox_PercentEffort.Enabled = false;

            // Make sure an actual PI is selected
            if (DDL_PI.SelectedItem.Value != "0")
            {
                // Strip out the middle initial for searching
                string PIname = DDL_PI.SelectedItem.Text;
                int index = PIname.IndexOf(' ');
                if ( index > 0 )
                    PIname = PIname.Substring(0, index);

                AD419DataAccess DA = new AD419DataAccess();
                DataSet ds = null;

                try
                {
                    ds = DA.getPIPayInfo(PIname.Replace("'", "''''"));
                }
                catch (SqlException ex)
                {
                    AD419ErrorReporting.ReportError(ex, "DDL_PI_SelectedIndexChanged");
                    Response.Redirect(AD419Configuration.ErrorPage(AD419Configuration.ErrorType.DATA));
                }

                if (ds.Tables[0].Rows.Count > 1)
                {
                    Panel_SearchPI.Visible = true;
                    Textbox_PISearch.Text = PIname;

                    gv_PISearch.Visible = true;
                    gv_PISearch.DataSource = ds;
                    gv_PISearch.DataBind();
                }
                else if (ds.Tables[0].Rows.Count == 1)
                {
                    DataRow dr = ds.Tables[0].Rows[0];

                    lbl_PayRate.Text = dr.ItemArray[2].ToString();
                    lbl_percentFullTime.Text = (Convert.ToDouble(dr.ItemArray[3]) * 100.0).ToString();


                    lbl_PayRate.Visible = true;
                    lbl_percentFullTime.Visible = true;
                    TextBox_EID.Text = dr.ItemArray[0].ToString();
                    TextBox_EID.Enabled = true;
                    TextBox_Title_Code.Enabled = true;
                    TextBox_Title_Code.Text = dr.ItemArray[1].ToString();
                    lbl_PIName.Text = DDL_PI.SelectedItem.Text;

                    Panel_SearchPI.Visible = false;

                    DDL_Project.Enabled = true;
                }
                else
                {
                    lbl_percentFullTime.Text = "no results";

                    gv_PISearch.Visible = false;
                    Textbox_PISearch.Text = "";
                    lbl_PIName.Text = "";
                }
            }
        }
        protected void btn_Search_Click(object sender, EventArgs e)
        {
            AD419DataAccess AD = new AD419DataAccess();
            DataSet ds = null;

            try
            {
                ds = AD.getPIPayInfo(Textbox_PISearch.Text.ToUpper());
            }
            catch (SqlException ex)
            {
                AD419ErrorReporting.ReportError(ex, "btn_Search_Click");
                Response.Redirect(AD419Configuration.ErrorPage(AD419Configuration.ErrorType.DATA));
            }

            gv_PISearch.DataSource = ds;
            gv_PISearch.DataBind();
        }
        protected void btn_SearchPI_Click(object sender, EventArgs e)
        {
            if ( DDL_Project.Items.Count != 0 )
                DDL_Project.SelectedIndex = 0;

            DDL_Project.Enabled = false;

            TextBox_PercentEffort.Enabled = false;

            gv_PISearch.Visible = true;
            Panel_SearchPI.Visible = true;

            Textbox_PISearch.Text = "";
        }
        protected void gv_PISearch_SelectedIndexChanged(object sender, EventArgs e)
        {
            lbl_PayRate.Visible = true;
            lbl_PayRate.Text = gv_PISearch.SelectedRow.Cells[5].Text;
            lbl_percentFullTime.Visible = true;
            lbl_percentFullTime.Text = (Convert.ToDouble(gv_PISearch.SelectedRow.Cells[6].Text) * 100.0).ToString();
            TextBox_Title_Code.Enabled = true;
            TextBox_Title_Code.Text = gv_PISearch.SelectedRow.Cells[4].Text;
            TextBox_EID.Enabled = true;
            TextBox_EID.Text = gv_PISearch.SelectedRow.Cells[1].Text;
            lbl_PIName.Text = gv_PISearch.SelectedRow.Cells[2].Text;

            Panel_SearchPI.Visible = false;

            DDL_Project.Enabled = true;
        }
        protected void DDL_Project_SelectedIndexChanged(object sender, EventArgs e)
        {
            TextBox_PercentEffort.Text = "";

            TextBox_PercentEffort.Enabled = true;
        }

        protected void Button_InsertCES_Click(object sender, EventArgs e)
        {
            // Calculate the Salary Expense
            double salary = Convert.ToDouble(lbl_PayRate.Text);
            double percentFullTime = Convert.ToDouble(lbl_percentFullTime.Text);
            double percentEffort = Convert.ToDouble(TextBox_PercentEffort.Text);

            percentFullTime = percentFullTime / 100; // Convert it to a decimal
            percentEffort = percentEffort / 100; // Convert it to a decimal

            double salaryExpense = salary * percentFullTime * percentEffort;

            AD419DataAccess ad = new AD419DataAccess();

            try
            {
                ad.insertCES(TextBox_EID.Text, lbl_PIName.Text, TextBox_Title_Code.Text, DDL_Project.SelectedItem.Value, DDL_Department.SelectedItem.Value, (percentEffort * 100), salaryExpense, (percentFullTime * percentEffort) * 100);

            }
            catch (SqlException ex)
            {
                AD419ErrorReporting.ReportError(ex, "Button_InsertCES_Click");
                Response.Redirect(AD419Configuration.ErrorPage(AD419Configuration.ErrorType.DATA));
            }

            lblCEEntryStatus.Text = "Inserted " + lbl_PIName.Text;
            
            resetCEEntry();
        }

        private void resetCEEntry()
        {
            DDL_PI.SelectedIndex = 0;
            //DDL_PI.Enabled = false;
            lbl_PayRate.Text = string.Empty;
            lbl_percentFullTime.Text = string.Empty;
            TextBox_EID.Text = string.Empty;
            TextBox_EID.Enabled = false;
            TextBox_Title_Code.Text = string.Empty;
            TextBox_Title_Code.Enabled = false;
            DDL_Project.SelectedIndex = 0;
            DDL_Project.Enabled = false;
            TextBox_PercentEffort.Text = string.Empty;
            TextBox_PercentEffort.Enabled = false;
            lbl_PIName.Text = string.Empty;
            gViewCEAssociations.DataBind();
        }

        #endregion


        protected void ImageButton1_Click(object sender, ImageClickEventArgs e)
        {
            ImageButton1.ImageUrl = "Images/xxxprojects.gif";
        }
}

}