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
    public partial class ReportingAssociations : ApplicationPage
    {
    
    #region Page Methods
        protected void Page_Load(object sender, EventArgs e)
        {
        } 
    #endregion

    #region Object Callbacks

        /// <summary>
        /// When changing departments, ensure that the projects gridview is reset to its initial state
        /// </summary>
        protected void dlistDepartment_SelectedIndexChanged(object sender, EventArgs e)
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
            TableCell tcCheckedHeader = gvAssociationProjects.HeaderRow.Cells[0]; //The header cell of the checkbox column
            //Check to see if the box was checked or unchecked
            if (cboxSender.Checked == true)
            {
                if (ViewState["NumCheckedProjects"] != null) //Check to make sure the ViewState Key exists
                {
                    ViewState["NumCheckedProjects"] = (int)ViewState["NumCheckedProjects"] + 1; //Increment the key
                    tcCheckedHeader.Text = ViewState["NumCheckedProjects"].ToString();
                }
                else
                {
                    //If the ViewState key has not been initialized, then set it equal to 1
                    ViewState["NumCheckedProjects"] = 1; //
                    tcCheckedHeader.Text = "1";
                }
            }
            else
            {
                //If a box is being unchecked
                if (ViewState["NumCheckedProjects"] != null)
                {
                    //If there is an entry in the viewstate, retrieve it and decrement it
                    ViewState["NumCheckedProjects"] = (int)ViewState["NumCheckedProjects"] - 1;
                    tcCheckedHeader.Text = ViewState["NumCheckedProjects"].ToString();
                }
                else
                {
                    //There is no entry in the viewstate (this shouldn't happen)
                    ViewState["NumCheckedProjects"] = 0;
                    tcCheckedHeader.Text = "0";
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
                    if ( gview.DataKeys[row.RowIndex]["isAssociated"].ToString() == "1")
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
                            AssociationsData = data.getAssociationsByGrouping(dlistRecordGrouping.SelectedValue, dlistDepartment.SelectedValue, Criterion, Chart, gvAssociationRecords.DataKeys[rowIndex]["isAssociated"].ToString());
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
                            AssociationsData = data.getAssociationsByGrouping(dlistRecordGrouping.SelectedValue, dlistDepartment.SelectedValue, Criterion, Chart, gvAssociationRecords.DataKeys[rowIndex]["isAssociated"].ToString());
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
        /// associated with
        /// </summary>
        protected void btnUnassociateRecords_Click(object sender, EventArgs e)
        {
            //If no records have been checked, return without doing any work
            if (ViewState["CheckedRecords"] == null)
                return;

            ArrayList checkedRecords = (ArrayList)ViewState["CheckedRecords"];

            //Make sure at least one record grouping is checked
            if (checkedRecords.Count == 0)
                return;

            //For each checked record grouping, delete the associated data
            foreach (int rowIndex in checkedRecords)
            {
                CheckBox currentCheckBox = (CheckBox)gvAssociationRecords.Rows[rowIndex].FindControl("cboxExpense");
                if (currentCheckBox.Checked != false)
                {
                    //Delete all associated information for the given criterion and grouping
                    string Chart = gvAssociationRecords.Rows[rowIndex].Cells[1].Text;
                    string Criterion = gvAssociationRecords.DataKeys[rowIndex]["Code"].ToString();
                    
                    AD419DataAccess data = new AD419DataAccess();

                    try
                    {
                        data.deleteAssociationsByGrouping(dlistDepartment.SelectedValue, dlistRecordGrouping.SelectedValue, Criterion, Chart);
                    }
                    catch (SqlException ex)
                    {
                        AD419ErrorReporting.ReportError(ex, "btnUnassociateRecords_Click");
                        Response.Redirect(AD419Configuration.ErrorPage(AD419Configuration.ErrorType.DATA));
                    }
                }
            }

            //Now that all of the records have been unassociated, clear the projects grid and rebind the records grid and totals grid
            ViewState["CheckedRecords"] = null;
            gvAssociationRecords.DataBind();
            gv_TotalExpesnsesByDept.DataBind();
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
        }

    #endregion

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
            if ( gvAssociationProjects.Rows.Count != 0 )
                gvAssociationProjects.HeaderRow.Cells[0].Text = ViewState["NumCheckedProjects"].ToString();

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
            
            int CurrentNumCheckedProjects = 0; //Will be used to keep track of which project we are currently associating

            ArrayList checkedRecords = (ArrayList)ViewState["CheckedRecords"];

            //Loop through all records that are checked (by index)
            foreach (int rowIndex in checkedRecords)
            {
                ArrayList transactionArray = new ArrayList(); //transaction array to keep the current transaction parameters in

                //Make sure the row is checked.  This should always be the case or else the rowIndex
                //should not be in checkedRecords
                CheckBox cbox = (CheckBox)gvAssociationRecords.Rows[rowIndex].FindControl("cboxExpense");
                
                if (cbox.Checked == false)
                    continue;

                //Grab the total value for this grouping
                double Spent = double.Parse(gvAssociationRecords.Rows[rowIndex].Cells[AD419Configuration.cellIndexRecordsSpent].Text, System.Globalization.NumberStyles.Currency);
                double FTE = double.Parse(gvAssociationRecords.Rows[rowIndex].Cells[AD419Configuration.cellIndexRecordsFTE].Text);

                double TotalSpentPerRow = 0.0; //Keeps track of how much has been assocaited
                double TotalFTEPerRow = 0.0;

                //Reset the current checked count
                CurrentNumCheckedProjects = NumCheckedProjects;

                //Now for this row, loop through all projects and associate the total Spent($) by the percentages
                //given in the text boxes
                foreach (GridViewRow row in gvAssociationProjects.Rows)
                {
                    CheckBox currentCheckBox = (CheckBox)row.FindControl("cboxAssociatePercent");
                    TextBox currentTextBox = (TextBox)row.FindControl("txtAssociatePercent");
                    
                    double associateSpent = 0.0;
                    double associateFTE = 0.0;

                    if (currentCheckBox.Checked == true)
                    {
                        CurrentNumCheckedProjects--; //We found one of the checked entries

                        //If this is the last row, forget the percentage and just associate everything left over
                        // (so that every cent is accounted for)
                        if (CurrentNumCheckedProjects == 0)
                        {
                            associateSpent = Spent - TotalSpentPerRow;
                            associateSpent = Math.Round(associateSpent, 2);

                            associateFTE = FTE - TotalFTEPerRow;
                            associateFTE = Math.Round(associateFTE, 2);
                        }
                        else
                        {
                            //associateSpent the given percenatge of the total Spent.  Percent is defined in whole numbers, so you must
                            //divide by 100 to get the correct multiplier
                            associateSpent = ( double.Parse(currentTextBox.Text) / 100.0 ) * Spent;
                            associateSpent = Math.Round(associateSpent, 2);
                            TotalSpentPerRow += associateSpent; //Keep a running count of how much you have assoicated so far

                            associateFTE = (double.Parse(currentTextBox.Text) / 100.0) * FTE;
                            associateFTE = Math.Round(associateFTE, 2);
                            TotalFTEPerRow += associateFTE;
                        }
                        
                        //Now we have to divide by the number of expenseIDs in the grouping so the numbers add up evenly
                        double NumExpenseIDs = double.Parse(gvAssociationRecords.Rows[rowIndex].Cells[0].Text);
                        associateSpent /= NumExpenseIDs;
                        associateFTE /= NumExpenseIDs;

                        //Do association
                        transactionArray.Add(setInsertAssociationParameters(dlistDepartment.SelectedValue, dlistRecordGrouping.SelectedValue,
                                                gvAssociationRecords.Rows[rowIndex].Cells[1].Text, gvAssociationRecords.DataKeys[rowIndex]["Code"].ToString(),
                                                gvAssociationProjects.DataKeys[row.RowIndex]["Accession"].ToString(), associateSpent, associateFTE));

                        //Stop looping if we have already gone through all projects
                        if (CurrentNumCheckedProjects == 0)
                            break;
                        
                    }
                }

                //Now that we have looped through all the projects on the right and built the parameter array, execute the transaction defined in DataAccess
                AD419DataAccess data = new AD419DataAccess();

                try
                {
                    data.insertAssociationsTransaction(transactionArray);
                }
                catch (System.Data.SqlClient.SqlException ex)
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
                gvAssociationProjects.HeaderRow.Cells[0].Text = string.Empty;
                gvAssociationProjects.HeaderRow.Cells[1].Text = "0%";
                //Disable the projects grid
                gvAssociationProjects.Enabled = false;
            }

            //update the projects updatepanel so the changes will take effect asynchronously
            updateAssociationProjects.Update();
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
            lbtn.OnClientClick = "javascript:__doPostBack('ctl00$ContentBody$gvAssociationRecords','Sort$"+SortExpression+"')";

            return lbtn;
        }

        /// <summary>
        /// Returns an ArrayList with all of the needed parameters for the insertAssociations SPROC in the correct order
        /// </summary>
        /// <param name="OrgR">Reporting Org</param>
        /// <param name="Grouping">The grouping currently used</param>
        /// <param name="Chart">The Chart -- 3 or L</param>
        /// <param name="Criterion">The unique criterion based on the Grouping</param>
        /// <param name="Accession">Accession number to associate with</param>
        /// <param name="Expense">Expense in dollars, rounded to 2 decimal places</param>
        /// <param name="FTE">FTE, rounded to two decimal places</param>
        /// <returns>ArrayList with parameters in the following order -- OrgR, Grouping, Chart, Criterion, Accession, Expense, FTE</returns>
        private ArrayList setInsertAssociationParameters(string OrgR, string Grouping, string Chart, string Criterion, string Accession, double Expense, double FTE)
        {
            ArrayList parameterArray = new ArrayList();

            parameterArray.Add(OrgR);
            parameterArray.Add(Grouping);
            parameterArray.Add(Chart);
            parameterArray.Add(Criterion);
            parameterArray.Add(Accession);
            parameterArray.Add(Expense);
            parameterArray.Add(FTE);

            return parameterArray;
        }

    #endregion

}

}