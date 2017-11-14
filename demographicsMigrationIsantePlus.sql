<<<<<<< HEAD
DELIMITER $$ 
CREATE PROCEDURE patientDemographics()
BEGIN
  DECLARE done INT DEFAULT FALSE;
 -- DECLARE a CHAR(16);
  
  DECLARE obs_datetime_,date_created_ datetime;
  DECLARE uuid_ varchar(50);
  DECLARE contact_,phoneContact_,addrContact_,relationContact_,medicalPoa_,relationMedicalPoa_,addrMedicalPoa_,phoneMedicalPoa_ TEXT;
  DECLARE disclosureName_,disclosureRel_,disclosureAddress_,disclosureTelephone_ TEXT;
  DECLARE person_id_,encounter_id_,location_id_,creator_,disclosureSlot_ INT;
  DECLARE encounter_type_ INT;
  DECLARE concept_relation,relationMedicalPoa_concept, disclosureRelation_concept,obs_id INT;


  
  DECLARE emergencyCursor CURSOR FOR select p.person_id,e.encounter_id,encounter_datetime as obs_datetime,1 as location_id,p.creator,e.date_created,uuid() as uuid,contact,phoneContact,addrContact,relationContact,
medicalPoa,relationMedicalPoa,addrMedicalPoa,phoneMedicalPoa
from person p, itech.patient j, encounter e
 where j.patGuid = p.uuid and e.patient_id=p.person_id and e.visit_id is null
and ((j.contact IS NOT NULL AND j.contact <> '') or 
     (j.phoneContact IS NOT NULL AND j.phoneContact <> '') or
     (j.addrContact IS NOT NULL AND j.addrContact <> '') or
     (j.relationContact IS NOT NULL AND j.relationContact <> '')
 );
 
 
 DECLARE disclosureCursor CURSOR FOR   select p.person_id,e.encounter_id,encounter_datetime as obs_datetime,1 as location_id,
 p.creator,e.date_created,uuid() as uuid,disclosureName,disclosureRel,disclosureAddress,disclosureTelephone,disclosureSlot	 
from person p, itech.patient j,itech.allowedDisclosures a, encounter e
 where j.patGuid = p.uuid and e.patient_id=p.person_id and a.patientID=j.patientID and e.visit_id is null;
 
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

  /* Load person table, linking person.uuid to itech.patient.patGuid
 * use lastModified field from encounter for create_date
 * make patGuid from patient table primary key for all additional migration statements
 */
 
 
 /* remove obs and encounter data when script failled */
 update obs set obs_group_id=null where person_id in (select p.person_id from person p,itech.patient p1 where p1.patGuid=p.uuid);
 delete from obs where person_id in (select p.person_id from person p,itech.patient p1 where p1.patGuid=p.uuid);
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
SELECT distinct p.person_id, 1,left(replace(fname, ' ',''),50), left(replace(lname,' ',''),50), 1,p.date_created, uuid()
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
FROM person p, itech.patient j where p.uuid = j.patGuid ON DUPLICATE KEY UPDATE
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
FROM person p, itech.patient j where p.uuid = j.patGuid ON DUPLICATE KEY UPDATE
creator = VALUES(creator),
date_created = VALUES(date_created);

select now() as patient;
/* Load iSanté patient identifier types    
 */ 
/*INSERT INTO patient_identifier_type (patient_identifier_type_id, name, description, creator, date_created) VALUES 
(20,'Haiti NationalID','Haiti NationalID',1,now()),
(21,'masterPID','masterPID',1,now()),
(22,'obgynID','obgynID',1,now()),
(23,'primCareID','primCareID',1,now()),
(24,'clinicPatientID','clinicPatientID',1,now()),
(25,'iSante PatientID','iSante PatientID',1,now());
*/






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
 *   nationalid, 
 *   masterPID (first iSanté patientID nationwide: assumes national fingerprint server in use), 
 *   clinicPatientID (ST code: HIV patients) 
