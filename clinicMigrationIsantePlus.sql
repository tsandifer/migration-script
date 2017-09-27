DELIMITER $$ 
CREATE PROCEDURE clinicMigration()
BEGIN
  DECLARE done INT DEFAULT FALSE;
 -- DECLARE a CHAR(16);
  
  DECLARE vvisit_type_id INT;
  DECLARE obs_datetime_,vobs_datetime,vdate_created,vencounter_datetime datetime;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE; 
  DECLARE vobs_id,vperson_id,vconcept_id,vencounter_id,vlocation_id INT;
  DECLARE vreferHosp,vreferVctCenter,vreferPmtctProg,vreferOutpatStd,vreferCommunityBasedProg,vfirstCareOtherFacText varchar(10);
  
DECLARE uuid_encounter CURSOR  for SELECT DISTINCT e.patient_id,e.encounter_id FROM itech.encounter c;

DECLARE source_reference CURSOR  for 
SELECT DISTINCT e.patient_id,5089,e.encounter_id,e.encounter_datetime,e.location_id,
referHosp,referVctCenter,referPmtctProg,referOutpatStd,referCommunityBasedProg,firstCareOtherFacText,e.date_created
FROM itech.encounter c, encounter e, itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and e.encounter_datetime = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
(referHosp=1 or referVctCenter=1 or referPmtctProg=1 or referOutpatStd=1 or referCommunityBasedProg=1 or firstCareOtherFacText=1);
  

select visit_type_id into vvisit_type_id from visit_type where uuid='7b0f5697-27e3-40c4-8bae-f4049abfb4ed';

 /* Visit Migration
 * find all unique patientid, visitdate instances in the encounter table and consider these visits
 */
INSERT INTO visit (patient_id, visit_type_id, date_started, date_stopped, location_id, creator, date_created, uuid)
SELECT DISTINCT p.person_id, vvisit_type_id, concat(e.visitDateYy,'-',e.visitDateMm,'-',e.visitDateDd), concat(e.visitDateYy,'-',e.visitDateMm,'-',e.visitDateDd), it.location_id,1, e.lastModified, UUID()
FROM person p, itech.patient it, itech.encounter e
WHERE p.uuid = it.patGuid AND it.patientid = e.patientid AND
e.encounterType in (1,2,3,4,5,6,12,14,16,17,18,19,20,21,24,25,26,27,28,29,31);


/* update encounter itech table with uuid */
ALTER TABLE itech.encounter ADD encGuid VARCHAR(36) NOT NULL;
 
OPEN uuid_encounter;

uuid_encounter_loop: LOOP
  FETCH uuid_encounter INTO vperson_id,vencounter_id;
    IF done THEN
      LEAVE uuid_encounter;
    END IF;
	UPDATE itech.encounter SET encGuid = UUID() where encounter_id=vencounter_id;
  END LOOP;
  
  CLOSE uuid_encounter;
CREATE UNIQUE INDEX eGuid ON itech.encounter (encGuid);
/* end update encounter itech table with uuid */


CREATE TABLE itech.typeToForm (encounterType INT, form_id INT,encounterTypeOpenmrs INT, uuid VARCHAR(36));
INSERT INTO itech.typeToForm (encounterType, uuid) VALUES 
( 14 , '81ddaf29-50d9-4654-a2e2-5a3d784b7427' ),
( 20 , '81ddaf29-50d9-4654-a2e2-5a3d784b7427' ),
( 6  , '56cf5b28-c0b5-4d57-8dde-a43e93e269d2' ),
( 19 , '56cf5b28-c0b5-4d57-8dde-a43e93e269d2' ),
( 25 , '154a1a80-3565-4b17-aa30-018e623ad148' ),
( 24 , '66207cc7-35ad-436a-8740-0810b92f17fb' ),
( 26 , '92b72750-916f-4cc6-a719-728285143770' ),
( 3  , '89710ca2-ac5a-42e4-a430-0dfa2cb71f6e' ),
( 4  , '89710ca2-ac5a-42e4-a430-0dfa2cb71f6e' ),
( 5  , '2eb5f8f8-9bb4-4aae-92cc-1706eca22e6a' ),
( 18 , 'b1a372de-2961-4468-8e7a-33b7e2048d71' ),
( 12 , '0c3ca345-f834-46d1-a620-6d0f20f217f2' ),
( 21 , '0c3ca345-f834-46d1-a620-6d0f20f217f2' ),
( 1  , 'f73c1969-49c4-4ef5-8943-e8838547a275' ),
( 16 , 'ef15c91f-734f-4e08-b6fa-d148b8ecbfc0' ),
( 31 , 'ae0288ee-a173-4dd3-ae81-88c9e01970ea' ),
( 27 , 'dd2c4fc5-3fea-430a-9442-c65a85d9c320' ),
( 29 , '88692569-a213-43c3-b1f3-d8745c456543' ),
( 28 , '3c7f88b0-b844-47ba-b4da-4b5dee2b8b0a' ),
( 2  , 'df621bc1-6f2e-46bf-9fe9-184f1fdd41f2' ),
( 17 , 'f55d3760-1bf1-4e42-a7f9-0a901fa49cf0' );
 
 UPDATE itech.typeToForm i, form t SET i.form_id = t.form_id,i.encounterTypeOpenmrs=t.encounter_type where i.uuid = t.uuid;
 
 create unique index mmm on encounter (patient_id,location_id, encounter_datetime, encounter_type,date_created);
 
