/**
 * @File Name          : powerLoader.js
 * @Description        : 
 * @Author             : Ankit Kumar
 * @Group              : 
 * @Last Modified By   : Ankit Kumar
 * @Last Modified On   : 10/5/2020, 10:50:36 pm
 * @Modification Log   : 
 * Ver       Date            Author      		    Modification
 * 1.0    9/5/2020         Ankit Kumar      Initial Version
**/
import { LightningElement, wire} from "lwc";
import getAllSobjects from "@salesforce/apex/showRelatedListViewOnAccountController.getAllSobjects";
import getAllFeildsOfSObject from "@salesforce/apex/powerLoader.getAllFeildsOfSObject";
import sendDataForUpload from "@salesforce/apex/powerLoader.sendDataForUpload";
import getBatchJobStatus from "@salesforce/apex/powerLoader.getBatchJobStatus";

export default class powerLoader extends LightningElement {
  allSobjects = [];
  allHeaders = [];
  allHeadersSelect = [];
  allMapping = {};
  allCsvData;
  uploadedFile;
  ShowMappingTable = false;
  AllFeildsOfSObject;
  AllExternalIdsOfSobject;
  externalIdSelected;
  AllFeildsOfCSV;
  SobjectName = "";
  fileName = "Upload a csv file";
  selectedValue;
  section1 = false;
  section2 = false;
  section3 = false;
  batchJobId;
  AsyncApexJob;
  AsyncStatus = "Uploading";
  AsyncErrors;
  AsyncProccessed;
  AsyncTotalJob;
  AsyncExtendedStatus;
  progress = 0;
  getRelationshipData;
  requiredText;
  @wire(getAllSobjects)
  wiredResult(result) {
    if (result.data) {
      var conts = result.data;
      this.section1 = true;
      this.section2 = false;
      this.section3 = false;
      for (var key in conts) {
        this.allSobjects = [
          ...this.allSobjects,
          { value: key, label: conts[key] }
        ];
      }
    }
  }

handleChange(event) {
    if (event.target.name === "customInputForDataList") {
      let key = event.target.value;
      let val = event.target.getAttribute("aria-label");
      this.allMapping[val] = key;
    }
    if (event.target.name === "customInputForSobject") {
      this.SobjectName=event.target.value;
      //console.log("value of box"+  this.SobjectName)
    }
    if (event.target.name === "customInputForExternalId") {
      this.externalIdSelected=event.target.value;
      //console.log("value of box"+  this.SobjectName)
    }
    
    if (event.target.name === "fileToUpload") {
      this.allHeadersSelect=[];
      this.allHeaders=[];
      this.uploadedFile = event.target.files[0];
      this.fileName =
        '"' + event.target.files[0].name + '" File ready to be loaded';
      function getBase64(file) {
        return new Promise((resolve, reject) => {
          const reader = new FileReader();
          reader.readAsText(file);
          reader.onload = () => resolve(reader.result);
          reader.onerror = (error) => reject(error);
        });
      }
      getBase64(this.uploadedFile).then((data) => {
        this.allCsvData = data;
        this.allHeaders = data
          .substr(0, data.indexOf("\n"))
          .toString()
          .split(",");
        var conts = this.allHeaders;
        for (var key in conts) {
          this.allHeadersSelect = [
            ...this.allHeadersSelect,
            { value: conts[key], label: conts[key] }
          ];
        }
      });
    }
  }

