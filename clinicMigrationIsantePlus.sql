DELIMITER $$ 
CREATE PROCEDURE clinicMigration()
BEGIN
  DECLARE done INT DEFAULT FALSE;
 -- DECLARE a CHAR(16);
  DECLARE vstatus,mmmIndex INT;
  DECLARE vvisit_type_id INT;
  DECLARE obs_datetime_,vobs_datetime,vdate_created,vencounter_datetime datetime;
  DECLARE vobs_id,vperson_id,vconcept_id,vencounter_id,vlocation_id INT;
  DECLARE vreferHosp,vreferVctCenter,vreferPmtctProg,vreferOutpatStd,vreferCommunityBasedProg,vfirstCareOtherFacText varchar(10);
  
DECLARE uuid_encounter CURSOR  for SELECT DISTINCT e.patientID,e.encounter_id FROM itech.encounter e;

DECLARE source_reference CURSOR  for 
SELECT DISTINCT e.patient_id,159936,e.encounter_id,e.encounter_datetime,e.location_id,
referHosp,referVctCenter,referPmtctProg,referOutpatStd,referCommunityBasedProg,firstCareOtherFacText,e.date_created
FROM itech.encounter c, encounter e, itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and e.encounter_datetime = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
(referHosp=1 or referVctCenter=1 or referPmtctProg=1 or referOutpatStd=1 or referCommunityBasedProg=1 or firstCareOtherFacText=1);
  
DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE; 


create table if not exists itech.obs_concept_group (obs_id int,person_id int,concept_id int,encounter_id int);

create table if not exists itech.migration_status(id int auto_increment primary key,procedures text,section text,status boolean);



select visit_type_id into vvisit_type_id from visit_type where uuid='7b0f5697-27e3-40c4-8bae-f4049abfb4ed';

 /* Visit Migration
 * find all unique patientid, visitdate instances in the encounter table and consider these visits
 */
 set vstatus=0;
 select status into vstatus from itech.migration_status where section='visit';
 
if (vstatus=0) then  
INSERT INTO visit (patient_id, visit_type_id, date_started, date_stopped, location_id, creator, date_created, uuid)
SELECT DISTINCT p.person_id, vvisit_type_id, concat(e.visitDateYy,'-',e.visitDateMm,'-',e.visitDateDd), concat(e.visitDateYy,'-',e.visitDateMm,'-',e.visitDateDd), 1,1, e.lastModified, UUID()
FROM person p, itech.patient it, itech.encounter e
WHERE p.uuid = it.patGuid AND it.patientid = e.patientid AND
e.encounterType in (1,2,3,4,5,6,12,14,16,17,18,19,20,21,24,25,26,27,28,29,31);

insert into itech.migration_status(procedures,section,status) values('clinicMigration','visit',1);
end if;
select 1 as visit;

set vstatus=0;
select status into vstatus from itech.migration_status where section='alter encounter';
/* update encounter itech table with uuid */
if (vstatus=0) then 
ALTER TABLE itech.encounter ADD encGuid VARCHAR(36) NOT NULL;
insert into itech.migration_status(procedures,section,status) values('clinicMigration','alter encounter',1);
end if;

 set vstatus=0;
 select status into vstatus from itech.migration_status where section='update encounter';
 
 if (vstatus=0) then 
UPDATE itech.encounter SET encGuid=uuid();
select count(*) into mmmIndex from information_schema.statistics where table_name = 'encounter' and index_name = 'eGuid' and table_schema ='itech';
if (mmmIndex=0) then    
CREATE UNIQUE INDEX eGuid ON itech.encounter (encGuid);
end if;
/* end update encounter itech table with uuid */
select 2 as encounter;
insert into itech.migration_status(procedures,section,status) values('clinicMigration','update encounter',1);
end if;

set vstatus=0;
select status into vstatus from itech.migration_status where section='mapping form';

 if (vstatus=0) then 
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
( 17 , 'f55d3760-1bf1-4e42-a7f9-0a901fa49cf0' );
 
 UPDATE itech.typeToForm i, form t SET i.form_id = t.form_id,i.encounterTypeOpenmrs=t.encounter_type where i.uuid = t.uuid;
 
 
 select count(*) into mmmIndex from information_schema.statistics where table_name = 'encounter' and index_name = 'mmm' and table_schema ='openmrs';

  if (mmmIndex=0) then 
 create unique index mmm on encounter (patient_id,location_id,form_id,visit_id, encounter_datetime, encounter_type,date_created);
 insert into itech.migration_status(procedures,section,status) values('clinicMigration','mapping form',1);
 end if;
 
 end if;

INSERT INTO encounter(encounter_type,patient_id,location_id,form_id,visit_id, encounter_datetime,creator,date_created,date_changed,uuid)
SELECT ALL f.encounterTypeOpenmrs, p.person_id, 1, f.form_id, v.visit_id,
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

select 3 as encounter1;

/* remove obs data */
update obs set obs_group_id=null where encounter_id in (select encounter_id from encounter where encounter_type<>32);
delete from obs where encounter_id in (select encounter_id from encounter where encounter_type<>32);


/*migration pour visit form history */

insert into isanteplus_form_history(visit_id,encounter_id,creator,date_created,uuid)
select visit_id,encounter_id,creator,date_created, uuid() from encounter e where encounter_type<>32 and form_id not in (1,2,3,4,5)
ON DUPLICATE KEY UPDATE
visit_id=values(visit_id),
encounter_id=values(encounter_id),
creator=values(creator),
date_created=values(date_created);

/*end of migration pour visit form history */
/* SIGNES VITAUX MENU */
/*DATA Migration for vitals Temp*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT c.patient_id,5088,c.encounter_id,c.encounter_datetime,c.location_id,
CASE WHEN v.vitalTempUnits=2 THEN ROUND((substring_index(replace(v.vitalTemp,',','.'),'.',2)+0-32)/1.8000,2) 
ELSE ROUND(substring_index(replace(v.vitalTemp,',','.'),'.',2)+0,2) END,1,c.date_created,UUID()
from encounter c, itech.encounter e, itech.vitals v 
WHERE c.uuid = e.encGuid and 
e.patientID = v.patientID and e.sitecode = v.sitecode and concat(e.visitDateYy,'-',e.visitDateMm,'-',e.visitDateDd) = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) and e.seqNum = v.seqNum AND 
(substring_index(replace(v.vitalTemp,',','.'),'.',2)+0 > 0 AND vitalTempUnits IS NOT NULL);

select 4 as vital1;
/*DATA Migration for vitals TA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,5085,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.vitalBPUnits=1 THEN substring_index(replace(v.vitalBp1+0,',','.'),'.',2)
WHEN v.vitalBPUnits=2 THEN substring_index(replace(v.vitalBp1+0,',','.'),'.',2)*10 END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
substring_index(replace(v.vitalBp1,',','.'),'.',2) REGEXP '^[0-9\.]+$' and v.vitalBp1 IS NOT NULL AND v.vitalBp2 <> '';

INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,5086,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.vitalBPUnits=1 THEN substring_index(replace(v.vitalBp2,',','.'),'.',2)
WHEN v.vitalBPUnits=2 THEN substring_index(replace(v.vitalBp2,',','.'),'.',2)*10 END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')= concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
substring_index(replace(v.vitalBp2,',','.'),'.',2) REGEXP '^[0-9\.]+$' and v.vitalBp2 IS NOT NULL AND v.vitalBp2 <> '';


/*DATA Migration for vitals POULS*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,5087,e.encounter_id,e.encounter_datetime,e.location_id,v.vitalHr,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd)
AND v.vitalHr<>'';


/*DATA Migration for vitals FR*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,5242,e.encounter_id,e.encounter_datetime,e.location_id,v.vitalRr,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd)
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
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')= concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
(v.vitalHeight<>'' OR v.vitalHeightCm<>'');


/*DATA Migration for vitals POIDS*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,5089,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.vitalWeightUnits=1 THEN v.vitalWeight
WHEN v.vitalWeightUnits=2  THEN v.vitalWeight/2.2046
ELSE NULL
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.vitalWeight<>'';

/*END OF SIGNES VITAUX MENU*/

select 5 as vital2;
/*STARTING SOURCE DE RÉFÉRENCE MENU*/ 
OPEN source_reference;

source_reference_loop: LOOP
  FETCH source_reference INTO vperson_id,vconcept_id,vencounter_id,vencounter_datetime,vlocation_id, vreferHosp,
	                          vreferVctCenter,vreferPmtctProg,vreferOutpatStd,vreferCommunityBasedProg,vfirstCareOtherFacText,vdate_created;
    IF done THEN
      LEAVE source_reference_loop;
    END IF;
	
select 6 as source;
	/*MIGRATION FOR Hôpital (patient a été hospitalisé antérieurement)*/
	if(vreferHosp=1) then 
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
	values (vperson_id,vconcept_id,vencounter_id,vencounter_datetime,vlocation_id,5485,1,vdate_created,uuid());
	end if;
