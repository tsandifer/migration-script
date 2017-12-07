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
drop procedure if exists ordonanceMigration;
DELIMITER $$ 
CREATE PROCEDURE ordonanceMigration()
BEGIN
  DECLARE done INT DEFAULT FALSE;
 -- DECLARE a CHAR(16);
  DECLARE vstatus boolean;
  DECLARE vvisit_type_id INT;
  DECLARE obs_datetime_,vobs_datetime,vdate_created,vencounter_datetime datetime;
  DECLARE vobs_id,vperson_id,vconcept_id,vencounter_id,vlocation_id INT;
  
DECLARE uuid_encounter CURSOR  for SELECT DISTINCT e.patientID,e.encounter_id FROM itech.encounter e;


 SET SQL_SAFE_UPDATES = 0;

/* L'enfant est-il au courant de son statut VIH?*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163524,e.encounter_id,e.encounter_datetime,e.location_id,
	CASE WHEN v.pedChildAware=1 THEN 1065
	     WHEN v.pedChildAware=2 THEN 1066
		 WHEN v.pedChildAware=4 THEN 1067
		ELSE NULL
	END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.pedHistory v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d') = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.pedChildAware in (1,2,4);

/* dispensation communautaire */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1755,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN o.concept_id=71642 AND o.value_boolean=1 THEN 1065
	 ELSE NULL
END,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and o.concept_id=71642 and o.value_boolean=1;	


select 1 as test1;


/* Abacavir(ABC) */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,70056,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=1;
 /*Rx,Prophy*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160742,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.forPepPmtct=1 then 163768
     when v.forPepPmtct=2 then 138405
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=1 and v.forPepPmtct in (1,2);

 /* dosage */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when c.encounterType=5 and v.stdDosage=1 then d.stdDosageDescription
     when c.encounterType=18 and v.stdDosage=1 then d.pedStdDosageFr1
	 when c.encounterType=18 and v.stdDosage=2 then d.pedStdDosageFr2
	 else d.stdDosageDescription
end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.drugLookup d,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and d.drugID=v.drugID and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=1;

 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=1 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=1 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,70056,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=1;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=1 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=1 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=1 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=1 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/


select 2 as test2;


/* Combivir(AZT+3TC) */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=8;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,630,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=8;
 /*Rx,Prophy*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160742,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.forPepPmtct=1 then 163768
     when v.forPepPmtct=2 then 138405
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=8 and v.forPepPmtct in (1,2);

 /* dosage */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when c.encounterType=5 and v.stdDosage=1 then d.stdDosageDescription
     when c.encounterType=18 and v.stdDosage=1 then d.pedStdDosageFr1
	 when c.encounterType=18 and v.stdDosage=2 then d.pedStdDosageFr2
	 else d.stdDosageDescription
end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.drugLookup d,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and d.drugID=v.drugID and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=8;

 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=8 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=8 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=8;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,630,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=8;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=8 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=8 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=8 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=8 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/

select 3 as test3;

/* Didanosine */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=10;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,74807,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=10;
 /*Rx,Prophy*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160742,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.forPepPmtct=1 then 163768
     when v.forPepPmtct=2 then 138405
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=10 and v.forPepPmtct in (1,2);

 /* dosage */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when c.encounterType=5 and v.stdDosage=1 then d.stdDosageDescription
     when c.encounterType=18 and v.stdDosage=1 then d.pedStdDosageFr1
	 when c.encounterType=18 and v.stdDosage=2 then d.pedStdDosageFr2
	 else d.stdDosageDescription
end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.drugLookup d,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and d.drugID=v.drugID and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=10;

 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=10 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=10 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=10;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,74807,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=10;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=10 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=10 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=10 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=10 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/

select 4 as test4;

/* Emtricitabine(FTC) */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=12;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,75628,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=12;
 /*Rx,Prophy*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160742,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.forPepPmtct=1 then 163768
     when v.forPepPmtct=2 then 138405
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=12 and v.forPepPmtct in (1,2);

 /* dosage */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when c.encounterType=5 and v.stdDosage=1 then d.stdDosageDescription
     when c.encounterType=18 and v.stdDosage=1 then d.pedStdDosageFr1
	 when c.encounterType=18 and v.stdDosage=2 then d.pedStdDosageFr2
	 else d.stdDosageDescription
end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.drugLookup d,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and d.drugID=v.drugID and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=12;

 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=12 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=12 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=12;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,75628,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=12;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=12 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=12 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=12 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=12 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/


