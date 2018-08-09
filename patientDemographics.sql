drop procedure if exists patientDemographics;
DELIMITER $$ 

CREATE PROCEDURE patientDemographics()
BEGIN
  DECLARE done INT DEFAULT FALSE;
 -- DECLARE a CHAR(16);
  
  DECLARE obs_datetime_,date_created_ datetime;
  DECLARE uuid_ varchar(50);
  DECLARE encounter_type_ INT;


 
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

  /* Load person table, linking person.uuid to itech.patient.patGuid
 * use lastModified field from encounter for create_date
 * make patGuid from patient table primary key for all additional migration statements
 */
 create table if not exists itech.obs_concept_group (obs_id int,person_id int,concept_id int,encounter_id int);
 
 create table if not exists itech.location_mapping(siteCode text, location_id int(11)); 
 truncate  table itech.location_mapping;
INSERT INTO itech.location_mapping(siteCode,location_id)
select distinct value_reference as siteCode,location_id  from location_attribute l, location_attribute_type sl
where sl.name='iSanteSiteCode' and sl.location_attribute_type_id=l.attribute_type_id;
 

 
 SET SQL_SAFE_UPDATES = 0;
 /* remove obs and encounter data when script failled */
 update obs set obs_group_id=null where person_id in (select p.person_id from person p,itech.patient p1 where p1.patGuid=p.uuid);
 delete from obs where person_id in (select p.person_id from person p,itech.patient p1 where p1.patGuid=p.uuid);
 delete from isanteplus_form_history;
 delete from openmrs.encounter where patient_id in (select p.person_id from person p,itech.patient p1 where p1.patGuid=p.uuid);
 
 
alter table itech.patient modify person_id int not null;
alter table itech.patient drop primary key;
alter table itech.patient add primary key (patGuid);

INSERT INTO person (gender, birthdate, birthdate_estimated, dead, death_date, creator, date_created, uuid)
SELECT CASE WHEN sex = 1 THEN 'F' WHEN sex = 2 THEN 'M' ELSE 'U' END,
case when dobyy REGEXP '^[0-9]+$' and dobmm REGEXP '^[0-9]+$' and dobdd REGEXP '^[0-9]+$' AND (
(dobmm+0 IN (4,6,9,11) AND dobdd+0 BETWEEN 1 AND 30) OR (dobmm+0 IN (1,3,5,7,8,12) AND dobdd+0 BETWEEN 1 AND 31) OR (dobmm+0 = 2 AND dobdd+0 BETWEEN 1 and 28)) THEN DATE(CONCAT(dobyy,'-',dobmm,'-',dobdd)) else 
case when dobyy REGEXP '^[0-9]+$' and dobmm REGEXP '^[0-9]+$' AND dobmm+0 BETWEEN 1 AND 12 THEN DATE(CONCAT(dobyy,'-',dobmm,'-01')) else 
case when dobyy REGEXP '^[0-9]+$' THEN DATE(CONCAT(dobyy,'-01-01')) ELSE NULL END END END,
CASE WHEN ageYears is not null then 1 ELSE 0 END,
CASE WHEN date(deathDt) <> "0000-00-00" then 1 ELSE 0 END,
CASE WHEN date(deathDt) = "0000-00-00" then NULL ELSE deathDt END, 
1,e.visitDate, patGuid 
FROM itech.patient p,itech.encounter e
where p.location_id > 0 and p.patientID=e.patientID and e.encounterType in (10,15) ON DUPLICATE KEY UPDATE
gender=VALUES(gender),
birthdate=VALUES(birthdate),
birthdate_estimated=VALUES(birthdate_estimated),
dead=VALUES(dead),
death_date=VALUES(death_date),
creator=VALUES(creator),
date_created=VALUES(date_created);


select now() as person;
/* Load person name information
 * create unique index so that script can be rerun
 */
 
 IF((SELECT COUNT(*) AS index_exists FROM information_schema.statistics WHERE TABLE_SCHEMA = DATABASE() and table_name ='person_name' AND index_name = 'nameIndex')  = 0) THEN
   SET @s = 'CREATE UNIQUE INDEX nameIndex ON person_name (person_id,preferred, given_name, family_name)';
   PREPARE stmt FROM @s;
   EXECUTE stmt;
 END IF; 
 
