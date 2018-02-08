drop function if exists IsNumeric;
CREATE FUNCTION IsNumeric (val varchar(255)) RETURNS tinyint 
 RETURN val REGEXP '^(-|\\+){0,1}([0-9]+\\.[0-9]*|[0-9]*\\.[0-9]+|[0-9]+)$';

DROP FUNCTION if exists FindNumericValue;
DELIMITER $$
 
CREATE FUNCTION FindNumericValue(val VARCHAR(255)) RETURNS VARCHAR(255)
    DETERMINISTIC
BEGIN
  DECLARE idx INT DEFAULT 0;
  IF ISNULL(val) THEN RETURN NULL; END IF;

  IF LENGTH(val) = 0 THEN RETURN ""; END IF;
 SET idx = LENGTH(val);
  WHILE idx > 0 DO
   IF IsNumeric(SUBSTRING(val,idx,1)) = 0 THEN
    SET val = REPLACE(val,SUBSTRING(val,idx,1),"");
    SET idx = LENGTH(val)+1;
   END IF;
    SET idx = idx - 1;
  END WHILE;
   RETURN val;
END
$$
DELIMITER ;
drop procedure if exists obygnMigration;
DELIMITER $$ 
CREATE PROCEDURE obygnMigration()
BEGIN
  DECLARE done INT DEFAULT FALSE;
 -- DECLARE a CHAR(16);
  DECLARE vstatus boolean;
  DECLARE vvisit_type_id INT;
  DECLARE obs_datetime_,vobs_datetime,vdate_created,vencounter_datetime datetime;
  DECLARE vobs_id,vperson_id,vconcept_id,vencounter_id,vlocation_id INT;


 SET SQL_SAFE_UPDATES = 0;

/* Groupe sanguin */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,300,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN o.concept_id=71142 AND o.value_coded=1 THEN 690
     WHEN o.concept_id=71142 AND o.value_coded=2 THEN 692
	 WHEN o.concept_id=71142 AND o.value_coded=4 THEN 694
	 WHEN o.concept_id=71142 AND o.value_coded=8 THEN 696
	 WHEN o.concept_id=71142 AND o.value_coded=16 THEN 699
	 WHEN o.concept_id=71142 AND o.value_coded=32 THEN 701
	 WHEN o.concept_id=71142 AND o.value_coded=64 THEN 1230
	 WHEN o.concept_id=71142 AND o.value_coded=128 THEN 1231
	 WHEN o.concept_id=71142 AND o.value_coded=256 THEN 1107
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71142 and o.value_coded>0;		

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
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160592,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
140234,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70800,70801,70803) and o.value_boolean=1;
 /*Pere / Mere  /  Frere ou soeur */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1560,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when o,concept_id=70800 and o.value_boolean=1 then 970
     when o,concept_id=70801 and o.value_boolean=1 then 971
	 when o,concept_id=70803 and o.value_boolean=1 then 972
	 else null
end ,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70800,70801,70803) and o.value_boolean=1;

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
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160592,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,151521,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70802,70804,70805)  and o.value_boolean=1;
 /*Pere / Mere  /  Frere ou soeur */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1560,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when o,concept_id=70802 and o.value_boolean=1 then 970
     when o,concept_id=70805 and o.value_boolean=1 then 971
	 when o,concept_id=70805 and o.value_boolean=1 then 972
	 else null
end ,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70802,70804,70805)  and o.value_boolean=1;

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
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160592,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,163114,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70807,70808,70809) and o.value_boolean=1;
 /*Pere / Mere  /  Frere ou soeur */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1560,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when o,concept_id=70807 and o.value_boolean=1 then 970
     when o,concept_id=70808 and o.value_boolean=1 then 971
	 when o,concept_id=70809 and o.value_boolean=1 then 972
	 else null