select 5 as test5;

/* Lamivudine(3TC)*/
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=20;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,78643,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=20;
 /*Rx,Prophy*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160742,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.forPepPmtct=1 then 163768
     when v.forPepPmtct=2 then 138405
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=20 and v.forPepPmtct in (1,2);

 /* dosage */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when c.encounterType=5 and v.stdDosage=1 then d.stdDosageDescription
     when c.encounterType=18 and v.stdDosage=1 then d.pedStdDosageFr1
	 when c.encounterType=18 and v.stdDosage=2 then d.pedStdDosageFr2
	 else d.stdDosageDescription
end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.drugLookup d,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and d.drugID=v.drugID and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=20;

 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=20 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=20 and FindNumericValue(v.numDaysDesc)>0;

/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=20;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,78643,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=20;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=20 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=20 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=20 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=20 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/


select 6 as test6;


/* Stavudine(d4T) */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=29;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,84309,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=29;
 /*Rx,Prophy*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160742,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.forPepPmtct=1 then 163768
     when v.forPepPmtct=2 then 138405
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=29 and v.forPepPmtct in (1,2);

 /* dosage */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when c.encounterType=5 and v.stdDosage=1 then d.stdDosageDescription
     when c.encounterType=18 and v.stdDosage=1 then d.pedStdDosageFr1
	 when c.encounterType=18 and v.stdDosage=2 then d.pedStdDosageFr2
	 else d.stdDosageDescription
end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.drugLookup d,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and d.drugID=v.drugID and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=29;

 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=29 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=29 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=29;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,84309,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=29;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=29 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=29 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=29 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=29 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/


select 7 as test7;


/* Tenofovir(TNF) */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=31;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,84795,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=31;
 /*Rx,Prophy*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160742,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.forPepPmtct=1 then 163768
     when v.forPepPmtct=2 then 138405
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=31 and v.forPepPmtct in (1,2);

select 71 as test71;
 /* dosage */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when c.encounterType=5 and v.stdDosage=1 then d.stdDosageDescription
     when c.encounterType=18 and v.stdDosage=1 then d.pedStdDosageFr1
	 when c.encounterType=18 and v.stdDosage=2 then d.pedStdDosageFr2
	 else d.stdDosageDescription
end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.drugLookup d,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and d.drugID=v.drugID and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=31 and v.stdDosage=1;

select 72 as test72;
 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=31 and v.altDosageSpecify<>'';

select 73 as test73;
/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=31 and FindNumericValue(v.numDaysDesc)>0;

select 730 as test730;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=31;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,84795,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=31;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=31 and v.dispensed=1;

select 74 as test74;
 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=31 and v.dispAltDosageSpecify<>'';

select 75 as test75;
 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=31 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

select 76 as test76;
/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=31 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/


select 8 as test8;


/* Trizivir(ABC+AZT+3TC)*/
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=33;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,817,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=33;
 /*Rx,Prophy*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160742,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.forPepPmtct=1 then 163768
     when v.forPepPmtct=2 then 138405
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=33 and v.forPepPmtct in (1,2);

 /* dosage */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when c.encounterType=5 and v.stdDosage=1 then d.stdDosageDescription
     when c.encounterType=18 and v.stdDosage=1 then d.pedStdDosageFr1
	 when c.encounterType=18 and v.stdDosage=2 then d.pedStdDosageFr2
	 else d.stdDosageDescription
end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.drugLookup d,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and d.drugID=v.drugID and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=33;

 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=33 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=33 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=33;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,817,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=33;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=33 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=33 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=33 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=33 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/




/* Zidovudine(AZT) */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=34;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,86663,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=34;
 /*Rx,Prophy*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160742,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.forPepPmtct=1 then 163768
     when v.forPepPmtct=2 then 138405
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=34 and v.forPepPmtct in (1,2);

 /* dosage */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when c.encounterType=5 and v.stdDosage=1 then d.stdDosageDescription
     when c.encounterType=18 and v.stdDosage=1 then d.pedStdDosageFr1
	 when c.encounterType=18 and v.stdDosage=2 then d.pedStdDosageFr2
	 else d.stdDosageDescription
end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.drugLookup d,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and d.drugID=v.drugID and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=34;

 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=34 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=34 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=34;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,86663,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=34;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=34 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=34 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=34 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=34 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/




