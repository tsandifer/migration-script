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
DROP PROCEDURE IF EXISTS labsMigration$$
CREATE PROCEDURE labsMigration()
BEGIN
 DECLARE vobs_id INT;
/* SECTION HEMATOLOGIE */
/*Migration for Anti-Thrombine III (Activite), Anti-Thrombine III (Dosage),Basophiles
*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	CASE WHEN (l.labID=1380) THEN 163432 /*Anti-Thrombine III (Activite)*/
	WHEN (l.labID=1379) THEN 163431 /*Anti-Thrombine III (Dosage)*/
	WHEN (l.labID=1364) THEN 1341 /*Basophiles*/
	END,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID IN(1380,1379,1364)
	AND (l.result <> "" AND FindNumericValue(l.result) >= 0);

/*Migration for the concept Anti-Thrombine III (Activite)*/

	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,
	CASE WHEN (l.labID=1380) THEN 163432
	WHEN (l.labID=1379) THEN 163431
	WHEN (l.labID=1364) THEN 1341
	END,c.encounter_id,
	CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
	WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
		DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
	WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
		DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
	END,c.location_id,FindNumericValue(l.result),l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID IN(1380,1379,1364)
	AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
/*END*/
/*Create table obs_concept_group for the obs_group_id*/
create table if not exists itech.obs_concept_group (obs_id int,person_id int,concept_id int,encounter_id int);
/*Insertion for CCMH test (concept_id CCMH, CAUSE of the group, 
		we made a separate query for it)*/
	/*Migration for the concept question of CCMH*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	1017,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1357
	AND (l.result <> "");
	 /*Migration for obsgroup of CCMH*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163700,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1357 and l.result is not null;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163700 
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1017,c.encounter_id,
	CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
	WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
		DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
	WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
		DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,FindNumericValue(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1357
	AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*END CCMH TEST*/
	/*Start migration for CD4 Compte Absolu*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	 5497,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1561
	AND (l.result <> "" AND FindNumericValue(l.result) > 0);
	/*Insert obs_group for CD4 Compte Absolu */
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,657,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1561 and l.result is not null;
	/*Finding the last obs_group_id inserted */
	set vobs_id=last_insert_id();
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,5497,c.encounter_id,
	CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
	WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
		DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
	WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
		DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
	END,c.location_id,vobs_id,FindNumericValue(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1561
	AND (l.result <> "" AND FindNumericValue(l.result) > 0);
	/*END of CD4 Compte Absolu*/
	/*Starting insert for CD4 Compte en %*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		730,1,e.createDate,
		UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1562
		AND (l.result <> "");
		/*add obsgroup*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
		SELECT DISTINCT e.patient_id,657,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
		FROM itech.encounter c, encounter e, itech.labs l 
		WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
		c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
		l.labID=1562 and l.result is not null;
		
		set vobs_id=last_insert_id();
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,730,c.encounter_id,
	CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
	WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
		DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
	WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
		DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
	END,c.location_id,vobs_id,FindNumericValue(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1562
	AND (l.result <> "" AND FindNumericValue(l.result) > 0);
	/*Ending insert for CD4 Compte en %*/
	/*Migration for Compte des Globules Blancs*/
	 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		678,1,e.createDate,
		UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1351
		AND (l.result <> "");
		/*add obsgroup*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
		SELECT DISTINCT e.patient_id,163700,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
		FROM itech.encounter c, encounter e, itech.labs l 
		WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
		c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
		l.labID=1351 and l.result is not null;
		
			set vobs_id=last_insert_id();
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,678,c.encounter_id,
	CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
	WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
		DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
	WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
		DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
	END,c.location_id,vobs_id,FindNumericValue(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1351
	AND (l.result <> "" AND FindNumericValue(l.result) > 0);
	/*END of migration for Compte des Globules Blancs*/
	/*Starting insert for Compte des Globules Rouges*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		679,1,e.createDate,
		UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1352
		AND (l.result <> "");
		/*add obsgroup*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
		SELECT DISTINCT e.patient_id,163700,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
		FROM itech.encounter c, encounter e, itech.labs l 
		WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
		c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
		l.labID=1352 and l.result is not null;
		
			set vobs_id=last_insert_id();
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,679,c.encounter_id,
	CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
	WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
		DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
	WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
		DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
	END,c.location_id,vobs_id,FindNumericValue(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1352
	AND (l.result <> "" AND FindNumericValue(l.result) > 0);
	/*Ending insert for Compte des Globules Rouges*/
	
	/*Starting insertion for Coombs Test Direct, Coombs Test Indirect*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		CASE WHEN (l.labID=1385) THEN 159607 /*Coombs Test Direct*/
		WHEN (l.labID=1386) THEN 159606 /*Coombs Test Indirect*/
		END,1,e.createDate,
		UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID IN(1385,1386)
		AND (l.result <> "" OR l.result is not null);
		
		
		/*concept Coombs*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,
		CASE WHEN (l.labID=1385) THEN 159607
		WHEN (l.labID=1386) THEN 159606
		END,c.encounter_id,
		CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
		WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
		WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
		END,c.location_id,
		 CASE WHEN (l.result LIKE LOWER ("N%"))THEN 664
			  WHEN (l.result LIKE LOWER ("P%"))THEN 703
			ELSE null
		END,l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID IN(1385,1386)
		AND (l.result <> "" AND l.result is not null);
	/*Ending insertion for Coombs Test Direct*/
	/*Starting migration for Electrophorese de l’hemoglobine*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		161421,1,e.createDate,
		UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1369
		AND (l.result <> "" OR l.result is not null);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_text,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,161421,c.encounter_id,
		CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
		WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
		WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
		END,c.location_id,l.result,l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1369
		AND (l.result <> "" AND l.result is not null);
	/*Ending migration for Electrophorese de l’hemoglobine*/
	/*Starting migration for Eosinophiles*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		1340,1,e.createDate,
		UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1363
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1340,c.encounter_id,
		CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
		WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
		WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
		END,c.location_id,l.result,l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1363
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*Ending migration for Eosinophiles*/
	
	/*Starting migration for Facteur IX*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		163429,1,e.createDate,
		UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1377
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163429,c.encounter_id,
		CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
		WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
		WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
		END,c.location_id,l.result,l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1377
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*Ending migration for Facteur IX*/
	
	/*Starting migration for Facteur VIII*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		163428,1,e.createDate,
		UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1376
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163428,c.encounter_id,
		CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
		WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
		WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
		END,c.location_id,l.result,l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1376
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*Ending migration for Facteur VIII*/
	/*Starting migration for Ferritine sérique*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		161511,1,e.createDate,
		UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=306
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,161511,c.encounter_id,
		CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
		WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
		WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
		END,c.location_id,FindNumericValue(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=306
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*Ending migration for Ferritine sérique*/
	/*Starting Migration for Groupe Sanguin - ABO (Have concept group)*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	300,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1381
	AND (l.result <> "");
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,161473,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1381 and l.result is not null;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=161473 
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,300,c.encounter_id,
	CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
	WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
		DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
	WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
		DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,FindNumericValue(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1381
	AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*Ending migration for Groupe Sanguin - ABO*/
	/*Starting migration for Groupe Sanguin - Rhesus (Have concept group)*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	160232,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1382
	AND (l.result <> "" and l.result is not null);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,161473,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1382 and l.result is not null;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=161473 
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,160232,c.encounter_id,
	CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
	WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
		DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
	WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
		DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
	CASE WHEN (l.result like LOWER("%POS%")) THEN 703
	WHEN(l.result like LOWER ("%NEG%")) THEN 664
	ELSE null
	END,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1382
	AND (l.result <> "" AND l.result is not null);
	/*Ending migration for Groupe Sanguin - Rhesus*/
	/*Starting migration for Hematocrite (Have concept group)*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	1015,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1354
	AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163700,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1354 and (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163700 
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1015,c.encounter_id,
	CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
	WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
		DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
	WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
		DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,FindNumericValue(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1354
	AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*Ending migration for Hematocrite*/
	/*Starting migration for Hemoglobine (Have concept group)*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	21,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1353
	AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163700,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1353 and (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163700 
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,21,c.encounter_id,
	CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
	WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
		DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
	WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
		DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,FindNumericValue(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1353
	AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*Ending migration for Hemoglobine*/
	
	/*Starting migration for Heparinemie*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		163430,1,e.createDate,
		UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1378
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163430,c.encounter_id,
		CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
		WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
		WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
		END,c.location_id,FindNumericValue(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1378
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*Ending migration for Heparinemie*/
	/*Starting migration for INR (Have concept group )*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	161482,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1375
	AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163436,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1375 and (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163436 
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161482,c.encounter_id,
	CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
	WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
		DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
	WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
		DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,FindNumericValue(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1375
	AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	
	/*Stop migration for INR*/
	/*Starting migration for Lymphocytes (have concept group)*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	1338,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1360
	AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163700,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1360 and (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163700 
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1338,c.encounter_id,
	CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
	WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
		DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
	WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
		DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,FindNumericValue(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1360
	AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*Stoping migration for Lymphocytes*/
	/*Starting migration for Mixtes (have concept group)*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163426,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1361
	AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163700,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1361 and (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163700 
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163426,c.encounter_id,
	CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
	WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
		DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
	WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
		DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,FindNumericValue(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1361
	AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*Ending migration for Mixtes*/
	/*Starting migration for Monocytes*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		1339,1,e.createDate,
		UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1362
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1339,c.encounter_id,
		CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
		WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
		WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
		END,c.location_id,FindNumericValue(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1362
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*Ending migration for Monocytes*/
	
	/*Starting migration for Neutrophiles (have concept group)*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	1336,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1359
	AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163700,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1359 and (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163700 
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1336,c.encounter_id,
	CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
	WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
		DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
	WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
		DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,FindNumericValue(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1359
	AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	
	/*Ending migration for Neutrophiles*/
	/*Starting migration for Plaquettes (have concept group)*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	729,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1358
	AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163700,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1358 and (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163700 
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,729,c.encounter_id,
	CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
	WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
		DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
	WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
		DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,FindNumericValue(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1358
	AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*Ending migration for Plaquettes*/
	/*Starting migration for Sickling Test*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		160225,1,e.createDate,
		UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1370
		AND (l.result <> "" OR l.result is not null);
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,160225,c.encounter_id,
		CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
		WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
		WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
		END,c.location_id,
		 CASE WHEN (l.result LIKE LOWER ("N%"))THEN 664
			  WHEN (l.result LIKE LOWER ("P%"))THEN 703
			ELSE null
		END,l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1370
		AND (l.result <> "" AND l.result is not null);
	/*Ending migration for Sickling Test*/
	/*Starting migration for Taux reticulocytes - Auto*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		1327,1,e.createDate,
		UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1371
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1327,c.encounter_id,
		CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
		WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
		WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
		END,c.location_id,FindNumericValue(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1371
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*Ending migration for Taux reticulocytes - Auto*/
	/*Starting migration for TCMH (have concept group)*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	1018,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1356
	AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163700,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1356 and (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163700 
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1018,c.encounter_id,
	CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
	WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
		DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
	WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
		DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,FindNumericValue(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1356
	AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*Ending migration for TCMH*/
	/*Starting migration for Temps de cephaline Activé(TCA) (have concept group)*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	161153,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1373
	AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163436,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1373 and (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163436
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161153,c.encounter_id,
	CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
	WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
		DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
	WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
		DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,FindNumericValue(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1373
	AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*Ending migration for Temps de cephaline Activé(TCA)*/
	/*Starting migration for Temps de Coagulation (have concept group)*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	161435,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1367
	AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163702,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1367 and (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163702
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161435,c.encounter_id,
	CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
	WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
		DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
	WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
		DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,FindNumericValue(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1367
	AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*Ending migration for Temps de Coagulation*/
	/*Starting migration for Temps de Coagulation en tube*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		163427,1,e.createDate,
		UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1366
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163427,c.encounter_id,
		CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
		WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
		WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
		END,c.location_id,FindNumericValue(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1366
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*Ending for Temps de Coagulation en tube*/
	/*Starting migration for Temps de Prothrombine*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		161481,1,e.createDate,
		UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1374
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,161481,c.encounter_id,
		CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
		WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
		WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
		END,c.location_id,FindNumericValue(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1374
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*Ending migration for Temps de Prothrombine*/
	/*Starting migration for Temps de saignement (have concept group)*/
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	161433,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1368
	AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163702,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1368 and (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163702
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161433,c.encounter_id,
	CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
	WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
		DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
	WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
		DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,FindNumericValue(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1368
	AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	
	/*Ending migration for Temps de saignement*/
	/*Starting migration for Test de comptabilite*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		161233,1,e.createDate,
		UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1383
		AND (l.result <> "" OR l.result is not null);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,
		161233,c.encounter_id,
		CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
		WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
		WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
		END,c.location_id,
		 CASE WHEN (l.result LIKE LOWER ("%INC%"))THEN 163434
			ELSE 163433
		END,l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1383
		AND (l.result <> "" AND l.result is not null);
	
	/*Ending migration for Test de comptabilite*/
	/*Starting migration for VGM (have concept group)*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	851,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1355
	AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163700,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1355 and (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163700
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,851,c.encounter_id,
	CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
	WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
		DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
	WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
		DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,FindNumericValue(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1355
	AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	
	/*Ending migration for VGM*/
	/*Starting migration for Vitamine B12*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		163435,1,e.createDate,
		UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=307
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163435,c.encounter_id,
		CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
		WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
		WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
		END,c.location_id,FindNumericValue(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=307
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*Ending migration Vitamine B12*/
	
	/*Starting migration for Vitesse de Sedimentation*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		855,1,e.createDate,UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1365
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,855,c.encounter_id,
		CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
		WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
		WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
		END,c.location_id,FindNumericValue(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1365
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*Ending migration for Vitesse de Sedimentation*/
	/*END OF Migration for Hematologie part*/
	

	/*Starting migration for Biochimie tests*/
	/*Migration for Acide urique=159825*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		159825,1,e.createDate,UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1456
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,159825,c.encounter_id,
		CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
		WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
		WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
		END,c.location_id,FindNumericValue(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1456
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*End migration for Acide urique*/
	/*Start migration for Albumine*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		848,1,e.createDate,UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1395
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,848,c.encounter_id,
		CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
		WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
		WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
		END,c.location_id,FindNumericValue(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1395
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*End migration for Albumine*/
	/*Starting migration for Amylase*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		1299,1,e.createDate,UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1404
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1299,c.encounter_id,
		CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
		WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
		WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
		END,c.location_id,FindNumericValue(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1404
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*End migration for Amylase*/
	/*Starting migration for Azote de l’Uree (have concept group)*/
	/*End migration for Azote de l’Uree*/
	/*Starting migration for BE (have concept group)*/
	/*End migration for BE*/
	/*Starting migration for Bicarbonates (Have concept group)*/
	/*End migration for Bicarbonates*/
	/*Starting migration for Bilirubine direct*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		1297,1,e.createDate,UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1416
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1297,c.encounter_id,
		CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
		WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
		WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
		END,c.location_id,FindNumericValue(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1416
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*End migration for Bilirubine direct*/
	/*Starting migration for Bilirubine indirecte*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		163001,1,e.createDate,UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1417
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163001,c.encounter_id,
		CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
		WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
		WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
		END,c.location_id,FindNumericValue(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1417
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*End migration for Bilirubine indirecte*/
	
	/*Starting migration for Bilirubine totale(have concept group)*/
	/*End migration for Bilirubine totale*/
	/*Starting migration for C3 complement*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		163600,1,e.createDate,UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1470
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163600,c.encounter_id,
		CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
		WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
		WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
		END,c.location_id,FindNumericValue(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1470
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*End migration for C3 complement*/
	/*Starting migration for C4 complement*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		163601,1,e.createDate,UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1471
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163601,c.encounter_id,
		CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
		WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
		WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
		END,c.location_id,FindNumericValue(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1471
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*End migration for C4 complement*/
	/*Starting migration for Calcium (Have concept group)*/
	/*End migration for Calcium*/
	/*Starting migration Chlore (have concept group)*/
	/*End migration Chlore*/
	/*Starting migration for Cholestérol total(have concept group)*/
	/*End migration for Cholestérol total*/
	/*Starting migration for CPK MB*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		1011,1,e.createDate,UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=302
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1011,c.encounter_id,
		CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
		WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
		WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
		END,c.location_id,FindNumericValue(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=302
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*End migration for CPK MB*/
	/*Starting migration for Créatinine (have concept group)*/
	/*END migration for Créatinine*/
	/*Starting migration for CRP Quantitatif (have concept group)*/
	/*End migration for CRP Quantitatif*/
	/*Starting migration for Facteur Rhumatoide (have concept group)*/
	/*End migration for Facteur Rhumatoide*/
	/*Start migration for Fer Serique*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		159828,1,e.createDate,UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1414
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,159828,c.encounter_id,
		CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
		WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
		WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
		END,c.location_id,FindNumericValue(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1414
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*End migration for Fer Serique*/
	/*Start migration for Glycemie*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		887,1,e.createDate,UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1391
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,887,c.encounter_id,
		CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
		WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
		WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
		END,c.location_id,FindNumericValue(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1391
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*End migration for Glycemie*/
	/*Start migration for Glycemie Postprandiale*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		160914,1,e.createDate,UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1445
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,160914,c.encounter_id,
		CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
		WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
		WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
		END,c.location_id,FindNumericValue(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1445
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*End migration for Glycemie Postprandiale*/
	/*Migration for Glycémie provoquée*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		163594,1,e.createDate,UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1444
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163594,c.encounter_id,
		CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
		WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
		WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
		END,c.location_id,FindNumericValue(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1444
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*End migration Glycémie provoquée*/ 
	/*Migration for Glycémie provoquée 1/2 hre*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		163703,1,e.createDate,UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1439
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163703,c.encounter_id,
		CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
		WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
		WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
		END,c.location_id,FindNumericValue(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1439
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/* End Migration for Glycémie provoquée 1/2 hre*/
	/*Migration for Glycémie provoquée 1hre*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		163704,1,e.createDate,UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1440
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163704,c.encounter_id,
		CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
		WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
		WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
		END,c.location_id,FindNumericValue(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1440
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*End migration for Glycémie provoquée 1hre*/
	/*Migration for Glycémie provoquée 2hres*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		163705,1,e.createDate,UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1441
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163705,c.encounter_id,
		CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
		WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
		WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
		END,c.location_id,FindNumericValue(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1441
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*Migration for Glycémie provoquée 2hres*/
	
	/*Migration for Glycémie provoquée 3hres*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		163706,1,e.createDate,UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1442
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163706,c.encounter_id,
		CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
		WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
		WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
		END,c.location_id,FindNumericValue(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1442
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*Migration for Glycémie provoquée 3hres*/
	/*Migration for Glycémie provoquée 4hres*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		163707,1,e.createDate,UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1443
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163707,c.encounter_id,
		CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
		WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
		WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
		END,c.location_id,FindNumericValue(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1443
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*Migration for Glycémie provoquée 4hres*/
	/*Migration for Glycemie Provoquée Fasting*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		160912,1,e.createDate,UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1438
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,160912,c.encounter_id,
		CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
		WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
		WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
		END,c.location_id,FindNumericValue(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1438
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*Migration for Glycemie Provoquée Fasting*/
	/*Start Migration for HCO3 (have concept group)*/
	/*End migration for HCO3*/
	
	/*Start Migration for HDL */
	/*END Migration for HDL */
	/*Start migration for Hémoglobine glycolisee*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		159644,1,e.createDate,UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1428
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,159644,c.encounter_id,
		CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
		WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
		WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
		END,c.location_id,FindNumericValue(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1428
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*End migration for Hémoglobine glycolisee*/
	/*Start migration for La porphyrineVLDL – cholesterol (calculée) (A verifier)*/
	
	/*End migration for La porphyrineVLDL – cholesterol (calculée)*/
	/*Start migration for LDH*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		1014,1,e.createDate,UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1429
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1014,c.encounter_id,
		CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
		WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
		WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
		END,c.location_id,FindNumericValue(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1429
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*End migration for LDH*/
	/*Start migration for LDL (have oncept group)*/
	/*End migration for LDL*/
	/*Starting migration for Lipase*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		101,1,e.createDate,
		UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1405
		AND (
			(l.result <> "" OR l.result is not null)
			OR
			(l.result2 <> "" OR l.result2 is not null)
			OR
			(l.result3 <> "" OR l.result3 is not null)
			OR
			(l.result4 <> "" OR l.result4 is not null)
			);
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,
		101,c.encounter_id,
		CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
		WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
		WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
		END,c.location_id,
		 CASE WHEN (l.result LIKE LOWER ("NO%") OR l.result2 LIKE LOWER ("NO%") 
		            OR l.result3 LIKE LOWER ("NO%") OR l.result4 LIKE LOWER ("NO%"))THEN 1115
			WHEN (l.result LIKE LOWER ("AN%") OR l.result2 LIKE LOWER ("AN%") 
		            OR l.result3 LIKE LOWER ("AN%") OR l.result4 LIKE LOWER ("AN%"))THEN 1116
			ELSE null
		END,l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1405
		AND (
			(l.result <> "" OR l.result is not null)
			OR
			(l.result2 <> "" OR l.result2 is not null)
			OR
			(l.result3 <> "" OR l.result3 is not null)
			OR
			(l.result4 <> "" OR l.result4 is not null)
			);
	/*End migration for Lipase*/
	/*Start Migration for Lithium=163592*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		163592,1,e.createDate,UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1413
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163592,c.encounter_id,
		CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
		WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
		WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
		END,c.location_id,FindNumericValue(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1413
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*End migration for Lithium*/
	/*Start migration for magnésium*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		159643,1,e.createDate,UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1411
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,159643,c.encounter_id,
		CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
		WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
		WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
		END,c.location_id,FindNumericValue(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1411
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*End migration for magnésium*/
	/*Start migration for MBG*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		163593,1,e.createDate,UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1427
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163593,c.encounter_id,
		CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
		WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
		WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
		END,c.location_id,FindNumericValue(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1427
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*End migration for MBG*/
	/*Start migration for O2 Saturation (have concept group)*/
	/*End migration for O2 Saturation*/
	/*Start migration for PaCO2 (have concept group)*/
	/*End migration for PaCO2*/
	/*Start migration for PaO2 (have concept group)*/
	/*End migration for PaO2*/
	/*Start migration for Ph*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		161455,1,e.createDate,UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1431
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,161455,c.encounter_id,
		CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
		WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
		WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
		END,c.location_id,FindNumericValue(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1431
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*End migration for Ph*/
	/*Start migration for Phosphatase Acide*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		163443,1,e.createDate,UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1400
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163443,c.encounter_id,
		CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
		WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
		WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
		END,c.location_id,FindNumericValue(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1400
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*End migration for Phosphatase Acide*/
	/*Start migration for Phosphatase Alcaline*/
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		785,1,e.createDate,UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1420
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,785,c.encounter_id,
		CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
		WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
		WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
		END,c.location_id,FindNumericValue(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1420
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*End migration for Phosphatase Alcaline*/
	/*Start migration for Phosphore*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		161154,1,e.createDate,UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1412
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,161154,c.encounter_id,
		CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
		WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
		WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
		END,c.location_id,FindNumericValue(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1412
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*End migration for Phosphore*/
	/*Start migration for Potassium (have concept group)*/
	/*End migration for Potassium*/
	/*Start migration for Proteines (have concept group)*/
	/*End migration for Proteines*/
	/*Start migration for Protéines totales */
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		717,1,e.createDate,UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1459
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,717,c.encounter_id,
		CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
		WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
		WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
		END,c.location_id,FindNumericValue(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1459
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*End migration for Protéines totales*/
	/*Start Migration for SGOT (AST) (have concept group)*/
	/*End migration for SGOT (AST)*/
	/*Start migration for SGPT (ALT) (have concept group)*/
	/*End migration for SGPT (ALT)*/
	/*Start migration for Sodium (have concept group)*/
	/*End migration for Sodium*/
	/*Start migration for Triglycéride (have concept group)*/
	/*End migration for Triglycéride*/
	/*Start migration for Triponine I*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		159654,1,e.createDate,UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1430
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,159654,c.encounter_id,
		CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
		WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
		WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
		END,c.location_id,FindNumericValue(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1430
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*End migration for Triponine I*/
	/*Start migration for Urée (calculée) (have concept group)*/
	/*End migration for Urée (calculée)*/
	/*Start migration for VLDL (have concept group)*/
	/*End migration for VLDL*/
	/*Start migration for α1 globuline*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		163437,1,e.createDate,UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1396
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163437,c.encounter_id,
		CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
		WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
		WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
		END,c.location_id,FindNumericValue(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1396
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*End migration for α1 globuline*/
	/*Start migration for α2 globuline*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		163438,1,e.createDate,UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1397
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163438,c.encounter_id,
		CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
		WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
		WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
		END,c.location_id,FindNumericValue(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1397
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*End migration for α2 globuline*/
	/*Start migration for β globuline*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		163439,1,e.createDate,UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1398
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163439,c.encounter_id,
		CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
		WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
		WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
		END,c.location_id,FindNumericValue(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1398
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*End migration for β globuline*/
	/*Start Migration for ϒ globuline*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		163442,1,e.createDate,UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1399
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163442,c.encounter_id,
		CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
		WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
		WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
		END,c.location_id,FindNumericValue(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1399
		AND (l.result <> "" AND FindNumericValue(l.result) >= 0);
	/*End migration for ϒ globuline*/
	/*Ending migration for Biochimie tests Part*/
	/*Start Migration for Cytobacteriologie part*/
		/*Start migration for Bacteries (Pour Femme)(have concept group)*/
		/*End migration for Bacteries*/
		/*Start migration for Bacteries (Pour Homme)(have concept group)*/
		/*End migration for Bacteries*/
	/*End Migration for Cytobacteriologie part*/
	
	/*Ending migration for labs data*/
	
 END$$
	DELIMITER ;
	call labsMigration();