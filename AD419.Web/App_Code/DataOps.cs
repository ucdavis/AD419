using System;
using System.Data;
using System.Configuration;
using System.Collections;
using System.Collections.Specialized;
using System.Web;
using System.Web.Security;
using System.Web.UI;
using System.Web.UI.WebControls;
using System.Web.UI.WebControls.WebParts;
using System.Web.UI.HtmlControls;
using System.Data.SqlClient;

using Microsoft.Practices.EnterpriseLibrary.Data;
using System.Data.Common;

    /// <summary>
    /// 
    /// Current Version : 2.10.6.2006
    /// 
    /// Written By : Alan Lai
    ///              College Of Agricultural and Environmental Sciences Dean's Office, UC Davis
    /// Date : Februrary 10, 2006
    /// 
    /// Basic interface for Database accesses for all applications
    /// 
    /// Modifications :
    /// 
    ///     October 3, 2006 : - Upgrading to use transactions and Enterprise Library 2.0
    ///                       - Handles input/output variables and returns return values
    ///                       - Requires access to the following files :
    ///                             Microsoft.Practices.EnterpriseLibrary.Common.dll
    ///                             Microsoft.Practices.EnterpriseLibrary.Data.dll
    ///                             Microsoft.Practices.EnterpriseLibrary.ObjectBuilder.dll
    /// </summary>
    /// 
namespace CAESDO
{

    public class DataOps
    {
        protected string Connection_String;
        protected ArrayList Parameters;       // Stores Parameters in an ArrayList of ArrayList
        /*
         * Each entry in Parameters should be of the following format
         * [ sproc param name (@param2), value of param, sql data type, direction ]
         */
        protected int NumParameters;          // number of parameters
        protected string sproc;
        protected int commandTimeout;     // Change the default timeout on the sql command
        protected Boolean outputPresent;    // true if an output parameter is present in the current ParameterList

        protected ArrayList outputVariables;    // Contains the values of any output variables

        public DataOps()
        {
            this.Parameters = new ArrayList();
            this.outputVariables = new ArrayList();
            this.outputPresent = false;
            this.NumParameters = 0;

            this.Connection_String = "MainDB";
            this.commandTimeout = -1;            
        }

        /// <summary>
        /// Gets and Sets the stored procedure to be used.
        /// </summary>
        public string Sproc
        {
            get
            {
                return this.sproc;
            }
            set
            {
                this.sproc = value;
            }
        }

        /// <summary>
        /// Gets and Sets the value of the connection string.
        /// The value should be the name of the connection string in the Web.Config
        /// </summary>
        public string ConnectionString
        {
            get
            {
                return this.Connection_String;
            }
            set
            {
                this.Connection_String = value;
            }
        }

        /// <summary>
        /// Gets and Sets the time (in seconds) before the sql command will be terminated
        /// Values must be greater than 0 for the property to be set when executing sql
        /// </summary>
        public int SqlTimeout
        {
            get
            {
                return this.commandTimeout;
            }
            set
            {
                this.commandTimeout = value;
            }
        }

        #region Data Execute Functions
        
