using System;
using System.Data;
using System.Configuration;
using System.Web;
using System.Web.Security;
using System.Web.UI;
using System.Web.UI.WebControls;
using System.Web.UI.WebControls.WebParts;
using System.Web.UI.HtmlControls;
using System.Collections;

using System.Security.Principal;
using System.Web.Caching;
using System.IO;
using System.Net;

namespace CAESDO
{
    public partial class login : System.Web.UI.Page
    {
        private const string STR_ReturnURL = "ReturnURL";
        private const string STR_CAS_URL = "https://cas.ucdavis.edu:8443/cas/";
        private const string STR_KERBEROS_URL = "https://secureweb.ucdavis.edu/form-auth/sendback?";
        private const string STR_Ticket = "ticket";

        protected void Page_Load(object sender, EventArgs e)
        {
            CASLogin();
        }

        #region CAS
        /// <summary>
        /// Login to the campus DistAuth system using CAS        
        /// </summary>
        private void CASLogin()
        {
            string loginUrl = STR_CAS_URL;

            // get the context from the source
            HttpContext context = HttpContext.Current;

            // try to load a valid ticket
            HttpCookie validCookie = context.Request.Cookies[FormsAuthentication.FormsCookieName];
            FormsAuthenticationTicket validTicket = null;

            // check to make sure cookie is valid by trying to decrypt it
            if (validCookie != null)
            {
                try
                {
                    validTicket = FormsAuthentication.Decrypt(validCookie.Value);
                }
                catch
                {
                    validTicket = null;
                }
            }

            // if user is unauthorized and no validTicket is defined then authenticate with cas
            //if (context.Response.StatusCode == 0x191 && (validTicket == null || validTicket.Expired))
            if (validTicket == null || validTicket.Expired)
            {
                // build query string but strip out ticket if it is defined
                string query = "";

                foreach (string key in context.Request.QueryString.AllKeys)
                {
                    if (String.Compare(key, STR_Ticket, true) != 0)
                    {
                        if (query.Contains(key) == false)
                            query += "&" + key + "=" + context.Request.QueryString[key];
                    }
                }

                // replace 1st character with ? if query is not empty
                if (!String.IsNullOrEmpty(query))
                {
                    query = "?" + query.Substring(1);
                }

                // get ticket & service
                string ticket = context.Request.QueryString[STR_Ticket];
                string service = context.Server.UrlEncode(context.Request.Url.GetLeftPart(UriPartial.Path) + query);

                // if ticket is defined then we assume they are coming from CAS
                if (!String.IsNullOrEmpty(ticket))
                {
                    // validate ticket against cas
                    StreamReader sr = new StreamReader(new WebClient().OpenRead(loginUrl + "validate?ticket=" + ticket + "&service=" + service));

                    // parse text file
                    if (sr.ReadLine() == "yes")
                    {
                        // get kerberos id
                        string kerberos = sr.ReadLine();

                        // set forms authentication ticket
                        FormsAuthentication.SetAuthCookie(kerberos, false);

                        string returnURL = string.Empty;

                        if (!string.IsNullOrEmpty(query))
                        {
                            //need to grab the return url from the query string: ?ReturnURL=/...                        
                            returnURL = query.Substring(query.IndexOf("=") + 1); //So get everything after the first equals sign
                        }

                        if (returnURL == null)
                            returnURL = FormsAuthentication.DefaultUrl;

                        context.Response.Redirect(returnURL);

                        return;
                    }
                }

                // ticket doesn't exist or is invalid so redirect user to CAS login
                context.Response.Redirect(loginUrl + "login?service=" + service);
            }
        }
        #endregion

        private void KerberosAuth()
        {
            HttpCookie authCookie = System.Web.HttpContext.Current.Request.Cookies["AuthUser"];

            if (authCookie == null)
                Response.Redirect("https://secureweb.ucdavis.edu/form-auth/sendback?" + Request.Url, true);

            //Check to see if the user is already authenticated.  
            //If so, then if there is a return url they are not authorized
            if (User.Identity.IsAuthenticated)
                if (Request.QueryString["ReturnURL"] != null)
                {
                    Response.Redirect(AD419Configuration.ErrorPage(AD419Configuration.ErrorType.AUTH));
                    return;
                }

            string userID;
            string afsHash;
            string distAuthHash;

            ParseDistAuthCookie(authCookie, out userID, out afsHash, out distAuthHash);

            if (VerifyDistAuthCookie(distAuthHash))
            {
                //then we are ok
                //Make sure that the user has at least one role in the application
                if (Roles.GetRolesForUser(userID).Length > 0)
                {
                    FormsAuthentication.Initialize();
                    //Create a new ticket for authentication

                    FormsAuthenticationTicket ticket = new FormsAuthenticationTicket(
                        1, //version
                        userID, //Username
                        DateTime.Now, //time issued
                        DateTime.Now.AddMinutes(10), //10 minutes to expire in
                        false, //non persistent ticket
                        String.Empty,
                        FormsAuthentication.FormsCookiePath);

                    //Hash the cookie for transport
                    string hash = FormsAuthentication.Encrypt(ticket);
                    HttpCookie cookie = new HttpCookie(FormsAuthentication.FormsCookieName, hash); //hashed ticket in cookie

                    //Now add the auth cookie
                    Response.Cookies.Add(cookie);

                    string returnURL = Request.QueryString["ReturnURL"];

                    if (returnURL == null)
                        returnURL = FormsAuthentication.DefaultUrl;

                    Response.Redirect(returnURL);

                }
            }

            Response.Redirect(AD419Configuration.ErrorPage(AD419Configuration.ErrorType.AUTH));

        }

