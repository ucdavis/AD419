<%@ Page Language="C#" MasterPageFile="~/AD419.master" AutoEventWireup="true" CodeFile="ReportingModule.aspx.cs" 
        Inherits="CAESDO.ReportingModule" Title="AD-419 Reporting Module" Trace="false" %>
        
<asp:Content ID="Content1" ContentPlaceHolderID="ContentHeader" Runat="Server">
</asp:Content>
<asp:Content ID="Content2" ContentPlaceHolderID="ContentBody" Runat="Server">

<Ajax:ScriptManager ID="ScriptManager" runat="server" EnablePartialRendering="true"></Ajax:ScriptManager>

<div id="wrapper2" style="font-size:12px;">
<script type="text/javascript" language="javascript">
    function showProgress(generateID)
    {
        var span = $(generateID);
        span.style.display = "inline";
    }
   function IMG1_onclick() {}
</script>

<Ajax:UpdateProgress ID="progressReportingModule" runat="server">
    <ProgressTemplate>
        <div class="loadingbox">
            <br /><img src="images/indicator_mozilla_blu.gif" alt="Progress" id="IMG1" /> Calculating...
        </div>
    </ProgressTemplate>
</Ajax:UpdateProgress>

<asp:ImageButton ID="ibutProjects" runat="server" ImageUrl="~/images/projects_sel.gif" OnClick="ibutProjects_Click" /><asp:ImageButton ID="ibutAssociations" runat="server" ImageUrl="~/images/associations_unsel.gif" OnClick="ibutAssociations_Click" /><asp:ImageButton ID="ibutReports" runat="server" ImageUrl="~/images/reports_unsel.gif" OnClick="ibutReports_Click" /><br />
    
