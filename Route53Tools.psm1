function Add-Route53Tools()
{
	$code = @"

	using System;
	using System.IO;
	using System.Net;
	using System.Security.Cryptography;
	using System.Text;
	using System.Xml;
	using System.Xml.Linq;

	namespace Route53Helper
	{
	    public class Route53Client
	    {
	        // Private WebRequest instance
	        WebRequest _apiRequest;

	        // Define API Urls
	        public static string ApiVersion = "2011-05-05";
	        public static string BaseUri = "https://route53.amazonaws.com";
	        public static string Route53XmlNameSpace = BaseUri + "/doc/" + ApiVersion + "/";

	        public HttpWebResponse CreateHostedZone(string domainName, string comment)
	        {
	            // Create web request client
	            var url = BaseUri + "/" + ApiVersion + "/hostedzone";
	            var callerReference = Guid.NewGuid().ToString();
	            _apiRequest = WebRequest.Create(url);
	            AddAuthorizationHeaders();

	            // Create Request Route53Messages
	            var route53Message = Route53Messages.CreateHostedZone(domainName, callerReference, comment);

	            // Make Request 
	            return DoPostRequest(route53Message);
	        }


	        public HttpWebResponse ListHostedZones()
	        {
	            // Create web request client
	            var url = BaseUri + "/" + ApiVersion + "/hostedzone";
	            _apiRequest = WebRequest.Create(url);
	            AddAuthorizationHeaders();

	            return DoWebRequest("GET");
	        }

	        public HttpWebResponse DeleteHostedZone(string hostedZoneId)
	        {
	            // Create web request client
	            var url = BaseUri + "/" + ApiVersion + "/hostedzone/" + hostedZoneId;
	            _apiRequest = WebRequest.Create(url);
	            AddAuthorizationHeaders();

	            return DoWebRequest("DELETE");
	        }
			
	        public HttpWebResponse GetHostedZone(string hostedZoneId)
	        {
	            // Create web request client
	            var url = BaseUri + "/" + ApiVersion + "/hostedzone/" + hostedZoneId;
	            _apiRequest = WebRequest.Create(url);
	            AddAuthorizationHeaders();

	            return DoWebRequest("GET");
	        }


	        public HttpWebResponse ChangeResourceRecordSets(string hostedZoneId, string comment, string action, string name, string type, string ttl, string value)
	        {

	            // Create web request client
	            var url = BaseUri + "/" + ApiVersion + "/hostedzone/" + hostedZoneId + "/rrset";
	            _apiRequest = WebRequest.Create(url);
	            AddAuthorizationHeaders();

	            // Create Request Route53Messages
	            var message = Route53Messages.ChangeResourceRecordSets(action, comment, name, type, ttl, value);

	            // Make Request 
	            return DoPostRequest(message);

	        }

	        public HttpWebResponse ListResourceRecordSets(string hostedZoneId)
	        {

	            // Create web request client
	            var url = BaseUri + "/" + ApiVersion + "/hostedzone/" + hostedZoneId + "/rrset";
	            _apiRequest = WebRequest.Create(url);
	            AddAuthorizationHeaders();

	            // Make Request 
	            return DoWebRequest("GET");

	        }

	        void AddAuthorizationHeaders()
	        {
	            // Add Authorization Headers to request
	            var amazonAuthHeader = String.Format(
	                "AWS3-HTTPS AWSAccessKeyId={0},Algorithm=HmacSHA1,Signature={1}",
	                Authentication.AwsAccessKeyId,
	                Authentication.AwsAuthSignature
	            );
	            _apiRequest.Headers.Add("X-Amzn-Authorization", amazonAuthHeader);
	            _apiRequest.Headers.Add("x-amz-date", Authentication.TimeStampRfc822());
	        }

	        HttpWebResponse DoPostRequest(string postData)
	        {
	            // Add AWS Authorization Headers
	            _apiRequest.Method = "POST";

	            // Add POST data
	            var byteArray = Encoding.UTF8.GetBytes(postData);
	            _apiRequest.ContentLength = byteArray.Length;
	            var dataStream = _apiRequest.GetRequestStream();
	            dataStream.Write(byteArray, 0, byteArray.Length);
	            dataStream.Close();

	            // Make Request and Return Response
	            return GetApiResponse();

	        }

	        HttpWebResponse DoWebRequest(string method)
	        {
	            // Add AWS Authorization Headers
	            _apiRequest.Method = method;

	            return GetApiResponse();
	        }

	        HttpWebResponse GetApiResponse()
	        {
	            // Make Request and Return Response
	            try {
	                return (HttpWebResponse)_apiRequest.GetResponse();
	            }
	            catch (WebException webException) {
	                return (HttpWebResponse)webException.Response;
	            }
	        }

	        public static XmlDocument GetResponseContentXml(HttpWebResponse response)
	        {
	            var stream = response.GetResponseStream();
	            if (stream == null) return null;

	            var httpContent = new StreamReader(stream).ReadToEnd();
	            return new XmlDocument { InnerXml = httpContent };
	        }
	    }
	    public class Authentication
	    {

	        // Properties AWS Access Keys
	        public static string AwsAccessKeyId { get; set; }
	        public static string AwsSecretAccessKey { get; set; }

	        // AWS Auth Signature based on Time Stamp
	        public static string AwsAuthSignature
	        {
	            get
	            {
	                var authSignature = GenerateAwsAuthSignature(TimeStampRfc822(), AwsSecretAccessKey);
	                return authSignature;
	            }
	        }

	        // Func to create Time stamp based on RFC 822
	        public static Func<string> TimeStampRfc822 = () => DateTime.Now.ToUniversalTime().ToString("ddd, dd MMM yyyy HH':'mm':'ss 'GMT'");

	        public static string GenerateAwsAuthSignature(string message, string key)
	        {
	            var encoding = new ASCIIEncoding();

	            // Create an HMAC  object using the given key
	            var myhash = new HMACSHA1(encoding.GetBytes(key), false);

	            // Compute the hash for the given message
	            var hashmessage = myhash.ComputeHash(encoding.GetBytes(message));

	            // Convert message to string and return
	            return Convert.ToBase64String(hashmessage);
	        }
	    }

	    public class Route53Messages
	    {


	        private static readonly XmlDocument XmlDoc = new XmlDocument();
	        

	        public static string CreateHostedZone(string domainName, string callerReference, string comment)
	        {
	            
	            var xmlns = (XNamespace) Route53Client.Route53XmlNameSpace;

	            var message =   new XElement(xmlns + "CreateHostedZoneRequest",
	                                       new XElement(xmlns + "Name", domainName),
	                                       new XElement(xmlns + "CallerReference", callerReference),
	                                       new XElement(xmlns + "HostedZoneConfig",
	                                                    new XElement(xmlns + "Comment", comment)
	                                       )
	                            );

	            return message.ToString();
	        }


	        public static string ChangeResourceRecordSets(string action, string comment, string name, string type, string ttl, string value)
	        {
	            var xmlns = (XNamespace) Route53Client.Route53XmlNameSpace;

	            var message =   new XElement(xmlns + "ChangeResourceRecordSetsRequest",
	                                new XElement(xmlns + "ChangeBatch",
	                                    new XElement(xmlns + "Comment",comment),
	                                    new XElement(xmlns + "Changes",
	                                        new XElement(xmlns + "Change",
	                                            new XElement(xmlns + "Action", action),
	                                            new XElement(xmlns + "ResourceRecordSet",
	                                                new XElement(xmlns + "Name", name),
	                                                new XElement(xmlns + "Type", type),
	                                                new XElement(xmlns + "TTL", ttl),
	                                                new XElement(xmlns + "ResourceRecords",
	                                                    new XElement(xmlns + "ResourceRecord",
	                                                        new XElement(xmlns + "Value", value)
	                                                    )
	                                                )
	                                            )
	                                       )
	                                   )
	                                )
	                          ); 

	            return message.ToString();
	        }
	    }
	}

"@;
	Add-Type -TypeDefinition $code -ReferencedAssemblies System.Xml, System.Xml.Linq  -Language CSharpVersion3
}