        /// <summary>
        /// Checks the authorization database to see if user is authorized for access
        /// </summary>
        /// <param name="requestUserID">The userID to check in the authorization database</param>
        /// <param name="requestUserData">An array, modified by the method,
        ///  which stores values found during authorization lookup</param>
        /// <returns>Boolean value for whether authorization succeeded, plus modifies requestUserData</returns>
        private bool Authorize(string requestUserID, out ArrayList requestUserData)
        {
            ArrayList credentials = new ArrayList();
            ArrayList rolesList = new ArrayList();
            ArrayList deptList = new ArrayList();
            bool records = false;

            string ConnectionStringKey = ((CAESDORoleProvider)Roles.Provider).ConnectionString;

            // Grab the User's Information
            DataOps dops1 = new DataOps();
            dops1.Sproc = "usp_LookupProfileByLoginID";
            dops1.ConnectionString = System.Configuration.ConfigurationManager.ConnectionStrings[ConnectionStringKey].ToString();

            dops1.SetParameter("@kerbID", requestUserID, "input");

            ArrayList fields1 = new ArrayList();
            fields1.Add("LoginID");
            fields1.Add("FirstName");
            fields1.Add("LastName");
            fields1.Add("EmployeeID");
            fields1.Add("Email");


            // Grab the User's Roles
            DataOps dops2 = new DataOps();
            dops2.Sproc = "usp_LookupRoleByLoginID";
            dops2.ConnectionString = System.Configuration.ConfigurationManager.ConnectionStrings[ConnectionStringKey].ToString();
            dops2.SetParameter("@kerbID", requestUserID, "input");

            ArrayList fields2 = new ArrayList();
            fields2.Add("RoleName");


            // Grab the User's Department
            DataOps dops3 = new DataOps();
            dops3.Sproc = "usp_LookupDeptByLoginID";
            dops3.ConnectionString = System.Configuration.ConfigurationManager.ConnectionStrings[ConnectionStringKey].ToString();
            dops3.SetParameter("@kerbID", requestUserID, "input");

            ArrayList fields3 = new ArrayList();
            fields3.Add("DepartmentID");

            // Execution of searches
            ArrayList temp = dops1.get_arrayList(fields1);
            // Build the Initial credentials array
            foreach (String s in (ArrayList)temp[0])
            {
                credentials.Add(s);
            }
            // Get an array list of all the roles
            rolesList = dops2.get_arrayList(fields2);
            // Get an array list of all the departments
            deptList = dops3.get_arrayList(fields3);

            // Checks the validity of the lists to ensure that
            // proper credentials were pulled
            if ((credentials.Count == 0) || (rolesList.Count == 0) || (deptList.Count == 0))
                records = false;
            else
                records = true;

            credentials.Add(rolesList);
            credentials.Add(deptList);

            requestUserData = credentials;
            return records;
        }

        /// <summary>
        /// Parses the DistAuth cookie into user, AFS Hash, and IP Hash
        /// </summary>
        /// <param name="suppliedDistAuthCookie">The cookie obtained from the DistAuth server</param>
        /// <param name="suppliedUserName">An out reference to the User name variable</param>
        /// <param name="suppliedAfsHash">An out reference to the AFS hash variable</param>
        /// <param name="suppliedDistAuthHash">An out reference to the DistAuth hash variable</param>
        private void ParseDistAuthCookie(HttpCookie suppliedDistAuthCookie,
            out string suppliedUserName,
            out string suppliedAfsHash,
            out string suppliedDistAuthHash)
        {
            string authUserValue = suppliedDistAuthCookie.Value;
            string[] authUserValueTokens = authUserValue.Split(new char[1] { '-' });
            suppliedUserName = authUserValueTokens[0];
            suppliedAfsHash = authUserValueTokens[1];
            suppliedDistAuthHash = authUserValueTokens[2];
        }

        /// <summary>
        /// Verifies the clients IP address matches the hashed IP address in DistAuth
        /// Prevents copying the cookie and using from another machine 
        /// </summary>
        /// <param name="ipHash">The DistAuth cookie's IP Address hash</param>
        /// <returns>True if verified, false otherwise</returns>
        private bool VerifyDistAuthCookie(string ipHash)
        {
            if (IpHash(System.Web.HttpContext.Current.Request.UserHostAddress) == ipHash)
                return true;
            return false;
        }

        /// <summary>
        /// Hashes an IP address using DistAuth's algoritm
        /// </summary>
        /// <param name="suppliedIPAddress">The clien'ts IP address</param>
        /// <returns>The hexadecimal string hash of the client's IP address</returns>
        private string IpHash(string suppliedIPAddress)
        {
            char[] ipArray = suppliedIPAddress.ToCharArray();
            ulong checksum;
            ulong ltmp;
            int i;

            // Hash base
            for (i = 0, checksum = 1; i < ipArray.Length / 2; i++)
            {
                checksum = (checksum & 0x00ffffff) * ipArray[i];
            }

            // Hash power
            for (ltmp = 1; i < ipArray.Length; i++)
            {
                ltmp = (ltmp & 0x00ffffff) * ipArray[i];
            }

            checksum = checksum ^ ltmp;

            // Convert checksum to uppercase hexadecimal string
            return checksum.ToString("X");
        }
    }
}