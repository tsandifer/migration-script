drop procedure if exists obgynMigration;
DELIMITER $$ 
CREATE PROCEDURE obgynMigration()
BEGIN
  DECLARE done INT DEFAULT FALSE;
 -- DECLARE a CHAR(16);
  DECLARE vstatus boolean;
  DECLARE vvisit_type_id INT;
  DECLARE obs_datetime_,vobs_datetime,vdate_created,vencounter_datetime datetime;
  DECLARE vobs_id,vperson_id,vconcept_id,vencounter_id,vlocation_id INT;

   create table if not exists itech.precisez (obs_id int,person_id int,concept_id int,encounter_id int,location_id int, obs_group_id int, value_coded int);

 SET SQL_SAFE_UPDATES = 0;

/* Groupe sanguin */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,300,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN o.concept_id=7861 AND o.value_coded=1 THEN 690
     WHEN o.concept_id=7861 AND o.value_coded=2 THEN 692
	 WHEN o.concept_id=7861 AND o.value_coded=4 THEN 694
	 WHEN o.concept_id=7861 AND o.value_coded=8 THEN 696
	 WHEN o.concept_id=7861 AND o.value_coded=16 THEN 699
	 WHEN o.concept_id=7861 AND o.value_coded=32 THEN 701
	 WHEN o.concept_id=7861 AND o.value_coded=64 THEN 1230
	 WHEN o.concept_id=7861 AND o.value_coded=128 THEN 1231
	 WHEN o.concept_id=7861 AND o.value_coded=256 THEN 1107
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=7861 and o.value_coded>0;		

select 1 as objn;

/* Patiente vue pour Consultation */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160288,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN o.concept_id=7860 AND o.value_boolean=1 THEN 160456
     WHEN o.concept_id=70018 AND o.value_boolean=1 THEN 1622
	 WHEN o.concept_id=71240 AND o.value_boolean=1 THEN 1623
	 WHEN o.concept_id=71368 AND o.value_boolean=1 THEN 5483
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (7860,70018,71240,71368) and o.value_boolean=1;	

select 2 as objn;
/* Source de référence  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159936,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.referHosp=1 THEN 5485
     WHEN v.referOutpatStd=1 THEN 160542
	 WHEN v.referVctCenter=1 THEN 159940
	 WHEN v.referCommunityBasedProg=1 THEN 159938
	 ELSE NULL
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
(v.referHosp=1 or v.referVctCenter=1 or v.referOutpatStd=1 or v.referCommunityBasedProg=1);
select 3 as objn;
/*Niveau d’étude*/
/* primaire, secondaire, universitaire */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1712,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN o.concept_id=71241 AND o.value_boolean=1 THEN 1713
     WHEN o.concept_id=71242 AND o.value_boolean=1 THEN 1714
	 WHEN o.concept_id=71243 AND o.value_boolean=1 THEN 159785
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (71241,71242,71243) and o.value_boolean=1;
select 4 as objn;
/* Alphabétisée,Non Alphabétisée */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159400,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN o.concept_id=71244 AND o.value_boolean=1 THEN 1065
     WHEN o.concept_id=71245 AND o.value_boolean=1 THEN 1066
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (71244,71245) and o.value_boolean=1;
select 5 as objn;
/* ANTECEDENTS HEREDO-COLLATERAUX*/
/*Aucune, Inconnu*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163607,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN o.concept_id=71096 AND o.value_numeric=1 THEN 163729
     WHEN o.concept_id=71096 AND o.value_numeric=2 THEN 163728
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71096 and o.value_numeric in (1,2);
select 6 as objn;
/* Asthme */
  /* migration group*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160593,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70800,70801,70803) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=160593 
GROUP BY openmrs.obs.person_id,encounter_id;
 select 7 as objn;
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160592,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
140234,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70800,70801,70803) and o.value_boolean=1;
select 8 as objn;
 /*Pere / Mere  /  Frere ou soeur */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1560,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when o.concept_id=70800 and o.value_boolean=1 then 970
     when o.concept_id=70801 and o.value_boolean=1 then 971
	 when o.concept_id=70803 and o.value_boolean=1 then 972
	 else null
end ,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70800,70801,70803) and o.value_boolean=1;
select 9 as objn;
/* end of ASTHME*/

/* CANCER */
  /* migration group*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160593,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70802,70804,70805) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=160593 
GROUP BY openmrs.obs.person_id,encounter_id;
 select 10 as objn;
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160592,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,151521,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70802,70804,70805)  and o.value_boolean=1;
select 11 as objn;
 /*Pere / Mere  /  Frere ou soeur */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1560,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when o.concept_id=70802 and o.value_boolean=1 then 970
     when o.concept_id=70804 and o.value_boolean=1 then 971
	 when o.concept_id=70805 and o.value_boolean=1 then 972
	 else null
end ,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70802,70804,70805)  and o.value_boolean=1;
select 12 as objn;
/* end of CANCER*/

/* Cardiopathie */
  /* migration group*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160593,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70807,70808,70809) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=160593 
GROUP BY openmrs.obs.person_id,encounter_id;
 select 13 as objn;
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160592,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,163114,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70807,70808,70809) and o.value_boolean=1;
select 14 as objn;
 /*Pere / Mere  /  Frere ou soeur */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1560,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when o.concept_id=70807 and o.value_boolean=1 then 970
     when o.concept_id=70808 and o.value_boolean=1 then 971
	 when o.concept_id=70809 and o.value_boolean=1 then 972
	 else null
end ,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70807,70808,70809) and o.value_boolean=1;
select 15 as objn;
/* end of Cardiopathie*/

/* Diabete */
  /* migration group */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160593,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70810,70811,70812) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=160593 
GROUP BY openmrs.obs.person_id,encounter_id;
 select 16 as objn;
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160592,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,140228,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70810,70811,70812) and o.value_boolean=1;
select 17 as objn;
 /*Pere / Mere  /  Frere ou soeur */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1560,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when o.concept_id=70810 and o.value_boolean=1 then 970
     when o.concept_id=70811 and o.value_boolean=1 then 971
	 when o.concept_id=70812 and o.value_boolean=1 then 972
	 else null
end ,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70810,70811,70812) and o.value_boolean=1;
select 18 as objn;
/* end of Diabete*/

/* Epilepsie */
  /* migration group */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160593,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70813,70814,70815) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=160593 
GROUP BY openmrs.obs.person_id,encounter_id;
 select 19 as objn;
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160592,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,152450,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70813,70814,70815) and o.value_boolean=1;
select 20 as objn;
 /*Pere / Mere  /  Frere ou soeur */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1560,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when o.concept_id=70813 and o.value_boolean=1 then 970
     when o.concept_id=70814 and o.value_boolean=1 then 971
	 when o.concept_id=70815 and o.value_boolean=1 then 972
	 else null
end ,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70813,70814,70815) and o.value_boolean=1;
select 21 as objn;
/* end of Epilepsie*/

/* HTA */
  /* migration group */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160593,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70816,70817,70818) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=160593 
GROUP BY openmrs.obs.person_id,encounter_id;
select 22 as objn; 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160592,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,151927,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70816,70817,70818) and o.value_boolean=1;
select 23 as objn;
 /*Pere / Mere  /  Frere ou soeur */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1560,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when o.concept_id=70816 and o.value_boolean=1 then 970
     when o.concept_id=70817 and o.value_boolean=1 then 971
	 when o.concept_id=70818 and o.value_boolean=1 then 972
	 else null
end ,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70816,70817,70818) and o.value_boolean=1;
select 24 as objn;
/* end of HTA*/

/* Tuberculose */
  /* migration group */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160593,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70819,70820,70821) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=160593 
GROUP BY openmrs.obs.person_id,encounter_id;
 select 25 as objn;
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160592,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,152460,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70819,70820,70821) and o.value_boolean=1;
select 26 as objn;
 /*Pere / Mere  /  Frere ou soeur */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1560,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when o.concept_id=70819 and o.value_boolean=1 then 970
     when o.concept_id=70820 and o.value_boolean=1 then 971
	 when o.concept_id=70821 and o.value_boolean=1 then 972
	 else null
end ,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70819,70820,70821) and o.value_boolean=1;
select 27 as objn;
/* end of Tuberculose*/

/* Tuberculose  MDR*/
  /* migration group */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160593,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (71237,71238,71239) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=160593 
GROUP BY openmrs.obs.person_id,encounter_id;
select 28 as objn; 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160592,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,164102,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71237,71238,71239) and o.value_boolean=1;
select 29 as objn;
 /*Pere / Mere  /  Frere ou soeur */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1560,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when o.concept_id=71237 and o.value_boolean=1 then 970
     when o.concept_id=71238 and o.value_boolean=1 then 971
	 when o.concept_id=71239 and o.value_boolean=1 then 972
	 else null
end ,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71237,71238,71239) and o.value_boolean=1;

select 30 as objn;

/* end of Tuberculose MDR*/
/*  END ANTECEDENTS HEREDO-COLLATERAUX*/



/* ANTECEDENTS PERSONNELS/HABITUDES */

/*Aucune, Inconnu*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163730,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN o.concept_id=71097 AND o.value_numeric=1 THEN 163729
     WHEN o.concept_id=71097 AND o.value_numeric=2 THEN 163728
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71097 and o.value_numeric in (1,2);
select 31 as objn;
/* Accident cérébro-vasculaire */
  /* migration group */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1633,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70001 and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1633 
GROUP BY openmrs.obs.person_id,encounter_id;
 select 32 as objn;
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1628,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,152512,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=70001 and o.value_boolean=1;
/* end of Accident cérébro-vasculaire */
select 33 as objn;
/* Allergies */
  /* migration group */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1633,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70002 and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1633 
GROUP BY openmrs.obs.person_id,encounter_id;
select 34 as objn; 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1628,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,110247,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=70002 and o.value_boolean=1;
select 35 as objn;
/* Precisez*/
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160221,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,o.value_text,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71002 and o.value_text<>'';
/* end of Allergies */
select 36 as objn;
/* Asthme */
  /* migration group */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1633,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70005 and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1633 
GROUP BY openmrs.obs.person_id,encounter_id;
 select 37 as objn;
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1628,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,139212,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=70005 and o.value_boolean=1;
/* end of Asthme */
select 38 as objn;
/* Cancer */
  /* migration group */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1633,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70006 and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1633 
GROUP BY openmrs.obs.person_id,encounter_id;
 select 39 as objn;
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1628,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,151286,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=70006 and o.value_boolean=1;
select 40 as objn;
/* Precisez*/
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160221,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,o.value_text,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71003 and o.value_text<>'';
select 41 as objn;
/* end of Cancer */

/* IST */
  /* migration group */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1633,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70012 and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1633 
GROUP BY openmrs.obs.person_id,encounter_id;
 select 42 as objn;
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1628,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,156660,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=70012 and o.value_boolean=1;
select 43 as objn;
/* Precisez*/
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160221,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,o.value_text,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71016 and o.value_text<>'';
select 44 as objn;
/* end of IST */

/* Cardiopathie */
  /* migration group */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1633,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70007 and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1633 
GROUP BY openmrs.obs.person_id,encounter_id;
select 45 as objn; 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1628,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,122432,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=70007 and o.value_boolean=1;
/* end of Cardiopathie */
select 46 as objn;
/* Chirurgie */
  /* migration group */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1633,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70736 and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1633 
GROUP BY openmrs.obs.person_id,encounter_id;
select 47 as objn; 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1628,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,163521,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=70736 and o.value_boolean=1;
select 48 as objn;
/* Precisez*/
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160221,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,o.value_text,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=70737 and o.value_text<>'';
select 49 as objn;
/* end of Chirurgie */

/* Epilepsie */
  /* migration group */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1633,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70009 and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1633 
GROUP BY openmrs.obs.person_id,encounter_id;
 select 50 as objn;
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1628,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,1625,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=70009 and o.value_boolean=1;
/* end of Epilepsie */
 select 51 as objn;
/* Hémoglobinopathie */
  /* migration group */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1633,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70452 and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1633 
GROUP BY openmrs.obs.person_id,encounter_id;
  select 52 as objn;
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1628,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,163583,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=70452 and o.value_boolean=1;
 select 53 as objn;
/* Precisez*/
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160221,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,o.value_text,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=70739 and o.value_text<>'';
 select 54 as objn;
/* end of Hémoglobinopathie */

/* HTA */
  /* migration group */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1633,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70011 and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1633 
GROUP BY openmrs.obs.person_id,encounter_id;
  select 55 as objn;
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1628,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,156639,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=70011 and o.value_boolean=1;
 select 56 as objn;
/* end of HTA */

/* Hyperchoestérolémie */
  /* migration group */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1633,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (71438,71007)  and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1633 
GROUP BY openmrs.obs.person_id,encounter_id;
  select 57 as objn;
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1628,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,156633,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71438,71007) and o.value_boolean=1;
 select 58 as objn;
/* end of Hyperchoestérolémie */

/* Alcool */
  /* migration group */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1633,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70015 and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1633 