-- CREATE UNIQUE INDEX nameIndex ON person_name (person_id, given_name, family_name); 
INSERT INTO person_name(person_id, preferred, given_name,family_name,creator, date_created, uuid)
SELECT distinct p.person_id, 1,left(fname,50), left(lname,50), 1,p.date_created, uuid()
FROM person p, itech.patient j where p.uuid = j.patGuid ON DUPLICATE KEY UPDATE
preferred      = VALUES(preferred),
given_name     = VALUES(given_name),
family_name    = VALUES(family_name),
creator        = VALUES(creator),
date_created   = VALUES(date_created);

select now() as personName;

/* Load person address information
 * create unique index so that script can be rerun
 */

  IF((SELECT COUNT(*) AS index_exists FROM information_schema.statistics WHERE TABLE_SCHEMA = DATABASE() and table_name ='person_address' AND index_name = 'addressIndex')  = 0) THEN
   SET @s = 'CREATE UNIQUE INDEX addressIndex ON person_address (person_id, address1, city_village)';
   PREPARE stmt FROM @s;
   EXECUTE stmt;
 END IF; 
 
-- CREATE UNIQUE INDEX addressIndex ON person_address (person_id, address1, city_village);
INSERT INTO person_address(person_id,   preferred, address1, city_village, creator, date_created, uuid)
SELECT distinct p.person_id, 1, addrDistrict, addrSection, 1, p.date_created, UUID()
FROM person p, itech.patient j where p.uuid = j.patGuid  and j.patStatus<255 ON DUPLICATE KEY UPDATE
preferred = VALUES(preferred), 
address1 = VALUES(address1), 
city_village = VALUES(city_village), 
creator = VALUES(creator), 
date_created = VALUES(date_created);
 
select now() as personAddress;
/* Load patient table
 */
INSERT INTO patient(patient_id,  creator, date_created)
SELECT  distinct p.person_id, 1, p.date_created
FROM person p, itech.patient j where p.uuid = j.patGuid and j.patStatus<255 ON DUPLICATE KEY UPDATE
creator = VALUES(creator),
date_created = VALUES(date_created);

select now() as patient;

/* create unique index so that script can be rerun
 */
 
   IF((SELECT COUNT(*) AS index_exists FROM information_schema.statistics WHERE TABLE_SCHEMA = DATABASE() and table_name ='patient_identifier' AND index_name = 'patIdentIndex')  = 0) THEN
   SET @s = 'CREATE UNIQUE INDEX patIdentIndex on patient_identifier (patient_id,identifier_type,identifier)';
   PREPARE stmt FROM @s;
   EXECUTE stmt;
 END IF; 
 
-- CREATE UNIQUE INDEX patIdentIndex on patient_identifier (patient_id,identifier_type,identifier);

/* Load patient identifiers from patient table
 * these identifiers come directly from isante patient table: 
 *   patientID (original iSanté internal identifier), 
 *   nationalid, isante ID
 *   masterPID (first iSanté patientID nationwide: assumes national fingerprint server in use), 
 *   clinicPatientID (ST code: HIV patients) 
*/
INSERT INTO patient_identifier(patient_id,  identifier, identifier_type, preferred, location_id, creator, date_created, uuid)
SELECT p.person_id, 
case when t.name = 'Code National' then left(j.nationalid,50)
     when t.name = 'Code ST' then left(j.clinicPatientID,50) 
	 when t.name = 'iSante ID' then left(j.patientID,50) end, t.patient_identifier_type_id, 1, l.location_id, 1, p.date_created,UUID()
FROM person p, itech.patient j, patient_identifier_type t , itech.location_mapping l
WHERE p.uuid = j.patGuid and j.patStatus<255 AND  l.siteCode=j.location_id AND (t.name = 'iSante ID' or t.name = 'Code ST' OR (t.name = 'Code National' and j.nationalid is not null and j.nationalid <> '') OR (t.name = 'Code ST' and j.clinicPatientID is not null and j.clinicPatientID <> '')) ON DUPLICATE KEY UPDATE
identifier=VALUES(identifier),
identifier_type=VALUES(identifier_type), 
preferred=VALUES(preferred), 
location_id=VALUES(location_id), 
creator=VALUES(creator), 
date_created=VALUES(date_created);