function New-Zone()
{
	Param(
		[parameter(Mandatory=$true)] [string] $domainName,
		[parameter(Mandatory=$true)] [string] $comment
	)
	
	$route53Client = New-Object Route53Helper.Route53Client
	$httpResponse = $route53Client.CreateHostedZone("cloudoman.com","testing")
	$httpContent = [Route53Helper.Route53Client]::GetResponseContentXml($httpResponse)

	$httpContent.CreateHostedZoneResponse.HostedZone | fl *
}

function Show-HostedZones()
{
	$route53Client = New-Object Route53Helper.Route53Client
	$httpResponse = $route53Client.ListHostedZones()
	$httpContent = [Route53Helper.Route53Client]::GetResponseContentXml($httpResponse)
	
	$httpContent.ListHostedZonesResponse.HostedZones.HostedZone

	Show-Errors -httpResponse $httpContent
	
}

function Remove-HostedZone()
{
	Param(
		[parameter(Mandatory=$true)] [string] $hostedZoneId
	)
	
	$route53Client = New-Object Route53Helper.Route53Client
	$httpResponse = $route53Client.DeleteHostedZone($hostedZoneId)
	$httpContent = [Route53Helper.Route53Client]::GetResponseContentXml($httpResponse)
	
	$httpContent.DeleteHostedZoneResponse.ChangeInfo

	Show-Errors -httpResponse $httpContent
	
}