GROUP BY openmrs.obs.person_id,encounter_id;
  select 59 as objn;
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1628,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159449,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=70015 and o.value_boolean=1;
/* end of Alcool */
 select 60 as objn;
/* Drogue */
  /* migration group */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1633,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71010 and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1633 
GROUP BY openmrs.obs.person_id,encounter_id;
  select 61 as objn;
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1628,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,162556,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71010 and o.value_boolean=1;
 select 62 as objn;
/* Precisez*/
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160221,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,o.value_text,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71011 and o.value_text<>'';

/* end of Drogue */
 select 63 as objn;

/* Tabac */
  /* migration group */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1633,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70016 and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1633 
GROUP BY openmrs.obs.person_id,encounter_id;
  select 64 as objn;
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1628,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,163731,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=70016 and o.value_boolean=1;
/* end of Tabac */
 select 65 as objn;
/* Diabète */
  /* migration group */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1633,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70008 and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1633 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1628,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,156630,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=70008 and o.value_boolean=1;
/* end of Diabète */
 select 66 as objn;

/* Malnutrition */
  /* migration group */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1633,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70270 and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1633 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1628,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,163584,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=70270 and o.value_boolean=1;
/* end of Malnutrition */
 select 67 as objn;

/* Tuberculose */
  /* migration group */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1633,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70014 and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1633 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1628,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,151632,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=70014 and o.value_boolean=1;
/* end of Tuberculose */

 select 67 as objn;
/* MDR - Tuberculose */
  /* migration group */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1633,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71229 and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1633 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1628,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,163586,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71229 and o.value_boolean=1;
/* end of MDR - Tuberculose */
 select 69 as objn;

/* Troubles psychiatriques*/
  /* migration group */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1633,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71008 and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1633 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1628,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,151282,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71008 and o.value_boolean=1;

/* Precisez*/
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160221,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,o.value_text,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71009 and o.value_text<>'';

/* end of Troubles psychiatriques */
 select 70 as objn;

/* Troubles psychiatriques*/
  /* migration group */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1633,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71008 and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1633 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1628,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,151282,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71008 and o.value_boolean=1;

/* Precisez*/
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160221,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,o.value_text,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71009 and o.value_text<>'';

/* end of Troubles psychiatriques */
 select 71 as objn;
/*Statut VIH */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1169,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 1067
     when o.value_numeric=2 then 664
	 when o.value_numeric=4 then 703
	 else null
end ,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71205 and o.value_numeric in (1,2,4);

/*Date*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160554,e.encounter_id,e.encounter_datetime,e.location_id,date(o.value_datetime) ,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71206 and o.value_datetime is not null;

/* Si positif, enrôlée en soins */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159811,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 1065
     when o.value_numeric=2 then 1065
	 else null
end ,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71212 and o.value_numeric in (1,2);

 select 72 as objn;
/* CD4  */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159375,e.encounter_id,e.encounter_datetime,e.location_id,
FindNumericValue(o.value_numeric),1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71208 and o.value_numeric>0;
/*Date  CD4 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159376,e.encounter_id,e.encounter_datetime,e.location_id,
date(o.value_datetime),1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=71226 and o.value_datetime is not null;

/* ARV */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160117,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 160119
	 else null
end ,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=71209 and o.value_numeric=1;

/* médicaments */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163322,e.encounter_id,e.encounter_datetime,e.location_id,o.value_text,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=71210 and o.value_text<>'';

/*Date de début*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1190,e.encounter_id,e.encounter_datetime,e.location_id,date(o.value_datetime) ,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=71211 and o.value_datetime is not null;


/* Prophylaxie  Cotrimoxazole*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1109,e.encounter_id,e.encounter_datetime,e.location_id,105281,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=71406 and o.value_boolean=1;

/* Prophylaxie  Azythromycine*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1110,e.encounter_id,e.encounter_datetime,e.location_id,71780,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=71407 and o.value_boolean=1;

/* Prophylaxie  Fluconazole*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1109,e.encounter_id,e.encounter_datetime,e.location_id,76488,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=71408 and o.value_boolean=1;

/* Prophylaxie  INH*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1110,e.encounter_id,e.encounter_datetime,e.location_id,1679,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=7941 and o.value_boolean=1;

/*Médicaments actuels */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159367,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_text<>'' then 1065
     else null
end ,o.value_text,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=69999 and o.value_text<>'';

/*Remarque*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,161011,e.encounter_id,e.encounter_datetime,e.location_id,o.value_text,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=70745 and o.value_text<>'';

select 2 as PERSONNELS;

/* end of ANTECEDENTS PERSONNELS/HABITUDES */

/* ANTECEDENTS OBSTETRICO/GYNECOLOGIQUE*/
/*Age des Ménarches */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160598,e.encounter_id,e.encounter_datetime,e.location_id,digits(o.value_numeric),1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=8067 and digits(o.value_numeric)>0;

/*Age des premières relations sexuelles*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163587,e.encounter_id,e.encounter_datetime,e.location_id,o.value_numeric,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=8068 and digits(o.value_numeric)>0;

/*Nombre cumulé de partenaires sexuels*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,5570,e.encounter_id,e.encounter_datetime,e.location_id,FindNumericValue(o.value_text),1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=70464 and FindNumericValue(o.value_text)>0;

/*Durée des Règles*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163732,e.encounter_id,e.encounter_datetime,e.location_id,FindNumericValue(o.value_text),1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=7866 and FindNumericValue(o.value_text)>0;

/*Durée des Cycles*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160597,e.encounter_id,e.encounter_datetime,e.location_id,FindNumericValue(o.value_text),1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=7867 and FindNumericValue(o.value_text)>0;

/*DDR */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1427,e.encounter_id,e.encounter_datetime,e.location_id,o.value_datetime,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=70465 and o.value_datetime is not null;
/*DPA*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,5596,e.encounter_id,e.encounter_datetime,e.location_id,o.value_datetime,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=70466 and o.value_datetime is not null;

/*Dysménorrhée */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1628,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 158306 else null end ,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=7868 and o.value_numeric=1;

/*Dysménorrhée Si oui */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1628,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 129135 
     when o.value_numeric=2 then 152336 
	 else null 
end ,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=7869 and o.value_numeric in (1,2);

/*Infertilité */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1628,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 158308 
	 else null 
end ,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=71352 and o.value_numeric=1;

/*Gravida para aborda  */ /* allready done in vih*/

 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1825,e.encounter_id,e.encounter_datetime,e.location_id,FindNumericValue(o.value_text) ,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=7870 and FindNumericValue(o.value_text)>0;

select 3.1 as gravita;

/*Grossesse multiple,Pré éclampsie sévère,Hémorragie de la grossesse/post-partum*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1628,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 115491
     when o.value_numeric=2 then 113006
	 when o.value_numeric=4 then 117612
	 else null 
end ,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=70032 and o.value_numeric in (1,2,4);


/* Grossesse 1 */
     /*Date  */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160602,e.encounter_id,e.encounter_datetime,e.location_id,o.value_datetime ,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=71353 and o.value_datetime is not null;
/* Suivi */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1622,e.encounter_id,e.encounter_datetime,e.location_id,o.value_numeric,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=70471 and o.value_numeric in (1,2);




/* Grossesse 2 */
     /*Date  */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160602,e.encounter_id,e.encounter_datetime,e.location_id,o.value_datetime ,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=71358 and o.value_datetime is not null;

/* Suivi */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1622,e.encounter_id,e.encounter_datetime,e.location_id,o.value_numeric ,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=70474 and o.value_numeric in (1,2);

/* Grossesse 3 */
     /*Date  */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160602,e.encounter_id,e.encounter_datetime,e.location_id,o.value_datetime ,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=71363 and o.value_datetime is not null;

/* Suivi */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1622,e.encounter_id,e.encounter_datetime,e.location_id,o.value_numeric ,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=70477 and o.value_numeric in (1,2);

select 3.2 Cesarienne;

/*ATCD de Césarienne indication 1*/
  /* migration group */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160714,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70480 and o.value_numeric=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=160714 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1651,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when o.value_numeric=1 then 1171 else null end ,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=70480 and o.value_numeric=1;

 /* Si oui, Indication1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160716,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,o.value_text,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=70481 and o.value_text<>'';
/*Date 1*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160715,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,o.value_datetime,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=70482 and o.value_datetime is not null;



/*ATCD de Césarienne indication 2*/
  /* migration group */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160714,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70480 and o.value_numeric=1 and exists (select * from itech.obs o1,itech.encounter c1 where c1.encounter_id=o1.encounter_id and  o1.concept_id='70483');

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=160714 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1651,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when o.value_numeric=1 then 1171 else null end ,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=70480 and o.value_numeric=1;

 /* Si oui, Indication1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160716,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,o.value_text,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=70483 and o.value_text<>'';
/*Date 1*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160715,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,o.value_datetime,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=70484 and o.value_datetime is not null;


/*Date du dernier dépistage du cancer du Col*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163267,e.encounter_id,e.encounter_datetime,e.location_id,o.value_datetime,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=70485 and o.value_datetime is not null;

/*Méthode utilisée*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163589,e.encounter_id,e.encounter_datetime,e.location_id,o.value_text,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=70486 and o.value_text<>'';

/*Résultat*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,885,e.encounter_id,e.encounter_datetime,e.location_id,
 case when o.value_numeric=1 then 1115
      when o.value_numeric=2 then 1116
      when o.value_numeric=4 then 1118
	  else null
 end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=70029 and o.value_numeric in (1,2,4);

/*Palpation mensuelle des Seins */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163590,e.encounter_id,e.encounter_datetime,e.location_id, 
case when o.value_numeric=1 then 1065
     when o.value_numeric=2 then 1066
	 else null 
end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=70487 and o.value_numeric in (1,2);

/*Mammographie (âge > 35ans)*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163591,e.encounter_id,e.encounter_datetime,e.location_id, 
case when o.value_numeric=1 then 1267
     when o.value_numeric=2 then 1118
	 else null 
end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=7873 and o.value_numeric in (1,2);

/*Resultat si oui*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163591,e.encounter_id,e.encounter_datetime,e.location_id, 
case when o.value_numeric=1 then 1267
     when o.value_numeric=2 then 1118
	 else null 
end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=70163 and o.value_numeric in (1,2);

/*Planification familiale */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,5271,e.encounter_id,e.encounter_datetime,e.location_id,v.famPlan,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.vitals v
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.famPlan in (1,2);

 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,374,e.encounter_id,e.encounter_datetime,e.location_id, o.value_text,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=70164 and o.value_text<>'';


/* menaupose */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1628,e.encounter_id,e.encounter_datetime,e.location_id, 
case when o.value_numeric=1 then 134346
	 else null 
end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=7871 and o.value_numeric=1;

/* Si menaupose oui */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160599,e.encounter_id,e.encounter_datetime,e.location_id, FindNumericValue(o.value_text),1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=7872 and FindNumericValue(o.value_text)>0;

select 3 as GYNECOLOGIQUE;
/* End of ANTECEDENTS OBSTETRICO/GYNECOLOGIQUE */

/* VACCINS */
/*Hépatite B*/
  /* migration group */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1441,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70693,70694,70695,71077,71078);

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1441 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the imunisation */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,984,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,782,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70693,70694,70695,71077,71078);

/* Date recu 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1410,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,o.value_datetime,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=70693 and o.value_datetime is not null;

/* Date recu 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1410,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,o.value_datetime,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=70694 and o.value_datetime is not null;

/* Date recu 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1410,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,o.value_datetime,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=70695 and o.value_datetime is not null;

/*date inconu*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163100,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,1065,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71077 and o.value_boolean>0;

/*Jamais recu */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163100,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,1066,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71078 and o.value_boolean>0;
/* End Hepatite B */



/* Tétanos Texoïde */
  /* migration group */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1441,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (71079,71080,71081,71082,71083);

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1441 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the imunisation */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,984,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,84879,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71079,71080,71081,71082,71083);

/* Date recu 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1410,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,o.value_datetime,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71079 and o.value_datetime is not null;

/* Date recu 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1410,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,o.value_datetime,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71080 and o.value_datetime is not null;

/* Date recu 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1410,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,o.value_datetime,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71081 and o.value_datetime is not null;

/*date inconu*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163100,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,1065,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71082 and o.value_boolean>0;

/*Jamais recu */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163100,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,1066,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71083 and o.value_boolean>0;
/* End of Tétanos Texoïde */




/* Pneumocoque */
  /* migration group */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1441,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (71616,71617,71618,71632,71633);

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1441 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the imunisation */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,984,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,82215,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71616,71617,71618,71632,71633);

/* Date recu 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1410,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,o.value_datetime,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71616 and o.value_datetime is not null;

/* Date recu 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1410,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,o.value_datetime,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71617 and o.value_datetime is not null;

/* Date recu 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1410,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,o.value_datetime,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71618 and o.value_datetime is not null;

/*date inconu*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163100,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,1065,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71632 and o.value_boolean>0;

/*Jamais recu */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163100,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,1066,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71633 and o.value_boolean>0;
/* End of Pneumocoque */






/* Autre Vaccin */
  /* migration group */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1441,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (71094,71089,71090,71091,71092,71093);

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1441 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the imunisation */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,comments,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,984,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,5622,o.value_text,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71094);

