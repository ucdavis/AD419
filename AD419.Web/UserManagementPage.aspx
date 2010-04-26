<%@ Page Title="AD-419 User Management" Language="C#" MasterPageFile="~/AD419.master" AutoEventWireup="true" CodeFile="UserManagementPage.aspx.cs" Inherits="UserManagementPage" %>

<asp:Content ID="Content1" ContentPlaceHolderID="ContentHeader" Runat="Server">
</asp:Content>
<asp:Content ID="Content2" ContentPlaceHolderID="ContentBody" Runat="Server">
    <div style="width: 70%; text-align:center;">
        <h1 id="page_title" ><asp:Label ID="lblPageTitle" runat="server" 
            Text="User Administration"></asp:Label></h1>
    </div>

    <div style="width: 100%; height: 500px" align="center">
        <iframe id="frame"  frameborder="0" 
            src='<%= ConfigurationManager.AppSettings["CatbertUserService"] %>' 
            scrolling="auto" name="frame" style="width:100%; height:100%;">
        </iframe> 
    </div>

</asp:Content>