function Show-ResourceRecords()
{
	Param(
		[parameter(Mandatory=$true)] [string] $hostedZoneId
	)
	
	$route53Client = New-Object Route53Helper.Route53Client
	$httpResponse = $route53Client.ListResourceRecordSets($hostedZoneId)
	$httpContent = [Route53Helper.Route53Client]::GetResponseContentXml($httpResponse)
	
	$httpContent.ListResourceRecordSetsResponse.ResourceRecordSets.ResourceRecordSet | fl *
	
	Show-Errors -httpResponse $httpContent

}

function Show-Errors()
{
	Param(
		[parameter(Mandatory=$true)] [System.Xml.XmlDocument] $httpResponse
	)
	
	if ($httpResponse.ErrorResponse.Error -ne $null)
	{
		#Write-Error "Error:"
		$httpContent.ErrorResponse.Error | fl
	}
}

function New-ARecord()
{
	Param(
		[parameter(Mandatory=$true)] [string] $domainName,
		[parameter(Mandatory=$true)] [string] $type,
		[parameter(Mandatory=$true)] [string] $ttl,
		[parameter(Mandatory=$true)] [string] $value,
		[parameter(Mandatory=$true)] [string] $hostedZoneId,
		[parameter(Mandatory=$true)] [string] $comment
	)
	
	$route53Client = New-Object Route53Helper.Route53Client
	$httpResponse = $route53Client.ChangeResourceRecordSets($hostedZoneId, $comment, "CREATE", $domainName, $type, $ttl, $value)
	$httpContent = [Route53Helper.Route53Client]::GetResponseContentXml($httpResponse)
	
	$httpContent.ChangeResourceRecordSetsResponse.ChangeInfo | fl *
	
	Show-Errors -httpResponse $httpContent
	
}

function Remove-ARecord()
{
	Param(
		[parameter(Mandatory=$true)] [string] $domainName,
		[parameter(Mandatory=$true)] [string] $type,
		[parameter(Mandatory=$true)] [string] $ttl,
		[parameter(Mandatory=$true)] [string] $value,
		[parameter(Mandatory=$true)] [string] $hostedZoneId,
		[parameter(Mandatory=$true)] [string] $comment
	)
	
	$route53Client = New-Object Route53Helper.Route53Client
	$httpResponse = $route53Client.ChangeResourceRecordSets($hostedZoneId, $comment, "DELETE", $domainName, $type, $ttl, $value)
	$httpContent = [Route53Helper.Route53Client]::GetResponseContentXml($httpResponse)
	
	$httpContent.ChangeResourceRecordSetsResponse.ChangeInfo | fl *
	
	Show-Errors -httpResponse $httpContent
	
}

# --------------------------------------
# Main
# --------------------------------------

Add-Route53Tools