/* Date recu 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1410,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,o.value_datetime,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71089 and o.value_datetime is not null;

/* Date recu 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1410,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,o.value_datetime,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71090 and o.value_datetime is not null;

/* Date recu 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1410,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,o.value_datetime,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71091 and o.value_datetime is not null;

/*date inconu*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163100,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,1065,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71092 and o.value_boolean>0;

/*Jamais recu */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163100,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,1066,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71093 and o.value_boolean>0;
/* End of Ather Imunization */

select 4 as VACCINS;

/* END OF VACCINS */


/*MOTIFS DE CONSULTATION*/

/* Agressions sexuelles <72H */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163737,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=71131 and o.value_boolean>0 then 163733
	 else null
end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71131 and o.value_boolean>0;

/* Agressions sexuelles 72H - 120H*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163737,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=71132 and o.value_boolean>0 then 163734
	 else null
end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71132 and o.value_boolean>0;

/* Agressions sexuelles 120H - 2sem */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163737,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=71133 and o.value_boolean>0 then 163735
	 else null
end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71133 and o.value_boolean>0;

/* Agressions sexuelles 2 sem et plus */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163737,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=71134 and o.value_boolean>0 then 163736
	 else null
end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71134 and o.value_boolean>0;

/* Aménorrhée, précisez */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159614,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=70587 and o.value_boolean>0 then 148989 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
((o.concept_id=70587 and o.value_boolean>0));

TRUNCATE TABLE itech.precisez;
 INSERT INTO itech.precisez(obs_id,person_id,concept_id,encounter_id,location_id, value_coded)
 SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,
 openmrs.obs.concept_id,openmrs.obs.encounter_id, openmrs.obs.location_id, openmrs.obs.value_coded
 FROM openmrs.obs
 WHERE openmrs.obs.concept_id=159614
    AND openmrs.obs.value_coded=148989 
 GROUP BY openmrs.obs.person_id,encounter_id;
 
 UPDATE openmrs.obs ob, itech.obs ito, encounter c, itech.encounter e, itech.precisez ip
     SET ob.comments=ito.value_text
 WHERE c.uuid = e.encGuid
 AND e.siteCode = ito.location_id 
 AND e.encounter_id = ito.encounter_id
 AND ito.concept_id=70622
 AND (ito.value_text <> '' AND ito.value_text is not null)
 AND ip.person_id=ob.person_id
 AND ip.concept_id=ob.concept_id
 AND ip.encounter_id=ob.encounter_id
 AND ip.location_id=ob.location_id
 AND ip.value_coded=ob.value_coded
 AND ip.concept_id=159614
 AND ip.value_coded=148989;

 
 /* Fracture osseuse */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159614,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=70180 and o.value_boolean>0 then 177 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
((o.concept_id=70180 and o.value_boolean>0));

/* Fièvre < 2 semaines" */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159614,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=70172 and o.value_boolean>0 then 163740 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70172 and o.value_boolean>0;

/*Planification Familiale*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159614,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=70623 and o.value_boolean>0 then 965 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and  
o.concept_id=70623 and o.value_boolean>0;

/*Asthénie*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159614,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=70828 and o.value_boolean>0 then 135367 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70828 and o.value_boolean>0;

/*Fièvre ≥ 2 semaines*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159614,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=70173 and o.value_boolean>0 then 162260 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70173 and o.value_boolean>0;

/*Pollakiurie */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159614,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=70193 and o.value_boolean>0 then 137593 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70193 and o.value_boolean>0;

/* Céphalée */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159614,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=70601 and o.value_boolean>0 then 139084 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70601 and o.value_boolean>0;

/* Frissons */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159614,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=71339 and o.value_boolean>0 then 871 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71339 and o.value_boolean>0;

/* Poly ménorrhée */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159614,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=70634 and o.value_boolean>0 then 162 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70634 and o.value_boolean>0;


/* Changement dans la fréquence et/ou intensité des mouvements foetaux */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159614,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=70624 and o.value_boolean>0 then 113377 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70624 and o.value_boolean>0;

/* Hémoptysie */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159614,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=70610 and o.value_boolean>0 then 138905 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=70610 and o.value_boolean>0;

/* Prurit Vulvaire */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159614,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=70194 and o.value_boolean>0 then 128310 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70194 and o.value_boolean>0;



/* Convulsions */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159614,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=70602 and o.value_boolean>0 then 206 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70602 and o.value_boolean>0;
/* Hypoménorrhée */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159614,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=70629 and o.value_boolean>0 then 138043 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70629 and o.value_boolean>0;
/* PTME */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159614,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=70591 and o.value_boolean>0 then 159937 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70591 and o.value_boolean>0;


/* Courbatures */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159614,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=71146 and o.value_boolean>0 then 150167 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71146 and o.value_boolean>0;
/* Hyperménorrhée */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159614,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=70629 and o.value_boolean>0 then 134345 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70629 and o.value_boolean>0;
/* Saignement Vaginal */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159614,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=70635 and o.value_boolean>0 then 147232 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70635 and o.value_boolean>0;


/* Diarrhée */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159614,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=70625 and o.value_boolean>0 then 142412 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70625 and o.value_boolean>0;
/* Inappétence */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159614,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=70214 and o.value_boolean>0 then 6031 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70214 and o.value_boolean>0;
/* Sueurs profuses face/doigts*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159614,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=70592 and o.value_boolean>0 then 140941 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70592 and o.value_boolean>0;

/* Douleurs Abdominales */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159614,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=70603 and o.value_boolean>0 then 151 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70603 and o.value_boolean>0;
/* Leucorrhée */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159614,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=70630 and o.value_boolean>0 then 123396 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70630 and o.value_boolean>0;
/* Toux < 2 semaines*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159614,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=70206 and o.value_boolean>0 then 163739 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70206 and o.value_boolean>0;


/* Douleurs Épigastriques en barre */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159614,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=70603 and o.value_boolean>0 then 141128 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70603 and o.value_boolean>0;
/* Masse Hypogastrique */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159614,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=70630 and o.value_boolean>0 then 130641 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=70630 and o.value_boolean>0;
/* Toux ≥ 2 semaines */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159614,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=70206 and o.value_boolean>0 then 159799 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70206 and o.value_boolean>0;


/* Douleurs Hypogastriques */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159614,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id in (70589,71126) and o.value_boolean>0 then 131034 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70589,71126) and o.value_boolean>0;
/*Ménorragie */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159614,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=70636 and o.value_boolean>0 then 134345 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=70636 and o.value_boolean>0;
/* Troubles Visuels */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159614,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=70593 and o.value_boolean>0 then 118938 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70593 and o.value_boolean>0;



/* Douleurs précordiales */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159614,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=70204 and o.value_boolean>0 then 159361 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70204 and o.value_boolean>0;

/* Métrorragie */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159614,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=70631 and o.value_boolean>0 then 163738 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=70631 and o.value_boolean>0;
/* Vomissement */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159614,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=7025 and o.value_boolean>0 then 122983 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=7025 and o.value_boolean>0;



/* Douleurs thoraciques */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159614,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=71435 and o.value_boolean>0 then 120749 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71435 and o.value_boolean>0;
/* Œdème */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159614,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=70168 and o.value_boolean>0 then 460 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=70168 and o.value_boolean>0;


/* Dyspnée */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159614,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=7007 and o.value_boolean>0 then 120749 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=7007 and o.value_boolean>0;
/* Oligo ménorrhée */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159614,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=70632 and o.value_boolean>0 then 114997 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=70632 and o.value_boolean>0;

/* Dysurie */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159614,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=70600 and o.value_boolean>0 then 118771 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70600 and o.value_boolean>0;
/* Passage de liquide par le vagin */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159614,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=70633 and o.value_boolean>0 then 148968 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=70633 and o.value_boolean>0;


/* Ecoulement nasal */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159614,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=71147 and o.value_boolean>0 then 113224 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71147 and o.value_boolean>0;
/* Perte de poids */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159614,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=70174 and o.value_boolean>0 then 832 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=70174 and o.value_boolean>0;

/*EDN OF MOTIFS DE CONSULTATION*/

/* EXAMEN PHYSIQUE */
/* Général */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1119,e.encounter_id,e.encounter_datetime,e.location_id,
case when  v.physicalGeneral=1 then 159438
     when  v.physicalGeneral=2 then 163293
     when  v.physicalGeneral=3 then 1118
	 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.vitals v
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.physicalGeneral in (1,2,3);

/* Tete */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1122,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 1115 
     when o.value_numeric=2 then 1116
	 when o.value_numeric=3 then 1118 
	 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=7086 and o.value_numeric in (1,2,3);


/* Nez */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163336,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 1115 
     when o.value_numeric=2 then 1116
	 when o.value_numeric=3 then 1118 
	 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70223 and o.value_numeric in (1,2,3);

/* Bouche */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163308,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 1115 
     when o.value_numeric=2 then 1116
	 when o.value_numeric=3 then 1118 
	 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70224 and o.value_numeric in (1,2,3);

/* Anus */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163582,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 1115 
     when o.value_numeric=2 then 1116
	 when o.value_numeric=3 then 1118 
	 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71417 and o.value_numeric in (1,2,3);


/* Oreilles */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163337,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 1115 
     when o.value_numeric=2 then 1116
	 when o.value_numeric=3 then 1118 
	 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70225 and o.value_numeric in (1,2,3);

/* Cou + Thyroïde */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163388,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 1115 
     when o.value_numeric=2 then 1116
	 when o.value_numeric=3 then 1118 
	 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (7087,7093) and o.value_numeric in (1,2,3); 

/* Poumons */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1119,e.encounter_id,e.encounter_datetime,e.location_id,
case when  v.physicalLungs=1 then 1115
     when  v.physicalLungs=2 then 1116
     when  v.physicalLungs=3 then 1118
	 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.vitals v
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.physicalLungs in (1,2,3);

	
/* Coeur */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1124,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 1115 
     when o.value_numeric=2 then 1116
	 when o.value_numeric=3 then 1118 
	 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=7088 and o.value_numeric in (1,2,3);

/* Seins */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159780,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 1115 
     when o.value_numeric=2 then 1116
	 when o.value_numeric=3 then 1118 
	 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=7089 and o.value_numeric in (1,2,3);


/* Abdomen */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1125,e.encounter_id,e.encounter_datetime,e.location_id,
case when  v.physicalAbdomen=1 then 1115
     when  v.physicalAbdomen=2 then 1116
     when  v.physicalAbdomen=3 then 1118
	 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.vitals v
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.physicalAbdomen in (1,2,3);

/* Uterus */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163742,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 1115 
     when o.value_numeric=2 then 1116
	 when o.value_numeric=3 then 1118 
	 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=7904 and o.value_numeric in (1,2,3);


/*Organes génitaux Externes*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163743,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 1115 
     when o.value_numeric=2 then 1116
	 when o.value_numeric=3 then 1118 
	 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id  in (7091,70228) and o.value_numeric in (1,2,3);

/* Examen Neurologique */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1129,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 1115 
     when o.value_numeric=2 then 1116
	 when o.value_numeric=3 then 1118 
	 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70905 and o.value_numeric in (1,2,3);


/* Vagin */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163744,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 1115 
     when o.value_numeric=2 then 1116
	 when o.value_numeric=3 then 1118 
	 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=7092 and o.value_numeric in (1,2,3);

/* Col */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160704,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 1115 
     when o.value_numeric=2 then 1116
	 when o.value_numeric=3 then 1118 
	 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=7093 and o.value_numeric in (1,2,3);

/* Annexes */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163745,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 1115 
     when o.value_numeric=2 then 1116
	 when o.value_numeric=3 then 1118 
	 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=7094 and o.value_numeric in (1,2,3);

/* Toucher Rectal */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163746,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 1115 
     when o.value_numeric=2 then 1116
	 when o.value_numeric=3 then 1118 
	 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=7095 and o.value_numeric in (1,2,3);


/* Membres */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1127,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 1115 
     when o.value_numeric=2 then 1116
	 when o.value_numeric=3 then 1118 
	 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=7096 and o.value_numeric in (1,2,3);

/* Reflexes Ostéo-Tendineux */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160623,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 1115 
     when o.value_numeric=2 then 1116
	 when o.value_numeric=3 then 1118 
	 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=7097 and o.value_numeric in (1,2,3);


/* Peau */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1120,e.encounter_id,e.encounter_datetime,e.location_id,
case when  v.physicalSkin=1 then 1115
     when  v.physicalSkin=2 then 1116
     when  v.physicalSkin=3 then 1118
	 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.vitals v
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.physicalSkin in (1,2,3);

/* Lymphadenopathy Cervicale */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,145802,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 163747 
     when o.value_numeric=2 then 163748
	 when o.value_numeric=3 then 1118 
	 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71233 and o.value_numeric in (1,2,3);

/* Lymphadenopathy Supraclaviculaire */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159003,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 163747 
     when o.value_numeric=2 then 163748
	 when o.value_numeric=3 then 1118 
	 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71234 and o.value_numeric in (1,2,3);