/* Numero TB*/
INSERT INTO patient_identifier(patient_id,  identifier, identifier_type, preferred, location_id, creator, date_created, uuid)
SELECT p.person_id, 
case when t.name = 'No. de dossier TB' then left(j.nationalid,50) end, t.patient_identifier_type_id, 1, l.location_id, 1, p.date_created,UUID()
FROM person p, itech.patient j, patient_identifier_type t , itech.location_mapping l,itech.tbStatus st
WHERE p.uuid = j.patGuid and st.patientID=j.patientID and j.patStatus<255 AND  l.siteCode=j.location_id AND (t.name = 'No. de dossier TB' and st.currentTreatNo is not null and st.currentTreatNo <> '') ON DUPLICATE KEY UPDATE
identifier=VALUES(identifier),
identifier_type=VALUES(identifier_type), 
preferred=VALUES(preferred), 
location_id=VALUES(location_id), 
creator=VALUES(creator), 
date_created=VALUES(date_created);
  
 
select now() as patientIdentifier;


/* insert person attribute */
   IF((SELECT COUNT(*) AS index_exists FROM information_schema.statistics WHERE TABLE_SCHEMA = DATABASE() and table_name ='person_attribute' AND index_name = 'personAttrIndex')  = 0) THEN
   SET @s = 'create unique index personAttrIndex on person_attribute (person_id, person_attribute_type_id, value);';
   PREPARE stmt FROM @s;
   EXECUTE stmt;
 END IF; 

INSERT INTO person_attribute (person_id, value, person_attribute_type_id, creator, date_created, uuid)
SELECT p.person_id, case 
when t.uuid = '8d871d18-c2cc-11de-8d13-0010c6dffd0f' then left(j.fnameMother,50)
when t.uuid= '14d4f066-15f5-102d-96e4-000c29c2a5d7' then left(j.telephone,50)
end, t.person_attribute_type_id,1, p.date_created, UUID()
FROM person p, itech.patient j, person_attribute_type t 
WHERE j.patGuid = p.uuid and j.patStatus<255 AND (
(t.uuid = '8d871d18-c2cc-11de-8d13-0010c6dffd0f' AND j.fnameMother IS NOT NULL AND j.fnameMother <> '') OR 
(t.uuid= '14d4f066-15f5-102d-96e4-000c29c2a5d7' AND j.telephone IS NOT NULL AND j.telephone <> '')
) ON DUPLICATE KEY UPDATE
value=VALUES(value), 
person_attribute_type_id=VALUES(person_attribute_type_id), 
creator=VALUES(creator), 
date_created=VALUES(date_created);



/*
insert encounter for registration patient
*/

insert into encounter(encounter_type,patient_id,location_id,encounter_datetime,creator,date_created,uuid)
select e.encounter_type_id,
p.person_id,l.location_id,p.date_created,1,p.date_created,uuid()
from person p,patient p1,itech.patient it,itech.location_mapping l,(select e.encounter_type_id from encounter_type e where uuid='873f968a-73a8-4f9c-ac78-9f4778b751b6'
) e where p.person_id=p1.patient_id and it.patGuid= p.uuid and it.location_id=l.siteCode
on duplicate key update 
encounter_type=values(encounter_type),
location_id=values(location_id),
encounter_datetime=values(encounter_datetime),
creator=values(creator),
date_created=values(date_created);


select now() as Encounter;

/* insert marital status into obs */
insert into obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
select p.person_id,1054 as concept_id,e.encounter_id,encounter_datetime as obs_datetime,e.location_id,
case WHEN j.maritalStatus=1 THEN 5555  -- marie
     WHEN j.maritalStatus=8 THEN 1056  -- separe
     WHEN j.maritalStatus=4 THEN 1059  -- veuve 
     else  5622
end as value_coded,
1,e.date_created,uuid() as uuid	 
from person p, itech.patient j, encounter e
 where j.patGuid = p.uuid and e.patient_id=p.person_id and e.visit_id is null
  and j.maritalStatus IS NOT NULL AND j.maritalStatus <> '';
  
  /* insert Occupation into obs */