select 7 as source1;	
	/*MIGRATION FOR Centres CDV intégrés*/
	if(vreferVctCenter=1) then 
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
	values (vperson_id,vconcept_id,vencounter_id,vencounter_datetime,vlocation_id,159940,1,vdate_created,uuid());
	end if;

	
	/*MIGRATION FOR Programme PTME*/
	if(vreferPmtctProg=1) then 
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
	values (vperson_id,vconcept_id,vencounter_id,vencounter_datetime,vlocation_id,159937,1,vdate_created,uuid());
	end if;
	
	/*MIGRATION FOR Clinique Externe*/
	if(vreferOutpatStd=1) then 
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
	values (vperson_id,vconcept_id,vencounter_id,vencounter_datetime,vlocation_id,160542,1,vdate_created,uuid());
	end if;
	
    /*MIGRATION FOR Programmes communautaires*/
	if(vreferCommunityBasedProg=1) then 
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
	values (vperson_id,vconcept_id,vencounter_id,vencounter_datetime,vlocation_id,159938,1,vdate_created,uuid());
	end if;
		
	/*MIGRATION FOR Transfert d'un autre établissement de santé*/
	if(vfirstCareOtherFacText<>'') then 
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
	values (vperson_id,vconcept_id,vencounter_id,vencounter_datetime,vlocation_id,5622,1,vdate_created,uuid());
	end if;
		
	/*END OF SOURCE DE RÉFÉRENCE MENU*/

  END LOOP;
  
  CLOSE source_reference;
  
  select 7 as source_reference;
  	
	/*STARTING TEST ANTICORPS VIH MENU*/
	   /*Migration for Date du premier test (anticorps) VIH positif*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160082,e.encounter_id,e.encounter_datetime,e.location_id,
	CASE WHEN v.firstTestYy<>'' AND v.firstTestMm<>'' THEN CONCAT(v.firstTestYy,'-',v.firstTestMm,'-',01)
		ELSE NULL
	END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.firstTestYy<>'' AND v.firstTestMm<>'';
		
select 8 as anticorps;
		
		/*Migration for Établissement où le test a été réalisé*/
		 /*Cet établissement */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159936,e.encounter_id,e.encounter_datetime,e.location_id,
	CASE WHEN v.firstTestThisFac=1 THEN 163266
		ELSE NULL
	END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.firstTestThisFac=1;
		
		/*Autre */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159936,e.encounter_id,e.encounter_datetime,e.location_id,
	CASE WHEN v.firstTestOtherFac=1 THEN 5622
		ELSE NULL
	END,v.firstTestOtherFacText,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.firstTestOtherFac=1;		
	/*END OF TEST ANTICORPS VIH MENU*/
 
 select 9 as etablissement;
 
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
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
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
CASE WHEN v.riskID=1 AND v.riskAnswer=1 THEN 163290
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
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.riskID in (1,3,5,6,9,14,15,19,31) and v.riskAnswer=1;

		/*FOR THE DATE*//*Bénéficier de sang/dérivé sanguin*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163268,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.riskID=15 AND v.riskAnswer=1 and v.riskYy>1 then date(concat(riskYy,'-',ifnull(v.riskMm,'01'),'-',ifnull(v.riskDd,'01')))
	 else null
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.riskAssessments v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')= concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.riskID=15 and v.riskAnswer=1 and ifnull(v.riskYy,0)>0;
		
/*MIGRATION FOR Accident d'exposition au sang*/
	/*Migration for obsgroup*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163288,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.riskAssessments v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.riskID=12 and v.riskAnswer=1;


INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=160741 
GROUP BY openmrs.obs.person_id,encounter_id;


		
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160581,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.riskID=12 AND v.riskAnswer=1 THEN 163274
	 ELSE NULL
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.riskAssessments v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.riskID=12 and v.riskAnswer=1;
		/*migration for the date*/
		
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,162601,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.riskID=12 AND v.riskAnswer=1 and v.riskYy>1 then date(concat(riskYy,'-',ifnull(v.riskMm,'01'),'-',ifnull(v.riskDd,'01')))
	 else null
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.riskAssessments v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.riskID=12 and v.riskAnswer=1 and ifnull(v.riskYy,0)>0;		
	
	/*END OF MIGRATION FOR MODE PROBABLE DE TRANSMISSION DU VIH MENU*/
 

/*MIGRATION FOR AUTRES FACTEURS DE RISQUE MENU*/
	/*Migration for Histoire ou présence de syphilis*/
	/*Migration for obsgroup*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163292,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.riskAssessments v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND v.riskID=32
AND (v.riskAnswer=1 OR v.riskAnswer=2 OR v.riskAnswer=4);
		
delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163292 
GROUP BY openmrs.obs.person_id,encounter_id;		
		
		
set vobs_id=last_insert_id();
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.riskID=32 AND v.riskAnswer=1 THEN 1065
	 WHEN v.riskID=32 AND v.riskAnswer=2 THEN 1066
	 WHEN v.riskID=32 AND v.riskAnswer=4 THEN 1067
	 ELSE NULL
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.riskAssessments v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND v.riskID=32
AND (v.riskAnswer=1 OR v.riskAnswer=2 OR v.riskAnswer=4);
		
		/*migration for Victime d'agression sexuelle*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,123160,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.riskID=13 AND v.riskAnswer=1 THEN 1065
	 WHEN v.riskID=13 AND v.riskAnswer=2 THEN 1066
	 WHEN v.riskID=13 AND v.riskAnswer=4 THEN 1067
	 ELSE NULL
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.riskAssessments v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND v.riskID=13
AND (v.riskAnswer=1 OR v.riskAnswer=2 OR v.riskAnswer=4);
		
		/*Migration for Rapports sexuels :
			- ≥ 2 personnes dans les 3 dernières mois
		*/
		
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160581,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.riskID=33 AND v.riskAnswer=1 THEN 5567
	 ELSE NULL
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.riskAssessments v  ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) 
AND v.riskID=33 AND v.riskAnswer=1;		
		
		
		/*- par voie anale*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163278,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.riskID=7 AND v.riskAnswer=1 THEN 1065
     WHEN v.riskID=7 AND v.riskAnswer=2 THEN 1066
	 ELSE NULL
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.riskAssessments v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and  
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) 
AND v.riskID=7 AND (v.riskAnswer=1 or v.riskAnswer=2);	
		
		/*- avec travailleur/euse de sexe*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160581,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.riskID=20 AND (v.riskAnswer=1 or v.riskAnswer=2 ) THEN 160580
	 ELSE NULL
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.riskAssessments v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) 
AND v.riskID=20 AND (v.riskAnswer=1 or v.riskAnswer=2);			

INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160580,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.riskID=20 AND v.riskAnswer=1 THEN 1065
     WHEN v.riskID=20 AND v.riskAnswer=2 THEN 1066
	 ELSE NULL
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.riskAssessments v  ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')= concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) 
AND v.riskID=20 AND (v.riskAnswer=1 or v.riskAnswer=2);	
		
		/* - L'échange de sexe pour argent/choses*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160581,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.riskID=34 AND (v.riskAnswer=1 or v.riskAnswer=2 ) THEN 160579
	 ELSE NULL
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.riskAssessments v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) 
AND v.riskID=34 AND (v.riskAnswer=1 or v.riskAnswer=2);			

INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160579,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.riskID=34 AND v.riskAnswer=1 THEN 1065
     WHEN v.riskID=34 AND v.riskAnswer=2 THEN 1066
	 ELSE NULL
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.riskAssessments v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) 
AND v.riskID=34 AND (v.riskAnswer=1 or v.riskAnswer=2);			

	/*END OF MIGRATION FOR AUTRES FACTEURS DE RISQUE MENU*/ 
 
 
 
 
 select 10 as testColumn;
 
 
 
 
 
 
 
 
 
 	/*STARTING MIGRATION FOR COMPTE CD4 MENU*/
		/*Compte CD4 le plus bas*/		
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159375,e.encounter_id,e.encounter_datetime,e.location_id,
	CASE WHEN v.lowestCd4Cnt<>'' THEN lowestCd4Cnt
		ELSE NULL
	END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.lowestCd4Cnt<>'';	

		/* DATE */		
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159376,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.lowestCd4CntDd<1 AND v.lowestCd4CntMm<1 AND v.lowestCd4CntYy>0 
		THEN date(CONCAT(v.lowestCd4CntYy,'-',01,'-',01))
		WHEN v.lowestCd4CntDd<1 AND v.lowestCd4CntMm>0 AND v.lowestCd4CntYy>0
		THEN date(CONCAT(v.lowestCd4CntYy,'-',v.lowestCd4CntMm,'-',01))
		WHEN v.lowestCd4CntDd>0 AND v.lowestCd4CntMm>0 AND v.lowestCd4CntYy>0
		THEN date(CONCAT(v.lowestCd4CntYy,'-',v.lowestCd4CntMm,'-',v.lowestCd4CntDd))
		ELSE NULL
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.lowestCd4Cnt<>'' AND v.lowestCd4CntYy>0;
		/*Non effectué/Inconnu*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1941,e.encounter_id,e.encounter_datetime,e.location_id,
	CASE WHEN v.lowestCd4Cnt<>'' AND v.lowestCd4CntNotDone=1 THEN 1066
		ELSE NULL
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
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
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.firstViralLoad<>'';	

		/* DATE */		
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163281,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.firstViralLoadDd<1 AND v.firstViralLoadMm<1 AND v.firstViralLoadYy>0 
		THEN date(CONCAT(v.firstViralLoadYy,'-',01,'-',01))
		WHEN v.firstViralLoadDd<1 AND v.firstViralLoadMm>0 AND v.firstViralLoadYy>0
		THEN date(CONCAT(v.firstViralLoadYy,'-',v.firstViralLoadMm,'-',01))
		WHEN v.firstViralLoadDd>0 AND v.firstViralLoadMm>0 AND v.firstViralLoadYy>0
		THEN date(CONCAT(v.firstViralLoadYy,'-',v.firstViralLoadMm,'-',v.firstViralLoadDd))
		ELSE NULL
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')= concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
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
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
(v.asymptomaticTb=1 OR v.completeTreat=1 OR v.currentTreat=1);
	
		/*Migration for Date complété */		
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159431,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.completeTreatDd<1 AND v.completeTreatMm<1 AND v.completeTreatYy>0 THEN date(CONCAT(v.completeTreatYy,'-',01,'-',01))
	 WHEN v.completeTreatDd<1 AND v.completeTreatMm>0 AND v.completeTreatYy>0 THEN date(CONCAT(v.completeTreatYy,'-',v.completeTreatMm,'-',01))
	 WHEN v.completeTreatDd>0 AND v.completeTreatMm>0 AND v.completeTreatYy>0 THEN date(CONCAT(v.completeTreatYy,'-',v.completeTreatMm,'-',v.completeTreatDd))
	 ELSE NULL
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.tbStatus v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
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
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
(v.vaccTetanus=1 OR v.vaccHepB=1);

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1421 
GROUP BY openmrs.obs.person_id,encounter_id;


set vobs_id=last_insert_id();	

		
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,984,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.vaccHepB=1 THEN 1685 ELSE NULL END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals  v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND v.vaccHepB=1;
		
/*migration for MM/AA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1410,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.vaccHepB=1 AND v.vaccHepBMm<1 AND v.vaccHepBYy>0 THEN CONCAT(v.vaccHepBYy,'-',01,'-',01)
	 WHEN v.vaccHepB=1 AND v.vaccHepBMm>0 AND v.vaccHepBYy>0 THEN CONCAT(v.vaccHepBYy,'-',v.vaccHepBMm,'-',01)
	 ELSE NULL
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals  v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.vaccHepB=1 AND v.vaccHepBYy>0;

/*migration for Nombre de dose */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1418,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.vaccHepB=1 AND v.hepBdoses>=0 THEN v.hepBdoses ELSE NULL END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals  v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.vaccHepB=1 AND v.hepBdoses>=0;

		/*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
		/*MIGRATION FOR Tétanos*/ 