/* Lymphadenopathy Axillaire */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,148058,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 163747 
     when o.value_numeric=2 then 163748
	 when o.value_numeric=3 then 1118 
	 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71235 and o.value_numeric in (1,2,3);

/* Lymphadenopathy Inguinale */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163950,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 163747 
     when o.value_numeric=2 then 163748
	 when o.value_numeric=3 then 1118 
	 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71236 and o.value_numeric in (1,2,3);


/*Description des conclusions anormales*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1391,e.encounter_id,e.encounter_datetime,e.location_id,o.value_text,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70906 and o.value_text<>'';


/* Rythme cardiaque fœtal */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1440,e.encounter_id,e.encounter_datetime,e.location_id,FindNumericValue(o.value_text),1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=7806 and FindNumericValue(o.value_text)>0;

/* Hauteur utérine */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1439,e.encounter_id,e.encounter_datetime,e.location_id,FindNumericValue(o.value_text),1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=7804 and FindNumericValue(o.value_text)>0;

/* OEDEM */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,460,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 1065  
     when o.value_numeric=2 then 1066
	 else null end ,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70825 and o.value_numeric in (1,2);


/* Présentation  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160090,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 160001  
     when o.value_numeric=2 then 139814
	 when o.value_numeric=4 then 112259
	 else null end ,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=7805 and o.value_numeric in (1,2,4);


/* Position  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163749,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 5141  
     when o.value_numeric=2 then 5139
	 else null end ,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70826 and o.value_numeric in (1,2);


/* Position  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163750,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 163748  
     when o.value_numeric=2 then 163747
	 else null end ,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70827 and o.value_numeric in (1,2);

select 5 as EXAMEN;

/* end of EXAMEN PHYSIQUE*/


/* IMPRESSIONS CLINIQUES/DIAGNOSTIQUES */	
  /* Agression sexuelle [T74.21XA] */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70360,70361,70362) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,152370,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70360,70361,70362) and o.value_boolean=1;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70360,70361,70362) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70360,70361,70362) and o.value_boolean=1;
/* End of aggresion sexuelle*/



  /* Adénofibrome (ADF) du sein [N60.39] */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70058,70106,70107) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,147635,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70058,70106,70107) and o.value_boolean=1;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70058,70106,70107) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70058,70106,70107) and o.value_boolean=1;
/* End of Adénofibrome (ADF) du sein */


  /* Anémie */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70234,70235,70236) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,121629,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70234,70235,70236) and o.value_boolean=1;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70234,70235,70236) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70234,70235,70236) and o.value_boolean=1;
/* Anémie */
	
	
  /* Avortement */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70057,70104,70105) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
50,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70057,70104,70105) and o.value_boolean=1;
	
TRUNCATE TABLE itech.precisez;
 INSERT INTO itech.precisez(obs_id,person_id,concept_id,encounter_id,location_id, value_coded)
 SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,
 openmrs.obs.concept_id,openmrs.obs.encounter_id, openmrs.obs.location_id, openmrs.obs.value_coded
 FROM openmrs.obs
 WHERE openmrs.obs.concept_id=159614
    AND openmrs.obs.value_coded=50 
 GROUP BY openmrs.obs.person_id,encounter_id;
 
 UPDATE openmrs.obs ob, itech.obs ito, encounter c, itech.encounter e, itech.precisez ip
     SET ob.comments=ito.value_text
 WHERE c.uuid = e.encGuid
 AND e.siteCode = ito.location_id 
 AND e.encounter_id = ito.encounter_id
 AND ito.concept_id=70088
 AND (ito.value_text <> '' AND ito.value_text is not null)
 AND ip.person_id=ob.person_id
 AND ip.concept_id=ob.concept_id
 AND ip.encounter_id=ob.encounter_id
 AND ip.location_id=ob.location_id
 AND ip.value_coded=ob.value_coded
 AND ip.concept_id=159614
 AND ip.value_coded=50;	
	
	
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70057,70104,70105) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70057,70104,70105) and o.value_boolean=1;
/* end of Avortement */	
	
	
	
  /* Cancer de l’endomètre [C54.1] */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70061,70108,70109) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,128983,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70061,70108,70109) and o.value_boolean=1;
	
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70061,70108,70109) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70061,70108,70109) and o.value_boolean=1;
/* end of Cancer de l’endomètre [C54.1] */		

	
  /* Cancer de l’ovaire [C56.9] */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70060,70110,70111) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,133318,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70060,70110,70111) and o.value_boolean=1;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70060,70110,70111) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70060,70110,70111) and o.value_boolean=1;
/* end of Cancer de l’ovaire [C56.9] */	


 /* Cancer de sein [C50.919] */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70059,70112,70113) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
133354,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70059,70112,70113) and o.value_boolean=1;


TRUNCATE TABLE itech.precisez;
 INSERT INTO itech.precisez(obs_id,person_id,concept_id,encounter_id,location_id, value_coded)
 SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,
 openmrs.obs.concept_id,openmrs.obs.encounter_id, openmrs.obs.location_id, openmrs.obs.value_coded
 FROM openmrs.obs
 WHERE openmrs.obs.concept_id=159614
    AND openmrs.obs.value_coded=133354 
 GROUP BY openmrs.obs.person_id,encounter_id;
 
 UPDATE openmrs.obs ob, itech.obs ito, encounter c, itech.encounter e, itech.precisez ip
     SET ob.comments=ito.value_text
 WHERE c.uuid = e.encGuid
 AND e.siteCode = ito.location_id 
 AND e.encounter_id = ito.encounter_id
 AND ito.concept_id=70098
 AND (ito.value_text <> '' AND ito.value_text is not null)
 AND ip.person_id=ob.person_id
 AND ip.concept_id=ob.concept_id
 AND ip.encounter_id=ob.encounter_id
 AND ip.location_id=ob.location_id
 AND ip.value_coded=ob.value_coded
 AND ip.concept_id=159614
 AND ip.value_coded=133354;	

	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70059,70112,70113) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70059,70112,70113) and o.value_boolean=1;
/*end of Cancer de sein [C50.919]*/		

/* Cardiopathie [I51.9] */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70240,70241,70242) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id; -- 163114, 122432, 119270
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
139071,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70240,70241,70242) and o.value_boolean=1;

TRUNCATE TABLE itech.precisez;
 INSERT INTO itech.precisez(obs_id,person_id,concept_id,encounter_id,location_id, value_coded)
 SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,
 openmrs.obs.concept_id,openmrs.obs.encounter_id, openmrs.obs.location_id, openmrs.obs.value_coded
 FROM openmrs.obs
 WHERE openmrs.obs.concept_id=159614
    AND openmrs.obs.value_coded=139071 
 GROUP BY openmrs.obs.person_id,encounter_id;
 
 UPDATE openmrs.obs ob, itech.obs ito, encounter c, itech.encounter e, itech.precisez ip
     SET ob.comments=ito.value_text
 WHERE c.uuid = e.encGuid
 AND e.siteCode = ito.location_id 
 AND e.encounter_id = ito.encounter_id
 AND ito.concept_id=71351
 AND (ito.value_text <> '' AND ito.value_text is not null)
 AND ip.person_id=ob.person_id
 AND ip.concept_id=ob.concept_id
 AND ip.encounter_id=ob.encounter_id
 AND ip.location_id=ob.location_id
 AND ip.value_coded=ob.value_coded
 AND ip.concept_id=159614
 AND ip.value_coded=139071;	
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70240,70241,70242) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70240,70241,70242) and o.value_boolean=1;
/* end of Cardiopathie [I51.9] */


/*Chorioamniotite [O41.129] */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (71253,71254,71255) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
145548,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71253,71254,71255) and o.value_boolean=1;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71253,71254,71255) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71253,71254,71255) and o.value_boolean=1;
/* end of Chorioamniotite [O41.129]*/


/*Diabète + grossesse [O99.810]*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70086,70114,70115) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
1449,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70086,70114,70115) and o.value_boolean=1;

TRUNCATE TABLE itech.precisez;
 INSERT INTO itech.precisez(obs_id,person_id,concept_id,encounter_id,location_id, value_coded)
 SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,
 openmrs.obs.concept_id,openmrs.obs.encounter_id, openmrs.obs.location_id, openmrs.obs.value_coded
 FROM openmrs.obs
 WHERE openmrs.obs.concept_id=159614
    AND openmrs.obs.value_coded=1449 
 GROUP BY openmrs.obs.person_id,encounter_id;
 
 UPDATE openmrs.obs ob, itech.obs ito, encounter c, itech.encounter e, itech.precisez ip
     SET ob.comments=ito.value_text
 WHERE c.uuid = e.encGuid
 AND e.siteCode = ito.location_id 
 AND e.encounter_id = ito.encounter_id
 AND ito.concept_id=70092
 AND (ito.value_text <> '' AND ito.value_text is not null)
 AND ip.person_id=ob.person_id
 AND ip.concept_id=ob.concept_id
 AND ip.encounter_id=ob.encounter_id
 AND ip.location_id=ob.location_id
 AND ip.value_coded=ob.value_coded
 AND ip.concept_id=159614
 AND ip.value_coded=1449;	

	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70086,70114,70115) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70086,70114,70115) and o.value_boolean=1;
/* end of Diabète + grossesse [O99.810]*/


/*Dystrophie ovarienne [N83.8]*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70062,70116,70117) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
115178,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70062,70116,70117) and o.value_boolean=1;


TRUNCATE TABLE itech.precisez;
 INSERT INTO itech.precisez(obs_id,person_id,concept_id,encounter_id,location_id, value_coded)
 SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,
 openmrs.obs.concept_id,openmrs.obs.encounter_id, openmrs.obs.location_id, openmrs.obs.value_coded
 FROM openmrs.obs
 WHERE openmrs.obs.concept_id=159614
    AND openmrs.obs.value_coded=115178 
 GROUP BY openmrs.obs.person_id,encounter_id;
 
 UPDATE openmrs.obs ob, itech.obs ito, encounter c, itech.encounter e, itech.precisez ip
     SET ob.comments=ito.value_text
 WHERE c.uuid = e.encGuid
 AND e.siteCode = ito.location_id 
 AND e.encounter_id = ito.encounter_id
 AND ito.concept_id=70089
 AND (ito.value_text <> '' AND ito.value_text is not null)
 AND ip.person_id=ob.person_id
 AND ip.concept_id=ob.concept_id
 AND ip.encounter_id=ob.encounter_id
 AND ip.location_id=ob.location_id
 AND ip.value_coded=ob.value_coded
 AND ip.concept_id=159614
 AND ip.value_coded=115178;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70062,70116,70117) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70062,70116,70117) and o.value_boolean=1;
/* end of Dystrophie ovarienne [N83.8]*/



/*Eclampsie [O15.9]*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70084,70118,70119) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,112335,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70084,70118,70119) and o.value_boolean=1;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70084,70118,70119) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70084,70118,70119) and o.value_boolean=1;
/*end of Eclampsie [O15.9]*/


/*Endométriose [N80.9]*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70064,70120,70121) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
118629,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70064,70120,70121) and o.value_boolean=1;

TRUNCATE TABLE itech.precisez;
 INSERT INTO itech.precisez(obs_id,person_id,concept_id,encounter_id,location_id, value_coded)
 SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,
 openmrs.obs.concept_id,openmrs.obs.encounter_id, openmrs.obs.location_id, openmrs.obs.value_coded
 FROM openmrs.obs
 WHERE openmrs.obs.concept_id=159614
    AND openmrs.obs.value_coded=118629 
 GROUP BY openmrs.obs.person_id,encounter_id;
 
 UPDATE openmrs.obs ob, itech.obs ito, encounter c, itech.encounter e, itech.precisez ip
     SET ob.comments=ito.value_text
 WHERE c.uuid = e.encGuid
 AND e.siteCode = ito.location_id 
 AND e.encounter_id = ito.encounter_id
 AND ito.concept_id=70091
 AND (ito.value_text <> '' AND ito.value_text is not null)
 AND ip.person_id=ob.person_id
 AND ip.concept_id=ob.concept_id
 AND ip.encounter_id=ob.encounter_id
 AND ip.location_id=ob.location_id
 AND ip.value_coded=ob.value_coded
 AND ip.concept_id=159614
 AND ip.value_coded=118629;	
 
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70064,70120,70121) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70064,70120,70121) and o.value_boolean=1;
/*end of Endométriose [N80.9]*/