insert into obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
select p.person_id,1542 as concept_id,e.encounter_id,encounter_datetime as obs_datetime,e.location_id,
case WHEN upper(j.occupation) like 'CHAUF%' or upper(j.occupation) like 'CHOF%' THEN 159466  
     else  1067
end as value_coded,
1,e.date_created,uuid() as uuid	 
from person p, itech.patient j, encounter e
 where j.patGuid = p.uuid and e.patient_id=p.person_id and e.visit_id is null
  and j.occupation IS NOT NULL AND j.occupation <> '';

/* birthDistrict */
	  /* migration group */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT p.person_id,164969,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
from person p, itech.patient j, encounter e
 where j.patGuid = p.uuid and e.patient_id=p.person_id and e.visit_id is null
and ((j.birthDistrict IS NOT NULL AND j.birthDistrict <> ''));
 
delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=164969 
GROUP BY openmrs.obs.person_id,encounter_id;

select now() as birthDistrict;
	
/* migration of contact*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT p.person_id,164958,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,j.birthDistrict ,1,e.date_created,UUID()
from person p, itech.patient j, encounter e,itech.obs_concept_group og
 where j.patGuid = p.uuid and e.patient_id=p.person_id and e.visit_id is null
 and og.person_id=e.patient_id and e.encounter_id=og.encounter_id 
and ((j.birthDistrict IS NOT NULL AND j.birthDistrict <> '')
 );	

 select now() as obs1;
                
/*Emergency contact */	
	  /* migration group */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT p.person_id,164968,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
from person p, itech.patient j, encounter e
 where j.patGuid = p.uuid and e.patient_id=p.person_id and e.visit_id is null
and ((j.contact IS NOT NULL AND j.contact <> '') or 
     (j.phoneContact IS NOT NULL AND j.phoneContact <> '') or
     (j.addrContact IS NOT NULL AND j.addrContact <> '') or
     (j.relationContact IS NOT NULL AND j.relationContact <> '')
 );
 
delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=164968 
GROUP BY openmrs.obs.person_id,encounter_id;
	
/* migration of contact*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT p.person_id,164950,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,j.contact ,1,e.date_created,UUID()
from person p, itech.patient j, encounter e,itech.obs_concept_group og
 where j.patGuid = p.uuid and e.patient_id=p.person_id and e.visit_id is null
 and og.person_id=e.patient_id and e.encounter_id=og.encounter_id 
and ((j.contact IS NOT NULL AND j.contact <> '')
 );	
 
 /* migration of Telephone contact*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT p.person_id,164956,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,j.phoneContact ,1,e.date_created,UUID()
from person p, itech.patient j, encounter e,itech.obs_concept_group og
 where j.patGuid = p.uuid and e.patient_id=p.person_id and e.visit_id is null
  and og.person_id=e.patient_id and e.encounter_id=og.encounter_id 
and ((j.phoneContact IS NOT NULL AND j.phoneContact <> '')
 );	
	
 /* migration of address contact*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT p.person_id,164958,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,j.addrContact ,1,e.date_created,UUID()
from person p, itech.patient j, encounter e,itech.obs_concept_group og
 where j.patGuid = p.uuid and e.patient_id=p.person_id and e.visit_id is null
  and og.person_id=e.patient_id and e.encounter_id=og.encounter_id 
and ((j.addrContact IS NOT NULL AND j.addrContact <> '')
 );
 
  /* migration of RelationShip contact*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT p.person_id,164352,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
  case 
        when (UPPER(j.relationContact)='PERE' or UPPER(j.relationContact)='PAPA')  then '971'
        when (UPPER(j.relationContact)='MERE' or UPPER(j.relationContact)='MANMAN' or UPPER(j.relationContact)='MAMAN')  then '970'
        when (UPPER(j.relationContact)='ONCLE' or UPPER(j.relationContact)='TONTON' or UPPER(j.relationContact)='UNCLE')  then '974'
        when (UPPER(j.relationContact)='GRAND PERE' or UPPER(j.relationContact)='GRAND PAPA' or UPPER(j.relationContact)='GRAN PAPA')  then '973'
        when (UPPER(j.relationContact)='TANTE' or UPPER(j.relationContact)='MATANT' or UPPER(j.relationContact)='MA TANTE')  then '975'
        when (UPPER(j.relationContact)='AMI' or UPPER(j.relationContact)='AMIS' or UPPER(j.relationContact)='ZANMI')  then  '5618'
        else '5622'
   end  ,1,e.date_created,UUID()
from person p, itech.patient j, encounter e,itech.obs_concept_group og
 where j.patGuid = p.uuid and e.patient_id=p.person_id and e.visit_id is null
  and og.person_id=e.patient_id and e.encounter_id=og.encounter_id 
and ((j.relationContact IS NOT NULL AND j.relationContact <> '')
 );		
 

 
/*Disclosure contact  */
 
 	  /* migration group */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT p.person_id,164959,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