INSERT INTO encounter(encounter_type,patient_id,location_id,form_id,visit_id, encounter_datetime,creator,date_created,date_changed,uuid)
SELECT ALL f.encounter_type_id, p.person_id, 1, f.form_id, v.visit_id,
concat(e.visitDateYy,'-',e.visitDateMm,'-',e.visitDateDd),1,e.createDate,e.lastModified,e.encGuid
FROM itech.encounter e, person p, itech.patient j, visit v, itech.typeToForm f
WHERE p.uuid = j.patGuid and 
e.patientID = j.patientID AND 
v.patient_id = p.person_id AND 
v.date_started = date(concat(e.visitDateYy,'-',e.visitDateMm,'-',e.visitDateDd)) AND 
e.encounterType in (1,2,3,4,5,6,12,14,16,17,18,19,20,21,24,25,26,27,28,29,31) AND
e.encounterType = f.encounterType 
ON DUPLICATE KEY UPDATE
encounter_type=VALUES(encounter_type),
patient_id=VALUES(patient_id),
location_id=VALUES(location_id),
form_id=VALUES(form_id),
encounter_datetime=VALUES(encounter_datetime),
creator=VALUES(creator),
date_created=VALUES(date_created),
date_changed=VALUES(date_changed);


/* SIGNES VITAUX MENU */
/*DATA Migration for vitals Temp*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT c.patient_id,5088,c.encounter_id,c.encounter_datetime,c.location_id,
CASE WHEN v.vitalTempUnits=2 THEN ROUND((substring_index(replace(v.vitalTemp,',','.'),'.',2)+0-32)/1.8000,2) 
ELSE ROUND(substring_index(replace(v.vitalTemp,',','.'),'.',2)+0,2) END,1,c.date_created,UUID()
from encounter c, itech.encounter e, itech.vitals v 
WHERE c.uuid = e.encGuid and 
e.patientid = v.patientid and e.sitecode = v.sitecode and concat(e.visitDateYy,'-',e.visitDateMm,'-',e.visitDateDd) = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) and e.seqNum = v.seqNum AND 
(substring_index(replace(v.vitalTemp,',','.'),'.',2)+0 > 0 AND vitalTempUnits IS NOT NULL);


/*DATA Migration for vitals TA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,5085,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.vitalBPUnits=1 THEN substring_index(replace(v.vitalBp1+0,',','.'),'.',2)
WHEN v.vitalBPUnits=2 THEN substring_index(replace(v.vitalBp1+0,',','.'),'.',2)*10 END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and
c.sitecode = v.sitecode and e.encounter_datetime = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
substring_index(replace(v.vitalBp1,',','.'),'.',2) REGEXP '^[0-9\.]+$' and v.vitalBp1 IS NOT NULL AND v.vitalBp2 <> '';

INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,5086,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.vitalBPUnits=1 THEN substring_index(replace(v.vitalBp2,',','.'),'.',2)
WHEN v.vitalBPUnits=2 THEN substring_index(replace(v.vitalBp2,',','.'),'.',2)*10 END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and
c.sitecode = v.sitecode and e.encounter_datetime = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
substring_index(replace(v.vitalBp2,',','.'),'.',2) REGEXP '^[0-9\.]+$' and v.vitalBp2 IS NOT NULL AND v.vitalBp2 <> '';


/*DATA Migration for vitals POULS*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,5085,e.encounter_id,e.encounter_datetime,e.location_id,v.vitalHr,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and e.encounter_datetime = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd)
AND v.vitalHr<>'';


/*DATA Migration for vitals FR*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,5085,e.encounter_id,e.encounter_datetime,e.location_id,v.vitalRr,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and e.encounter_datetime = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd)
AND v.vitalRr<>'';


/*DATA Migration for vitals TAILLE*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,5090,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.vitalHeightCm<>'' THEN v.vitalHeightCm
WHEN v.vitalHeight<>''  THEN vitalHeight*100
ELSE NULL
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and e.encounter_datetime = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
(v.vitalHeight<>'' OR v.vitalHeightCm<>'');


/*DATA Migration for vitals POIDS*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,5089,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.vitalWeightUnits=1 THEN vvitalWeight
WHEN v.vitalWeightUnits=2  THEN v.vitalWeight/2.2046
ELSE NULL
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and e.encounter_datetime = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.vitalWeight<>'';

/*END OF SIGNES VITAUX MENU*/


