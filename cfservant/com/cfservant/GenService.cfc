component accessors="false" {
	
	property String objectName;
	property any Dao; 
	
	public function init () {
		var metaData = getMetaData();
		// we have to have an object to play with
		if ( !structKeyExists(metaData, 'object') || !len(metaData.object) ) { throw('Invalid ORM Object name.'); }
		this.objectName = metaData.object;
	}
	
	public function setDAO(IGenDAO dao) {
		this.dao = arguments.dao;
	}
	
	public any function getDAO() {
		return this.dao;
	}
	
	/* 
		get() - returns an array of all objects
		get(id) - returns the reqeusted object
	 */
	public any function get (String id="") {
		// do we have an ID to get
		if ( len(arguments.id) ) {
			return entityLoadByPK(this.objectName, arguments.id);
		} else { // otherwise, get all
			return entityLoad(this.objectName);
		}
	}
	
	/* 
		load() - returns a new object
		load(id) - returns the requested object, or a new object with the id property set if none exists
	 */
	public any function load (String id='') {
		if ( len(arguments.id) ) {
			var o = entityLoadByPK(this.objectName, arguments.id);
		}
		
		// if no id was passed, or if we didn't find the object with that id
		if ( isNull(local.o) ) {
			var o = entityNew(this.objectName);
			if ( len(arguments.id) ) {
				// this works regardless or id property name thanks to Hibernate
				o.setId(arguments.id);
			}
		}
		
		return o;
	}
	
	public any function put (any object) {
		entitySave(arguments.object);
		ormFlush();
		entityReload(object);
		return object;
	}
	
	public any function post (any object) {
		// for now, lets just use this as a convenience to put - eventually if we implement rest, 
		// that wrapper will probably handle put differently - since this generic code doesn't care how it is accessed this is for convenience only
		put(object);
		return object;
	}
	
	public any function delete (any object, Boolean soft="false") {
		if ( !arguments.soft ) {
			entityDelete(object);
			ormFlush();
			return true;
		} else {
			throw('Soft deletes not possible for #this.objectName#.  It does not implement ISoftDeleteable.');
		}
	}
	
	public function onMissingMethod (String missingMethodName, Struct missingMethodArguments) {
		/* 
			Some methods are only available if a DAO is injected.  We go through the following operation when finding a method
			1. look in the service itself
			2. look in the dao
			3. throw an error (stay transparent)
		 */
		// first, do we have a DAO to check and does the dao have the method we are looking for
		if ( !isNull(this.dao) && structKeyExists(this.dao, missingMethodName) ) {
			return evaluate("this.dao.#arguments.missingMethodName#(argumentCollection=arguments.missingMethodArguments)");
		}
		// otherwise we will fail from here, and give the error the dev would expect to see
		throw(message="The method list was not found in component #getMetaData().path#.", type="Application", detail="Ensure that the method is defined, and that it is spelled correctly.");
	}
	
}