/*Fibrome utérin [D26.9]*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70065,70122,70124) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
123455,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70065,70122,70124) and o.value_boolean=1;

TRUNCATE TABLE itech.precisez;
 INSERT INTO itech.precisez(obs_id,person_id,concept_id,encounter_id,location_id, value_coded)
 SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,
 openmrs.obs.concept_id,openmrs.obs.encounter_id, openmrs.obs.location_id, openmrs.obs.value_coded
 FROM openmrs.obs
 WHERE openmrs.obs.concept_id=159614
    AND openmrs.obs.value_coded=123455 
 GROUP BY openmrs.obs.person_id,encounter_id;
 
 UPDATE openmrs.obs ob, itech.obs ito, encounter c, itech.encounter e, itech.precisez ip
     SET ob.comments=ito.value_text
 WHERE c.uuid = e.encGuid
 AND e.siteCode = ito.location_id 
 AND e.encounter_id = ito.encounter_id
 AND ito.concept_id=70093
 AND (ito.value_text <> '' AND ito.value_text is not null)
 AND ip.person_id=ob.person_id
 AND ip.concept_id=ob.concept_id
 AND ip.encounter_id=ob.encounter_id
 AND ip.location_id=ob.location_id
 AND ip.value_coded=ob.value_coded
 AND ip.concept_id=159614
 AND ip.value_coded=123455;	
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70065,70122,70124) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70065,70122,70124) and o.value_boolean=1;
/* end of Fibrome utérin [D26.9]*/


/* Grossesse ectopique [O0.00] */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70066,70123,70125) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
46,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70066,70123,70125) and o.value_boolean=1;

TRUNCATE TABLE itech.precisez;
 INSERT INTO itech.precisez(obs_id,person_id,concept_id,encounter_id,location_id, value_coded)
 SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,
 openmrs.obs.concept_id,openmrs.obs.encounter_id, openmrs.obs.location_id, openmrs.obs.value_coded
 FROM openmrs.obs
 WHERE openmrs.obs.concept_id=159614
    AND openmrs.obs.value_coded=46 
 GROUP BY openmrs.obs.person_id,encounter_id;
 
 UPDATE openmrs.obs ob, itech.obs ito, encounter c, itech.encounter e, itech.precisez ip
     SET ob.comments=ito.value_text
 WHERE c.uuid = e.encGuid
 AND e.siteCode = ito.location_id 
 AND e.encounter_id = ito.encounter_id
 AND ito.concept_id=70095
 AND (ito.value_text <> '' AND ito.value_text is not null)
 AND ip.person_id=ob.person_id
 AND ip.concept_id=ob.concept_id
 AND ip.encounter_id=ob.encounter_id
 AND ip.location_id=ob.location_id
 AND ip.value_coded=ob.value_coded
 AND ip.concept_id=159614
 AND ip.value_coded=46;


	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70066,70123,70125) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70066,70123,70125) and o.value_boolean=1;
/* Grossesse ectopique [O0.00] */


/*Grossesse intra utérine [Z33.1]*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70067,70126,70128) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,132678,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70067,70126,70128) and o.value_boolean=1;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70067,70126,70128) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70067,70126,70128) and o.value_boolean=1;
/*Grossesse intra utérine [Z33.1]*/


/* HTA + grossesse [O16.9] */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70087,71140,71141) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,47,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70087,71140,71141) and o.value_boolean=1;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70087,71140,71141) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70087,71140,71141) and o.value_boolean=1;
/* end of HTA + grossesse [O16.9] */

/* Hémorragie troisième trimestre [O46.90] */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70069,70132,70133) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
163751,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70069,70132,70133) and o.value_boolean=1;

TRUNCATE TABLE itech.precisez;
 INSERT INTO itech.precisez(obs_id,person_id,concept_id,encounter_id,location_id, value_coded)
 SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,
 openmrs.obs.concept_id,openmrs.obs.encounter_id, openmrs.obs.location_id, openmrs.obs.value_coded
 FROM openmrs.obs
 WHERE openmrs.obs.concept_id=159614
    AND openmrs.obs.value_coded=163751 
 GROUP BY openmrs.obs.person_id,encounter_id;
 
 UPDATE openmrs.obs ob, itech.obs ito, encounter c, itech.encounter e, itech.precisez ip
     SET ob.comments=ito.value_text
 WHERE c.uuid = e.encGuid
 AND e.siteCode = ito.location_id 
 AND e.encounter_id = ito.encounter_id
 AND ito.concept_id=71135
 AND (ito.value_text <> '' AND ito.value_text is not null)
 AND ip.person_id=ob.person_id
 AND ip.concept_id=ob.concept_id
 AND ip.encounter_id=ob.encounter_id
 AND ip.location_id=ob.location_id
 AND ip.value_coded=ob.value_coded
 AND ip.concept_id=159614
 AND ip.value_coded=163751;

	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70069,70132,70133) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70069,70132,70133) and o.value_boolean=1;
/* end of Hémorragie troisième trimestre [O46.90]*/


/*Hyperémèse gravidique [O21.0]*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70068,70130,70131) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,490,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70068,70130,70131) and o.value_boolean=1;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70068,70130,70131) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70068,70130,70131) and o.value_boolean=1;
/*Hyperémèse gravidique [O21.0]*/


/*Infection génito-urinaire (IGU) [N73.9]*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70847,70848,70849) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,116988,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70847,70848,70849) and o.value_boolean=1;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70847,70848,70849) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70847,70848,70849) and o.value_boolean=1;
/* end of Infection génito-urinaire (IGU) [N73.9]*/


/* IST */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70097,70136,70137) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
112992,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70097,70136,70137) and o.value_boolean=1;

TRUNCATE TABLE itech.precisez;
 INSERT INTO itech.precisez(obs_id,person_id,concept_id,encounter_id,location_id, value_coded)
 SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,
 openmrs.obs.concept_id,openmrs.obs.encounter_id, openmrs.obs.location_id, openmrs.obs.value_coded
 FROM openmrs.obs
 WHERE openmrs.obs.concept_id=159614
    AND openmrs.obs.value_coded=112992 
 GROUP BY openmrs.obs.person_id,encounter_id;
 
 UPDATE openmrs.obs ob, itech.obs ito, encounter c, itech.encounter e, itech.precisez ip
     SET ob.comments=ito.value_text
 WHERE c.uuid = e.encGuid
 AND e.siteCode = ito.location_id 
 AND e.encounter_id = ito.encounter_id
 AND ito.concept_id=70096
 AND (ito.value_text <> '' AND ito.value_text is not null)
 AND ip.person_id=ob.person_id
 AND ip.concept_id=ob.concept_id
 AND ip.encounter_id=ob.encounter_id
 AND ip.location_id=ob.location_id
 AND ip.value_coded=ob.value_coded
 AND ip.concept_id=159614
 AND ip.value_coded=112992;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70097,70136,70137) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70097,70136,70137) and o.value_boolean=1;
/* end of IST */


/* Kyste de l’ovaire [N83.29] */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70077,70138,70139) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
119702,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70077,70138,70139) and o.value_boolean=1;

TRUNCATE TABLE itech.precisez;
 INSERT INTO itech.precisez(obs_id,person_id,concept_id,encounter_id,location_id, value_coded)
 SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,
 openmrs.obs.concept_id,openmrs.obs.encounter_id, openmrs.obs.location_id, openmrs.obs.value_coded
 FROM openmrs.obs
 WHERE openmrs.obs.concept_id=159614
    AND openmrs.obs.value_coded=119702 
 GROUP BY openmrs.obs.person_id,encounter_id;
 
 UPDATE openmrs.obs ob, itech.obs ito, encounter c, itech.encounter e, itech.precisez ip
     SET ob.comments=ito.value_text
 WHERE c.uuid = e.encGuid
 AND e.siteCode = ito.location_id 
 AND e.encounter_id = ito.encounter_id
 AND ito.concept_id=70102
 AND (ito.value_text <> '' AND ito.value_text is not null)
 AND ip.person_id=ob.person_id
 AND ip.concept_id=ob.concept_id
 AND ip.encounter_id=ob.encounter_id
 AND ip.location_id=ob.location_id
 AND ip.value_coded=ob.value_coded
 AND ip.concept_id=159614
 AND ip.value_coded=119702;

	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70077,70138,70139) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70077,70138,70139) and o.value_boolean=1;

/* end of Kyste de l’ovaire [N83.29]*/


/*Lésion cervicale [D26.0]*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70079,70140,70141) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
157480,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70079,70140,70141) and o.value_boolean=1;

TRUNCATE TABLE itech.precisez;
 INSERT INTO itech.precisez(obs_id,person_id,concept_id,encounter_id,location_id, value_coded)
 SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,
 openmrs.obs.concept_id,openmrs.obs.encounter_id, openmrs.obs.location_id, openmrs.obs.value_coded
 FROM openmrs.obs
 WHERE openmrs.obs.concept_id=159614
    AND openmrs.obs.value_coded=157480 
 GROUP BY openmrs.obs.person_id,encounter_id;
 
 UPDATE openmrs.obs ob, itech.obs ito, encounter c, itech.encounter e, itech.precisez ip
     SET ob.comments=ito.value_text
 WHERE c.uuid = e.encGuid
 AND e.siteCode = ito.location_id 
 AND e.encounter_id = ito.encounter_id
 AND ito.concept_id=70101
 AND (ito.value_text <> '' AND ito.value_text is not null)
 AND ip.person_id=ob.person_id
 AND ip.concept_id=ob.concept_id
 AND ip.encounter_id=ob.encounter_id
 AND ip.location_id=ob.location_id
 AND ip.value_coded=ob.value_coded
 AND ip.concept_id=159614
 AND ip.value_coded=157480;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70079,70140,70141) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70079,70140,70141) and o.value_boolean=1;
/*end of Lésion cervicale [D26.0]*/


/*Maladie inflammatoire pelvienne [N73.9]*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70080,70142,70143) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
902,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70080,70142,70143) and o.value_boolean=1;

TRUNCATE TABLE itech.precisez;
 INSERT INTO itech.precisez(obs_id,person_id,concept_id,encounter_id,location_id, value_coded)
 SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,
 openmrs.obs.concept_id,openmrs.obs.encounter_id, openmrs.obs.location_id, openmrs.obs.value_coded
 FROM openmrs.obs
 WHERE openmrs.obs.concept_id=1284
    AND openmrs.obs.value_coded=902 
 GROUP BY openmrs.obs.person_id,encounter_id;
 
 UPDATE openmrs.obs ob, itech.obs ito, encounter c, itech.encounter e, itech.precisez ip
     SET ob.comments=ito.value_text
 WHERE c.uuid = e.encGuid
 AND e.siteCode = ito.location_id 
 AND e.encounter_id = ito.encounter_id
 AND ito.concept_id=70100
 AND (ito.value_text <> '' AND ito.value_text is not null)
 AND ip.person_id=ob.person_id
 AND ip.concept_id=ob.concept_id
 AND ip.encounter_id=ob.encounter_id
 AND ip.location_id=ob.location_id
 AND ip.value_coded=ob.value_coded
 AND ip.concept_id=1284
 AND ip.value_coded=902;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70080,70142,70143) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70080,70142,70143) and o.value_boolean=1;
/*end of Maladie inflammatoire pelvienne [N73.9]*/

/*Malaria (paludisme) [B52.9]*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (71148,71150,71152,70850,70851,70852) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
116128,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71148,71150,71152,70850,70851,70852) and o.value_boolean=1;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when o.concept_id in (71148,71150,71152) then 159392
     when o.concept_id in (70850,70851,70852) then 159393
	 else null end ,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71148,71150,71152,70850,70851,70852) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71148,71150,71152,70850,70851,70852) and o.value_boolean=1;
/* end of Malaria (paludisme) [B52.9]*/



/* Menace d’accouchement prématurée [O42.00] */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70078,70144,70145) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,158489,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70078,70144,70145) and o.value_boolean=1;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70078,70144,70145) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70078,70144,70145) and o.value_boolean=1;
/*end of Menace d’accouchement prématurée [O42.00] */

/* Mort fœtale [O36.4XX0] */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70146,70147,71136) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,140399,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70146,70147,71136) and o.value_boolean=1;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70146,70147,71136) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70146,70147,71136) and o.value_boolean=1;
/* end of Mort fœtale [O36.4XX0] */


/*Oligoamnios [O41.00X0]*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (71256,71257,71258) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,132425,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71256,71257,71258) and o.value_boolean=1;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71256,71257,71258) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71256,71257,71258) and o.value_boolean=1;
/* end of Oligoamnios [O41.00X0]*/



/*Pathologie rénale,*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (71259,71260,71261) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,6033,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71259,71260,71261) and o.value_boolean=1;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71259,71260,71261) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71259,71260,71261) and o.value_boolean=1;

TRUNCATE TABLE itech.precisez;
 INSERT INTO itech.precisez(obs_id,person_id,concept_id,encounter_id,location_id, value_coded)
 SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,
 openmrs.obs.concept_id,openmrs.obs.encounter_id, openmrs.obs.location_id, openmrs.obs.value_coded
 FROM openmrs.obs
 WHERE openmrs.obs.concept_id=1284
    AND openmrs.obs.value_coded=6033 
 GROUP BY openmrs.obs.person_id,encounter_id;
 
 UPDATE openmrs.obs ob, itech.obs ito, encounter c, itech.encounter e, itech.precisez ip
     SET ob.comments=ito.value_text
 WHERE c.uuid = e.encGuid
 AND e.siteCode = ito.location_id 
 AND e.encounter_id = ito.encounter_id
 AND ito.concept_id=71349
 AND (ito.value_text <> '' AND ito.value_text is not null)
 AND ip.person_id=ob.person_id
 AND ip.concept_id=ob.concept_id
 AND ip.encounter_id=ob.encounter_id
 AND ip.location_id=ob.location_id
 AND ip.value_coded=ob.value_coded
 AND ip.concept_id=1284
 AND ip.value_coded=6033;
	
/* END of Pathologie rénale,*/

