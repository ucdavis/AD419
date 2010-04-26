<%@ Page Language="C#" MasterPageFile="~/AD419.master" AutoEventWireup="true" CodeFile="Default.aspx.cs" Inherits="CAESDO._Default" Title="AD-419" %>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentHeader" Runat="Server">

</asp:Content>
<asp:Content ID="Content2" ContentPlaceHolderID="ContentBody" Runat="Server">
    <br />
    <div style="background-image: url(images/indextop.gif); width:380px; height:45px; margin-left: 2em;"><br />
    <span style="margin-left:2em; margin-right:1em;"><asp:Label ID="lblUserName" runat="server" ForeColor="White"></asp:Label>
    <asp:LinkButton ID="lbtnResetUser" runat="server" OnClick="lbtnResetUser_Click">[Reset User]</asp:LinkButton></span></div>
    <div style="background-image: url(images/indexrepeat.gif); background-repeat:repeat-x; background-color: #dadada; width: 380px; margin-left: 2em;"><br />
    <div style="margin-left:2em; margin-right:1em;" class="indexlinks">
    <asp:HyperLink ID="hlinkReportAdministration" runat="server" NavigateUrl="~/ReportAdministration.aspx">Report Administration<br /><br /></asp:HyperLink>
    
    <asp:HyperLink ID="hlinkReportingModule" runat="server" NavigateUrl="~/reportingModule.aspx">Reporting Module</asp:HyperLink>
    <br /><br />
    <asp:HyperLink ID="hlinkInstructions" runat="server" NavigateUrl="~/AD419Instructions.pdf" Target="_blank">Instructions (PDF)</asp:HyperLink>
    <br /><br />
    <asp:HyperLink ID="hlinkEmulation" runat="server" NavigateUrl="~/Emulation.aspx">Emulation<br /><br /></asp:HyperLink>
    
    <asp:HyperLink ID="hLinkUserAdministration" runat="server" NavigateUrl="~/UserManagementPage.aspx">User Administration<br /><br /></asp:HyperLink>
    </div></div>
    <img src="images/indexbot.gif" alt="" style="margin-left: 2em;"/> 
</asp:Content>