/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,984,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.vaccTetanus=1 THEN 1685 ELSE NULL END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals  v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND v.vaccTetanus=1;
		
/*migration for MM/AA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1410,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.vaccTetanus=1 AND v.vaccTetanusMm<1 AND v.vaccTetanusYy>0 THEN CONCAT(v.vaccTetanusYy,'-',01,'-',01)
	 WHEN v.vaccTetanus=1 AND v.vaccTetanusMm>0 AND v.vaccTetanusYy>0 THEN CONCAT(v.vaccTetanusYy,'-',v.vaccTetanusMm,'-',01)
	 ELSE NULL
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals  v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.vaccTetanus=1 AND v.vaccTetanusYy>0;

/*migration for Nombre de dose */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1418,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.vaccTetanus=1 AND v.tetDoses>=0 THEN v.tetDoses ELSE NULL END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals  v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
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

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1727 
GROUP BY openmrs.obs.person_id,encounter_id;

set vobs_id=last_insert_id();	
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1728,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN o.concept_id=7000 AND o.value_boolean=1 THEN 151
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7000 and o.value_boolean=1 and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id;		

		/*Migration for YES */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1729,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN o.concept_id=7000 AND o.value_boolean=1 THEN 1065
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7000 and o.value_boolean=1 and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id;
		/*=========================================================================================================*/
		/*migration for Anorexie/Perte d'appétit*/
	  /*concept group */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1727,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7001 and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1727 
GROUP BY openmrs.obs.person_id,encounter_id;

set vobs_id=last_insert_id();	
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1728,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN o.concept_id=7001 AND o.value_boolean=1 THEN 6031
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7001 and o.value_boolean=1 and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id;		

		/*Migration for YES */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1729,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN o.concept_id=7001 AND o.value_boolean=1 THEN 1065
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7001 and o.value_boolean=1 and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id;	
		/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
		/*migration for Toux*/
	  /*concept group */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1727,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7004 and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1727 
GROUP BY openmrs.obs.person_id,encounter_id;

set vobs_id=last_insert_id();	
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1728,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN o.concept_id=7004 AND o.value_boolean=1 THEN 143264
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7004 and o.value_boolean=1 and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id;

		/*Migration for YES */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1729,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN o.concept_id=7004 AND o.value_boolean=1 THEN 1065
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7004 and o.value_boolean=1  and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id; 
		/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
		/*Migration for Toux/Expectoration (sauf hémoptysie)*/		
		 /*concept group */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1727,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7008 and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1727 
GROUP BY openmrs.obs.person_id,encounter_id;

set vobs_id=last_insert_id();	
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1728,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN o.concept_id=7008 AND o.value_boolean=1 THEN 5957
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7008 and o.value_boolean=1 and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id; 	

		/*Migration for YES */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1729,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN o.concept_id=7008 AND o.value_boolean=1 THEN 1065
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7008 and o.value_boolean=1 and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id;		 
		/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
		/*Migration for Dyspnée*/
		 /*concept group */
		 
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1727,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7007 and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1727 
GROUP BY openmrs.obs.person_id,encounter_id;

set vobs_id=last_insert_id();	
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1728,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN o.concept_id=7007 AND o.value_boolean=1 THEN 122496
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7007 and o.value_boolean=1  and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id;

		/*Migration for YES */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1729,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN o.concept_id=7007 AND o.value_boolean=1 THEN 1065
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7007 and o.value_boolean=1 and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id;			 

	/*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
		/*Migration for Céphalée*/
	 /*concept group */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1727,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7011 and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1727 
GROUP BY openmrs.obs.person_id,encounter_id;

