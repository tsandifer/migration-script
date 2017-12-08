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
DROP PROCEDURE IF EXISTS adherenceMigration$$
CREATE PROCEDURE adherenceMigration()
BEGIN
	 /*Delete all inserted discontinuations data if the script fail*/
	 SET SQL_SAFE_UPDATES = 0;
	 SET FOREIGN_KEY_CHECKS=0;
	 DELETE FROM obs WHERE encounter_id IN
	 (
		SELECT en.encounter_id FROM encounter en, encounter_type ent
		WHERE en.encounter_type=ent.encounter_type_id
		AND ent.uuid='c45d7299-ad08-4cb5-8e5d-e0ce40532939'
	 );
	  SET SQL_SAFE_UPDATES = 1;
	  SET FOREIGN_KEY_CHECKS=1;
	/*Start migration for Évaluation faite par: */ 
        /*Start migration for Médecin */	
	    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163556,c.encounter_id,
		CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
		WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
		WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
		END,c.location_id,162591,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.adherenceCounseling ac
		WHERE c.uuid = e.encGuid 
		AND e.siteCode = ac.siteCode
		AND e.patientID = ac.patientID
		AND concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd) =
		concat(ac.visitDateYy,"-",ac.visitDateMm,"-",ac.visitDateDd)
		AND ac.evaluationDoctor=1;
		/*Pharmacien/Dispensateur*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163556,c.encounter_id,
		CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
		WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
		WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
		END,c.location_id,163557,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.adherenceCounseling ac
		WHERE c.uuid = e.encGuid 
		AND e.siteCode = ac.siteCode
		AND e.patientID = ac.patientID
		AND concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd) =
		concat(ac.visitDateYy,"-",ac.visitDateMm,"-",ac.visitDateDd)
		AND ac.evaluationPharmacien=1;
		/*Infirmière */
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163556,c.encounter_id,
		CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
		WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
		WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
		END,c.location_id,1577,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.adherenceCounseling ac
		WHERE c.uuid = e.encGuid 
		AND e.siteCode = ac.siteCode
		AND e.patientID = ac.patientID
		AND concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd) =
		concat(ac.visitDateYy,"-",ac.visitDateMm,"-",ac.visitDateDd)
		AND ac.evaluationNurse=1;
		/*Travailleur social/Psychologue */
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163556,c.encounter_id,
		CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
		WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
		WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
		END,c.location_id,163558,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.adherenceCounseling ac
		WHERE c.uuid = e.encGuid 
		AND e.siteCode = ac.siteCode
		AND e.patientID = ac.patientID
		AND concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd) =
		concat(ac.visitDateYy,"-",ac.visitDateMm,"-",ac.visitDateDd)
		AND ac.evaluationSocialWorker=1;
		/* Agent de santé communautaire/accompagnateur*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163556,c.encounter_id,
		CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
		WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
		WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
		END,c.location_id,1555,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.adherenceCounseling ac
		WHERE c.uuid = e.encGuid 
		AND e.siteCode = ac.siteCode
		AND e.patientID = ac.patientID
		AND concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd) =
		concat(ac.visitDateYy,"-",ac.visitDateMm,"-",ac.visitDateDd)
		AND ac.evaluationAgent=1;
		/*Autre, préciser:*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163556,c.encounter_id,
		CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
		WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
		WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
		END,c.location_id,5622,ac.evaluationOtherText,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.adherenceCounseling ac
		WHERE c.uuid = e.encGuid 
		AND e.siteCode = ac.siteCode
		AND e.patientID = ac.patientID
		AND concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd) =
		concat(ac.visitDateYy,"-",ac.visitDateMm,"-",ac.visitDateDd)
		AND ac.evaluationOther=1;
	/*End migration for Évaluation faite par: */
	/*Start migration for Adhérence:
	Durant les 4 derniers jours, combien de doses du médicament le patient a-t-il-manqué?*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163709,c.encounter_id,
		CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
		WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
		WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
		END,c.location_id,
		CASE WHEN ac.missedDoses=1 THEN 0
		WHEN ac.missedDoses=2 THEN 1
		WHEN ac.missedDoses=4 THEN 2
		WHEN ac.missedDoses=8 THEN 3
		WHEN ac.missedDoses=16 THEN 4
		END,1,e.createDate, UUID()
		from encounter c, itech.encounter e,itech.adherenceCounseling ac
		WHERE c.uuid = e.encGuid 
		AND e.siteCode = ac.siteCode
		AND e.patientID = ac.patientID
		AND concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd) =
		concat(ac.visitDateYy,"-",ac.visitDateMm,"-",ac.visitDateDd)
		AND ac.missedDoses IN(1,2,4,8,16) ;
	/*End migration for Adhérence:
	Durant les 4 derniers jours, combien de doses du médicament le patient a-t-il-manqué?*/
	/*Start migration for Quel pourcentage de doses le patient a-t-il pris le mois dernier ? */
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163710,c.encounter_id,
		CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
		WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
		WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
		END,c.location_id,
		CASE WHEN ac.doseProp=1 THEN 0
		WHEN ac.doseProp=2 THEN 10
		WHEN ac.doseProp=4 THEN 20
		WHEN ac.doseProp=8 THEN 30
		WHEN ac.doseProp=16 THEN 40
		WHEN ac.doseProp=32 THEN 50
		WHEN ac.doseProp=64 THEN 60
		WHEN ac.doseProp=128 THEN 70
		WHEN ac.doseProp=256 THEN 80
		WHEN ac.doseProp=512 THEN 90
		WHEN ac.doseProp=1024 THEN 100
		END,1,e.createDate, UUID()
		from encounter c, itech.encounter e,itech.adherenceCounseling ac
		WHERE c.uuid = e.encGuid 
		AND e.siteCode = ac.siteCode
		AND e.patientID = ac.patientID
		AND concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd) =
		concat(ac.visitDateYy,"-",ac.visitDateMm,"-",ac.visitDateDd)
		AND ac.missedDoses IN(1,2,4,8,16,32,64,128,256,512,1024) ;
		/*End migration for Quel pourcentage de doses le patient a-t-il pris le mois dernier ?*/
		/*Start migration for Raison donnée pour avoir manqué une dose, cocher le ou les cas ci-dessous*/
		/*Médicament non-disponible à la clinique*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,160582,c.encounter_id,
		CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
		WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
		WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
		END,c.location_id,1754,1,e.createDate, UUID()
		from encounter c, itech.encounter e,itech.adherenceCounseling ac
		WHERE c.uuid = e.encGuid 
		AND e.siteCode = ac.siteCode
		AND e.patientID = ac.patientID
		AND concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd) =
		concat(ac.visitDateYy,"-",ac.visitDateMm,"-",ac.visitDateDd)
		AND ac.reasonNotAvail=1;
		/*A oublié*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,160582,c.encounter_id,
		CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
		WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
		WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
		END,c.location_id,160587,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.adherenceCounseling ac
		WHERE c.uuid = e.encGuid 
		AND e.siteCode = ac.siteCode
		AND e.patientID = ac.patientID
		AND concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd) =
		concat(ac.visitDateYy,"-",ac.visitDateMm,"-",ac.visitDateDd)
		AND ac.reasonForgot=1;
		/*Effets secondaires, préciser ci-dessous*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,160582,c.encounter_id,
		CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
		WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
		WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
		END,c.location_id,1778,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.adherenceCounseling ac
		WHERE c.uuid = e.encGuid 
		AND e.siteCode = ac.siteCode
		AND e.patientID = ac.patientID
		AND concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd) =
		concat(ac.visitDateYy,"-",ac.visitDateMm,"-",ac.visitDateDd)
		AND ac.reasonSideEff=1;
		/*Emprisonné*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,160582,c.encounter_id,
		CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
		WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
		WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
		END,c.location_id,156761,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.adherenceCounseling ac
		WHERE c.uuid = e.encGuid 
		AND e.siteCode = ac.siteCode
		AND e.patientID = ac.patientID
		AND concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd) =
		concat(ac.visitDateYy,"-",ac.visitDateMm,"-",ac.visitDateDd)
		AND ac.reasonPrison=1;
		/*S'est senti trop malade*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,160582,c.encounter_id,
		CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
		WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
		WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
		END,c.location_id,160585,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.adherenceCounseling ac
		WHERE c.uuid = e.encGuid 
		AND e.siteCode = ac.siteCode
		AND e.patientID = ac.patientID
		AND concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd) =
		concat(ac.visitDateYy,"-",ac.visitDateMm,"-",ac.visitDateDd)
		AND ac.reasonTooSick=1;
		/*A terminé tous les médicaments*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,160582,c.encounter_id,
		CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
		WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
		WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
		END,c.location_id,1775,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.adherenceCounseling ac
		WHERE c.uuid = e.encGuid 
		AND e.siteCode = ac.siteCode
		AND e.patientID = ac.patientID
		AND concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd) =
		concat(ac.visitDateYy,"-",ac.visitDateMm,"-",ac.visitDateDd)
		AND ac.reasonFinished=1;
		/*S'est senti bien*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,160582,c.encounter_id,
		CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
		WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
		WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
		END,c.location_id,160586,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.adherenceCounseling ac
		WHERE c.uuid = e.encGuid 
		AND e.siteCode = ac.siteCode
		AND e.patientID = ac.patientID
		AND concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd) =
		concat(ac.visitDateYy,"-",ac.visitDateMm,"-",ac.visitDateDd)
		AND ac.reasonFeelWell=1;
		/*A perdu les pilules*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,160582,c.encounter_id,
		CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
		WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
		WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
		END,c.location_id,160584,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.adherenceCounseling ac
		WHERE c.uuid = e.encGuid 
		AND e.siteCode = ac.siteCode
		AND e.patientID = ac.patientID
		AND concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd) =
		concat(ac.visitDateYy,"-",ac.visitDateMm,"-",ac.visitDateDd)
		AND ac.reasonLost=1;
		/*N'a pas voulu*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,160582,c.encounter_id,
		CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
		WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
		WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
		END,c.location_id,127750,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.adherenceCounseling ac
		WHERE c.uuid = e.encGuid 
		AND e.siteCode = ac.siteCode
		AND e.patientID = ac.patientID
		AND concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd) =
		concat(ac.visitDateYy,"-",ac.visitDateMm,"-",ac.visitDateDd)
		AND ac.reasonDidNotWant=1;
		/*Gêné de prendre des médicaments en présence d'autres personnes*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,160582,c.encounter_id,
		CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
		WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
		WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
		END,c.location_id,160589,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.adherenceCounseling ac
		WHERE c.uuid = e.encGuid 
		AND e.siteCode = ac.siteCode
		AND e.patientID = ac.patientID
		AND concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd) =
		concat(ac.visitDateYy,"-",ac.visitDateMm,"-",ac.visitDateDd)
		AND ac.reasonNotComf=1;
		/*Difficultés à avaler*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,160582,c.encounter_id,
		CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
		WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
		WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
		END,c.location_id,5954,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.adherenceCounseling ac
		WHERE c.uuid = e.encGuid 
		AND e.siteCode = ac.siteCode
		AND e.patientID = ac.patientID
		AND concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd) =
		concat(ac.visitDateYy,"-",ac.visitDateMm,"-",ac.visitDateDd)
		AND ac.reasonNoSwallow=1;
		/*En voyage*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,160582,c.encounter_id,
		CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
		WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
		WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
		END,c.location_id,124153,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.adherenceCounseling ac
		WHERE c.uuid = e.encGuid 
		AND e.siteCode = ac.siteCode
		AND e.patientID = ac.patientID
		AND concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd) =
		concat(ac.visitDateYy,"-",ac.visitDateMm,"-",ac.visitDateDd)
		AND ac.reasonTravel=1;
		/*Manque de nourriture*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,160582,c.encounter_id,
		CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
		WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
		WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
		END,c.location_id,119533,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.adherenceCounseling ac
		WHERE c.uuid = e.encGuid 
		AND e.siteCode = ac.siteCode
		AND e.patientID = ac.patientID
		AND concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd) =
		concat(ac.visitDateYy,"-",ac.visitDateMm,"-",ac.visitDateDd)
		AND ac.reasonNoFood=1;
		/*Autres, préciser :*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		comments,creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,160582,c.encounter_id,
		CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
		WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
		WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
		END,c.location_id,5622,ac.reasonOtherText,1,e.createDate, UUID()
		from encounter c, itech.encounter e,itech.adherenceCounseling ac
		WHERE c.uuid = e.encGuid 
		AND e.siteCode = ac.siteCode
		AND e.patientID = ac.patientID
		AND concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd) =
		concat(ac.visitDateYy,"-",ac.visitDateMm,"-",ac.visitDateDd)
		AND ac.reasonOther=1;
		/*Start migration for EFFETS SECONDAIRES*/
		/*Create table obs_concept_group for the obs_group_id*/
	create table if not exists itech.obs_concept_group (obs_id int,person_id int,concept_id int,encounter_id int);

	/*Migration for the concept question of Nausée ou vomissement*/
	 /*Migration for obsgroup of Nausée ou vomissement*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161879,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM encounter c, itech.encounter e, itech.adherenceCounseling ac 
	WHERE c.uuid = e.encGuid 
	AND e.patientID = ac.patientID 
	AND e.siteCode = ac.siteCode
	AND concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd) =
		concat(ac.visitDateYy,"-",ac.visitDateMm,"-",ac.visitDateDd)
	AND(ac.sideNausea=1 OR ac.sideNausea=2 OR ac.sideNausea=4);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=161879 
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,159935,c.encounter_id,
		CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
		WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
		WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
		END,c.location_id,cg.obs_id,133473,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.adherenceCounseling ac, itech.obs_concept_group cg
		WHERE c.uuid = e.encGuid 
		AND e.siteCode = ac.siteCode
		AND e.patientID = ac.patientID
		AND c.encounter_id=cg.encounter_id
		AND c.patient_id=cg.person_id
		AND concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd) =
		concat(ac.visitDateYy,"-",ac.visitDateMm,"-",ac.visitDateDd)
		AND(ac.sideNausea=1 OR ac.sideNausea=2 OR ac.sideNausea=4);
		/*=====================================================================*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,162760,c.encounter_id,
		CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
		WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
		WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
		END,c.location_id,cg.obs_id,
		CASE WHEN ac.sideNausea=1 THEN 1498
		WHEN ac.sideNausea=2 THEN 1499
		WHEN ac.sideNausea=4 THEN 1500
		END,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.adherenceCounseling ac, itech.obs_concept_group cg
		WHERE c.uuid = e.encGuid 
		AND e.siteCode = ac.siteCode
		AND e.patientID = ac.patientID
		AND c.encounter_id=cg.encounter_id
		AND c.patient_id=cg.person_id
		AND concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd) =
		concat(ac.visitDateYy,"-",ac.visitDateMm,"-",ac.visitDateDd)
		AND(ac.sideNausea=1 OR ac.sideNausea=2 OR ac.sideNausea=4);
		/*End migration for Nausée ou vomissement*/
		/*Start migration for Diarrhée*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161879,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM encounter c, itech.encounter e, itech.adherenceCounseling ac 
	WHERE c.uuid = e.encGuid 
	AND e.patientID = ac.patientID 
	AND e.siteCode = ac.siteCode
	AND concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd) =
		concat(ac.visitDateYy,"-",ac.visitDateMm,"-",ac.visitDateDd)
	AND(ac.sideDiarrhea=1 OR ac.sideDiarrhea=2 OR ac.sideDiarrhea=4);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=161879 
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,159935,c.encounter_id,
		CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
		WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
		WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
		END,c.location_id,cg.obs_id,142412,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.adherenceCounseling ac, itech.obs_concept_group cg
		WHERE c.uuid = e.encGuid 
		AND e.siteCode = ac.siteCode
		AND e.patientID = ac.patientID
		AND c.encounter_id=cg.encounter_id
		AND c.patient_id=cg.person_id
		AND concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd) =
		concat(ac.visitDateYy,"-",ac.visitDateMm,"-",ac.visitDateDd)
		AND(ac.sideDiarrhea=1 OR ac.sideDiarrhea=2 OR ac.sideDiarrhea=4);
		/*=====================================================================*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,162760,c.encounter_id,
		CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
		WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
		WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
		END,c.location_id,cg.obs_id,
		CASE WHEN ac.sideDiarrhea=1 THEN 1498
		WHEN ac.sideDiarrhea=2 THEN 1499
		WHEN ac.sideDiarrhea=4 THEN 1500
		END,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.adherenceCounseling ac, itech.obs_concept_group cg
		WHERE c.uuid = e.encGuid 
		AND e.siteCode = ac.siteCode
		AND e.patientID = ac.patientID
		AND c.encounter_id=cg.encounter_id
		AND c.patient_id=cg.person_id
		AND concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd) =
		concat(ac.visitDateYy,"-",ac.visitDateMm,"-",ac.visitDateDd)
		AND(ac.sideDiarrhea=1 OR ac.sideDiarrhea=2 OR ac.sideDiarrhea=4);
		/*End migration for Diarrhée*/
		/*Start migration for Eruption cutanée*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161879,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM encounter c, itech.encounter e, itech.adherenceCounseling ac 
	WHERE c.uuid = e.encGuid 
	AND e.patientID = ac.patientID 
	AND e.siteCode = ac.siteCode
	AND concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd) =
		concat(ac.visitDateYy,"-",ac.visitDateMm,"-",ac.visitDateDd)
	AND(ac.sideRash=1 OR ac.sideRash=2 OR ac.sideRash=4);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=161879 
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,159935,c.encounter_id,
		CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
		WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
		WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
		END,c.location_id,cg.obs_id,512,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.adherenceCounseling ac, itech.obs_concept_group cg
		WHERE c.uuid = e.encGuid 
		AND e.siteCode = ac.siteCode
		AND e.patientID = ac.patientID
		AND c.encounter_id=cg.encounter_id
		AND c.patient_id=cg.person_id
		AND concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd) =
		concat(ac.visitDateYy,"-",ac.visitDateMm,"-",ac.visitDateDd)
		AND(ac.sideRash=1 OR ac.sideRash=2 OR ac.sideRash=4);
		/*=====================================================================*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,162760,c.encounter_id,
		CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
		WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
		WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
		END,c.location_id,cg.obs_id,
		CASE WHEN ac.sideRash=1 THEN 1498
		WHEN ac.sideRash=2 THEN 1499
		WHEN ac.sideRash=4 THEN 1500
		END,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.adherenceCounseling ac, itech.obs_concept_group cg
		WHERE c.uuid = e.encGuid 
		AND e.siteCode = ac.siteCode
		AND e.patientID = ac.patientID
		AND c.encounter_id=cg.encounter_id
		AND c.patient_id=cg.person_id
		AND concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd) =
		concat(ac.visitDateYy,"-",ac.visitDateMm,"-",ac.visitDateDd)
		AND(ac.sideRash=1 OR ac.sideRash=2 OR ac.sideRash=4);
		/*End migration for Eruption cutanée*/
		/*Start migration for Maux de tête*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161879,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM encounter c, itech.encounter e, itech.adherenceCounseling ac 
	WHERE c.uuid = e.encGuid 
	AND e.patientID = ac.patientID 
	AND e.siteCode = ac.siteCode
	AND concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd) =
		concat(ac.visitDateYy,"-",ac.visitDateMm,"-",ac.visitDateDd)
	AND(ac.sideHeadache=1 OR ac.sideHeadache=2 OR ac.sideHeadache=4);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=161879 
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,159935,c.encounter_id,
		CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
		WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
		WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
		END,c.location_id,cg.obs_id,139084,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.adherenceCounseling ac, itech.obs_concept_group cg
		WHERE c.uuid = e.encGuid 
		AND e.siteCode = ac.siteCode
		AND e.patientID = ac.patientID
		AND c.encounter_id=cg.encounter_id
		AND c.patient_id=cg.person_id
		AND concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd) =
		concat(ac.visitDateYy,"-",ac.visitDateMm,"-",ac.visitDateDd)
		AND(ac.sideHeadache=1 OR ac.sideHeadache=2 OR ac.sideHeadache=4);
		/*=====================================================================*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,162760,c.encounter_id,
		CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
		WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
		WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
		END,c.location_id,cg.obs_id,
		CASE WHEN ac.sideHeadache=1 THEN 1498
		WHEN ac.sideHeadache=2 THEN 1499
		WHEN ac.sideHeadache=4 THEN 1500
		END,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.adherenceCounseling ac, itech.obs_concept_group cg
		WHERE c.uuid = e.encGuid 
		AND e.siteCode = ac.siteCode
		AND e.patientID = ac.patientID
		AND c.encounter_id=cg.encounter_id
		AND c.patient_id=cg.person_id
		AND concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd) =
		concat(ac.visitDateYy,"-",ac.visitDateMm,"-",ac.visitDateDd)
		AND(ac.sideHeadache=1 OR ac.sideHeadache=2 OR ac.sideHeadache=4);
		/*End migration for Maux de tête*/
		/*Start migration for Douleur abdominale*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161879,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM encounter c, itech.encounter e, itech.adherenceCounseling ac 
	WHERE c.uuid = e.encGuid 
	AND e.patientID = ac.patientID 
	AND e.siteCode = ac.siteCode
	AND concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd) =
		concat(ac.visitDateYy,"-",ac.visitDateMm,"-",ac.visitDateDd)
	AND(ac.sideAbPain=1 OR ac.sideAbPain=2 OR ac.sideAbPain=4);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=161879 
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,159935,c.encounter_id,
		CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
		WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
		WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
		END,c.location_id,cg.obs_id,151,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.adherenceCounseling ac, itech.obs_concept_group cg
		WHERE c.uuid = e.encGuid 
		AND e.siteCode = ac.siteCode
		AND e.patientID = ac.patientID
		AND c.encounter_id=cg.encounter_id
		AND c.patient_id=cg.person_id
		AND concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd) =
		concat(ac.visitDateYy,"-",ac.visitDateMm,"-",ac.visitDateDd)
		AND(ac.sideAbPain=1 OR ac.sideAbPain=2 OR ac.sideAbPain=4);
		/*=====================================================================*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,162760,c.encounter_id,
		CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
		WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
		WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
		END,c.location_id,cg.obs_id,
		CASE WHEN ac.sideAbPain=1 THEN 1498
		WHEN ac.sideAbPain=2 THEN 1499
		WHEN ac.sideAbPain=4 THEN 1500
		END,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.adherenceCounseling ac, itech.obs_concept_group cg
		WHERE c.uuid = e.encGuid 
		AND e.siteCode = ac.siteCode
		AND e.patientID = ac.patientID
		AND c.encounter_id=cg.encounter_id
		AND c.patient_id=cg.person_id
		AND concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd) =
		concat(ac.visitDateYy,"-",ac.visitDateMm,"-",ac.visitDateDd)
		AND(ac.sideAbPain=1 OR ac.sideAbPain=2 OR ac.sideAbPain=4);
		/*End migration for Douleur abdominale*/
		/*Start migration for Faiblesse*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161879,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM encounter c, itech.encounter e, itech.adherenceCounseling ac 
	WHERE c.uuid = e.encGuid 
	AND e.patientID = ac.patientID 
	AND e.siteCode = ac.siteCode
	AND concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd) =
		concat(ac.visitDateYy,"-",ac.visitDateMm,"-",ac.visitDateDd)
	AND(ac.sideWeak=1 OR ac.sideWeak=2 OR ac.sideWeak=4);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=161879 
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,159935,c.encounter_id,
		CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
		WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
		WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
		END,c.location_id,cg.obs_id,5226,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.adherenceCounseling ac, itech.obs_concept_group cg
		WHERE c.uuid = e.encGuid 
		AND e.siteCode = ac.siteCode
		AND e.patientID = ac.patientID
		AND c.encounter_id=cg.encounter_id
		AND c.patient_id=cg.person_id
		AND concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd) =
		concat(ac.visitDateYy,"-",ac.visitDateMm,"-",ac.visitDateDd)
		AND(ac.sideWeak=1 OR ac.sideWeak=2 OR ac.sideWeak=4);
		/*=====================================================================*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,162760,c.encounter_id,
		CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
		WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
		WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
		END,c.location_id,cg.obs_id,
		CASE WHEN ac.sideWeak=1 THEN 1498
		WHEN ac.sideWeak=2 THEN 1499
		WHEN ac.sideWeak=4 THEN 1500
		END,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.adherenceCounseling ac, itech.obs_concept_group cg
		WHERE c.uuid = e.encGuid 
		AND e.siteCode = ac.siteCode
		AND e.patientID = ac.patientID
		AND c.encounter_id=cg.encounter_id
		AND c.patient_id=cg.person_id
		AND concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd) =
		concat(ac.visitDateYy,"-",ac.visitDateMm,"-",ac.visitDateDd)
		AND(ac.sideWeak=1 OR ac.sideWeak=2 OR ac.sideWeak=4);
		/*End migration for Faiblesse*/
		/*Start migration for Paresthésie/fourmillement*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161879,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM encounter c, itech.encounter e, itech.adherenceCounseling ac 
	WHERE c.uuid = e.encGuid 
	AND e.patientID = ac.patientID 
	AND e.siteCode = ac.siteCode
	AND concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd) =
		concat(ac.visitDateYy,"-",ac.visitDateMm,"-",ac.visitDateDd)
	AND(ac.sideNumb=1 OR ac.sideNumb=2 OR ac.sideNumb=4);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=161879 
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,159935,c.encounter_id,
		CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
		WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
		WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
		END,c.location_id,cg.obs_id,6004,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.adherenceCounseling ac, itech.obs_concept_group cg
		WHERE c.uuid = e.encGuid 
		AND e.siteCode = ac.siteCode
		AND e.patientID = ac.patientID
		AND c.encounter_id=cg.encounter_id
		AND c.patient_id=cg.person_id
		AND concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd) =
		concat(ac.visitDateYy,"-",ac.visitDateMm,"-",ac.visitDateDd)
		AND(ac.sideNumb=1 OR ac.sideNumb=2 OR ac.sideNumb=4);
		/*=====================================================================*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,162760,c.encounter_id,
		CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
		WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
		WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
		END,c.location_id,cg.obs_id,
		CASE WHEN ac.sideNumb=1 THEN 1498
		WHEN ac.sideNumb=2 THEN 1499
		WHEN ac.sideNumb=4 THEN 1500
		END,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.adherenceCounseling ac, itech.obs_concept_group cg
		WHERE c.uuid = e.encGuid 
		AND e.siteCode = ac.siteCode
		AND e.patientID = ac.patientID
		AND c.encounter_id=cg.encounter_id
		AND c.patient_id=cg.person_id
		AND concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd) =
		concat(ac.visitDateYy,"-",ac.visitDateMm,"-",ac.visitDateDd)
		AND(ac.sideNumb=1 OR ac.sideNumb=2 OR ac.sideNumb=4);
		/*End migration for Paresthésie/fourmillement*/
		/*Start migration for Autres, préciser :*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161879,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM encounter c, itech.encounter e, itech.adherenceCounseling ac 
	WHERE c.uuid = e.encGuid 
	AND e.patientID = ac.patientID 
	AND e.siteCode = ac.siteCode
	AND concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd) =
		concat(ac.visitDateYy,"-",ac.visitDateMm,"-",ac.visitDateDd)
	AND(ac.sideOtherText<>"" AND ac.sideOtherText is not null);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=161879 
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
		comments,creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,159935,c.encounter_id,
		CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
		WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
		WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
		END,c.location_id,cg.obs_id,5622,ac.sideOtherText,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.adherenceCounseling ac, itech.obs_concept_group cg
		WHERE c.uuid = e.encGuid 
		AND e.siteCode = ac.siteCode
		AND e.patientID = ac.patientID
		AND c.encounter_id=cg.encounter_id
		AND c.patient_id=cg.person_id
		AND concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd) =
		concat(ac.visitDateYy,"-",ac.visitDateMm,"-",ac.visitDateDd)
		AND(ac.sideOtherText<>"" AND ac.sideOtherText is not null);
		/*=====================================================================*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,162760,c.encounter_id,
		CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
		WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
		WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
		END,c.location_id,cg.obs_id,
		CASE WHEN ac.sideNumb=1 THEN 1498
		WHEN ac.sideNumb=2 THEN 1499
		WHEN ac.sideNumb=4 THEN 1500
		END,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.adherenceCounseling ac, itech.obs_concept_group cg
		WHERE c.uuid = e.encGuid 
		AND e.siteCode = ac.siteCode
		AND e.patientID = ac.patientID
		AND c.encounter_id=cg.encounter_id
		AND c.patient_id=cg.person_id
		AND concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd) =
		concat(ac.visitDateYy,"-",ac.visitDateMm,"-",ac.visitDateDd)
		AND (ac.sideOtherText<>"" AND ac.sideOtherText is not null);
		/*End migration for Autres, préciser :*/
		
		
		/*Stop migration for EFFETS SECONDAIRES*/
		/*Start migration for REMARQUES/PLAN D'ACTION*/
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
		END,c.location_id,ac.adherenceRemark,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.adherenceCounseling ac
		WHERE c.uuid = e.encGuid 
		AND e.siteCode = ac.siteCode
		AND e.patientID = ac.patientID
		AND concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd) =
		concat(ac.visitDateYy,"-",ac.visitDateMm,"-",ac.visitDateDd)
		AND (ac.adherenceRemark<>"" AND ac.adherenceRemark is not null);
		/*End migration for REMARQUES/PLAN D'ACTION*/
		/*End migration for Raison donnée pour avoir manqué une dose, cocher le ou les cas ci-dessous*/
END$$
	DELIMITER ;