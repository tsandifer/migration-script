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
DELIMITER $$ 
DROP PROCEDURE IF EXISTS travailAccMigration$$
CREATE PROCEDURE travailAccMigration()
BEGIN
	 /*Delete all inserted discontinuations data if the script fail*/
	 SET SQL_SAFE_UPDATES = 0;
	 SET FOREIGN_KEY_CHECKS=0;
	 DELETE FROM obs WHERE encounter_id IN
	 (
		SELECT en.encounter_id FROM encounter en, encounter_type ent
		WHERE en.encounter_type=ent.encounter_type_id
		AND ent.uuid='d95b3540-a39f-4d1e-a301-8ee0e03d5eab'
	 );
	  SET SQL_SAFE_UPDATES = 1;
	  SET FOREIGN_KEY_CHECKS=1;
  /*End of delete all inserted discontinuations data*/
   /*Start migration for Travailleur Accouchement Form*/
		/*Start migration for Grossesse suivie:*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1622,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN ito.value_numeric=1 THEN 1
	WHEN ito.value_numeric=2 THEN 2
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=70523;
	/*End migration for Grossesse suivie:*/
	/*Start migration for Poids*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,5089,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,FindNumericValue(ito.value_text),1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=7842
	AND FindNumericValue(ito.value_text) > 0;
	/*End migration for Poids*/
	/*Start migration for G (Gravida)*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,5624,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,FindNumericValue(v.gravida),1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.vitals v
	WHERE c.uuid = e.encGuid and 
	e.patientID = v.patientID and e.siteCode = v.siteCode
	AND (v.gravida<>"" AND v.gravida is not null)
	AND e.encounterType=26
	AND FindNumericValue(v.gravida) > 0;
	/*End migration for G (Gravida)*/
	/*Start migration for P (Para)*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1053,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,FindNumericValue(v.para),1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.vitals v
	WHERE c.uuid = e.encGuid and 
	e.patientID = v.patientID and e.siteCode = v.siteCode
	AND (v.para<>"" AND v.para is not null)
	AND e.encounterType=26
	AND FindNumericValue(v.para) > 0;
	/*End migraion for P (Para)*/
	/*Start migration for Aborta*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1823,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,FindNumericValue(v.aborta),1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.vitals v
	WHERE c.uuid = e.encGuid and 
	e.patientID = v.patientID and e.siteCode = v.siteCode
	AND (v.aborta<>"" AND v.aborta is not null)
	AND e.encounterType=26
	AND FindNumericValue(v.aborta) > 0;
	/*End migration for Aborta*/
	/*Start migration for EV (Enfants Vivants)*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1825,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,FindNumericValue(ito.value_text),1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=7870
	AND FindNumericValue(ito.value_text) > 0;
	/*End migration for EV (Enfants Vivants)*/
	/*Start migration for Grossesse désirée:*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163085,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN ito.value_numeric=1 THEN 122933
	WHEN ito.value_numeric=2 THEN 123572
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=71275;
	/*End migration for Grossesse désirée:*/
	/*Start migration for Référence:*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1648,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN ito.value_numeric=1 THEN 1
	WHEN ito.value_numeric=2 THEN 2
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=71276;
	/*End migration for Référence:*/
	/*Start migration for Si oui: (matrone ou autre)*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,160482,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN ito.value_numeric=1 THEN 1578
	WHEN ito.value_numeric=2 THEN 5622
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=71277;
	/*End migration for Si oui: (matrone ou autre)*/
	/*Start migration for Prophylaxie contre la Malaria:*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159610,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN ito.value_numeric=1 THEN 1
	WHEN ito.value_numeric=2 THEN 2
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=71278;
	/*End migration for Prophylaxie contre la Malaria:*/
	
	/*Start migration for Heure d'admission:*/
	
	/*End migration for Heure d'admission:*/
	
	/*Start migration for Grossesse:*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159949,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN ito.value_numeric=1 THEN 159913
	WHEN ito.value_numeric=2 THEN 159914
	WHEN ito.value_numeric=4 THEN 115491
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=70531;
	/*End migration for Grossesse:*/
	/*Start migration for DEBUT DU TRAVAIL(Date et Heure)*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_datetime,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163444,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,ito.value_datetime,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=7802;
	/*End migration for DEBUT DU TRAVAIL (Date et Heure)*/
	/*Start migration for Age gestationnel*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1409,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,FindNumericValue(ito.value_text),1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=7803
	AND FindNumericValue(ito.value_text) > 0;
	/*End migration for Age gestationnel*/
	/*Start migration for Hauteur utérine*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1439,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,FindNumericValue(ito.value_text),1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=7804
	AND FindNumericValue(ito.value_text) > 0;
	/*End migration for Hauteur utérine*/
	/*Start migration for Présentation:*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,160090,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN ito.value_numeric=1 THEN 160091
	WHEN ito.value_numeric=2 THEN 139814
	WHEN ito.value_numeric=4 THEN 112259
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=7805;
	/*End migration for Présentation:*/
	/*Start migration for précisez  (Céphalique, Précisez=70532)(Transversale, Précisez=70533):*/
	
	/*End migration for précisez  :*/
	/*Start migration for Rythme Cardiaque Foetal*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1440,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,FindNumericValue(ito.value_text),1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=7806
	AND FindNumericValue(ito.value_text) > 0;
	/*End migration for Rythme Cardiaque Foetal*/
	/*Start migration for Fièvre:*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,140238,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN ito.value_numeric=1 THEN 1065
	WHEN ito.value_numeric=2 THEN 1066
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=7807;
	/*End migration for Fièvre:*/
	/*Start migration for Rupture des membranes: (A verifier)*/
	/*INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,140238,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN ito.value_numeric=1 THEN 1065
	WHEN ito.value_numeric=2 THEN 1066
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=;*/
	/*End migration for Rupture des membranes:*/
	/*Start migration for Date et Heure:*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_datetime,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,160710,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,ito.value_datetime,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=7809;
	/*End migration for Date et Heure:*/
	/*Start migration for Liquide amniotique :*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163446,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN ito.value_numeric=1 THEN 1115
	WHEN ito.value_numeric=2 THEN 155311
	WHEN ito.value_numeric=4 THEN 134488
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=7810;
	/*End migration for Liquide amniotique :*/
	/*Start migration for Dystocie :*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163449,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN ito.value_numeric=1 THEN 163447
	WHEN ito.value_numeric=2 THEN 163448
	WHEN ito.value_numeric=4 THEN 5622
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=71279;
	/*End migration for Dystocie*/
	/*Start migration for Procidence du cordon :*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,128420,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN ito.value_numeric=1 THEN 1065
	WHEN ito.value_numeric=2 THEN 1066
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=71280;
	/*End migration for Procidence du cordon :*/
	
	/*Start migration for Hémorragie vaginale:*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,147232,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN ito.value_numeric=1 THEN 1065
	WHEN ito.value_numeric=2 THEN 1066
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=7828;
	/*End migration for Hémorragie vaginale:*/
	/*Start migration for Si oui, précisez:*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,147232,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN ito.value_numeric=1 THEN 130108
	WHEN ito.value_numeric=2 THEN 138902
	WHEN ito.value_numeric=4 THEN 127259
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=70534;
	/*End migration for Si oui, précisez:*/
	/*Start migration for Autre, précisez  :*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,147232,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,5622,ito.value_text,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=70535
	AND (ito.value_text<>"" AND ito.value_text is not null) ;
	/*End migration for Autre, précisez  :*/
	/*Start migration for Perte sanguine estimée à:*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161928,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,FindNumericValue(ito.value_text),1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=70518
	AND FindNumericValue(ito.value_text) > 0;
	/*End migration for Perte sanguine estimée à:*/
	/*Start migration for Transfusion :*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1063,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN ito.value_numeric=1 THEN 1
	WHEN ito.value_numeric=2 THEN 2
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=7829;
	/*End migration for Transfusion :*/
	/*Start migration for HTA*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,113858,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=70525
	AND ito.value_numeric=1;
	/*End migration for HTA*/
	/*Start migration for Pré Eclampsie Sévère*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,113006,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=70529
	AND ito.value_numeric=1;
	/*End migration for Pré Eclampsie Sévère*/
	/*Start migration for Eclampsie*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,118744,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=71281
	AND ito.value_numeric=1;
	/*End migration for Eclampsie*/
	/*Start migration for Si VIH positif: TAR*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,160117,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN ito.value_numeric=1 THEN 160119
	WHEN ito.value_numeric=2 THEN 1461
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=71129;
	/*End migration for Si VIH positif: TAR*/
	
	/*Start migration for Accouchement part*/
		/*Start migration for Date et Heure*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_datetime,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,5599,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,ito.value_datetime,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=7819;
		/*End migration for Date et Heure*/
		/*Start migration for Lieu Accouchement :*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1572,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN ito.value_numeric=1 THEN 163266
	WHEN ito.value_numeric=2 THEN 1501
	WHEN ito.value_numeric=4 THEN 1502
	WHEN ito.value_numeric=8 THEN 5622
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=71282;
		/*End migration for Lieu Accouchement :*/
	/*Start migration for Si accouchement à domicile, assisté par Matrone :*/	
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1573,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN ito.value_numeric=1 THEN 1578
	WHEN ito.value_numeric=2 THEN 1107
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=7823;
	/*End migration for Si accouchement à domicile, assisté par Matrone :*/	
	/*Start migration for Vaginal :*/	
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1170,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN ito.value_numeric=1 THEN 1065
	WHEN ito.value_numeric=2 THEN 1066
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=71137;
	/*End migration for Vaginal :*/	
	/*Start migration for Forceps :*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159901,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN ito.value_numeric=1 THEN 1065
	WHEN ito.value_numeric=2 THEN 1066
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=70524;
	/*End migration for Forceps :*/
	/*Start migration for Vacuum :*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159902,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN ito.value_numeric=1 THEN 1065
	WHEN ito.value_numeric=2 THEN 1066
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=7822;
	/*End migration for Vacuum :*/
	/*Start migration for Ligature tardive du cordon : (A Corriger dans eclipse)*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163450,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN ito.value_numeric=1 THEN 1065
	WHEN ito.value_numeric=2 THEN 1066
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=71283;
	/*End migration for Ligature tardive du cordon :*/
	/*Start migration for Délivrance :*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163453,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN ito.value_numeric=1 THEN 163451
	WHEN ito.value_numeric=2 THEN 163452
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=7824;
	/*End migration for Délivrance :*/
	/*Start migration for Placenta :*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163454,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN ito.value_numeric=1 THEN 163455
	WHEN ito.value_numeric=2 THEN 163456
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=7827;
	/*End migration for Placenta :*/
	/*Start migration for Membranes complètes : */
	/*End migration for Membranes complètes : */
	
	/*Start migration for Rétention placentaire : */
	
	/*End migration for Rétention placentaire : */
	
	/*Start migration for Lacération du périnée :*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,160084,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN ito.value_numeric=1 THEN 112253
	WHEN ito.value_numeric=2 THEN 1115
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=7825;
	/*End migration for Lacération du périnée :*/
	/*Start migration for Si oui Réparation :*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163457,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN ito.value_numeric=1 THEN 1065
	WHEN ito.value_numeric=2 THEN 1066
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=7826;
	/*End migration for Si oui Réparation :*/
	/*Start migration for Césarienne :*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,5630,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,1171,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=7820
	AND ito.value_numeric=2;
	/*End migration for Césarienne : Indication = 70519*/
	/*Start migration for Section Césarienne + Hystérectomie*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,5630,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,161848,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id 
	AND ito.concept_id=7820
	AND ito.value_numeric=4;
	/*End migration for Section Césarienne + Hystérectomie*/
	/*Start migration for Counseling sur la Nutrition du Nouveau-né :*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161070,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN ito.value_numeric=1 THEN 1065
	WHEN ito.value_numeric=2 THEN 1066
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=7835;
	/*End migration for Counseling sur la Nutrition du Nouveau-né :*/
	
	/*End migration for Accouchement part*/
	
	/*Start migration for Prophylaxie ARV Nouveau-né :*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,5665,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN ito.value_numeric=1 THEN 1065
	WHEN ito.value_numeric=2 THEN 1066
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=70528;
	/*End migration for Prophylaxie ARV Nouveau-né :*/
	/*Start migration for TABLEAU DE NAISSANCE Part*/
		/*Start migration for Naissance Vivante (1er)*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159917,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,151849,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=70500
	AND ito.value_numeric=1;
	/*======================================================================================*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159917,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,151849,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=70501
	AND ito.value_numeric=1;
	/*=====================================================================================*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159917,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,151849,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=70502
	AND ito.value_numeric=1;
	/*=====================================================================================*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159917,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,151849,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=70503
	AND ito.value_numeric=1;
	/*End migration for Naissance Vivante (1er)*/
	/*Start migration for Macérée*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159917,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,135436,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=70500
	AND ito.value_numeric=2;
	/*=============================================================*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159917,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,135436,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=70501
	AND ito.value_numeric=2;
	/*=================================================================*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159917,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,135436,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=70502
	AND ito.value_numeric=2;
	/*=====================================================================*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159917,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,135436,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=70503
	AND ito.value_numeric=2;
	/*End migration for Macérée*/
	/*Start migration for Mort Foetale Non Macérée*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159917,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,159916,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=70500
	AND ito.value_numeric=4;
	/*==========================================================================*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159917,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,159916,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=70501
	AND ito.value_numeric=4;
	/*========================================================================*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159917,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,159916,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=70502
	AND ito.value_numeric=4;
	/*=========================================================================*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159917,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,159916,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=70503
	AND ito.value_numeric=4;
	/*End migration for Mort Foetale Non Macérée*/
	/*Start migration for Date et Heure*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_datetime,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,5599,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,ito.value_datetime,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=71284;
	/*=======================================================================*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_datetime,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,5599,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,ito.value_datetime,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=71285;
	/*======================================================================*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_datetime,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,5599,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,ito.value_datetime,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=71286;
	/*========================================================================*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_datetime,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,5599,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,ito.value_datetime,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=71287;
	/*End migration for Date et Heure*/
	/*Start migration for Mort Néonatale*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159917,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,154223,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=70500
	AND ito.value_numeric=8;
	/*===================================================================*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159917,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,154223,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=70501
	AND ito.value_numeric=8;
	/*====================================================================*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159917,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,154223,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=70502
	AND ito.value_numeric=8;
	/*======================================================================*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159917,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,154223,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=70503
	AND ito.value_numeric=8;
	/*End migration for Mort Néonatale*/
	/*Start migration for APGAR : 1mn-5mn*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159603,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,FindNumericValue(ito.value_text),1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(71046,71048,71050,71052)
	AND FindNumericValue(ito.value_text) > 0;
	
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159604,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,FindNumericValue(ito.value_text),1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(71047,71049,71051,71053)
	AND FindNumericValue(ito.value_text) > 0;
	/*End migration for APGAR : 1mn-5mn*/
	/*Start migration for Poids du (ou des) Nnés :*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,5916,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN itob.value_numeric=1 THEN FindNumericValue(ito.value_text)
	ELSE (FindNumericValue(ito.value_text) * 0.45)
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs itob
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.encounter_id = itob.encounter_id
	AND ito.concept_id=70508
	AND itob.concept_id=70512
	AND FindNumericValue(ito.value_text) > 0;
	
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,5916,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN itob.value_numeric=1 THEN FindNumericValue(ito.value_text)
	ELSE (FindNumericValue(ito.value_text) * 0.45)
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs itob
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.encounter_id = itob.encounter_id
	AND ito.concept_id=70509
	AND itob.concept_id=70513
	AND FindNumericValue(ito.value_text) > 0;
	
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,5916,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN itob.value_numeric=1 THEN FindNumericValue(ito.value_text)
	ELSE (FindNumericValue(ito.value_text) * 0.45)
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs itob
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.encounter_id = itob.encounter_id
	AND ito.concept_id=70510
	AND itob.concept_id=70514
	AND FindNumericValue(ito.value_text) > 0;
	
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,5916,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN itob.value_numeric=1 THEN FindNumericValue(ito.value_text)
	ELSE (FindNumericValue(ito.value_text) * 0.45)
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs itob
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.encounter_id = itob.encounter_id
	AND ito.concept_id=70511
	AND itob.concept_id=70515
	AND FindNumericValue(ito.value_text) > 0;
	
	/*End migration for Poids du (ou des) Nnés :*/
	/*Start migration for Périmètre cranien et taille :*/
	
	/*End migration for Périmètre cranien et taille :*/
	/*Start migration for Sexe*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1587,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN ito.value_numeric=1 THEN 1534
	WHEN ito.value_numeric=2 THEN 1535
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=70504;
	/*=====================================================*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1587,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN ito.value_numeric=1 THEN 1534
	WHEN ito.value_numeric=2 THEN 1535
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=70505;
	/*======================================================*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1587,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN ito.value_numeric=1 THEN 1534
	WHEN ito.value_numeric=2 THEN 1535
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=70506;
	/*===============================================================*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1587,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN ito.value_numeric=1 THEN 1534
	WHEN ito.value_numeric=2 THEN 1535
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=70507;
	/*End migration for sexe*/
	/*Start migration for Malformation congénitale visible : */
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,143849,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN ito.value_numeric=1 THEN 1065
	WHEN ito.value_numeric=2 THEN 1066
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=71317;
	/*====================================================*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,143849,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN ito.value_numeric=1 THEN 1065
	WHEN ito.value_numeric=2 THEN 1066
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=71320;
	/*=========================================================*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,143849,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN ito.value_numeric=1 THEN 1065
	WHEN ito.value_numeric=2 THEN 1066
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=71323;
	/*=================================================================*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,143849,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN ito.value_numeric=1 THEN 1065
	WHEN ito.value_numeric=2 THEN 1066
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=71326;
	/*End migration for Malformation congénitale visible : */
	/*Start migration for Allaitement maternel 1ere heure*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163459,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN ito.value_numeric=1 THEN 1065
	WHEN ito.value_numeric=2 THEN 1066
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=71318;
	/*=========================================================================*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163459,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN ito.value_numeric=1 THEN 1065
	WHEN ito.value_numeric=2 THEN 1066
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=71321;
	/*============================================================================*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163459,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN ito.value_numeric=1 THEN 1065
	WHEN ito.value_numeric=2 THEN 1066
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=71324;
	/*=========================================================================================*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163459,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN ito.value_numeric=1 THEN 1065
	WHEN ito.value_numeric=2 THEN 1066
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=71327;
	/*End migration for Allaitement maternel 1ere heure*/
	/*End migration for TABLEAU DE NAISSANCE Part*/
	/*Start migration for SIGNES VITAUX A L'ADMISSION Part*/
		/*Start migration for TA*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,5085,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN itob.value_numeric=1 THEN FindNumericValue(ito.value_text)
	ELSE (FindNumericValue(ito.value_text) * 0.09)
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs itob
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.encounter_id = itob.encounter_id
	AND ito.concept_id=7840
	AND itob.concept_id=7841
	AND FindNumericValue(ito.value_text) > 0;
	
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,5086,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN itob.value_numeric=1 THEN FindNumericValue(ito.value_text)
	ELSE (FindNumericValue(ito.value_text) * 0.09)
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs itob
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.encounter_id = itob.encounter_id
	AND ito.concept_id=7797
	AND itob.concept_id=7841
	AND FindNumericValue(ito.value_text) > 0;
		/*End migration for TA*/
		/*Start migration for Pouls*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,5087,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,FindNumericValue(ito.value_text),1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=7838
	AND FindNumericValue(ito.value_text) > 0;
		/*End migration for Pouls*/
		/*Start migration for FR*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,5242,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,FindNumericValue(ito.value_text),1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=7839
	AND FindNumericValue(ito.value_text) > 0;
		/*End migration for FR*/
		/*Start migration for Temp*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,5088,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN itob.value_numeric=1 THEN FindNumericValue(ito.value_text)
	WHEN itob.value_numeric=2 THEN ((5/9)*(FindNumericValue(ito.value_text) -32)) /*C = 5/9(F - 32)*/
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs itob
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.encounter_id = itob.encounter_id
	AND ito.concept_id=7836
	AND itob.concept_id=7837
	AND FindNumericValue(ito.value_text) > 0;
		/*End migration for Temp*/
		
		
	/*End migration for SIGNES VITAUX A L'ADMISSION Part*/
	/*Start migration for SIGNES VITAUX POST PARTUM ET ETAT DE CONSCIENCE PART*/
		/*Start migration for Date et Heure*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_datetime,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,162869,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,ito.value_datetime,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id IN (70554,70555,70556,70557,70558,70559);
		/*End migration for Date et Heure*/
		/*Start migration for TA*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,5085,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN itob.value_numeric=1 THEN FindNumericValue(ito.value_text)
	ELSE (FindNumericValue(ito.value_text) * 0.09)
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs itob
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.encounter_id = itob.encounter_id
	AND ito.concept_id=7848
	AND itob.concept_id=7849
	AND FindNumericValue(ito.value_text) > 0;
	
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,5086,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN itob.value_numeric=1 THEN FindNumericValue(ito.value_text)
	ELSE (FindNumericValue(ito.value_text) * 0.09)
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs itob
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.encounter_id = itob.encounter_id
	AND ito.concept_id=7798
	AND itob.concept_id=7849
	AND FindNumericValue(ito.value_text) > 0;
	/*============================================================================*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,5085,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN itob.value_numeric=1 THEN FindNumericValue(ito.value_text)
	ELSE (FindNumericValue(ito.value_text) * 0.09)
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs itob
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.encounter_id = itob.encounter_id
	AND ito.concept_id=7856
	AND itob.concept_id=7857
	AND FindNumericValue(ito.value_text) > 0;
	
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,5086,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN itob.value_numeric=1 THEN FindNumericValue(ito.value_text)
	ELSE (FindNumericValue(ito.value_text) * 0.09)
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs itob
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.encounter_id = itob.encounter_id
	AND ito.concept_id=7799
	AND itob.concept_id=7857
	AND FindNumericValue(ito.value_text) > 0;
	/*========================================================================================*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,5085,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN itob.value_numeric=1 THEN FindNumericValue(ito.value_text)
	ELSE (FindNumericValue(ito.value_text) * 0.09)
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs itob
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.encounter_id = itob.encounter_id
	AND ito.concept_id=70536
	AND itob.concept_id=70544
	AND FindNumericValue(ito.value_text) > 0;
	
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,5086,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN itob.value_numeric=1 THEN FindNumericValue(ito.value_text)
	ELSE (FindNumericValue(ito.value_text) * 0.09)
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs itob
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.encounter_id = itob.encounter_id
	AND ito.concept_id=70540
	AND itob.concept_id=70544
	AND FindNumericValue(ito.value_text) > 0;
	/*=========================================================================================*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,5085,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN itob.value_numeric=1 THEN FindNumericValue(ito.value_text)
	ELSE (FindNumericValue(ito.value_text) * 0.09)
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs itob
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.encounter_id = itob.encounter_id
	AND ito.concept_id=70537
	AND itob.concept_id=70545
	AND FindNumericValue(ito.value_text) > 0;
	
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,5086,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN itob.value_numeric=1 THEN FindNumericValue(ito.value_text)
	ELSE (FindNumericValue(ito.value_text) * 0.09)
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs itob
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.encounter_id = itob.encounter_id
	AND ito.concept_id=70541
	AND itob.concept_id=70545
	AND FindNumericValue(ito.value_text) > 0;
	/*==========================================================================================*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,5085,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN itob.value_numeric=1 THEN FindNumericValue(ito.value_text)
	ELSE (FindNumericValue(ito.value_text) * 0.09)
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs itob
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.encounter_id = itob.encounter_id
	AND ito.concept_id=70538
	AND itob.concept_id=70546
	AND FindNumericValue(ito.value_text) > 0;
	
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,5086,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN itob.value_numeric=1 THEN FindNumericValue(ito.value_text)
	ELSE (FindNumericValue(ito.value_text) * 0.09)
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs itob
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.encounter_id = itob.encounter_id
	AND ito.concept_id=70542
	AND itob.concept_id=70546
	AND FindNumericValue(ito.value_text) > 0;
	/*=====================================================================================*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,5085,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN itob.value_numeric=1 THEN FindNumericValue(ito.value_text)
	ELSE (FindNumericValue(ito.value_text) * 0.09)
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs itob
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.encounter_id = itob.encounter_id
	AND ito.concept_id=70539
	AND itob.concept_id=70547
	AND FindNumericValue(ito.value_text) > 0;
	
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,5086,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN itob.value_numeric=1 THEN FindNumericValue(ito.value_text)
	ELSE (FindNumericValue(ito.value_text) * 0.09)
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs itob
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.encounter_id = itob.encounter_id
	AND ito.concept_id=70543
	AND itob.concept_id=70547
	AND FindNumericValue(ito.value_text) > 0;
		/*End migration for TA*/
		/*Start migration for Pouls*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,5087,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,FindNumericValue(ito.value_text),1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(7846,7854,70560,70561,70562,70563)
	AND FindNumericValue(ito.value_text) > 0;
		/*End migration for Pouls*/
		/*Start migration for FR*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,5242,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,FindNumericValue(ito.value_text),1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(7847,7855,70564,70565,70566,70567)
	AND FindNumericValue(ito.value_text) > 0;
		/*End migration for FR*/
		/*Start migration for Température*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,5088,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN itob.value_numeric=1 THEN FindNumericValue(ito.value_text)
	WHEN itob.value_numeric=2 THEN ((5/9) * (FindNumericValue(ito.value_text) -32)) /*C = 5/9(F - 32)*/
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs itob
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.encounter_id = itob.encounter_id
	AND ito.concept_id=7844
	AND itob.concept_id=7845
	AND FindNumericValue(ito.value_text) > 0;
	
	/*=========================================*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,5088,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN itob.value_numeric=1 THEN FindNumericValue(ito.value_text)
	WHEN itob.value_numeric=2 THEN ((5/9) * (FindNumericValue(ito.value_text) -32)) /*C = 5/9(F - 32)*/
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs itob
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.encounter_id = itob.encounter_id
	AND ito.concept_id=7852
	AND itob.concept_id=7853
	AND FindNumericValue(ito.value_text) > 0;
	/*=============================================================*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,5088,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN itob.value_numeric=1 THEN FindNumericValue(ito.value_text)
	WHEN itob.value_numeric=2 THEN ((5/9) * (FindNumericValue(ito.value_text) -32)) /*C = 5/9(F - 32)*/
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs itob
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.encounter_id = itob.encounter_id
	AND ito.concept_id=70568
	AND itob.concept_id=70572
	AND FindNumericValue(ito.value_text) > 0;
	/*==================================================*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,5088,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN itob.value_numeric=1 THEN FindNumericValue(ito.value_text)
	WHEN itob.value_numeric=2 THEN ((5/9) * (FindNumericValue(ito.value_text) -32)) /*C = 5/9(F - 32)*/
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs itob
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.encounter_id = itob.encounter_id
	AND ito.concept_id=70569
	AND itob.concept_id=70573
	AND FindNumericValue(ito.value_text) > 0;
	/*===============================================*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,5088,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN itob.value_numeric=1 THEN FindNumericValue(ito.value_text)
	WHEN itob.value_numeric=2 THEN ((5/9) * (FindNumericValue(ito.value_text) -32)) /*C = 5/9(F - 32)*/
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs itob
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.encounter_id = itob.encounter_id
	AND ito.concept_id=70570
	AND itob.concept_id=70574
	AND FindNumericValue(ito.value_text) > 0;
	/*==============================================================*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,5088,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN itob.value_numeric=1 THEN FindNumericValue(ito.value_text)
	WHEN itob.value_numeric=2 THEN ((5/9) * (FindNumericValue(ito.value_text) -32)) /*C = 5/9(F - 32)*/
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs itob
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.encounter_id = itob.encounter_id
	AND ito.concept_id=70571
	AND itob.concept_id=70575
	AND FindNumericValue(ito.value_text) > 0;
		/*End migration for Température*/
		/*Start migration for Conscience*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		comments,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,162643,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,160282,ito.value_text,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70548,70549,70550,70551,70552,70553);
		/*End migration for Conscience*/
		/*Start migration for Globe Sec.*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		comments,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,132846,ito.value_text,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(71291,71292,71293,71294,71295,71296);
		/*End migration for Globe Sec.*/
	/*End migration for SIGNES VITAUX POST PARTUM ET ETAT DE CONSCIENCE PART*/
	/*Start migration for EVOLUTION MERE Part*/
		/*Start migration for Référée en suites de couche*/
		/*AND Start migration for Référée en pathologie pour:*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161630,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN ito.value_numeric=1 THEN 1623
	WHEN ito.value_numeric=2 THEN 161625
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=70521
	AND (ito.value_numeric=1 OR ito.value_numeric=2);
		/*End migration for Référée en suites de couche*/
		/*AND End migration for Référée en pathologie pour:*/
		/*Start migration for HTA,Hémorragie,Infection,Post op,Cardiomyopathie,Autre*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1887,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN ito.value_numeric=1 THEN 117399
	WHEN ito.value_numeric=2 THEN 230
	WHEN ito.value_numeric=4 THEN 121262
	WHEN ito.value_numeric=8 THEN 159007
	WHEN ito.value_numeric=16 THEN 5016
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=71297;
		/*End migration for HTA,Hémorragie,Infection,Post op,Cardiomyopathie,Autre*/
		/*Start migration for autre*/
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	comments,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1887,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,5622,ito.value_text,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=71298;
		/*End migration for autre*/
		/*Start migration for Exéatée,Décédée,Autre*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,160433,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN ito.value_numeric=4 THEN 1692
	WHEN ito.value_numeric=8 THEN 159
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=70521
	AND (ito.value_numeric=4 OR ito.value_numeric=8);
		/*END migration for Exéatée,Décédée,Autre*/
		/*Start migration for autre*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	comments,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,160433,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,5622,ito.value_text,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=70522
	AND (ito.value_text<>"" AND ito.value_text is not null);
		/*End migration for autre*/
		/*Start migration for Choix d'une méthode contraceptive?*/
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	comments,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,374,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN ito.value_numeric=1 THEN 162332
	WHEN ito.value_numeric=2 THEN 1175
	END,
	CASE WHEN (ito.value_numeric=1 AND itob.concept_id=71300) THEN itob.value_text
	END,
	1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito LEFT OUTER JOIN itech.obs itob
	ON ito.encounter_id=itob.encounter_id
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=71299
	AND (ito.value_numeric=1 OR ito.value_numeric=2);
		/*End migration for Choix d'une méthode contraceptive?*/
	/*End migration for EVOLUTION MERE Part*/
	/*Start migration for EVOLUTION NOUVEAU NE 1 PART*/
		/*Start migration Référée à la pouponnière ou en suites de couche avec sa maman/
		Référée en pédiatrie pour: */
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161630,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN ito.value_numeric=1 THEN 1623
	WHEN ito.value_numeric=2 THEN 160537
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=71301
	AND (ito.value_numeric=1 OR ito.value_numeric=2);
		/*End migration for Référée à la pouponnière ou en suites de couche avec sa maman*/
		/*AND Référée en pédiatrie pour: */
	    /*Start migration for Détresse respiratoire,Suspicion d'infection materno-foetale,Prématurité,Autre*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1887,c.encounter_id,
		CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
		WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
		WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
		END,c.location_id,
		CASE WHEN ito.value_numeric=1 THEN 130497
		WHEN ito.value_numeric=2 THEN 140343
		WHEN ito.value_numeric=8 THEN 159908
		END,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.obs ito
		WHERE c.uuid = e.encGuid and 
		e.patientID = ito.person_id and e.siteCode = ito.location_id 
		and e.encounter_id = ito.encounter_id
		AND ito.concept_id=71303;
		/*End migration for Détresse respiratoire,Suspicion d'infection materno-foetale,Prématurité,Autre*/
		/*Start migration for autre*/
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	comments,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1887,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,5622,ito.value_text,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=71304;
		/*End migration for autre*/
		
		/*Start migration for Exéatée,Décédée,Autre*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,160433,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN ito.value_numeric=4 THEN 1692
	WHEN ito.value_numeric=8 THEN 159
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=71301
	AND (ito.value_numeric=4 OR ito.value_numeric=8);
		/*ENd migration for Exéatée,Décédée,Autre*/
		/*Start migration for autre*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	comments,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,160433,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,5622,ito.value_text,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=71302
	AND (ito.value_text<>"" AND ito.value_text is not null);
		/*End migration for autre*/
	   /*Start migration for Méthode d'alimentation choisie à la sortie :*/
		   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1151,c.encounter_id,
		CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
		WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
		WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
		END,c.location_id,
		CASE WHEN ito.value_numeric=1 THEN 5526
		WHEN ito.value_numeric=2 THEN 5254
		WHEN ito.value_numeric=4 THEN 6046
		END,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.obs ito
		WHERE c.uuid = e.encGuid 
		AND e.siteCode = ito.location_id 
		AND e.encounter_id = ito.encounter_id
		AND ito.concept_id=71305
		AND (ito.value_numeric=1 OR ito.value_numeric=2 OR ito.value_numeric=4);
	   /*End migration for Méthode d'alimentation choisie à la sortie :*/
	/*End migration for EVOLUTION NOUVEAU NE 1 Part*/
	/*Start migration for EVOLUTION NOUVEAU NE 2 Part*/
		/*Start migration for Référée à la pouponnière ou en suites de couche avec sa maman*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161630,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN ito.value_numeric=1 THEN 1623
	WHEN ito.value_numeric=2 THEN 160537
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=71306
	AND (ito.value_numeric=1 OR ito.value_numeric=2);
		/*End migration for Référée à la pouponnière ou en suites de couche avec sa maman*/
		/*AND Référée en pédiatrie pour: */
	    /*Start migration for Détresse respiratoire,Suspicion d'infection materno-foetale,Prématurité,Autre*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1887,c.encounter_id,
		CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
		WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
		WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
		END,c.location_id,
		CASE WHEN ito.value_numeric=1 THEN 130497
		WHEN ito.value_numeric=2 THEN 140343
		WHEN ito.value_numeric=8 THEN 159908
		END,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.obs ito
		WHERE c.uuid = e.encGuid and 
		e.patientID = ito.person_id and e.siteCode = ito.location_id 
		and e.encounter_id = ito.encounter_id
		AND ito.concept_id=71308;
		/*End migration for Détresse respiratoire,Suspicion d'infection materno-foetale,Prématurité,Autre*/
		/*Start migration for autre*/
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	comments,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1887,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,5622,ito.value_text,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=71309;
		/*End migration for autre*/
		
		/*Start migration for Exéatée,Décédée,Autre*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,160433,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN ito.value_numeric=4 THEN 1692
	WHEN ito.value_numeric=8 THEN 159
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=71306
	AND (ito.value_numeric=4 OR ito.value_numeric=8);
		/*ENd migration for Exéatée,Décédée,Autre*/
		/*Start migration for autre*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	comments,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,160433,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,5622,ito.value_text,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=71307
	AND (ito.value_text<>"" AND ito.value_text is not null);
		/*End migration for autre*/
	   /*Start migration for Méthode d'alimentation choisie à la sortie :*/
		   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1151,c.encounter_id,
		CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
		WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
		WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
		END,c.location_id,
		CASE WHEN ito.value_numeric=1 THEN 5526
		WHEN ito.value_numeric=2 THEN 5254
		WHEN ito.value_numeric=4 THEN 6046
		END,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.obs ito
		WHERE c.uuid = e.encGuid 
		AND e.siteCode = ito.location_id 
		AND e.encounter_id = ito.encounter_id
		AND ito.concept_id=71310
		AND (ito.value_numeric=1 OR ito.value_numeric=2 OR ito.value_numeric=4);
	/*End migration for EVOLUTION NOUVEAU NE 2 Part*/
	/*Start migration for EVOLUTION NOUVEAU NE 3 PART*/
		/*Start migration for Référée à la pouponnière ou en suites de couche avec sa maman*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161630,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN ito.value_numeric=1 THEN 1623
	WHEN ito.value_numeric=2 THEN 160537
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=71311
	AND (ito.value_numeric=1 OR ito.value_numeric=2);
		/*End migration for Référée à la pouponnière ou en suites de couche avec sa maman*/
		/*AND Référée en pédiatrie pour: */
	    /*Start migration for Détresse respiratoire,Suspicion d'infection materno-foetale,Prématurité,Autre*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1887,c.encounter_id,
		CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
		WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
		WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
		END,c.location_id,
		CASE WHEN ito.value_numeric=1 THEN 130497
		WHEN ito.value_numeric=2 THEN 140343
		WHEN ito.value_numeric=8 THEN 159908
		END,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.obs ito
		WHERE c.uuid = e.encGuid and 
		e.patientID = ito.person_id and e.siteCode = ito.location_id 
		and e.encounter_id = ito.encounter_id
		AND ito.concept_id=71313;
		/*End migration for Détresse respiratoire,Suspicion d'infection materno-foetale,Prématurité,Autre*/
		/*Start migration for autre*/
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	comments,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1887,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,5622,ito.value_text,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=71314;
		/*End migration for autre*/
		
		/*Start migration for Exéatée,Décédée,Autre*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,160433,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN ito.value_numeric=4 THEN 1692
	WHEN ito.value_numeric=8 THEN 159
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=71311
	AND (ito.value_numeric=4 OR ito.value_numeric=8);
		/*ENd migration for Exéatée,Décédée,Autre*/
		/*Start migration for autre*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	comments,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,160433,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,5622,ito.value_text,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid  and e.siteCode = ito.location_id 
	and e.encounter_id = ito.encounter_id
	AND ito.concept_id=71312
	AND (ito.value_text<>"" AND ito.value_text is not null);
		/*End migration for autre*/
	   /*Start migration for Méthode d'alimentation choisie à la sortie :*/
		   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1151,c.encounter_id,
		CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
		WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
		WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
		END,c.location_id,
		CASE WHEN ito.value_numeric=1 THEN 5526
		WHEN ito.value_numeric=2 THEN 5254
		WHEN ito.value_numeric=4 THEN 6046
		END,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.obs ito
		WHERE c.uuid = e.encGuid 
		AND e.siteCode = ito.location_id 
		AND e.encounter_id = ito.encounter_id
		AND ito.concept_id=71315
		AND (ito.value_numeric=1 OR ito.value_numeric=2 OR ito.value_numeric=4);
	/*End migration for EVOLUTION NOUVEAU NE 3 PART*/
	/*Start migration for dernier commentaire*/
	   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_text,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,161011,c.encounter_id,
		CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
		WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
		WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
		END,c.location_id,e.encComments,1,e.createDate, UUID()
		from encounter c, itech.encounter e
		WHERE c.uuid = e.encGuid
		AND (e.encComments<>"" AND e.encComments is not null)
		AND e.encounterType=26;
	/*End migraion for dernier commentaire*/
	
	/*End migration for Travailleur Accouchement Form*/
	
END$$
	DELIMITER ;
	call travailAccMigration();