        /// <summary>
        /// Gets a DataSet
        /// </summary>
        /// <returns>Returns requested data in DataSet</returns>
        public DataSet get_dataset()
        {
            this.outputVariables.Clear();

            DataSet ds;
            Database db = DatabaseFactory.CreateDatabase(this.Connection_String);
            DbCommand command = db.GetStoredProcCommand(this.sproc);

            if (this.commandTimeout > 0)
                command.CommandTimeout = this.commandTimeout;

            ArrayList tempArray;

            if (NumParameters > 0)
                for (int i = 0; i < NumParameters; i++)
                {
                    tempArray = (ArrayList)Parameters[i];

                    // tempArray[0] --> Parameter name
                    // tempArray[1] --> Parameter value
                    // tempArray[2] --> DBType
                    // tempArray[3] --> Direction

                    if (tempArray[1] == null)
                    {
                        if (tempArray[3].ToString().ToLower().Contains("out"))
                            db.AddOutParameter(command, tempArray[0].ToString(), (DbType)tempArray[2], 32);
                        else if (tempArray[3].ToString().ToLower().Contains("return"))
                            db.AddParameter(command, "RETURN_VALUE", DbType.Int32, ParameterDirection.ReturnValue, String.Empty, DataRowVersion.Default, DBNull.Value);
                        else
                            db.AddInParameter(command, tempArray[0].ToString(), (DbType)tempArray[2], DBNull.Value);
                    }
                    else
                    {
                        if (tempArray[3].ToString().ToLower().Contains("out"))
                            db.AddOutParameter(command, tempArray[0].ToString(), (DbType)tempArray[2], 32);
                        else if (tempArray[3].ToString().ToLower().Contains("return"))
                            db.AddParameter(command, "RETURN_VALUE", DbType.Int32, ParameterDirection.ReturnValue, String.Empty, DataRowVersion.Default, DBNull.Value);
                        else
                            db.AddInParameter(command, tempArray[0].ToString(), (DbType)tempArray[2], tempArray[1].ToString());
                    }
                }

            ds = db.ExecuteDataSet(command);

            if (this.outputPresent)
            {

                ArrayList temp, temp2;
                string direction;

                for (int i = 0; i < this.Parameters.Count; i++)
                {
                    temp = (ArrayList)this.Parameters[i];
                    direction = temp[3].ToString();
                    direction = direction.ToLower();

                    if (direction.Contains("out") || direction.Contains("return"))
                    {
                        temp2 = new ArrayList();
                        temp2.Add(temp[0].ToString());
                        temp2.Add(db.GetParameterValue(command, temp[0].ToString()));

                        outputVariables.Add(temp2);
                    }
                }
            }

            return ds;
        }

        /// <summary>
        /// Gets an ArrayList
        /// </summary>
        /// <param name="fields">An ArrayList of column names you would like returned (Data will be returned in this order)</param>
        /// <returns>Arraylist 1d if only 1 parameter is passed in fields, otherwise a 2d arraylist where foreach entry data is in order of fields entered</returns>
        public ArrayList get_arrayList(ArrayList fields)
        {
            this.outputVariables.Clear();

            Database db = DatabaseFactory.CreateDatabase(this.Connection_String);
            DbCommand command = db.GetStoredProcCommand(this.sproc);

            if (this.commandTimeout > 0)
                command.CommandTimeout = this.commandTimeout;

            ArrayList tempArray = new ArrayList();
            if (NumParameters > 0)
                for (int i = 0; i < NumParameters; i++)
                {
                    tempArray = (ArrayList)Parameters[i];

                    // tempArray[0] --> Parameter name
                    // tempArray[1] --> Parameter value
                    // tempArray[2] --> DBType
                    // tempArray[3] --> Direction

                    if (tempArray[1] == null)
                    {
                        if (tempArray[3].ToString().ToLower().Contains("out"))
                            db.AddOutParameter(command, tempArray[0].ToString(), (DbType)tempArray[2], 32);
                        else if (tempArray[3].ToString().ToLower().Contains("return"))
                            db.AddParameter(command, "RETURN_VALUE", DbType.Int32, ParameterDirection.ReturnValue, String.Empty, DataRowVersion.Default, DBNull.Value);
                        else
                            db.AddInParameter(command, tempArray[0].ToString(), (DbType)tempArray[2], DBNull.Value);
                    }
                    else
                    {
                        if (tempArray[3].ToString().ToLower().Contains("out"))
                            db.AddOutParameter(command, tempArray[0].ToString(), (DbType)tempArray[2], 32);
                        else if (tempArray[3].ToString().ToLower().Contains("return"))
                            db.AddParameter(command, "RETURN_VALUE", DbType.Int32, ParameterDirection.ReturnValue, String.Empty, DataRowVersion.Default, DBNull.Value);
                        else
                            db.AddInParameter(command, tempArray[0].ToString(), (DbType)tempArray[2], tempArray[1].ToString());
                    }
                }

            ArrayList returnResults = new ArrayList();
            ArrayList temp = new ArrayList();

            if (fields.Count == 1)
            {
                using (IDataReader dr = db.ExecuteReader(command))
                {
                    while(dr.Read())
                    {
                        returnResults.Add(dr[fields[0].ToString()]);
                    }


                }
                
                if (this.outputPresent)
                    {
                        ArrayList temp2;
                        string direction;

                        for (int i = 0; i < this.Parameters.Count; i++)
                        {
                            temp = (ArrayList)this.Parameters[i];
                            direction = temp[3].ToString();
                            direction = direction.ToLower();

                            if (direction.Contains("out") || direction.Contains("return"))
                            {
                                temp2 = new ArrayList();
                                temp2.Add(temp[0].ToString());
                                temp2.Add(db.GetParameterValue(command, temp[0].ToString()));

                                outputVariables.Add(temp2);
                            }
                        }
                    }
            }
            else
            {
                using (IDataReader dr = db.ExecuteReader(command))
                {
                    while(dr.Read())
                    {
                        temp = new ArrayList();
                        for (int i = 0; i < fields.Count; i++)
                        {
                            temp.Add(dr[fields[i].ToString()]);
                        }
                        returnResults.Add(temp);
                    }


                }
                if (this.outputPresent)
                    {
                        ArrayList temp2;
                        string direction;

                        for (int i = 0; i < this.Parameters.Count; i++)
                        {
                            temp = (ArrayList)this.Parameters[i];
                            direction = temp[3].ToString();
                            direction = direction.ToLower();

                            if (direction.Contains("out") || direction.Contains("return"))
                            {
                                temp2 = new ArrayList();
                                temp2.Add(temp[0].ToString());
                                temp2.Add(db.GetParameterValue(command, temp[0].ToString()));

                                outputVariables.Add(temp2);
                            }
                        }
                    }
            }

            return returnResults;

            
        }