/*STARTING SOURCE DE RÉFÉRENCE MENU*/ 
OPEN source_reference;

source_reference_loop: LOOP
  FETCH source_reference INTO vperson_id,vconcept_id,vencounter_id,vencounter_datetime,vlocation_id, vreferHosp,
	                          vreferVctCenter,vreferPmtctProg,vreferOutpatStd,vreferCommunityBasedProg,vfirstCareOtherFacText,vdate_created;
    IF done THEN
      LEAVE source_reference;
    END IF;
	

	/*MIGRATION FOR Hôpital (patient a été hospitalisé antérieurement)*/
	if(vreferHosp=1) then 
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
	values (vperson_id,vconcept_id,vencounter_id_,vobs_datetime,vlocation_id,5485,1,vdate_created,uuid());
	end if;
	
	/*MIGRATION FOR Centres CDV intégrés*/
	if(vreferVctCenter=1) then 
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
	values (vperson_id,vconcept_id,vencounter_id_,vobs_datetime,vlocation_id,159940,1,vdate_created,uuid());
	end if;

	
	/*MIGRATION FOR Programme PTME*/
	if(vreferPmtctProg=1) then 
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
	values (vperson_id,vconcept_id,vencounter_id_,vobs_datetime,vlocation_id,159937,1,vdate_created,uuid());
	end if;
	
	/*MIGRATION FOR Clinique Externe*/
	if(vreferOutpatStd=1) then 
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
	values (vperson_id,vconcept_id,vencounter_id_,vobs_datetime,vlocation_id,160542,1,vdate_created,uuid());
	end if;
	
    /*MIGRATION FOR Programmes communautaires*/
	if(vreferCommunityBasedProg=1) then 
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
	values (vperson_id,vconcept_id,vencounter_id_,vobs_datetime,vlocation_id,159938,1,vdate_created,uuid());
	end if;
		
	/*MIGRATION FOR Transfert d'un autre établissement de santé*/
	if(vfirstCareOtherFacText<>'') then 
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
	values (vperson_id,vconcept_id,vencounter_id_,vobs_datetime,vlocation_id,5622,1,vdate_created,uuid());
	end if;
		
	/*END OF SOURCE DE RÉFÉRENCE MENU*/

  END LOOP;
  
  CLOSE source_reference;
  
  
  	
	/*STARTING TEST ANTICORPS VIH MENU*/
	   /*Migration for Date du premier test (anticorps) VIH positif*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160082,e.encounter_id,e.encounter_datetime,e.location_id,
	CASE WHEN v.firstTestYy<>'' AND v.firstTestMm<>'' THEN CONCAT(v.firstTestYy,'-',v.firstTestMm,'-',01)
		ELSE NULL
	END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and e.encounter_datetime = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.firstTestYy<>'' AND v.firstTestMm<>'';
		
		/*Migration for Établissement où le test a été réalisé*/
		 /*Cet établissement */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159936,e.encounter_id,e.encounter_datetime,e.location_id,
	CASE WHEN itech.vitals.firstTestThisFac=1 THEN 163266
		ELSE NULL
	END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and e.encounter_datetime = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.firstTestThisFac=1;
		
		/*Autre */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159936,e.encounter_id,e.encounter_datetime,e.location_id,
	CASE WHEN itech.vitals.firstTestOtherFac=1 THEN 5622
		ELSE NULL
	END,v.firstTestOtherFacText,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and e.encounter_datetime = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.firstTestOtherFac=1;		
	/*END OF TEST ANTICORPS VIH MENU*/
 
 
 	/*STARTING ÉTAT DE FONCTIONNEMENT MENU*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,162753,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.functionalStatus=1 THEN 159468
	 WHEN v.functionalStatus=2 THEN 160026
	 WHEN v.functionalStatus=4 THEN 162752
	 ELSE NULL
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and e.encounter_datetime = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.functionalStatus>0;
	/*END OF ÉTAT DE FONCTIONNEMENT MENU*/
 
 
 /*STARTING MIGRATION FOR MODE PROBABLE DE TRANSMISSION DU VIH MENU*/
		/*Rapports sexuels avec un homme*/
		/*Rapports sexuels avec une femme*/
		/*Injection de drogues*/
		/*Bénéficier de sang/dérivé sanguin*/
		/*Migration FOR Transmission mère a enfant*/
		/*MIGRATION FOR - homme bisexuel */
		/*MIGRATION FOR Rapports hétérosexuelles avec :
		  - personne SIDA/VIH+
		*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1061,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN itech.riskAssessments.riskID=1 AND itech.riskAssessments.riskAnswer=1 THEN 163290
	 WHEN v.riskID=3 AND v.riskAnswer=1 THEN 163291
	 WHEN v.riskID=9 AND v.riskAnswer=1 THEN 105
	 WHEN v.riskID=15 AND v.riskAnswer=1 THEN 1063
	 WHEN v.riskID=14 AND v.riskAnswer=1 THEN 163273
	 WHEN v.riskID=19 AND v.riskAnswer=1 THEN 163289
	 WHEN v.riskID=5 AND v.riskAnswer=1 THEN 105
	 WHEN v.riskID=6 AND v.riskAnswer=1 THEN 163275
	 WHEN v.riskID=31 AND v.riskAnswer=1 THEN 1063
		ELSE NULL
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.riskAssessments v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and e.encounter_datetime = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.riskID in (1,3,5,6,9,14,15,19,31) and v.riskAnswer=1;

		/*FOR THE DATE*//*Bénéficier de sang/dérivé sanguin*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163268,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.riskID=15 AND v.riskAnswer=1 and v.riskYy>1 then concat(riskYy,'-',ifnull(v.riskMm,'01'),'-',ifnull(v.riskDd,'01'))
	 else null
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.riskAssessments v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and e.encounter_datetime = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.riskID=15 and v.riskAnswer=1 and ifnull(v.riskYy,0)>0;
		
/*MIGRATION FOR Accident d'exposition au sang*/
	/*Migration for obsgroup*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163288,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.riskAssessments v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and e.encounter_datetime = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.riskID=12 and v.riskAnswer=1;

set vobs_id=last_insert_id();

		
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160581,e.encounter_id,e.encounter_datetime,e.location_id,vobs_id,
CASE WHEN v.riskID=12 AND v.riskAnswer=1 THEN 163274
	 ELSE NULL
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.riskAssessments v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and e.encounter_datetime = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.riskID=12 and v.riskAnswer=1;
		/*migration for the date*/
		
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,162601,e.encounter_id,e.encounter_datetime,e.location_id,vobs_id,
CASE WHEN v.riskID=12 AND v.riskAnswer=1 and v.riskYy>1 then concat(riskYy,'-',ifnull(v.riskMm,'01'),'-',ifnull(v.riskDd,'01'))
	 else null
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.riskAssessments v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and e.encounter_datetime = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.riskID=12 and v.riskAnswer=1 and ifnull(v.riskYy,0)>0;		
	
	/*END OF MIGRATION FOR MODE PROBABLE DE TRANSMISSION DU VIH MENU*/
 