/* Efavirenz(EFV)*/
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=11;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,75523,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=11;
 /*Rx,Prophy*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160742,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.forPepPmtct=1 then 163768
     when v.forPepPmtct=2 then 138405
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=11 and v.forPepPmtct in (1,2);

 /* dosage */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when c.encounterType=5 and v.stdDosage=1 then d.stdDosageDescription
     when c.encounterType=18 and v.stdDosage=1 then d.pedStdDosageFr1
	 when c.encounterType=18 and v.stdDosage=2 then d.pedStdDosageFr2
	 else d.stdDosageDescription
end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.drugLookup d,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and d.drugID=v.drugID and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=11;

 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=11 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=11 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=11;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,75523,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=11;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=11 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=11 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=11 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=11 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/





/* Nevirapine(NVP)*/
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=23;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,80586,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=23;
 /*Rx,Prophy*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160742,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.forPepPmtct=1 then 163768
     when v.forPepPmtct=2 then 138405
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=23 and v.forPepPmtct in (1,2);

 /* dosage */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when c.encounterType=5 and v.stdDosage=1 then d.stdDosageDescription
     when c.encounterType=18 and v.stdDosage=1 then d.pedStdDosageFr1
	 when c.encounterType=18 and v.stdDosage=2 then d.pedStdDosageFr2
	 else d.stdDosageDescription
end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.drugLookup d,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and d.drugID=v.drugID and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=23;

 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=23 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=23 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=23;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,80586,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=23;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=23 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=23 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=23 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=23 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/





/* Atazanavir(ATZN) */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=5;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,71647,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=5;
 /*Rx,Prophy*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160742,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.forPepPmtct=1 then 163768
     when v.forPepPmtct=2 then 138405
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=5 and v.forPepPmtct in (1,2);

 /* dosage */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when c.encounterType=5 and v.stdDosage=1 then d.stdDosageDescription
     when c.encounterType=18 and v.stdDosage=1 then d.pedStdDosageFr1
	 when c.encounterType=18 and v.stdDosage=2 then d.pedStdDosageFr2
	 else d.stdDosageDescription
end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.drugLookup d,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and d.drugID=v.drugID and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=5;

 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=5 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=5 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=5;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,71647,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=5;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=5 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=5 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=5 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=5 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/





/* Atazanavir+BostRTV */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=6;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159809,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=6;
 /*Rx,Prophy*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160742,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.forPepPmtct=1 then 163768
     when v.forPepPmtct=2 then 138405
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=6 and v.forPepPmtct in (1,2);

 /* dosage */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when c.encounterType=5 and v.stdDosage=1 then d.stdDosageDescription
     when c.encounterType=18 and v.stdDosage=1 then d.pedStdDosageFr1
	 when c.encounterType=18 and v.stdDosage=2 then d.pedStdDosageFr2
	 else d.stdDosageDescription
end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.drugLookup d,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and d.drugID=v.drugID and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=6;

 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=6 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=6 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=6;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159809,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=6;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=6 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=6 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=6 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=6 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/



/* Indinavir(IDV) */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=16;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,77995,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=16;
 /*Rx,Prophy*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160742,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.forPepPmtct=1 then 163768
     when v.forPepPmtct=2 then 138405
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=16 and v.forPepPmtct in (1,2);

 /* dosage */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when c.encounterType=5 and v.stdDosage=1 then d.stdDosageDescription
     when c.encounterType=18 and v.stdDosage=1 then d.pedStdDosageFr1
	 when c.encounterType=18 and v.stdDosage=2 then d.pedStdDosageFr2
	 else d.stdDosageDescription
end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.drugLookup d,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and d.drugID=v.drugID and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=16;

 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=16 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=16 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=16;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,77995,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=16;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=16 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=16 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=16 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=16 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/






/* Lopinavir + BostRTV(Kaletra)*/
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=21;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,794,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=21;
 /*Rx,Prophy*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160742,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.forPepPmtct=1 then 163768
     when v.forPepPmtct=2 then 138405
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=21 and v.forPepPmtct in (1,2);

 /* dosage */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when c.encounterType=5 and v.stdDosage=1 then d.stdDosageDescription
     when c.encounterType=18 and v.stdDosage=1 then d.pedStdDosageFr1
	 when c.encounterType=18 and v.stdDosage=2 then d.pedStdDosageFr2
	 else d.stdDosageDescription
end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.drugLookup d,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and d.drugID=v.drugID and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=21;

 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=21 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=21 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=21;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,794,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=21;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=21 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=21 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=21 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=21 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/






