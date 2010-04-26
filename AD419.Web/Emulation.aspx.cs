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
    public partial class Emulation : ApplicationPage
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            string[] temp = Roles.GetRolesForUser();
            if (!Roles.IsUserInRole("Admin"))
                Response.Redirect(FormsAuthentication.DefaultUrl);

            if (Page.IsPostBack == false)
            {
                System.Collections.Generic.List<string> allUsers = new System.Collections.Generic.List<string>();
                foreach (string role in Roles.GetAllRoles())
                {
                    foreach (string user in Roles.GetUsersInRole(role))
                    {
                        if (allUsers.Contains(user) == false)
                            allUsers.Add(user);
                    }
                }

                dlistUsers.DataSource = allUsers.ToArray();
                dlistUsers.DataBind();
            }

        }
        protected void btnEmulate_Click(object sender, EventArgs e)
        {
            FormsAuthentication.SignOut();

            FormsAuthentication.Initialize();

            FormsAuthenticationTicket ticket = new FormsAuthenticationTicket(1,
                dlistUsers.SelectedValue,
                DateTime.Now,
                DateTime.Now.AddMinutes(15),
                false,
                String.Empty,
                FormsAuthentication.FormsCookiePath);

            string hash = FormsAuthentication.Encrypt(ticket);
            HttpCookie cookie = new HttpCookie(FormsAuthentication.FormsCookieName, hash);

            Response.Cookies.Add(cookie);

            Response.Redirect(FormsAuthentication.DefaultUrl);
        }
} 
}
