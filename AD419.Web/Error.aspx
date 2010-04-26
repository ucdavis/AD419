<%@ Page Language="C#" MasterPageFile="~/AD419.master" AutoEventWireup="true" CodeFile="Error.aspx.cs" Inherits="CAESDO.Error" Title="AD-419 Error Page" %>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentHeader" Runat="Server">
<table border="0" cellpadding="0" cellspacing="0" width="480">
    <tr style="background-color:#FFFFFF;"><td style="width:17px; height: 18px;"><img src="images/corn_lefttop.gif" alt="" /></td><td style="height: 18px"><img src="images/spaceholder.gif" alt="" /></td><td style="width:17px; height: 18px;"><img src="images/corn_righttop.gif" alt="" /></td></tr>
    <tr style="background-color:#ffffff;"><td style="width:17px; vertical-align:top;"></td>
    <td style="vertical-align:top;">
        AD-419 Error Page</td>
    <td style="width:17px;"></td></tr>
    <tr style="background-color:#ffffff;"><td style="width:17px;"><img src="images/corn_leftbot.gif" alt="" /></td><td></td><td style="width:17px;"><img src="images/corn_rightbot.gif" alt="" /></td></tr>
    </table></asp:Content>
<asp:Content ID="Content2" ContentPlaceHolderID="ContentBody" Runat="Server">
<table border="0" cellpadding="0" cellspacing="0" width="480">
    <tr style="background-color:#FFFFFF;"><td style="width:17px; height: 18px;"><img src="images/corn_lefttop.gif" alt="" /></td><td style="height: 18px"><img src="images/spaceholder.gif" alt="" /></td><td style="width:17px; height: 18px;"><img src="images/corn_righttop.gif" alt="" /></td></tr>
    <tr style="background-color:#ffffff;"><td style="width:17px; vertical-align:top;"></td>
    <td style="vertical-align:top;">
        <br />
        An Error Has Occured Of Type: <asp:Label ID="lblErrorType" runat="server"></asp:Label>
        <br />
        <br />
        Please try your request again.  If problems continue contact AppRequests@caes.ucdavis.edu for support.
        <br /><br />
        <asp:HyperLink id="hlinkHome" runat="server" NavigateUrl="~/Default.aspx">Go to the Homepage</asp:HyperLink>
     </td>
    <td style="width:17px;"></td></tr>
    <tr style="background-color:#ffffff;"><td style="width:17px;"><img src="images/corn_leftbot.gif" alt="" /></td><td></td><td style="width:17px;"><img src="images/corn_rightbot.gif" alt="" /></td></tr>
    </table></asp:Content>