set vobs_id=last_insert_id();	
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1728,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN o.concept_id=7011 AND o.value_boolean=1 THEN 139084
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7011 and o.value_boolean=1  and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id;	

		/*Migration for YES */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1729,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN o.concept_id=7011 AND o.value_boolean=1 THEN 1065
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7011 and o.value_boolean=1  and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id;	 

		/*=============================================================================================================*/
		/*Migration for Hémoptysie*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1727,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7012 and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1727 
GROUP BY openmrs.obs.person_id,encounter_id;

set vobs_id=last_insert_id();	
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1728,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN o.concept_id=7012 AND o.value_boolean=1 THEN 138905
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7012 and o.value_boolean=1  and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id;		

		/*Migration for YES */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1729,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN o.concept_id=7012 AND o.value_boolean=1 THEN 1065
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7012 and o.value_boolean=1  and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id;			
		/*=================================================================================================================*/
		/*Migration for Nausée*/
		/*Concept group*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1727,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7013 and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1727 
GROUP BY openmrs.obs.person_id,encounter_id;

set vobs_id=last_insert_id();	
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1728,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN o.concept_id=7013 AND o.value_boolean=1 THEN 5978
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7013 and o.value_boolean=1  and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id;		

		/*Migration for YES */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1729,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN o.concept_id=7013 AND o.value_boolean=1 THEN 1065
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7013 and o.value_boolean=1  and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id;
		/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
		/*Migration for Sueurs nocturnes*/
		/*Concept group*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1727,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7014 and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1727 
GROUP BY openmrs.obs.person_id,encounter_id;

set vobs_id=last_insert_id();	
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1728,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN o.concept_id=7014 AND o.value_boolean=1 THEN 133027
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7014 and o.value_boolean=1  and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id;	

		/*Migration for YES */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1729,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN o.concept_id=7014 AND o.value_boolean=1 THEN 1065
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7014 and o.value_boolean=1  and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id;
		/*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
		/*Migration for Perte de sensibilité*/
		/*Concept group*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1727,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7015 and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1727 
GROUP BY openmrs.obs.person_id,encounter_id;

set vobs_id=last_insert_id();	
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1728,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN o.concept_id=7015 AND o.value_boolean=1 THEN 141635
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7015 and o.value_boolean=1  and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id;		

		/*Migration for YES */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1729,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN o.concept_id=7015 AND o.value_boolean=1 THEN 1065
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7015 and o.value_boolean=1  and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id;	
		/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
		/*Migration for Odynophagie/dysphagie*/
		/*Concept group*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1727,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7016 and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1727 
GROUP BY openmrs.obs.person_id,encounter_id;

set vobs_id=last_insert_id();	
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1728,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN o.concept_id=7016 AND o.value_boolean=1 THEN 118789
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7016 and o.value_boolean=1  and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id;	

		/*Migration for YES */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1729,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN o.concept_id=7016 AND o.value_boolean=1 THEN 1065
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7024 and o.value_boolean=1  and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id;		
		/*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
		/*Migration for Eruption cutanée*/
		/*Concept group*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1727,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7024 and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1727 
GROUP BY openmrs.obs.person_id,encounter_id;

set vobs_id=last_insert_id();	
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1728,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN o.concept_id=7024 AND o.value_boolean=1 THEN 512
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7024 and o.value_boolean=1 and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id;	

		/*Migration for YES */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1729,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN o.concept_id=7024 AND o.value_boolean=1 THEN 1065
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7024 and o.value_boolean=1 and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id;	
		/*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
		/*Migration for Vomissement*/
		/*Concept group*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1727,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7025 and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1727 
GROUP BY openmrs.obs.person_id,encounter_id;

set vobs_id=last_insert_id();	
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1728,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN o.concept_id=7025 AND o.value_boolean=1 THEN 122983
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7025 and o.value_boolean=1 and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id;	

		/*Migration for YES */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1729,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN o.concept_id=7025 AND o.value_boolean=1 THEN 1065
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7025 and o.value_boolean=1 and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id;	

		/*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
		/*Migration for Prurigo*/
		/*Concept group*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1727,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7042 and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1727 
GROUP BY openmrs.obs.person_id,encounter_id;

set vobs_id=last_insert_id();	
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1728,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN o.concept_id=7042 AND o.value_boolean=1 THEN 128319
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7042 and o.value_boolean=1 and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id;		

		/*Migration for YES */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1729,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN o.concept_id=7042 AND o.value_boolean=1 THEN 1065
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7042 and o.value_boolean=1 and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id;			

		/*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
		/*Migration for Autres, préciser :*/
		/*Concept group*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1727,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7044 and o.value_boolean=1 and value_text<>'';

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1727 
GROUP BY openmrs.obs.person_id,encounter_id;

set vobs_id=last_insert_id();	
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,comments,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1728,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN o.concept_id=7044 AND o.value_boolean=1 THEN 5622
	 ELSE NULL
END,o.value_text,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7044 and o.value_boolean=1 and value_text<>'' and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id;		

		/*Migration for YES */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1729,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN o.concept_id=7044 AND o.value_boolean=1 THEN 1065
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=7044 and o.value_boolean=1 and value_text<>'' and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id;			
	/*END OF MIGRATION FOR SYMPTÔMES MENU*/

	
 
 /*MIGRATION FOR EXAMEN CLINIQUE*/
		/* Migration for Général*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1119,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.physicalGeneral=1 THEN 159438
	 WHEN v.physicalGeneral=2 THEN 163293
	 WHEN v.physicalGeneral=4 THEN 1118
	 ELSE NULL
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')= concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd)
AND (v.physicalGeneral=1 OR v.physicalGeneral=2 OR v.physicalGeneral=4);	

		/*Migration for Peau*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1120,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.physicalSkin=1 THEN 1115
	 WHEN v.physicalSkin=2 THEN 1116
	 WHEN v.physicalSkin=4 THEN 1118
	 ELSE NULL
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd)
AND (v.physicalSkin=1 OR v.physicalSkin=2 OR v.physicalSkin=4);	

		/*Migration for Bouche/Orale*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163308,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.physicalOral=1 THEN 1115
	 WHEN v.physicalOral=2 THEN 1116
	 WHEN v.physicalOral=4 THEN 1118
	 ELSE NULL
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd)
AND (v.physicalOral=1 OR v.physicalOral=2 OR v.physicalOral=4);	
		/*Migration for Oreilles*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163337,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.physicalEarsNose=1 THEN 1115
	 WHEN v.physicalEarsNose=2 THEN 1116
	 WHEN v.physicalEarsNose=4 THEN 1118
	 ELSE NULL
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd)
AND (v.physicalEarsNose=1 OR v.physicalEarsNose=2 OR v.physicalEarsNose=4);	

		/*Migration for Yeux*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163309,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.physicalEyes=1 THEN 1115
	 WHEN v.physicalEyes=2 THEN 1116
	 WHEN v.physicalEyes=4 THEN 1118
	 ELSE NULL
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')= concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd)
AND (v.physicalEyes=1 OR v.physicalEyes=2 OR v.physicalEyes=4);	
		/*Migration for Ganglions lymphatiques*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1121,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.physicalLymph=1 THEN 1115
	 WHEN v.physicalLymph=2 THEN 1116
	 WHEN v.physicalLymph=4 THEN 1118
	 ELSE NULL
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd)
AND (v.physicalLymph=1 OR v.physicalLymph=2 OR v.physicalLymph=4);			
		
		/*Migration for Poumons*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1123,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.physicalLungs=1 THEN 1115
	 WHEN v.physicalLungs=2 THEN 1116
	 WHEN v.physicalLungs=4 THEN 1118
	 ELSE NULL
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd)
AND (v.physicalLungs=1 OR v.physicalLungs=2 OR v.physicalLungs=4);			

		/*Migration for Cardio-vasculaire*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1124,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.physicalCardio=1 THEN 1115
	 WHEN v.physicalCardio=2 THEN 1116
	 WHEN v.physicalCardio=4 THEN 1118
	 ELSE NULL
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd)
AND (v.physicalCardio=1 OR v.physicalCardio=2 OR v.physicalCardio=4);	
		
		/*Migration for Abdomen*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1125,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.physicalAbdomen=1 THEN 1115
	 WHEN v.physicalAbdomen=2 THEN 1116
	 WHEN v.physicalAbdomen=4 THEN 1118
	 ELSE NULL
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')= concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd)
AND (v.physicalAbdomen=1 OR v.physicalAbdomen=2 OR v.physicalAbdomen=4);	

		/*Migration for Urogénital*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1126,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.physicalUro=1 THEN 1115
	 WHEN v.physicalUro=2 THEN 1116
	 WHEN v.physicalUro=4 THEN 1118
	 ELSE NULL
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd)
AND (v.physicalUro=1 OR v.physicalUro=2 OR v.physicalUro=4);	

		/*Migration for Musculo-squeletal*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1128,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.physicalMusculo=1 THEN 1115
	 WHEN v.physicalMusculo=2 THEN 1116
	 WHEN v.physicalMusculo=4 THEN 1118
	 ELSE NULL
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd)
AND (v.physicalMusculo=1 OR v.physicalMusculo=2 OR v.physicalMusculo=4);	

		/*Migration for Neurologique*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1129,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.physicalNeuro=1 THEN 1115
	 WHEN v.physicalNeuro=2 THEN 1116
	 WHEN v.physicalNeuro=4 THEN 1118
	 ELSE NULL
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')= concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd)
AND (v.physicalNeuro=1 OR v.physicalNeuro=2 OR v.physicalNeuro=4);
		
		/*Migration for Description des conclusions anormales*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1391,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.clinicalExam<>'' THEN v.clinicalExam ELSE NULL END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND v.clinicalExam<>'';
		
	/*END OF MIGRATION FOR EXAMEN CLINIQUE*/
 
  
  /*MIGRATION FOR ÉVALUATION TB*/
		/*Migration for Présence de cicatrice BCG*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160265,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.presenceBCG=1 THEN 1065 ELSE NULL END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.tbStatus  v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.presenceBCG=1;		

		
		/*migration for Prophylaxie à I'INH*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1110,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.propINH=1 THEN 1679 ELSE NULL END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.tbStatus  v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.propINH=1;	

		/*Migration for Suspicion de TB selon les symptômes*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1659,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.suspicionTBwSymptoms=1 THEN 142177 ELSE NULL END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.tbStatus  v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.suspicionTBwSymptoms=1;		

		/*Date d'arrêt de I'INH*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163284,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.arretINHMm<0 AND v.arretINHYy>0 THEN CONCAT(v.arretINHYy,'-',01,'-',01)
	 WHEN v.arretINHMm>0 AND v.arretINHYy>0 THEN CONCAT(v.arretINHYy,'-',v.arretINHMm,'-',01)
	 ELSE NULL END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.tbStatus  v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.arretINHYy>0;			

		
	/*END OF MIGRATION FOR ÉVALUATION TB*/
  
  /*MIGRATION FOR ANTÉCEDENTS MÉDICAUX ET DIAGNOSTICS ACTUELS*/
	  /*Migration for Lymphadénopathie chronique persistante*/
	  INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
		SELECT DISTINCT e.patient_id,
		CASE WHEN v.conditionActive=1 THEN 6042
		     WHEN v.conditionActive=2 THEN 6097
             else null END,e.encounter_id,
		CASE WHEN (v.conditionActive=1 OR v.conditionActive=2) AND v.conditionYy>0 AND v.conditionMm<1 THEN CONCAT(v.conditionYy,'-',01,'-',01)
		     WHEN (v.conditionActive=1 OR v.conditionActive=2) AND v.conditionYy>0 AND v.conditionMm>0 THEN CONCAT(v.conditionYy,'-',v.conditionMm,'-',01)
		     ELSE e.encounter_datetime END,1,
			 case when v.conditionID=435 then 5328
			      when v.conditionID=406 then 298
				  when v.conditionID=403 then 127794
				  when v.conditionID=402 then 512
				  when v.conditionID=407 then 111721
				  when v.conditionID=192 then 117543
				  when v.conditionID=297 then 902
				  when v.conditionID=196 then 5334
				  when v.conditionID=396 then 298
				  when v.conditionID=408 then 5333
				  when v.conditionID=202 then 5337
				  when v.conditionID=205 then 121255
				  when v.conditionID=409 then 42
				  when v.conditionID=715 then 159355
				  when v.conditionID=410 then 5030
				  when v.conditionID=218 then 116023
				  when v.conditionID=411 then 5035
				  when v.conditionID=230 then 142963
				  when v.conditionID=233 then 120330
				  when v.conditionID=257 then 5033
				  when v.conditionID=412 then 1460
				  when v.conditionID=433 then 5334
				  when v.conditionID=428 then case when v.conditionActive=1 then 130864
				                                   when v.conditionActive=2 then 132827
												   end 
				  when v.conditionID=303 then case when v.conditionActive=1 then 1226
				                                   when v.conditionActive=2 then 121629
												   end 
				  when v.conditionID=306 then 129079
				  when v.conditionID=429 then 116030
				  when v.conditionID=430 then 119816
				  when v.conditionID=315 then case when v.conditionActive=1 then 142474
				                                   when v.conditionActive=2 then 142473
												   end
				  when v.conditionID=320 then 111759
				  when v.conditionID=323 then case when v.conditionActive=1 then 149743
				                                   when v.conditionActive=2 then 145347
												   end
				  when v.conditionID=326 then 117441
				  when v.conditionID=329 then 117339
				  when v.conditionID=332 then 135761
				  when v.conditionID=716 then 116128
				  when v.conditionID=335 then 160148
				  when v.conditionID=416 then 145443
				  when v.conditionID=434 then 5034
				  when v.conditionID=414 then 136458
				  when v.conditionID=415 then 139739
				  when v.conditionID=416 then 118510
				  when v.conditionID=417 then 110516
				  when v.conditionID=418 then 156804
				  when v.conditionID=419 then 135886
				  when v.conditionID=251 then 5040
				  when v.conditionID=287 then 990
				  when v.conditionID=242 then 5038
				  when v.conditionID=290 then 141488
				  when v.conditionID=420 then 507
				  when v.conditionID=421 then 5041
				  when v.conditionID=422 then 115195
				  when v.conditionID=423 then case when v.conditionActive=1 then 118890
				                                   when v.conditionActive=2 then 5042
												   end
				  when v.conditionID=424 then case when v.conditionActive=1 then 5043
				                                   when v.conditionActive=2 then 5044
												   end		
				  when v.conditionID=425 then case when v.conditionActive=1 then 114100
				                                   when v.conditionActive=2 then 123742
												   end		
                  when v.conditionID=426 then 5340	
                  when v.conditionID=427 then 123098	
                  when v.conditionID=272 then 882
                  when v.conditionID=248 then 5046	
                  when v.conditionID=717 then 160155
				  when v.conditionID=344 then 118983
				  when v.conditionID=350 then 112493
				  when v.conditionID=353 then 117295
				  when v.conditionID=431 then 119537
				  when v.conditionID=383 then 113517
				  when v.conditionID=386 then 121131
				  when v.conditionID=368 then 159449
				  when v.conditionID=371 then 73650
			END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.conditions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.conditionID in (435,406,403,402,407,192,297,196,396,408,202,205,409,715,410,218,411,230,233,257,412,433,428,303,306,429,430,315,320,323,326,329,332,716,335,416,434,414,415,416,417,418,419,251,287,242,290,420,421,422,423,424,425,426,427,272,248,717,344,350,353,431,383,386,368,371)
AND (v.conditionActive=1 OR v.conditionActive=2);
	/*END OF MIGRATION FOR ANTÉCEDENTS MÉDICAUX ET DIAGNOSTICS ACTUELS*/