        /// <summary>
        /// Executes a sql statement without returning any data
        /// </summary>
        /// <returns>Returns true if the sql executed properly.</returns>
        public Boolean Execute_Sql()
        {
            this.outputVariables.Clear();

            Database db = DatabaseFactory.CreateDatabase(this.Connection_String);

            DbCommand command = db.GetStoredProcCommand(this.sproc);

            if (this.commandTimeout > 0)
                command.CommandTimeout = this.commandTimeout;

            ArrayList tempArray;

            if (NumParameters > 0)
                for (int i = 0; i < NumParameters; i++)
                {
                    tempArray = (ArrayList)Parameters[i];

                    // tempArray[0] --> Parameter name
                    // tempArray[1] --> Parameter value
                    // tempArray[2] --> DBType
                    // tempArray[3] --> Direction

                    if (tempArray[1] == null)
                    {
                        if (tempArray[3].ToString().ToLower().Contains("out"))
                            db.AddOutParameter(command, tempArray[0].ToString(), (DbType)tempArray[2], 32);
                        else if (tempArray[3].ToString().ToLower().Contains("return"))
                            db.AddParameter(command, "RETURN_VALUE", DbType.Int32, ParameterDirection.ReturnValue, String.Empty, DataRowVersion.Default, DBNull.Value);
                        else
                            db.AddInParameter(command, tempArray[0].ToString(), (DbType)tempArray[2], DBNull.Value);
                    }
                    else
                    {
                        if (tempArray[3].ToString().ToLower().Contains("out"))
                            db.AddOutParameter(command, tempArray[0].ToString(), (DbType)tempArray[2], 32);
                        else if (tempArray[3].ToString().ToLower().Contains("return"))
                            db.AddParameter(command, "RETURN_VALUE", DbType.Int32, ParameterDirection.ReturnValue, String.Empty, DataRowVersion.Default, DBNull.Value);
                        else
                            db.AddInParameter(command, tempArray[0].ToString(), (DbType)tempArray[2], tempArray[1].ToString());
                    }
                }

            using (DbConnection connection = db.CreateConnection())
            {
                connection.Open();
                DbTransaction transaction = connection.BeginTransaction();

                try
                {
                    db.ExecuteNonQuery(command, transaction);

                    transaction.Commit();

                    // Grabs the values of output variables
                    if (this.outputPresent)
                    {
                        ArrayList temp = new ArrayList();
                        ArrayList temp2;
                        string direction;

                        for (int i = 0; i < this.Parameters.Count; i++)
                        {
                            temp = (ArrayList)this.Parameters[i];
                            direction = temp[3].ToString();
                            direction = direction.ToLower();

                            if (direction.Contains("out") || direction.Contains("return"))
                            {
                                temp2 = new ArrayList();
                                temp2.Add(temp[0].ToString());
                                temp2.Add(db.GetParameterValue(command, temp[0].ToString()));
                                
                                outputVariables.Add(temp2);
                            }
                        }
                    }
                }
                catch
                {
                    transaction.Rollback();
                    connection.Close();

                    throw;

                    //return false;
                }
                finally
                {
                    connection.Close();
                }
            }

            return true;

        }