/*MIGRATION FOR AUTRES FACTEURS DE RISQUE MENU*/
	/*Migration for Histoire ou présence de syphilis*/
	/*Migration for obsgroup*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163292,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.riskAssessments v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and e.encounter_datetime = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND v.riskID=32
AND (v.riskAnswer=1 OR v.riskAnswer=2 OR v.riskAnswer=4);
		
set vobs_id=last_insert_id();
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163276,e.encounter_id,e.encounter_datetime,e.location_id,vobs_id,
CASE WHEN v.riskID=32 AND v.riskAnswer=1 THEN 1065
	 WHEN v.riskID=32 AND v.riskAnswer=2 THEN 1066
	 WHEN v.riskID=32 AND v.riskAnswer=4 THEN 1067
	 ELSE NULL
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.riskAssessments v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and e.encounter_datetime = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND v.riskID=32
AND (v.riskAnswer=1 OR v.riskAnswer=2 OR v.riskAnswer=4);
		
		/*migration for Victime d'agression sexuelle*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,123160,e.encounter_id,e.encounter_datetime,e.location_id,vobs_id,
CASE WHEN v.riskID=13 AND v.riskAnswer=1 THEN 1065
	 WHEN v.riskID=13 AND v.riskAnswer=2 THEN 1066
	 WHEN v.riskID=13 AND v.riskAnswer=4 THEN 1067
	 ELSE NULL
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.riskAssessments v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and e.encounter_datetime = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND v.riskID=13
AND (v.riskAnswer=1 OR v.riskAnswer=2 OR v.riskAnswer=4);
		
		/*Migration for Rapports sexuels :
			- ≥ 2 personnes dans les 3 dernières mois
		*/
		
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160581,e.encounter_id,e.encounter_datetime,e.location_id,vobs_id,
CASE WHEN v.riskID=33 AND v.riskAnswer=1 THEN 5567
	 ELSE NULL
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.riskAssessments v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and e.encounter_datetime = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) 
AND v.riskID=33 AND v.riskAnswer=1;		
		
		
		/*- par voie anale*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163278,e.encounter_id,e.encounter_datetime,e.location_id,vobs_id,
CASE WHEN v.riskID=7 AND v.riskAnswer=1 THEN 1065
     WHEN v.riskID=7 AND v.riskAnswer=2 THEN 1066
	 ELSE NULL
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.riskAssessments v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and e.encounter_datetime = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) 
AND v.riskID=7 AND (v.riskAnswer=1 or v.riskAnswer=2);	
		
		/*- avec travailleur/euse de sexe*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160581,e.encounter_id,e.encounter_datetime,e.location_id,vobs_id,
CASE WHEN v.riskID=20 AND (v.riskAnswer=1 or v.riskAnswer=2 ) THEN 160580
	 ELSE NULL
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.riskAssessments v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and e.encounter_datetime = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) 
AND v.riskID=20 AND (v.riskAnswer=1 or v.riskAnswer=2);			

INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160580,e.encounter_id,e.encounter_datetime,e.location_id,vobs_id,
CASE WHEN v.riskID=20 AND v.riskAnswer=1 THEN 1065
     WHEN v.riskID=20 AND v.riskAnswer=2 THEN 1066
	 ELSE NULL
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.riskAssessments v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and e.encounter_datetime = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) 
AND v.riskID=20 AND (v.riskAnswer=1 or v.riskAnswer=2);	
		
		/* - L'échange de sexe pour argent/choses*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160581,e.encounter_id,e.encounter_datetime,e.location_id,vobs_id,
CASE WHEN v.riskID=34 AND (v.riskAnswer=1 or v.riskAnswer=2 ) THEN 160579
	 ELSE NULL
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.riskAssessments v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and e.encounter_datetime = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) 
AND v.riskID=34 AND (v.riskAnswer=1 or v.riskAnswer=2);			

INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160579,e.encounter_id,e.encounter_datetime,e.location_id,vobs_id,
CASE WHEN v.riskID=34 AND v.riskAnswer=1 THEN 1065
     WHEN v.riskID=34 AND v.riskAnswer=2 THEN 1066
	 ELSE NULL
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.riskAssessments v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and e.encounter_datetime = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) 
AND v.riskID=34 AND (v.riskAnswer=1 or v.riskAnswer=2);			

	/*END OF MIGRATION FOR AUTRES FACTEURS DE RISQUE MENU*/ 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 	/*STARTING MIGRATION FOR COMPTE CD4 MENU*/
		/*Compte CD4 le plus bas*/		
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159375,e.encounter_id,e.encounter_datetime,e.location_id,
	CASE WHEN v.lowestCd4Cnt<>'' THEN lowestCd4Cnt
		ELSE NULL
	END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and e.encounter_datetime = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.lowestCd4Cnt<>'';	

		/* DATE */		
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159376,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.lowestCd4CntDd<1 AND v.lowestCd4CntMm<1 AND v.lowestCd4CntYy>0 
		THEN CONCAT(v.lowestCd4CntYy,'-',01,'-',01)
		WHEN v.lowestCd4CntDd<1 AND v.lowestCd4CntMm>0 AND v.lowestCd4CntYy>0
		THEN CONCAT(v.lowestCd4CntYy,'-',v.lowestCd4CntMm,'-',01)
		WHEN v.lowestCd4CntDd>0 AND v.lowestCd4CntMm>0 AND v.lowestCd4CntYy>0
		THEN CONCAT(v.lowestCd4CntYy,'-',v.lowestCd4CntMm,'-',v.lowestCd4CntDd)
		ELSE NULL
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and e.encounter_datetime = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.lowestCd4Cnt<>'' AND v.lowestCd4CntYy>0;
		/*Non effectué/Inconnu*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1941,e.encounter_id,e.encounter_datetime,e.location_id,
	CASE WHEN v.lowestCd4Cnt<>'' AND v.lowestCd4CntNotDone=1 THEN 1066
		ELSE NULL
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and e.encounter_datetime = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.lowestCd4Cnt<>'' AND 
v.lowestCd4CntNotDone=1;

		/*MIGRATION for Virémie*/
		
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163280,e.encounter_id,e.encounter_datetime,e.location_id,
	CASE WHEN v.firstViralLoad<>'' THEN lowestCd4Cnt
		ELSE NULL
	END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and e.encounter_datetime = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.firstViralLoad<>'';	

		/* DATE */		
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163281,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.firstViralLoadDd<1 AND v.firstViralLoadMm<1 AND v.firstViralLoadYy>0 
		THEN CONCAT(v.firstViralLoadYy,'-',01,'-',01)
		WHEN v.firstViralLoadDd<1 AND v.firstViralLoadMm>0 AND v.firstViralLoadYy>0
		THEN CONCAT(v.firstViralLoadYy,'-',v.firstViralLoadMm,'-',01)
		WHEN v.firstViralLoadDd>0 AND v.firstViralLoadMm>0 AND v.firstViralLoadYy>0
		THEN CONCAT(v.firstViralLoadYy,'-',v.firstViralLoadMm,'-',v.firstViralLoadDd)
		ELSE NULL
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and e.encounter_datetime = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.firstViralLoad<>'' AND
v.firstViralLoadYy>0;
		
	/*END OF MIGRATION FOR COMPTE CD4 MENU*/
 
 
 
 	/*MIGRATION FOR STATUT TB MENU*/
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1659,e.encounter_id,e.encounter_datetime,e.location_id,
	CASE WHEN v.asymptomaticTb=1 AND (v.completeTreat=0 OR v.completeTreat='') AND (v.currentTreat=0 OR v.currentTreat='') THEN 1660
		WHEN v.completeTreat=1 AND (v.asymptomaticTb=0 OR v.asymptomaticTb='') AND (v.currentTreat=0 OR v.currentTreat='') THEN 1663
		WHEN v.currentTreat=1 AND (v.asymptomaticTb=0 OR v.asymptomaticTb='') AND (v.completeTreat=0 OR v.completeTreat='') THEN 1662
		ELSE NULL
	END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.tbStatus  v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and e.encounter_datetime = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