/* Pré éclampsie [O14.90], */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70103,70148,70149) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,129251,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70103,70148,70149) and o.value_boolean=1;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70103,70148,70149) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70103,70148,70149) and o.value_boolean=1;

TRUNCATE TABLE itech.precisez;
 INSERT INTO itech.precisez(obs_id,person_id,concept_id,encounter_id,location_id, value_coded)
 SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,
 openmrs.obs.concept_id,openmrs.obs.encounter_id, openmrs.obs.location_id, openmrs.obs.value_coded
 FROM openmrs.obs
 WHERE openmrs.obs.concept_id=1284
    AND openmrs.obs.value_coded=129251 
 GROUP BY openmrs.obs.person_id,encounter_id;
 
 UPDATE openmrs.obs ob, itech.obs ito, encounter c, itech.encounter e, itech.precisez ip
     SET ob.comments=ito.value_text
 WHERE c.uuid = e.encGuid
 AND e.siteCode = ito.location_id 
 AND e.encounter_id = ito.encounter_id
 AND ito.concept_id=70081
 AND (ito.value_text <> '' AND ito.value_text is not null)
 AND ip.person_id=ob.person_id
 AND ip.concept_id=ob.concept_id
 AND ip.encounter_id=ob.encounter_id
 AND ip.location_id=ob.location_id
 AND ip.value_coded=ob.value_coded
 AND ip.concept_id=1284
 AND ip.value_coded=129251;
/* END OF Pré éclampsie [O14.90],*/

/*Retard croissance Intrautérin [P05.9]*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (71262,71263,71264) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,118245,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71262,71263,71264) and o.value_boolean=1;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71262,71263,71264) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71262,71263,71264) and o.value_boolean=1;
/* END OF Retard croissance Intrautérin [P05.9]*/

/*Rupture prématurée des membranes [O42.00]*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70082,70150,70151) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,129211,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70082,70150,70151) and o.value_boolean=1;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70082,70150,70151) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70082,70150,70151) and o.value_boolean=1;
/* END OF Rupture prématurée des membranes [O42.00]*/

/*Saignement utérin anormal [N93.8]*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70083,70152,70153) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,141631,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70083,70152,70153) and o.value_boolean=1;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70083,70152,70153) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70083,70152,70153) and o.value_boolean=1;
/* END OF Saignement utérin anormal [N93.8]*/

/*Syphilis [A53.9]*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (71021,71022,71023) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,112493,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71021,71022,71023) and o.value_boolean=1;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71021,71022,71023) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71021,71022,71023) and o.value_boolean=1;
/* END OF Syphilis [A53.9]*/

/*Thrombopénie [D69.6]*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (71265,71266,71267) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,112406,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71265,71266,71267) and o.value_boolean=1;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71265,71266,71267) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71265,71266,71267) and o.value_boolean=1;
/*END OF Thrombopénie [D69.6]*/

/*Thromboses */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (71268,71269,71270) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,124772,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71268,71269,71270) and o.value_boolean=1;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71268,71269,71270) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71268,71269,71270) and o.value_boolean=1;
/* END OF Thromboses*/

/*Tuberculose [A15.0] remplir la section Tuberculose ci-dessous*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (71403,71404,71405) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,112141,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71403,71404,71405) and o.value_boolean=1;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71403,71404,71405) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71403,71404,71405) and o.value_boolean=1;
/*END OF Tuberculose [A15.0] remplir la section Tuberculose ci-dessous*/

/*MDR TB remplir la section Tuberculose ci-dessous [Z16.24]*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (71271,71272,71273) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159345,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71271,71272,71273) and o.value_boolean=1;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71271,71272,71273) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71271,71272,71273) and o.value_boolean=1;
/*END OF MDR TB remplir la section Tuberculose ci-dessous [Z16.24]*/

/*Travail, Latent*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (71421,71422,71423) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,162938,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71421,71422,71423) and o.value_boolean=1;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71421,71422,71423) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71421,71422,71423) and o.value_boolean=1;
/*END OF Travail, Latent*/

/*Travail, Actif*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (71418,71419,71420) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,162194,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71418,71419,71420) and o.value_boolean=1;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71418,71419,71420) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71418,71419,71420) and o.value_boolean=1;
/*Travail, Actif*/

/*VIH/SIDA [B20]*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70858,71138,71139) and o.value_boolean=1 and c.encounterType in (24,25);

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,149197,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70858,71138,71139) and o.value_boolean=1 and c.encounterType in (24,25);
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70858,71138,71139) and o.value_boolean=1 and c.encounterType in (24,25);

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70858,71138,71139) and o.value_boolean=1 and c.encounterType in (24,25);
/*END OF VIH/SIDA [B20]*/

/*Vulvo vaginite [N76.0]*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70154,70155) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,123380,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70154,70155) and o.value_boolean=1;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70154,70155) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70154,70155) and o.value_boolean=1;
/* END OF Vulvo vaginite [N76.0]*/



/* remarque */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159395,e.encounter_id,e.encounter_datetime,e.location_id,o.value_text,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=7271 and o.value_text<>'';



/*TURBERCULOSE */
/*Nouveau diagnostic,Suivi*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1659,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 160567
     when o.value_numeric=2 then 1662
	 else null
end ,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71224 and o.value_numeric>0;

/* date d'enregistrement TB */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,161552,e.encounter_id,e.encounter_datetime,e.location_id,o.value_datetime ,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71173 and o.value_datetime is not null;

/*Etablissement */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,162724,e.encounter_id,e.encounter_datetime,e.location_id,v.currentTreatFac,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.tbStatus v
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.currentTreatFac<>'';

/* Type de Malade */
/* Nouveau */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159871,e.encounter_id,e.encounter_datetime,e.location_id,160567,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71174 and o.value_boolean=1;
/* Traitement après interruption*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159871,e.encounter_id,e.encounter_datetime,e.location_id,163057,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71175 and o.value_boolean=1;
/* Echec */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159871,e.encounter_id,e.encounter_datetime,e.location_id,159874,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71176 and o.value_boolean=1;
/* Rechute */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159871,e.encounter_id,e.encounter_datetime,e.location_id,160033,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71177 and o.value_boolean=1;
/* Transfere */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159871,e.encounter_id,e.encounter_datetime,e.location_id,159872,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71178 and o.value_boolean=1;
/* MDR TB */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159871,e.encounter_id,e.encounter_datetime,e.location_id,159345,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71179 and o.value_boolean=1;

/* Classification de la maladie */
/* Pulmonaire */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160040,e.encounter_id,e.encounter_datetime,e.location_id,42,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71180 and o.value_boolean=1;
/* Extra Pulmonaire */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160040,e.encounter_id,e.encounter_datetime,e.location_id,5042,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71181 and o.value_boolean=1;

/* Méningite */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160040,e.encounter_id,e.encounter_datetime,e.location_id,111967,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71182 and o.value_boolean=1;

/* Genitale */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160040,e.encounter_id,e.encounter_datetime,e.location_id,159167,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71183 and o.value_boolean=1;

/* Pleurale */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160040,e.encounter_id,e.encounter_datetime,e.location_id,111946,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71184 and o.value_boolean=1;

/* Miliaire */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160040,e.encounter_id,e.encounter_datetime,e.location_id,115753,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71185 and o.value_boolean=1;

/* Ganglionnaire */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160040,e.encounter_id,e.encounter_datetime,e.location_id,111873,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71186 and o.value_boolean=1;

/* Intestinale */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160040,e.encounter_id,e.encounter_datetime,e.location_id,161355,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71187 and o.value_boolean=1;

/* Intestinale */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160040,e.encounter_id,e.encounter_datetime,e.location_id,5622,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71188 and o.value_boolean=1;

TRUNCATE TABLE itech.precisez;
 INSERT INTO itech.precisez(obs_id,person_id,concept_id,encounter_id,location_id, value_coded)
 SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,
 openmrs.obs.concept_id,openmrs.obs.encounter_id, openmrs.obs.location_id, openmrs.obs.value_coded
 FROM openmrs.obs
 WHERE openmrs.obs.concept_id=160040
    AND openmrs.obs.value_coded=5622 
 GROUP BY openmrs.obs.person_id,encounter_id;
 
 UPDATE openmrs.obs ob, itech.obs ito, encounter c, itech.encounter e, itech.precisez ip
     SET ob.comments=ito.value_text
 WHERE c.uuid = e.encGuid
 AND e.siteCode = ito.location_id 
 AND e.encounter_id = ito.encounter_id
 AND ito.concept_id=71189
 AND (ito.value_text <> '' AND ito.value_text is not null)
 AND ip.person_id=ob.person_id
 AND ip.concept_id=ob.concept_id
 AND ip.encounter_id=ob.encounter_id
 AND ip.location_id=ob.location_id
 AND ip.value_coded=ob.value_coded
 AND ip.concept_id=160040
 AND ip.value_coded=5622;
 
 
 /* Diagnostic basé sur */
 /*Crachat*/
  INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163752,e.encounter_id,e.encounter_datetime,e.location_id,307,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71190 and o.value_boolean=1;
  /*X-Ray*/
  INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163752,e.encounter_id,e.encounter_datetime,e.location_id,12,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71191 and o.value_boolean=1;
  /*Impression Clinique*/
  INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163752,e.encounter_id,e.encounter_datetime,e.location_id,1690,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71192 and o.value_boolean=1;


/*Date début traitement */
  INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1113,e.encounter_id,e.encounter_datetime,e.location_id,o.value_datetime,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71193 and o.value_datetime is not null;

/*Régime et posologie prescrits*/
/* E */
  INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1111,e.encounter_id,e.encounter_datetime,e.location_id,75948,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71197 and o.value_boolean=1;

/* 4RH */
  INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1111,e.encounter_id,e.encounter_datetime,e.location_id,160093,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71432 and o.value_boolean=1;

/* 5RHE */
  INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1111,e.encounter_id,e.encounter_datetime,e.location_id,160096,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71433 and o.value_boolean=1;

/* 1RHEZ */
  INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1111,e.encounter_id,e.encounter_datetime,e.location_id,160095,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71220 and o.value_boolean=1;

/* 2RHEZ */
  INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1111,e.encounter_id,e.encounter_datetime,e.location_id,160092,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71198 and o.value_boolean=1;

/* S */
  INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1111,e.encounter_id,e.encounter_datetime,e.location_id,84360,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71218 and o.value_boolean=1;

/* 2S */
  INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1111,e.encounter_id,e.encounter_datetime,e.location_id,163753,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71199 and o.value_boolean=1;

/* 2SRHEZ */
  INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1111,e.encounter_id,e.encounter_datetime,e.location_id,160094,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71434 and o.value_boolean=1;

/* Z */
  INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1111,e.encounter_id,e.encounter_datetime,e.location_id,82900,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71196 and o.value_boolean=1;

/*Cas Contact (TPM+)*/
  INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,124068,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 1065
     when o.value_numeric=2 then 1066
	 else null
end ,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71201 and o.value_numeric in (1,2);

/* Nombre de contacts */
  INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163754,e.encounter_id,e.encounter_datetime,e.location_id,digits(o.value_numeric),1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71202 and digits(o.value_numeric)>=0;

/* No de référence du cas index */
  INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163755,e.encounter_id,e.encounter_datetime,e.location_id,o.value_numeric,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71203 and o.value_numeric>=0;

/* Accompagnateur  */
  INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160112,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 1065
     when o.value_numeric=2 then 1066
	 else null
end ,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71204 and o.value_numeric>=0;

TRUNCATE TABLE itech.precisez;
 INSERT INTO itech.precisez(obs_id,person_id,concept_id,encounter_id,location_id, value_coded)
 SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,
 openmrs.obs.concept_id,openmrs.obs.encounter_id, openmrs.obs.location_id, openmrs.obs.value_coded
 FROM openmrs.obs
 WHERE openmrs.obs.concept_id=160112
    AND openmrs.obs.value_coded in (1065,1066) 
 GROUP BY openmrs.obs.person_id,encounter_id;
 
 UPDATE openmrs.obs ob, itech.obs ito, encounter c, itech.encounter e, itech.precisez ip
     SET ob.comments=ito.value_text
 WHERE c.uuid = e.encGuid
 AND e.siteCode = ito.location_id 
 AND e.encounter_id = ito.encounter_id
 AND ito.concept_id=71189
 AND (ito.value_text <> '' AND ito.value_text is not null)
 AND ip.person_id=ob.person_id
 AND ip.concept_id=ob.concept_id
 AND ip.encounter_id=ob.encounter_id
 AND ip.location_id=ob.location_id
 AND ip.value_coded=ob.value_coded
 AND ip.concept_id=160112
 AND ip.value_coded in (1065,1066);


/*Statut VIH */
  INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1169,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 1402
     when o.value_numeric=2 then 664
	 when o.value_numeric=4 then 703
	 else null
