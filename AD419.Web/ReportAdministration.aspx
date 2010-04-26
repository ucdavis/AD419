<%@ Page Language="C#" MasterPageFile="~/AD419.master" AutoEventWireup="true" CodeFile="ReportAdministration.aspx.cs" Inherits="CAESDO.ReportAdministration" Title="AD-419 Report Administration" Trace="false" %>
 
<%@ Register Assembly="AjaxControlToolkit" Namespace="AjaxControlToolkit" TagPrefix="AjaxToolkit" %>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentHeader" Runat="Server">
</asp:Content>
<asp:Content ID="Content2" ContentPlaceHolderID="ContentBody" Runat="Server">
<Ajax:ScriptManager ID="ScriptManager" runat="server"></Ajax:ScriptManager>
    <br />
    <div id="wrapper">
           <asp:ImageButton ID="ibutExpenses" runat="server" ImageUrl="~/images/ad419_05.gif" OnClick="ibutExpenses_Click" /><asp:ImageButton ID="ibutInterdept" runat="server" ImageUrl="~/images/ad419_06.gif" OnClick="ImageButton2_Click" /><asp:ImageButton ID="ibutProject" runat="server" ImageUrl="~/images/ad419_07.gif" OnClick="ibutProject_Click" /><asp:ImageButton ID="ibutCoop" runat="server" ImageUrl="~/images/ad419_08.gif" OnClick="ibutCoop_Click" /><br />
           
           <table border="0" cellpadding="0" cellspacing="0">
           <tr style="background-color:#FFFFFF;"><td style="width:25px;"><img src="images/lefttop.gif" alt="" /></td><td><img src="images/spaceholder.gif" alt="" /></td><td style="width:25px;"><img src="images/righttop.gif" alt="" /></td></tr>
           <tr style="background-image:url(images/ad419_10.gif); background-repeat:repeat-x; background-color:#cfcfcf;"><td style="width:25px; vertical-align:top;"><img src="images/ad419_10.gif" alt="" /></td><td style="vertical-align:top;">
           <asp:Panel ID="pnlProjectAssociations" runat="server" Width="100%">
        <ul class="InfoList">
        <li></li><li>Reporting Org: <asp:DropDownList ID="dlistAssocationsReportingOrg" runat="server" DataSourceID="AD419DataReportingOrg" DataTextField="Org-Dept" DataValueField="OrgR" AutoPostBack="True" AppendDataBoundItems="True">
            <asp:ListItem Value="None">-- Pick A Department --</asp:ListItem>
        </asp:DropDownList></li></ul>
    <div class="xxxstyle"> 
        <asp:GridView ID="gViewProjectAssociations" runat="server" AutoGenerateColumns="False" CellPadding="4" DataSourceID="AD419DataAssociations" ForeColor="#333333" GridLines="None" AllowSorting="True" CellSpacing="1" DataKeyNames="AccountID" EmptyDataText="No Associable Accounts Found" OnRowUpdating="gViewProjectAssociations_RowUpdating">
            <FooterStyle BackColor="#5D7B9D" Font-Bold="True" ForeColor="White" />
            <Columns>
                <asp:CommandField ShowEditButton="True" ButtonType="Image" EditImageUrl="~/images/Edit.gif" CancelImageUrl="~/images/cancel.gif" UpdateImageUrl="~/images/update.gif" CancelText="Cancel2" >
                    <HeaderStyle CssClass="selecthead" Height="33px" />
                </asp:CommandField>
                <asp:BoundField DataField="AccountID" HeaderText="Account" SortExpression="AccountID" ReadOnly="True" >
                    <HeaderStyle CssClass="selecthead" Height="33px" />
                </asp:BoundField>
                <asp:BoundField DataField="Expenses" DataFormatString="{0:C}" HeaderText="Expenses"
                    HtmlEncode="False" SortExpression="Expenses" ReadOnly="True" >
                    <HeaderStyle CssClass="selecthead" Height="33px" />
                </asp:BoundField>
                <asp:BoundField DataField="AccountName" HeaderText="Account Name" SortExpression="AccountName" ReadOnly="True" >
                    <HeaderStyle CssClass="selecthead" Height="33px" />
                </asp:BoundField>
                <asp:BoundField DataField="AwardNum" HeaderText="Award Number" SortExpression="AwardNum" ReadOnly="True" >
                    <HeaderStyle CssClass="selecthead" Height="33px" />
                </asp:BoundField>
                <asp:BoundField DataField="PrincipalInvestigatorName" HeaderText="P.I. Name" SortExpression="PrincipalInvestigatorName" ReadOnly="True" >
                    <HeaderStyle CssClass="selecthead" Height="33px" />
                </asp:BoundField>
                <asp:TemplateField HeaderText="Project" SortExpression="Project">
                    <EditItemTemplate>
                        &nbsp;<asp:DropDownList ID="dlistProject" runat="server" DataSourceID="AD419DataAssociationProject"
                            DataTextField="Project" DataValueField="Project" AppendDataBoundItems="True" OnDataBound="dlistProject_DataBound">
                            <asp:ListItem Selected="True"></asp:ListItem>
                        </asp:DropDownList><asp:ObjectDataSource ID="AD419DataAssociationProject" runat="server"
                            SelectMethod="getProjectsByDept" TypeName="CAESDO.AD419DataAccess">
                            <SelectParameters>
                                <asp:ControlParameter ControlID="dlistAssocationsReportingOrg" Name="OrgR" PropertyName="SelectedValue"
                                    Type="String" />
                            </SelectParameters>
                        </asp:ObjectDataSource>
                    </EditItemTemplate>
                    <ItemTemplate>
                        <asp:Literal ID="litProject" runat="server" Text='<%# Eval("Project") %>'></asp:Literal>
                    </ItemTemplate>
                    <HeaderStyle CssClass="selecthead" Height="33px" />
                </asp:TemplateField>
                <asp:BoundField DataField="TermDate" HeaderText="Term Date" SortExpression="TermDate" DataFormatString="{0:d}" HtmlEncode="False" ReadOnly="True" >
                    <HeaderStyle CssClass="selecthead" Height="33px" />
                </asp:BoundField>
            </Columns>
            <RowStyle BackColor="#DAE1E8" ForeColor="#333333" Height="33px" />
            <EditRowStyle BackColor="#999999" />
            <SelectedRowStyle BackColor="#E0E0E0" Font-Bold="True" ForeColor="Black" />
            <PagerStyle BackColor="#284775" ForeColor="White" HorizontalAlign="Center" />
            <HeaderStyle BackColor="#5D7B9D" Font-Bold="True" ForeColor="Black" />
            <AlternatingRowStyle BackColor="White" ForeColor="#284775" />
        </asp:GridView>
        </div>
        &nbsp;&nbsp;
        <asp:ObjectDataSource ID="AD419DataAssociations" runat="server" SelectMethod="getProjectAssociations"
            TypeName="CAESDO.AD419DataAccess" UpdateMethod="changeProjectAssociation">
            <SelectParameters>
                <asp:ControlParameter ControlID="dlistAssocationsReportingOrg" Name="OrgR" PropertyName="SelectedValue"
                    Type="String" />
            </SelectParameters>
            <UpdateParameters>
                <asp:Parameter Name="AccountID" Type="String" />
                <asp:Parameter Name="Project" Type="String" />
            </UpdateParameters>
        </asp:ObjectDataSource>
    
    </asp:Panel>
    <br />
    <asp:Panel ID="pnlInterdepartmentalAssociations" runat="server" Width="100%" Visible="False">
         <div id="intdepBox">
             <br />
        <table style="margin-left:auto; margin-right:auto;">
            <tr>
                <td>
                    <span style="color: #003366">Project:</span></td> 
                <td><asp:TextBox ID="txtProject" runat="server"></asp:TextBox></td>
                <td>
                    &nbsp; &nbsp; &nbsp; &nbsp;<span style="color: #003366">Title:</span></td>
                <td rowspan="2" ><asp:TextBox ID="txtTitle" runat="server" Height="100%" TextMode="MultiLine" Width="25em"></asp:TextBox><br /></td>
            </tr>
            <tr>
                <td>
                    <span style="color: #003366">Accession:</span></td>
                <td><asp:TextBox ID="txtAccession" runat="server"></asp:TextBox></td>
                <td></td>
            </tr>
        </table>
             <br />
         </div>
         <br />
        <p style="text-align:center;">
            <asp:ImageButton ID="ImageButton1" runat="server" ImageUrl="images/xxxprojects2.gif" OnClick="ImageButton1_Click" /></p>
        <asp:Label ID="lblInterdepartmentalError" runat="server" ForeColor="Red" EnableViewState="False"></asp:Label><br />
        <table class="ProjectsTable" cellpadding="0" cellspacing="0" border="0">
            <tr>
                <td id="projectCell" valign="top">
                <div class="xxxstyle">
                    <asp:GridView ID="gviewProjects" runat="server" AllowSorting="True" AutoGenerateColumns="False" CellPadding="4" DataKeyNames="Accession" DataSourceID="AD419DATAInterdepartmentalProjects" ForeColor="#333333" GridLines="None" OnSelectedIndexChanged="gviewProjects_SelectedIndexChanged" AllowPaging="True" CellSpacing="1" BackColor="White">
                        <FooterStyle BackColor="White" Font-Bold="True" ForeColor="Black" />
                        <Columns>
                            <asp:CommandField ShowSelectButton="True" ButtonType="Image" SelectImageUrl="~/images/select.gif" >
                                <HeaderStyle CssClass="selecthead" Height="33px" />
                                <ItemStyle CssClass="selectrollover" />
                            </asp:CommandField>
                            <asp:BoundField DataField="Project" HeaderText="Project" SortExpression="Project" >
                                <HeaderStyle CssClass="selecthead" />
                            </asp:BoundField>
                            <asp:BoundField DataField="Ct" HeaderText="Count" SortExpression="Ct" >
                                <HeaderStyle CssClass="selecthead" />
                            </asp:BoundField>
                        </Columns>
                        <RowStyle BackColor="#DAE1E8" ForeColor="#333333" Height="22px" />
                        <EditRowStyle BackColor="#999999" Height="22px" />
                        <SelectedRowStyle Font-Bold="True" ForeColor="#333333" />
                        <PagerStyle BackColor="#5D7B9D" ForeColor="White" HorizontalAlign="Center" />
                        <HeaderStyle BackColor="#5D7B9D" Font-Bold="True" ForeColor="Black" />
                        <AlternatingRowStyle BackColor="White" ForeColor="#284775" />
                    </asp:GridView>
                </div>
                </td>
                <td id="investigatorCell" valign="top" style="width: 100%">
                <asp:Panel ID="pnlInvestigator" runat="server" Visible="false">
                <div class="xxxstyle2">
                    <table cellpadding="0" cellspacing="1" border="0" style="background-color:White; width:100%;">
                        <tr class="GridHeaderProfessional">
                            <td style="height:33px;width: 100%; background-image: url(images/greenbg.gif); background-repeat:no-repeat;">
                                <div style="color: black;text-align: center;">Investigators:</div></td>
                        </tr>
                        <tr>
                            <td style="width: 100%">
                                <asp:GridView ID="gviewInvestigators" runat="server" CellPadding="0" ForeColor="#333333" GridLines="None" ShowHeader="False" Width="100%" CssClass="investstyle">
                                    <FooterStyle BackColor="#5D7B9D" Font-Bold="True" ForeColor="White" />
                                    <RowStyle BackColor="#DAE1E8" ForeColor="#333333" Height="30px" CssClass="investleft" />
                                    <EditRowStyle BackColor="#999999" />
                                    <SelectedRowStyle BackColor="#E2DED6" Font-Bold="True" ForeColor="#333333" />
                                    <PagerStyle BackColor="#284775" ForeColor="White" HorizontalAlign="Center" />
                                    <HeaderStyle BackColor="#5D7B9D" Font-Bold="True" ForeColor="White" />
                                    <AlternatingRowStyle BackColor="White" ForeColor="#284775" CssClass="investleftwht" />
                                </asp:GridView>
                            </td>
                        </tr>
                    </table></div>
                </asp:Panel>
                </td>
                <td id="departmentCell" valign="top">
                <div class="xxxstyle2">
                <asp:Panel ID="pnlDepartment" runat="server" Visible="false" BackColor="White">
                    <asp:GridView ID="gViewDepartments" runat="server" AllowSorting="True" AutoGenerateColumns="False" CellPadding="0" DataKeyNames="CRISDeptCd" DataSourceID="AD419DataSecondaryDepartments" ForeColor="#333333" GridLines="None" EmptyDataText="No Associated Departments" ShowFooter="True" CellSpacing="1">
                        <FooterStyle BackColor="#5D7B9D" Font-Bold="True" ForeColor="White" />
                        <Columns>
                            <asp:TemplateField>
                                <ItemTemplate>
                                    <asp:ImageButton ID="lbtnRemoveDepartment" runat="server" CommandArgument='<%# Eval("CRISDeptCd") %>' OnClick="lbtnRemoveDepartment_Click" ImageUrl="images/remove.gif" />
                                </ItemTemplate>
                                <FooterTemplate>
                                    <asp:ImageButton ID="lbtnAddDepartment" runat="server" CommandName="INSERT" OnClick="lbtnAddDepartment_Click" ImageUrl="images/add.gif" />
                                </FooterTemplate>
                                <HeaderStyle CssClass="selecthead2" Height="33px" HorizontalAlign="Left" />
                            </asp:TemplateField>
                            <asp:TemplateField HeaderText="Department" SortExpression="deptname">
                                <ItemTemplate>
                                    <asp:Literal ID="litDeptname" runat="server" Text='<%# Eval("deptname") %>'></asp:Literal>
                                </ItemTemplate>
                                <FooterTemplate>
                                    <asp:DropDownList ID="dlistAllDepartments" runat="server" DataSourceID="AD419DataAllDepartments"
                                        DataTextField="deptname" DataValueField="CRISDeptCd" Height="25px">
                                    </asp:DropDownList>
                                </FooterTemplate>
                                <HeaderStyle CssClass="selecthead" ForeColor="Black" Height="33px" />
                            </asp:TemplateField>
                        </Columns>
                        <RowStyle BackColor="#DAE1E8" ForeColor="#333333" CssClass="investleft" Height="30px" />
                        <EditRowStyle BackColor="#999999" />
                        <SelectedRowStyle BackColor="#E2DED6" Font-Bold="True" ForeColor="#333333" />
                        <PagerStyle ForeColor="White" HorizontalAlign="Center" />
                        <HeaderStyle BackColor="#5D7B9D" Font-Bold="True" ForeColor="White" />
                        <AlternatingRowStyle BackColor="White" ForeColor="#284775" CssClass="investleftwht" />
                        <EmptyDataTemplate>
                            <table cellpadding="0" cellspacing="0" border="0">
                                <tr class="GridHeaderProfessional" style="height:33px;width: 100%; background-image: url(images/bg_gradgreen.gif);">
                                    <td style="background-image: url(images/greenbg.gif); background-repeat:no-repeat;"></td>
                                    <td style="color:Black">Department [Empty]</td>
                                </tr>
                                <tr>
                                    <td><br /><asp:ImageButton ID="lbtnAddFirstDepartment" runat="server" ImageUrl="images/add.gif" OnClick="lbtnAddFirstDepartment_Click" /></td>
                                    <td><br /><asp:DropDownList ID="dlistAddFirstDepartment" runat="server" DataSourceID="AD419DataAllDepartments" DataTextField="deptname" DataValueField="CRISDeptCd"></asp:DropDownList></td>
                                </tr>
                            </table>                            
                        </EmptyDataTemplate>
                    </asp:GridView>
                    &nbsp;&nbsp;
                    <asp:ObjectDataSource ID="AD419DataSecondaryDepartments" runat="server" SelectMethod="getSecondaryDepartments"
                        TypeName="CAESDO.AD419DataAccess" DeleteMethod="removeSecondaryDepartments" InsertMethod="insertSecondaryDepartments">
                        <SelectParameters>
                            <asp:ControlParameter ControlID="gviewProjects" Name="accession" PropertyName="SelectedValue"
                                Type="String" />
                        </SelectParameters>
                        <DeleteParameters>
                            <asp:ControlParameter ControlID="gviewProjects" Name="accession" PropertyName="SelectedValue"
                                Type="String" />
                            <asp:Parameter Name="CRISDeptCd" Type="String" />
                        </DeleteParameters>
                        <InsertParameters>
                            <asp:ControlParameter ControlID="gviewProjects" Name="accession" PropertyName="SelectedValue"
                                Type="String" />
                            <asp:Parameter Name="CRIS_DeptCd" Type="String" />
                        </InsertParameters>
                    </asp:ObjectDataSource>
                <asp:ObjectDataSource ID="AD419DataAllDepartments" runat="server"
                                        SelectMethod="getAllDepartments" TypeName="CAESDO.AD419DataAccess"></asp:ObjectDataSource>
                </asp:Panel></div>
                </td>
            </tr>
        </table>
        <asp:ObjectDataSource ID="AD419DATAInterdepartmentalProjects" runat="server" SelectMethod="getInterdepartmentalProjects"
            TypeName="CAESDO.AD419DataAccess"></asp:ObjectDataSource>
    </asp:Panel>
    
    <asp:Panel ID="pnlProjectExpenses" runat="server" Width="100%">
    <span class="InfoList">
        Filters:&nbsp;&nbsp;&nbsp;SFN: <asp:DropDownList ID="dlistFilterSFN" runat="server" DataSourceID="AD419DataSFN" DataTextField="Description" DataValueField="SFN" AutoPostBack="True" AppendDataBoundItems="True" OnSelectedIndexChanged="dlistFilterSFN_SelectedIndexChanged">
            <asp:ListItem Value="All">-- All SFNs--</asp:ListItem>
        </asp:DropDownList>&nbsp;Reporting Org: <asp:DropDownList ID="dlistFilterReportingOrg" runat="server" DataSourceID="AD419DataReportingOrg" DataTextField="Org-Dept" DataValueField="OrgR" AutoPostBack="True" AppendDataBoundItems="True" OnSelectedIndexChanged="dlistFilterReportingOrg_SelectedIndexChanged">
            <asp:ListItem Value="All">-- All Departments --</asp:ListItem>
        </asp:DropDownList></span>
        <br /><br />
        <asp:Button ID="btnAddExpense" runat="server" Text="Add Expense" />&nbsp;
        <asp:Label ID="lblAddExpense" runat="server" ForeColor="Red"></asp:Label><br />
        <br />
        <asp:ValidationSummary ID="valSummary" runat="server" />
        <div class="xxxstyle">
        <asp:GridView ID="gViewProjectExpenses" runat="server" AllowSorting="True" AutoGenerateColumns="False" CellPadding="4" DataKeyNames="ExpenseID" DataSourceID="AD419DataProjectExpenses" ForeColor="#333333" GridLines="None" AllowPaging="True" EmptyDataText="No Projects Found" CellSpacing="1" OnRowDeleted="gViewProjectExpenses_RowDeleted" OnRowUpdated="gViewProjectExpenses_RowUpdated" BackColor="White" Width="100%">
            <FooterStyle BackColor="#5D7B9D" Font-Bold="True" ForeColor="White" />
            <Columns>
                <asp:CommandField ShowEditButton="True" ButtonType="Image" EditImageUrl="~/images/Edit.gif" CancelImageUrl="~/images/cancel.gif" UpdateImageUrl="~/images/update.gif" >
                    <HeaderStyle CssClass="selecthead" Width="33px" />
                </asp:CommandField>
                <asp:TemplateField HeaderText="SFN" SortExpression="SFN">
                    <ItemTemplate>
                        <asp:Literal ID="litSFN" runat="server" Text='<%# Eval("SFN") %>'></asp:Literal>
                    </ItemTemplate>
                    <HeaderStyle CssClass="selecthead" Height="33px" />
                </asp:TemplateField>
                <asp:TemplateField HeaderText="OrgR" SortExpression="OrgR">
                    <ItemTemplate>
                        <asp:Literal ID="litOrgR" runat="server" Text='<%# Eval("OrgR") %>'></asp:Literal>
                    </ItemTemplate>
                    <HeaderStyle CssClass="selecthead" Height="33px" />
                </asp:TemplateField>
                <asp:TemplateField HeaderText="Project" SortExpression="Project">
                    <ItemTemplate>
                        <asp:Literal ID="litProject" runat="server" Text='<%# Eval("Project") %>'></asp:Literal>
                    </ItemTemplate>
                    <HeaderStyle CssClass="selecthead" Height="33px" />
                </asp:TemplateField>
                <asp:TemplateField HeaderText="Expenses" SortExpression="Expenses">
                    <EditItemTemplate>
                        <asp:TextBox ID="txtExpenses" runat="server" Text='<%# Bind("Expenses") %>'></asp:TextBox><asp:CompareValidator
                            ID="CompareValidator1" runat="server" ControlToValidate="txtExpenses" ErrorMessage="Expense Format Invalid"
                            ForeColor="DarkRed" Operator="GreaterThanEqual" Type="Double" ValueToCompare="0">*</asp:CompareValidator><asp:RequiredFieldValidator
                                ID="RequiredFieldValidator2" runat="server" ControlToValidate="txtExpenses" ErrorMessage="Expense Required"
                                ForeColor="DarkRed">*</asp:RequiredFieldValidator>
                    </EditItemTemplate>
                    <ItemTemplate>
                        <asp:Literal ID="litExpenses" runat="server" Text='<%# Eval("Expenses", "{0:C}") %>'></asp:Literal>
                    </ItemTemplate>
                    <HeaderStyle CssClass="selecthead" Height="33px" />
                </asp:TemplateField>
                <asp:TemplateField HeaderText="P.I." SortExpression="PI">
                    <ItemTemplate>
                        <asp:Literal ID="litPI" runat="server" Text='<%# Eval("PI") %>'></asp:Literal>
                    </ItemTemplate>
                    <HeaderStyle CssClass="selecthead" Height="33px" />
                </asp:TemplateField>
                <asp:CommandField ShowDeleteButton="True" ButtonType="Image" DeleteImageUrl="~/images/remove.gif" >
                    <HeaderStyle CssClass="selecthead" Height="33px" Width="80px" />
                </asp:CommandField>
            </Columns>
            <RowStyle BackColor="#DAE1E8" ForeColor="#333333" />
            <EditRowStyle BackColor="#999999" />
            <SelectedRowStyle BackColor="#E2DED6" Font-Bold="True" ForeColor="#333333" />
            <PagerStyle BackColor="#5D7B9D" ForeColor="White" HorizontalAlign="Center" />
            <HeaderStyle BackColor="#5D7B9D" Font-Bold="True" ForeColor="Black" />
            <AlternatingRowStyle BackColor="White" ForeColor="#284775" />
        </asp:GridView>
        </div>
        &nbsp; &nbsp;
        <asp:ObjectDataSource ID="AD419DataProjectExpenses" runat="server" SelectMethod="getProjectExpenses"
            TypeName="CAESDO.AD419DataAccess" UpdateMethod="changeProjectExpense" DeleteMethod="deleteProjectExpense">
            <SelectParameters>
                <asp:ControlParameter ControlID="dlistFilterSFN" Name="SFN" PropertyName="SelectedValue"
                    Type="String" />
                <asp:ControlParameter ControlID="dlistFilterReportingOrg" Name="OrgR" PropertyName="SelectedValue"
                    Type="String" />
            </SelectParameters>
            <UpdateParameters>
                <asp:Parameter Name="ExpenseID" Type="Int32" />
                <asp:Parameter Name="Expenses" Type="Decimal" />
            </UpdateParameters>
            <DeleteParameters>
                <asp:Parameter Name="ExpenseID" Type="Int32" />
            </DeleteParameters>
        </asp:ObjectDataSource>
        <asp:ObjectDataSource ID="AD419DataSFN" runat="server" SelectMethod="getSFN" TypeName="CAESDO.AD419DataAccess">
        </asp:ObjectDataSource>
        <asp:ObjectDataSource ID="AD419DataReportingOrg" runat="server" SelectMethod="getReportingOrg"
            TypeName="CAESDO.AD419DataAccess"></asp:ObjectDataSource>
        <asp:Panel ID="pnlSFNSubtotals" runat="server" Width="200px">
            <br />
            SFN Subtotals:<br />
            <div class="xxxstyle"><asp:GridView ID="gViewSFNSubtotals" runat="server" AllowSorting="True" AutoGenerateColumns="False"
                CellPadding="4" DataSourceID="AD419DataSFNSubtotals" ForeColor="#333333" GridLines="None" EmptyDataText="Please Choose a Department To See SFN Subtotals" CellSpacing="1" BackColor="White" Width="100%">
                <FooterStyle BackColor="#5D7B9D" Font-Bold="True" ForeColor="White" />
                <Columns>
                    <asp:BoundField DataField="SFN" HeaderText="SFN" SortExpression="SFN" >
                        <HeaderStyle CssClass="selecthead" Height="33px" />
                    </asp:BoundField>
                    <asp:BoundField DataField="SumOfExpenses" DataFormatString="{0:C}" HeaderText="Total Expenses"
                        HtmlEncode="False" SortExpression="SumOfExpenses" >
                        <HeaderStyle CssClass="selecthead" />
                    </asp:BoundField>
                </Columns>
                <RowStyle BackColor="#DAE1E8" ForeColor="#333333" />
                <EditRowStyle BackColor="#999999" />
                <SelectedRowStyle BackColor="#E2DED6" Font-Bold="True" ForeColor="#333333" />
                <PagerStyle BackColor="#284775" ForeColor="White" HorizontalAlign="Center" />
                <HeaderStyle BackColor="#5D7B9D" Font-Bold="True" ForeColor="Black" />
                <AlternatingRowStyle BackColor="White" ForeColor="#284775" />
            </asp:GridView></div>
            <asp:ObjectDataSource ID="AD419DataSFNSubtotals" runat="server" SelectMethod="getSFNSubtotals"
                TypeName="CAESDO.AD419DataAccess">
                <SelectParameters>
                    <asp:ControlParameter ControlID="dlistFilterReportingOrg" Name="OrgR" PropertyName="SelectedValue"
                        Type="String" />
                </SelectParameters>
            </asp:ObjectDataSource>
        </asp:Panel>
        
        <AjaxControlToolkit:ModalPopupExtender ID="MPopupAddExpense" runat="server" BackgroundCssClass="modalBackground" 
                            PopupControlID="pnlPopupAddExpense" TargetControlID="btnAddExpense" CancelControlID="btnCancelAddExpense">
        </AjaxControlToolkit:ModalPopupExtender>
        
        <asp:Panel ID="pnlPopupAddExpense" runat="server" Width="350px" CssClass="modalPopup" style="display:none;" DefaultButton="btnConfirmAddExpense">
        <div style="text-align:center;">
            <strong>Add Expense<br />
                <br />
            </strong>
        </div>
        <table>
            <tr>
                <td>SFN:</td>
                <td>
                    <asp:TextBox ID="txtAddExpenseSFN" runat="server" ReadOnly="True" Width="4em"></asp:TextBox></td>
            </tr>
            <tr>
                <td>Reporting Org:</td>
                <td>
                    <asp:TextBox ID="txtAddExpenseOrgR" runat="server" ReadOnly="True" Width="4em"></asp:TextBox></td>
            </tr>
            <tr>
                <td>Project:</td>
                <td><asp:DropDownList ID="dlistAddExpenseProject" runat="server" DataSourceID="AD419DataProjectsByOrg" DataTextField="Project" DataValueField="Accession"></asp:DropDownList><asp:ObjectDataSource ID="AD419DataProjectsByOrg" runat="server"
                    SelectMethod="getProjectsByDept" TypeName="CAESDO.AD419DataAccess">
                    <SelectParameters>
                        <asp:ControlParameter ControlID="dlistFilterReportingOrg" Name="OrgR" PropertyName="SelectedValue"
                            Type="String" />
                    </SelectParameters>
                </asp:ObjectDataSource>
                </td>
            </tr>
            <tr>
                <td>Expenses:</td>
                <td>
                    <asp:TextBox ID="txtAddExpenseExpenses" runat="server"></asp:TextBox><asp:RequiredFieldValidator ID="RequiredFieldValidator1" runat="server" ControlToValidate="txtAddExpenseExpenses"
                        ErrorMessage="RequiredFieldValidator" ValidationGroup="AddExpense">*</asp:RequiredFieldValidator><asp:CompareValidator
                            ID="CompareValidator1" runat="server" ControlToValidate="txtAddExpenseExpenses"
                            ErrorMessage="Expense Format Invalid" Operator="GreaterThanEqual" Type="Double"
                            ValidationGroup="AddExpense" ValueToCompare="0">*</asp:CompareValidator></td>
            </tr>
        </table>
            <br />
        <div class="Submit" >
                <asp:Label ID="lblAddExpenseInfo" runat="server" Text="You Must Choose a Department and SFN Before Adding An Expense" ForeColor="Red"></asp:Label>
                <br />
                <asp:Button ID="btnConfirmAddExpense" runat="server" Text="Add Expense" Enabled="False" ValidationGroup="AddExpense" OnClick="btnConfirmAddExpense_Click" />
                <asp:Button ID="btnCancelAddExpense" runat="server" Text="Cancel" CausesValidation="False" />
        </div>
        </asp:Panel>
        <br />
    </asp:Panel>
               <br />
               <asp:Panel ID="pnl_CEEntry" runat="server" style="width:100%;">
                    <asp:Label ID="lblCEEntryStatus" runat="server" Text="" EnableViewState="false"></asp:Label>
                   <asp:ValidationSummary ID="valSummaryCEEntry" runat="server" ValidationGroup="CEEntry" />
                   <br />
                   <table><tr><td style="width:400px;"><div class="xxxstyle" style="width:380px"><table style="background-color:White;width:380px;" cellpadding="0" cellspacing="1">
                       <tbody>
                           <tr style="height:33px;">
                               <td class="selecthead" style="text-align: left;">
                                  &nbsp;&nbsp;<strong>Department:</strong></td>
                               <td>
                               </td>
                               <td>
                                   <asp:DropDownList ID="DDL_Department" runat="server" AppendDataBoundItems="True"
                                       AutoPostBack="True" DataSourceID="AD419DataReportingOrg" DataTextField="Org-Dept"
                                       DataValueField="OrgR" OnSelectedIndexChanged="DDL_Department_SelectedIndexChanged"
                                       Width="250px">
                                       <asp:ListItem Selected="True" Value="0">-- Select Department --</asp:ListItem>
                                   </asp:DropDownList></td>
                           
                           </tr>
                           <tr style="height:33px;">
                               <td style="height:33px" class="selecthead">
                                   &nbsp;&nbsp;<strong>PI:</strong></td>
                               <td style="height: 33px">
                               </td>
                               <td style="height: 33px;">
                                   <asp:DropDownList ID="DDL_PI" runat="server" AppendDataBoundItems="True" AutoPostBack="True"
                                       DataTextField="PrincipalInvestigatorName" DataValueField="PrincipalInvestigatorName"
                                       Enabled="False" OnSelectedIndexChanged="DDL_PI_SelectedIndexChanged" Width="250px">
                                   </asp:DropDownList></td>
                               <td style="height: 33px">
                               </td>
                           </tr>
                           <tr>
                               <td  style="height: 33px" class="selecthead">
                                   &nbsp;&nbsp;<strong>Employee ID:</strong></td>
                               <td>
                               </td>
                               <td>
                                   <asp:TextBox ID="TextBox_EID" runat="server" Enabled="False" Width="150px" ReadOnly="True"></asp:TextBox></td>
                           </tr>
                           <tr>
                               <td  style="height: 33px" class="selecthead">
                                   &nbsp;&nbsp;<strong>Title Code:</strong></td>
                               <td>
                               </td>
                               <td>
                                   <asp:TextBox ID="TextBox_Title_Code" runat="server" Enabled="False" Width="150px" ReadOnly="True"></asp:TextBox></td>
                           </tr>
                           <tr>
                               <td style="height: 33px"  class="selecthead">
                                   &nbsp;&nbsp;<strong>Project:</strong></td>
                               <td style="height: 33px">
                               </td>
                               <td style="height: 33px;" >
                                   <asp:DropDownList ID="DDL_Project" runat="server" AppendDataBoundItems="True" AutoPostBack="True"
                                       DataSourceID="AD419DataProjectsByOrg2" DataTextField="Project" DataValueField="Accession"
                                       Enabled="False" OnSelectedIndexChanged="DDL_Project_SelectedIndexChanged" Width="250px">
                                       <asp:ListItem Value="0">-- Select Project --</asp:ListItem>
                                   </asp:DropDownList></td>
                           </tr>
                           <tr>
                               <td style="height: 33px"  class="selecthead">
                                   &nbsp;&nbsp;% <strong>Effort:</strong></td>
                               <td style="height: 33px">
                               </td>
                               <td style="height: 33px">
                                   <asp:TextBox ID="TextBox_PercentEffort" runat="server" Enabled="False" Width="150px"></asp:TextBox><asp:RequiredFieldValidator
                                       ID="reqValCEEffort" runat="server" ControlToValidate="TextBox_PercentEffort"
                                       ErrorMessage="% Effort Is A Required Field" ValidationGroup="CEEntry">*</asp:RequiredFieldValidator><asp:CompareValidator
                                           ID="compValCEEffortGreater" runat="server" ControlToValidate="TextBox_PercentEffort"
                                           ErrorMessage="%Effort Must Be A Number Between 10 And 100" Operator="GreaterThanEqual"
                                           Type="Double" ValidationGroup="CEEntry" ValueToCompare="10">*</asp:CompareValidator><asp:CompareValidator
                                               ID="comValCEEfforLess" runat="server" ControlToValidate="TextBox_PercentEffort"
                                               ErrorMessage="%Effort Must Be A Number Between 10 And 100" Operator="LessThanEqual"
                                               Type="Double" ValidationGroup="CEEntry" ValueToCompare="100">*</asp:CompareValidator></td>
                           </tr>
                       </tbody>
                   </table></div></td><td style="vertical-align:top;"><div class="xxxstyle" style="width:330px;"><table style="background-color:White; width:330px; text-align:center;" cellpadding="0" cellspacing="1">
                       <tr>
                           <td class="selecthead" style="height:33px;">
                                   <strong>
                                   Pay Rate:</strong></td>
                               <td class="selecthead" style="height:33px;">
                                   <strong>
                                    Full Time:</strong></td>
                       </tr>
                       <tr>
                           <td style="height: 33px">
                                   <asp:Label ID="lbl_PayRate" runat="server" Text="Label" Visible="False"></asp:Label>
                               </td>
                               <td style="height: 33px">
                                   <asp:Label ID="lbl_percentFullTime" runat="server" Text="Label" Visible="False"></asp:Label>
                               </td>
                       </tr>
                       <tr>
                               <td style="height: 33px; background-color:#DAE1E8;">
                                   <asp:Label ID="lbl_PIName" runat="server"></asp:Label></td>
                               <td style="width: 150px; height: 23px; background-color:#DAE1E8;">
                                   <asp:ObjectDataSource ID="AD419DataProjectsByOrg2" runat="server" OldValuesParameterFormatString="original_{0}"
                                       SelectMethod="getProjectsByDept" TypeName="CAESDO.AD419DataAccess">
                                       <SelectParameters>
                                           <asp:ControlParameter ControlID="DDL_Department" Name="OrgR" PropertyName="SelectedValue"
                                               Type="String" />
                                       </SelectParameters>
                                   </asp:ObjectDataSource>
                               </td>
                       </tr>
                       <tr>
                               <td style="height: 33px">
                                   <asp:Button ID="btn_SearchPI" runat="server" Enabled="False" OnClick="btn_SearchPI_Click"
                                       Text="Search PI" CausesValidation="False" /></td>
                               <td style="height: 33px">
                                   <asp:Button ID="Button_InsertCES" runat="server" OnClick="Button_InsertCES_Click"
                                       Text="Insert CES" ValidationGroup="CEEntry" /></td>
                       </tr>
                   </table></div></td></tr></table>
                   <br />
                   <br />
                   <asp:Panel ID="Panel_SearchPI" runat="server" Visible="False" Width="100%">
                       <asp:TextBox ID="Textbox_PISearch" runat="server"></asp:TextBox>
                       <asp:Button ID="btn_Search" runat="server" OnClick="btn_Search_Click" Text="Search" /><br />
                       <br /><div class="xxxstyle">
                       <asp:GridView ID="gv_PISearch" runat="server" AutoGenerateColumns="False" OnSelectedIndexChanged="gv_PISearch_SelectedIndexChanged" BackColor="White" CellPadding="4" CellSpacing="1" GridLines="None" Width="100%">
                           <Columns>
                               <asp:CommandField ButtonType="Image" ShowSelectButton="True" SelectImageUrl="~/images/select.gif" >
                                   <HeaderStyle CssClass="selecthead" Height="33px" />
                               </asp:CommandField>
                               <asp:BoundField DataField="Employee_ID" HeaderText="Employee ID" >
                                   <HeaderStyle CssClass="selecthead" Height="33px" />
                               </asp:BoundField>
                               <asp:BoundField DataField="EMP_NAME" HeaderText="Employee Name" >
                                   <HeaderStyle CssClass="selecthead" Height="33px" />
                               </asp:BoundField>
                               <asp:BoundField DataField="HOME_DEPT" HeaderText="Department" >
                                   <HeaderStyle CssClass="selecthead" Height="33px" />
                               </asp:BoundField>
                               <asp:BoundField DataField="Title_Code" HeaderText="Title Code" >
                                    <HeaderStyle CssClass="selecthead" Height="33px" />
                               </asp:BoundField>
                               <asp:BoundField DataField="Pay_Rate" HeaderText="Pay Rate" >
                                   <HeaderStyle CssClass="selecthead" Height="33px" />
                               </asp:BoundField>
                               <asp:BoundField DataField="PERCENT_FULLTIME" HeaderText="% Full-Time" >
                                   <HeaderStyle CssClass="selecthead" Height="33px" />
                               </asp:BoundField>
                           </Columns>
                           <RowStyle BackColor="#DAE1E8" />
                           <AlternatingRowStyle BackColor="White" />
                       </asp:GridView></div>
                   </asp:Panel>
                   <br />
                   Current PI Associations:
                   <div class="xxxstyle" style="width:500px;">
                   <asp:GridView ID="gViewCEAssociations" runat="server" AllowSorting="True" AutoGenerateColumns="False"
                       DataSourceID="AD419DataGetCEAssociations" BackColor="White" ForeColor="#333333" CellPadding="4" CellSpacing="1" GridLines="None" Width="100%">
                       <Columns>
                           <asp:BoundField DataField="AccountPIName" HeaderText="PI Name" SortExpression="AccountPIName">
                            <HeaderStyle CssClass="selecthead" Height="33px" />
                           </asp:BoundField>
                           <asp:BoundField DataField="Project" HeaderText="Project" SortExpression="Project">
                             <HeaderStyle CssClass="selecthead" Height="33px" />
                           </asp:BoundField>
                           <asp:BoundField DataField="PctEffort" HeaderText="%Effort" SortExpression="PctEffort">
                             <HeaderStyle CssClass="selecthead" Height="33px" />
                           </asp:BoundField>
                       </Columns>
                       <RowStyle BackColor="#DAE1E8" />
                        <AlternatingRowStyle BackColor="White" />
                   </asp:GridView>
                   </div>
                   <asp:ObjectDataSource ID="AD419DataGetCEAssociations" runat="server" SelectMethod="getCEAssociations"
                       TypeName="CAESDO.AD419DataAccess"></asp:ObjectDataSource>
                       
               </asp:Panel>
               <br />
    </td><td style="width:25px;"></td></tr>
    <tr style="background-color:#cfcfcf;"><td style="width:25px;"><img src="images/leftbot.gif" alt="" /></td><td></td><td style="width:25px;"><img src="images/rightbot.gif" alt="" /></td></tr></table><p>&nbsp;</p><p>&nbsp;</p><p>&nbsp;</p></div>
</asp:Content>

