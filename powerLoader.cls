/**
 * @File Name          : powerLoader.cls
 * @Description        : 
 * @Author             : Ankit Kumar (TCS)
 * @Group              : 
 * @Last Modified By   : Ankit Kumar (TCS)
 * @Last Modified On   : 12/5/2020, 5:03:15 pm
 * @Modification Log   : 
 * Ver       Date            Author      		    Modification
 * 1.0    9/5/2020   Ankit Kumar (TCS)     Initial Version
**/
public with sharing class powerLoader {
    public powerLoader() {
        
    }
    /**
    * @description 
    * @author Ankit Kumar (TCS) | 9/5/2020 
    * @param sObjectName = Name of the sObject
    * @param RelationshipData = if this is true, this method will return relationship data in a list , format -> <relationshipName:objectName,..>
    * @param getOnlyExternalIds = ig this is true, this methode will return the external ids of the sobject specified
    * @return List<String> 
    **/
    @AuraEnabled
    public static List<String>  getAllFeildsOfSObject(string sObjectName, boolean getRelationshipData, boolean getOnlyExternalIds){
        List<String> options = new List<String>();
        list<String> RelationshipDataList=new list<String>();
        list<string> getOnlyExternalIdlist=new list<string>();
        Map <String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();
        Map <String, Schema.SObjectField> fieldMap = schemaMap.get(sObjectName).getDescribe().fields.getMap();
        for(Schema.SObjectField sfield : fieldMap.Values())
        {
            schema.describefieldresult dfield = sfield.getDescribe();
            if(dfield.isUpdateable() || dfield.getname()=='id'){
                if(dfield.isExternalId()){
                    getOnlyExternalIdlist.add(dfield.getName());
                    getOnlyExternalIdlist.add('Id');
                }
                string relatedObject=(dfield.getReferenceTo()).toString();
                relatedObject=relatedObject.removeEnd(')');
                relatedObject=relatedObject.removeStart('(');
                system.debug('relatedObject--- '+relatedObject);
                if(Schema.DisplayType.REFERENCE==dfield.getType() && string.isNotBlank(relatedObject)){
                    try{
                        Map <String, Schema.SObjectField> fieldMapOfRelatedObject = schemaMap.get(relatedObject).getDescribe().fields.getMap();
                        for(Schema.SObjectField rfield : fieldMapOfRelatedObject.Values()){
                            schema.describefieldresult drfield = rfield.getDescribe();
                            if(drfield.isExternalId()){
                                string addRelationship=dfield.getRelationshipName()+':'+drfield.getName();
                                options.add(addRelationship); 
                                system.debug(addRelationship);
                                string RelationshipDataItems=dfield.getRelationshipName()+':'+relatedObject;
                                RelationshipDataList.add(RelationshipDataItems);
                                
                                
                            }
                            
                            
                        }
                    }catch(Exception ex){
                        system.debug('no problem'+ ex.getMessage());
                    }
                    
                    
                }
                options.add(dfield.getname());
            }
            
            
        }
        if(getRelationshipData==true){
            system.debug('RelationshipDataList -->'+RelationshipDataList);
            return RelationshipDataList;
        }
        if(getOnlyExternalIds==true){
            system.debug('RelationshipDataList -->'+RelationshipDataList);
            return getOnlyExternalIdlist;
        }
        return options;
    }

    @AuraEnabled
    public static Id sendDataForUpload(string sObjectName, string getHeaderOfCsv, string mappingOfCsvData, string csvData, string externalId, string getRelationshipData){
        //System.debug('sendDataForUpload csvData-->' +csvData);
        List<SObject> recordstoupload=new List<SObject>(); 
        list<string> RelationshipData=getRelationshipData.split(',');
        map<string, string> RelationshipDataMap=new map<string, string>();
        for(string RelatedObject:RelationshipData){
            list<string> putIntoMap=RelatedObject.split(':');
            RelationshipDataMap.put(putIntoMap[0], putIntoMap[1]);
        }
        //system.debug('RelationshipDataMap--->'+RelationshipDataMap);
        id batchJobId;
        try{
             Map<String,string> mapOfCsvData = (Map<String,string>)JSON.deserialize(mappingOfCsvData, Map<String,string>.class);
             system.debug('mapOfCsvData line 105 '+mapOfCsvData);
             list<list<String>> parsedFields = (list<list<String>>)JSON.deserialize(csvData, list<list<String>>.class);
            system.debug('sendDataForUpload parsedFields 107-->  '+parsedFields);

            powerLoader_batch  db = new powerLoader_batch(sObjectName, externalId , getHeaderOfCsv, mapOfCsvData, parsedFields, RelationshipDataMap);
            batchJobId=Database.executeBatch(db,200);
            System.debug('Heap size 102--> '+Limits.getLimitHeapSize());

             }catch(Exception e){
            System.debug('error in sendDataForUpload line 105--> '+e.getMessage());
        }
        
        
        return batchJobId; 
    }
    /**
    * @description 
    * @author Ankit Kumar (TCS) | 9/5/2020 
    * @param jobID 
    * @return AsyncApexJob 
    **/
    @AuraEnabled
    public static AsyncApexJob getBatchJobStatus(Id jobID){
        AsyncApexJob  jobInfo = [SELECT Status, NumberOfErrors,JobItemsProcessed,TotalJobItems,ExtendedStatus FROM AsyncApexJob WHERE Id = :jobID];
        return jobInfo;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String,string> getAllSobjects() {
        Map<String,string> options = new Map<String,string>();
        for(Schema.SObjectType objTyp : Schema.getGlobalDescribe().Values()){
             options.put(String.valueOf(objTyp.getDescribe().getName()), objTyp.getDescribe().getLabel());
       }    
        return options;
    }
    
}