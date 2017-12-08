drop procedure if exists encounter_Migration;
DELIMITER $$ 

CREATE PROCEDURE encounter_Migration()
BEGIN
  DECLARE done INT DEFAULT FALSE;
 -- DECLARE a CHAR(16);
  DECLARE vstatus,mmmIndex INT;
  DECLARE vvisit_type_id INT;
  
DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE; 

create table if not exists itech.obs_concept_group (obs_id int,person_id int,concept_id int,encounter_id int);

create table if not exists itech.location_mapping 
select distinct value_reference as siteCode,location_id  from location_attribute l, location_attribute_type sl
where sl.name='iSanteSiteCode' and sl.location_attribute_type_id=l.attribute_type_id;
 

select visit_type_id into vvisit_type_id from visit_type where uuid='7b0f5697-27e3-40c4-8bae-f4049abfb4ed';

 /* Visit Migration
 * find all unique patientid, visitdate instances in the encounter table and consider these visits
 */
 SET SQL_SAFE_UPDATES = 0;
 

  /* remove old obs, visit and encounter data */
update obs set obs_group_id=null where encounter_id in (select encounter_id from encounter where encounter_type not in (select e.encounter_type_id from encounter_type e where uuid='873f968a-73a8-4f9c-ac78-9f4778b751b6'));
delete from obs where encounter_id in (select encounter_id from encounter where encounter_type not in (select e.encounter_type_id from encounter_type e where uuid='873f968a-73a8-4f9c-ac78-9f4778b751b6'));
delete from isanteplus_form_history;
delete from encounter where encounter_type not in (select e.encounter_type_id from encounter_type e where uuid='873f968a-73a8-4f9c-ac78-9f4778b751b6');


delete from visit;

/* Visit Migration */
INSERT INTO visit (patient_id, visit_type_id, date_started, date_stopped, location_id, creator, date_created, uuid)
SELECT DISTINCT p.person_id, vvisit_type_id, concat(e.visitDateYy,'-',e.visitDateMm,'-',e.visitDateDd), concat(e.visitDateYy,'-',e.visitDateMm,'-',e.visitDateDd), l.location_id,1, e.lastModified, UUID()
FROM person p, itech.patient it, itech.encounter e,itech.location_mapping l
WHERE p.uuid = it.patGuid AND it.patientid = e.patientid AND l.siteCode=e.siteCode AND
e.encounterType in (1,2,3,4,5,6,12,14,16,17,18,19,20,21,24,25,26,27,28,29,31,32);

select 1 as visit;

/* alter  itech.encounter table with uuid  if the column where not exists*/
IF NOT EXISTS( SELECT NULL
            FROM INFORMATION_SCHEMA.COLUMNS
           WHERE table_name = 'encounter'
             AND table_schema = 'itech'
             AND column_name = 'encGuid')  THEN
  ALTER TABLE itech.encounter ADD `encGuid` VARCHAR(36) NOT NULL;
END IF;

UPDATE itech.encounter SET encGuid=uuid();
  
 /* create index in table itech.encounter if index is not exists */ 
select count(*) into mmmIndex from information_schema.statistics where table_name = 'encounter' and index_name = 'eGuid' and table_schema ='itech';
if(mmmIndex=0) then    
CREATE UNIQUE INDEX eGuid ON itech.encounter (encGuid);
end if;
/* end update encounter itech table with uuid */

/* create mapping table with isante and isantePlus form */
CREATE TABLE if not exists itech.typeToForm (encounterType INT, form_id INT,encounterTypeOpenmrs INT, uuid VARCHAR(36));
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
( 17 , 'f55d3760-1bf1-4e42-a7f9-0a901fa49cf0' ),
( 32 , '42ad13ab-db20-4aed-b8d5-fa4ca15317ee' );
 
UPDATE itech.typeToForm i, form t SET i.form_id = t.form_id,i.encounterTypeOpenmrs=t.encounter_type where i.uuid = t.uuid; 
 
 /* create index on encounter table */
select count(*) into mmmIndex from information_schema.statistics where table_name = 'encounter' and index_name = 'mmm' and table_schema ='openmrs';
if(mmmIndex=0) then 
 create unique index mmm on encounter (patient_id,location_id,form_id,visit_id, encounter_datetime, encounter_type,date_created);
 end if;
 

/* encounter migration data */ 
INSERT INTO encounter(encounter_type,patient_id,location_id,form_id,visit_id, encounter_datetime,creator,date_created,date_changed,uuid)
SELECT ALL f.encounterTypeOpenmrs, p.person_id, v.location_id, f.form_id, v.visit_id,
concat(e.visitDateYy,'-',e.visitDateMm,'-',e.visitDateDd),1,e.createDate,e.lastModified,e.encGuid
FROM itech.encounter e, person p, itech.patient j, visit v, itech.typeToForm f
WHERE p.uuid = j.patGuid and 
e.patientID = j.patientID AND 
v.patient_id = p.person_id AND 
v.date_started = date(concat(e.visitDateYy,'-',e.visitDateMm,'-',e.visitDateDd)) AND 
e.encounterType in (1,2,3,4,5,6,12,14,16,17,18,19,20,21,24,25,26,27,28,29,31,32) AND
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

select 3 as encounter1;

/*migration for form history */
insert into isanteplus_form_history(visit_id,encounter_id,creator,date_created,uuid)
select visit_id,encounter_id,creator,date_created, uuid() from encounter e where encounter_type not in (select e.encounter_type_id from encounter_type e where uuid='873f968a-73a8-4f9c-ac78-9f4778b751b6') and form_id not in (1,2,3,4,5)
ON DUPLICATE KEY UPDATE
visit_id=values(visit_id),
encounter_id=values(encounter_id),
creator=values(creator),
date_created=values(date_created);

/*end of migration pour visit form history */

end;