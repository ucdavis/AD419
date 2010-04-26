using System;
using System.Data;
using System.Configuration;
using System.Web;
using System.Web.Security;
using System.Web.UI;
using System.Web.UI.WebControls;
using System.Web.UI.WebControls.WebParts;
using System.Web.UI.HtmlControls;
using System.Web.Compilation;
using System.CodeDom;

namespace CAESDO
{
    /// <summary>
    /// CodeExpressionBuilder written to easily evaluate code inline in the application.
    /// Use in the code like: <asp:literal id="lit1" runat="server" text='<%$ Code: Expression %>' />
    /// where Expression is pretty much any C# expression that you want to use.
    /// </summary>
    /// <remarks>This includes compound code like <%$ Code: "Welcome " + p.FirstName + " " + p.LastName %> and more</remarks>
    /// <see cref="http://weblogs.asp.net/infinitiesloop/archive/2006/08/09/The-CodeExpressionBuilder.aspx"/>
    [ExpressionPrefix("Code")]
    public class CodeExpressionBuilder : ExpressionBuilder
    {
        public override CodeExpression GetCodeExpression(BoundPropertyEntry entry, object parsedData, ExpressionBuilderContext context)
        {
            return new CodeSnippetExpression(entry.Expression);
        }
    }

}