<table border="0" cellpadding="0" cellspacing="0" width="980">
    <tr style="background-color:#FFFFFF;"><td style="width:17px; height: 18px;"><img src="images/corn_lefttop.gif" alt="" /></td><td style="height: 18px"><img src="images/spaceholder.gif" alt="" /></td><td style="width:17px; height: 18px;"><img src="images/corn_righttop.gif" alt="" /></td></tr>
    <tr style="background-color:#ffffff;"><td style="width:17px; vertical-align:top;"></td>
    <td style="vertical-align:top;">
    <asp:Panel ID="pnlProjectInfo" runat="server" Width="100%">
    <div style="float: left;">
    <div style="background-image:url(images/rm_bluemodbg.gif);background-repeat:repeat-y; vertical-align:top;width:429px;" >
        <div style="background-image:url(images/rm_bluemod_03.jpg); background-repeat:no-repeat; padding-left:25px;">
            <br /><br />Department:<asp:DropDownList ID="dlistDepartment" runat="server" AutoPostBack="True" DataSourceID="AD419DataReportingOrg" DataTextField="Org-Dept" DataValueField="OrgR" OnSelectedIndexChanged="dlistDepartment_SelectedIndexChanged" AppendDataBoundItems="True" OnDataBound="dlistDepartment_DataBound">
        <asp:ListItem Value="All">-- All Departments --</asp:ListItem></asp:DropDownList><br />
            <asp:GridView ID="gv_TotalExpensesByDept" runat="server" AutoGenerateColumns="False"
                 BorderStyle="None" BorderWidth="0px" 
                GridLines="None" Height="100%" OnRowDataBound="gv_TotalExpensesByDept_RowDataBound"
                  CellSpacing="5">
                <Columns>
                    <asp:BoundField DataField="Column1" >
                        <ItemStyle HorizontalAlign="Right" Width="75px" />
                    </asp:BoundField>
                    <asp:BoundField DataField="SPENT" HeaderText="SPENT" >
                        <ItemStyle CssClass="fillinBox" />
                        <HeaderStyle Width="123px" />
                    </asp:BoundField>
                    <asp:BoundField DataField="FTE" HeaderText="FTE" DataFormatString="{0:f2}" HtmlEncode="False" >
                        <ItemStyle CssClass="fillinBox2" Width="80px" />
                    </asp:BoundField>
                    <asp:BoundField DataField="RECS" HeaderText="RECS" >
                        <ItemStyle CssClass="fillinBox3" Width="63px" />
                    </asp:BoundField>
                </Columns>
                <RowStyle Height="30px" HorizontalAlign="Center" />
                <HeaderStyle HorizontalAlign="Center" />
            </asp:GridView></div></div><img src="images/rm_bluemod_05.jpg" alt="" height="42" /></div>
    <div style="float:right">
         <div style="background-image:url(images/rm_totalmod_04.gif); background-repeat:no-repeat; padding-left:25px; padding-top:25px;"> 
             <Ajax:UpdatePanel ID="updateViewMode" runat="server" UpdateMode="Conditional">
                 <ContentTemplate>
                     <asp:ImageButton ID="ibtnSFNTotals" runat="server" ImageUrl="~/images/totals_sel.gif"
                         CommandArgument="1" OnClick="ibtnSFNTotals_Click" />
                     <asp:ImageButton ID="ibtnSFNAssociated" runat="server" ImageUrl="~/images/ass_unsel.gif"
                         CommandArgument="2" OnClick="ibtnSFNAssociated_Click" />
                        <asp:ImageButton ID="ibtnSFNUnassociated" runat="server" ImageUrl="~/images/unass_unsel.gif" CommandArgument="3" OnClick="ibtnSFNUnassociated_Click" />
                        <asp:ImageButton ID="ibtnSFNProject" runat="server" ImageUrl="~/images/proj_unsel.gif" CommandArgument="4" OnClick="ibtnSFNProject_Click" />
                 </ContentTemplate>
             </Ajax:UpdatePanel>
         </div><%--
            <Ajax:UpdateProgress ID="progressTotalExpenses" runat="server">
            <ProgressTemplate>
            <div>
                Calculating...peopl
            </div>
            </ProgressTemplate>
            </Ajax:UpdateProgress>
            --%>
            <table cellpadding="0" cellspacing="0" border="0">
              <tr>
                <td style="background-image:url(images/rm_totalmod_06.gif); width: 9px;">
                </td>
                <td>
                
            <Ajax:UpdatePanel ID="updateTotalExpenses" runat="server" UpdateMode="Conditional">
            <ContentTemplate>
            <asp:GridView ID="gViewSFNTotalExpenses" runat="server" AutoGenerateColumns="False"
                CellPadding="2" DataKeyNames="LineTypeCode" DataSourceID="AD419DataSFNTotals"
                ForeColor="White" GridLines="Horizontal" OnPreRender="gViewSFNTotalExpenses_PreRender" Width="487px" BorderColor="White">
                <FooterStyle BackColor="#5D7B9D" Font-Bold="True" ForeColor="White" />
                <Columns>
                    <asp:BoundField DataField="LineDisplayDescriptor" HeaderText="Line Description" />
                    <asp:BoundField DataField="SFN" HeaderText="SFN" />
                    <asp:BoundField DataField="Total" HeaderText="Total" />
                </Columns>
                <RowStyle BackColor="White" ForeColor="#333333" />
                <EditRowStyle BackColor="#999999" />
                <SelectedRowStyle BackColor="#E2DED6" Font-Bold="True" ForeColor="#333333" />
                <PagerStyle BackColor="#284775" ForeColor="White" HorizontalAlign="Center" />
                <HeaderStyle BackColor="#33332D" Font-Bold="True" ForeColor="White" />
                <AlternatingRowStyle BackColor="#F7F6F3" ForeColor="Black" />
            </asp:GridView>
            </ContentTemplate>
           
        </Ajax:UpdatePanel>
                        </td>
                <td style="background-image:url(images/rm_totalmod_08.gif); width: 10px;">
                </td>
              </tr>
            </table><img src="images/rm_totalmod_13.jpg" alt="" />
