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
case when o.concept_id=70589 and o.value_boolean>0 then 131034 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=70589 and o.value_boolean>0;
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
case when o.concept_id=7007 and o.value_boolean>0 then 122496 else null end,1,e.date_created,UUID()
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
	 o.value_numeric=3 then 1118 
	 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=7086 and o.value_numeric in (1,2,3);

/* Cou + Thyroïde */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163388,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 1115 
     when o.value_numeric=2 then 1116
	 o.value_numeric=3 then 1118 
	 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=7087 and o.value_numeric in (1,2,3);

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
	 o.value_numeric=3 then 1118 
	 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=7088 and o.value_numeric in (1,2,3);

/* Seins */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159780,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 1115 
     when o.value_numeric=2 then 1116
	 o.value_numeric=3 then 1118 
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
	 o.value_numeric=3 then 1118 
	 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=7904 and o.value_numeric in (1,2,3);


/*Organes génitaux Externes*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163743,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 1115 
     when o.value_numeric=2 then 1116
	 o.value_numeric=3 then 1118 
	 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=7091 and o.value_numeric in (1,2,3);

/* Vagin */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163744,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 1115 
     when o.value_numeric=2 then 1116
	 o.value_numeric=3 then 1118 
	 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=7092 and o.value_numeric in (1,2,3);

/* Col */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160704,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 1115 
     when o.value_numeric=2 then 1116
	 o.value_numeric=3 then 1118 
	 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=7093 and o.value_numeric in (1,2,3);

/* Annexes */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163745,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 1115 
     when o.value_numeric=2 then 1116
	 o.value_numeric=3 then 1118 
	 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=7094 and o.value_numeric in (1,2,3);

/* Toucher Rectal */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163746,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 1115 
     when o.value_numeric=2 then 1116
	 o.value_numeric=3 then 1118 
	 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=7095 and o.value_numeric in (1,2,3);


/* Membres */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1127,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 1115 
     when o.value_numeric=2 then 1116
	 o.value_numeric=3 then 1118 
	 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=7096 and o.value_numeric in (1,2,3);

/* Reflexes Ostéo-Tendineux */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160623,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 1115 
     when o.value_numeric=2 then 1116
	 o.value_numeric=3 then 1118 
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
	 o.value_numeric=3 then 1118 
	 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71233 and o.value_numeric in (1,2,3);

/* Lymphadenopathy Supraclaviculaire */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159003,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 163747 
     when o.value_numeric=2 then 163748
	 o.value_numeric=3 then 1118 
	 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71234 and o.value_numeric in (1,2,3);

/* Lymphadenopathy Axillaire */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,148058,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 163747 
     when o.value_numeric=2 then 163748
	 o.value_numeric=3 then 1118 
	 else null end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o 
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71235 and o.value_numeric in (1,2,3);

/* Lymphadenopathy Inguinale */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163950,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 163747 
     when o.value_numeric=2 then 163748
	 o.value_numeric=3 then 1118 
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
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,110247,1,e.date_created,UUID()
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
o.concept_id in (70057,70104,70105,) nd o.value_boolean=1;
	
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
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,comments,creator,date_created,uuid)
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
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,comments,creator,date_created,uuid)
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
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,comments,creator,date_created,uuid)
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
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,comments,creator,date_created,uuid)
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
 WHERE openmrs.obs.concept_id=159614
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
 AND ip.concept_id=159614
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
     when o.value_numercic=2 then 1662
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
 FROM itech.encounter c, encounter e,tbStatus v
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

/* end of TURBERCULOSE */




END;







