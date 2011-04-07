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
					// simple property
					// we might have some composite objects here - do a JSON decode here just in case
					var tmpValue = ( !isJSON(arguments.data[key]) ) ? arguments.data[key] : deserializeJSON(arguments.data[key]);
					if ( isSimpleValue(tmpValue) && (structKeyExists(o, 'set#key#') && !structKeyExists(o, 'has#key#')) ) { // we check hasXXX here to make sure it isn't an composite object id
						// don't allow a blank id to be set, all other values blanks are ok
						if ( len(tmpValue) || lcase(key) != 'id' ) {
							evaluate("o.set#key#(tmpValue)");
						}
					} else if ( isArray(tmpValue) && (structKeyExists(o, 'add#key#') || structKeyExists(o, "add#left(key, len(key)-3)&'y'#") || structKeyExists(o, "add#left(key, len(key)-2)#") || structKeyExists(o, "add#left(key, len(key)-1)#")) ) { // composite collection
						
						//first determine the proper object name
						if ( structKeyExists(o, 'add#key#') ) {
						 var compositeObjectName = key;
						} else if ( structKeyExists(o, "add#left(key, len(key)-3)&'y'#") ) { // ies
							var compositeObjectName = left(key, len(key)-3) & 'y';
						} else if ( structKeyExists(o, "add#left(key, len(key)-2)#") ) { // es
							var compositeObjectName = left(key, len(key)-2);
						} else if ( structKeyExists(o, "add#left(key, len(key)-1)#") ) { // s
							var compositeObjectName = left(key, len(key)-1);
						}
						
						// lets use the service for the composite object
						var compService = application.cfservant.getService(compositeObjectName);
						
						// we will have an array here, so lets parse it
						for ( var i=1;i<=arrayLen(tmpValue);i++ ) {
							// try to load up an existing object, otherwise it returns a new object with the specified key
							var oComp = compService.load(tmpValue[i].id);
							// now, set any values sent along with this bugger
							var subkey = '';
							for ( subkey in tmpValue[i] ) {
								if ( structKeyExists(oComp, 'set#subKey#') ) {
									/* at this point we have to assume there are no complex objects, gotta stop somewhere for now since I 
									don't want to bother with recursion - besides, can you imagine the client UI logic it sould require to 
									do so much at once?
									 */
									// don't allow a blank id to be set, all other values blanks are ok
									if ( len(tmpValue[i][subKey]) || lcase(subKey) != 'id' ) {
										evaluate("oComp.set#subKey#(tmpValue[i][subKey])");
									}
								}
							}
							// do we need to handle setting a bidirectional relationship
							if ( structKeyExists(oComp, 'set#objectName#') ) {
								evaluate("oComp.set#objectName#(o)");
							}
							// add this mofo to the parent object
							evaluate("o.add#compositeObjectName#(oComp)");
						}
					} else if ( structKeyExists(o, 'has#key#') ) { // composite object
						
						// for right now we are only handling setting by id - these are not created at this time - the idea is to read it in and set it - there is no bidi relationship being set here either
						// we dont try to get the generic service for this object, as I imagine most of these will be lookups, and have no service
						var oComp = entityLoadByPK(key, tmpValue);
						// throw an error if the object wasn't found
						if ( isNull(oComp) ) {
							throw("Could not find an object of type '#key#' with an id of '#tmpValue#'.");
						}
						// add it to the parent object
						evaluate("o.set#key#(oComp)");
					}
				}
				
				return services[objectName].put(o);
			break;
			
			case 'delete':
				// the rule is to send an argument called id if we are calling delete, otherwise, throw an error
				if ( structKeyExists(arguments.data, 'id') && len(arguments.data.id) ) {
					return services[objectName].delete(id);
				} else {
					throw("You must send an id along with the DELETE request.");
				}
			break;
			
			case 'list':
				return services[objectName].list();
			break;
		}
	}
	
}