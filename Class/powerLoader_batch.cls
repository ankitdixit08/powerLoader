/**
 * @File Name          : powerLoader_batch.cls
 * @Description        : 
 * @Author             : Ankit Kumar (TCS)
 * @Group              : 
 * @Last Modified By   : Ankit Kumar (TCS)
 * @Last Modified On   : 12/5/2020, 10:24:50 am
 * @Modification Log   : 
 * Ver       Date            Author      		    Modification
 * 1.0    9/5/2020   Ankit Kumar (TCS)     Initial Version
**/
public class powerLoader_batch implements Database.Batchable<list<String>>, Database.Stateful{
public string sObjectName;
public string externalId;
public string getHeaderOfCsv;
public map<string, string> mapOfCsvData;
public list<list<string>> parsedFields;
public map<String,string> RelationshipDataMap;
public string finalstr;
public Schema.sObjectField externalIdtype;
public powerLoader_batch(string sObjectName, string externalId , string getHeaderOfCsv, map<string, string> mapOfCsvData, list<list<string>> parsedFields, map<String,string> RelationshipDataMap){
    this.sObjectName=sObjectName;
    this.externalId=externalId;
    this.getHeaderOfCsv=getHeaderOfCsv;
    this.mapOfCsvData=mapOfCsvData;
    parsedFields.remove(0);
    this.parsedFields=parsedFields;
    this.RelationshipDataMap=RelationshipDataMap;
    
    Map <String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();
    Map <String, Schema.SObjectField> fieldMap = schemaMap.get(sObjectName).getDescribe().fields.getMap();
    
    for(Schema.SObjectField sfield : fieldMap.Values())
    {
        schema.describefieldresult dfield = sfield.getDescribe();
        if(dfield.getName()==externalId){
        this.externalIdtype=  dfield.getSObjectField();
        }
    }  
}

    public Iterable<list<string>> start(Database.BatchableContext BC) {
        return parsedFields;
    }

    public void execute(Database.BatchableContext info, List<list<string>> parsedFieldsScope) {

        List<SObject> recordstoupload=new List<SObject>(); 
        list<string> HeaderOfCsvList=getHeaderOfCsv.split(',');
        //system.debug('HeaderOfCsvList ---->>'+HeaderOfCsvList);
        //system.debug('parsedFieldsScope --->> '+parsedFieldsScope);
        //system.debug('mapOfCsvData --->> '+mapOfCsvData);
        for(Integer i=0;i<parsedFieldsScope.size()-1;i++){
            sObject sObj = Schema.getGlobalDescribe().get(sObjectName).newSObject() ;
            for(Integer j=0;j<HeaderOfCsvList.size();j++){
                if(mapOfCsvData.get(HeaderOfCsvList[j])!=null){
                
                   //system.debug('pf  '+mapOfCsvData.get(parsedFields[0][j]));
                   //system.debug('parsedFields[0][j] -->'+parsedFields[0][j]);
                   //system.debug('p11  '+parsedFields[i+1][j]);
                    //getting lookup
                    if(mapOfCsvData.get(HeaderOfCsvList[j]).contains(':')){
                        
                        list<string> relationWithExternalId=mapOfCsvData.get(HeaderOfCsvList[j]).split(':');
                       // System.debug('p12 --->'+ relationWithExternalId);
                        sObject RelatedsObj = Schema.getGlobalDescribe().get(RelationshipDataMap.get(relationWithExternalId[0])).newSObject() ;
                        //System.debug('p13 --->'+ RelatedsObj);
                        //created an in-memory instance of code, with the external id set
                        RelatedsObj.put(relationWithExternalId[1], parsedFieldsScope[i][j]);
                        //System.debug('p14 --->'+ RelatedsObj);
                        //putting reference of the master in the current record
                        sObj.putSobject(relationWithExternalId[0], RelatedsObj);
                       // System.debug('p15 --->'+ sObj);
                        
                    }
                    //normal
                    else{
                        //system.debug('p17 --->'+mapOfCsvData.get(HeaderOfCsvList[j]));
                        //system.debug('p17 --->'+parsedFieldsScope[i+1][j]);
                       // system.debug('i -->'+i); system.debug('j -->'+j);
                        //system.debug('mapOfCsvData -->'+mapOfCsvData.get(HeaderOfCsvList[j]));
                        //system.debug('parsedFieldsScope -->'+parsedFieldsScope[i][j]);
                        sObj.put(mapOfCsvData.get(HeaderOfCsvList[j]), parsedFieldsScope[i][j]);
                       // System.debug('p16 --->'+ sObj);
                    }
                    
                }
               // System.debug('sobj--- '+sObj);
                
            }
            //system.debug('recordstoupload  --->'+recordstoupload);
            recordstoupload.add(sObj);
        }
        if(string.isblank(externalId)){
            externalId='Id';
        }
        List<GenericUpsertResult> gurList = GenericUpsertResult.genericUpsertWithForeignKey(recordstoupload, externalId, sObjectName, false);
        system.debug('gurList-->'+gurList);

       //string generatedError=dynamicUpsert(recordstoupload, sObjectName, externalId, externalIdtype);
       //finalstr=finalstr==null?generatedError:finalstr+'\n'+generatedError;
        
    }

    public void finish(Database.BatchableContext info) {
        System.debug('all done');
        String userEmail = UserInfo.getUserEmail();
        if(String.isNotBlank(finalstr)){
         System.debug('all done');
         system.debug('headerOfCsv'+getHeaderOfCsv);
         finalstr=(getHeaderOfCsv.deleteWhitespace()).removeEndIgnoreCase(' ')+', errors \n'+finalstr;
         try{
             Messaging.EmailFileAttachment csvAttc = new Messaging.EmailFileAttachment();
             blob csvBlob = Blob.valueOf(finalstr);
             string csvname= 'Error.csv';
             csvAttc.setFileName(csvname);
             csvAttc.setBody(csvBlob);
             Messaging.SingleEmailMessage email =new Messaging.SingleEmailMessage();
             String[] toAddresses = (userEmail).split(',');
             String subject ='Error Report of Dataload';
             email.setSubject(subject);
             email.setToAddresses( toAddresses );
             email.setPlainTextBody('Hello,\n\n This is a error log of your recent data loading activity !!\n\nThanks\nOR Salesforce Team');
             email.setFileAttachments(new Messaging.EmailFileAttachment[]{csvAttc});
             Messaging.SendEmailResult [] r = Messaging.sendEmail(new Messaging.SingleEmailMessage[] {email});
         
             }catch(exception ex){
                 system.debug(ex.getMessage());
             }
         
        }
    }


}