/* Darunavir */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=88;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,74258,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=88;
 /*Rx,Prophy*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160742,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.forPepPmtct=1 then 163768
     when v.forPepPmtct=2 then 138405
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=88 and v.forPepPmtct in (1,2);

 /* dosage */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when c.encounterType=5 and v.stdDosage=1 then d.stdDosageDescription
     when c.encounterType=18 and v.stdDosage=1 then d.pedStdDosageFr1
	 when c.encounterType=18 and v.stdDosage=2 then d.pedStdDosageFr2
	 else d.stdDosageDescription
end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.drugLookup d,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and d.drugID=v.drugID and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=88;

 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=88 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=88 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=88;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,74258,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=88;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=88 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=88 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=88 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=88 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/





/* Raltegravir */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=87;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,154378,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=87;
 /*Rx,Prophy*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160742,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.forPepPmtct=1 then 163768
     when v.forPepPmtct=2 then 138405
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=87 and v.forPepPmtct in (1,2);

 /* dosage */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when c.encounterType=5 and v.stdDosage=1 then d.stdDosageDescription
     when c.encounterType=18 and v.stdDosage=1 then d.pedStdDosageFr1
	 when c.encounterType=18 and v.stdDosage=2 then d.pedStdDosageFr2
	 else d.stdDosageDescription
end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.drugLookup d,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and d.drugID=v.drugID and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=87;

 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=87 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=87 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=87;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,154378,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=87;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=87 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=87 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=87 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=87 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/


/*Acétaminophène*/
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=36;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,70116,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=36;
 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=36 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=36 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=36;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,70116,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=36;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=36 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=36 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=36 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=36 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/



/* Aspirine */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=37;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,71617,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=37;
 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=37 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=37 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=37;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,71617,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=37;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=37 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=37 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=37 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=37 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/


/* Hydroxyde d'aluminium */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=82;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,70994,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=82;
 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=82 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=82 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=82;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,70994,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=82;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=82 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=82 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=82 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=82 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/




/* Enalapril */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=80;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,75633,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=80;
 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=80 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=80 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=80;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,75633,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=80;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=80 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=80 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=80 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=80 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/



/* HCTZ */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=81;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,77696,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=81;
 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=81 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=81 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=81;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,77696,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=81;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=81 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=81 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=81 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=81 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/





/* Amoxiciline */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=55;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,71160,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=55;
 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=55 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=55 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=55;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,71160,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=55;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=55 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=55 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=55 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=55 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/




/* Ciprofloxacine */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=42;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,73449,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=42;
 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=42 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=42 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=42;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,73449,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=42;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=42 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=42 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=42 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=42 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/





/* Clarithromycin */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=56;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,73498,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=56;
 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=56 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=56 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=56;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,73498,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=56;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=56 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=56 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=56 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=56 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/





/* Clindamycine */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=57;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,73546,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=57;
 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=57 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=57 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=57;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,73546,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=57;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=57 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=57 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=57 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=57 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/






/* Cotrimoxazole */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=9;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,105281,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=9;
 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=9 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=9 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=9;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,105281,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=9;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=9 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=9 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=9 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=9 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/




/* Erythromycin */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=43;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,75842,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=43;
 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=43 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=43 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=43;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,75842,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=43;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=43 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=43 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=43 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=43 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/





/* Metromidazole */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=44;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,79782,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=44;
 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=44 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=44 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=44;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,79782,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=44;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=44 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=44 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=44 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=44 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/





/* Doxycyline */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=79;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,75222,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=79;
 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=79 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=79 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=79;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,75222,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=79;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=79 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=79 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=79 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=79 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/




/* PNC */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=84;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,81724,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=84;
 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=84 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=84 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=84;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,81724,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=84;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=84 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=84 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=84 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=84 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/




/* Amphotericine B */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=58;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,71184,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=58;
 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=58 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=58 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=58;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,71184,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=58;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=58 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=58 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=58 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=58 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/




/* Fluconazole */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=14;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,76488,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=14;
 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=14 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=14 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=14;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,76488,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=14;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=14 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=14 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=14 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=14 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/





/* Itraconazole */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=59;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,78338,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=59;
 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=59 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=59 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=59;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,78338,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=59;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=59 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=59 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=59 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=59 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/






/* Ketaconazole */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=19;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,78476,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=19;
 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=19 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=19 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=19;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,78476,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=19;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=19 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=19 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=19 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=19 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/