        /// <summary>
        /// Gets a string dictionary
        /// </summary>
        /// <param name="idField">Name of the column to be the Key field</param>
        /// <param name="valueField">Name of the column to be the Value field</param>
        /// <returns>StringDictionary</returns>
        public StringDictionary get_dictionary(string idField, string valueField)
        {
            this.outputVariables.Clear();

            StringDictionary returnDictionary = new StringDictionary();

            Database db = DatabaseFactory.CreateDatabase(this.Connection_String);
            DbCommand command = db.GetStoredProcCommand(this.sproc);

            if (this.commandTimeout > 0)
                command.CommandTimeout = this.commandTimeout;

            ArrayList tempArray = new ArrayList();
            if (NumParameters > 0)
                for (int i = 0; i < NumParameters; i++)
                {
                    tempArray = (ArrayList)Parameters[i];

                    // tempArray[0] --> Parameter name
                    // tempArray[1] --> Parameter value
                    // tempArray[2] --> DBType
                    // tempArray[3] --> Direction

                    if (tempArray[1] == null)
                        db.AddInParameter(command, tempArray[0].ToString(), (DbType)tempArray[2], DBNull.Value);
                    else
                        db.AddInParameter(command, tempArray[0].ToString(), (DbType)tempArray[2], tempArray[1].ToString());
                }


            using (IDataReader dr = db.ExecuteReader(command))
            {
                while (dr.Read())
                {
                    returnDictionary.Add(dr[idField].ToString(), dr[valueField].ToString());
                }
            }

            if (this.outputPresent)
            {
                ArrayList temp, temp2;
                string direction;                

                for (int i = 0; i < this.Parameters.Count; i++)
                {
                    temp = (ArrayList)this.Parameters[i];
                    direction = temp[3].ToString();
                    direction = direction.ToLower();

                    if (direction.Contains("out") || direction.Contains("return"))
                    {
                        temp2 = new ArrayList();
                        temp2.Add(temp[0].ToString());
                        temp2.Add(db.GetParameterValue(command, temp[0].ToString()));

                        outputVariables.Add(temp2);
                    }
                }
            }

            return returnDictionary;
        }

        /// <summary>
        /// Executes a sql statement without returning any data
        /// </summary>
        /// <param name="outputVariables">ArrayList that will return a 2d ArrayList where parameter 0 in each sub array is the parameter name and 1 is the value</param>
        /// <returns>Returns true if the sql executed properly</returns>
        public Boolean Execute_Sql(out ArrayList outputVariables)
        {
            Boolean flag = this.Execute_Sql();

            outputVariables = this.outputVariables;
            return flag;
        }

        /// <summary>
        /// Gets an ArrayList
        /// </summary>
        /// <param name="Fields">An ArrayList of column names you would like returned (Data will be returned in this order)</param>
        /// <param name="outputVariables">ArrayList that will return a 2d ArrayList where parameter 0 in each sub array is the parameter name and 1 is the value</param>
        /// <returns>Arraylist 1d if only 1 parameter is passed in fields, otherwise a 2d arraylist where foreach entry data is in order of fields entered</returns>
        public ArrayList get_arrayList(ArrayList Fields, out ArrayList outputVariables)
        {
            ArrayList returnArray;
            returnArray = this.get_arrayList(Fields);

            outputVariables = this.outputVariables;
            return returnArray;
        }