end ,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70807,70808,70809) and o.value_boolean=1;

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
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160592,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,140228,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70810,70811,70812) and o.value_boolean=1;
 /*Pere / Mere  /  Frere ou soeur */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1560,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when o,concept_id=70810 and o.value_boolean=1 then 970
     when o,concept_id=70811 and o.value_boolean=1 then 971
	 when o,concept_id=70812 and o.value_boolean=1 then 972
	 else null
end ,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70810,70811,70812) and o.value_boolean=1;

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
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160592,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,152450,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70813,70814,70815) and o.value_boolean=1;
 /*Pere / Mere  /  Frere ou soeur */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1560,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when o,concept_id=70813 and o.value_boolean=1 then 970
     when o,concept_id=70814 and o.value_boolean=1 then 971
	 when o,concept_id=70815 and o.value_boolean=1 then 972
	 else null
end ,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70813,70814,70815) and o.value_boolean=1;

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
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160592,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,151927,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70816,70817,70818) and o.value_boolean=1;
 /*Pere / Mere  /  Frere ou soeur */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1560,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when o,concept_id=70816 and o.value_boolean=1 then 970
     when o,concept_id=70817 and o.value_boolean=1 then 971
	 when o,concept_id=70818 and o.value_boolean=1 then 972
	 else null
end ,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70816,70817,70818) and o.value_boolean=1;

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
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160592,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,152460,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70819,70820,70821) and o.value_boolean=1;
 /*Pere / Mere  /  Frere ou soeur */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1560,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when o,concept_id=70819 and o.value_boolean=1 then 970
     when o,concept_id=70820 and o.value_boolean=1 then 971
	 when o,concept_id=70821 and o.value_boolean=1 then 972
	 else null
end ,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70819,70820,70821) and o.value_boolean=1;

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
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160592,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,139071,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71237,71238,71239) and o.value_boolean=1;
 /*Pere / Mere  /  Frere ou soeur */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1560,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when o,concept_id=71237 and o.value_boolean=1 then 970
     when o,concept_id=71238 and o.value_boolean=1 then 971
	 when o,concept_id=71239 and o.value_boolean=1 then 972
	 else null
end ,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71237,71238,71239) and o.value_boolean=1;

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
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1628,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,152512,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=70001 and o.value_boolean=1;
/* end of Accident cérébro-vasculaire */

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
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1628,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,110247,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=70002 and o.value_boolean=1;

/* Precisez*/
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160221,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,o.value_text,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71002 and o.value_text<>'';
/* end of Allergies */

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
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1628,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,139212,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=70005 and o.value_boolean=1;
/* end of Asthme */

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
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1628,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,151286,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=70006 and o.value_boolean=1;

/* Precisez*/
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160221,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,o.value_text,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71003 and o.value_text<>'';

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
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1628,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,156660,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=70012 and o.value_boolean=1;

/* Precisez*/
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160221,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,o.value_text,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71016 and o.value_text<>'';

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
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1628,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,122432,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=70007 and o.value_boolean=1;
/* end of Cardiopathie */

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
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1628,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,163521,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=70736 and o.value_boolean=1;

/* Precisez*/
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160221,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,o.value_text,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=70737 and o.value_text<>'';

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
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1628,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,1625,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=70009 and o.value_boolean=1;
/* end of Epilepsie */

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
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1628,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,163583,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=70452 and o.value_boolean=1;

/* Precisez*/
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160221,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,o.value_text,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=70739 and o.value_text<>'';

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
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1628,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,156639,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=70011 and o.value_boolean=1;

/* end of HTA */

/* Hyperchoestérolémie */
  /* migration group */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1633,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71438 and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1633 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1628,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,156633,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71438 and o.value_boolean=1;

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
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1628,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159449,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=70015 and o.value_boolean=1;
/* end of Alcool */

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
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1628,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,162556,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71010 and o.value_boolean=1;

/* Precisez*/
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160221,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,o.value_text,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71011 and o.value_text<>'';