/* Miconazole */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=45;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,79831,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=45;
 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=45 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=45 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=45;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,79831,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=45;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=45 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=45 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=45 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=45 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/







/* Nystatin */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=46;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,80945,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=46;
 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=46 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=46 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=46;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,80945,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=46;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=46 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=46 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=46 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=46 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/





/* Chloroquine */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=60;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,73300,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=60;
 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=60 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=60 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=60;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,73300,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=60;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=60 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=60 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=60 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltNumPills>0 then v.dispAltNumPills else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=60 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/


/* Ivermectine */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=64;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,78342,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=64;
 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=64 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=64 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=64;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,78342,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=64;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=64 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=64 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=64 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=64 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/




/* Primaquine */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=85;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,82521,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=85;
 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=85 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=85 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=85;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,82521,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=85;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=85 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=85 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=85 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=85 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/




/* Pyrimethamine */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=61;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,82919,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=61;
 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=61 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=61 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=61;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,82919,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=61;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=61 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=61 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=61 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=61 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/




/* Quinine */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=62;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,83023,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=62;
 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=62 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=62 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=62;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,83023,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=62;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=62 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=62 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=62 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=62 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/



/* Sulfadiazine */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=63;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,84459,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=63;
 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=63 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=63 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=63;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,84459,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=63;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=63 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=63 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=63 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=63 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/




/* Ethambutol */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=13;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,75948,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=13;
 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=13 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=13 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=13;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,75948,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=13;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=13 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=13 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=13 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=13 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/







/* Isoniazide */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=18;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,78280,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=18;
 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=18 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=18 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=18;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,78280,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=18;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=18 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=18 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=18 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=18 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/




/* Pyrazinamide */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=24;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,82900,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=24;
 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=24 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=24 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=24;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,82900,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=24;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=24 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=24 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=24 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=24 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/




/* Rifampicine */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=25;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,767,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=25;
 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=25 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=25 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=25;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,82900,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=25;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=25 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=25 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=25 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=25 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/






/* Streptomycine */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=30;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,84360,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=30;
 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=30 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=30 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=30;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,84360,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=30;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=30 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=30 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=30 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=30 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/






/* Acide Folique */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=48;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,76613,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=48;
 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=48 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=48 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=48;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,84360,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=48;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=48 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=48 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=48 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=48 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/






/* B Complexe */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=47;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,86341,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=47;
 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=47 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=47 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=47;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,86341,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=47;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=47 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=47 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=47 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=47 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/





/* Fer */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=49;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,78218,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=49;
 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=49 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=49 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=49;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,78218,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=49;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=49 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=49 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=49 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=49 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/







/* Multivitamine */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=50;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,461,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=50;
 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=50 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=50 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=50;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,461,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=50;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=50 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=50 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=50 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=50 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/




/* Pyridoxine */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=65;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,82912,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=65;
 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=65 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=65 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=65;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,82912,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=65;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=65 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=65 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=65 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=65 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/




/* Supplément Protéinique */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=51;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,82767,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=51;
 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=51 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=51 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=51;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,82767,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=51;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=51 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=51 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=51 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=51 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/





/* Vitamine C */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=52;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,71589,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=52;
 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=52 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=52 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=52;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,71589,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=52;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=52 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=52 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=52 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=52 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/




/* Acyclovir*/
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=2;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,70245,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=2;
 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=2 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=2 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=2;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,70245,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=2;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=2 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=2 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=2 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=2 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/



/* Loperamide*/
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=53;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,79037,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=53;
 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=53 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=53 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=53;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,79037,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=53;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=53 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=53 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=53 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=53 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/




/* Promethazine*/
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=54;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,82667,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=54;
 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=54 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=54 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=54;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,82667,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=54;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=54 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=54 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=54 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=54 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/






/* Calamine*/
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=78;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,493,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=78;
 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=78 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=78 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=78;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,493,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=78;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=78 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=78 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=78 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=78 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/



/* Bromhexine*/
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=77;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,72401,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=77;
 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=77 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=77 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=77;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,72401,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=77;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=77 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=77 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=77 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=77 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/



/* Benzoate de benzyl */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=76;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,72075,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=76;
 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=76 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=76 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=76;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,72075,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=76;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=76 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=76 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=76 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=76 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/



/* drug pediatric */

