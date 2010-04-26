using System;
using System.Data;
using System.Configuration;
using System.Web;
using System.Web.Security;
using System.Web.UI;
using System.Web.UI.WebControls;
using System.Web.UI.WebControls.WebParts;
using System.Web.UI.HtmlControls;
// added
using System.Security.Principal;
using System.Data.SqlClient;
using System.Collections;
using System.Collections.Specialized;
using System.Threading;
using System.Web.SessionState;
using System.Web.Caching;


namespace CAESDO
{
    /// <summary>
    /// All pages in the application except Login.aspx will derive from ApplicationPage.
    /// </summary>
    public class ApplicationPage : System.Web.UI.Page
    {
        // Used on ALL pages to access the user's session state
        //protected UserSession userSession;

        // Principal to hold user data
        protected CAESDOPrincipal p;// = new CAESDOPrincipal(HttpContext.Current.User.Identity); //= (CAESDOPrincipal)HttpContext.Current.User;

        // Database variables
        // check internal Database caesUserAdminDB = DatabaseFactory.CreateDatabase("Authentication");//eligibilityDB
        internal DataSet ds = new DataSet();
        //internal IDataReader reader;
        // check internal DBCommandWrapper dbCommandWrapper;
        //internal DBCommandWrapper dbCommandWrapper2;

        protected DataOps dops = new DataOps();

        public ApplicationPage()
        {
        }

        #region Events

        protected override void OnPreInit(EventArgs e)
        {
            //Don't cache the credentials if we don't have a user authenticated
            if ( HttpContext.Current.User.Identity.IsAuthenticated == false )
                return;

            if (Cache.Get(HttpContext.Current.User.Identity.Name) == null)
            {
                // Get the user information and put into CAESDOPrincipal
                DataOps dops = new DataOps();
                dops.ResetDops();
                dops.ConnectionString = "CATBERT";
                dops.Sproc = "usp_getUserByLogin";
                dops.SetParameter("@LoginID", HttpContext.Current.User.Identity.Name, "input");

                ArrayList fields = new ArrayList();
                fields.Add("FirstName");
                fields.Add("LastName");
                fields.Add("EmployeeID");
                fields.Add("Email");

                ArrayList results = dops.get_arrayList(fields);

                //Only continue if the user has at least one result from the information lookup
                if (results.Count == 0)
                    return;

                results = (ArrayList)results[0];

                // Get the user's departments
                dops.ResetDops();
                dops.Sproc = "usp_GetUserUnits";
                dops.SetParameter("@EmployeeID", results[2].ToString(), "input");

                fields.Clear();
                fields.Add("ShortName");
                fields.Add("PPS_Code");
                fields.Add("FIS_Code");

                // 2d arraylist that contains departments
                //  subarrays are [[ShortName] [PPS_Code] [FIS_Code]]
                ArrayList results2 = dops.get_arrayList(fields);

                IIdentity objectIdentity = new GenericIdentity(HttpContext.Current.User.Identity.Name);
                //objectContext.User = new CAESDOPrincipal(objectIdentity, userData);
                //HttpContext.Current.User = new CAESDOPrincipal(objectIdentity, results[0].ToString(), results[1].ToString(), results[3].ToString(), results[2].ToString(), userID);

                //Cache.Insert(HttpContext.Current.User.Identity.Name, new CAESDOPrincipal(objectIdentity, results[0].ToString(), results[1].ToString(), results[3].ToString(), results[2].ToString(), HttpContext.Current.User.Identity.Name), null, Cache.NoAbsoluteExpiration, System.TimeSpan.FromMinutes(15));

                Cache.Insert(HttpContext.Current.User.Identity.Name, new CAESDOPrincipal(objectIdentity, results[0].ToString(), results[1].ToString(), results[3].ToString(), results[2].ToString(), HttpContext.Current.User.Identity.Name, results2), null, Cache.NoAbsoluteExpiration, System.TimeSpan.FromMinutes(15));

                this.p = (CAESDOPrincipal)Cache.Get(HttpContext.Current.User.Identity.Name);
            }
            else
                this.p = (CAESDOPrincipal)Cache.Get(HttpContext.Current.User.Identity.Name);

            base.OnPreInit(e);
        }

        /// <summary>
        /// Automatically invoked before the page is displayed
        /// </summary>
        /// <param name="e">Event Arguments</param>
        protected override void OnLoad(EventArgs e)
        {
            // Instantiate a new UserSession object
            //userSession = new UserSession(this.Session);
            base.OnLoad(e);
        }

        /// <summary>
        /// Hack to stop the Validation of Viewstate MAC error.  Basically when an HTTPException
        /// is caught, the page is reloaded (not reposted), starting a new viewstate session that is clean
        /// </summary>
        /// <remarks>This means that other HTTPExceptions that are not Viewstate MAC errors are also caught</remarks>
        protected override void OnError(EventArgs e)
        {
            //Grab the page context
            HttpContext ctx = HttpContext.Current;

            //Grab the exception that raised this error
            Exception ex = ctx.Server.GetLastError();

            //Only handle HttpException Errors
            if (ex.GetType().Name == "HttpException")
            {
                //StringBuilder errorInfo = new StringBuilder();
                //errorInfo.Append("Offending URL: " + ctx.Request.Url.ToString());
                //errorInfo.Append("<br>Source: " + ex.Source);
                //errorInfo.Append("<br>Type: " + ex.GetType().Name);
                //errorInfo.Append("<br>Message: " + ex.Message);
                //errorInfo.Append("<br>Stack Trace: " + ex.StackTrace);

                //ctx.Response.Write(errorInfo.ToString());

                //Clear the error and redirect to the page the raised this error (getting a fresh copy)
                ctx.Server.ClearError();
                ctx.Response.Redirect(AD419Configuration.ErrorPage(AD419Configuration.ErrorType.SESSION));
            }
            else
            {
                //TODO: Add error reporting back in
                /* 
                if ( ex.InnerException != null )
                    AD419ErrorReporting.ReportError(ex.InnerException, "OnError");
                else
                    AD419ErrorReporting.ReportError(ex, "OnError");
                 */
                ctx.Server.ClearError();
                ctx.Response.Redirect(AD419Configuration.ErrorPage(AD419Configuration.ErrorType.UNKNOWN));
            }

            base.OnError(e);
        }


        #endregion



    }

}