select 12 as arvTraitement;
	
	/*MIGRATION FOR ARV : TRAITEMENTS PRÉCÉDENTS MENU*/
	/*Migration for Est-ce que le patient a déjà utilisé des ARV ?*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160117,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.arvEver=1 THEN 160119 END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.arvEnrollment v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.arvEver=1;
	/*(-) INTIs*/
	/*Migration for Abacavir (ABC)*/
	/*Concept group*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160741,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=160741 
GROUP BY openmrs.obs.person_id,encounter_id;

set vobs_id=last_insert_id();
		
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,70056,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=1;
		/*==================================================*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160742,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,138405,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v ,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=1;		
		
		/*Migration for Début MM/AA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1190,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.startMm<1 AND v.startYy>0 THEN CONCAT(v.startYy,'-',01,'-',01)
		WHEN v.startMm>0 AND v.startYy>0 THEN CONCAT(v.startYy,'-',v.startMm,'-',01)
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v ,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=1 AND v.startYy>0;			

		/*Migration for Arrêt MM/AA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1191,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.stopMm<1 AND v.stopYy>0 THEN CONCAT(v.stopYy,'-',01,'-',01)
		WHEN v.stopMm>0 AND v.stopYy>0 THEN CONCAT(v.stopYy,'-',v.stopMm,'-',01)
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v 	,itech.obs_concept_group og 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=1 AND v.stopYy>0;			

		/*Migration for Utilisation courante*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159367,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,1065,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og  	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=1 and v.isContinued=1;
		/*Arrêt : raison*/
		/*Migration for Tox,Intol,Ech,Inconnu,Fin PTME*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,6098,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,		
		case when v.toxicity=1 then 102
		     when v.intolerance=1 then 987
			 when v.failure=1 then 843
			 when v.discUnknown=1 then 1067
			 when v.finPTME=1 then 1253
		end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v ,itech.obs_concept_group og 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')= concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=1 and (v.isContinued=1 or v.toxicity=1 or v.intolerance=1 or v.failure=1 or v.discUnknown=1 or v.finPTME=1);

	/*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
	/*Migration for Combivir (AZT+3TC)*/
		/*Concept group*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160741,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')= concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=8;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=160741 
GROUP BY openmrs.obs.person_id,encounter_id;

set vobs_id=last_insert_id();
		
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,630,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=8;
		/*==================================================*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160742,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,138405,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=8;		
		
		/*Migration for Début MM/AA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1190,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.startMm<1 AND v.startYy>0 THEN CONCAT(v.startYy,'-',01,'-',01)
		WHEN v.startMm>0 AND v.startYy>0 THEN CONCAT(v.startYy,'-',v.startMm,'-',01)
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=8 AND v.startYy>0;			

		/*Migration for Arrêt MM/AA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1191,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.stopMm<1 AND v.stopYy>0 THEN CONCAT(v.stopYy,'-',01,'-',01)
		WHEN v.stopMm>0 AND v.stopYy>0 THEN CONCAT(v.stopYy,'-',v.stopMm,'-',01)
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v 	,itech.obs_concept_group og	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=8 AND v.stopYy>0;			

		/*Migration for Utilisation courante*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159367,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,1065,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v ,itech.obs_concept_group og	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=8 and v.isContinued=1;
		/*Arrêt : raison*/
		/*Migration for Tox,Intol,Ech,Inconnu,Fin PTME*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,6098,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,		
		case when v.toxicity=1 then 102
		     when v.intolerance=1 then 987
			 when v.failure=1 then 843
			 when v.discUnknown=1 then 1067
			 when v.finPTME=1 then 1253
		end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v ,itech.obs_concept_group og	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=8 and (v.isContinued=1 or v.toxicity=1 or v.intolerance=1 or v.failure=1 or v.discUnknown=1 or v.finPTME=1);		

	
	/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
	/*Migration for Didanosine (ddI) */
	/*Concept group*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160741,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=10;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=160741 
GROUP BY openmrs.obs.person_id,encounter_id;

set vobs_id=last_insert_id();
		
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,74807,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=10;
		/*==================================================*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160742,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,138405,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=10;		
		
		/*Migration for Début MM/AA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1190,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.startMm<1 AND v.startYy>0 THEN CONCAT(v.startYy,'-',01,'-',01)
		WHEN v.startMm>0 AND v.startYy>0 THEN CONCAT(v.startYy,'-',v.startMm,'-',01)
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=10 AND v.startYy>0;			

		/*Migration for Arrêt MM/AA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1191,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.stopMm<1 AND v.stopYy>0 THEN CONCAT(v.stopYy,'-',01,'-',01)
		WHEN v.stopMm>0 AND v.stopYy>0 THEN CONCAT(v.stopYy,'-',v.stopMm,'-',01)
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 		
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')= concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=10 AND v.stopYy>0;			

		/*Migration for Utilisation courante*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159367,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,1065,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and e.encounter_datetime = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=10 and v.isContinued=1;
		/*Arrêt : raison*/
		/*Migration for Tox,Intol,Ech,Inconnu,Fin PTME*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,6098,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,		
		case when v.toxicity=1 then 102
		     when v.intolerance=1 then 987
			 when v.failure=1 then 843
			 when v.discUnknown=1 then 1067
			 when v.finPTME=1 then 1253
		end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=10 and (v.isContinued=1 or v.toxicity=1 or v.intolerance=1 or v.failure=1 or v.discUnknown=1 or v.finPTME=1);
 
	/*======================================================================================================================*/
	/*Migration for Emtricitabine (FTC)*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160741,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=12;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=160741 
GROUP BY openmrs.obs.person_id,encounter_id;

set vobs_id=last_insert_id();
		
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,75628,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=12;
		/*==================================================*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160742,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,138405,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=12;		
		
		/*Migration for Début MM/AA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1190,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.startMm<1 AND v.startYy>0 THEN CONCAT(v.startYy,'-',01,'-',01)
		WHEN v.startMm>0 AND v.startYy>0 THEN CONCAT(v.startYy,'-',v.startMm,'-',01)
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=12 AND v.startYy>0;			

		/*Migration for Arrêt MM/AA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1191,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.stopMm<1 AND v.stopYy>0 THEN CONCAT(v.stopYy,'-',01,'-',01)
		WHEN v.stopMm>0 AND v.stopYy>0 THEN CONCAT(v.stopYy,'-',v.stopMm,'-',01)
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 		
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=12 AND v.stopYy>0;			

		/*Migration for Utilisation courante*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159367,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,1065,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=12 and v.isContinued=1;
		/*Arrêt : raison*/
		/*Migration for Tox,Intol,Ech,Inconnu,Fin PTME*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,6098,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,		
		case when v.toxicity=1 then 102
		     when v.intolerance=1 then 987
			 when v.failure=1 then 843
			 when v.discUnknown=1 then 1067
			 when v.finPTME=1 then 1253
		end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=12 and (v.isContinued=1 or v.toxicity=1 or v.intolerance=1 or v.failure=1 or v.discUnknown=1 or v.finPTME=1);

	/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/	
	/*Migration for Lamivudine (3TC)*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160741,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=20;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=160741 
GROUP BY openmrs.obs.person_id,encounter_id;

set vobs_id=last_insert_id();
		
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,78643,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')= concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=20;
		/*==================================================*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160742,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,138405,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=20;		
		
		/*Migration for Début MM/AA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1190,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.startMm<1 AND v.startYy>0 THEN CONCAT(v.startYy,'-',01,'-',01)
		WHEN v.startMm>0 AND v.startYy>0 THEN CONCAT(v.startYy,'-',v.startMm,'-',01)
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=20 AND v.startYy>0;			

		/*Migration for Arrêt MM/AA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1191,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.stopMm<1 AND v.stopYy>0 THEN CONCAT(v.stopYy,'-',01,'-',01)
		WHEN v.stopMm>0 AND v.stopYy>0 THEN CONCAT(v.stopYy,'-',v.stopMm,'-',01)
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 		
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=20 AND v.stopYy>0;			

		/*Migration for Utilisation courante*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159367,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,1065,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v ,itech.obs_concept_group og	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')= concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=20 and v.isContinued=1;
		/*Arrêt : raison*/
		/*Migration for Tox,Intol,Ech,Inconnu,Fin PTME*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,6098,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,		
		case when v.toxicity=1 then 102
		     when v.intolerance=1 then 987
			 when v.failure=1 then 843
			 when v.discUnknown=1 then 1067
			 when v.finPTME=1 then 1253
		end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v ,itech.obs_concept_group og	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=20 and (v.isContinued=1 or v.toxicity=1 or v.intolerance=1 or v.failure=1 or v.discUnknown=1 or v.finPTME=1);	

		/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
		/*Migration for Stavudine (d4T)*/
		/*Migration for the group*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160741,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=29;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=160741 
GROUP BY openmrs.obs.person_id,encounter_id;

set vobs_id=last_insert_id();
		
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,84309,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=29;
		/*==================================================*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160742,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,138405,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')= concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=29;		
		
		/*Migration for Début MM/AA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1190,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.startMm<1 AND v.startYy>0 THEN CONCAT(v.startYy,'-',01,'-',01)
		WHEN v.startMm>0 AND v.startYy>0 THEN CONCAT(v.startYy,'-',v.startMm,'-',01)
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=29 AND v.startYy>0;			

		/*Migration for Arrêt MM/AA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1191,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.stopMm<1 AND v.stopYy>0 THEN CONCAT(v.stopYy,'-',01,'-',01)
		WHEN v.stopMm>0 AND v.stopYy>0 THEN CONCAT(v.stopYy,'-',v.stopMm,'-',01)
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 		
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=29 AND v.stopYy>0;			

		/*Migration for Utilisation courante*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159367,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,1065,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=29 and v.isContinued=1;
		/*Arrêt : raison*/
		/*Migration for Tox,Intol,Ech,Inconnu,Fin PTME*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,6098,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,		
		case when v.toxicity=1 then 102
		     when v.intolerance=1 then 987
			 when v.failure=1 then 843
			 when v.discUnknown=1 then 1067
			 when v.finPTME=1 then 1253
		end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=29 and (v.isContinued=1 or v.toxicity=1 or v.intolerance=1 or v.failure=1 or v.discUnknown=1 or v.finPTME=1);			
		

		
		/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
		/*Migration for Tenofovir (TNF)*/
		/*Migration for the group*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160741,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=31;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=160741 
GROUP BY openmrs.obs.person_id,encounter_id;

set vobs_id=last_insert_id();
		
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,84795,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')= concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=31;
		/*==================================================*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160742,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,138405,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=31;		
		
		/*Migration for Début MM/AA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1190,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.startMm<1 AND v.startYy>0 THEN CONCAT(v.startYy,'-',01,'-',01)
		WHEN v.startMm>0 AND v.startYy>0 THEN CONCAT(v.startYy,'-',v.startMm,'-',01)
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=31 AND v.startYy>0;			

		/*Migration for Arrêt MM/AA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1191,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.stopMm<1 AND v.stopYy>0 THEN CONCAT(v.stopYy,'-',01,'-',01)
		WHEN v.stopMm>0 AND v.stopYy>0 THEN CONCAT(v.stopYy,'-',v.stopMm,'-',01)
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 		
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=31 AND v.stopYy>0;			

		/*Migration for Utilisation courante*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159367,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,1065,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=31 and v.isContinued=1;
		/*Arrêt : raison*/
		/*Migration for Tox,Intol,Ech,Inconnu,Fin PTME*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,6098,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,		
		case when v.toxicity=1 then 102
		     when v.intolerance=1 then 987
			 when v.failure=1 then 843
			 when v.discUnknown=1 then 1067
			 when v.finPTME=1 then 1253
		end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=31 and (v.isContinued=1 or v.toxicity=1 or v.intolerance=1 or v.failure=1 or v.discUnknown=1 or v.finPTME=1);	


		/*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
		/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
		/*Migration for Trizivir (ABC+AZT+3TC)*/
		/*Migration for the group*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160741,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=33;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=160741 
GROUP BY openmrs.obs.person_id,encounter_id;

set vobs_id=last_insert_id();
		
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,817,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=33;
		/*==================================================*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160742,e.encounter_id,e.encounter_datetime,e.location_id,vobs_id,138405,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=33;		
		
		/*Migration for Début MM/AA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1190,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.startMm<1 AND v.startYy>0 THEN CONCAT(v.startYy,'-',01,'-',01)
		WHEN v.startMm>0 AND v.startYy>0 THEN CONCAT(v.startYy,'-',v.startMm,'-',01)
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=33 AND v.startYy>0;			

		/*Migration for Arrêt MM/AA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1191,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.stopMm<1 AND v.stopYy>0 THEN CONCAT(v.stopYy,'-',01,'-',01)
		WHEN v.stopMm>0 AND v.stopYy>0 THEN CONCAT(v.stopYy,'-',v.stopMm,'-',01)
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 		
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=33 AND v.stopYy>0;			

		/*Migration for Utilisation courante*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159367,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,1065,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=33 and v.isContinued=1;
		/*Arrêt : raison*/
		/*Migration for Tox,Intol,Ech,Inconnu,Fin PTME*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,6098,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,		
		case when v.toxicity=1 then 102
		     when v.intolerance=1 then 987
			 when v.failure=1 then 843
			 when v.discUnknown=1 then 1067
			 when v.finPTME=1 then 1253
		end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=33 and (v.isContinued=1 or v.toxicity=1 or v.intolerance=1 or v.failure=1 or v.discUnknown=1 or v.finPTME=1);		

		/*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
		/*Migration for Zidovudine (AZT)*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160741,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=34;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=160741 
GROUP BY openmrs.obs.person_id,encounter_id;

set vobs_id=last_insert_id();
		
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,86663,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=34;
		/*==================================================*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160742,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,138405,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=34;		
		
		/*Migration for Début MM/AA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1190,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.startMm<1 AND v.startYy>0 THEN CONCAT(v.startYy,'-',01,'-',01)
		WHEN v.startMm>0 AND v.startYy>0 THEN CONCAT(v.startYy,'-',v.startMm,'-',01)
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=34 AND v.startYy>0;			

		/*Migration for Arrêt MM/AA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1191,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.stopMm<1 AND v.stopYy>0 THEN CONCAT(v.stopYy,'-',01,'-',01)
		WHEN v.stopMm>0 AND v.stopYy>0 THEN CONCAT(v.stopYy,'-',v.stopMm,'-',01)
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 		
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=34 AND v.stopYy>0;			

		/*Migration for Utilisation courante*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159367,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,1065,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=34 and v.isContinued=1;
		/*Arrêt : raison*/
		/*Migration for Tox,Intol,Ech,Inconnu,Fin PTME*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,6098,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,		
		case when v.toxicity=1 then 102
		     when v.intolerance=1 then 987
			 when v.failure=1 then 843
			 when v.discUnknown=1 then 1067
			 when v.finPTME=1 then 1253
		end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')= concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=34 and (v.isContinued=1 or v.toxicity=1 or v.intolerance=1 or v.failure=1 or v.discUnknown=1 or v.finPTME=1);	

		/*Migration for Efavirenz (EFV)*/
		/*Migration for the group*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160741,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')= concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=11;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=160741 
GROUP BY openmrs.obs.person_id,encounter_id;

set vobs_id=last_insert_id();
		
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,75523,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=11;
		/*==================================================*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160742,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,138405,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=11;		
		
		/*Migration for Début MM/AA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1190,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.startMm<1 AND v.startYy>0 THEN CONCAT(v.startYy,'-',01,'-',01)
		WHEN v.startMm>0 AND v.startYy>0 THEN CONCAT(v.startYy,'-',v.startMm,'-',01)
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=11 AND v.startYy>0;			

		/*Migration for Arrêt MM/AA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1191,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.stopMm<1 AND v.stopYy>0 THEN CONCAT(v.stopYy,'-',01,'-',01)
		WHEN v.stopMm>0 AND v.stopYy>0 THEN CONCAT(v.stopYy,'-',v.stopMm,'-',01)
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 		
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=11 AND v.stopYy>0;			

		/*Migration for Utilisation courante*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159367,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,1065,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=11 and v.isContinued=1;
		/*Arrêt : raison*/
		/*Migration for Tox,Intol,Ech,Inconnu,Fin PTME*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,6098,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,		
		case when v.toxicity=1 then 102
		     when v.intolerance=1 then 987
			 when v.failure=1 then 843
			 when v.discUnknown=1 then 1067
			 when v.finPTME=1 then 1253
		end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=11 and (v.isContinued=1 or v.toxicity=1 or v.intolerance=1 or v.failure=1 or v.discUnknown=1 or v.finPTME=1);	


		/*=========================================================================================================================*/
		/*Migration for Nevirapine (NVP)*/
			/*Migration for the group*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160741,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=23;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=160741 
GROUP BY openmrs.obs.person_id,encounter_id;

set vobs_id=last_insert_id();
		
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,80586,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=23;
		/*==================================================*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160742,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,138405,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=23;		
		
		/*Migration for Début MM/AA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1190,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.startMm<1 AND v.startYy>0 THEN CONCAT(v.startYy,'-',01,'-',01)
		WHEN v.startMm>0 AND v.startYy>0 THEN CONCAT(v.startYy,'-',v.startMm,'-',01)
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=23 AND v.startYy>0;			

		/*Migration for Arrêt MM/AA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1191,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.stopMm<1 AND v.stopYy>0 THEN CONCAT(v.stopYy,'-',01,'-',01)
		WHEN v.stopMm>0 AND v.stopYy>0 THEN CONCAT(v.stopYy,'-',v.stopMm,'-',01)
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 		
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=23 AND v.stopYy>0;			

		/*Migration for Utilisation courante*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159367,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,1065,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=23 and v.isContinued=1;
		/*Arrêt : raison*/
		/*Migration for Tox,Intol,Ech,Inconnu,Fin PTME*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,6098,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,		
		case when v.toxicity=1 then 102
		     when v.intolerance=1 then 987
			 when v.failure=1 then 843
			 when v.discUnknown=1 then 1067
			 when v.finPTME=1 then 1253
		end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=23 and (v.isContinued=1 or v.toxicity=1 or v.intolerance=1 or v.failure=1 or v.discUnknown=1 or v.finPTME=1);	

		/*Migration for Atazanavir (ATZN)*/
		/*Migration for the group*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160741,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')= concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=5;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=160741 
GROUP BY openmrs.obs.person_id,encounter_id;

set vobs_id=last_insert_id();
		
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,71647,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=5;
		/*==================================================*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160742,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,138405,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=5;		
		
		/*Migration for Début MM/AA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1190,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.startMm<1 AND v.startYy>0 THEN CONCAT(v.startYy,'-',01,'-',01)
		WHEN v.startMm>0 AND v.startYy>0 THEN CONCAT(v.startYy,'-',v.startMm,'-',01)
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')= concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=5 AND v.startYy>0;			

		/*Migration for Arrêt MM/AA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1191,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.stopMm<1 AND v.stopYy>0 THEN CONCAT(v.stopYy,'-',01,'-',01)
		WHEN v.stopMm>0 AND v.stopYy>0 THEN CONCAT(v.stopYy,'-',v.stopMm,'-',01)
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 		
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=5 AND v.stopYy>0;			

		/*Migration for Utilisation courante*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159367,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,1065,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=5 and v.isContinued=1;
		/*Arrêt : raison*/
		/*Migration for Tox,Intol,Ech,Inconnu,Fin PTME*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,6098,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,		
		case when v.toxicity=1 then 102
		     when v.intolerance=1 then 987
			 when v.failure=1 then 843
			 when v.discUnknown=1 then 1067
			 when v.finPTME=1 then 1253
		end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=5 and (v.isContinued=1 or v.toxicity=1 or v.intolerance=1 or v.failure=1 or v.discUnknown=1 or v.finPTME=1);	

		/*+++++++++++++++++++++++++++++++++++++++++++++++*/
		/*Migration for Atazanavir+BostRTV*/
		/*Migration for the group*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160741,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=6;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=160741 
GROUP BY openmrs.obs.person_id,encounter_id;

set vobs_id=last_insert_id();
		
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159809,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=6;
		/*==================================================*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160742,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,138405,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=6;		
		
		/*Migration for Début MM/AA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1190,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.startMm<1 AND v.startYy>0 THEN CONCAT(v.startYy,'-',01,'-',01)
		WHEN v.startMm>0 AND v.startYy>0 THEN CONCAT(v.startYy,'-',v.startMm,'-',01)
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=6 AND v.startYy>0;			

		/*Migration for Arrêt MM/AA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1191,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.stopMm<1 AND v.stopYy>0 THEN CONCAT(v.stopYy,'-',01,'-',01)
		WHEN v.stopMm>0 AND v.stopYy>0 THEN CONCAT(v.stopYy,'-',v.stopMm,'-',01)
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 		
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=6 AND v.stopYy>0;			

		/*Migration for Utilisation courante*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159367,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,1065,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=6 and v.isContinued=1;
		/*Arrêt : raison*/
		/*Migration for Tox,Intol,Ech,Inconnu,Fin PTME*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,6098,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,		
		case when v.toxicity=1 then 102
		     when v.intolerance=1 then 987
			 when v.failure=1 then 843
			 when v.discUnknown=1 then 1067
			 when v.finPTME=1 then 1253
		end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=6 and (v.isContinued=1 or v.toxicity=1 or v.intolerance=1 or v.failure=1 or v.discUnknown=1 or v.finPTME=1);	

		/*--------------------------------------------------------------------------------------------------------*/
		/*Migration for Indinavir (IDV)*/
		/*Migration for the group*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160741,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=16;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=160741 
GROUP BY openmrs.obs.person_id,encounter_id;

set vobs_id=last_insert_id();
		
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,77995,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=16;
		/*==================================================*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160742,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,138405,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=16;		
		
		/*Migration for Début MM/AA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1190,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.startMm<1 AND v.startYy>0 THEN CONCAT(v.startYy,'-',01,'-',01)
		WHEN v.startMm>0 AND v.startYy>0 THEN CONCAT(v.startYy,'-',v.startMm,'-',01)
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=16 AND v.startYy>0;			

		/*Migration for Arrêt MM/AA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1191,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.stopMm<1 AND v.stopYy>0 THEN CONCAT(v.stopYy,'-',01,'-',01)
		WHEN v.stopMm>0 AND v.stopYy>0 THEN CONCAT(v.stopYy,'-',v.stopMm,'-',01)
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 		
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=16 AND v.stopYy>0;			

		/*Migration for Utilisation courante*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159367,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,1065,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=16 and v.isContinued=1;
		/*Arrêt : raison*/
		/*Migration for Tox,Intol,Ech,Inconnu,Fin PTME*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,6098,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,		
		case when v.toxicity=1 then 102
		     when v.intolerance=1 then 987
			 when v.failure=1 then 843
			 when v.discUnknown=1 then 1067
			 when v.finPTME=1 then 1253
		end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=16 and (v.isContinued=1 or v.toxicity=1 or v.intolerance=1 or v.failure=1 or v.discUnknown=1 or v.finPTME=1);	

		/*---------------------------------------------------------------------------------------------------------------------------*/
		/*Migration for Lopinavir+BostRTV (Kaletra)*/
		/*Migration for the group*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160741,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=21;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=160741 
GROUP BY openmrs.obs.person_id,encounter_id;

set vobs_id=last_insert_id();
		
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,794,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=21;
		/*==================================================*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160742,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,138405,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')= concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=21;		
		
		/*Migration for Début MM/AA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1190,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.startMm<1 AND v.startYy>0 THEN CONCAT(v.startYy,'-',01,'-',01)
		WHEN v.startMm>0 AND v.startYy>0 THEN CONCAT(v.startYy,'-',v.startMm,'-',01)
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=21 AND v.startYy>0;			

		/*Migration for Arrêt MM/AA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1191,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.stopMm<1 AND v.stopYy>0 THEN CONCAT(v.stopYy,'-',01,'-',01)
		WHEN v.stopMm>0 AND v.stopYy>0 THEN CONCAT(v.stopYy,'-',v.stopMm,'-',01)
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 		
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=21 AND v.stopYy>0;			

		/*Migration for Utilisation courante*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159367,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,1065,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=21 and v.isContinued=1;
		/*Arrêt : raison*/
		/*Migration for Tox,Intol,Ech,Inconnu,Fin PTME*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,6098,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,		
		case when v.toxicity=1 then 102
		     when v.intolerance=1 then 987
			 when v.failure=1 then 843
			 when v.discUnknown=1 then 1067
			 when v.finPTME=1 then 1253
		end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=21 and (v.isContinued=1 or v.toxicity=1 or v.intolerance=1 or v.failure=1 or v.discUnknown=1 or v.finPTME=1);
		
		/*Autre a Verifier +++++++++++++++++++++++==========================++++++++++++++++++++++++++++++++++==*/
	/*END OF MIGRATION FOR ARV : TRAITEMENTS PRÉCÉDENTS MENU*/
	/*MIGRATION FOR REMARQUES MENU*/
	
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163322,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.drugComments<>'' THEN v.drugComments
	 ELSE NULL
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugComments<>'';

	/*END OF MIGRATION FOR REMARQUES MENU*/
	
	

	/*MIGRATION FOR ARV ET GROSSESSE (SEXE F) MENU*/
	/*Migration for Est-ce que la patiente a pris un médicament ARV exclusivement afin de prévenir la transmission mère-enfant ?*/	
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,966,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.ARVexcl=1 THEN 1107 END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.arvAndPregnancy v 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.ARVexcl=1;
/*Migration for Zidovudine,Nevirapine (NVP),Inconnu,Autre :*/	
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,966,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.zidovudineARVpreg=1 THEN 86663
	 WHEN v.nevirapineARVpreg=1 THEN 80586
	 WHEN v.unknownARVpreg=1 THEN 1067
	 WHEN v.otherARVpreg=1 THEN 5424
