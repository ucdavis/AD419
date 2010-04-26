using System;
using System.Security.Principal;
using System.Collections;

namespace CAESDO
{
    /// <summary>
    /// Instantiates a custom Principal which stores values
    /// from Authentication database into an ArrayList
    /// and has additional useful methods.
    /// See public accessors for specifics
    /// 
    /// </summary>
    public class CAESDOPrincipal : IPrincipal
    {
        private IIdentity _identity;
        //private ArrayList _userdata = new ArrayList();

        private string _FirstName;
        private string _LastName;
        private string _Email;
        private string _EmployeeID;
        private string _LoginID;

        private ArrayList _Departments;
            /* Stored as a 2d arraylist where the structure is as follows
             *             
             *  {
             *      [ [ShortName] [PPS_Code] [FIS_Code] ]
             *      [ [ShortName] [PPS_Code] [FIS_Code] ]
             *      [ [ShortName] [PPS_Code] [FIS_Code] ]
             *  }
            */

        //public CAESDOPrincipal(IIdentity Identity, ArrayList UserData)
        //{
        //    // Deep copy constructor for ArrayList with ArrayLists
        //    // Elements 0-4 are strings, 5 and 6 are ArrayLists
        //    _identity = Identity;
        //    //			foreach (string s in UserData)
        //    //			{
        //    //				_userdata.Add(s);
        //    //			}
        //        //for (int i = 0; i < 7; i++)
        //        //{
        //        //    _userdata.Add(UserData[i]);
        //        //}
        //    //			for (int i = 5; i < 7; i++)
        //    //			{
        //    //				_userdata.Add(UserData[i] as ArrayList);
        //    //			}

        //}

        public CAESDOPrincipal(IIdentity Identity, string FirstName, string LastName, string Email, string EmployeeID, string LoginID, ArrayList Departments)
        {
            _identity = Identity;
            _FirstName = FirstName;
            _LastName = LastName;
            _Email = Email;
            _EmployeeID = EmployeeID;
            _LoginID = LoginID;
            _Departments = Departments;
        }

        public CAESDOPrincipal(IIdentity Identity)
        {
            _identity = Identity;
            //_userdata = null;
            _FirstName = null;
            _LastName = null;
            _Email = null;
            _EmployeeID = null;
        }

        #region IPrincipal Members
        public IIdentity Identity
        {
            get
            {
                return _identity;
            }
        }

        public bool IsInRole(string role)
        {
                //			if (_userdata.Contains(role) )
                //				return true;
                //			return false;
            //if ((_userdata[5] as ArrayList).Contains(role))
            //    return true;
            //return false;

            return false;
        }

        public string LoginID
        {
            get
            {
                //return _userdata[0].ToString();
                return this._LoginID;
            }
        }

        public string FirstName
        {
            get
            {
                //return _userdata[1].ToString();
                return this._FirstName;
            }
        }

        public string LastName
        {
            get
            {
                //return _userdata[2].ToString();
                return this._LastName;
            }
        }

        public string EmployeeID
        {
            get
            {
                //return _userdata[3].ToString();
                return this._EmployeeID;
            }
        }

        public string Email
        {
            get
            {
                //return _userdata[4].ToString();
                return this._Email;
            }
        }

        //public ArrayList Roles
        //{
        //    get
        //    {
        //        return _userdata[5] as ArrayList;
        //    }
        //}

        public ArrayList Departments
        {
            get
            {
                return _Departments as ArrayList;
            }
        }


        #endregion
    }

}