  handleClick(event) {
    if (event.target.name === "next1") {
      //Validatimg form
            const allValid = [...this.template.querySelectorAll('.required')]
            .reduce((validSoFar, inputCmp) => {
                        inputCmp.reportValidity();
                        return validSoFar && inputCmp.checkValidity();
            }, true);
            //If validation true
        if (allValid) {
          this.section1 = false;
          this.section2 = true;
          this.section3 = false;
          this.requiredText='';
    
          //console.log('ye main h next1 '+ this.SobjectName);
    
          getAllFeildsOfSObject({
            sObjectName: this.SobjectName,
            getRelationshipData: false, 
            getOnlyExternalIds:false
          })
            .then((result) => {
              if (result) {
                this.AllFeildsOfSObject = result;
              } else {
                console.log("result contains no data");
              }
            })
            .catch((error) => {
              console.log("error hai!! next1" + error);
            });
    
    
            getAllFeildsOfSObject({
              sObjectName: this.SobjectName,
              getRelationshipData: false, 
              getOnlyExternalIds:true
            })
              .then((result) => {
                if (result) {
                  this.AllExternalIdsOfSobject = result;
                } else {
                  console.log("result contains no data");
                }
              })
              .catch((error) => {
                console.log("error hai!! next1 getOnlyExternalIds" + error);
              });
    
              getAllFeildsOfSObject({
                sObjectName: this.SobjectName,
                getRelationshipData: true, 
                getOnlyExternalIds:false
              })
                .then((result) => {
                  if (result) {
                    this.getRelationshipData = result;
                  } else {
                    console.log("result contains no data");
                  }
                })
                .catch((error) => {
                  console.log("error hai!! next1 getOnlyExternalIds" + error);
                });
    
    
        }//if invalid validation  
        else {
          this.requiredText="Complete this field.";
        }

    }
    if (event.target.name === "next2") {
      this.section1 = false;
      this.section2 = false;
      this.section3 = true;
      var csvData=JSON.stringify(this.csvToArray(this.allCsvData));
      console.log('csvData--> '+ csvData);
      sendDataForUpload({
        sObjectName: this.SobjectName,
        getHeaderOfCsv: this.allHeaders.join(),
        mappingOfCsvData: JSON.stringify(this.allMapping),
        csvData: csvData, 
        externalId: this.externalIdSelected, 
        getRelationshipData: this.getRelationshipData.join()
      })
        .then((result) => {
          this.batchJobId = result;

          getBatchJobStatus({
            jobID: this.batchJobId
          }).then((result) => {
            this.AsyncApexJob = Object.values(result);
            this.AsyncStatus = this.AsyncApexJob[0];
            this.AsyncErrors = this.AsyncApexJob[1];
            this.AsyncProccessed = this.AsyncApexJob[2];
            this.AsyncTotalJob = this.AsyncApexJob[3];
            this.AsyncExtendedStatus = this.AsyncApexJob[4];
            this._interval = setInterval(this.updateProgress.bind(this), 5000);

          
          });
        })
        .catch((error, stack) => {
          console.log("error is in handleClick Next2 " + error + "" + stack);
        });
    }
    if (event.target.name === "next3") {
      this.section1 = true;
      this.section2 = false;
      this.section3 = false;
      this.allHeadersSelect = [];
      this.allHeaders = [];
      this.allMapping = {};
      this.fileName = "Upload a csv file";
      this.progress=0;
      this.requiredText='';
      clearInterval(this._interval);
    }
  }

  handleFocus(event){
    if (event.target.name === "customInputForDataList") {
      event.target.nextSibling.setAttribute("id", "valueList");
    }
    if (event.target.name === "customInputForSobject") {
      event.target.nextSibling.setAttribute("id", "SobjectList");
    }
    if (event.target.name === "customInputForExternalId") {
      event.target.nextSibling.setAttribute("id", "ExternalidList");
    }

  }
  updateProgress() {
    getBatchJobStatus({
      jobID: this.batchJobId
    }).then((result) => {
      this.AsyncApexJob = Object.values(result);
      this.AsyncStatus = this.AsyncApexJob[0];
      this.AsyncErrors = this.AsyncApexJob[1];
      this.AsyncProccessed = this.AsyncApexJob[2];
      this.AsyncTotalJob = this.AsyncApexJob[3];
      this.AsyncExtendedStatus = this.AsyncApexJob[4];
    });
    this.progress = (parseInt(this.AsyncProccessed) * 100) / parseInt(this.AsyncTotalJob);
    if(this.AsyncStatus  === 'Completed'){
      clearInterval(this._interval);
    }
  }

  csvToArray(text) {
    let p = '', row = [''], ret = [row], i = 0, r = 0, s = !0, l;
    for (l of text) {
        if ('"' === l) {
            if (s && l === p) row[i] += l;
            s = !s;
        } else if (',' === l && s) l = row[++i] = '';
        else if ('\n' === l && s) {
            if ('\r' === p) row[i] = row[i].slice(0, -1);
            row = ret[++r] = [l = '']; i = 0;
        } else row[i] += l;
        p = l;
    }
    return ret;
};
}