END,
CASE WHEN v.otherARVpreg=1 AND v.otherTextARVpreg<>'' THEN v.otherTextARVpreg ELSE NULL END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.arvAndPregnancy v 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
(v.zidovudineARVpreg=1 OR v.nevirapineARVpreg=1 OR v.unknownARVpreg=1 OR v.otherARVpreg=1);
	/*END OF ARV ET GROSSESSE (SEXE F) MENU*/	


	
/*MIGRATION FOR AUTRES TRAITEMENTS PRÉCÉDENTS MENU */
		/*Migration for Ethambutol*/
		/*Migration for the group*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160741,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=13;	

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=160741 
GROUP BY openmrs.obs.person_id,encounter_id;	

set vobs_id=last_insert_id();
		
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,75948,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')= concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=13;
		/*==================================================*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160742,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,138405,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and e.encounter_datetime = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=13;		
		
		/*Migration for Début MM/AA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1190,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.startMm<1 AND v.startYy>0 THEN CONCAT(v.startYy,'-',01,'-',01)
		WHEN v.startMm>0 AND v.startYy>0 THEN CONCAT(v.startYy,'-',v.startMm,'-',01)
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')= concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=13 AND v.startYy>0;			

		/*Migration for Arrêt MM/AA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1191,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.stopMm<1 AND v.stopYy>0 THEN CONCAT(v.stopYy,'-',01,'-',01)
		WHEN v.stopMm>0 AND v.stopYy>0 THEN CONCAT(v.stopYy,'-',v.stopMm,'-',01)
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v ,itech.obs_concept_group og		
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=13 AND v.stopYy>0;			

		/*Migration for Utilisation courante*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159367,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,1065,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=13 and v.isContinued=1;

		
		/*Migration for Isoniazide (INH)*/
		/*Migration for the group*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160741,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=18;		

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=160741 
GROUP BY openmrs.obs.person_id,encounter_id;

set vobs_id=last_insert_id();
		
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,78280,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=18;
		/*==================================================*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160742,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,138405,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=18;		
		
		/*Migration for Début MM/AA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1190,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.startMm<1 AND v.startYy>0 THEN CONCAT(v.startYy,'-',01,'-',01)
		WHEN v.startMm>0 AND v.startYy>0 THEN CONCAT(v.startYy,'-',v.startMm,'-',01)
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=18 AND v.startYy>0;			

		/*Migration for Arrêt MM/AA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1191,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.stopMm<1 AND v.stopYy>0 THEN CONCAT(v.stopYy,'-',01,'-',01)
		WHEN v.stopMm>0 AND v.stopYy>0 THEN CONCAT(v.stopYy,'-',v.stopMm,'-',01)
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 		
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=18 AND v.stopYy>0;			

		/*Migration for Utilisation courante*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159367,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,1065,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')= concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=18 and v.isContinued=1;		

		/*Migration for Pyrazinamide*/
		/*Migration for the group*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160741,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=24;		

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=160741 
GROUP BY openmrs.obs.person_id,encounter_id;

set vobs_id=last_insert_id();
		
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,82900,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and e.encounter_datetime = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=24;
		/*==================================================*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160742,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,138405,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=24;		
		
		/*Migration for Début MM/AA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1190,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.startMm<1 AND v.startYy>0 THEN CONCAT(v.startYy,'-',01,'-',01)
		WHEN v.startMm>0 AND v.startYy>0 THEN CONCAT(v.startYy,'-',v.startMm,'-',01)
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=24 AND v.startYy>0;			

		/*Migration for Arrêt MM/AA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1191,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.stopMm<1 AND v.stopYy>0 THEN CONCAT(v.stopYy,'-',01,'-',01)
		WHEN v.stopMm>0 AND v.stopYy>0 THEN CONCAT(v.stopYy,'-',v.stopMm,'-',01)
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 		
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=24 AND v.stopYy>0;			

		/*Migration for Utilisation courante*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159367,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,1065,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')= concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=24 and v.isContinued=1;

		/*Migration for Rifampicine*/
		/*Migration for Streptomycine*/
		/*Migration for Acyclovir*/
		/*Migration for the group*/
		
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160741,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=2;		

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=160741 
GROUP BY openmrs.obs.person_id,encounter_id;

