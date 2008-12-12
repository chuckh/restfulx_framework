package org.ruboss.services.mock {
  import flash.data.SQLStatement;
  import flash.filesystem.File;
  import flash.utils.describeType;
  import flash.utils.getQualifiedClassName;
  
  import mx.rpc.IResponder;
  
  import org.ruboss.Ruboss;
  import org.ruboss.controllers.ServicesController;
  import org.ruboss.services.air.AIRServiceProvider;
  import org.ruboss.utils.RubossUtils;

  public class MockAIRServiceProvider extends AIRServiceProvider {

    public static const ID:int = ServicesController.generateId();
            
    public override function get id():int {
      return ID;
    }
    
    public function MockAIRServiceProvider() {
      var databaseName:String = Ruboss.airDatabaseName;
      var dbFile:File = File.userDirectory.resolvePath(databaseName + ".db");
      if (dbFile.exists) {
        dbFile.deleteFile();
      }
      
      super();
    }

    /**
     * @see org.ruboss.services.IServiceProvider#create
     */
    public override function create(object:Object, responder:IResponder, metadata:Object = null, nestedBy:Array = null):void {
      var fqn:String = getQualifiedClassName(object);
      var sqlText:String = sql[fqn]["insert"];
      if (!RubossUtils.isEmpty(object["id"])) {
        sqlText = sqlText.replace(")", ", id)");
        sqlText = sqlText.replace(/\)$/, ", \:id)");
      }
      var statement:SQLStatement = getSQLStatement(sqlText);
      for each (var node:XML in describeType(object)..accessor) {
        var localName:String = node.@name;
        var type:String = node.@type;
        var snakeName:String = RubossUtils.toSnakeCase(localName);
  
        if (isInvalidPropertyType(type) || isInvalidPropertyName(localName) || RubossUtils.isHasOne(node)) continue;
                    
        if (RubossUtils.isBelongsTo(node)) {
          if (RubossUtils.isPolymorphicBelongsTo(node)) {
            statement.parameters[":" + snakeName + "_type"] = (object[localName] == null) ? null : 
              getQualifiedClassName(object[localName]).split("::")[1];
          }
          snakeName = snakeName + "_id";
          var ref:Object = object[localName];
          statement.parameters[":" + snakeName] = (ref == null) ? null : ref["id"];
  
        } else {
          if (object[localName] is Boolean) {
            statement.parameters[":" + snakeName] = object[localName];
          } else {
            statement.parameters[":" + snakeName] = RubossUtils.uncast(object, localName);
          }
        }
      }
      
      try {
        if (!RubossUtils.isEmpty(object["id"])) {
          statement.parameters[":id"] = object["id"];
        }
        statement.execute();
        if (RubossUtils.isEmpty(object["id"])) {
          object["id"] = statement.getResult().lastInsertRowID;
        }
        invokeResponderResult(responder, object);
      } catch (e:Error) {
        responder.fault(e);
      }
    }
    
    public function loadTestData(dataSets:Object):void {
      Ruboss.log.debug("loading test data for MockAIRServiceProvider");
        
      for (var dataSetName:String in dataSets) {        
        Ruboss.log.debug("loading test data for :" + dataSetName);
        for each (var instance:Object in 
          Ruboss.serializers.xml.unmarshall(dataSets[dataSetName])) {
          create(instance, null);    
        }
      }
    }
  }
}