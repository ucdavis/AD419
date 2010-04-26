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
using System.Web.Configuration;

public partial class AD419 : System.Web.UI.MasterPage
{
    protected void Page_Load(object sender, EventArgs e)
    {
        string AssemblyVersion = System.Reflection.Assembly.GetExecutingAssembly().GetName().Version.ToString();
        
        litAssemblyVersion.Text = AssemblyVersion;

        hlinkEmail.NavigateUrl = "mailto:" + WebConfigurationManager.AppSettings["AppMailTo"] + "?subject=[" + WebConfigurationManager.AppSettings["AppName"] + "] " + AssemblyVersion + " <your question or comment>";
    }
}