set vobs_id=last_insert_id();
		
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,70245,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=2;
		/*==================================================*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160742,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,138405,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=2;		
		
		/*Migration for Début MM/AA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1190,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.startMm<1 AND v.startYy>0 THEN CONCAT(v.startYy,'-',01,'-',01)
		WHEN v.startMm>0 AND v.startYy>0 THEN CONCAT(v.startYy,'-',v.startMm,'-',01)
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=2 AND v.startYy>0;			

		/*Migration for Arrêt MM/AA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1191,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.stopMm<1 AND v.stopYy>0 THEN CONCAT(v.stopYy,'-',01,'-',01)
		WHEN v.stopMm>0 AND v.stopYy>0 THEN CONCAT(v.stopYy,'-',v.stopMm,'-',01)
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 		
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=2 AND v.stopYy>0;			

		/*Migration for Utilisation courante*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159367,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,1065,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=2 and v.isContinued=1;		

		/*Migration for Cotrimoxazole (TMS)*/
		/*Migration for the group*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160741,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=9;		

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=160741 
GROUP BY openmrs.obs.person_id,encounter_id;

set vobs_id=last_insert_id();
		
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,105281,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=9;
		/*==================================================*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160742,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,138405,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')= concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=9;		
		
		/*Migration for Début MM/AA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1190,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.startMm<1 AND v.startYy>0 THEN CONCAT(v.startYy,'-',01,'-',01)
		WHEN v.startMm>0 AND v.startYy>0 THEN CONCAT(v.startYy,'-',v.startMm,'-',01)
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=9 AND v.startYy>0;			

		/*Migration for Arrêt MM/AA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1191,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.stopMm<1 AND v.stopYy>0 THEN CONCAT(v.stopYy,'-',01,'-',01)
		WHEN v.stopMm>0 AND v.stopYy>0 THEN CONCAT(v.stopYy,'-',v.stopMm,'-',01)
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 		
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=9 AND v.stopYy>0;			

		/*Migration for Utilisation courante*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159367,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,1065,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=9 and v.isContinued=1;			

		/*Migration for Fluconazole*/
		/*Migration for the group*/
		
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160741,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=14;		

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=160741 
GROUP BY openmrs.obs.person_id,encounter_id;