</div>
<br />
<div style="float:left;">
<div style="text-align: center; width:429px;font-size:20px; font-weight:bold;">FISCAL YEAR <%= System.Configuration.ConfigurationManager.AppSettings["FiscalYear"] %></div>
   <div style="background-image:url(images/rm_bluemodbg.gif);background-repeat:repeat-y; vertical-align:top; float: left;" >
              <div style="background-image:url(images/rm_bluemod_03.jpg); background-repeat:no-repeat;  padding-left:23px; padding-right:20px;" > 
   
            <%-- Header table --%>
            <%-- Loading Progress: Keep out for now
            <Ajax:UpdateProgress ID="UpdateProjectsBodyProgress" runat="server">
                <ProgressTemplate>
                    Loading New Project Record ... 
                </ProgressTemplate>
            </Ajax:UpdateProgress>
            --%>
            <br /><br />
            <table id="projectsHeader" width="384" cellpadding="0" cellspacing="0" border="0"><tr>
                <td style="height: 20px">
                    <strong>Projects:</strong></td>
                <td style="height: 20px"><asp:Label ID="lblProjectsActive" runat="server" CssClass="labelboxes" ForeColor="#0066FF">12</asp:Label> 
                    <strong style="color: #0066ff">Active</strong></td>
                <td style="height: 20px"><asp:Label ID="lblProjectsExpired" runat="server" CssClass="labelboxes" ForeColor="#C00000">12</asp:Label> 
                    <strong style="color: #cc0000">Expired</strong></td>
                <td style="height: 20px"><asp:Label ID="lblProjectsTotal" runat="server" CssClass="labelboxes">12</asp:Label>
                    <strong>
                    Total</strong></td>
            </tr></table>

            <%-- Body with the project information --%>
            <Ajax:UpdatePanel ID="UpdateProjectsBody" runat="server" UpdateMode="Conditional">
            <ContentTemplate>
            <br />
            <table id="ProjectsBody"   width="384" cellpadding="0" cellspacing="0" border="0">
                <tr>
                    <td>
                        <strong>ProjectID</strong></td>
                    <td><asp:DropDownList ID="dlistProjectID" runat="server" AutoPostBack="True" DataSourceID="AD419DataProjects" DataTextField="Project" DataValueField="Project" OnSelectedIndexChanged="dlistProjectID_SelectedIndexChanged"><asp:ListItem Text="-- Choose A Project --"></asp:ListItem></asp:DropDownList>
                    </td>
                    <td>
                        <strong>Accession#</strong></td>
                    <td><asp:Label id="lblProjectAccession" runat="server" CssClass="labelboxesdark"></asp:Label></td>
                </tr>
            </table>
            <br />
            <table id="ProjectsBodyInvestigators" width="384" cellpadding="0" cellspacing="0" border="0">
                <tr>
                    <td colspan="3" align="center">
                        <strong>Investigator(s)</strong></td>
                </tr>
                <tr>
                    <td style="width:128px; height:32px;"><asp:TextBox ID="lblProjectInvestigator1" CssClass="labelboxes" runat="server" EnableViewState="False" Width="100px">&nbsp;</asp:TextBox></td>
                    <td style="width:128px;"><asp:TextBox ID="lblProjectInvestigator2" CssClass="labelboxes" runat="server" EnableViewState="False" Width="100px">&nbsp;</asp:TextBox></td>
                    <td style="width:128px;"><asp:TextBox ID="lblProjectInvestigator3" CssClass="labelboxes" runat="server" EnableViewState="False" Width="100px">&nbsp;</asp:TextBox></td>
                </tr>
                <tr>
                    <td style="height:21px;">
                        <asp:TextBox ID="lblProjectInvestigator4" CssClass="labelboxes" runat="server" EnableViewState="False" Width="100px">&nbsp;</asp:TextBox><br /><br /></td>
                    <td style="width: 128px"><asp:TextBox ID="lblProjectInvestigator5" CssClass="labelboxes" runat="server" EnableViewState="False" Width="100px">&nbsp;</asp:TextBox><br /><br /></td>
                    <td><asp:TextBox ID="lblProjectInvestigator6" CssClass="labelboxes" runat="server" EnableViewState="False" Width="100px">&nbsp;</asp:TextBox><br /><br /></td>
                </tr>
            </table>
            <table id="ProjectsBodyInfo" width="388" cellpadding="0" cellspacing="0" border="0">
                <tr style="height:19px;">
                    <td style="width:194px;">
                        <strong>Beginning Date</strong>
                        <br />
                        <asp:TextBox ID="lblBeginningDate" runat="server" EnableViewState="False" CssClass="labelboxes" Width="70px">begdate</asp:TextBox><br /><br /></td>
                    <td style="width:194px;">
                        <strong>Termination Date</strong>
                        <br />
                        <asp:TextBox ID="lblTerminationDate" runat="server" EnableViewState="False" CssClass="labelboxes" Width="70px">termdate</asp:TextBox><br /><br /></td>
                </tr>
                <tr style="height:19px;">
                    <td>
                        <strong>CRIS Status Type</strong></td>
                    <td>
                        <strong>CRIS Project Type</strong></td>
                </tr>
                <tr style="height:19px;">  
                    <td><asp:TextBox ID="lblProjectStatusType" runat="server" EnableViewState="False" CssClass="labelboxesdark" Width="160px" >statustype</asp:TextBox></td>
                    <td><asp:TextBox ID="lblProjectType" runat="server" EnableViewState="False" CssClass="labelboxesdark" Width="160px" >projectype</asp:TextBox></td>
                </tr>
                <tr style="height:19px;">
                    <td>
                        <strong>Regional Project Number</strong></td>
                    <td>
                        <strong>CRIS Funding Type</strong></td>
                </tr>
                <tr style="height:19px;"> 
                    <td><asp:TextBox ID="lblProjectNumber" runat="server" EnableViewState="False" CssClass="labelboxesdark" Width="160px">projnumber</asp:TextBox><br /><br /></td>
                    <td><asp:TextBox ID="lblProjectFundingType" runat="server" EnableViewState="False" CssClass="labelboxesdark" Width="160px" >projfundtype</asp:TextBox><br /><br /></td>
                </tr>
                <tr>
                    <td colspan="3" align="center" style="height: 13px">
                        <strong>Project Title / Description</strong></td>
                </tr>
                <tr>
                    <td colspan="3" style="height: 24px;"><asp:TextBox ID="txtProjectDescription" runat="server" TextMode="MultiLine" Width="380px" ReadOnly="True" EnableViewState="False"></asp:TextBox></td>
                </tr>
            </table>
            </ContentTemplate>
            </Ajax:UpdatePanel>