/* end of Drogue */


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
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1628,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,163731,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=70016 and o.value_boolean=1;
/* end of Tabac */

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
SELECT DISTINCT e.patient_id,1628,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,162556,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=70008 and o.value_boolean=1;
/* end of Diabète */


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
SELECT DISTINCT e.patient_id,1169,e.encounter_id,e.encounter_datetime,e.location_id,date(o.value_datetime) ,1,e.date_created,UUID()
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
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
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

/* end of ANTECEDENTS PERSONNELS/HABITUDES */

/* ANTECEDENTS OBSTETRICO/GYNECOLOGIQUE*/
/*Age des Ménarches */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160598,e.encounter_id,e.encounter_datetime,e.location_id,o.value_numeric,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=8067 and o.value_numeric>0;

/*Age des premières relations sexuelles*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163587,e.encounter_id,e.encounter_datetime,e.location_id,o.value_numeric,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=8068 and o.value_numeric>0;

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
case when o.value_numeric=1 then 158306 else null end ,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=7868 and o.value_numeric=1;

/*Dysménorrhée Si oui */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1628,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 129135 
     when o.value_numeric=2 then 152336 
	 else null 
end ,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=7869 and o.value_numeric in (1,2);

/*Infertilité */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1628,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 158308 
	 else null 
end ,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=71352 and o.value_numeric=1;

/*Gravida para aborda  */ /* allready done in vih*/

 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1825,e.encounter_id,e.encounter_datetime,e.location_id,FindNumericValue(o.value_text) ,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=7870 and FindNumericValue(o.value_text)>0;

/*Grossesse multiple,Pré éclampsie sévère,Hémorragie de la grossesse/post-partum*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1628,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 115491
     when o.value_numeric=2 then 113006
	 when o.value_numeric=4 then 117612
	 else null 
end ,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=70032 and o.value_numeric in (1,2,4);


/* Grossesse 1 */
     /*Date  */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160602,e.encounter_id,e.encounter_datetime,e.location_id,o.value_datetime ,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=71353 and o.value_datetime is not null;




/* Grossesse 2 */
     /*Date  */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160602,e.encounter_id,e.encounter_datetime,e.location_id,o.value_datetime ,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=71358 and o.value_datetime is not null;


/* Grossesse 3 */
     /*Date  */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160602,e.encounter_id,e.encounter_datetime,e.location_id,o.value_datetime ,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=71363 and o.value_datetime is not null;


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
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numercic,creator,date_created,uuid)
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
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numercic,creator,date_created,uuid)
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
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,creator,date_created,uuid)
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
o.concept_id=70029 and o.value_text<>'';

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
SELECT DISTINCT e.patient_id,5271,e.encounter_id,e.encounter_datetime,e.location_id, 
case when o.value_numeric=1 then 1267
     when o.value_numeric=2 then 1118
	 else null 
end,1,e.date_created,UUID()
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
SELECT DISTINCT e.patient_id,374,e.encounter_id,e.encounter_datetime,e.location_id, o.value_text,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and
o.concept_id=70164 and o.value_text<>'';


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

/* END OF VACCINS */



/* Agressions sexuelles <72H */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163737,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=71131 and o.value_boolean>0 then 163733
	 else null
end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71131 and o.value_boolean>0;

/* Agressions sexuelles 72H - 120H*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163737,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=71132 and o.value_boolean>0 then 163734
	 else null
end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71132 and o.value_boolean>0;

/* Agressions sexuelles 120H - 2sem */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163737,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=71133 and o.value_boolean>0 then 163735
	 else null
end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71133 and o.value_boolean>0;

/* Agressions sexuelles 2 sem et plus */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163737,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=71134 and o.value_boolean>0 then 163736
	 else null
end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id=71134 and o.value_boolean>0;

/* */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163737,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.concept_id=70587 and o.value_boolean>0 then 148989 else null end,
case when o.concept_id=70622 and o.value_text<>'' then o.value_text else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
((o.concept_id=70587 and o.value_boolean>0) or (o.concept_id=70622 and o.value_text<>''));







	
END;






