<cfcomponent accessors="true">
	
	<cfproperty type="Struct" name="services" />
	<cfproperty type="String" name="configPath" />
	<cfproperty type="Boolean" name="useReturnStructure" />
	<cfproperty type="String" name="serviceProxyName" />
	
	<cfscript>
		public function init (String configPath) {
			// empty services and initialize
			setServices(structNew());
			// read in and process the configuration
			parseConfig(arguments.configPath);
		}
		
		public GenService function getService(String ormBean) {
			var s = getServices();
			if ( !structKeyExists(s, arguments.ormBean) ) {
				throw("No bean configured with the name '#arguments.ormBean#'.");
			}
			
			return services[arguments.ormBean];
		}
		
		private void function parseConfig(configPath) {
			var path = getDirectoryFromPath(configPath);
			// try variable as is
			if ( !fileExists(arguments.configPath) ) {
				// try expanding the path
				if ( fileExists(expandPath(arguments.configPath)) ) {
					arguments.configPath = expandPath(arguments.configPath);
				} else {
					throw("Can't find configuration file '#arguments.configPath#'.");
				}
			}
			
			// read the file
			var xmlText = fileRead(arguments.configPath);
			var xml = xmlParse(xmlText);
			
			// first, save off the config data
			// should we package the result in a cfservant native return structure
			if ( structKeyExists(xml.cfservant.config, 'returnFormatting') && lcase(xml.cfservant.config.returnFormatting.xmlText) == 'true' ) {
				setUseReturnStructure(true);
			} else {
				setUseReturnStructure(false);
			}
			// are we overriding the default GenServiceProxy.cfc
			if ( structKeyExists(xml.cfservant.config, 'genproxy-override') && len(xml.cfservant.config['genproxy-override'].xmlText) ) {
				setServiceProxyName(xml.cfservant.config['genproxy-override'].xmlText);
			} else {
				setServiceProxyName('GenServiceProxy.cfc');
			}
			
			// now lets create the service beans
			// shortcut ptr
			var serviceNodes = xml.cfservant.services.xmlChildren;
			for ( var i=1;i<=arrayLen(serviceNodes);i++ ) {
				// create the object
				variables.services[serviceNodes[i].xmlAttributes.ormBean] = evaluate("new #serviceNodes[i].xmlAttributes.class#()");
				// TODO: might want to insert a check to see if this is extending GenService, but for now there might be good applications to not requiring it
				// inject the DAO, if one is specified
				if ( structKeyExists(serviceNodes[i], 'dao') ) {
					variables.services[serviceNodes[i].xmlAttributes.ormBean].setDAO(evaluate("new #serviceNodes[i].dao.xmlAttributes.class#()"));
				}
			}
			
			// writeDump(variables);
			// abort;
		}
	</cfscript>
	
	<cffunction name="methodProxy" returnType="void" output="false">
		<cfargument name="args" type="struct" required="true">
		<cfargument name="requestMethod" type="string" required="false" default="">
		
		<cfscript>
			// call the generic method handler in the service proxy
				var proxy = new GenServiceProxy();
				var ret = proxy.requestHandler(args, cgi.request_method);
				if ( !structKeyExists(arguments.args, 'returnFormat') || !listContainsNoCase('json,plain,wddx', arguments.args.returnFormat) ) {
					arguments.args.returnFormat = 'json';
				}
				
				var output = '';
		</cfscript>
		
		<cfif lcase(arguments.args.returnFormat) EQ 'json'>
			<cfset output = serializeJSON(ret) />
		<!--- don't wddx XML values --->
		<cfelseif lcase(arguments.args.returnFormat) EQ 'wddx' AND !isXML(ret)>
			<cfwddx action="cfml2wddx" input="#ret#" output="output" />
		<cfelseif !isXML(ret)>
			<cfset output = toString(ret)/>
		<cfelse>
			<cfset output = ret />
		</cfif>
		
		<cfheader statuscode="200" statustext="OK" />
		<cfcontent type="text/plain" variable="#ToBinary( ToBase64( output ) )#" />
		
	</cffunction>
	
</cfcomponent>