using System;
using System.Collections;
using System.Collections.Specialized;
using System.Data;
using System.Data.SqlClient;
using System.Web.Security;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace CAESDO
{
    public partial class ReportingModule : ApplicationPage
    {
        /// <summary>
        /// Page_Load
        /// </summary>
        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack)
            {
                if (Roles.IsUserInRole("Reader") && !Roles.IsUserInRole("Admin") && !Roles.IsUserInRole("User"))
                {
                    btnAssociateRecords.Enabled = false;
                    btnUnassociateRecords.Enabled = false;
                }

                //Sets the initial type of reporting module that we want to look at.
                AD419Configuration.ReportingModuleType primaryType = AD419Configuration.ReportingModuleType.ProjectInformation;
                setupReportView(primaryType);

                //Populate the project details for the initial project.  Must bind the department dlist
                //first because the project dlist depends on it
                dlistDepartment.DataBind();
                dlistProjectID.DataBind();
                populateProjectBody(dlistProjectID.SelectedValue);

                //addProjectInfoToDropDownList(dl_ViewMode);

                AD419DataAccess da = new AD419DataAccess();
                DataSet ds = new DataSet();
                StringDictionary projectStatusDictionary = new StringDictionary();

                try
                {
                    ds = da.getTotalExpensesByDept(dlistDepartment.SelectedValue);
                    projectStatusDictionary = da.getActiveProjectsCount(dlistDepartment.SelectedValue);
                }
                catch (SqlException ex)
                {
                    AD419ErrorReporting.ReportError(ex, "Page_Load");
                    Response.Redirect(AD419Configuration.ErrorPage(AD419Configuration.ErrorType.DATA));
                }

                lblProjectsActive.Text = projectStatusDictionary["Active"];
                lblProjectsExpired.Text = projectStatusDictionary["Expired"];
                lblProjectsTotal.Text = projectStatusDictionary["Total"];

                gv_TotalExpensesByDept.DataSource = ds;
                gv_TotalExpensesByDept.DataBind();
            }
        }

        #region ReportingModule

        #region Object Events

        /// <summary>
        /// When a ProjectID is selected, the Project Details Pane is updated with all of the information for that panel
        /// </summary>
        protected void dlistProjectID_SelectedIndexChanged(object sender, EventArgs e)
        {
            DropDownList dlist = (DropDownList)sender;

            populateProjectBody(dlist.SelectedValue);

            //addProjectInfoToDropDownList(dl_ViewMode);

            //Update the ViewMode drop down list with this choice
            ibtnSFNProject_Click(ibtnSFNProject, null);
            updateViewMode.Update();

            updateTotalExpenses.Update();
        }

        /// <summary>
        /// Causes the project drop down list to rebind, updating the record in the project pane
        /// </summary>
        protected void dlistDepartment_SelectedIndexChanged(object sender, EventArgs e)
        {
            ClearProjectLabels();

            //Bind the project dropdownlist (which depends on the department dl), then update the project body
            dlistProjectID.DataBind();
            populateProjectBody(dlistProjectID.SelectedValue);
            //addProjectInfoToDropDownList(dl_ViewMode);

            AD419DataAccess da = new AD419DataAccess();
            DataSet ds = new DataSet();
            StringDictionary projectStatusDictionary = new StringDictionary();

            try
            {
                ds = da.getTotalExpensesByDept(dlistDepartment.SelectedValue);
                projectStatusDictionary = da.getActiveProjectsCount(dlistDepartment.SelectedValue);
            }
            catch (SqlException ex)
            {
                AD419ErrorReporting.ReportError(ex, "Page_Load");
                Response.Redirect(AD419Configuration.ErrorPage(AD419Configuration.ErrorType.DATA));
            }

            lblProjectsActive.Text = projectStatusDictionary["Active"];
            lblProjectsExpired.Text = projectStatusDictionary["Expired"];
            lblProjectsTotal.Text = projectStatusDictionary["Total"];

            gv_TotalExpensesByDept.DataSource = ds;
            gv_TotalExpensesByDept.DataBind();

            if (AD419DataSFNTotals.SelectParameters["AssociationStatus"].DefaultValue == ibtnSFNProject.CommandArgument)
            {
                // The the Program view was selected, so update the project ID:
                ibtnSFNProject_Click(ibtnSFNProject, null);
            }
        }

        /// <summary>
        /// Remove the "All Departments" option for Non-Admins
        /// </summary>
        protected void dlistDepartment_DataBound(object sender, EventArgs e)
        {
            if (Roles.IsUserInRole("Admin") == false)
            {
                ListItem AllDepartments = dlistDepartment.Items.FindByValue("All");

                if (AllDepartments != null)
                    dlistDepartment.Items.Remove(AllDepartments);
            }
        }

        /// <summary>
        /// Formats the left column making it bold so the table looks like a grid.
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        protected void gv_TotalExpensesByDept_RowDataBound(object sender, GridViewRowEventArgs e)
        {
            //Only look at DataRow(s)
            if (e.Row.RowType == DataControlRowType.DataRow)
            {
                e.Row.Cells[0].Font.Bold = true;
                e.Row.Cells[1].Text = String.Format("{0:c}", double.Parse(e.Row.Cells[1].Text));
                e.Row.Cells[2].Text = string.Format("{0:f}", double.Parse(e.Row.Cells[2].Text));
            }
        }

        /// <summary>
        /// Formats rows in the Totals after the rows are databound, depending on what the LineTypeCode is
        /// </summary>
        /// <see cref="http://msdn.microsoft.com/library/default.asp?url=/library/en-us/cpguide/html/cpconstandardnumericformatstrings.asp">
        /// For string.Format() rules, see the link.  {0:c} gives the number in currency format, and ${0:#,###} gives the money value rounded
        /// to the nearest integer</see>
        protected void gViewSFNTotalExpenses_PreRender(object sender, EventArgs e)
        {
            GridView gview = (GridView)sender;

            foreach (GridViewRow row in gview.Rows)
            {
                //Only look at DataRow(s)
                if (row.RowType == DataControlRowType.DataRow)
                {
                    //Pull out the LineTypeCode for this row
                    string LineTypeCode = gview.DataKeys[row.RowIndex]["LineTypeCode"].ToString();

                    switch (LineTypeCode)
                    {
                        case "Heading":
                            row.BackColor = AD419Configuration.LineColor(AD419Configuration.LineTypeCode.Heading);
                            break;
                        case "SFN":
                            row.BackColor = AD419Configuration.LineColor(AD419Configuration.LineTypeCode.SFN);
                            row.HorizontalAlign = HorizontalAlign.Right;
                            row.Cells[2].Text = String.Format("{0:c}", double.Parse(row.Cells[2].Text, System.Globalization.NumberStyles.Currency));
                            break;
                        case "GroupSum":
                            row.BackColor = AD419Configuration.LineColor(AD419Configuration.LineTypeCode.GroupSum);
                            row.Font.Bold = true;
                            row.HorizontalAlign = HorizontalAlign.Right;
                            row.Cells[2].Text = String.Format("{0:c}", double.Parse(row.Cells[2].Text, System.Globalization.NumberStyles.Currency));
                            break;
                        case "GrandTotal":
                            row.BackColor = AD419Configuration.LineColor(AD419Configuration.LineTypeCode.GrandTotal);
                            row.Font.Bold = true;
                            row.HorizontalAlign = HorizontalAlign.Right;
                            row.Cells[2].Text = String.Format("{0:c}", double.Parse(row.Cells[2].Text, System.Globalization.NumberStyles.Currency));
                            break;
                        case "FTE":
                            row.BackColor = AD419Configuration.LineColor(AD419Configuration.LineTypeCode.FTE);
                            row.HorizontalAlign = HorizontalAlign.Right;
                            row.Cells[2].Text = String.Format("{0:f2}", double.Parse(row.Cells[2].Text, System.Globalization.NumberStyles.Currency));
                            break;
                        case "FTETotal":
                            row.BackColor = AD419Configuration.LineColor(AD419Configuration.LineTypeCode.FTETotal);
                            row.Font.Bold = true;
                            row.HorizontalAlign = HorizontalAlign.Right;
                            row.Cells[2].Text = String.Format("{0:f2}", double.Parse(row.Cells[2].Text, System.Globalization.NumberStyles.Currency));
                            break;
                    }
                }
            }
        }

        #endregion Object Events

        #region Private Functions

        /// <summary>
        /// Populates all of the fields in the project body pane
        /// </summary>
        /// <param name="ProjectID">The Project ID</param>
        private void populateProjectBody(string ProjectID)
        {
            AD419DataAccess data = new AD419DataAccess();

            //Stores the data of the project info here from the data source
            DataSet ds = new DataSet();

            try
            {
                ds = data.getProjectInfoByID(ProjectID);
            }
            catch (SqlException ex)
            {
                AD419ErrorReporting.ReportError(ex, "populateProjectBody");
                Response.Redirect(AD419Configuration.ErrorPage(AD419Configuration.ErrorType.DATA));
            }

            //Make sure the dataset returned at least one matching record
            if (ds.Tables[0].Rows.Count == 0)
                return;

            //Grab the first row out of the database (there should only be one row anyway)
            DataRow dr = ds.Tables[0].Rows[0];

            //Now that we have the project info array populated, start filling the information into the project body pane

            lblProjectAccession.Text = (string)dr["Accession"];

            //Fill in the investigators -- boxes with no investigators get the blank records from the db
            lblProjectInvestigator1.Text = dr["inv1"] as string ?? string.Empty;
            lblProjectInvestigator2.Text = dr["inv2"] as string ?? string.Empty;
            lblProjectInvestigator3.Text = dr["inv3"] as string ?? string.Empty;
            lblProjectInvestigator4.Text = dr["inv4"] as string ?? string.Empty;
            lblProjectInvestigator5.Text = dr["inv5"] as string ?? string.Empty;
            lblProjectInvestigator6.Text = dr["inv6"] as string ?? string.Empty;

            //Grab the date from the row -- might have to parse it first
            lblBeginningDate.Text = ((DateTime)dr["BeginDate"]).ToShortDateString();
            lblTerminationDate.Text = ((DateTime)dr["TermDate"]).ToShortDateString();

            //Fill in the types -- may have to do lookups on this data
            lblProjectStatusType.Text = dr["StatusCd"] as string ?? string.Empty;
            lblProjectType.Text = dr["ProjTypeCd"] as string ?? string.Empty;
            lblProjectFundingType.Text = "N/A"; //No implemented

            //Project number
            lblProjectNumber.Text = dr["RegionalProjNum"] as string ?? string.Empty;

            //Fill the title into this read only textbox
            txtProjectDescription.Text = dr["Title"] as string ?? string.Empty;
        }

        private void ClearProjectLabels()
        {
            lblProjectAccession.Text = "";
            lblProjectInvestigator1.Text = "";
            lblProjectInvestigator2.Text = "";
            lblProjectInvestigator3.Text = "";
            lblProjectInvestigator4.Text = "";
            lblProjectInvestigator5.Text = "";
            lblProjectInvestigator6.Text = "";
            lblBeginningDate.Text = "";
            lblTerminationDate.Text = "";
            lblProjectStatusType.Text = "";
            lblProjectType.Text = "";
            lblProjectNumber.Text = "";
            lblProjectFundingType.Text = "";
            txtProjectDescription.Text = "";
        }

        /// <summary>
        /// Adds the info of the currently selected project (if one exists) to the dropdownlist supplied.
        /// </summary>
        /// <param name="dlist">The dropdownlist to add the project info to</param>
        private void addProjectInfoToDropDownList(DropDownList dlist)
        {
            string selectedValue = dlist.SelectedValue;
            //Remove the last item from the dlist if there are more than 3 entries
            if (dlist.Items.Count > 3)
                dlist.Items.RemoveAt(dlist.Items.Count - 1);

            //Don't add the info if there are no projects to bind to
            if (dlistProjectID.Items.Count != 0)
            {
                //Add the project name value of 4 (given in AD419Configuration) to the drop down list
                dlist.Items.Add(new ListItem(dlistProjectID.SelectedItem.Text, AD419Configuration.ViewProjectTotals.ToString()));
            }

            if (selectedValue == AD419Configuration.ViewProjectTotals.ToString())
            {
                gViewSFNTotalExpenses.DataBind();
                updateTotalExpenses.Update();
            }
        }

        #endregion Private Functions

        #endregion ReportingModule

        #region Associations

        #region Object Callbacks

        /// <summary>
        /// When changing departments, ensure that the projects gridview is reset to its initial state
        /// </summary>
        protected void dlistAssociationsDepartment_SelectedIndexChanged(object sender, EventArgs e)
        {
            clearGvAssociationProjects();
        }

        /// <summary>
        /// Whenever the record grouping is changed, all current work on the projects gridview
        /// should be reset
        /// </summary>
        protected void dlistRecordGrouping_SelectedIndexChanged(object sender, EventArgs e)
        {
            clearGvAssociationProjects();
        }

        /// <summary>
        /// When the associated box is checked or unchecked, the record grouping updates
        /// and the projects gridview is reset
        /// </summary>
        protected void cboxAssociated_CheckedChanged(object sender, EventArgs e)
        {
            clearGvAssociationProjects();
        }

        /// <summary>
        /// When the unassociated box is checked or unchecked, the record grouping updates
        /// and the projects gridview is reset
        /// </summary>
        protected void cboxUnassociated_CheckedChanged(object sender, EventArgs e)
        {
            clearGvAssociationProjects();
        }

        /// <summary>
        /// Associates percentages with the number of boxes checked.  When a box is checked or unchecked, the percentages
        /// are updated and stored in the viewstate
        /// </summary>
        /// <remarks>Sets/Retrieves data from the "NumCheckedProjects" ViewState Key</remarks>
        protected void cboxAssociatePercent_CheckedChanged(object sender, EventArgs e)
        {
            CheckBox cboxSender = (CheckBox)sender;   //the checkbox that raised the event
            LinkButton lbtnNumCheckedProjects = (LinkButton)gvAssociationProjects.HeaderRow.FindControl("lbtnNumCheckedProjects");//The header cell of the checkbox column
            //Check to see if the box was checked or unchecked
            if (cboxSender.Checked == true)
            {
                if (ViewState["NumCheckedProjects"] != null) //Check to make sure the ViewState Key exists
                {
                    ViewState["NumCheckedProjects"] = (int)ViewState["NumCheckedProjects"] + 1; //Increment the key
                    lbtnNumCheckedProjects.Text = ViewState["NumCheckedProjects"].ToString();
                }
                else
                {
                    //If the ViewState key has not been initialized, then set it equal to 1
                    ViewState["NumCheckedProjects"] = 1; //
                    lbtnNumCheckedProjects.Text = "1";
                }
            }
            else
            {
                //If a box is being unchecked
                if (ViewState["NumCheckedProjects"] != null)
                {
                    //If there is an entry in the viewstate, retrieve it and decrement it
                    ViewState["NumCheckedProjects"] = (int)ViewState["NumCheckedProjects"] - 1;
                    lbtnNumCheckedProjects.Text = ViewState["NumCheckedProjects"].ToString();
                }
                else
                {
                    //There is no entry in the viewstate (this shouldn't happen)
                    ViewState["NumCheckedProjects"] = 0;
                    lbtnNumCheckedProjects.Text = "0";
                }
            }

            //Now the checks are taken care of, so figure out the percentages and assign them
            int numChecks = (int)ViewState["NumCheckedProjects"]; //Total number of checks
            double percent = 100.00 / numChecks;

            //Go through the grid, and for each checked row, add the percent value to the corresponding text box
            foreach (GridViewRow row in gvAssociationProjects.Rows)
            {
                //We are only concerned with the data rows
                if (row.RowType == DataControlRowType.DataRow)
                {
                    //Pull out the checkbox and text box from the current row
                    CheckBox cbox = (CheckBox)row.FindControl("cboxAssociatePercent");
                    TextBox tbox = (TextBox)row.FindControl("txtAssociatePercent");

                    //If the checkbox is checked, we will insert the percent into the textbox, if not, we will blank it out
                    if (cbox.Checked == true)
                    {
                        tbox.Text = percent.ToString("F");
                    }
                    else
                    {
                        tbox.Text = string.Empty;
                    }
                }
            }

            gvAssociationProjects.HeaderRow.Cells[1].Text = "100%";
        }

        /// <summary>
        /// Sets the ForeColor (Text Color) of this control to the AssociatedGrouping color as defined
        /// in the AD419Configuration File
        /// </summary>
        protected void cboxAssociated_PreRender(object sender, EventArgs e)
        {
            ((CheckBox)sender).ForeColor = AD419Configuration.LineColor(AD419Configuration.LineTypeCode.AssociatedGrouping);
        }

        /// <summary>
        /// Sets the ForeColor (Text Color) of this control to the UnassociatedGrouping color as defined
        /// in the AD419Configuration File
        /// </summary>
        protected void cboxUnassociated_PreRender(object sender, EventArgs e)
        {
            ((CheckBox)sender).ForeColor = AD419Configuration.LineColor(AD419Configuration.LineTypeCode.UnassociatedGrouping);
        }

        /// <summary>
        /// Updates percentages based on what a user types into the percentage box field
        /// </summary>
        protected void txtAssociatePercent_TextChanged(object sender, EventArgs e)
        {
            TableCell tcTextHeader = gvAssociationProjects.HeaderRow.Cells[1];
            TextBox txtSender = (TextBox)sender;

            double percent = 0.0;

            //Only continue if the parse succeeds
            if (double.TryParse(txtSender.Text, out percent))
            {
                //Iterate through all rows of the grid, and add up the percentages
                percent = 0.0;

                foreach (GridViewRow row in gvAssociationProjects.Rows)
                {
                    //Only interested in data rows
                    if (row.RowType == DataControlRowType.DataRow)
                    {
                        //Pull out the checkbox and text box from the current row
                        CheckBox cbox = (CheckBox)row.FindControl("cboxAssociatePercent");
                        TextBox tbox = (TextBox)row.FindControl("txtAssociatePercent");

                        if (cbox.Checked == true)
                        {
                            percent += double.Parse(tbox.Text);
                        }
                    }
                }

                setPercentTotal(percent);
            }
            else
            {
                //Reset both grids and display an error
                gvAssociationRecords.DataBind();
                ViewState["checkedRecords"] = null;
                clearGvAssociationProjects();
                updateAssociationsGrouping.Update();

                lblError.Text = "Invalid Character In Percentage Box";
            }
        }

        /// <summary>
        /// Prepares the column names and visiblity depending on what data is filtered
        /// </summary>
        /// <remarks>Uses getSortingLinkButton to prepare dynamic sorting column names without
        /// requerying the database</remarks>
        protected void gvAssociationRecords_PreRender(object sender, EventArgs e)
        {
            GridView gview = gvAssociationRecords;

            if (gview.HeaderRow != null)
            {
                gview.HeaderRow.Cells[0].Controls.Add(getSortingLinkButton(gview.Rows.Count.ToString(), "Num"));

                //First go through the header and make the changes you want
                switch (dlistRecordGrouping.SelectedValue)
                {
                    case "PI":
                        gview.HeaderRow.Cells[3].Visible = false;
                        gview.HeaderRow.Cells[2].Controls.Add(getSortingLinkButton("Principle Investigator", "Code"));
                        break;
                    case "Organization":
                        gview.HeaderRow.Cells[2].Controls.Add(getSortingLinkButton("OrgCode", "Code"));
                        gview.HeaderRow.Cells[3].Controls.Add(getSortingLinkButton("OrgName", "Description"));
                        break;
                    case "Sub-Account":
                        gview.HeaderRow.Cells[2].Controls.Add(getSortingLinkButton("SubAcctCode", "Code"));
                        gview.HeaderRow.Cells[3].Controls.Add(getSortingLinkButton("SubAcctName", "Description"));
                        break;
                    case "Account":
                        gview.HeaderRow.Cells[2].Controls.Add(getSortingLinkButton("AcctCode", "Code"));
                        gview.HeaderRow.Cells[3].Controls.Add(getSortingLinkButton("AcctName", "Description"));
                        break;
                    case "Employee":
                        gview.HeaderRow.Cells[2].Visible = false;
                        gview.HeaderRow.Cells[3].Controls.Add(getSortingLinkButton("Employee (StaffGroup)", "Description"));
                        break;
                    case "None":
                        gview.HeaderRow.Cells[2].Visible = false;
                        gview.HeaderRow.Cells[3].Controls.Add(getSortingLinkButton("Acct[SubAcct]: Employee(TitleCode)", "Description"));
                        break;
                }
            }
            //Go through each row and hide the cells for the current grouping
            foreach (GridViewRow row in gvAssociationRecords.Rows)
            {
                if (row.RowType == DataControlRowType.DataRow)
                {
                    switch (dlistRecordGrouping.SelectedValue)
                    {
                        case "PI":
                            row.Cells[2].Visible = true;
                            row.Cells[3].Visible = false;
                            break;
                        case "Organization":
                            row.Cells[3].Visible = true;
                            row.Cells[2].Visible = true;
                            break;
                        case "Sub-Account":
                            row.Cells[2].Visible = true;
                            row.Cells[3].Visible = true;
                            break;
                        case "Account":
                            row.Cells[2].Visible = true;
                            row.Cells[3].Visible = true;
                            break;
                        case "Employee":
                            row.Cells[3].Visible = true;
                            row.Cells[2].Visible = false;
                            break;
                        case "None":
                            row.Cells[3].Visible = true;
                            row.Cells[2].Visible = false;
                            break;
                    }

                    //Color Code the rows based in the isAssociable DataKey
                    if (gview.DataKeys[row.RowIndex]["isAssociated"].ToString() == "1")
                        row.ForeColor = AD419Configuration.LineColor(AD419Configuration.LineTypeCode.AssociatedGrouping);
                    else
                        row.ForeColor = AD419Configuration.LineColor(AD419Configuration.LineTypeCode.UnassociatedGrouping);
                }
            }
        }

        /// <summary>
        /// Whenever the record grouping is sorted, all current work on the projects gridview
        /// should be reset
        /// </summary>
        protected void gvAssociationRecords_Sorted(object sender, EventArgs e)
        {
            clearGvAssociationProjects();
        }

        /// <summary>
        /// When a record grouping check is checked or unchecked, we need to update the project
        /// associations on the projects gridview.  This includes Spent/FTE information in the
        /// current state.
        /// </summary>
        protected void cboxExpense_CheckedChanged(object sender, EventArgs e)
        {
            CheckBox cbox = (CheckBox)sender;

            //If the checked records list is null, initialize it
            if (ViewState["CheckedRecords"] == null)
                ViewState["CheckedRecords"] = new ArrayList();

            ArrayList checkedRecords = (ArrayList)ViewState["CheckedRecords"];

            //Go through each row and find the entry whose check has changed
            foreach (GridViewRow row in gvAssociationRecords.Rows)
            {
                //Grab the current row's checkbox and row index
                CheckBox currentCbox = (CheckBox)row.FindControl("cboxExpense");
                int rowIndex = row.RowIndex;

                //If the box is checked, make sure its in the list
                if (currentCbox.Checked == true)
                {
                    if (checkedRecords.Contains(rowIndex) == false)
                    {
                        //The box was just checked.
                        //Handle the event and insert rowIndex into the viewstate

                        //Add rowIndex to the viewstate
                        checkedRecords.Add(rowIndex);

                        string Chart = gvAssociationRecords.Rows[rowIndex].Cells[1].Text;
                        string Criterion = gvAssociationRecords.Rows[rowIndex].Cells[2].Text;

                        double TotalSpent = getTotalSpent(checkedRecords);

                        //Grab the Associations Information out of the db
                        AD419DataAccess data = new AD419DataAccess();
                        DataSet AssociationsData = new DataSet();

                        try
                        {
                            AssociationsData = data.getAssociationsByGrouping(dlistRecordGrouping.SelectedValue, dlistAssociationsDepartment.SelectedValue, Criterion, Chart, gvAssociationRecords.DataKeys[rowIndex]["isAssociated"].ToString());
                        }
                        catch (SqlException ex)
                        {
                            AD419ErrorReporting.ReportError(ex, "cboxExpense_CheckedChanged");
                            Response.Redirect(AD419Configuration.ErrorPage(AD419Configuration.ErrorType.DATA));
                        }

                        updateAssociations(AssociationsData, TotalSpent, true);

                        break;
                    }
                }
                else
                {
                    if (checkedRecords.Contains(rowIndex) == true)
                    {
                        //The box was just unchecked
                        //Handle the event and then remove rowIndex from the viewstate

                        //remove rowIndex from the viewstate
                        checkedRecords.Remove(rowIndex);

                        string Chart = gvAssociationRecords.Rows[rowIndex].Cells[1].Text;
                        string Criterion = gvAssociationRecords.Rows[rowIndex].Cells[2].Text;

                        double TotalSpent = getTotalSpent(checkedRecords);

                        //Grab the Associations Information out of the db
                        AD419DataAccess data = new AD419DataAccess();
                        DataSet AssociationsData = new DataSet();

                        try
                        {
                            AssociationsData = data.getAssociationsByGrouping(dlistRecordGrouping.SelectedValue, dlistAssociationsDepartment.SelectedValue, Criterion, Chart, gvAssociationRecords.DataKeys[rowIndex]["isAssociated"].ToString());
                        }
                        catch (SqlException ex)
                        {
                            AD419ErrorReporting.ReportError(ex, "cboxExpense_CheckedChanged");
                            Response.Redirect(AD419Configuration.ErrorPage(AD419Configuration.ErrorType.DATA));
                        }

                        updateAssociations(AssociationsData, TotalSpent, false);

                        break;
                    }
                }
            }

            if (checkedRecords.Count == 0)
                gvAssociationProjects.Enabled = false;
            else
                gvAssociationProjects.Enabled = true;

            //Make sure to update the projects grid's update panel now that we have made changes to the grid
            updateAssociationProjects.Update();

            //Now re-insert the ArrayList into the viewstate bag
            ViewState["CheckedRecords"] = checkedRecords;
        }

        /// <summary>
        /// Unassociates all checked record groupings from all projects that they were previously
        /// associated with.  Creates an arraylist of Expenses in the current grouping, then passes the
        /// arraylist to the DataAccess class for a deletion transaction.
        /// </summary>
        protected void btnUnassociateRecords_Click(object sender, EventArgs e)
        {
            if (ViewState["CheckedRecords"] == null)
            {
                lblError.Text = "Association Failed: No Records Are Selected";
                return;
            }

            ArrayList checkedRecords = (ArrayList)ViewState["CheckedRecords"];

            //Loop through all records that are checked (by index)
            foreach (int rowIndex in checkedRecords)
            {
                //Make sure the row is checked.  This should always be the case or else the rowIndex
                //should not be in checkedRecords
                CheckBox cbox = (CheckBox)gvAssociationRecords.Rows[rowIndex].FindControl("cboxExpense");

                if (cbox.Checked == false)
                    continue;

                //Grab all of the expenseID's along with Spent and FTE information for this grouping
                ArrayList currentGroupingExpenses = new ArrayList();
                AD419DataAccess dataExpenses = new AD419DataAccess();

                try
                {
                    currentGroupingExpenses = dataExpenses.getExpensesByRecordGrouping(dlistRecordGrouping.SelectedValue, dlistAssociationsDepartment.SelectedValue,
                                                                gvAssociationRecords.Rows[rowIndex].Cells[1].Text, gvAssociationRecords.Rows[rowIndex].Cells[2].Text,
                                                                gvAssociationRecords.DataKeys[rowIndex]["isAssociated"].ToString());

                    //Now delete all of the ExpenseIDs in the currentGroupingExpense
                    dataExpenses.deleteAssociationsTransaction(currentGroupingExpenses, dlistAssociationsDepartment.SelectedValue);
                }
                catch (SqlException ex)
                {
                    AD419ErrorReporting.ReportError(ex, "associateRecords");
                    Response.Redirect(AD419Configuration.ErrorPage(AD419Configuration.ErrorType.DATA));
                }
            }

            //Now that all of the records have been unassociated, clear the projects grid and rebind the records grid and totals grid
            ViewState["CheckedRecords"] = null;
            gvAssociationRecords.DataBind();
            gv_TotalExpesnsesByDept.DataBind();
            updateAssociationProjects.Update();
            updateAssociationsTotalExpenses.Update();
            updateAssociationsGrouping.Update();
            clearGvAssociationProjects();
        }

        /// <summary>
        /// For each checked record grouping, the projects on the right are associated depending
        /// on the percentages chosen
        /// </summary>
        protected void btnAssociateRecords_Click(object sender, EventArgs e)
        {
            //Do the associations
            associateRecords();

            //Reset the datagrids
            clearGvAssociationProjects();
            ViewState["CheckedRecords"] = null;
            gvAssociationRecords.DataBind();
            gv_TotalExpesnsesByDept.DataBind();
            updateAssociationProjects.Update();
            updateAssociationsTotalExpenses.Update();
            updateAssociationsGrouping.Update();
        }

        /// <summary>
        /// Selects all of the projects in the projects grid by looping through the rows and calling the CheckedChanged
        /// method to take care of the percentages
        /// </summary>
        protected void lbtnNumCheckedProjects_Click(object sender, EventArgs e)
        {
            //Set the number checked to 0
            ViewState["NumCheckedProjects"] = 0;

            //Go through all of the project rows and check the boxes and assign percentages
            foreach (GridViewRow row in gvAssociationProjects.Rows)
            {
                CheckBox cbox = (CheckBox)row.FindControl("cboxAssociatePercent");

                cbox.Checked = true;
                cboxAssociatePercent_CheckedChanged(cbox, e);
            }
        }

        #endregion Object Callbacks

        #region Private Methods

        /// <summary>
        /// Given a DataSet of Associations Data, this function will update the projects
        /// gridview by making correct associations, taking into account its current state.
        /// </summary>
        /// <param name="AssociationsData">project number, spent and FTE</param>
        /// <param name="TotalSpent">The total ammount of money spent through all checked projects</param>
        /// <param name="addValues">True if the values in the dataset should be
        /// added to the existing data.  False otherwise</param>
        private void updateAssociations(DataSet AssociationsData, double TotalSpent, bool addValues)
        {
            if (ViewState["NumCheckedProjects"] == null)
                ViewState["NumCheckedProjects"] = 0;

            double percent = 0.0;

            DataRowCollection AssociationsRow = AssociationsData.Tables[0].Rows;
            if (AssociationsData.Tables[0].Rows.Count != 0)
            {
                //Assuming that both the projects table and the associations data set
                //Are sorted by project name
                foreach (GridViewRow row in gvAssociationProjects.Rows)
                {
                    //If the checkbox is currently unchecked, check it and add one to the checked projects count.
                    CheckBox currentCheckBox = (CheckBox)row.FindControl("cboxAssociatePercent");
                    TextBox currentTextBox = (TextBox)row.FindControl("txtAssociatePercent");

                    if (TotalSpent == 0)
                    {
                        //If we don't have a total, then there are no boxes checked or the true value is actually 0, so
                        //Remove all values from this gridview
                        row.Cells[AD419Configuration.cellIndexProjectSpent].Text = string.Empty;
                        row.Cells[AD419Configuration.cellIndexProjectsFTE].Text = string.Empty;
                        currentTextBox.Text = string.Empty;

                        if (currentCheckBox.Checked == true)
                        {
                            currentCheckBox.Checked = false;
                            ViewState["NumCheckedProjects"] = (int)ViewState["NumCheckedProjects"] - 1;
                        }
                    }
                    else
                    {
                        DataRow CurrentAssociationsRow = getRowInDataSet(AssociationsData, "Project", row.Cells[2].Text);
                        if (CurrentAssociationsRow != null)
                        {
                            //Now we know we have the row with a matching project
                            double Spent = double.Parse(CurrentAssociationsRow["Spent"].ToString());

                            if (row.Cells[AD419Configuration.cellIndexProjectSpent].Text == string.Empty)
                            {
                                //there is no data in this project, so there is no previous value to add it to
                                row.Cells[AD419Configuration.cellIndexProjectSpent].Text = string.Format("{0:c}", Spent);
                                row.Cells[AD419Configuration.cellIndexProjectsFTE].Text = string.Format("{0:f}", CurrentAssociationsRow["FTE"]);
                                currentTextBox.Text = string.Format("{0:f}", (Spent / TotalSpent) * 100.0);

                                //Keep track of the new percent
                                percent += (Spent / TotalSpent) * 100.0;

                                //If the check is false, check it and add one to the viewstate.  Otherwise do nothing.
                                if (currentCheckBox.Checked == false)
                                {
                                    currentCheckBox.Checked = true;
                                    ViewState["NumCheckedProjects"] = (int)ViewState["NumCheckedProjects"] + 1;
                                }
                            }
                            else
                            {
                                //There is an existing entry in the box, so add it or subtract it from the previous measurement
                                double TotalRowSpent = 0;
                                double TotalRowFTE = 0;

                                if (addValues == true)
                                {
                                    TotalRowSpent = Spent + double.Parse(row.Cells[AD419Configuration.cellIndexProjectSpent].Text, System.Globalization.NumberStyles.Currency);
                                    TotalRowFTE = double.Parse(CurrentAssociationsRow["FTE"].ToString()) + double.Parse(row.Cells[AD419Configuration.cellIndexProjectsFTE].Text, System.Globalization.NumberStyles.Currency);
                                }
                                else
                                {
                                    TotalRowSpent = double.Parse(row.Cells[AD419Configuration.cellIndexProjectSpent].Text, System.Globalization.NumberStyles.Currency) - Spent;
                                    TotalRowFTE = double.Parse(row.Cells[AD419Configuration.cellIndexProjectsFTE].Text, System.Globalization.NumberStyles.Currency) - double.Parse(CurrentAssociationsRow["FTE"].ToString());
                                }

                                row.Cells[AD419Configuration.cellIndexProjectSpent].Text = string.Format("{0:c}", TotalRowSpent);
                                row.Cells[AD419Configuration.cellIndexProjectsFTE].Text = string.Format("{0:f}", TotalRowFTE);

                                currentTextBox.Text = string.Format("{0:f}", (TotalRowSpent / TotalSpent) * 100.0);

                                if (row.Cells[AD419Configuration.cellIndexProjectSpent].Text == "$0.00" && row.Cells[AD419Configuration.cellIndexProjectsFTE].Text == "0.00")
                                {
                                    //Blank out the entry if there is no money or FTE in it
                                    row.Cells[AD419Configuration.cellIndexProjectSpent].Text = string.Empty;
                                    row.Cells[AD419Configuration.cellIndexProjectsFTE].Text = string.Empty;
                                    currentTextBox.Text = string.Empty;

                                    if (currentCheckBox.Checked == true)
                                    {
                                        currentCheckBox.Checked = false;
                                        ViewState["NumCheckedProjects"] = (int)ViewState["NumCheckedProjects"] - 1;
                                    }
                                }
                                else if (currentCheckBox.Checked == false)
                                {
                                    //If the check is false, check it and add one to the viewstate.  Otherwise do nothing.
                                    currentCheckBox.Checked = true;
                                    ViewState["NumCheckedProjects"] = (int)ViewState["NumCheckedProjects"] + 1;

                                    //Keep track of the new percent
                                    percent += (TotalRowSpent / TotalSpent) * 100.0;
                                }
                                else if (currentCheckBox.Checked == true)
                                {
                                    percent += (TotalRowSpent / TotalSpent) * 100.0;
                                }
                            }
                        }
                        else
                        {
                            //This row does not correspond to a current project, but it may still have a value from a previous project so we need to update the percentages.
                            if (row.Cells[4].Text != string.Empty)
                            {
                                //make sure that the spent text for this row has a value in it.

                                double Spent = double.Parse(row.Cells[AD419Configuration.cellIndexProjectSpent].Text, System.Globalization.NumberStyles.Currency);

                                currentTextBox.Text = string.Format("{0:f}", (Spent / TotalSpent) * 100.0);

                                if (row.Cells[AD419Configuration.cellIndexProjectSpent].Text == "$0.00" && row.Cells[AD419Configuration.cellIndexProjectsFTE].Text == "0.00")
                                {
                                    //Blank out the entry if there is no money or FTE in it
                                    row.Cells[AD419Configuration.cellIndexProjectSpent].Text = string.Empty;
                                    row.Cells[AD419Configuration.cellIndexProjectsFTE].Text = string.Empty;
                                    currentTextBox.Text = string.Empty;
                                    if (currentCheckBox.Checked == true)
                                    {
                                        currentCheckBox.Checked = false;
                                        ViewState["NumCheckedProjects"] = (int)ViewState["NumCheckedProjects"] - 1;
                                    }
                                }
                                else if (currentCheckBox.Checked == false)
                                {
                                    //If the check is false, check it and add one to the viewstate.  Otherwise do nothing.
                                    currentCheckBox.Checked = true;
                                    ViewState["NumCheckedProjects"] = (int)ViewState["NumCheckedProjects"] + 1;

                                    //Keep track of the new percent
                                    percent += (Spent / TotalSpent) * 100.0;
                                }
                                else if (currentCheckBox.Checked == true)
                                {
                                    percent += (Spent / TotalSpent) * 100.0;
                                }
                            }
                            else
                            {
                                //If there is no spent value, make sure the checkbox and textbox are blank too
                                if (currentCheckBox.Checked == true)
                                {
                                    currentCheckBox.Checked = false;
                                    ViewState["NumCheckedProjects"] = (int)ViewState["NumCheckedProjects"] - 1;
                                }

                                currentTextBox.Text = string.Empty;
                            }
                        }
                    }
                }

                setPercentTotal(percent);
            }

            //Update header with the number of checked cells
            if (gvAssociationProjects.Rows.Count != 0)
            {
                LinkButton lbtnNumCheckedProjects = (LinkButton)gvAssociationProjects.HeaderRow.FindControl("lbtnNumCheckedProjects");
                lbtnNumCheckedProjects.Text = ViewState["NumCheckedProjects"].ToString();
                //gvAssociationProjects.HeaderRow.Cells[0].Text = ViewState["NumCheckedProjects"].ToString();
            }
        }

        /// <summary>
        /// For each checked record grouping, the projects on the right are associated depending
        /// on the percentages chosen
        /// </summary>
        /// <returns>True if association succeeds, else false</returns>
        /// <remarks>Any additional money that is leftover by percentages will be associated with the last project alphabetically.
        /// The whole association will happen in a transaction.</remarks>
        private bool associateRecords()
        {
            if (ViewState["CheckedRecords"] == null)
            {
                lblError.Text = "Association Failed: No Records Are Selected";
                return false;
            }

            if (ViewState["NumCheckedProjects"] == null)
            {
                lblError.Text = "Association Failed: No Projects Are Selected";
                return false;
            }

            if (gvAssociationProjects.Rows.Count == 0)
            {
                lblError.Text = "Association Failed: No Projects Found";
                return false;
            }

            if (gvAssociationProjects.HeaderRow.Cells[1].Text != "100%")
            {
                lblError.Text = "Association Failed: Total Selected Is Not 100%";
                return false;
            }

            int NumCheckedProjects = (int)ViewState["NumCheckedProjects"];

            // // // int CurrentNumCheckedProjects = 0; //Will be used to keep track of which project we are currently associating

            ArrayList checkedRecords = (ArrayList)ViewState["CheckedRecords"];

            //Keep an arraylist of all projects checked in the projects grid, along with percentages, so that we don't have to
            //do the parse-ing every time.
            //-- Will be array list of array lists -- with each array list being Accession, Percent
            ArrayList projectCheckedArray = new ArrayList();

            //Loop through all rows in the projects table and build up an re-usable array list of accession/percentages
            foreach (GridViewRow row in gvAssociationProjects.Rows)
            {
                CheckBox currentCheckBox = (CheckBox)row.FindControl("cboxAssociatePercent");
                TextBox currentTextBox = (TextBox)row.FindControl("txtAssociatePercent");

                if (currentCheckBox.Checked == true)
                {
                    ArrayList projectCheckedEntry = new ArrayList();

                    //Add the accession number for this project
                    projectCheckedEntry.Add(gvAssociationProjects.DataKeys[row.RowIndex]["Accession"].ToString());
                    //Add the percent as a double (divide by 100 for percent)
                    projectCheckedEntry.Add((double.Parse(currentTextBox.Text) / 100.0));

                    //Add the current entry to the array
                    projectCheckedArray.Add(projectCheckedEntry);
                }
            }

            //Loop through all records that are checked (by index)
            foreach (int rowIndex in checkedRecords)
            {
                ArrayList transactionArray = new ArrayList(); //transaction array to keep the current transaction parameters in

                //Make sure the row is checked.  This should always be the case or else the rowIndex
                //should not be in checkedRecords
                CheckBox cbox = (CheckBox)gvAssociationRecords.Rows[rowIndex].FindControl("cboxExpense");

                if (cbox.Checked == false)
                    continue;

                //Grab all of the expenseID's along with Spent and FTE information for this grouping
                ArrayList currentGroupingExpenses = new ArrayList();
                AD419DataAccess dataExpenses = new AD419DataAccess();

                try
                {
                    currentGroupingExpenses = dataExpenses.getExpensesByRecordGrouping(dlistRecordGrouping.SelectedValue, dlistAssociationsDepartment.SelectedValue,
                                                                gvAssociationRecords.Rows[rowIndex].Cells[1].Text, gvAssociationRecords.Rows[rowIndex].Cells[2].Text,
                                                                gvAssociationRecords.DataKeys[rowIndex]["isAssociated"].ToString());
                }
                catch (SqlException ex)
                {
                    AD419ErrorReporting.ReportError(ex, "associateRecords");
                    Response.Redirect(AD419Configuration.ErrorPage(AD419Configuration.ErrorType.DATA));
                }

                //So now we have all of the Expenses, along with Spent and FTE, for this Grouping in currentGroupingExpenses
                //As well as all of the projects and percentages in projectCheckedArray

                //Now build up an array of associations to be entered, totaling (num projects X num expenses in current grouping) entries long
                transactionArray = buildTransactionArray(currentGroupingExpenses, projectCheckedArray);

                //Now execute the association transaction defined in DataAccess on the current Expense grouping
                AD419DataAccess data = new AD419DataAccess();

                try
                {
                    data.insertAssociationsTransaction(transactionArray, dlistAssociationsDepartment.SelectedValue);
                }
                catch (SqlException ex)
                {
                    AD419ErrorReporting.ReportError(ex, "associateRecords");
                    Response.Redirect(AD419Configuration.ErrorPage(AD419Configuration.ErrorType.DATA));
                }
            }

            return true;
        }

        /// <summary>
        /// Check to see if the the value 'value' is contained in a certain column
        /// in the dataset
        /// </summary>
        /// <param name="ds">DataSet to search</param>
        /// <param name="columnName">Column Name to search</param>
        /// <param name="value">The value to search for</param>
        /// <returns>True if the value is present, false otherwise</returns>
        private DataRow getRowInDataSet(DataSet ds, string columnName, string value)
        {
            foreach (DataRow row in ds.Tables[0].Rows)
            {
                if ((string)row[columnName] == value)
                    return row;
            }

            return null;
        }

        /// <summary>
        /// Returns the total ammount spent over the checked records, given in the
        /// checked records array list
        /// </summary>
        /// <param name="rowIndex">ArrayList containing the rowIndex's of checked rows</param>
        /// <returns>Total Amount Spent</returns>
        /// <remarks>Could also probably keep a running total in the viewstate</remarks>
        private double getTotalSpent(ArrayList checkedRecords)
        {
            double TotalSpent = 0;

            //The total is always in the fourth column, even if the third column is set visible = false
            int cellIndex = AD419Configuration.cellIndexRecordsSpent;

            foreach (int rowIndex in checkedRecords)
            {
                //Using NumberStyles.Currency in order to allow the string to contain the $, (), and thousands separator.
                TotalSpent += double.Parse(gvAssociationRecords.Rows[rowIndex].Cells[cellIndex].Text, System.Globalization.NumberStyles.Currency);
                //string Total = string.Format("{0:f}", gvAssociationRecords.Rows[rowIndex].Cells[cellIndex].Text);
                //TotalSpent += double.Parse(string.Format("{0:f}", gvAssociationRecords.Rows[rowIndex].Cells[cellIndex].Text));
            }

            return TotalSpent;
        }

        /// <summary>
        /// Sets the percent header from the given percent, rounded to
        /// the nearest whole number
        /// </summary>
        private void setPercentTotal(double percent)
        {
            //If percent rounds to 0, set the header to 0%
            if (Math.Round(percent, 0) == 0)
                gvAssociationProjects.HeaderRow.Cells[1].Text = "0%";
            else
                gvAssociationProjects.HeaderRow.Cells[1].Text = percent.ToString("#") + "%";
        }

        /// <summary>
        /// Clears all values in the projects gridview, sets the viewstate 'NumCheckedProjects' entry back to zero,
        /// greys out (enabled = false) the grid
        /// </summary>
        /// <remarks>Called when the departments or record grouping dlist's change, or when the filtering checks are changed</remarks>
        private void clearGvAssociationProjects()
        {
            foreach (GridViewRow row in gvAssociationProjects.Rows)
            {
                //Get the row's checkbox and textbox
                CheckBox currentCheckBox = (CheckBox)row.FindControl("cboxAssociatePercent");
                TextBox currentTextBox = (TextBox)row.FindControl("txtAssociatePercent");

                //Clear all values
                row.Cells[AD419Configuration.cellIndexProjectSpent].Text = string.Empty;
                row.Cells[AD419Configuration.cellIndexProjectsFTE].Text = string.Empty;
                currentTextBox.Text = string.Empty;
                currentCheckBox.Checked = false;
            }

            //Reset the viewstate to 0 projects
            ViewState["NumCheckedProjects"] = 0;
            ViewState["CheckedRecords"] = null;

            if (gvAssociationProjects.Rows.Count != 0)
            {
                //Chage the header on the first column to show that no projects are selected
                LinkButton lbtnNumCheckedProjects = (LinkButton)gvAssociationProjects.HeaderRow.FindControl("lbtnNumCheckedProjects");
                lbtnNumCheckedProjects.Text = string.Empty;
                gvAssociationProjects.HeaderRow.Cells[1].Text = "0%";
                //Disable the projects grid
                gvAssociationProjects.Enabled = false;
            }

            //update the projects updatepanel so the changes will take effect asynchronously
            updateAssociationProjects.Update();
        }

        /// <summary>
        /// Given the current grouping and current checked projects, a transaction array is built of Expenses <--> Accession
        /// with all the proper Spent($) and FTE adding up after being spread out over multiple projects by arbitrary percentages.
        /// </summary>
        /// <param name="currentGroupingExpenses">Contains all of the ExpenseIDs, along with Spent and FTE, from the Grouping checked</param>
        /// <param name="projectCheckedArray">Contains all of the projects, by Accession, along with Percent, from the Projects checked</param>
        /// <returns></returns>
        private ArrayList buildTransactionArray(ArrayList currentGroupingExpenses, ArrayList projectCheckedArray)
        {
            ArrayList transactionArray = new ArrayList();

            for (int i = 0; i < currentGroupingExpenses.Count; i++)
            {
                ArrayList currentExpense = (ArrayList)currentGroupingExpenses[i];

                int currentExpenseID = (int)currentExpense[0];
                double TotalSpent = double.Parse(currentExpense[1].ToString());
                double TotalFTE = 0d;
                double tempFTE = 0d;

                if (double.TryParse(currentExpense[2].ToString(), out tempFTE))
                    TotalFTE = tempFTE;

                double currentSpentSum = 0.0;
                double currentFTESum = 0.0;

                for (int j = 0; j < projectCheckedArray.Count; j++)
                {
                    ArrayList currentCheckedProject = (ArrayList)projectCheckedArray[j];

                    string Accession = (string)currentCheckedProject[0];
                    double Percent = (double)currentCheckedProject[1];

                    if (j == projectCheckedArray.Count - 1)
                    {
                        //If this is the last entry in the projects array, ignore the percentage and associate the left overs
                        transactionArray.Add(buildInsertAssociationParameters(currentExpenseID, Accession, TotalSpent - currentSpentSum, TotalFTE - currentFTESum));
                    }
                    else
                    {
                        //else associate by percent
                        transactionArray.Add(buildInsertAssociationParameters(currentExpenseID, Accession, TotalSpent * Percent, TotalFTE * Percent));
                        currentSpentSum += TotalSpent * Percent;
                        currentFTESum += TotalFTE * Percent;
                    }
                }
            }

            return transactionArray;
        }

        /// <summary>
        /// Returns a LinkButton that contains an OnClick event which sorts a column in a gridview through
        /// the use of JavaScript
        /// </summary>
        /// <param name="ColumnName">The Display Name of the LinkButton</param>
        /// <param name="SortExpression">The expression to sort on that matches the database column name</param>
        /// <returns>A LinkButton which causes a sorting postback when clicked</returns>
        /// <remarks>There must be a SortExpression defined in the gridview that matches the one here, as well as a
        /// blank initial header text.  Also, this is gridview specific so it will only work with the gvAssociationRecords
        /// grid.</remarks>
        private LinkButton getSortingLinkButton(string ColumnName, string SortExpression)
        {
            LinkButton lbtn = new LinkButton();
            lbtn.ForeColor = System.Drawing.Color.White;    //Make it white to match the grid

            lbtn.Text = ColumnName;

            //Performs the actual postback that sorts the gridview based on the SortExpression
            lbtn.OnClientClick = "javascript:__doPostBack('ctl00$ContentBody$gvAssociationRecords','Sort$" + SortExpression + "')";

            return lbtn;
        }

        /// <summary>
        /// Creates an Insert Association Parameter to be used in a assoication insert transaction
        /// </summary>
        /// <param name="ExpenseID">ExpenseID to associate</param>
        /// <param name="Accession">Accession number to associate</param>
        /// <param name="Spent">Total Spent by the ExpenseID on the Accession number</param>
        /// <param name="FTE">FTE</param>
        /// <returns></returns>
        private ArrayList buildInsertAssociationParameters(int ExpenseID, string Accession, double Spent, double FTE)
        {
            ArrayList parameterArray = new ArrayList();

            parameterArray.Add(ExpenseID);
            parameterArray.Add(Accession);
            parameterArray.Add(Spent);
            parameterArray.Add(FTE);

            return parameterArray;
        }

        #endregion Private Methods

        #endregion Associations

        #region Reports

        #region Object Callbacks

        /// <summary>
        /// Generates a report on the reporting server, depending on the ReportType currently selected.
        /// </summary>
        /// <remarks>Report Server URL should be put into a AppSetting</remarks>
        protected void btnGenerate_Click(object sender, EventArgs e)
        {
            Microsoft.Reporting.WebForms.ReportViewer rview = new Microsoft.Reporting.WebForms.ReportViewer();

            rview.ServerReport.ReportServerUrl = new Uri(System.Web.Configuration.WebConfigurationManager.AppSettings["ReportServer"]);

            System.Collections.Generic.List<Microsoft.Reporting.WebForms.ReportParameter> paramList = new System.Collections.Generic.List<Microsoft.Reporting.WebForms.ReportParameter>();

            int ReportID = int.Parse(dlistChooseReport.SelectedValue);
            if (ReportID == (int)AD419Configuration.ReportType.ProjectAD419)
            {
                paramList.Add(new Microsoft.Reporting.WebForms.ReportParameter("OrgR", dlistReportDepartment.SelectedValue));
                //paramList.Add(new Microsoft.Reporting.WebForms.ReportParameter("SortColumn", dlistSortBy.SelectedValue));
                rview.ServerReport.ReportPath = "/AD419Reports/ProjectAD419";
            }
            else if (ReportID == (int)AD419Configuration.ReportType.DepartmentAD419)
            {
                paramList.Add(new Microsoft.Reporting.WebForms.ReportParameter("OrgR", dlistReportDepartment419Departments.SelectedValue));
                paramList.Add(new Microsoft.Reporting.WebForms.ReportParameter("intAssociationStatus", dlistExpenseFiltering.SelectedValue));
                rview.ServerReport.ReportPath = "/AD419Reports/DepartmentAD419";
            }

            //Microsoft.Reporting.WebForms.ReportParameter[] param = new Microsoft.Reporting.WebForms.ReportParameter[2];
            //param[0] = new Microsoft.Reporting.WebForms.ReportParameter("CRISDeptCd", dlistReportDepartment.SelectedValue);
            //param[1] = new Microsoft.Reporting.WebForms.ReportParameter("SortColumn", dlistSortBy.SelectedValue);
            rview.ServerReport.SetParameters(paramList);

            string mimeType, encoding, extension, deviceInfo;
            string[] streamids;
            Microsoft.Reporting.WebForms.Warning[] warnings;
            string format = dlistExportType.SelectedValue;

            deviceInfo =
            "<DeviceInfo>" +
            "<SimplePageHeaders>True</SimplePageHeaders>" +
            "</DeviceInfo>";

            byte[] bytes = rview.ServerReport.Render(format, deviceInfo, out mimeType, out encoding, out extension, out streamids, out warnings);

            Response.Clear();

            if (format == "PDF")
            {
                Response.ContentType = "application/pdf";
                Response.AddHeader("Content-disposition", "filename=output.pdf");
            }
            else if (format == "Excel")
            {
                Response.ContentType = "application/excel";
                Response.AddHeader("Content-disposition", "filename=output.xls");
            }

            Response.OutputStream.Write(bytes, 0, bytes.Length);
            Response.OutputStream.Flush();
            Response.OutputStream.Close();
            Response.Flush();
            Response.Close();
        }

        /// <summary>
        /// Remove the "All Departments" option for Non-Admins
        /// </summary>
        protected void dlistReportDepartment419Departments_DataBound(object sender, EventArgs e)
        {
            DropDownList currentDList = (DropDownList)sender;

            if (Roles.IsUserInRole("Admin") == false)
            {
                ListItem AllDepartments = currentDList.Items.FindByValue("All");

                if (AllDepartments != null)
                    currentDList.Items.Remove(AllDepartments);
            }
        }

        /// <summary>
        /// Changes the multiview so that selecting a different report from the drop down list
        /// will present you with options pertaining to that report
        /// </summary>
        protected void dlistChooseReport_SelectedIndexChanged(object sender, EventArgs e)
        {
            mViewReportTypes.ActiveViewIndex = int.Parse(dlistChooseReport.SelectedValue);

            if (dlistChooseReport.SelectedValue != "-1")
                pnlGenerate.Visible = true;
            else
                pnlGenerate.Visible = false;
        }

        #endregion Object Callbacks

        #endregion Reports

        #region ViewControl

        /// <summary>
        /// Handles panel swapping so the code is re-usable.  Takes advantage of the ReportingModuleType
        /// enum in the static AD419Configuration class to keep the naming/code clean.
        /// </summary>
        /// <param name="type">ReportingModuleType enum</param>
        private void setupReportView(AD419Configuration.ReportingModuleType type)
        {
            switch (type)
            {
                case AD419Configuration.ReportingModuleType.ProjectInformation:
                    pnlProjectInfo.Visible = true;
                    pnlAssociations.Visible = false;
                    pnlReports.Visible = false;
                    break;
                case AD419Configuration.ReportingModuleType.Associations:
                    pnlAssociations.Visible = true;
                    pnlProjectInfo.Visible = false;
                    pnlReports.Visible = false;
                    break;
                case AD419Configuration.ReportingModuleType.Reports:
                    pnlReports.Visible = true;
                    pnlProjectInfo.Visible = false;
                    pnlAssociations.Visible = false;
                    break;
            }
        }

        #endregion ViewControl

        protected void ibutReports_Click(object sender, ImageClickEventArgs e)
        {
            ibutProjects.ImageUrl = "Images/projects_unsel.gif";
            ibutAssociations.ImageUrl = "Images/associations_unsel.gif";
            ibutReports.ImageUrl = "Images/reports_sel.gif";
            setupReportView(AD419Configuration.ReportingModuleType.Reports);
        }

        protected void ibutAssociations_Click(object sender, ImageClickEventArgs e)
        {
            ibutProjects.ImageUrl = "Images/projects_unsel.gif";
            ibutAssociations.ImageUrl = "Images/associations_sel.gif";
            ibutReports.ImageUrl = "Images/reports_unsel.gif";
            setupReportView(AD419Configuration.ReportingModuleType.Associations);
        }

        protected void ibutProjects_Click(object sender, ImageClickEventArgs e)
        {
            ibutProjects.ImageUrl = "Images/projects_sel.gif";
            ibutAssociations.ImageUrl = "Images/associations_unsel.gif";
            ibutReports.ImageUrl = "Images/reports_unsel.gif";
            setupReportView(AD419Configuration.ReportingModuleType.ProjectInformation);

            gViewSFNTotalExpenses.DataBind();
            dlistProjectID_SelectedIndexChanged(dlistProjectID, new EventArgs());
        }

        #region SFNTotals View Mode

        protected void ibtnSFNTotals_Click(object sender, ImageClickEventArgs e)
        {
            changeSFNTotalsViewMode((ImageButton)sender);
            ibtnSFNTotals.ImageUrl = "Images/totals_sel.gif";
            ibtnSFNUnassociated.ImageUrl = "Images/unass_unsel.gif";
            ibtnSFNAssociated.ImageUrl = "Images/ass_unsel.gif";
            ibtnSFNProject.ImageUrl = "Images/proj_unsel.gif";
        }

        protected void ibtnSFNAssociated_Click(object sender, ImageClickEventArgs e)
        {
            changeSFNTotalsViewMode((ImageButton)sender);
            ibtnSFNTotals.ImageUrl = "Images/totals_unsel.gif";
            ibtnSFNUnassociated.ImageUrl = "Images/unass_unsel.gif";
            ibtnSFNAssociated.ImageUrl = "Images/ass_sel.gif";
            ibtnSFNProject.ImageUrl = "Images/proj_unsel.gif";
        }

        protected void ibtnSFNUnassociated_Click(object sender, ImageClickEventArgs e)
        {
            changeSFNTotalsViewMode((ImageButton)sender);
            ibtnSFNTotals.ImageUrl = "Images/totals_unsel.gif";
            ibtnSFNUnassociated.ImageUrl = "Images/unass_sel.gif";
            ibtnSFNAssociated.ImageUrl = "Images/ass_unsel.gif";
            ibtnSFNProject.ImageUrl = "Images/proj_unsel.gif";
        }

        protected void ibtnSFNProject_Click(object sender, ImageClickEventArgs e)
        {
            changeSFNTotalsViewMode((ImageButton)sender);
            ibtnSFNTotals.ImageUrl = "Images/totals_unsel.gif";
            ibtnSFNUnassociated.ImageUrl = "Images/unass_unsel.gif";
            ibtnSFNAssociated.ImageUrl = "Images/ass_unsel.gif";
            ibtnSFNProject.ImageUrl = "Images/proj_sel.gif";

            if (gViewSFNTotalExpenses.HeaderRow != null)
            {
                gViewSFNTotalExpenses.HeaderRow.Cells[AD419Configuration.cellIndexSFNExpensesAmmount].Text = dlistProjectID.SelectedValue;
            }
        }

        private void changeSFNTotalsViewMode(ImageButton ibtn)
        {
            AD419DataSFNTotals.SelectParameters["AssociationStatus"].DefaultValue = ibtn.CommandArgument;
            gViewSFNTotalExpenses.DataBind();
            updateTotalExpenses.Update();
        }

        #endregion SFNTotals View Mode

        protected void gvAssociationRecords_PageIndexChanged(object sender, EventArgs e)
        {
            GridView currentGridView = (GridView)sender;
            clearGvAssociationProjects();
            currentGridView.Focus();
        }
    }
}