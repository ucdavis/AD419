<%@ Page Language="C#" MasterPageFile="~/AD419.master" AutoEventWireup="true" CodeFile="Emulation.aspx.cs" Inherits="CAESDO.Emulation" Title="Emulation Page" %>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentHeader" Runat="Server">
</asp:Content>
<asp:Content ID="Content2" ContentPlaceHolderID="ContentBody" Runat="Server">
<br /><br /><table cellpadding="0" cellspacing="0" border="0" style="background-color:White; margin-left:1.5em; margin-right:1.5em"><tr><td><img src="images/corn_lefttop.gif" alt="" /></td><td></td><td><img src="images/corn_righttop.gif" alt="" /></td></tr>
    <tr><td></td><td>
    Emulate:
    <asp:DropDownList ID="dlistUsers" runat="server">
        <asp:ListItem Value="postit">Scott Kirkland</asp:ListItem>
        <asp:ListItem Value="anlai">Alan Lai</asp:ListItem>
        <asp:ListItem Value="vqhtran">Viet Tran</asp:ListItem>
        <asp:ListItem Value="grosa">Gabe Rosa</asp:ListItem>
    </asp:DropDownList><br />
    <br />
    <asp:Button ID="btnEmulate" runat="server" OnClick="btnEmulate_Click" Text="Emulate" /></td><td></td></tr>
    <tr><td><img src="images/corn_leftbot.gif" alt="" /></td><td></td><td><img src="images/corn_rightbot.gif" alt="" /></td></tr></table>
</asp:Content>