<asp:ObjectDataSource ID="AD419DataReportingOrg" runat="server"
        SelectMethod="getReportingOrgFiltered" TypeName="CAESDO.AD419DataAccess" OldValuesParameterFormatString="original_{0}">
    <SelectParameters>
        <asp:Parameter DefaultValue="<%$ Code: ((CAESDO.CAESDOPrincipal)Cache.Get(HttpContext.Current.User.Identity.Name)).EmployeeID %>" Name="employeeID" Type="String" />
    </SelectParameters>
</asp:ObjectDataSource>



<asp:ObjectDataSource ID="AD419DataProjects" runat="server" SelectMethod="getProjectsByDept"
                        TypeName="CAESDO.AD419DataAccess">
                        <SelectParameters>
                            <asp:ControlParameter ControlID="dlistDepartment" Name="OrgR" PropertyName="SelectedValue"
                                Type="String" />
                        </SelectParameters>
                    </asp:ObjectDataSource>
    <asp:ObjectDataSource ID="AD419DataSFNTotals" runat="server" SelectMethod="getExpensesBySFN"
        TypeName="CAESDO.AD419DataAccess" OldValuesParameterFormatString="original_{0}">
        <SelectParameters>
            <asp:ControlParameter ControlID="dlistDepartment" Name="OrgR" PropertyName="SelectedValue"
                Type="String" />
            <asp:ControlParameter ControlID="lblProjectAccession" Name="Accession" PropertyName="Text"
                Type="String" />
            <asp:Parameter DefaultValue="1" Name="AssociationStatus" Type="Int32" />
        </SelectParameters>
    </asp:ObjectDataSource>