*/
INSERT INTO patient_identifier(patient_id,  identifier, identifier_type, preferred, location_id, creator, date_created, uuid)
SELECT p.person_id, case when t.name = 'Code National' then left(j.nationalid,50)
when t.name = 'Code ST' then left(j.clinicPatientID,50) end, t.patient_identifier_type_id, 1, 1, 1, p.date_created,UUID()
FROM person p, itech.patient j, patient_identifier_type t 
WHERE p.uuid = j.patGuid AND (t.name = 'Code ST' OR (t.name = 'Code National' and j.nationalid is not null and j.nationalid <> '') OR (t.name = 'Code ST' and j.clinicPatientID is not null and j.clinicPatientID <> '')) ON DUPLICATE KEY UPDATE
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
WHERE j.patGuid = p.uuid AND (
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
person_id,1,p.date_created,1,p.date_created,uuid()
from person p,patient p1, (select e.encounter_type_id from encounter_type e where uuid='873f968a-73a8-4f9c-ac78-9f4778b751b6'
) e where p.person_id=p1.patient_id on duplicate key update 
encounter_type=values(encounter_type),
location_id=values(location_id),
encounter_datetime=values(encounter_datetime),
creator=values(creator),
date_created=values(date_created);


select now() as Encounter;

/* insert marital status into obs */
insert into obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
select p.person_id,'1054' as concept_id,e.encounter_id,encounter_datetime as obs_datetime,e.location_id,
case WHEN j.maritalStatus=1 THEN 5555  -- marie
     WHEN j.maritalStatus=8 THEN 1056  -- separe
     WHEN j.maritalStatus=4 THEN 1059  -- veuve 
     else  5622
end as value_coded,
1,e.date_created,uuid() as uuid	 
from person p, itech.patient j, encounter e
 where j.patGuid = p.uuid and e.patient_id=p.person_id and e.visit_id is null
  and j.maritalStatus IS NOT NULL AND j.maritalStatus <> '';

 select now() as obs1;


  OPEN emergencyCursor;
  OPEN disclosureCursor;

  emergency_loop: LOOP
    FETCH emergencyCursor INTO person_id_,encounter_id_,obs_datetime_,location_id_,creator_,date_created_,uuid_,contact_,phoneContact_,addrContact_,relationContact_,medicalPoa_,relationMedicalPoa_,addrMedicalPoa_,phoneMedicalPoa_;
    IF done THEN
      LEAVE emergency_loop;
    END IF;
	
/* insert emergency contact */	

case relationContact_
when (UPPER(relationContact_)='PERE' or UPPER(relationContact_)='PAPA')  then set concept_relation='971';
when (UPPER(relationContact_)='MERE' or UPPER(relationContact_)='MANMAN' or UPPER(relationContact_)='MAMAN')  then set concept_relation='970';
when (UPPER(relationContact_)='ONCLE' or UPPER(relationContact_)='TONTON' or UPPER(relationContact_)='UNCLE')  then set concept_relation='974';
when (UPPER(relationContact_)='GRAND PERE' or UPPER(relationContact_)='GRAND PAPA' or UPPER(relationContact_)='GRAN PAPA')  then set concept_relation='973';
when (UPPER(relationContact_)='TANTE' or UPPER(relationContact_)='MATANT' or UPPER(relationContact_)='MA TANTE')  then set concept_relation='975';
when (UPPER(relationContact_)='AMI' or UPPER(relationContact_)='AMIS' or UPPER(relationContact_)='ZANMI')  then set concept_relation='5618';
else set concept_relation='5622';
end case;

case relationMedicalPoa_
when (UPPER(relationMedicalPoa_)='PERE' or UPPER(relationMedicalPoa_)='PAPA')  then set relationMedicalPoa_concept='971';
when (UPPER(relationMedicalPoa_)='MERE' or UPPER(relationMedicalPoa_)='MANMAN' or UPPER(relationMedicalPoa_)='MAMAN')  then set relationMedicalPoa_concept='970';
when (UPPER(relationMedicalPoa_)='ONCLE' or UPPER(relationMedicalPoa_)='TONTON' or UPPER(relationMedicalPoa_)='UNCLE')  then set relationMedicalPoa_concept='974';
when (UPPER(relationMedicalPoa_)='GRAND PERE' or UPPER(relationMedicalPoa_)='GRAND PAPA' or UPPER(relationMedicalPoa_)='GRAN PAPA')  then set relationMedicalPoa_concept='973';
when (UPPER(relationMedicalPoa_)='TANTE' or UPPER(relationMedicalPoa_)='MATANT' or UPPER(relationMedicalPoa_)='MA TANTE')  then set relationMedicalPoa_concept='975';
when (UPPER(relationMedicalPoa_)='AMI' or UPPER(relationMedicalPoa_)='AMIS' or UPPER(relationMedicalPoa_)='ZANMI')  then set relationMedicalPoa_concept='5618';
else set relationMedicalPoa_concept='5622';
end case;


insert into obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
values (person_id_,'164966',encounter_id_,obs_datetime_,location_id_,creator_,date_created_,uuid_);

set obs_id=last_insert_id();
	
insert into obs(person_id,concept_id,encounter_id,obs_group_id,obs_datetime,location_id,value_text,creator,date_created,uuid)
values (person_id_,'164950',encounter_id_,obs_id,obs_datetime_,location_id_,contact_,creator_,date_created_,uuid()), -- contact
       (person_id_,'164956',encounter_id_,obs_id,obs_datetime_,location_id_,phoneContact_,creator_,date_created_,uuid()), -- phone contact
       (person_id_,'164949',encounter_id_,obs_id,obs_datetime_,location_id_,addrContact_,creator_,date_created_,uuid()) ;  -- address contact  	   

insert into obs(person_id,concept_id,encounter_id,obs_group_id,obs_datetime,location_id,value_coded,comments,creator,date_created,uuid)
values (person_id_,'164352',encounter_id_,obs_id,obs_datetime_,location_id_,concept_relation,relationContact_,creator_,date_created_,uuid()); -- relationship
/* insert poa contact */	
insert into obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
values (person_id_,'164959',encounter_id_,obs_datetime_,location_id_,creator_,date_created_,uuid());

set obs_id=last_insert_id();

insert into obs(person_id,concept_id,encounter_id,obs_group_id,obs_datetime,location_id,value_text,creator,date_created,uuid)
values (person_id_,'164950',encounter_id_,obs_id,obs_datetime_,location_id_,medicalPoa_,creator_,date_created_,uuid()), -- contact
       (person_id_,'164956',encounter_id_,obs_id,obs_datetime_,location_id_,phoneMedicalPoa_,creator_,date_created_,uuid()), -- phone contact
       (person_id_,'164949',encounter_id_,obs_id,obs_datetime_,location_id_,addrMedicalPoa_,creator_,date_created_,uuid()) ;  -- address contact  
	
insert into obs(person_id,concept_id,encounter_id,obs_group_id,obs_datetime,location_id,value_coded,comments,creator,date_created,uuid)
values (person_id_,'164352',encounter_id_,obs_id,obs_datetime_,location_id_,relationMedicalPoa_concept,relationMedicalPoa_,creator_,date_created_,uuid()); 	
	
  select now() as obs2,contact_; 
  END LOOP;
  
  CLOSE emergencyCursor;
  
   
  disclosure_loop: LOOP
    FETCH disclosureCursor INTO person_id_,encounter_id_,obs_datetime_,location_id_,creator_,date_created_,uuid_,disclosureName_,disclosureRel_,disclosureAddress_,disclosureTelephone_,disclosureSlot_;
    IF done THEN
      LEAVE disclosure_loop;
    END IF;
	
case disclosureRel_
when (UPPER(disclosureRel_)='PERE' or UPPER(disclosureRel_)='PAPA')  then set disclosureRelation_concept='971';
when (UPPER(disclosureRel_)='MERE' or UPPER(disclosureRel_)='MANMAN' or UPPER(disclosureRel_)='MAMAN')  then set disclosureRelation_concept='970';
when (UPPER(disclosureRel_)='ONCLE' or UPPER(disclosureRel_)='TONTON' or UPPER(disclosureRel_)='UNCLE')  then set disclosureRelation_concept='974';
when (UPPER(disclosureRel_)='GRAND PERE' or UPPER(disclosureRel_)='GRAND PAPA' or UPPER(disclosureRel_)='GRAN PAPA')  then set disclosureRelation_concept='973';
when (UPPER(disclosureRel_)='TANTE' or UPPER(disclosureRel_)='MATANT' or UPPER(disclosureRel_)='MA TANTE')  then set disclosureRelation_concept='975';
when (UPPER(disclosureRel_)='AMI' or UPPER(disclosureRel_)='AMIS' or UPPER(disclosureRel_)='ZANMI')  then set disclosureRelation_concept='5618';
else set disclosureRelation_concept='5622';
end case;	
	
/* insert disclosure contact */	
insert into obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
values (person_id_,'164963',encounter_id_,obs_datetime_,location_id_,creator_,date_created_,uuid());

set obs_id=last_insert_id();
	
insert into obs(person_id,concept_id,encounter_id,obs_group_id,obs_datetime,location_id,value_text,creator,date_created,uuid)
values (person_id_,'164950',encounter_id_,obs_id,obs_datetime_,location_id_,disclosureName_,creator_,date_created_,uuid()), -- contact
       (person_id_,'164956',encounter_id_,obs_id,obs_datetime_,location_id_,disclosureTelephone_,creator_,date_created_,uuid()), -- phone contact
       (person_id_,'164949',encounter_id_,obs_idobs_datetime_,location_id_,disclosureAddress_,creator_,date_created_,uuid()) ;  -- address contact  	   

insert into obs(person_id,concept_id,encounter_id,obs_group_id,obs_datetime,location_id,value_coded,comments,creator,date_created,uuid)
values (person_id_,'164352',encounter_id_,obs_id,obs_datetime_,location_id_,disclosureRelation_concept,disclosureRel_,creator_,date_created_,uuid()); -- relationship	   
	   
	   
	   
  END LOOP;

  CLOSE disclosureCursor;
  
END;
=======
DELIMITER $$ 
CREATE PROCEDURE patientDemographics()
BEGIN
  DECLARE done INT DEFAULT FALSE;
 -- DECLARE a CHAR(16);
  
  DECLARE obs_datetime_,date_created_ datetime;
  DECLARE uuid_ varchar(50);
  DECLARE contact_,phoneContact_,addrContact_,relationContact_,medicalPoa_,relationMedicalPoa_,addrMedicalPoa_,phoneMedicalPoa_ TEXT;
  DECLARE disclosureName_,disclosureRel_,disclosureAddress_,disclosureTelephone_ TEXT;
  DECLARE person_id_,encounter_id_,location_id_,creator_,disclosureSlot_ INT;
  DECLARE encounter_type_ INT;
  DECLARE concept_relation,relationMedicalPoa_concept, disclosureRelation_concept,obs_id INT;


  
  DECLARE emergencyCursor CURSOR FOR select p.person_id,e.encounter_id,encounter_datetime as obs_datetime,1 as location_id,p.creator,e.date_created,uuid() as uuid,contact,phoneContact,addrContact,relationContact,
medicalPoa,relationMedicalPoa,addrMedicalPoa,phoneMedicalPoa
from person p, itech.patient j, encounter e
 where j.patGuid = p.uuid and e.patient_id=p.person_id and e.visit_id is null
and ((j.contact IS NOT NULL AND j.contact <> '') or 
     (j.phoneContact IS NOT NULL AND j.phoneContact <> '') or
     (j.addrContact IS NOT NULL AND j.addrContact <> '') or
     (j.relationContact IS NOT NULL AND j.relationContact <> '')
 );
 
 
 DECLARE disclosureCursor CURSOR FOR   select p.person_id,e.encounter_id,encounter_datetime as obs_datetime,1 as location_id,
 p.creator,e.date_created,uuid() as uuid,disclosureName,disclosureRel,disclosureAddress,disclosureTelephone,disclosureSlot	 
from person p, itech.patient j,itech.allowedDisclosures a, encounter e
 where j.patGuid = p.uuid and e.patient_id=p.person_id and a.patientID=j.patientID and e.visit_id is null;
 
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

  /* Load person table, linking person.uuid to itech.patient.patGuid
 * use lastModified field from encounter for create_date
 * make patGuid from patient table primary key for all additional migration statements
 */
 
 
 /* remove obs and encounter data when script failled */
 update obs set obs_group_id=null where person_id in (select p.person_id from person p,itech.patient p1 where p1.patGuid=p.uuid);
 delete from obs where person_id in (select p.person_id from person p,itech.patient p1 where p1.patGuid=p.uuid);
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
SELECT distinct p.person_id, 1,left(replace(fname, ' ',''),50), left(replace(lname,' ',''),50), 1,p.date_created, uuid()
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
FROM person p, itech.patient j where p.uuid = j.patGuid ON DUPLICATE KEY UPDATE
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
FROM person p, itech.patient j where p.uuid = j.patGuid ON DUPLICATE KEY UPDATE
creator = VALUES(creator),
date_created = VALUES(date_created);

select now() as patient;
/* Load iSanté patient identifier types    
 */ 
/*INSERT INTO patient_identifier_type (patient_identifier_type_id, name, description, creator, date_created) VALUES 
(20,'Haiti NationalID','Haiti NationalID',1,now()),
(21,'masterPID','masterPID',1,now()),
(22,'obgynID','obgynID',1,now()),
(23,'primCareID','primCareID',1,now()),
(24,'clinicPatientID','clinicPatientID',1,now()),
(25,'iSante PatientID','iSante PatientID',1,now());
*/






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
 *   nationalid, 
 *   masterPID (first iSanté patientID nationwide: assumes national fingerprint server in use), 
 *   clinicPatientID (ST code: HIV patients) 
*/
INSERT INTO patient_identifier(patient_id,  identifier, identifier_type, preferred, location_id, creator, date_created, uuid)
SELECT p.person_id, case when t.name = 'Code National' then left(j.nationalid,50)
when t.name = 'Code ST' then left(j.clinicPatientID,50) end, t.patient_identifier_type_id, 1, 1, 1, p.date_created,UUID()
FROM person p, itech.patient j, patient_identifier_type t 
WHERE p.uuid = j.patGuid AND (t.name = 'Code ST' OR (t.name = 'Code National' and j.nationalid is not null and j.nationalid <> '') OR (t.name = 'Code ST' and j.clinicPatientID is not null and j.clinicPatientID <> '')) ON DUPLICATE KEY UPDATE
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
WHERE j.patGuid = p.uuid AND (
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
person_id,1,p.date_created,1,p.date_created,uuid()
from person p,patient p1, (select e.encounter_type_id from encounter_type e where uuid='873f968a-73a8-4f9c-ac78-9f4778b751b6'
) e where p.person_id=p1.patient_id on duplicate key update 
encounter_type=values(encounter_type),
location_id=values(location_id),
encounter_datetime=values(encounter_datetime),
creator=values(creator),
date_created=values(date_created);


select now() as Encounter;

/* insert marital status into obs */
insert into obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
select p.person_id,'1054' as concept_id,e.encounter_id,encounter_datetime as obs_datetime,e.location_id,
case WHEN j.maritalStatus=1 THEN 5555  -- marie
     WHEN j.maritalStatus=8 THEN 1056  -- separe
     WHEN j.maritalStatus=4 THEN 1059  -- veuve 
     else  5622
end as value_coded,
1,e.date_created,uuid() as uuid	 
from person p, itech.patient j, encounter e
 where j.patGuid = p.uuid and e.patient_id=p.person_id and e.visit_id is null
  and j.maritalStatus IS NOT NULL AND j.maritalStatus <> '';

 select now() as obs1;


  OPEN emergencyCursor;
  OPEN disclosureCursor;

  emergency_loop: LOOP
    FETCH emergencyCursor INTO person_id_,encounter_id_,obs_datetime_,location_id_,creator_,date_created_,uuid_,contact_,phoneContact_,addrContact_,relationContact_,medicalPoa_,relationMedicalPoa_,addrMedicalPoa_,phoneMedicalPoa_;
    IF done THEN
      LEAVE emergency_loop;
    END IF;
	
/* insert emergency contact */	

case relationContact_
when (UPPER(relationContact_)='PERE' or UPPER(relationContact_)='PAPA')  then set concept_relation='971';
when (UPPER(relationContact_)='MERE' or UPPER(relationContact_)='MANMAN' or UPPER(relationContact_)='MAMAN')  then set concept_relation='970';
when (UPPER(relationContact_)='ONCLE' or UPPER(relationContact_)='TONTON' or UPPER(relationContact_)='UNCLE')  then set concept_relation='974';
when (UPPER(relationContact_)='GRAND PERE' or UPPER(relationContact_)='GRAND PAPA' or UPPER(relationContact_)='GRAN PAPA')  then set concept_relation='973';
when (UPPER(relationContact_)='TANTE' or UPPER(relationContact_)='MATANT' or UPPER(relationContact_)='MA TANTE')  then set concept_relation='975';
when (UPPER(relationContact_)='AMI' or UPPER(relationContact_)='AMIS' or UPPER(relationContact_)='ZANMI')  then set concept_relation='5618';
else set concept_relation='5622';
end case;

case relationMedicalPoa_
when (UPPER(relationMedicalPoa_)='PERE' or UPPER(relationMedicalPoa_)='PAPA')  then set relationMedicalPoa_concept='971';
when (UPPER(relationMedicalPoa_)='MERE' or UPPER(relationMedicalPoa_)='MANMAN' or UPPER(relationMedicalPoa_)='MAMAN')  then set relationMedicalPoa_concept='970';
when (UPPER(relationMedicalPoa_)='ONCLE' or UPPER(relationMedicalPoa_)='TONTON' or UPPER(relationMedicalPoa_)='UNCLE')  then set relationMedicalPoa_concept='974';
when (UPPER(relationMedicalPoa_)='GRAND PERE' or UPPER(relationMedicalPoa_)='GRAND PAPA' or UPPER(relationMedicalPoa_)='GRAN PAPA')  then set relationMedicalPoa_concept='973';
when (UPPER(relationMedicalPoa_)='TANTE' or UPPER(relationMedicalPoa_)='MATANT' or UPPER(relationMedicalPoa_)='MA TANTE')  then set relationMedicalPoa_concept='975';
when (UPPER(relationMedicalPoa_)='AMI' or UPPER(relationMedicalPoa_)='AMIS' or UPPER(relationMedicalPoa_)='ZANMI')  then set relationMedicalPoa_concept='5618';
else set relationMedicalPoa_concept='5622';
end case;


insert into obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
values (person_id_,'164966',encounter_id_,obs_datetime_,location_id_,creator_,date_created_,uuid_);

set obs_id=last_insert_id();
	
insert into obs(person_id,concept_id,encounter_id,obs_group_id,obs_datetime,location_id,value_text,creator,date_created,uuid)
values (person_id_,'164950',encounter_id_,obs_id,obs_datetime_,location_id_,contact_,creator_,date_created_,uuid()), -- contact
       (person_id_,'164956',encounter_id_,obs_id,obs_datetime_,location_id_,phoneContact_,creator_,date_created_,uuid()), -- phone contact
       (person_id_,'164949',encounter_id_,obs_id,obs_datetime_,location_id_,addrContact_,creator_,date_created_,uuid()) ;  -- address contact  	   

insert into obs(person_id,concept_id,encounter_id,obs_group_id,obs_datetime,location_id,value_coded,comments,creator,date_created,uuid)
values (person_id_,'164352',encounter_id_,obs_id,obs_datetime_,location_id_,concept_relation,relationContact_,creator_,date_created_,uuid()); -- relationship
/* insert poa contact */	
insert into obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
values (person_id_,'164959',encounter_id_,obs_datetime_,location_id_,creator_,date_created_,uuid());

set obs_id=last_insert_id();

insert into obs(person_id,concept_id,encounter_id,obs_group_id,obs_datetime,location_id,value_text,creator,date_created,uuid)
values (person_id_,'164950',encounter_id_,obs_id,obs_datetime_,location_id_,medicalPoa_,creator_,date_created_,uuid()), -- contact
       (person_id_,'164956',encounter_id_,obs_id,obs_datetime_,location_id_,phoneMedicalPoa_,creator_,date_created_,uuid()), -- phone contact
       (person_id_,'164949',encounter_id_,obs_id,obs_datetime_,location_id_,addrMedicalPoa_,creator_,date_created_,uuid()) ;  -- address contact  
	
insert into obs(person_id,concept_id,encounter_id,obs_group_id,obs_datetime,location_id,value_coded,comments,creator,date_created,uuid)
values (person_id_,'164352',encounter_id_,obs_id,obs_datetime_,location_id_,relationMedicalPoa_concept,relationMedicalPoa_,creator_,date_created_,uuid()); 	
	
  select now() as obs2,contact_; 
  END LOOP;
  
  CLOSE emergencyCursor;
  
   
  disclosure_loop: LOOP
    FETCH disclosureCursor INTO person_id_,encounter_id_,obs_datetime_,location_id_,creator_,date_created_,uuid_,disclosureName_,disclosureRel_,disclosureAddress_,disclosureTelephone_,disclosureSlot_;
    IF done THEN
      LEAVE disclosure_loop;
    END IF;
	
case disclosureRel_
when (UPPER(disclosureRel_)='PERE' or UPPER(disclosureRel_)='PAPA')  then set disclosureRelation_concept='971';
when (UPPER(disclosureRel_)='MERE' or UPPER(disclosureRel_)='MANMAN' or UPPER(disclosureRel_)='MAMAN')  then set disclosureRelation_concept='970';
when (UPPER(disclosureRel_)='ONCLE' or UPPER(disclosureRel_)='TONTON' or UPPER(disclosureRel_)='UNCLE')  then set disclosureRelation_concept='974';
when (UPPER(disclosureRel_)='GRAND PERE' or UPPER(disclosureRel_)='GRAND PAPA' or UPPER(disclosureRel_)='GRAN PAPA')  then set disclosureRelation_concept='973';
when (UPPER(disclosureRel_)='TANTE' or UPPER(disclosureRel_)='MATANT' or UPPER(disclosureRel_)='MA TANTE')  then set disclosureRelation_concept='975';
when (UPPER(disclosureRel_)='AMI' or UPPER(disclosureRel_)='AMIS' or UPPER(disclosureRel_)='ZANMI')  then set disclosureRelation_concept='5618';
else set disclosureRelation_concept='5622';
end case;	
	
/* insert disclosure contact */	
insert into obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
values (person_id_,'164963',encounter_id_,obs_datetime_,location_id_,creator_,date_created_,uuid());

set obs_id=last_insert_id();
	
insert into obs(person_id,concept_id,encounter_id,obs_group_id,obs_datetime,location_id,value_text,creator,date_created,uuid)
values (person_id_,'164950',encounter_id_,obs_id,obs_datetime_,location_id_,disclosureName_,creator_,date_created_,uuid()), -- contact
       (person_id_,'164956',encounter_id_,obs_id,obs_datetime_,location_id_,disclosureTelephone_,creator_,date_created_,uuid()), -- phone contact
       (person_id_,'164949',encounter_id_,obs_idobs_datetime_,location_id_,disclosureAddress_,creator_,date_created_,uuid()) ;  -- address contact  	   

insert into obs(person_id,concept_id,encounter_id,obs_group_id,obs_datetime,location_id,value_coded,comments,creator,date_created,uuid)
values (person_id_,'164352',encounter_id_,obs_id,obs_datetime_,location_id_,disclosureRelation_concept,disclosureRel_,creator_,date_created_,uuid()); -- relationship	   
	   
	   
	   
  END LOOP;

  CLOSE disclosureCursor;
  
END;
>>>>>>> d0e3541c99b31eba5d47ab9e3a5fdf522593a760