set vobs_id=last_insert_id();
		
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,76488,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')= concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=14;
		/*==================================================*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160742,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,138405,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=14;		
		
		/*Migration for Début MM/AA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1190,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.startMm<1 AND v.startYy>0 THEN CONCAT(v.startYy,'-',01,'-',01)
		WHEN v.startMm>0 AND v.startYy>0 THEN CONCAT(v.startYy,'-',v.startMm,'-',01)
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=14 AND v.startYy>0;			

		/*Migration for Arrêt MM/AA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1191,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.stopMm<1 AND v.stopYy>0 THEN CONCAT(v.stopYy,'-',01,'-',01)
		WHEN v.stopMm>0 AND v.stopYy>0 THEN CONCAT(v.stopYy,'-',v.stopMm,'-',01)
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 		
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=14 AND v.stopYy>0;			

		/*Migration for Utilisation courante*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159367,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,1065,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=14 and v.isContinued=1;			
		
		/*Migration for Ketaconazole*/
			/*Migration for the group*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160741,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=19;		

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=160741 
GROUP BY openmrs.obs.person_id,encounter_id;

set vobs_id=last_insert_id();
		
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,78476,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=19;
		/*==================================================*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160742,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,138405,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=19;		
		
		/*Migration for Début MM/AA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1190,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.startMm<1 AND v.startYy>0 THEN CONCAT(v.startYy,'-',01,'-',01)
		WHEN v.startMm>0 AND v.startYy>0 THEN CONCAT(v.startYy,'-',v.startMm,'-',01)
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')= concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=19 AND v.startYy>0;			

		/*Migration for Arrêt MM/AA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1191,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.stopMm<1 AND v.stopYy>0 THEN CONCAT(v.stopYy,'-',01,'-',01)
		WHEN v.stopMm>0 AND v.stopYy>0 THEN CONCAT(v.stopYy,'-',v.stopMm,'-',01)
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 		
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=19 AND v.stopYy>0;			

		/*Migration for Utilisation courante*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159367,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,1065,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=19 and v.isContinued=1;			
			

		/*Migration for Traitement traditionnelle*/
		/*Migration for the group*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160741,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=35;		

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=160741 
GROUP BY openmrs.obs.person_id,encounter_id;

set vobs_id=last_insert_id();
		
		/*migration for the concept*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,5841,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=35;
		/*==================================================*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160742,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,138405,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=35;		
		
		/*Migration for Début MM/AA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1190,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.startMm<1 AND v.startYy>0 THEN CONCAT(v.startYy,'-',01,'-',01)
		WHEN v.startMm>0 AND v.startYy>0 THEN CONCAT(v.startYy,'-',v.startMm,'-',01)
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=35 AND v.startYy>0;			

		/*Migration for Arrêt MM/AA*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1191,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
CASE WHEN v.stopMm<1 AND v.stopYy>0 THEN CONCAT(v.stopYy,'-',01,'-',01)
		WHEN v.stopMm>0 AND v.stopYy>0 THEN CONCAT(v.stopYy,'-',v.stopMm,'-',01)
		END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 		
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=35 AND v.stopYy>0;			

		/*Migration for Utilisation courante*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159367,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,1065,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.drugs v,itech.obs_concept_group og 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=35 and v.isContinued=1;


/*Migration for Commentaire*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163323,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.treatmentComments<>'' THEN v.treatmentComments ELSE NULL END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')= concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.treatmentComments<>'';


		/*Migration for Autres, préciser :*/
		/*Migration for the group*/
/* other drugs can be multiple in the table */
	/*END OF AUTRES TRAITEMENTS PRÉCÉDENTS MENU*/	
	
	
/*MIGRATION FOR ÉLIGIBILITÉ MÉDICALE AUX ARV MENU*/
		/*Stade OMS actuel*/
		/*Migration for Stade I (Asymptomatique) AND Stade II (Symptomatique) AND Stade III (Symptomatique) AND Stade IV (SIDA)*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,5356,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.currentHivStage=1 THEN 1204
	 WHEN v.currentHivStage=2 THEN 1205
	 WHEN v.currentHivStage=4 THEN 1206
	 WHEN v.currentHivStage=8 THEN 1207
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.medicalEligARVs v 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
(v.currentHivStage=1 OR v.currentHivStage=2 OR v.currentHivStage=4 OR v.currentHivStage=8);

		/*Migration for Éligibilité médicale aux ARV*/
		/*Migration for Oui - préciser la raison AND Non - pas d'éligibilité médicale aujourd'hui AND À déterminer*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,162703,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.medElig=1 THEN 1065
	 WHEN v.medElig=4 THEN 1066
	 WHEN v.medElig=8 THEN 1067
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.medicalEligARVs v 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
(v.medElig=1 OR v.medElig=4 OR v.medElig=8);
		/*Raison d'éligibilité médicale aux ARV*/
		/*Migration for CD4 inférieur au seuil (500) */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,162225,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.cd4LT200=1 THEN 5497 
     WHEN v.WHOIII=1 THEN 163326
	 WHEN v.WHOIV=1 THEN 1207
	 WHEN v.PMTCT=1 THEN 160538
	 WHEN v.medEligHAART=1 THEN 163327
	 WHEN v.formerARVtherapy=1 THEN 1087
	 WHEN v.PEP=1 THEN 1691
	 WHEN v.coinfectionTbHiv=1 THEN 163324
	 WHEN v.coinfectionHbvHiv=1 THEN 163325
	 WHEN v.coupleSerodiscordant=1 THEN 6096
	 WHEN v.pregnantWomen=1 THEN 1434
	 WHEN v.breastfeedingWomen=1 THEN 5632
	 WHEN v.patientGt50ans=1 THEN 163328
	 WHEN v.nephropathieVih=1 THEN 153701
	 WHEN v.protocoleTestTraitement=1 THEN 163329
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.medicalEligARVs v 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.medElig=1	AND (v.cd4LT200=1 or v.WHOIII=1 or v.WHOIV=1 or v.PMTCT=1 or v.medEligHAART=1 or v.formerARVtherapy=1 or 
                 v.PEP=1 or v.coinfectionTbHiv=1 or v.coinfectionHbvHiv=1 or v.coupleSerodiscordant=1 or v.pregnantWomen=1 or 
                 v.breastfeedingWomen=1 or v.patientGt50ans=1 or v.nephropathieVih=1 or v.protocoleTestTraitement=1);	

INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,162225,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.WHOIII=1 THEN 163326 else null END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.medicalEligARVs v 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.medElig=1	AND (v.WHOIII=1);					 
				 
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,162225,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.WHOIV=1 THEN 1207 else null END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.medicalEligARVs v 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.medElig=1	AND (v.WHOIV=1);	

INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,162225,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.PMTCT=1 THEN 160538 else null END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.medicalEligARVs v 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.medElig=1	AND (v.PMTCT=1);

INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,162225,e.encounter_id,e.encounter_datetime,e.location_id,
CASE  WHEN v.medEligHAART=1 THEN 163327 else null END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.medicalEligARVs v 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.medElig=1	AND (v.medEligHAART=1);	

INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,162225,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.formerARVtherapy=1 THEN 1087 else null END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.medicalEligARVs v 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.medElig=1	AND (v.formerARVtherapy=1);	

INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,162225,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.PEP=1 THEN 1691 else null END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.medicalEligARVs v 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.medElig=1	AND (v.PEP=1);		

INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,162225,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.coinfectionTbHiv=1 THEN 163324 else null END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.medicalEligARVs v 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.medElig=1	AND (v.coinfectionTbHiv=1);	

INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,162225,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.coinfectionHbvHiv=1 THEN 163325 else null END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.medicalEligARVs v 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.medElig=1	AND (v.coinfectionHbvHiv=1);

INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,162225,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.coupleSerodiscordant=1 THEN 6096 else null END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.medicalEligARVs v 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.medElig=1	AND ( v.coupleSerodiscordant=1);	

INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,162225,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.pregnantWomen=1 THEN 1434 else null END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.medicalEligARVs v 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.medElig=1	AND (v.pregnantWomen=1);

INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,162225,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.breastfeedingWomen=1 THEN 5632 else null END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.medicalEligARVs v 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.medElig=1	AND (v.breastfeedingWomen=1);

INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,162225,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.patientGt50ans=1 THEN 163328 else null END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.medicalEligARVs v 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.medElig=1	AND (v.patientGt50ans=1);	

INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,162225,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.nephropathieVih=1 THEN 153701 else null END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.medicalEligARVs v 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.medElig=1	AND (v.nephropathieVih=1);

INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,162225,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.protocoleTestTraitement=1 THEN 163329 END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.medicalEligARVs v 	
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.medElig=1	AND (v.protocoleTestTraitement=1);					
	/*END OF ÉLIGIBILITÉ MÉDICALE AUX ARV MENU*/
	/*MIGRATION FOR Date de prochaine visite */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,5096,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN c.nxtVisitDd<1 AND c.nxtVisitMm<1 AND c.nxtVisitYy>0 THEN CONCAT(c.nxtVisitYy,'-',01,'-',01)
	 WHEN c.nxtVisitDd<1 AND c.nxtVisitMm>0 AND c.nxtVisitYy>0 THEN CONCAT(c.nxtVisitYy,'-',c.nxtVisitMm,'-',01)
	 WHEN c.nxtVisitDd>0 AND c.nxtVisitMm>0 AND c.nxtVisitYy>0 THEN CONCAT(c.nxtVisitYy,'-',c.nxtVisitMm,'-',c.nxtVisitDd)
	 ELSE NULL
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e
WHERE e.uuid = c.encGuid  and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(c.visitDateYy,'-',c.visitDateMm,'-',c.visitDateDd)
AND c.nxtVisitYy>0;

	/*END OF MIGRATION FOR Date de prochaine visite*/
	/*MIGRATION FOR ÉVALUATION ET PLAN MENU*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159395,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.assessmentPlan<>'' THEN v.assessmentPlan ELSE NULL END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.assessmentPlan>0;
	/*END OF ÉVALUATION ET PLAN MENU*/	
	
  
  
  
  
  /* migration for suivi visit*/
  
/*MIGRATION FOR ÉTAT GENERAL MENU*/
/* MIGRATION OF Inchangé,uelque peu amélioré,Aggravé,Nette amélioration*/			
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,
case when v.genStat=1 then 162676
	 when v.genStat=4 then 1898
	 when v.genStat=8 then 162676
	 when v.genStat=16 then 162676
else null
END,e.encounter_id,e.encounter_datetime,e.location_id,
case when v.genStat=1 then 162679
	 when v.genStat=4 then 1065
	 when v.genStat=8 then 162678
	 when v.genStat=16 then 162677
else null
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.genStat in (1,4,8,16);	
/*Hospitalisé depuis la dernière visite*/	
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,976,e.encounter_id,e.encounter_datetime,e.location_id,
case when v.hospitalized=1 then 1065
	 when v.hospitalized=2 then 1066
else null
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.hospitalized in (1,2);
/* Si oui, expliquer */			
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,162879,e.encounter_id,e.encounter_datetime,e.location_id,
case when v.hospitalizedText<>'' then v.hospitalizedText else null END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')= concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.hospitalizedText<>'';


/* END of MIGRATION FOR ÉTAT GENERAL MENU*/		
  
  

  
  
  
END;