from person p, itech.patient j, encounter e
 where j.patGuid = p.uuid and e.patient_id=p.person_id and e.visit_id is null
and ((j.medicalPoa IS NOT NULL AND j.medicalPoa <> '') or 
     (j.phoneMedicalPoa IS NOT NULL AND j.phoneMedicalPoa <> '') or
     (j.addrMedicalPoa IS NOT NULL AND j.addrMedicalPoa <> '') or
     (j.relationMedicalPoa IS NOT NULL AND j.relationMedicalPoa <> '')
 );

  
delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=164959 
GROUP BY openmrs.obs.person_id,encounter_id;
	
/* migration of contact*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT p.person_id,164950,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,j.medicalPoa ,1,e.date_created,UUID()
from person p, itech.patient j, encounter e,itech.obs_concept_group og
 where j.patGuid = p.uuid and e.patient_id=p.person_id and e.visit_id is null
 and og.person_id=e.patient_id and e.encounter_id=og.encounter_id 
and ((j.medicalPoa IS NOT NULL AND j.medicalPoa <> '')
 );	
 
 /* migration of Telephone contact*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT p.person_id,164956,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,j.phoneMedicalPoa ,1,e.date_created,UUID()
from person p, itech.patient j, encounter e,itech.obs_concept_group og
 where j.patGuid = p.uuid and e.patient_id=p.person_id and e.visit_id is null
  and og.person_id=e.patient_id and e.encounter_id=og.encounter_id 
and ((j.phoneMedicalPoa IS NOT NULL AND j.phoneMedicalPoa <> '')
 );	
	
 /* migration of address contact*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT p.person_id,164958,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,j.addrMedicalPoa ,1,e.date_created,UUID()
from person p, itech.patient j, encounter e,itech.obs_concept_group og
 where j.patGuid = p.uuid and e.patient_id=p.person_id and e.visit_id is null
  and og.person_id=e.patient_id and e.encounter_id=og.encounter_id 
and ((j.addrMedicalPoa IS NOT NULL AND j.addrMedicalPoa <> '')
 );
 
  /* migration of RelationShip contact*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT p.person_id,164352,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
  case 
        when (UPPER(j.relationMedicalPoa)='PERE' or UPPER(j.relationMedicalPoa)='PAPA')  then '971'
        when (UPPER(j.relationMedicalPoa)='MERE' or UPPER(j.relationMedicalPoa)='MANMAN' or UPPER(j.relationMedicalPoa)='MAMAN')  then '970'
        when (UPPER(j.relationMedicalPoa)='ONCLE' or UPPER(j.relationMedicalPoa)='TONTON' or UPPER(j.relationMedicalPoa)='UNCLE')  then '974'
        when (UPPER(j.relationMedicalPoa)='GRAND PERE' or UPPER(j.relationMedicalPoa)='GRAND PAPA' or UPPER(j.relationMedicalPoa)='GRAN PAPA')  then '973'
        when (UPPER(j.relationMedicalPoa)='TANTE' or UPPER(j.relationMedicalPoa)='MATANT' or UPPER(j.relationMedicalPoa)='MA TANTE')  then '975'
        when (UPPER(j.relationMedicalPoa)='AMI' or UPPER(j.relationMedicalPoa)='AMIS' or UPPER(j.relationMedicalPoa)='ZANMI')  then  '5618'
        else '5622'
   end  ,1,e.date_created,UUID()
from person p, itech.patient j, encounter e,itech.obs_concept_group og
 where j.patGuid = p.uuid and e.patient_id=p.person_id and e.visit_id is null
  and og.person_id=e.patient_id and e.encounter_id=og.encounter_id 
and ((j.relationMedicalPoa IS NOT NULL AND j.relationMedicalPoa <> '')
 );		
 
 
/*Medical Pao Contact  1 */
 
 	  /* migration group */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT p.person_id,164965,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