(v.asymptomaticTb=1 OR v.completeTreat=1 OR v.currentTreat=1);
	
		/*Migration for Date complété */		
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159431,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.completeTreatDd<1 AND v.completeTreatMm<1 AND v.completeTreatYy>0 THEN CONCAT(v.completeTreatYy,'-',01,'-',01)
	 WHEN v.completeTreatDd<1 AND v.completeTreatMm>0 AND v.completeTreatYy>0 THEN CONCAT(v.completeTreatYy,'-',v.completeTreatMm,'-',01)
	 WHEN v.completeTreatDd>0 AND v.completeTreatMm>0 AND v.completeTreatYy>0 THEN CONCAT(v.completeTreatYy,'-',v.completeTreatMm,'-',v.completeTreatDd)
	 ELSE NULL
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.tbStatus v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and e.encounter_datetime = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.completeTreat=1 AND v.completeTreatYy>0;
		/*On Going with james*/
	/*END OF MIGRATION FOR STATUT TB MENU */
	
	
	
	
	
	/*MIGRATION FOR VACCINS MENU*/
	/*MIGRATION FOR Hépatite B*/
	/*concept group */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1421,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals  v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and e.encounter_datetime = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
(v.vaccTetanus=1 OR v.vaccHepB=1);

set vobs_id=last_insert_id();	

		
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,984,e.encounter_id,e.encounter_datetime,e.location_id,vobs_id,
CASE WHEN v.vaccHepB=1 THEN 1685 ELSE NULL END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals  v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and e.encounter_datetime = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND v.vaccHepB=1;
		