end ,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71205 and o.value_numeric>=0;

/* Date  Statut VIH */
  INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160554,e.encounter_id,e.encounter_datetime,e.location_id,o.value_datetime,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71206 and o.value_datetime is not null;
/* Si positif, enrôlée en soins */
  INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159811,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 1065
     when o.value_numeric=2 then 1066
	 else null
end ,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71212 and o.value_numeric>=0;

/*CD4*/
  INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,5497,e.encounter_id,e.encounter_datetime,e.location_id,digits(o.value_numeric),1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71208 and digits(o.value_numeric)>0;

TRUNCATE TABLE itech.precisez;
 INSERT INTO itech.precisez(obs_id,person_id,concept_id,encounter_id,location_id, value_coded)
 SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,
 openmrs.obs.concept_id,openmrs.obs.encounter_id, openmrs.obs.location_id, openmrs.obs.value_coded
 FROM openmrs.obs
 WHERE openmrs.obs.concept_id=5497
 GROUP BY openmrs.obs.person_id,encounter_id;
 
 UPDATE openmrs.obs ob, itech.obs ito, encounter c, itech.encounter e, itech.precisez ip
     SET ob.obs_datetime=ito.value_datetime
 WHERE c.uuid = e.encGuid
 AND e.siteCode = ito.location_id 
 AND e.encounter_id = ito.encounter_id
 AND ito.concept_id=71226
 AND (ito.value_numeric>0)
 AND ip.person_id=ob.person_id
 AND ip.concept_id=ob.concept_id
 AND ip.encounter_id=ob.encounter_id
 AND ip.location_id=ob.location_id
 AND ip.value_coded=ob.value_coded
 AND ip.concept_id=5497;

 
 /* ARV */
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160117,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 160119
     when o.value_numeric=2 then 1461
	 else null
end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71209 and o.value_numeric>0;

/* Si oui ARV, médicaments */
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163322,e.encounter_id,e.encounter_datetime,e.location_id,o.value_text,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71210 and o.value_text<>'';


/*Date de début*/
  INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159599,e.encounter_id,e.encounter_datetime,e.location_id,o.value_datetime,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71211 and o.value_datetime is not null;

/*Prophylaxie */
  INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1110,e.encounter_id,e.encounter_datetime,e.location_id,1679,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (71409,71410) and o.value_boolean=1;

/* Supplémentation Alimentaire */
  INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,161542,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 1065
     when o.value_numeric=2 then 1066
	 else null
end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71214 and o.value_numeric in (1,2);


TRUNCATE TABLE itech.precisez;
 INSERT INTO itech.precisez(obs_id,person_id,concept_id,encounter_id,location_id, value_coded)
 SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,
 openmrs.obs.concept_id,openmrs.obs.encounter_id, openmrs.obs.location_id, openmrs.obs.value_coded
 FROM openmrs.obs
 WHERE openmrs.obs.concept_id=161542
 GROUP BY openmrs.obs.person_id,encounter_id;
 
 UPDATE openmrs.obs ob, itech.obs ito, encounter c, itech.encounter e, itech.precisez ip
     SET ob.comments=ito.value_text
 WHERE c.uuid = e.encGuid
 AND e.siteCode = ito.location_id 
 AND e.encounter_id = ito.encounter_id
 AND ito.concept_id=71228
 AND (ito.value_text<>'')
 AND ip.person_id=ob.person_id
 AND ip.concept_id=ob.concept_id
 AND ip.encounter_id=ob.encounter_id
 AND ip.location_id=ob.location_id
 AND ip.value_coded=ob.value_coded
 AND ip.concept_id=161542;


 /*Supplémentation en vitamine B*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1193,e.encounter_id,e.encounter_datetime,e.location_id,86341,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71411 and o.value_numeric=1;

/* end of TURBERCULOSE */

/*SURVEILLANCE DU TRAITEMENT(TB)*/
/*RESULTATS DE L’EXPECTORATION*/

/* mois 0 */ 
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159960,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (71158,71159,71160) and (o.value_datetime is not null or digits(o.value_numeric)>0);

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159960 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* the month  */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163756,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,'0',1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71158,71159,71160) and (o.value_datetime is not null or digits(o.value_numeric)>0);
	
/*the date */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159964,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,o.value_datetime,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71158 and o.value_datetime is not null;

/* bascilloscopie */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,307,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when o.value_numeric=1 then 703
     when o.value_numeric=2 then 664
	 else null 
end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71159 and o.value_numeric in (1,2);

/* poids */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,5089,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,FindNumericValue(o.value_numeric),1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71160 and FindNumericValue(o.value_numeric)>0;
/* end of mois 0*/

/* mois 2 */ 
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159960,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (71161,71162,71163) and (o.value_datetime is not null or o.value_numeric>0);

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159960 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* the month  */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163756,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,'2',1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71161,71162,71163) and (o.value_datetime is not null or o.value_numeric>0);
	
/*the date */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159964,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,o.value_datetime,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71161 and o.value_datetime is not null;

/* bascilloscopie */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,307,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when o.value_numeric=1 then 703
     when o.value_numeric=2 then 664
	 else null 
end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71162 and o.value_numeric in (1,2);

/* poids */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,5089,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,FindNumericValue(o.value_numeric),1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71163 and FindNumericValue(o.value_numeric)>0;
/* end of mois 2*/

/* mois 3 */ 
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159960,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (71164,71165,71166) and (o.value_datetime is not null or o.value_numeric>0);

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159960 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* the month  */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163756,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,'3',1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71164,71165,71166) and (o.value_datetime is not null or o.value_numeric>0);
	
/*the date */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159964,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,o.value_datetime,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71164 and o.value_datetime is not null;

/* bascilloscopie */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,307,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when o.value_numeric=1 then 703
     when o.value_numeric=2 then 664
	 else null 
end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71165 and o.value_numeric in (1,2);

/* poids */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,5089,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,FindNumericValue(o.value_numeric),1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71166 and FindNumericValue(o.value_numeric)>0;
/* end of mois 3*/


/* mois 5 */  
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159960,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (71167,71168,71169) and (o.value_datetime is not null or o.value_numeric>0);

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159960 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* the month  */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163756,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,'5',1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71167,71168,71169)  and (o.value_datetime is not null or o.value_numeric>0);
	
/*the date */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159964,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,o.value_datetime,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71167 and o.value_datetime is not null;

/* bascilloscopie */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,307,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when o.value_numeric=1 then 703
     when o.value_numeric=2 then 664
	 else null 
end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71168 and o.value_numeric in (1,2);

/* poids */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,5089,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,FindNumericValue(o.value_numeric),1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71169 and FindNumericValue(o.value_numeric)>0;
/* end of mois 5*/

/* mois Fin de rx */ 
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159960,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (71170,71171,71172) and (o.value_datetime is not null or o.value_numeric>0);

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159960 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* the month  */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163756,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,'Fin de rx',1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71170,71171,71172)  and (o.value_datetime is not null or o.value_numeric>0);
	
/*the date */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159964,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,o.value_datetime,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71170 and o.value_datetime is not null;

/* bascilloscopie */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,307,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when o.value_numeric=1 then 703
     when o.value_numeric=2 then 664
	 else null 
end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71171 and o.value_numeric in (1,2);

/* poids */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,5089,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,FindNumericValue(o.value_numeric),1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71172 and FindNumericValue(o.value_numeric)>0;
/* end of mois Fin de rx */

/* END OF SURVEILLANCE DU TRAITEMENT(TB)*/

/* RESULTAT DU TRAITEMENT(TB) */
/*Date d’arret du traitement*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159431,e.encounter_id,e.encounter_datetime,e.location_id,o.value_datetime,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71215 and o.value_datetime is not null;


 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159786,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 159791
     when o.value_numeric=2 then 160035
	 when o.value_numeric=8 then 159874
	 when o.value_numeric=16 then 160031
	 when o.value_numeric=32 then 160034
	 else null 
 end,1,e.date_created,UUID() 
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71216 and o.value_numeric in (1,2,4,8,16,32);

/* END OF RESULTAT DU TRAITEMENT(TB) */

/* Conduite a tenir */

/* Planification familiale */
/*Counseling effectué*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1382,e.encounter_id,e.encounter_datetime,e.location_id,1065,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71402 and o.value_boolean=1;

/* Date début */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163757,e.encounter_id,e.encounter_datetime,e.location_id,o.value_datetime,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70584 and o.value_datetime is not null;

/* Date d’arrêt*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163758,e.encounter_id,e.encounter_datetime,e.location_id,o.value_datetime,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70585 and o.value_datetime is not null;

/*Utilisation Courante*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160653,e.encounter_id,e.encounter_datetime,e.location_id,965,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=8081 and o.value_numeric=1;

/*Méthode PF administrée*/
/* Condom  */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,374,e.encounter_id,e.encounter_datetime,e.location_id,
case when  v.famPlanMethodCondom=1 then 190
	 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.vitals v
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.famPlanMethodCondom>0;

/*Ligature des trompes*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,374,e.encounter_id,e.encounter_datetime,e.location_id,1472,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=7879 and o.value_numeric=1;

/*Pilule: Combiné*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,374,e.encounter_id,e.encounter_datetime,e.location_id,780,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71372 and o.value_boolean=1;

/*Progestatif seule*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,374,e.encounter_id,e.encounter_datetime,e.location_id,82624,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71373 and o.value_boolean=1;

/* Implants */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,374,e.encounter_id,e.encounter_datetime,e.location_id,1359,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71127 and o.value_boolean=1;

/* Stérilet */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,374,e.encounter_id,e.encounter_datetime,e.location_id,5275,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=7877 and o.value_boolean=1;

/* Injectable */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,374,e.encounter_id,e.encounter_datetime,e.location_id,5279,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71128 and o.value_boolean=1;

/* Collier, jour fixe */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,374,e.encounter_id,e.encounter_datetime,e.location_id,163759,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71374 and o.value_boolean=1;

TRUNCATE TABLE itech.precisez;
 INSERT INTO itech.precisez(obs_id,person_id,concept_id,encounter_id,location_id, value_coded)
 SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,
 openmrs.obs.concept_id,openmrs.obs.encounter_id, openmrs.obs.location_id, openmrs.obs.value_coded
 FROM openmrs.obs
 WHERE openmrs.obs.concept_id=374 and openmrs.obs.value_coded=163759
 GROUP BY openmrs.obs.person_id,encounter_id;
 
 UPDATE openmrs.obs ob, itech.obs ito, encounter c, itech.encounter e, itech.precisez ip
     SET ob.obs_datetime=ito.value_datetime
 WHERE c.uuid = e.encGuid
 AND e.siteCode = ito.location_id 
 AND e.encounter_id = ito.encounter_id
 AND ito.concept_id=71375
 AND (ito.value_datetime is not null)
 AND ip.person_id=ob.person_id
 AND ip.concept_id=ob.concept_id
 AND ip.encounter_id=ob.encounter_id
 AND ip.location_id=ob.location_id
 AND ip.value_coded=ob.value_coded
 AND ip.concept_id=374 and ip.value_coded=163759;
 
 /*Autre */
  INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,374,e.encounter_id,e.encounter_datetime,e.location_id,5622,o.value_text,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70721 and o.value_text<>'';


/* Vaccination */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1421,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70411,70414) and (o.value_boolean=1 or o.value_text<>'');

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1421 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* DT/Tétanos toxoïde  */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,984,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,17,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=70411 and o.value_boolean=1;
	
/* Autre */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,comments,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,984,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,5622,o.value_text,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=70414 and o.value_text<>'';
/* end of Vaccination*/

/* Medicaments prescrits / Posologie */
 /* 1  */
  INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70416) and (o.value_boolean=1 or o.value_text<>'');

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,comments,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,5622,o.value_text,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=70416 and o.value_text<>'';
	
 /* 2  */ 
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70417) and (o.value_boolean=1 or o.value_text<>'');

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,comments,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,5622,substring(o.value_text,1000),1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=70417 and o.value_text<>'';

 /* 3  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70418) and (o.value_boolean=1 or o.value_text<>'');

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,comments,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,5622,o.value_text,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=70418 and o.value_text<>'';

 /* 4  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70419) and (o.value_boolean=1 or o.value_text<>'');

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,comments,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,5622,o.value_text,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=70419 and o.value_text<>'';

 /* 5  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70420) and (o.value_boolean=1 or o.value_text<>'');

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;

INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,comments,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,5622,o.value_text,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=70420 and o.value_text<>'';

/* end of Medicaments prescrits / Posologie*/

/*Suivi et planification*/
/*Semaine de Gestation*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1438,e.encounter_id,e.encounter_datetime,e.location_id,FindNumericValue(o.value_text),1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70750 and FindNumericValue(o.value_text)>0;

/* Facteur de risque Aucune*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160079,e.encounter_id,e.encounter_datetime,e.location_id,1107,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71376 and o.value_boolean=1;

/* Facteur de risque Ancienne césarisée*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160079,e.encounter_id,e.encounter_datetime,e.location_id,145777,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71377 and o.value_boolean=1;

/* Facteur de risque Anémie */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160079,e.encounter_id,e.encounter_datetime,e.location_id,148834,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71378 and o.value_boolean=1;

