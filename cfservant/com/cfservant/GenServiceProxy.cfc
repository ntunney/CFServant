component {
	
	public any function requestHandler (Struct data, String methodType) {
		
		// break apart the requested method
		try {
			var method = data.method;
		} catch (any e) {
			throw('No method specified.');
		}
		
		// we don't have to check if the requested method exists - if it did, this method would never have been called
		// get method
		if ( reFindNoCase('^get', method) ) {
			var methodName = 'get';
			var objectName = right(method, len(method)-3);
		} else if ( reFindNoCase('^save', method) ) { // save method
			var methodName = 'save';
			var objectName = right(method, len(method)-4);
		} else if ( reFindNoCase('^delete', method) ) { // delete method
			var methodName = 'delete';
			var objectName = right(method, len(method)-6);
		} else if ( reFindNoCase('^list', method) ) { // list method (returns query)
			var methodName = 'list';
			var objectName = right(method, len(method)-4);
		} else {
			throw("I don't know how to process the method you requested.  Try one of delete/get/save/list{object}.");
		}
		
		// writeDump(objectName);writeDump(methodName);abort;
		
		// we have a bunch of generic service objects in our bag of tricks - lets see if see have one for the object they requested
		// get a ptr to the single service storage struct
		var services = application.cfservant.getServices();
		if ( !len(objectName) || !structKeyExists(services, objectName) ) {
			// if we are doing a get or list we might have a plural - we might need to try to trim the s, es or ies
			if ( reFindNoCase('s$', objectName) ) { // end in 's', 'es' or 'ies'
				if ( structKeyExists(services, left(objectName, len(objectName)-3)&'y') ) { // 'ies'
					objectName = left(objectName, len(objectName)-3&'y');
				} else if ( structKeyExists(services, left(objectName, len(objectName)-2)) ) { // 'es'
					objectName = left(objectName, len(objectName)-2);
				} else if ( structKeyExists(services, left(objectName, len(objectName)-1)) ) { // 's'
					objectName = left(objectName, len(objectName)-1);
				} else {
					throw("There is no generic service for #objectName#.  Please check your configuration.");
				}
			}
		}
		
		// process according to the method we found
		switch (methodName) {
			case 'get':
				// if we have an id, get the object (won't be plural)
				if ( structKeyExists(arguments.data, 'id') && len(arguments.data.id) ) {
					return services[objectName].get(arguments.data.id);
				} else {  
					return services[objectName].get();
				}
			break;
			
			case 'save':
				// for save we need to try to load the object and then overwrite values as necessary, or create a new one and store the values
				// do we have an id specified
				if ( structKeyExists(arguments.data, 'id') && len(arguments.data.id) ) {
					var o = entityLoadByPK(objectName, arguments.data.id);
				}
				
				if ( isNull(o) ) {
					var o = entityNew(objectName);
				}
				
				// loop over the data and set anything that exists in the object
				var key = '';
				for ( key in arguments.data ) {
					o = parseProperty(o, key, arguments.data[key]);
				}
				
				return services[objectName].put(o);
			break;
			
			case 'delete':
				// the rule is to send an argument called id if we are calling delete, otherwise, throw an error
				if ( structKeyExists(arguments.data, 'id') && len(arguments.data.id) ) {
					try{
					var o = entityLoadByPK(objectName, arguments.data.id);
					} catch (Any e) {
						throw('No object found with the id ' & arguments.data.id);
					}
					return services[objectName].delete(o);
				} else {
					throw("You must send an id along with the DELETE request.");
				}
			break;
			
			case 'list':
				return services[objectName].list();
			break;
		}
	}
	
	private function parseProperty (object, propertyName, data) {
		// we might have some composite objects here - do a JSON decode here just in case
		var tmpValue = ( !isJSON(arguments.data) ) ? arguments.data : deserializeJSON(arguments.data);
		var o = object;
		
		// SIMPLE VALUE
		if ( isSimpleValue(tmpValue) && (structKeyExists(o, 'set#propertyName#') && !structKeyExists(o, 'has#propertyName#')) ) { // we check hasXXX here to make sure it isn't an composite object id
			// don't allow a blank id to be set, all other values blanks are ok
			if ( len(tmpValue) || lcase(propertyName) != 'id' ) {
				evaluate("o.set#propertyName#(tmpValue)");
			}
			
		// COMPOSITE COLLECTION
		// we check for multiple spellings of the plural here (-s, -es, -ies)
		} else if ( isArray(tmpValue) && (structKeyExists(o, 'add#propertyName#') || structKeyExists(o, "add#left(propertyName, len(propertyName)-3)&'y'#") || structKeyExists(o, "add#left(propertyName, len(propertyName)-2)#") || structKeyExists(o, "add#left(propertyName, len(propertyName)-1)#")) ) { // composite collection
			//first determine the proper object name
			if ( structKeyExists(o, 'add#propertyName#') ) {
			 var compositeObjectName = key;
			} else if ( structKeyExists(o, "add#left(propertyName, len(propertyName)-3)&'y'#") ) { // ies
				var compositeObjectName = left(propertyName, len(key)-3) & 'y';
			} else if ( structKeyExists(o, "add#left(propertyName, len(propertyName)-2)#") ) { // es
				var compositeObjectName = left(propertyName, len(propertyName)-2);
			} else if ( structKeyExists(o, "add#left(propertyName, len(propertyName)-1)#") ) { // s
				var compositeObjectName = left(propertyName, len(propertyName)-1);
			}
			
			// lets use the service for the composite object
			var compService = application.cfservant.getService(compositeObjectName);
			
			// we will have an array here, so lets parse it
			for ( var i=1;i<=arrayLen(tmpValue);i++ ) { // array of objects
				// try to load up an existing object, otherwise it returns a new object with the specified key
				var oComp = compService.load(tmpValue[i].id);
				
				// now, set any values sent along with this bugger
				var subkey = '';
				
				for ( subkey in tmpValue[i] ) {
					// now recurse to parse the values for this guy
					parseProperty(oComp, subKey, tmpValue[i][subKey]); // passed by reference so no need to set here
				}
				
				// save the composite
				compService.put(oComp);
				
				// add this mofo to the parent object if it doesn't already exist
				if ( oComp.getID() == -1 ) {
					evaluate("o.add#compositeObjectName#(oComp)");
				}
				
			}
			
		// COMPOSITE OBJECT
		} else if ( structKeyExists(o, 'has#propertyName#') ) { // composite object
			// for right now we are only handling setting by id - these are not created at this time - the idea is to read it in and set it - there is no bidi relationship being set here either
			// we dont try to get the generic service for this object, as I imagine most of these will be lookups, and have no service
			
			// lets use the service for the composite object
			// lets first check to see if they specified a classname - we use this to permit the user to rename properties as they see fit
			if ( structKeyExists(tmpValue, 'className') ) {
				var oComp = entityLoadByPK(tmpValue.className, tmpValue.id);
				var compService = application.cfservant.getService(tmpValue.className);
			} else {
				var oComp = entityLoadByPK(propertyName, tmpValue.id);
				var compService = application.cfservant.getService(propertyName);
			}
			
			// create a new object if an object wasnt found
			if ( isNull(oComp) ) {
				// throw("Could not find an object of type '#propertyName#' with the id #tmpValue.id#.");
				var oComp = compService.load();
			}
			
			// set any properties supplied with the object
			for ( key in tmpValue ) {
				// now recurse to parse the values for this guy
				parseProperty(oComp, key, tmpValue[key]); // passed by reference so no need to set here
			}
			
			compService.put(oComp);
							
			// set bi-directional relationship, if necessary
			// derive parent object name
			var objectName = listGetAt(getMetaData(o).name, listLen(getMetaData(o).name, '.'), '.');
			if ( structKeyExists(oComp, 'set#objectName#') ) {
				evaluate("oComp.set#objectName#(o)");
			}
			
			// add it to the parent object
			evaluate("o.set#propertyName#(oComp)");
			
		} else {
			// do nothing, these are properties in the data that dont exist (could be things like returnFormat, method, etc)
			/* writeOutput('<br/>None: ');
			// writeDump(getMetaData(o));
			writeDump(propertyName);
			writeDump(tmpValue); */
		}
		
		return o;
	}
	
}