/*migration for MM/AA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1410,e.encounter_id,e.encounter_datetime,e.location_id,vobs_id,
CASE WHEN v.vaccHepB=1 AND v.vaccHepBMm<1 AND v.vaccHepBYy>0 THEN CONCAT(v.vaccHepBYy,'-',01,'-',01)
	 WHEN v.vaccHepB=1 AND v.vaccHepBMm>0 AND v.vaccHepBYy>0 THEN CONCAT(v.vaccHepBYy,'-',v.vaccHepBMm,'-',01)
	 ELSE NULL
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals  v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and e.encounter_datetime = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.vaccHepB=1 AND v.vaccHepBYy>0;

/*migration for Nombre de dose */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1418,e.encounter_id,e.encounter_datetime,e.location_id,vobs_id,
CASE WHEN v.vaccHepB=1 AND v.hepBdoses>=0 THEN v.hepBdoses ELSE NULL END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals  v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and e.encounter_datetime = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.vaccHepB=1 AND v.hepBdoses>=0;

		/*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
		/*MIGRATION FOR Tétanos*/ 
/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,984,e.encounter_id,e.encounter_datetime,e.location_id,vobs_id,
CASE WHEN v.vaccTetanus=1 THEN 1685 ELSE NULL END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals  v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and e.encounter_datetime = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND v.vaccTetanus=1;
		
/*migration for MM/AA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1410,e.encounter_id,e.encounter_datetime,e.location_id,vobs_id,
CASE WHEN v.vaccTetanus=1 AND v.vaccTetanusMm<1 AND v.vaccTetanusYy>0 THEN CONCAT(v.vaccTetanusYy,'-',01,'-',01)
	 WHEN v.vaccTetanus=1 AND v.vaccTetanusMm>0 AND v.vaccTetanusYy>0 THEN CONCAT(v.vaccTetanusYy,'-',v.vaccTetanusMm,'-',01)
	 ELSE NULL
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals  v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and e.encounter_datetime = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.vaccTetanus=1 AND v.vaccTetanusYy>0;

/*migration for Nombre de dose */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1418,e.encounter_id,e.encounter_datetime,e.location_id,vobs_id,
CASE WHEN v.vaccTetanus=1 AND v.tetDoses>=0 THEN v.tetDoses ELSE NULL END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals  v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and e.encounter_datetime = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.vaccTetanus=1 AND v.tetDoses>=0 and v.tetDoses<>'';		
		/*On going*/
		/*Autre preciser*/
	/*END OF MIGRATION FOR VACCINS MENU*/
	