/* Facteur de risque Diabète */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160079,e.encounter_id,e.encounter_datetime,e.location_id,119476,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71379 and o.value_boolean=1;


/* Facteur de risque Œdème */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160079,e.encounter_id,e.encounter_datetime,e.location_id,460,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71380 and o.value_boolean=1;

/* Facteur de risque Grande parité*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160079,e.encounter_id,e.encounter_datetime,e.location_id,1053,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71381 and o.value_boolean=1;

/* Facteur de risque <18ans */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160079,e.encounter_id,e.encounter_datetime,e.location_id,163119,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71382 and o.value_boolean=1;

/* Facteur de risque >35ans */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160079,e.encounter_id,e.encounter_datetime,e.location_id,163120,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71383 and o.value_boolean=1;

/* Facteur de risque Grossesse multiple */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160079,e.encounter_id,e.encounter_datetime,e.location_id,115491,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71384 and o.value_boolean=1;

/* Facteur de risque Hémorragie antépartum */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160079,e.encounter_id,e.encounter_datetime,e.location_id,228,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71385 and o.value_boolean=1;

/* Facteur de risque Hypertension */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160079,e.encounter_id,e.encounter_datetime,e.location_id,113858,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71386 and o.value_boolean=1;

/* Facteur de risque Poids stationnaire */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160079,e.encounter_id,e.encounter_datetime,e.location_id,136784,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71387 and o.value_boolean=1;

/* Facteur de risque VIH */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160079,e.encounter_id,e.encounter_datetime,e.location_id,163210,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71388 and o.value_boolean=1;

/* Facteur de risque Taille < 150cm */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160079,e.encounter_id,e.encounter_datetime,e.location_id,162589,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71389 and o.value_boolean=1;
/* end of Suivi et planification */

/*Counseling pretest Date */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163760,e.encounter_id,e.encounter_datetime,e.location_id,1065,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71390 and o.value_boolean=1;

TRUNCATE TABLE itech.precisez;
 INSERT INTO itech.precisez(obs_id,person_id,concept_id,encounter_id,location_id, value_coded)
 SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,
 openmrs.obs.concept_id,openmrs.obs.encounter_id, openmrs.obs.location_id, openmrs.obs.value_coded
 FROM openmrs.obs
 WHERE openmrs.obs.concept_id=163760 and openmrs.obs.value_coded=1065
 GROUP BY openmrs.obs.person_id,encounter_id;
 
 UPDATE openmrs.obs ob, itech.obs ito, encounter c, itech.encounter e, itech.precisez ip
     SET ob.obs_datetime=ito.value_datetime
 WHERE c.uuid = e.encGuid
 AND e.siteCode = ito.location_id 
 AND e.encounter_id = ito.encounter_id
 AND ito.concept_id=71391
 AND (ito.value_datetime is not null)
 AND ip.person_id=ob.person_id
 AND ip.concept_id=ob.concept_id
 AND ip.encounter_id=ob.encounter_id
 AND ip.location_id=ob.location_id
 AND ip.value_coded=ob.value_coded
 AND ip.concept_id=163760 and ip.value_coded=1065;
 
 
 /*Counseling post test Date*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159382,e.encounter_id,e.encounter_datetime,e.location_id,1065,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71392 and o.value_boolean=1;

TRUNCATE TABLE itech.precisez;
 INSERT INTO itech.precisez(obs_id,person_id,concept_id,encounter_id,location_id, value_coded)
 SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,
 openmrs.obs.concept_id,openmrs.obs.encounter_id, openmrs.obs.location_id, openmrs.obs.value_coded
 FROM openmrs.obs
 WHERE openmrs.obs.concept_id=159382 and openmrs.obs.value_coded=1065
 GROUP BY openmrs.obs.person_id,encounter_id;
 
 UPDATE openmrs.obs ob, itech.obs ito, encounter c, itech.encounter e, itech.precisez ip
     SET ob.obs_datetime=ito.value_datetime
 WHERE c.uuid = e.encGuid
 AND e.siteCode = ito.location_id 
 AND e.encounter_id = ito.encounter_id
 AND ito.concept_id=71393
 AND (ito.value_datetime is not null)
 AND ip.person_id=ob.person_id
 AND ip.concept_id=ob.concept_id
 AND ip.encounter_id=ob.encounter_id
 AND ip.location_id=ob.location_id
 AND ip.value_coded=ob.value_coded
 AND ip.concept_id=159382 and ip.value_coded=1065;
 
 /*Patiente sous ARV*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,161557,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 1065
     when o.value_numeric=2 then 1066
	 else null
end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71394 and o.value_numeric in (1,2);


 /*Référence partenaire*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1436,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 703
     when o.value_numeric=2 then 664
	 when o.value_numeric=4 then 1067
	 else null
end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71395 and o.value_numeric in (1,2);


/* Motif de dépistage */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163761,e.encounter_id,e.encounter_datetime,e.location_id,o.value_text,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71396 and o.value_text<>'';

/* VIH Positif:Stade OMS */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,5356,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=70753 and o.value_boolean=1 then 1204
     when o.concept_id=70754 and o.value_boolean=1 then 1205
	 when o.concept_id=70755 and o.value_boolean=1 then 1206
	 when o.concept_id=70756 and o.value_boolean=1 then 1207
	 when o.concept_id=70757 and o.value_boolean=1 then 1067
	 else null
end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in(70753,70754,70755,70756,70757) and o.value_boolean=1;

/*Numération ou taux de CD4*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,5497,e.encounter_id,e.encounter_datetime,e.location_id,FindNumericValue(o.value_text),1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70758 and FindNumericValue(o.value_text)>0;

/* Référence */
/*Psychologue*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1272,e.encounter_id,e.encounter_datetime,e.location_id,5490,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70421 and o.value_boolean=1;

/*Programme de nutrition */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1272,e.encounter_id,e.encounter_datetime,e.location_id,5484,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70422 and o.value_boolean=1;

/*Planification familiale*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1272,e.encounter_id,e.encounter_datetime,e.location_id,5483,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70423 and o.value_boolean=1;

/*Salle de Travail et d’Accouchement (STA)*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1272,e.encounter_id,e.encounter_datetime,e.location_id,1371,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70761 and o.value_boolean=1;

/*Hospitalisation*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1272,e.encounter_id,e.encounter_datetime,e.location_id,5485,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70425 and o.value_boolean=1;

/*Structure Communautaire*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1272,e.encounter_id,e.encounter_datetime,e.location_id,1555,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70762 and o.value_boolean=1;

/*Fiches de référence remplie*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1272,e.encounter_id,e.encounter_datetime,e.location_id,163762,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70424 and o.value_boolean=1;

/* Autre établissement / clinique */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,161562,e.encounter_id,e.encounter_datetime,e.location_id,o.value_text,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70648 and o.value_text<>'';

/* end of Conduite a tenir */

/* AUTRE PLAN */
/*Date de prochaine visite */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,5096,e.encounter_id,e.encounter_datetime,e.location_id,o.value_datetime,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71067 and o.value_datetime is not null;

/*Suivi Prénatal*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1592,e.encounter_id,e.encounter_datetime,e.location_id,1622,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70729 and o.value_boolean=1;

/*Dispensation ARV*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1592,e.encounter_id,e.encounter_datetime,e.location_id,5576,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70730 and o.value_boolean=1;


/*Education Individuelle*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1592,e.encounter_id,e.encounter_datetime,e.location_id,163106,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70731 and o.value_boolean=1;


/*Education des Accompagnateurs*/
/*INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1592,e.encounter_id,e.encounter_datetime,e.location_id,,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70732 and o.value_boolean=1;
*/
/*Visite Domiciliaire */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1592,e.encounter_id,e.encounter_datetime,e.location_id,162186,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70733 and o.value_boolean=1;

/*Club des Mères Groupe de Support */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1592,e.encounter_id,e.encounter_datetime,e.location_id,5486,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71068 and o.value_boolean=1;

/*Conseils sur l’allaitement maternel */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1592,e.encounter_id,e.encounter_datetime,e.location_id,1910,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71398 and o.value_boolean=1;

/*Date Probable d’accouchement*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,5596,e.encounter_id,e.encounter_datetime,e.location_id,o.value_datetime,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71069 and o.value_datetime is not null;

/* Lieu */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159758,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=2 then 1536
     when o.value_numeric=1 then 1589
	 else null
end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=7955 and o.value_numeric in (1,2);

TRUNCATE TABLE itech.precisez;
 INSERT INTO itech.precisez(obs_id,person_id,concept_id,encounter_id,location_id, value_coded)
 SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,
 openmrs.obs.concept_id,openmrs.obs.encounter_id, openmrs.obs.location_id, openmrs.obs.value_coded
 FROM openmrs.obs
 WHERE openmrs.obs.concept_id=159758 and openmrs.obs.value_coded=1589
 GROUP BY openmrs.obs.person_id,encounter_id;
 
 UPDATE openmrs.obs ob, itech.obs ito, encounter c, itech.encounter e, itech.precisez ip
     SET ob.comments=ito.value_text
 WHERE c.uuid = e.encGuid
 AND e.siteCode = ito.location_id 
 AND e.encounter_id = ito.encounter_id
 AND ito.concept_id=7957
 AND (ito.value_datetime is not null)
 AND ip.person_id=ob.person_id
 AND ip.concept_id=ob.concept_id
 AND ip.encounter_id=ob.encounter_id
 AND ip.location_id=ob.location_id
 AND ip.value_coded=ob.value_coded
 AND ip.concept_id=159758 and ip.value_coded=1589;

 /*Si domicile et femme VIH positif*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163764,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 1065
     when o.value_numeric=2 then 1066
	 else null
end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=7958 and o.value_numeric in (1,2);


TRUNCATE TABLE itech.precisez;
 INSERT INTO itech.precisez(obs_id,person_id,concept_id,encounter_id,location_id, value_coded)
 SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,
 openmrs.obs.concept_id,openmrs.obs.encounter_id, openmrs.obs.location_id, openmrs.obs.value_coded
 FROM openmrs.obs
 WHERE openmrs.obs.concept_id=163764 and openmrs.obs.value_coded=1065
 GROUP BY openmrs.obs.person_id,encounter_id;
 
 UPDATE openmrs.obs ob, itech.obs ito, encounter c, itech.encounter e, itech.precisez ip
     SET ob.comments=ito.value_text
 WHERE c.uuid = e.encGuid
 AND e.siteCode = ito.location_id 
 AND e.encounter_id = ito.encounter_id
 AND ito.concept_id=7959
 AND (ito.value_datetime is not null)
 AND ip.person_id=ob.person_id
 AND ip.concept_id=ob.concept_id
 AND ip.encounter_id=ob.encounter_id
 AND ip.location_id=ob.location_id
 AND ip.value_coded=ob.value_coded
 AND ip.concept_id=163764 and ip.value_coded=1065;
 
 /*Si domicile : Planification pour la présence d’une matrone*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,161007,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 1065
     when o.value_numeric=2 then 1066
	 else null
end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=7960 and o.value_numeric in (1,2);


TRUNCATE TABLE itech.precisez;
 INSERT INTO itech.precisez(obs_id,person_id,concept_id,encounter_id,location_id, value_coded)
 SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,
 openmrs.obs.concept_id,openmrs.obs.encounter_id, openmrs.obs.location_id, openmrs.obs.value_coded
 FROM openmrs.obs
 WHERE openmrs.obs.concept_id=161007 and openmrs.obs.value_coded=1065
 GROUP BY openmrs.obs.person_id,encounter_id;
 
 UPDATE openmrs.obs ob, itech.obs ito, encounter c, itech.encounter e, itech.precisez ip
     SET ob.comments=ito.value_text
 WHERE c.uuid = e.encGuid
 AND e.siteCode = ito.location_id 
 AND e.encounter_id = ito.encounter_id
 AND ito.concept_id=7961
 AND (ito.value_datetime is not null)
 AND ip.person_id=ob.person_id
 AND ip.concept_id=ob.concept_id
 AND ip.encounter_id=ob.encounter_id
 AND ip.location_id=ob.location_id
 AND ip.value_coded=ob.value_coded
 AND ip.concept_id=161007 and ip.value_coded=1065;
 
 /*Planification pour un Accompagnateur*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160112,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 1065
     when o.value_numeric=2 then 1066
	 else null
end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=7307 and o.value_numeric in (1,2);

/*Planification pour transition dans une Maison de Naissance*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163765,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 1065
     when o.value_numeric=2 then 1066
	 else null
end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71070 and o.value_numeric in (1,2);

/*Inscrite dans un Club des Mères*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163766,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 1065
     when o.value_numeric=2 then 1066
	 else null
end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=7967 and o.value_numeric in (1,2);

/*Date de Prochaine Visite*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163766,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 1065
     when o.value_numeric=2 then 1066
	 else null
end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=7967 and o.value_numeric in (1,2);


/* END OF AUTRE PLAN*/

END;