        /// <summary>
        /// Gets a DataSet
        /// </summary>
        /// <param name="outputVariables">ArrayList that will return a 2d ArrayList where parameter 0 in each sub array is the parameter name and 1 is the value</param>
        /// <returns>Returns requested data in DataSet</returns>
        public DataSet get_dataset(out ArrayList outputVariables)
        {
            DataSet ds = this.get_dataset();
            outputVariables = this.outputVariables;

            return ds;
        }
                        
        #endregion

        #region Parameter Modding functions
        
        // used for adding parameter when value is an int
        public void SetParameter(string ParamName, int value, string direction)
        {
            ArrayList tempArray = new ArrayList();

            tempArray.Add(ParamName);
            tempArray.Add(value);
            tempArray.Add(DbType.Int32);
            if (direction.ToLower().Contains("out"))
            {
                tempArray.Add(ParameterDirection.Output);
                this.outputPresent = true;
            }
            else if (direction.ToLower().Contains("return"))
            {
                tempArray.Add(ParameterDirection.ReturnValue);
                this.outputPresent = true;
            }
            else
                tempArray.Add(ParameterDirection.Input);

            this.Parameters.Add(tempArray);
            this.NumParameters++;
        }

        // used for adding parameter when value is a string
        public void SetParameter(string ParamName, string value, string direction)
        {
            ArrayList tempArray = new ArrayList();

            tempArray.Add(ParamName);
            tempArray.Add(value);
            tempArray.Add(DbType.String);
            if (direction.ToLower().Contains("out"))
            {
                tempArray.Add(ParameterDirection.Output);
                this.outputPresent = true;
            }
            else if (direction.ToLower().Contains("return"))
            {
                tempArray.Add(ParameterDirection.ReturnValue);
                this.outputPresent = true;
            }
            else
                tempArray.Add(ParameterDirection.Input);

            this.Parameters.Add(tempArray);
            this.NumParameters++;
        }

        public void SetParameter(string ParamName, double value, string direction)
        {
            ArrayList tempArray = new ArrayList();

            tempArray.Add(ParamName);
            tempArray.Add(value);
            tempArray.Add(DbType.Double);
            if (direction.ToLower().Contains("out"))
            {
                tempArray.Add(ParameterDirection.Output);
                this.outputPresent = true;
            }
            else if (direction.ToLower().Contains("return"))
            {
                tempArray.Add(ParameterDirection.ReturnValue);
                this.outputPresent = true;
            }
            else
                tempArray.Add(ParameterDirection.Input);

            this.Parameters.Add(tempArray);
            this.NumParameters++;
        }

        public void SetParameter(string ParamName, bool value, string direction)
        {
            ArrayList tempArray = new ArrayList();

            tempArray.Add(ParamName);
            tempArray.Add(value);
            tempArray.Add(DbType.Boolean);
            if (direction.ToLower().Contains("out"))
            {
                tempArray.Add(ParameterDirection.Output);
                this.outputPresent = true;
            }
            else if (direction.ToLower().Contains("return"))
            {
                tempArray.Add(ParameterDirection.ReturnValue);
                this.outputPresent = true;
            }
            else
                tempArray.Add(ParameterDirection.Input);

            this.Parameters.Add(tempArray);
            this.NumParameters++;
        }

        public void SetParameter(string ParamName, DateTime value, string direction)
        {
            ArrayList tempArray = new ArrayList();

            tempArray.Add(ParamName);
            tempArray.Add(value);
            tempArray.Add(DbType.DateTime);
            if (direction.ToLower().Contains("out"))
            {
                tempArray.Add(ParameterDirection.Output);
                this.outputPresent = true;
            }
            else if (direction.ToLower().Contains("return"))
            {
                tempArray.Add(ParameterDirection.ReturnValue);
                this.outputPresent = true;
            }
            else
                tempArray.Add(ParameterDirection.Input);

            this.Parameters.Add(tempArray);
            this.NumParameters++;
        }