/*MIGRATION FOR SYMPTÔMES MENU*/
	  /*migration for Douleur abdominale*/
	  /*concept group */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1727,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7000 and o.value_boolean=1;

set vobs_id=last_insert_id();	
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1728,e.encounter_id,e.encounter_datetime,e.location_id,vobs_id,
CASE WHEN o.concept_id=7000 AND o.value_boolean=1 THEN 151
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7000 and o.value_boolean=1;		

		/*Migration for YES */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1729,e.encounter_id,e.encounter_datetime,e.location_id,vobs_id,
CASE WHEN o.concept_id=7000 AND o.value_boolean=1 THEN 1065
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7000 and o.value_boolean=1;	
		/*=========================================================================================================*/
		/*migration for Anorexie/Perte d'appétit*/
	  /*concept group */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1727,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7001 and o.value_boolean=1;

set vobs_id=last_insert_id();	
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1728,e.encounter_id,e.encounter_datetime,e.location_id,vobs_id,
CASE WHEN o.concept_id=7001 AND o.value_boolean=1 THEN 6031
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7001 and o.value_boolean=1;		

		/*Migration for YES */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1729,e.encounter_id,e.encounter_datetime,e.location_id,vobs_id,
CASE WHEN o.concept_id=7001 AND o.value_boolean=1 THEN 1065
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7001 and o.value_boolean=1;
		/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
		/*migration for Toux*/
	  /*concept group */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1727,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7004 and o.value_boolean=1;

set vobs_id=last_insert_id();	
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1728,e.encounter_id,e.encounter_datetime,e.location_id,vobs_id,
CASE WHEN o.concept_id=7004 AND o.value_boolean=1 THEN 143264
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7004 and o.value_boolean=1;		

		/*Migration for YES */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1729,e.encounter_id,e.encounter_datetime,e.location_id,vobs_id,
CASE WHEN o.concept_id=7004 AND o.value_boolean=1 THEN 1065
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7004 and o.value_boolean=1;	  
		/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
		/*Migration for Toux/Expectoration (sauf hémoptysie)*/		
		 /*concept group */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1727,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7008 and o.value_boolean=1;

set vobs_id=last_insert_id();	
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1728,e.encounter_id,e.encounter_datetime,e.location_id,vobs_id,
CASE WHEN o.concept_id=7008 AND o.value_boolean=1 THEN 5957
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7008 and o.value_boolean=1;		

		/*Migration for YES */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1729,e.encounter_id,e.encounter_datetime,e.location_id,vobs_id,
CASE WHEN o.concept_id=7008 AND o.value_boolean=1 THEN 1065
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7008 and o.value_boolean=1;			 
		/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
		/*Migration for Dyspnée*/
		 /*concept group */
		 
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1727,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7007 and o.value_boolean=1;

set vobs_id=last_insert_id();	
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1728,e.encounter_id,e.encounter_datetime,e.location_id,vobs_id,
CASE WHEN o.concept_id=7007 AND o.value_boolean=1 THEN 122496
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7007 and o.value_boolean=1;		

		/*Migration for YES */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1729,e.encounter_id,e.encounter_datetime,e.location_id,vobs_id,
CASE WHEN o.concept_id=7007 AND o.value_boolean=1 THEN 1065
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7007 and o.value_boolean=1;			 

	/*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
		/*Migration for Céphalée*/
	 /*concept group */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1727,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7011 and o.value_boolean=1;

set vobs_id=last_insert_id();	
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1728,e.encounter_id,e.encounter_datetime,e.location_id,vobs_id,
CASE WHEN o.concept_id=7011 AND o.value_boolean=1 THEN 139084
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7011 and o.value_boolean=1;		

		/*Migration for YES */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1729,e.encounter_id,e.encounter_datetime,e.location_id,vobs_id,
CASE WHEN o.concept_id=7011 AND o.value_boolean=1 THEN 1065
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7011 and o.value_boolean=1;		 

		/*=============================================================================================================*/
		/*Migration for Hémoptysie*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1727,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7012 and o.value_boolean=1;

set vobs_id=last_insert_id();	
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1728,e.encounter_id,e.encounter_datetime,e.location_id,vobs_id,
CASE WHEN o.concept_id=7012 AND o.value_boolean=1 THEN 138905
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7012 and o.value_boolean=1;		

		/*Migration for YES */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1729,e.encounter_id,e.encounter_datetime,e.location_id,vobs_id,
CASE WHEN o.concept_id=7012 AND o.value_boolean=1 THEN 1065
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7012 and o.value_boolean=1;			
		/*=================================================================================================================*/
		/*Migration for Nausée*/
		/*Concept group*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1727,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7013 and o.value_boolean=1;

set vobs_id=last_insert_id();	
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1728,e.encounter_id,e.encounter_datetime,e.location_id,vobs_id,
CASE WHEN o.concept_id=7013 AND o.value_boolean=1 THEN 5978
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7013 and o.value_boolean=1;		

		/*Migration for YES */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1729,e.encounter_id,e.encounter_datetime,e.location_id,vobs_id,
