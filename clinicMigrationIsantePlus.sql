DELIMITER $$ 
CREATE PROCEDURE clinicMigration()
BEGIN
  DECLARE done INT DEFAULT FALSE;
 -- DECLARE a CHAR(16);
  
  DECLARE @visit_type_id INT;
  DECLARE obs_datetime_,date_created_ datetime;

 
select visit_type_id into @visit_type_id from visit_type where uuid='7b0f5697-27e3-40c4-8bae-f4049abfb4ed';

 /* Visit Migration
 * find all unique patientid, visitdate instances in the encounter table and consider these visits
 */
INSERT INTO visit (patient_id, visit_type_id, date_started, date_stopped, location_id, creator, date_created, uuid)
SELECT DISTINCT p.person_id, @visit_type_id, ymdToDate(e.visitdateyy,e.visitdatemm,e.visitdatedd), ymdToDate(e.visitdateyy,e.visitdatemm,e.visitdatedd), it.location_id,1, e.lastModified, UUID()
FROM person p, itech.patient it, itech.encounter e
WHERE p.uuid = it.patGuid AND it.patientid = e.patientid AND
e.encounterType in (1,2,3,4,5,6,12,14,16,17,18,19,20,21,24,25,26,27,28,29,31);


ALTER TABLE itech.encounter ADD encGuid VARCHAR(36) NOT NULL;
UPDATE itech.encounter SET encGuid = UUID();
CREATE UNIQUE INDEX eGuid ON itech.encounter (encGuid);



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
ymdToDate(e.visitdateyy,e.visitdatemm,e.visitdatedd),1,e.createDate,e.lastModified,e.encGuid
FROM itech.encounter e, person p, itech.patient j, visit v, itech.typeToForm f
WHERE p.uuid = j.patGuid and 
e.patientID = j.patientID AND 
v.patient_id = p.person_id AND 
v.date_started = ymdToDate(e.visitdateyy,e.visitdatemm,e.visitdatedd) AND 
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
e.patientid = v.patientid and e.sitecode = v.sitecode and concat(e.visitdateyy,'-',e.visitdatemm,'-',e.visitdatedd) = concat(v.visitdateyy,'-',v.visitdatemm,'-',v.visitdatedd) and e.seqNum = v.seqNum AND 
(substring_index(replace(v.vitalTemp,',','.'),'.',2)+0 > 0 AND vitalTempUnits IS NOT NULL)


/*DATA Migration for vitals TA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,5085,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.vitalBPUnits=1 THEN substring_index(replace(v.vitalBp1+0,',','.'),'.',2)
WHEN v.vitalBPUnits=2 THEN substring_index(replace(v.vitalBp1+0,',','.'),'.',2)*10 END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and
c.sitecode = v.sitecode and e.encounter_datetime = concat(v.visitdateyy,'-',v.visitdatemm,'-',v.visitdatedd) AND 
substring_index(replace(v.vitalBp1,',','.'),'.',2) REGEXP '^[0-9\.]+$' and v.vitalBp1 IS NOT NULL AND v.vitalBp2 <> ''

INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,5086,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.vitalBPUnits=1 THEN substring_index(replace(v.vitalBp2,',','.'),'.',2)
WHEN v.vitalBPUnits=2 THEN substring_index(replace(v.vitalBp2,',','.'),'.',2)*10 END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and
c.sitecode = v.sitecode and e.encounter_datetime = concat(v.visitdateyy,'-',v.visitdatemm,'-',v.visitdatedd) AND 
substring_index(replace(v.vitalBp2,',','.'),'.',2) REGEXP '^[0-9\.]+$' and v.vitalBp2 IS NOT NULL AND v.vitalBp2 <> ''


/*DATA Migration for vitals POULS*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,5085,e.encounter_id,e.encounter_datetime,e.location_id,v.vitalHr,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and e.encounter_datetime = concat(v.visitdateyy,'-',v.visitdatemm,'-',v.visitdatedd) AND 
AND v.vitalHr<>'';


/*DATA Migration for vitals FR*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,5085,e.encounter_id,e.encounter_datetime,e.location_id,v.vitalRr,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and e.encounter_datetime = concat(v.visitdateyy,'-',v.visitdatemm,'-',v.visitdatedd) AND 
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
c.sitecode = v.sitecode and e.encounter_datetime = concat(v.visitdateyy,'-',v.visitdatemm,'-',v.visitdatedd) AND 
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
c.sitecode = v.sitecode and e.encounter_datetime = concat(v.visitdateyy,'-',v.visitdatemm,'-',v.visitdatedd) AND 
v.vitalWeight<>'';

/*END OF SIGNES VITAUX MENU*/


 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
  
END;