        public void SetParameter(string ParamName, float value, string direction)
        {
            ArrayList tempArray = new ArrayList();

            tempArray.Add(ParamName);
            tempArray.Add(value);
            tempArray.Add(DbType.Single);
            if (direction.ToLower().Contains("out"))
            {
                tempArray.Add(ParameterDirection.Output);
                this.outputPresent = true;
            }
            else if (direction.ToLower().Contains("return"))
            {
                tempArray.Add(ParameterDirection.ReturnValue);
                this.outputPresent = true;
            }
            else
                tempArray.Add(ParameterDirection.Input);

            this.Parameters.Add(tempArray);
            this.NumParameters++;
        }

        // used to change value of a parameter after it has been set
        public void ChangeParameter(string ParamName, int value)
        {
            int elements = this.Parameters.Count;
            //int index;

            for (int i = 0; i < elements; i++)
            {
                if (((ArrayList)this.Parameters[i])[0].ToString() == ParamName)
                {
                    ((ArrayList)this.Parameters[i])[1] = value;
                    break;
                }
            }


            //this.NumParameters++;
        }

        // used to change value of parameter after it has been set
        public void ChangeParameter(string ParamName, string value)
        {
            int elements = this.Parameters.Count;
            //int index;

            for (int i = 0; i < elements; i++)
            {
                if (((ArrayList)this.Parameters[i])[0].ToString() == ParamName)
                {
                    ((ArrayList)this.Parameters[i])[1] = value;
                    break;
                }
            }
        }

        // used to change value of parameter after it has been set
        public void ChangeParameter(string ParamName, float value)
        {
            int elements = this.Parameters.Count;
            //int index;

            for (int i = 0; i < elements; i++)
            {
                if (((ArrayList)this.Parameters[i])[0].ToString() == ParamName)
                {
                    ((ArrayList)this.Parameters[i])[1] = value;
                    break;
                }
            }


        }
        public void ChangeParameter(string ParamName, double value)
        {
            int elements = this.Parameters.Count;
            //int index;

            for (int i = 0; i < elements; i++)
            {
                if (((ArrayList)this.Parameters[i])[0].ToString() == ParamName)
                {
                    ((ArrayList)this.Parameters[i])[1] = value;
                    break;
                }
            }


            //this.NumParameters++;
        }

        // used to check if parameter has already been created, so no duplicates are added
        public bool ParamExist(string ParamName)
        {
            int elements = this.Parameters.Count;
            for (int i = 0; i < elements; i++)
            {
                if (((ArrayList)this.Parameters[i])[0].ToString() == ParamName)
                    return true;    // parameter found
            }
            return false;       // parameter not found
        }

        // clears all current parameters
        public void ClearParams()
        {
            this.Parameters.Clear();
            NumParameters = 0;
            this.outputPresent = false;
            this.outputVariables.Clear();
        }

        // clears values of the parameters, but leaves everything else valid
        public void ClearParamsValues()
        {
            int elements = this.Parameters.Count;
            for (int i = 0; i < elements; i++)
            {
                ((ArrayList)this.Parameters[i])[1] = null;
            }
        }

        public void ResetDops()
        {
            this.ClearParams();

            this.sproc = null;
            this.commandTimeout = -1;
        }
        #endregion

        /// <summary>
        /// Provides the return value from the stored procedure for specified parameters.
        /// </summary>
        /// <param name="parameterName">Name of parameter as output value.  For return values use RETURN_VALUE</param>
        /// <returns></returns>
        public object GetOutputVariable(string parameterName)
        {
            ArrayList temp;

            for (int i = 0; i < this.outputVariables.Count; i++)
            {
                temp = (ArrayList)this.outputVariables[i];

                if (temp[0].ToString() == parameterName)
                    return temp[1];
            }

            return null;
        }

    }
}