</div></div></div><img src="images/rm_bluemod_05.jpg" width="429" alt="" />
    </asp:Panel>
    <asp:Panel ID="pnlAssociations" runat="server" Visible="false">
    Department:
    <asp:DropDownList ID="dlistAssociationsDepartment" runat="server"
        AutoPostBack="True" DataSourceID="AD419DataAssociationsReportingOrg" DataTextField="Org-Dept"
        DataValueField="OrgR">
    </asp:DropDownList><br />
    <asp:ObjectDataSource ID="AD419DataAssociationsReportingOrg" runat="server"
        SelectMethod="getReportingOrgFiltered" TypeName="CAESDO.AD419DataAccess">
        <SelectParameters>
        <asp:Parameter DefaultValue="<%$ Code: ((CAESDO.CAESDOPrincipal)Cache.Get(HttpContext.Current.User.Identity.Name)).EmployeeID %>" Name="employeeID" Type="String" />
        </SelectParameters>
    </asp:ObjectDataSource>
    <br />
    
    <div id="AssociationsHeader" style="float:left; width:540px;" >
            <div style="background-image:url(images/rm_associationsbig.gif); background-repeat:no-repeat;  padding-left:21px; padding-right:20px; padding-top: 25px; padding-bottom: 10px;" > 
            <Ajax:UpdatePanel ID="updateAssociationsHeader" runat="server" UpdateMode="conditional">
            <ContentTemplate>
                <strong>
                Expense Record Grouping:</strong> &nbsp;
                <asp:DropDownList ID="dlistRecordGrouping" runat="server" AutoPostBack="True" OnSelectedIndexChanged="dlistRecordGrouping_SelectedIndexChanged"><asp:ListItem Text="Organization"></asp:ListItem>
                    <asp:ListItem>Sub-Account</asp:ListItem>
                    <asp:ListItem Value="PI">Principle Investigator</asp:ListItem>
                    <asp:ListItem>Account</asp:ListItem>
                    <asp:ListItem>Employee</asp:ListItem>
                    <asp:ListItem Value="None">No Grouping</asp:ListItem>
                </asp:DropDownList>
                <%-- 
                <Ajax:UpdateProgress ID="updateProgressAssociationGrouping" runat="server">
                <ProgressTemplate>
                    Processing...
                </ProgressTemplate>
                </Ajax:UpdateProgress>
                --%>
                <br />
                <strong>
                Show:</strong> &nbsp;&nbsp;
                <asp:CheckBox ID="cboxAssociated" runat="server" Text="Associated" AutoPostBack="True" OnCheckedChanged="cboxAssociated_CheckedChanged" OnPreRender="cboxAssociated_PreRender" />&nbsp;
                <asp:CheckBox ID="cboxUnassociated" runat="server" Text="Unassociated" Checked="true" AutoPostBack="True" OnCheckedChanged="cboxUnassociated_CheckedChanged" OnPreRender="cboxUnassociated_PreRender" />
            </ContentTemplate>
            </Ajax:UpdatePanel>
            </div>
            <table cellpadding="0" cellspacing="0" border="0" width="539">
              <tr>
                <td style="background-image:url(images/rm_totalmod_06.gif); width: 9px;">
                </td>
                <td>
            <%--Associations List--%>
            <div style="overflow:auto; height: 349px; width:520px; visibility: visible;">
            <Ajax:UpdatePanel ID="updateAssociationsGrouping" runat="server" UpdateMode="conditional">
            <ContentTemplate>
                <asp:GridView ID="gvAssociationRecords" runat="server" AllowSorting="True" DataSourceID="AD419DataExpenseRecordGrouping" AutoGenerateColumns="False" CellPadding="4" CssClass="bordertop" ForeColor="White" GridLines="Horizontal" EmptyDataText="No Records Found" DataKeyNames="isAssociated,Code" OnPreRender="gvAssociationRecords_PreRender" OnSorted="gvAssociationRecords_Sorted" BorderColor="White" Width="100%" AllowPaging="True" OnPageIndexChanged="gvAssociationRecords_PageIndexChanged" PageSize="200">
                    <FooterStyle BackColor="#5D7B9D" Font-Bold="True" ForeColor="White" />
                    <Columns>
                        <asp:BoundField DataField="Num" SortExpression="Num" />
                        <asp:BoundField DataField="Chart" HeaderText="Chart" SortExpression="Chart" />
                        <asp:BoundField DataField="Code" SortExpression="Code" NullDisplayText="----" />
                        <asp:BoundField DataField="Description" SortExpression="Description" NullDisplayText="----" >
                        </asp:BoundField>
                        <asp:BoundField DataField="Spent" DataFormatString="{0:c}" HeaderText="Spent ($)"
                            HtmlEncode="False" SortExpression="Spent" />
                        <asp:BoundField DataField="FTE" HeaderText="FTE" SortExpression="FTE" DataFormatString="{0:f2}" HtmlEncode="False" />
                        <asp:TemplateField>
                            <ItemTemplate>
                                <asp:CheckBox ID="cboxExpense" runat="server" AutoPostBack="True" OnCheckedChanged="cboxExpense_CheckedChanged" />
                            </ItemTemplate>
                        </asp:TemplateField>
                    </Columns>
                    <RowStyle BackColor="#EBF1E2" ForeColor="#333333" />
                    <EditRowStyle BackColor="#999999" />
                    <SelectedRowStyle BackColor="#E2DED6" Font-Bold="True" ForeColor="#333333" />
                    <PagerStyle BackColor="#284775" ForeColor="White" HorizontalAlign="Center" />
                    <HeaderStyle BackColor="#3D5C79" Font-Bold="True" ForeColor="White" Height="33px" />
                    <AlternatingRowStyle ForeColor="#284775" BackColor="White" />
                    <PagerSettings Mode="NumericFirstLast" Position="TopAndBottom" />
                </asp:GridView>
                <asp:ObjectDataSource ID="AD419DataExpenseRecordGrouping" runat="server" SelectMethod="getExpenseRecordGrouping"
                    TypeName="CAESDO.AD419DataAccess">
                    <SelectParameters>
                        <asp:ControlParameter ControlID="dlistRecordGrouping" Name="Grouping" PropertyName="SelectedValue"
                            Type="String" />
                        <asp:ControlParameter ControlID="dlistAssociationsDepartment" Name="OrgR" PropertyName="SelectedValue"
                            Type="String" />
                        <asp:ControlParameter ControlID="cboxAssociated" Name="Associated" PropertyName="Checked"
                            Type="Boolean" />
                        <asp:ControlParameter ControlID="cboxUnassociated" Name="Unassocaited" PropertyName="Checked"
                            Type="Boolean" />
                    </SelectParameters>
                </asp:ObjectDataSource>
                &nbsp;&nbsp;
            </ContentTemplate>
            <Triggers>
                <Ajax:AsyncPostBackTrigger ControlID="dlistRecordGrouping" EventName="SelectedIndexChanged" />
                <Ajax:AsyncPostBackTrigger ControlID="cboxAssociated" EventName="CheckedChanged" />
                <Ajax:AsyncPostBackTrigger ControlID="cboxUnassociated" EventName="CheckedChanged" />
            </Triggers>
            </Ajax:UpdatePanel>
            </div></td>
                <td style="background-image:url(images/rm_totalmod_08.gif); width: 10px;">
                </td>
              </tr>
            </table><img src="images/rm_associationsbigbot.gif" alt="" />
            <!--AssociationsTotals-->
            <Ajax:UpdatePanel ID="updateAssociationsTotalExpenses" UpdateMode="conditional" runat="server">
            <ContentTemplate>
            <div id="intdepBox2">
                <br />
                <asp:GridView ID="gv_TotalExpesnsesByDept" runat="server" BorderStyle="None"
                    GridLines="None" Height="100%" Width="100%" AutoGenerateColumns="False" DataSourceID="AD419ExpensesByDept" CellSpacing="5">
                    <Columns>
                        <asp:BoundField DataField="Column1" >
                            <ItemStyle CssClass="rmtotals" HorizontalAlign="Right" />
                        </asp:BoundField>
                        <asp:BoundField DataField="SPENT" HeaderText="SPENT" DataFormatString="{0:c}" HtmlEncode="False" >
                            <HeaderStyle Width="123px" HorizontalAlign="Center" />
                            <ItemStyle CssClass="fillinBox" HorizontalAlign="Center" />
                        </asp:BoundField>
                        <asp:BoundField DataField="FTE" HeaderText="FTE" DataFormatString="{0:f}" HtmlEncode="False" >
                            <ItemStyle CssClass="fillinBox" HorizontalAlign="Center" />
                            <HeaderStyle HorizontalAlign="Center" Width="123px" />
                        </asp:BoundField>
                        <asp:BoundField DataField="RECS" HeaderText="RECS" >
                            <ItemStyle CssClass="fillinBox" HorizontalAlign="Center" />
                            <HeaderStyle Width="123px" />
                        </asp:BoundField>
                    </Columns>
                    <HeaderStyle HorizontalAlign="Left" />
                    <RowStyle Height="30px" />
                </asp:GridView>
                    <asp:ObjectDataSource ID="AD419ExpensesByDept" runat="server" SelectMethod="getTotalExpensesByDept"
                        TypeName="CAESDO.AD419DataAccess" OldValuesParameterFormatString="original_{0}">
                        <SelectParameters>
                            <asp:ControlParameter ControlID="dlistAssociationsDepartment" Name="OrgR" PropertyName="SelectedValue"
                                Type="String" />
                        </SelectParameters>
                    </asp:ObjectDataSource>
                <br />
           </div>
           </ContentTemplate>
           </Ajax:UpdatePanel> 
    </div>
    <div style="float:right; width:390px;">

    <Ajax:UpdatePanel ID="UpdateAssociateRecords" runat="server" UpdateMode="Conditional">
    <ContentTemplate>
        <div style="background-image:url(images/rm_associationssm.gif); background-repeat:no-repeat;  padding-left:21px; padding-right:20px; padding-top: 25px; padding-bottom: 10px;" >           
          <asp:ImageButton ID="btnUnassociateRecords" runat="server" OnClick="btnUnassociateRecords_Click"  ImageUrl="images/unass_selrecord.gif" />
          <asp:ImageButton ID="btnAssociateRecords" runat="server"  OnClick="btnAssociateRecords_Click" ImageUrl="images/ass_selrecord.gif" />
        </div>
    </ContentTemplate>
    </Ajax:UpdatePanel>
    
        <table cellpadding="0" cellspacing="0" border="0"  width="389">
              <tr>
                <td style="background-image:url(images/rm_totalmod_06.gif); width: 9px;">
                </td>
                <td>
            
            <%--
            <div class="updateProgress">
                <Ajax:UpdateProgress ID="updateAssociationProjectsProgress" runat="server">
                <ProgressTemplate>
                <div>
                    Calculating...
                </div>
                </ProgressTemplate>
                </Ajax:UpdateProgress> 
            </div>
            --%>
            <div style="overflow:auto;height:450px; width:370px;" >
                <Ajax:UpdatePanel ID="updateAssociationProjects" runat="server" UpdateMode="conditional">
                <ContentTemplate>
                    <asp:Label ID="lblError" runat="server" EnableViewState="False" Font-Size="Larger"
                        ForeColor="Red"></asp:Label><asp:GridView ID="gvAssociationProjects" runat="server" AutoGenerateColumns="False" DataSourceID="AD419AssociationsDataProjects" CellPadding="4" CssClass="bordertop" ForeColor="#333333" GridLines="None" Enabled="False" DataKeyNames="Accession" EmptyDataText="No Projects Found" Width="100%">
                    <Columns>
                        <asp:TemplateField>
                            <ItemTemplate>
                                <asp:CheckBox ID="cboxAssociatePercent" runat="server" AutoPostBack="True" OnCheckedChanged="cboxAssociatePercent_CheckedChanged" />
                            </ItemTemplate>
                            <HeaderTemplate>
                                <asp:LinkButton ID="lbtnNumCheckedProjects" runat="server" CausesValidation="False"
                                    CommandArgument="SelectAll" ForeColor="White" OnClick="lbtnNumCheckedProjects_Click"
                                    ToolTip="Click to Select All Projects">0</asp:LinkButton>
                            </HeaderTemplate>
                        </asp:TemplateField>
                        <asp:TemplateField HeaderText="0%">
                            <ItemTemplate>
                                <asp:TextBox ID="txtAssociatePercent" runat="server" Width="3em" AutoPostBack="True" OnTextChanged="txtAssociatePercent_TextChanged"></asp:TextBox>
                            </ItemTemplate>
                        </asp:TemplateField>
                        <asp:BoundField DataField="Project" HeaderText="Project" SortExpression="Project" />
                        <asp:BoundField HeaderText="Spent ($)" />
                        <asp:BoundField HeaderText="FTE (#)" />
                    </Columns>
                    <FooterStyle BackColor="#5D7B9D" Font-Bold="True" ForeColor="White" />
                    <RowStyle BackColor="#EBF1E2" ForeColor="#333333" />
                    <EditRowStyle BackColor="#999999" />
                    <SelectedRowStyle BackColor="#E2DED6" Font-Bold="True" ForeColor="#333333" />
                    <PagerStyle BackColor="#284775" ForeColor="White" HorizontalAlign="Center" />
                    <HeaderStyle BackColor="#3D5C79" Font-Bold="True" ForeColor="White" />
                    <AlternatingRowStyle BackColor="White" ForeColor="#284775" />
                </asp:GridView>
                    <asp:ObjectDataSource ID="AD419AssociationsDataProjects" runat="server" SelectMethod="getProjectsByDept"
                        TypeName="CAESDO.AD419DataAccess">
                        <SelectParameters>
                            <asp:ControlParameter ControlID="dlistAssociationsDepartment" Name="OrgR" PropertyName="SelectedValue"
                                Type="String" />
                        </SelectParameters>
                    </asp:ObjectDataSource>
                    &nbsp;&nbsp;
                </ContentTemplate>
                </Ajax:UpdatePanel>
            </div>
            </td>
                <td style="background-image:url(images/rm_totalmod_08.gif); width: 10px;">
                </td>
              </tr>
            </table><img src="images/rm_associationssmbot.gif" alt="" />
     </div>
    </asp:Panel>
    
    <asp:Panel ID="pnlReports" runat="server">
    <div style="float:left">
       <div style="background-image:url(images/rm_bluemodbg.gif);background-repeat:repeat-y; vertical-align:top;width:429px;" >
              <div style="background-image:url(images/rm_bluemod_03.jpg); background-repeat:no-repeat; padding-left:25px; height:200px;">
                  <br />
                  <br />
    Report Type:
        <asp:DropDownList ID="dlistChooseReport" runat="server" AutoPostBack="True" OnSelectedIndexChanged="dlistChooseReport_SelectedIndexChanged">
            <asp:ListItem Value="-1">-- Choose Report Type --</asp:ListItem>
            <asp:ListItem Value="0">Project AD419</asp:ListItem>
            <asp:ListItem Value="1">Department AD419</asp:ListItem>
        </asp:DropDownList><br />
        <br />
        <asp:MultiView ID="mViewReportTypes" runat="server">
            <asp:View ID="ViewProject" runat="server">
                Department:
                <asp:DropDownList ID="dlistReportDepartment" runat="server" DataSourceID="AD419DataReportingOrg"
                    DataTextField="Org-Dept" DataValueField="OrgR">
                </asp:DropDownList>
                <br />
                <br />
                <%-- 
                Sort By:
                <asp:DropDownList ID="dlistSortBy" runat="server">
                    <asp:ListItem>Project</asp:ListItem>
                    <asp:ListItem>Accession</asp:ListItem>
                    <asp:ListItem>Spent</asp:ListItem>
                    <asp:ListItem>FTE</asp:ListItem>
                </asp:DropDownList><br />
                <br />
                --%>
            </asp:View>
            <asp:View ID="ViewDepartment" runat="server">
                Department:
                <asp:DropDownList ID="dlistReportDepartment419Departments" runat="server" DataSourceID="AD419DataReportingOrg"
                    DataTextField="Org-Dept" DataValueField="OrgR" AppendDataBoundItems="true" OnDataBound="dlistReportDepartment419Departments_DataBound">
                    <asp:ListItem Text="-- All Departments --" Value="All"></asp:ListItem>
                </asp:DropDownList>
                <br />
                <br />
                Show:
                <asp:DropDownList ID="dlistExpenseFiltering" runat="server">
                    <asp:ListItem Value="1">All Records</asp:ListItem>
                    <asp:ListItem Value="2">Associated</asp:ListItem>
                    <asp:ListItem Value="3">Unassociated</asp:ListItem>
                </asp:DropDownList>
                <br /><br />
            </asp:View>
        </asp:MultiView>  
    <asp:Panel ID="pnlGenerate" runat="server" Visible="false">
        Export to:
                <asp:DropDownList ID="dlistExportType" runat="server">
                    <asp:ListItem>PDF</asp:ListItem>
                    <asp:ListItem>Excel</asp:ListItem>
                </asp:DropDownList>
                <br /><br />
        <asp:Button ID="btnGenerate" runat="server" OnClick="btnGenerate_Click" OnClientClick="showProgress('GenerateProgress')" Text="Generate Report" />
        <span id="GenerateProgress" style="display:none;">Generating... Please Wait &nbsp;<img src="images/indicator_mozilla_blu.gif" alt="Progress" /></span>
    </asp:Panel>
    <asp:ObjectDataSource ID="AD419DataDepartments" runat="server" SelectMethod="getAllDepartments"
        TypeName="CAESDO.AD419DataAccess"></asp:ObjectDataSource></div></div><img src="images/rm_bluemod_05.jpg" alt="" /></div>
    </asp:Panel>
    </td>
    <td style="width:17px;"></td></tr>
    <tr style="background-color:#ffffff;"><td style="width:17px;"><img src="images/corn_leftbot.gif" alt="" /></td><td></td><td style="width:17px;"><img src="images/corn_rightbot.gif" alt="" /></td></tr>
    </table>
</div>
</asp:Content>