from person p, itech.patient j, encounter e,itech.allowedDisclosures a
 where j.patGuid = p.uuid and e.patient_id=p.person_id and e.visit_id is null and a.patientID=j.patientID and disclosureSlot=1
and ((a.disclosureName IS NOT NULL AND a.disclosureName <> '') or 
     (a.disclosureRel IS NOT NULL AND a.disclosureRel <> '') or
     (a.disclosureAddress IS NOT NULL AND a.disclosureAddress <> '') or
     (a.disclosureTelephone IS NOT NULL AND a.disclosureTelephone <> '')
 );

 
  
delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=164965 
GROUP BY openmrs.obs.person_id,encounter_id;
	
/* migration of contact*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT p.person_id,164950,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,a.disclosureName,1,e.date_created,UUID()
from person p, itech.patient j, encounter e,itech.allowedDisclosures a,itech.obs_concept_group og
 where j.patGuid = p.uuid and e.patient_id=p.person_id and e.visit_id is null and a.patientID=j.patientID and disclosureSlot=1
  and og.person_id=e.patient_id and e.encounter_id=og.encounter_id 
and ((a.disclosureName IS NOT NULL AND a.disclosureName <> ''));

 
 /* migration of Telephone contact*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT p.person_id,164956,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,a.disclosureTelephone,1,e.date_created,UUID()
from person p, itech.patient j, encounter e,itech.allowedDisclosures a,itech.obs_concept_group og
 where j.patGuid = p.uuid and e.patient_id=p.person_id and e.visit_id is null and a.patientID=j.patientID and disclosureSlot=1
  and og.person_id=e.patient_id and e.encounter_id=og.encounter_id 
and ((a.disclosureTelephone IS NOT NULL AND a.disclosureTelephone <> ''));

 /* migration of address contact*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT p.person_id,164958,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,a.disclosureAddress,1,e.date_created,UUID()
from person p, itech.patient j, encounter e,itech.allowedDisclosures a,itech.obs_concept_group og
 where j.patGuid = p.uuid and e.patient_id=p.person_id and e.visit_id is null and a.patientID=j.patientID and disclosureSlot=1
  and og.person_id=e.patient_id and e.encounter_id=og.encounter_id 
and ((a.disclosureAddress IS NOT NULL AND a.disclosureAddress <> ''));
 
  /* migration of RelationShip contact*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT p.person_id,164352,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
  case 
        when (UPPER(a.disclosureRel)='PERE' or UPPER(a.disclosureRel)='PAPA')  then '971'
        when (UPPER(a.disclosureRel)='MERE' or UPPER(a.disclosureRel)='MANMAN' or UPPER(a.disclosureRel)='MAMAN')  then '970'
        when (UPPER(a.disclosureRel)='ONCLE' or UPPER(a.disclosureRel)='TONTON' or UPPER(a.disclosureRel)='UNCLE')  then '974'
        when (UPPER(a.disclosureRel)='GRAND PERE' or UPPER(a.disclosureRel)='GRAND PAPA' or UPPER(a.disclosureRel)='GRAN PAPA')  then '973'
        when (UPPER(a.disclosureRel)='TANTE' or UPPER(a.disclosureRel)='MATANT' or UPPER(a.disclosureRel)='MA TANTE')  then '975'
        when (UPPER(a.disclosureRel)='AMI' or UPPER(a.disclosureRel)='AMIS' or UPPER(a.disclosureRel)='ZANMI')  then  '5618'
        else '5622'
   end  ,1,e.date_created,UUID()
from person p, itech.patient j, encounter e,itech.allowedDisclosures a,itech.obs_concept_group og
 where j.patGuid = p.uuid and e.patient_id=p.person_id and e.visit_id is null and a.patientID=j.patientID and disclosureSlot=1
  and og.person_id=e.patient_id and e.encounter_id=og.encounter_id 
and ((a.disclosureRel IS NOT NULL AND a.disclosureRel <> ''));		
	


/*Medical Pao Contact  2 */
 
 	  /* migration group */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT p.person_id,164961,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