/*  Nelfinavir (NFV) */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=22;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,80487,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=22;
 /*Rx,Prophy*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160742,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.forPepPmtct=1 then 163768
     when v.forPepPmtct=2 then 138405
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=22 and v.forPepPmtct in (1,2);

 /* dosage */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when c.encounterType=5 and v.stdDosage=1 then d.stdDosageDescription
     when c.encounterType=18 and v.stdDosage=1 then d.pedStdDosageFr1
	 when c.encounterType=18 and v.stdDosage=2 then d.pedStdDosageFr2
	 else d.stdDosageDescription
end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.drugLookup d,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and d.drugID=v.drugID and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=22;

 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=22 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=22 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=22;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,80487,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=22;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=22 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=22 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=22 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=22 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/



/* Saquinavir (SQV) */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=27;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,83690,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=27;
 /*Rx,Prophy*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160742,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.forPepPmtct=1 then 163768
     when v.forPepPmtct=2 then 138405
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=27 and v.forPepPmtct in (1,2);

 /* dosage */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when c.encounterType=5 and v.stdDosage=1 then d.stdDosageDescription
     when c.encounterType=18 and v.stdDosage=1 then d.pedStdDosageFr1
	 when c.encounterType=18 and v.stdDosage=2 then d.pedStdDosageFr2
	 else d.stdDosageDescription
end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.drugLookup d,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and d.drugID=v.drugID and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=27;

 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=27 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=27 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=27;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,80487,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=27;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=27 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=27 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=27 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=27 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/



/* Ritonavir (RTV) */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=26;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,83412,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=26;
 /*Rx,Prophy*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,160742,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.forPepPmtct=1 then 163768
     when v.forPepPmtct=2 then 138405
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=26 and v.forPepPmtct in (1,2);

 /* dosage */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when c.encounterType=5 and v.stdDosage=1 then d.stdDosageDescription
     when c.encounterType=18 and v.stdDosage=1 then d.pedStdDosageFr1
	 when c.encounterType=18 and v.stdDosage=2 then d.pedStdDosageFr2
	 else d.stdDosageDescription
end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.drugLookup d,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and d.drugID=v.drugID and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=26;

 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=26 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=26 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=26;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,83412,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=26;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=26 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=26 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=26 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=26 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/








/* Diclofenac */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=72;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,74778,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=72;
 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=72 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=72 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=72;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,74778,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=72;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=72 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=72 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=72 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=72 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/


/* Ibuprofen */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=38;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,77897,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=38;
 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=38 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=38 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=38;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,77897,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=38;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=38 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=38 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=38 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=38 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/





/* Paracétamol */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=39;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,70116,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=39;
 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=39 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=39 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=39;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,70116,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=39;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=39 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=39 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=39 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=39 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/







/* Amoxiciline + acide clavulanique */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=73;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,450,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=73;
 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=73 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=73 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=73;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,450,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=73;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=73 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=73 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=73 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=73 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/







/* mebendazole */
  /* migration group 1 */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1442,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=75;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=1442 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,79413,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=75;
 /* dosage alternative */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.altDosageSpecify<>'' then v.altDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=75 and v.altDosageSpecify<>'';

/* Durée de prise des médicaments */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.numDaysDesc)>0 then FindNumericValue(v.numDaysDesc) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=75 and FindNumericValue(v.numDaysDesc)>0;
/* end migration group 1*/

  /* migration group 2*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163711,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=75;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=163711 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the drug */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1282,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,79413,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=75;
 /* MÉDICAMENT dispense A LA VISITE */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1276,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispensed=1 then 1065
	 else null
end ,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=75 and v.dispensed=1;

 /* Posologie alternative  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1444,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when v.dispAltDosageSpecify<>'' then v.dispAltDosageSpecify else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=75 and v.dispAltDosageSpecify<>'';

 /* Nombre de jours alternatifs  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159368,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumDaysSpecify)>0 then FindNumericValue(v.dispAltNumDaysSpecify) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=75 and FindNumericValue(v.dispAltNumDaysSpecify)>0;

/* Nombre de pillules distribuée*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1443,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,
case when FindNumericValue(v.dispAltNumPills)>0 then FindNumericValue(v.dispAltNumPills) else null end,1,e.date_created,UUID()
FROM itech.encounter c, encounter e,  itech.prescriptions v ,itech.obs_concept_group og
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')  = concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.drugID=75 and FindNumericValue(v.dispAltNumPills)>0;

/* End of migration group 2*/


END;