CASE WHEN o.concept_id=7013 AND o.value_boolean=1 THEN 1065
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7013 and o.value_boolean=1;
		/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
		/*Migration for Sueurs nocturnes*/
		/*Concept group*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1727,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7014 and o.value_boolean=1;

set vobs_id=last_insert_id();	
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1728,e.encounter_id,e.encounter_datetime,e.location_id,vobs_id,
CASE WHEN o.concept_id=7014 AND o.value_boolean=1 THEN 133027
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7014 and o.value_boolean=1;		

		/*Migration for YES */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1729,e.encounter_id,e.encounter_datetime,e.location_id,vobs_id,
CASE WHEN o.concept_id=7014 AND o.value_boolean=1 THEN 1065
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7014 and o.value_boolean=1;
		/*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
		/*Migration for Perte de sensibilité*/
		/*Concept group*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1727,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7015 and o.value_boolean=1;

set vobs_id=last_insert_id();	
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1728,e.encounter_id,e.encounter_datetime,e.location_id,vobs_id,
CASE WHEN o.concept_id=7015 AND o.value_boolean=1 THEN 141635
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7015 and o.value_boolean=1;		

		/*Migration for YES */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1729,e.encounter_id,e.encounter_datetime,e.location_id,vobs_id,
CASE WHEN o.concept_id=7015 AND o.value_boolean=1 THEN 1065
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7015 and o.value_boolean=1;		
		/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
		/*Migration for Odynophagie/dysphagie*/
		/*Concept group*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1727,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7016 and o.value_boolean=1;

set vobs_id=last_insert_id();	
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1728,e.encounter_id,e.encounter_datetime,e.location_id,vobs_id,
CASE WHEN o.concept_id=7016 AND o.value_boolean=1 THEN 118789
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7016 and o.value_boolean=1;		

		/*Migration for YES */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1729,e.encounter_id,e.encounter_datetime,e.location_id,vobs_id,
CASE WHEN o.concept_id=7016 AND o.value_boolean=1 THEN 1065
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7024 and o.value_boolean=1;		
		/*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
		/*Migration for Eruption cutanée*/
		/*Concept group*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1727,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7024 and o.value_boolean=1;

set vobs_id=last_insert_id();	
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1728,e.encounter_id,e.encounter_datetime,e.location_id,vobs_id,
CASE WHEN o.concept_id=7024 AND o.value_boolean=1 THEN 512
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7024 and o.value_boolean=1;		

		/*Migration for YES */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1729,e.encounter_id,e.encounter_datetime,e.location_id,vobs_id,
CASE WHEN o.concept_id=7024 AND o.value_boolean=1 THEN 1065
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7024 and o.value_boolean=1;	
		/*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
		/*Migration for Vomissement*/
		/*Concept group*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1727,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7025 and o.value_boolean=1;

set vobs_id=last_insert_id();	
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1728,e.encounter_id,e.encounter_datetime,e.location_id,vobs_id,
CASE WHEN o.concept_id=7025 AND o.value_boolean=1 THEN 122983
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7025 and o.value_boolean=1;		

		/*Migration for YES */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1729,e.encounter_id,e.encounter_datetime,e.location_id,vobs_id,
CASE WHEN o.concept_id=7025 AND o.value_boolean=1 THEN 1065
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7025 and o.value_boolean=1;	

		/*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
		/*Migration for Prurigo*/
		/*Concept group*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1727,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7042 and o.value_boolean=1;

set vobs_id=last_insert_id();	
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1728,e.encounter_id,e.encounter_datetime,e.location_id,vobs_id,
CASE WHEN o.concept_id=7042 AND o.value_boolean=1 THEN 128319
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7042 and o.value_boolean=1;		

		/*Migration for YES */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1729,e.encounter_id,e.encounter_datetime,e.location_id,vobs_id,
CASE WHEN o.concept_id=7042 AND o.value_boolean=1 THEN 1065
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7042 and o.value_boolean=1;			

		/*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
		/*Migration for Autres, préciser :*/
		/*Concept group*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1727,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7044 and o.value_boolean=1 and value_text<>'';

set vobs_id=last_insert_id();	
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,comments,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1728,e.encounter_id,e.encounter_datetime,e.location_id,vobs_id,
CASE WHEN o.concept_id=7044 AND o.value_boolean=1 THEN 5622
	 ELSE NULL
END,o.value_text,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7044 and o.value_boolean=1 and value_text<>'';		

		/*Migration for YES */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1729,e.encounter_id,e.encounter_datetime,e.location_id,vobs_id,
CASE WHEN o.concept_id=7044 AND o.value_boolean=1 THEN 1065
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7044 and o.value_boolean=1 and value_text<>'';			
	/*END OF MIGRATION FOR SYMPTÔMES MENU*/

	
 
  
END;