from person p, itech.patient j, encounter e,itech.allowedDisclosures a
 where j.patGuid = p.uuid and e.patient_id=p.person_id and e.visit_id is null and a.patientID=j.patientID and disclosureSlot=2
and ((a.disclosureName IS NOT NULL AND a.disclosureName <> '') or 
     (a.disclosureRel IS NOT NULL AND a.disclosureRel <> '') or
     (a.disclosureAddress IS NOT NULL AND a.disclosureAddress <> '') or
     (a.disclosureTelephone IS NOT NULL AND a.disclosureTelephone <> '')
 );

 
  
delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=164961 
GROUP BY openmrs.obs.person_id,encounter_id;
	
/* migration of contact*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT p.person_id,164950,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,a.disclosureName,1,e.date_created,UUID()
from person p, itech.patient j, encounter e,itech.allowedDisclosures a,itech.obs_concept_group og
 where j.patGuid = p.uuid and e.patient_id=p.person_id and e.visit_id is null and a.patientID=j.patientID and disclosureSlot=2
  and og.person_id=e.patient_id and e.encounter_id=og.encounter_id 
and ((a.disclosureName IS NOT NULL AND a.disclosureName <> ''));

 
 /* migration of Telephone contact*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT p.person_id,164956,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,a.disclosureTelephone,1,e.date_created,UUID()
from person p, itech.patient j, encounter e,itech.allowedDisclosures a,itech.obs_concept_group og
 where j.patGuid = p.uuid and e.patient_id=p.person_id and e.visit_id is null and a.patientID=j.patientID and disclosureSlot=2
  and og.person_id=e.patient_id and e.encounter_id=og.encounter_id 
and ((a.disclosureTelephone IS NOT NULL AND a.disclosureTelephone <> ''));

 /* migration of address contact*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT p.person_id,164958,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,a.disclosureAddress,1,e.date_created,UUID()
from person p, itech.patient j, encounter e,itech.allowedDisclosures a,itech.obs_concept_group og
 where j.patGuid = p.uuid and e.patient_id=p.person_id and e.visit_id is null and a.patientID=j.patientID and disclosureSlot=2
  and og.person_id=e.patient_id and e.encounter_id=og.encounter_id 
and ((a.disclosureAddress IS NOT NULL AND a.disclosureAddress <> ''));
 
  /* migration of RelationShip contact*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT p.person_id,164352,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
  case 
        when (UPPER(a.disclosureRel)='PERE' or UPPER(a.disclosureRel)='PAPA')  then '971'
        when (UPPER(a.disclosureRel)='MERE' or UPPER(a.disclosureRel)='MANMAN' or UPPER(a.disclosureRel)='MAMAN')  then '970'
        when (UPPER(a.disclosureRel)='ONCLE' or UPPER(a.disclosureRel)='TONTON' or UPPER(a.disclosureRel)='UNCLE')  then '974'
        when (UPPER(a.disclosureRel)='GRAND PERE' or UPPER(a.disclosureRel)='GRAND PAPA' or UPPER(a.disclosureRel)='GRAN PAPA')  then '973'
        when (UPPER(a.disclosureRel)='TANTE' or UPPER(a.disclosureRel)='MATANT' or UPPER(a.disclosureRel)='MA TANTE')  then '975'
        when (UPPER(a.disclosureRel)='AMI' or UPPER(a.disclosureRel)='AMIS' or UPPER(a.disclosureRel)='ZANMI')  then  '5618'
        else '5622'
   end  ,1,e.date_created,UUID()
from person p, itech.patient j, encounter e,itech.allowedDisclosures a,itech.obs_concept_group og
 where j.patGuid = p.uuid and e.patient_id=p.person_id and e.visit_id is null and a.patientID=j.patientID and disclosureSlot=2
  and og.person_id=e.patient_id and e.encounter_id=og.encounter_id 
and ((a.disclosureRel IS NOT NULL AND a.disclosureRel <> ''));			
 
 
 select now() endDemo;
END;
