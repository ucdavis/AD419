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

namespace CAESDO
{
    public partial class _Default : ApplicationPage
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            if (p == null)
            {
                FormsAuthentication.SignOut();
                Response.Redirect(AD419Configuration.ErrorPage(AD419Configuration.ErrorType.AUTH));
            }
            else
            {
                lblUserName.Text = "Welcome, " + p.FirstName + " " + p.LastName;
            }

            if (User.IsInRole("Admin") == false)
            {
                hlinkEmulation.Visible = false;
                hlinkReportAdministration.Visible = false;
            }

            if (User.IsInRole("ManageAll") == false)
            {
               hLinkUserAdministration.Visible = false;
            }

            hlinkInstructions.Attributes.Add("href", ConfigurationManager.AppSettings["Ad419InstructionServer"]);
        }

        protected void lbtnResetUser_Click(object sender, EventArgs e)
        {
            FormsAuthentication.SignOut();
            Response.Redirect(Request.Url.AbsolutePath);
            //Response.Redirect(FormsAuthentication.LoginUrl);
        }
} 
}
