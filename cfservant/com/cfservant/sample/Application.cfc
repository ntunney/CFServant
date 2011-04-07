<cfcomponent displayname="Application" output="false">
	
	<cfscript>
		this.name = 'cfServantDemo';
		
		// orm setup
		this.ormenabled = true;
		this.datasource = 'myDSN';
		this.ormSettings.logSQL = true;
		this.ormSettings.flushAtRequestEnd = false;
	</cfscript>
	
	<cffunction name="onApplicationStart" returnType="boolean" output="false">
		
		<cfscript>
			ORMReload();

			//application constants
			application.dsn = this.ormSettings.datasource;
			
			// CFServant configuration
			import blogexamples.gen.com.cfservant.*;
			application.cfservant = new CFServant('/blogexamples/gen/config/cfservant.xml');
			
			return true;
		</cfscript>
		
	</cffunction>

	<!--- Run before the request is processed --->
	<cffunction name="onRequestStart" returnType="boolean" output="false">
		<cfargument name="thePage" type="string" required="true">
		
		<cfscript>
			if ( structKeyExists(url, 'flush') ) {
				onApplicationStart();
				onSessionStart();
			}
		</cfscript>
		
		<cfreturn true>
	</cffunction>

	<!--- Runs on error --->
	<cffunction name="onError" returnType="any" output="false">
		<cfargument name="exception" required="true">
		<cfargument name="eventname" type="string" required="true">
		
		<cfscript>
			// override the behavior if we are hitting the ServiceProxy this will act like our onMissingMethod() for remote calls - thanks Ben Nadel --->
			if ( findNoCase('GenServiceProxy.cfc', cgi.script_name) AND structKeyExists( arguments.exception, "func" ) ) {
				// grab the variables regardless if it as a GET or POST
				var args = {};
				structAppend(args, duplicate(url));
				structAppend(args, duplicate(form)); // form takes precedence
				application.cfservant.methodProxy(args, cgi.request_method);
			} else {
				// EDIT HERE if you have your own error handling strategy
				writeDump(arguments);
				abort;
			}
		</cfscript>
		
	</cffunction>

</cfcomponent>