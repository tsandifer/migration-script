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

DROP FUNCTION if exists `digits`;
DELIMITER $$
CREATE FUNCTION `digits`( str CHAR(32) ) RETURNS char(32) CHARSET utf8
BEGIN
  DECLARE i, len SMALLINT DEFAULT 1;
  DECLARE ret CHAR(32) DEFAULT '';
  DECLARE c CHAR(1);
  DECLARE pos SMALLINT;
  DECLARE after_p CHAR(20);
  IF str IS NULL
  THEN 
    RETURN "";
  END IF;
  SET len = CHAR_LENGTH( str );
  l:REPEAT
    BEGIN
      SET c = MID( str, i, 1 );
      IF c BETWEEN '0' AND '9' THEN 
        SET ret=CONCAT(ret,c);
      ELSEIF c = '.' OR c = ',' THEN
		IF c = '.' THEN
			SET pos=INSTR(str, '.' );
            SET after_p=MID(str,pos,pos+2);
            SET ret=CONCAT(FindNumericValue(ret),'.',FindNumericValue(after_p));
            LEAVE l;
		ELSEIF c = ',' THEN 
			SET pos=INSTR(str, ',');
            SET after_p=MID(str,pos,pos+2);
            SET ret=CONCAT(FindNumericValue(ret),'.',FindNumericValue(after_p));
            LEAVE l;
		END IF;
      END IF;
      
      SET i = i + 1;
      
    END;
  UNTIL i > len END REPEAT;
  RETURN ret;
END$$
DELIMITER ;


DELIMITER $$
DROP PROCEDURE IF EXISTS labsMigration$$
CREATE PROCEDURE labsMigration()
BEGIN
 /*DECLARE vobs_id INT;
 set vobs_id=last_insert_id();*/
 /*Delete all inserted labs data if the script fail*/
 SET SQL_SAFE_UPDATES = 0;
 SET FOREIGN_KEY_CHECKS=0;
 DELETE FROM obs WHERE encounter_id IN
 (
	SELECT en.encounter_id FROM encounter en, encounter_type ent
	WHERE en.encounter_type=ent.encounter_type_id
	AND ent.uuid='f037e97b-471e-4898-a07c-b8e169e0ddc4'
 );
  SET SQL_SAFE_UPDATES = 1;
  SET FOREIGN_KEY_CHECKS=1;
  /*End of delete all inserted labs data*/
/* SECTION HEMATOLOGIE */
/*Migration for Anti-Thrombine III (Activite), Anti-Thrombine III (Dosage),Basophiles*/
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
	AND (l.result <> "" AND digits(l.result) >= 0);

/*Migration for the concept Anti-Thrombine III (Activite)*/

	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,
	CASE WHEN (l.labID=1380) THEN 163432
	WHEN (l.labID=1379) THEN 163431
	WHEN (l.labID=1364) THEN 1341
	END,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result),l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID IN(1380,1379,1364)
	AND (l.result <> "" AND digits(l.result) >= 0);
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
	AND (l.result <> "" and l.result is not null);
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
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1357
	AND (l.result <> "" AND digits(l.result) >= 0);
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
	AND (l.result <> "" AND digits(l.result) > 0);
	/*Insert obs_group for CD4 Compte Absolu */
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,657,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1561 and l.result is not null;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=657 
	GROUP BY openmrs.obs.person_id,encounter_id;

	/*Finding the last obs_group_id inserted */
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,5497,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1561
	AND (l.result <> "" AND digits(l.result) > 0);
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
		AND (l.result <> "" AND digits(l.result) > 0);
		/*add obsgroup*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
		SELECT DISTINCT e.patient_id,657,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
		FROM itech.encounter c, encounter e, itech.labs l 
		WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
		c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
		l.labID=1562 AND (l.result <> "" AND digits(l.result) > 0);
		/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=657 
	GROUP BY openmrs.obs.person_id,encounter_id;
	   /*concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,730,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1562
	AND (l.result <> "" AND digits(l.result) > 0);
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
		AND (l.result <> "" AND digits(l.result) > 0);
		/*add obsgroup*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
		SELECT DISTINCT e.patient_id,163700,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
		FROM itech.encounter c, encounter e, itech.labs l 
		WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
		c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
		l.labID=1351 AND (l.result <> "" AND digits(l.result) > 0);
		
		TRUNCATE TABLE itech.obs_concept_group;
		INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
		SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
		FROM openmrs.obs
		WHERE openmrs.obs.concept_id=163700 
		GROUP BY openmrs.obs.person_id,encounter_id;
		/*concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,678,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1351
	AND (l.result <> "" AND digits(l.result) > 0);
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
		
		TRUNCATE TABLE itech.obs_concept_group;
		INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
		SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
		FROM openmrs.obs
		WHERE openmrs.obs.concept_id=163700 
		GROUP BY openmrs.obs.person_id,encounter_id;
      /*concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,679,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1352
	AND (l.result <> "" AND digits(l.result) > 0);
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
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
		 CASE WHEN (l.result LIKE LOWER ("NEG%"))THEN 664
			  WHEN (l.result LIKE LOWER ("POS%"))THEN 703
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
	/*Ending insertion for Coombs Test Direct----------------------*/
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
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
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
		AND (l.result <> "" AND digits(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1340,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,l.result,l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1363
		AND (l.result <> "" AND digits(l.result) >= 0);
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
		AND (l.result <> "" AND digits(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163429,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,l.result,l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1377
		AND (l.result <> "" AND digits(l.result) >= 0);
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
		AND (l.result <> "" AND digits(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163428,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,l.result,l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1376
		AND (l.result <> "" AND digits(l.result) >= 0);
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
		AND (l.result <> "" AND digits(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,161511,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=306
		AND (l.result <> "" AND digits(l.result) >= 0);
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
	AND (
		(l.result <> "" and l.result is not null)
		OR
		(l.result2 <> "" and l.result2 is not null)
		OR
		(l.result3 <> "" and l.result3 is not null)
		OR
		(l.result4 <> "" and l.result4 is not null)
	
	);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,161473,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1381
	AND (
		(l.result <> "" and l.result is not null)
		OR
		(l.result2 <> "" and l.result2 is not null)
		OR
		(l.result3 <> "" and l.result3 is not null)
		OR
		(l.result4 <> "" and l.result4 is not null)
	
	);
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
	SELECT DISTINCT c.patient_id,300,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
		CASE WHEN (l.result LIKE LOWER ("A+"))THEN 690
			WHEN (l.result LIKE LOWER ("A-"))THEN 692
	        WHEN (l.result LIKE LOWER ("B+"))THEN 694
			WHEN (l.result LIKE LOWER ("B-"))THEN 696
			WHEN (l.result LIKE LOWER ("O+"))THEN 699
			WHEN (l.result LIKE LOWER ("O-"))THEN 701
			WHEN (l.result LIKE LOWER ("AB+"))THEN 1230
			WHEN (l.result LIKE LOWER ("AB-"))THEN 1231
			
			WHEN (l.result2 LIKE LOWER ("A+"))THEN 690
			WHEN (l.result2 LIKE LOWER ("A-"))THEN 692
	        WHEN (l.result2 LIKE LOWER ("B+"))THEN 694
			WHEN (l.result2 LIKE LOWER ("B-"))THEN 696
			WHEN (l.result2 LIKE LOWER ("O+"))THEN 699
			WHEN (l.result2 LIKE LOWER ("O-"))THEN 701
			WHEN (l.result2 LIKE LOWER ("AB+"))THEN 1230
			WHEN (l.result2 LIKE LOWER ("AB-"))THEN 1231
			
			WHEN (l.result3 LIKE LOWER ("A+"))THEN 690
			WHEN (l.result3 LIKE LOWER ("A-"))THEN 692
	        WHEN (l.result3 LIKE LOWER ("B+"))THEN 694
			WHEN (l.result3 LIKE LOWER ("B-"))THEN 696
			WHEN (l.result3 LIKE LOWER ("O+"))THEN 699
			WHEN (l.result3 LIKE LOWER ("O-"))THEN 701
			WHEN (l.result3 LIKE LOWER ("AB+"))THEN 1230
			WHEN (l.result3 LIKE LOWER ("AB-"))THEN 1231
			
			WHEN (l.result4 LIKE LOWER ("A+"))THEN 690
			WHEN (l.result4 LIKE LOWER ("A-"))THEN 692
	        WHEN (l.result4 LIKE LOWER ("B+"))THEN 694
			WHEN (l.result4 LIKE LOWER ("B-"))THEN 696
			WHEN (l.result4 LIKE LOWER ("O+"))THEN 699
			WHEN (l.result4 LIKE LOWER ("O-"))THEN 701
			WHEN (l.result4 LIKE LOWER ("AB+"))THEN 1230
			WHEN (l.result4 LIKE LOWER ("AB-"))THEN 1231
			
	END,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1381
	AND (
		(l.result <> "" and l.result is not null)
		OR
		(l.result2 <> "" and l.result2 is not null)
		OR
		(l.result3 <> "" and l.result3 is not null)
		OR
		(l.result4 <> "" and l.result4 is not null)
	
	);
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
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
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
	AND (l.result <> "" AND digits(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163700,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1354 and (l.result <> "" AND digits(l.result) >= 0);
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
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1354
	AND (l.result <> "" AND digits(l.result) >= 0);
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
	AND (l.result <> "" AND digits(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163700,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1353 and (l.result <> "" AND digits(l.result) >= 0);
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
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1353
	AND (l.result <> "" AND digits(l.result) >= 0);
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
		AND (l.result <> "" AND digits(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163430,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1378
		AND (l.result <> "" AND digits(l.result) >= 0);
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
	AND (l.result <> "" AND digits(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163436,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1375 and (l.result <> "" AND digits(l.result) >= 0);
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
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1375
	AND (l.result <> "" AND digits(l.result) >= 0);
	
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
	AND (l.result <> "" AND digits(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163700,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1360 and (l.result <> "" AND digits(l.result) >= 0);
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
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1360
	AND (l.result <> "" AND digits(l.result) >= 0);
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
	AND (l.result <> "" AND digits(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163700,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1361 and (l.result <> "" AND digits(l.result) >= 0);
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
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1361
	AND (l.result <> "" AND digits(l.result) >= 0);
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
		AND (l.result <> "" AND digits(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1339,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1362
		AND (l.result <> "" AND digits(l.result) >= 0);
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
	AND (l.result <> "" AND digits(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163700,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1359 and (l.result <> "" AND digits(l.result) >= 0);
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
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1359
	AND (l.result <> "" AND digits(l.result) >= 0);
	
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
	AND (l.result <> "" AND digits(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163700,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1358 and (l.result <> "" AND digits(l.result) >= 0);
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
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1358
	AND (l.result <> "" AND digits(l.result) >= 0);
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
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
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
		AND (l.result <> "" AND digits(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1327,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1371
		AND (l.result <> "" AND digits(l.result) >= 0);
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
	AND (l.result <> "" AND digits(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163700,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1356 and (l.result <> "" AND digits(l.result) >= 0);
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
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1356
	AND (l.result <> "" AND digits(l.result) >= 0);
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
	AND (l.result <> "" AND digits(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163436,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1373 and (l.result <> "" AND digits(l.result) >= 0);
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
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1373
	AND (l.result <> "" AND digits(l.result) >= 0);
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
	AND (l.result <> "" AND digits(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163702,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1367 and (l.result <> "" AND digits(l.result) >= 0);
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
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1367
	AND (l.result <> "" AND digits(l.result) >= 0);
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
		AND (l.result <> "" AND digits(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163427,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1366
		AND (l.result <> "" AND digits(l.result) >= 0);
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
		AND (l.result <> "" AND digits(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,161481,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1374
		AND (l.result <> "" AND digits(l.result) >= 0);
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
	AND (l.result <> "" AND digits(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163702,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1368 and (l.result <> "" AND digits(l.result) >= 0);
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
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1368
	AND (l.result <> "" AND digits(l.result) >= 0);
	
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
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
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
	AND (l.result <> "" AND digits(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163700,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1355 and (l.result <> "" AND digits(l.result) >= 0);
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
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1355
	AND (l.result <> "" AND digits(l.result) >= 0);
	
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
		AND (l.result <> "" AND digits(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163435,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=307
		AND (l.result <> "" AND digits(l.result) >= 0);
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
		AND (l.result <> "" AND digits(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,855,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1365
		AND (l.result <> "" AND digits(l.result) >= 0);
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
		AND (l.result <> "" AND digits(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,159825,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1456
		AND (l.result <> "" AND digits(l.result) >= 0);
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
		AND (l.result <> "" AND digits(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,848,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1395
		AND (l.result <> "" AND digits(l.result) >= 0);
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
		AND (l.result <> "" AND digits(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1299,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1404
		AND (l.result <> "" AND digits(l.result) >= 0);
	/*End migration for Amylase*/
	/*Starting migration for Azote de l’Uree (have concept group)*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	857,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1387
	AND (l.result <> "" AND digits(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,161488,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1387 and (l.result <> "" AND digits(l.result) >= 0);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=161488
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,857,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,digits(l.result),l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1387
	AND (l.result <> "" AND digits(l.result) >= 0);
	/*End migration for Azote de l’Uree*/
	/*Starting migration for BE (have concept group)*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163599,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1436
	AND (l.result <> "" AND digits(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163602,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1436 and (l.result <> "" AND digits(l.result) >= 0);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163602
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163599,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1436
	AND (l.result <> "" AND digits(l.result) >= 0);
	/*End migration for BE*/
	/*Starting migration for Bicarbonates (Have concept group)*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	1135,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1409
	AND (l.result <> "" AND digits(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,5473,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1409 and (l.result <> "" AND digits(l.result) >= 0);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=5473
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1135,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1409
	AND (l.result <> "" AND digits(l.result) >= 0);
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
		AND (l.result <> "" AND digits(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1297,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1416
		AND (l.result <> "" AND digits(l.result) >= 0);
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
		AND (l.result <> "" AND digits(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163001,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1417
		AND (l.result <> "" AND digits(l.result) >= 0);
	/*End migration for Bilirubine indirecte*/
	
	/*Starting migration for Bilirubine totale(have concept group)*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	655,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1415
	AND (l.result <> "" AND digits(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,953,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1415 and (l.result <> "" AND digits(l.result) >= 0);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=953
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,655,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1415
	AND (l.result <> "" AND digits(l.result) >= 0);
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
		AND (l.result <> "" AND digits(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163600,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1470
		AND (l.result <> "" AND digits(l.result) >= 0);
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
		AND (l.result <> "" AND digits(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163601,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1471
		AND (l.result <> "" AND digits(l.result) >= 0);
	/*End migration for C4 complement*/
	/*Starting migration for Calcium (Have concept group)*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	159497,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1410
	AND (l.result <> "" AND digits(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,5473,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1410 and (l.result <> "" AND digits(l.result) >= 0);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=5473
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159497,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1410
	AND (l.result <> "" AND digits(l.result) >= 0);
	/*End migration for Calcium*/
	/*Starting migration Chlore (have concept group)*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	1134,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1393
	AND (l.result <> "" AND digits(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,159645,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1393 and (l.result <> "" AND digits(l.result) >= 0);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=159645
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1134,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1393
	AND (l.result <> "" AND digits(l.result) >= 0);
	/*End migration Chlore*/
	/*Starting migration for Cholestérol total(have concept group)*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	1006,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1451
	AND (l.result <> "" AND digits(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,1010,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1451 and (l.result <> "" AND digits(l.result) >= 0);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=1010
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1006,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1451
	AND (l.result <> "" AND digits(l.result) >= 0);
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
		AND (l.result <> "" AND digits(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1011,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=302
		AND (l.result <> "" AND digits(l.result) >= 0);
	/*End migration for CPK MB*/
	/*Starting migration for Créatinine (have concept group)*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	790,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1461
	AND (l.result <> "" AND digits(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,161488,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1461 and (l.result <> "" AND digits(l.result) >= 0);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=161488
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,790,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1461
	AND (l.result <> "" AND digits(l.result) >= 0);
	/*END migration for Créatinine*/
	/*Starting migration for CRP Quantitatif (have concept group)*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	161500,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1468
	AND (l.result <> "" AND digits(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,161501,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1468 and (l.result <> "" AND digits(l.result) >= 0);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=161501
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161500,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1468
	AND (l.result <> "" AND digits(l.result) >= 0);
	/*End migration for CRP Quantitatif*/
	/*Starting migration for Facteur Rhumatoide (have concept group)*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	161470,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1474
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,161479,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") 
	AND l.labID=1474
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=161479
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161470,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
	CASE WHEN (
				(l.result like lower("POS%"))
				OR (l.result2 like lower("POS%"))
				OR (l.result3 like lower("POS%"))
				OR (l.result4 like lower("POS%"))
				)  THEN 703
	WHEN (
			(l.result like lower("NEG%"))
			OR (l.result2 like lower("NEG%"))
			OR (l.result3 like lower("NEG%"))
			OR (l.result4 like lower("NEG%"))
		) THEN 664
	ELSE null
	END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1474
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	
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
		AND (l.result <> "" AND digits(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,159828,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1414
		AND (l.result <> "" AND digits(l.result) >= 0);
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
		AND (l.result <> "" AND digits(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,887,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1391
		AND (l.result <> "" AND digits(l.result) >= 0);
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
		AND (l.result <> "" AND digits(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,160914,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1445
		AND (l.result <> "" AND digits(l.result) >= 0);
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
		AND (l.result <> "" AND digits(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163594,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1444
		AND (l.result <> "" AND digits(l.result) >= 0);
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
		AND (l.result <> "" AND digits(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163703,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1439
		AND (l.result <> "" AND digits(l.result) >= 0);
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
		AND (l.result <> "" AND digits(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163704,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1440
		AND (l.result <> "" AND digits(l.result) >= 0);
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
		AND (l.result <> "" AND digits(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163705,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1441
		AND (l.result <> "" AND digits(l.result) >= 0);
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
		AND (l.result <> "" AND digits(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163706,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1442
		AND (l.result <> "" AND digits(l.result) >= 0);
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
		AND (l.result <> "" AND digits(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163707,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1443
		AND (l.result <> "" AND digits(l.result) >= 0);
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
		AND (l.result <> "" AND digits(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,160912,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1438
		AND (l.result <> "" AND digits(l.result) >= 0);
	/*Migration for Glycemie Provoquée Fasting*/
	/*Start Migration for HCO3 (have concept group)*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163596,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1433
	AND (l.result <> "" AND digits(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163602,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1433 and (l.result <> "" AND digits(l.result) >= 0);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163602
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163596,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1433
	AND (l.result <> "" AND digits(l.result) >= 0);
		
	/*End migration for HCO3*/
	
	/*Start Migration for HDL (have concept group)*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	1007,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1424
	AND (l.result <> "" AND digits(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,1010,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1424 and (l.result <> "" AND digits(l.result) >= 0);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=1010
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1007,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1424
	AND (l.result <> "" AND digits(l.result) >= 0);
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
		AND (l.result <> "" AND digits(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,159644,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1428
		AND (l.result <> "" AND digits(l.result) >= 0);
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
		AND (l.result <> "" AND digits(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1014,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1429
		AND (l.result <> "" AND digits(l.result) >= 0);
	/*End migration for LDH*/
	/*Start migration for LDL (have oncept group)*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	1008,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1425
	AND (l.result <> "" AND digits(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,1010,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1425 and (l.result <> "" AND digits(l.result) >= 0);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=1010
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1008,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1425
	AND (l.result <> "" AND digits(l.result) >= 0);
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
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
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
		AND (l.result <> "" AND digits(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163592,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1413
		AND (l.result <> "" AND digits(l.result) >= 0);
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
		AND (l.result <> "" AND digits(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,159643,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1411
		AND (l.result <> "" AND digits(l.result) >= 0);
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
		AND (l.result <> "" AND digits(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163593,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1427
		AND (l.result <> "" AND digits(l.result) >= 0);
	/*End migration for MBG*/
	/*Start migration for O2 Saturation (have concept group)*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163597,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1434
	AND (l.result <> "" AND digits(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163602,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1434 and (l.result <> "" AND digits(l.result) >= 0);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163602
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163597,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1434
	AND (l.result <> "" AND digits(l.result) >= 0);
	/*End migration for O2 Saturation*/
	/*Start migration for PaCO2 (have concept group)*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163595,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1432
	AND (l.result <> "" AND digits(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163602,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1432 and (l.result <> "" AND digits(l.result) >= 0);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163602
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163595,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1432
	AND (l.result <> "" AND digits(l.result) >= 0);
	/*End migration for PaCO2*/
	/*Start migration for PaO2 (have concept group)*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163598,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1435
	AND (l.result <> "" AND digits(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163602,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1435 and (l.result <> "" AND digits(l.result) >= 0);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163602
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163598,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1435
	AND (l.result <> "" AND digits(l.result) >= 0);
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
		AND (l.result <> "" AND digits(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,161455,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1431
		AND (l.result <> "" AND digits(l.result) >= 0);
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
		AND (l.result <> "" AND digits(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163443,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1400
		AND (l.result <> "" AND digits(l.result) >= 0);
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
		AND (l.result <> "" AND digits(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,785,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1420
		AND (l.result <> "" AND digits(l.result) >= 0);
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
		AND (l.result <> "" AND digits(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,161154,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1412
		AND (l.result <> "" AND digits(l.result) >= 0);
	/*End migration for Phosphore*/
	/*Start migration for Potassium (have concept group)*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	1133,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1408
	AND (l.result <> "" AND digits(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,5473,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1408 and (l.result <> "" AND digits(l.result) >= 0);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=5473
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1133,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1408
	AND (l.result <> "" AND digits(l.result) >= 0);
	/*End migration for Potassium*/
	/*Start migration for Proteines (have concept group)*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	159646,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1392
	AND (l.result <> "" AND digits(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,159645,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1392 and (l.result <> "" AND digits(l.result) >= 0);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=159645
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159646,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1392
	AND (l.result <> "" AND digits(l.result) >= 0);
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
		AND (l.result <> "" AND digits(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,717,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1459
		AND (l.result <> "" AND digits(l.result) >= 0);
	/*End migration for Protéines totales*/
	/*Start Migration for SGOT (AST) (have concept group)*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	653,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1450
	AND (l.result <> "" AND digits(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,953,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1450 and (l.result <> "" AND digits(l.result) >= 0);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=953
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,653,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1450
	AND (l.result <> "" AND digits(l.result) >= 0);
	/*End migration for SGOT (AST)*/
	/*Start migration for SGPT (ALT) (have concept group)*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	654,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1449
	AND (l.result <> "" AND digits(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,953,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1449 and (l.result <> "" AND digits(l.result) >= 0);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=953
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,654,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1449
	AND (l.result <> "" AND digits(l.result) >= 0);
	/*End migration for SGPT (ALT)*/
	/*Start migration for Sodium (have concept group)*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	1132,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1407
	AND (l.result <> "" AND digits(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,5473,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1407 and (l.result <> "" AND digits(l.result) >= 0);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=5473
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1132,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1407
	AND (l.result <> "" AND digits(l.result) >= 0);
	/*End migration for Sodium*/
	/*Start migration for Triglycéride (have concept group)*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	1009,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1455
	AND (l.result <> "" AND digits(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,1010,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1455 and (l.result <> "" AND digits(l.result) >= 0);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=1010
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1009,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1455
	AND (l.result <> "" AND digits(l.result) >= 0);
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
		AND (l.result <> "" AND digits(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,159654,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1430
		AND (l.result <> "" AND digits(l.result) >= 0);
	/*End migration for Triponine I*/
	/*Start migration for Urée (calculée) (have concept group)*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163699,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1447
	AND (l.result <> "" AND digits(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,161488,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1447 and (l.result <> "" AND digits(l.result) >= 0);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=161488
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163699,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1447
	AND (l.result <> "" AND digits(l.result) >= 0);
	/*End migration for Urée (calculée)*/
	/*Start migration for VLDL (have concept group)*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	1298,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1426
	AND (l.result <> "" AND digits(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,1010,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1426 and (l.result <> "" AND digits(l.result) >= 0);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=1010
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1298,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1426
	AND (l.result <> "" AND digits(l.result) >= 0);
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
		AND (l.result <> "" AND digits(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163437,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1396
		AND (l.result <> "" AND digits(l.result) >= 0);
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
		AND (l.result <> "" AND digits(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163438,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1397
		AND (l.result <> "" AND digits(l.result) >= 0);
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
		AND (l.result <> "" AND digits(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163439,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1398
		AND (l.result <> "" AND digits(l.result) >= 0);
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
		AND (l.result <> "" AND digits(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163442,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1399
		AND (l.result <> "" AND digits(l.result) >= 0);
	/*End migration for ϒ globuline*/
	/*Ending migration for Biochimie tests Part*/
	/*Start Migration for Cytobacteriologie part*/
		/*Start migration for Bacteries (Pour Femme)(have concept group)*/
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163645,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.patient p
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and l.patientID=p.patientID
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	and p.sex=1
	AND l.labID=1483
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,161458,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l, itech.patient p 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum 
	and l.patientID=p.patientID and p.sex=1
	and c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1483 
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=161458
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163645,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
	CASE WHEN (
				(l.result like lower("N%"))
				OR (l.result2 like lower("N"))
				OR (l.result3 like lower("N%"))
				OR (l.result4 like lower("N%"))
			  ) THEN 664
		WHEN (
				(l.result like ("1%") OR l.result like lower("UN%"))
				OR (l.result2 like ("1%") OR l.result2 like lower("UN%"))
				OR (l.result3 like ("1%") OR l.result3 like lower("UN%"))
				OR (l.result4 like ("1%") OR l.result4 like lower("UN%"))
			  ) THEN 1362
		WHEN (
				(l.result like ("2%") OR l.result like lower("DE%"))
				OR (l.result2 like ("2%") OR l.result2 like lower("DE%"))
				OR (l.result3 like ("2%") OR l.result3 like lower("DE%"))
				OR (l.result4 like ("2%") OR l.result4 like lower("DE%"))
			  ) THEN 1363
		WHEN (
				(l.result like ("3%") OR l.result like lower("TROIS%"))
				OR (l.result2 like ("3%") OR l.result2 like lower("TROIS%"))
				OR (l.result3 like ("3%") OR l.result3 like lower("TROIS%"))
				OR (l.result4 like ("3%") OR l.result4 like lower("TROIS%"))
			  ) THEN 1364
			  
	END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg, itech.patient p 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.patientID=p.patientID
	AND p.sex=1
	AND l.labID=1483
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
		/*End migration for Bacteries*/
		/*Start migration for Bacteries (Pour Homme)(have concept group)*/
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163645,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.patient p
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and l.patientID=p.patientID
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	and p.sex=2
	AND l.labID=1483
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163652,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l, itech.patient p 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum 
	and l.patientID=p.patientID and p.sex=2
	and c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1483 
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163652
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163645,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
	CASE WHEN (
				(l.result like lower("N%"))
				OR (l.result2 like lower("N"))
				OR (l.result3 like lower("N%"))
				OR (l.result4 like lower("N%"))
			  ) THEN 664
		WHEN (
				(l.result like ("1%") OR l.result like lower("UN%"))
				OR (l.result2 like ("1%") OR l.result2 like lower("UN%"))
				OR (l.result3 like ("1%") OR l.result3 like lower("UN%"))
				OR (l.result4 like ("1%") OR l.result4 like lower("UN%"))
			  ) THEN 1362
		WHEN (
				(l.result like ("2%") OR l.result like lower("DE%"))
				OR (l.result2 like ("2%") OR l.result2 like lower("DE%"))
				OR (l.result3 like ("2%") OR l.result3 like lower("DE%"))
				OR (l.result4 like ("2%") OR l.result4 like lower("DE%"))
			  ) THEN 1363
		WHEN (
				(l.result like ("3%") OR l.result like lower("TROIS%"))
				OR (l.result2 like ("3%") OR l.result2 like lower("TROIS%"))
				OR (l.result3 like ("3%") OR l.result3 like lower("TROIS%"))
				OR (l.result4 like ("3%") OR l.result4 like lower("TROIS%"))
			  ) THEN 1364
			  
	END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg, itech.patient p 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.patientID=p.patientID
	AND p.sex=2
	AND l.labID=1483
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
		
		/*End migration for Bacteries*/
		/*Start migration for Cellules Epitheliales*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163650,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1490
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163650,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (
				(l.result like lower("N%"))
				OR (l.result2 like lower("N%"))
				OR (l.result3 like lower("N%"))
				OR (l.result4 like lower("N%"))
			  ) THEN 664
		WHEN (
				(l.result like ("1%") OR l.result like lower("UN%") OR l.result like lower("+"))
				OR (l.result2 like ("1%") OR l.result2 like lower("UN%") OR l.result2 like lower("+"))
				OR (l.result3 like ("1%") OR l.result3 like lower("UN%") OR l.result3 like lower("+"))
				OR (l.result4 like ("1%") OR l.result4 like lower("UN%") OR l.result4 like lower("+"))
			  ) THEN 1362
		WHEN (
				(l.result like ("2%") OR l.result like lower("DE%") OR l.result like lower("++"))
				OR (l.result2 like ("2%") OR l.result2 like lower("DE%") OR l.result2 like lower("++"))
				OR (l.result3 like ("2%") OR l.result3 like lower("DE%") OR l.result3 like lower("++"))
				OR (l.result4 like ("2%") OR l.result4 like lower("DE%") OR l.result4 like lower("++"))
			  ) THEN 1363
		WHEN (
				(l.result like ("3%") OR l.result like lower("TROIS%") OR l.result like lower("+++") )
				OR (l.result2 like ("3%") OR l.result2 like lower("TROIS%") OR l.result2 like lower("+++"))
				OR (l.result3 like ("3%") OR l.result3 like lower("TROIS%") OR l.result3 like lower("+++"))
				OR (l.result4 like ("3%") OR l.result4 like lower("TROIS%") OR l.result4 like lower("+++"))
			  ) THEN 1364
			  
	END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1490
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
		/*End migration for Cellules Epitheliales*/
		
		/*Start migration for Cholera Test rapide*/
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
		AND l.labID=1513
		AND (l.result <> "" AND digits(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163442,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result),l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1513
		AND (l.result <> "" AND digits(l.result) >= 0);
		/*End migration for Cholera Test rapide*/
		/*Start migration for Coloration de Gram*/
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		161454,1,e.createDate,UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1526
		AND (
			  (l.result <> "" AND l.result is not null) 
			   OR (l.result2 <> "" AND l.result2 is not null)
			   OR (l.result3 <> "" AND l.result3 is not null)
			   OR (l.result4 <> "" AND l.result4 is not null)
			);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_text,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,161454,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
		CASE WHEN (l.result <> "" AND l.result is not null) THEN l.result
		WHEN (l.result2 <> "" AND l.result2 is not null) THEN l.result2
		WHEN (l.result3 <> "" AND l.result3 is not null) THEN l.result3
		WHEN (l.result4 <> "" AND l.result4 is not null) THEN l.result4
		END,l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1526
		AND (
			  (l.result <> "" AND l.result is not null) 
			   OR (l.result2 <> "" AND l.result2 is not null)
			   OR (l.result3 <> "" AND l.result3 is not null)
			   OR (l.result4 <> "" AND l.result4 is not null)
			);
		/*End migration for Coloration de Gram*/
		/*Start migration Compte de spermes (have concept group)*/
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163661,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1520
	AND (l.result <> "" AND digits(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,161468,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1520 and (l.result <> "" AND digits(l.result) >= 0);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=161468
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163661,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1520
	AND (l.result <> "" AND digits(l.result) >= 0);
		/*End migration for Compte de spermes*/
		/*Start migration for Couleur (have concept group)*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		163657,1,e.createDate,UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1515
		AND (
			  (l.result <> "" AND l.result is not null) 
			   OR (l.result2 <> "" AND l.result2 is not null)
			   OR (l.result3 <> "" AND l.result3 is not null)
			   OR (l.result4 <> "" AND l.result4 is not null)
			);
		
		 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,161468,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1515
	AND (
			  (l.result <> "" AND l.result is not null) 
			   OR (l.result2 <> "" AND l.result2 is not null)
			   OR (l.result3 <> "" AND l.result3 is not null)
			   OR (l.result4 <> "" AND l.result4 is not null)
			);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=161468
	GROUP BY openmrs.obs.person_id,encounter_id;
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163657,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
		CASE WHEN ((l.result like lower("%ORANGE%")) OR (l.result2 like lower("%ORANGE%")) 
		OR (l.result3 like lower("%ORANGE%")) OR (l.result4 like lower("%ORANGE%"))) THEN 163656
		WHEN ((l.result like lower("%BLANC JAUN%")) OR (l.result2 like lower("%BLANC JAUN%")) 
		OR (l.result3 like lower("%BLANC JAUN%")) OR (l.result4 like lower("%BLANC JAUN%"))) THEN 163655
		WHEN ((l.result like lower("JAUNE")) OR (l.result2 like lower("JAUNE")) 
		OR (l.result3 like lower("JAUNE")) OR (l.result4 like lower("JAUNE"))) THEN 160910
		WHEN ((l.result like lower("ROUGE")) OR (l.result2 like lower("ROUGE")) 
		OR (l.result3 like lower("ROUGE")) OR (l.result4 like lower("ROUGE"))) THEN 127778
		WHEN ((l.result like lower("JAUNE CLAIR")) OR (l.result2 like lower("JAUNE CLAIR")) 
		OR (l.result3 like lower("JAUNE CLAIR")) OR (l.result4 like lower("JAUNE CLAIR"))) THEN 162097
		WHEN ((l.result like lower("JAUNE FONC%")) OR (l.result2 like lower("JAUNE FONC%")) 
		OR (l.result3 like lower("JAUNE FONC%")) OR (l.result4 like lower("JAUNE FONC%"))) THEN 162098
		WHEN ((l.result like lower("MARRON")) OR (l.result2 like lower("MARRON")) 
		OR (l.result3 like lower("MARRON")) OR (l.result4 like lower("MARRON"))) THEN 162100
		END,l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND c.encounter_id=cg.encounter_id
		AND c.patient_id=cg.person_id
		AND l.labID=1515
		AND (
			  (l.result <> "" AND l.result is not null) 
			   OR (l.result2 <> "" AND l.result2 is not null)
			   OR (l.result3 <> "" AND l.result3 is not null)
			   OR (l.result4 <> "" AND l.result4 is not null)
			);
	
   
		/*End migration for Couleur*/
		/*Start migration for Filaments Myceliens*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		163649,1,e.createDate,UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1489
		AND (
			  (l.result <> "" AND l.result is not null) 
			   OR (l.result2 <> "" AND l.result2 is not null)
			   OR (l.result3 <> "" AND l.result3 is not null)
			   OR (l.result4 <> "" AND l.result4 is not null)
			);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163649,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
		CASE WHEN (
				(l.result like lower("NEG%"))
				OR (l.result2 like lower("NEG%"))
				OR (l.result3 like lower("NEG%"))
				OR (l.result4 like lower("NEG%"))
			  ) THEN 664
		WHEN (
				(l.result like ("1%") OR l.result like lower("UN%"))
				OR (l.result2 like ("1%") OR l.result2 like lower("UN%"))
				OR (l.result3 like ("1%") OR l.result3 like lower("UN%"))
				OR (l.result4 like ("1%") OR l.result4 like lower("UN%"))
			  ) THEN 1362
		WHEN (
				(l.result like ("2%") OR l.result like lower("DE%"))
				OR (l.result2 like ("2%") OR l.result2 like lower("DE%"))
				OR (l.result3 like ("2%") OR l.result3 like lower("DE%"))
				OR (l.result4 like ("2%") OR l.result4 like lower("DE%"))
			  ) THEN 1363
		WHEN (
				(l.result like ("3%") OR l.result like lower("TROIS%"))
				OR (l.result2 like ("3%") OR l.result2 like lower("TROIS%"))
				OR (l.result3 like ("3%") OR l.result3 like lower("TROIS%"))
				OR (l.result4 like ("3%") OR l.result4 like lower("TROIS%"))
			  ) THEN 1364
			  
	END,l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1489
		AND (
			  (l.result <> "" AND l.result is not null) 
			   OR (l.result2 <> "" AND l.result2 is not null)
			   OR (l.result3 <> "" AND l.result3 is not null)
			   OR (l.result4 <> "" AND l.result4 is not null)
			);
		/*End migration for Filaments Myceliens*/
		/*Start migration for Formes normales (have concept group)(a corriger dans eclipse)*/
		 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163662,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1521
	AND (l.result <> "" AND digits(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,161468,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1521 and (l.result <> "" AND digits(l.result) >= 0);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=161468
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163662,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1521
	AND (l.result <> "" AND digits(l.result) >= 0);
		/*End migration for Formes anormales*/
		
		/*Start migration for Fructose (have concept group)*/
		 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163659,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1518
	AND (l.result <> "" AND digits(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,161468,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1518 and (l.result <> "" AND digits(l.result) >= 0);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=161468
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163659,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1518
	AND (l.result <> "" AND digits(l.result) >= 0);
		/*End migration for Fructose*/
		/*Start migration for Globules Blancs (pour femmes) (have concept group)*/
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163605,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.patient p
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and l.patientID=p.patientID
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	and p.sex=1
	AND l.labID=1479
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,161458,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l, itech.patient p 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum 
	and l.patientID=p.patientID and p.sex=1
	and c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1479
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=161458
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163605,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
	CASE WHEN (
				(l.result like lower("N%"))
				OR (l.result2 like lower("N"))
				OR (l.result3 like lower("N%"))
				OR (l.result4 like lower("N%"))
			  ) THEN 664
		WHEN (
				(l.result like ("1%") OR l.result like lower("UN%"))
				OR (l.result2 like ("1%") OR l.result2 like lower("UN%"))
				OR (l.result3 like ("1%") OR l.result3 like lower("UN%"))
				OR (l.result4 like ("1%") OR l.result4 like lower("UN%"))
			  ) THEN 1362
		WHEN (
				(l.result like ("2%") OR l.result like lower("DE%"))
				OR (l.result2 like ("2%") OR l.result2 like lower("DE%"))
				OR (l.result3 like ("2%") OR l.result3 like lower("DE%"))
				OR (l.result4 like ("2%") OR l.result4 like lower("DE%"))
			  ) THEN 1363
		WHEN (
				(l.result like ("3%") OR l.result like lower("TROIS%"))
				OR (l.result2 like ("3%") OR l.result2 like lower("TROIS%"))
				OR (l.result3 like ("3%") OR l.result3 like lower("TROIS%"))
				OR (l.result4 like ("3%") OR l.result4 like lower("TROIS%"))
			  ) THEN 1364
			  
	END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg, itech.patient p 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.patientID=p.patientID
	AND p.sex=1
	AND l.labID=1479
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
		/*End migration for Globules Blancs (pour femmes)*/
		/*Start migration for Globules Blancs (pour hommes) (have concept group)*/
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163605,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.patient p
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and l.patientID=p.patientID
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	and p.sex=2
	AND l.labID=1479
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163652,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l, itech.patient p 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum 
	and l.patientID=p.patientID and p.sex=2
	and c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1479
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163652
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163605,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
	CASE WHEN (
				(l.result like lower("N%"))
				OR (l.result2 like lower("N"))
				OR (l.result3 like lower("N%"))
				OR (l.result4 like lower("N%"))
			  ) THEN 664
		WHEN (
				(l.result like ("1%") OR l.result like lower("UN%"))
				OR (l.result2 like ("1%") OR l.result2 like lower("UN%"))
				OR (l.result3 like ("1%") OR l.result3 like lower("UN%"))
				OR (l.result4 like ("1%") OR l.result4 like lower("UN%"))
			  ) THEN 1362
		WHEN (
				(l.result like ("2%") OR l.result like lower("DE%"))
				OR (l.result2 like ("2%") OR l.result2 like lower("DE%"))
				OR (l.result3 like ("2%") OR l.result3 like lower("DE%"))
				OR (l.result4 like ("2%") OR l.result4 like lower("DE%"))
			  ) THEN 1363
		WHEN (
				(l.result like ("3%") OR l.result like lower("TROIS%"))
				OR (l.result2 like ("3%") OR l.result2 like lower("TROIS%"))
				OR (l.result3 like ("3%") OR l.result3 like lower("TROIS%"))
				OR (l.result4 like ("3%") OR l.result4 like lower("TROIS%"))
			  ) THEN 1364
			  
	END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg, itech.patient p 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.patientID=p.patientID
	AND p.sex=2
	AND l.labID=1479
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
		/*End migration for Globules Blancs*/
		/*Start migration for Globules Rouges (pour femmes) (have concept group)*/
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163604,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.patient p
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and l.patientID=p.patientID
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	and p.sex=1
	AND l.labID=1480
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,161458,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l, itech.patient p 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum 
	and l.patientID=p.patientID and p.sex=1
	and c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1480
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=161458
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163604,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
	CASE WHEN (
				(l.result like lower("N%"))
				OR (l.result2 like lower("N%"))
				OR (l.result3 like lower("N%"))
				OR (l.result4 like lower("N%"))
			  ) THEN 664
		WHEN (
				(l.result like ("1%") OR l.result like lower("UN%"))
				OR (l.result2 like ("1%") OR l.result2 like lower("UN%"))
				OR (l.result3 like ("1%") OR l.result3 like lower("UN%"))
				OR (l.result4 like ("1%") OR l.result4 like lower("UN%"))
			  ) THEN 1362
		WHEN (
				(l.result like ("2%") OR l.result like lower("DE%"))
				OR (l.result2 like ("2%") OR l.result2 like lower("DE%"))
				OR (l.result3 like ("2%") OR l.result3 like lower("DE%"))
				OR (l.result4 like ("2%") OR l.result4 like lower("DE%"))
			  ) THEN 1363
		WHEN (
				(l.result like ("3%") OR l.result like lower("TROIS%"))
				OR (l.result2 like ("3%") OR l.result2 like lower("TROIS%"))
				OR (l.result3 like ("3%") OR l.result3 like lower("TROIS%"))
				OR (l.result4 like ("3%") OR l.result4 like lower("TROIS%"))
			  ) THEN 1364
			  
	END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg, itech.patient p 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.patientID=p.patientID
	AND p.sex=1
	AND l.labID=1480
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
		/*End migration for Globules Rouges (pour femmes)*/
		/*Start migration for Globules Rouges (pour hommes) (have concept group)*/
		
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163604,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.patient p
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and l.patientID=p.patientID
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	and p.sex=2
	AND l.labID=1480
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163652,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l, itech.patient p 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum 
	and l.patientID=p.patientID and p.sex=2
	and c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1480
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163652
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163604,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
	CASE WHEN (
				(l.result like lower("N%"))
				OR (l.result2 like lower("N%"))
				OR (l.result3 like lower("N%"))
				OR (l.result4 like lower("N%"))
			  ) THEN 664
		WHEN (
				(l.result like ("1%") OR l.result like lower("UN%"))
				OR (l.result2 like ("1%") OR l.result2 like lower("UN%"))
				OR (l.result3 like ("1%") OR l.result3 like lower("UN%"))
				OR (l.result4 like ("1%") OR l.result4 like lower("UN%"))
			  ) THEN 1362
		WHEN (
				(l.result like ("2%") OR l.result like lower("DE%"))
				OR (l.result2 like ("2%") OR l.result2 like lower("DE%"))
				OR (l.result3 like ("2%") OR l.result3 like lower("DE%"))
				OR (l.result4 like ("2%") OR l.result4 like lower("DE%"))
			  ) THEN 1363
		WHEN (
				(l.result like ("3%") OR l.result like lower("TROIS%"))
				OR (l.result2 like ("3%") OR l.result2 like lower("TROIS%"))
				OR (l.result3 like ("3%") OR l.result3 like lower("TROIS%"))
				OR (l.result4 like ("3%") OR l.result4 like lower("TROIS%"))
			  ) THEN 1364
			  
	END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg, itech.patient p 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.patientID=p.patientID
	AND p.sex=2
	AND l.labID=1480
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
		/*End migration for Globules Rouges*/
		/*Start migration for KOH*/
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		161453,1,e.createDate,UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1491
		AND (
			  (l.result <> "" AND l.result is not null) 
			   OR (l.result2 <> "" AND l.result2 is not null)
			   OR (l.result3 <> "" AND l.result3 is not null)
			   OR (l.result4 <> "" AND l.result4 is not null)
			);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_text,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,161453,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
		CASE WHEN (l.result <> "" AND l.result is not null) THEN l.result
		WHEN (l.result2 <> "" AND l.result2 is not null) THEN l.result2
		WHEN (l.result3 <> "" AND l.result3 is not null) THEN l.result3
		WHEN (l.result4 <> "" AND l.result4 is not null) THEN l.result4
		END,l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1491
		AND (
			  (l.result <> "" AND l.result is not null) 
			   OR (l.result2 <> "" AND l.result2 is not null)
			   OR (l.result3 <> "" AND l.result3 is not null)
			   OR (l.result4 <> "" AND l.result4 is not null)
			);
		/*End migration for KOH*/
		/*Migration for Levures Bourgeonantes (have concept group) (pour femmes)*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163647,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.patient p
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and l.patientID=p.patientID
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	and p.sex=1
	AND l.labID=1485
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,161458,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l, itech.patient p 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum 
	and l.patientID=p.patientID and p.sex=1
	and c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1485
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=161458
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163647,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
	CASE WHEN (
				(l.result like lower("N%"))
				OR (l.result2 like lower("N"))
				OR (l.result3 like lower("N%"))
				OR (l.result4 like lower("N%"))
			  ) THEN 664
		WHEN (
				(l.result like ("1%") OR l.result like lower("UN%"))
				OR (l.result2 like ("1%") OR l.result2 like lower("UN%"))
				OR (l.result3 like ("1%") OR l.result3 like lower("UN%"))
				OR (l.result4 like ("1%") OR l.result4 like lower("UN%"))
			  ) THEN 1362
		WHEN (
				(l.result like ("2%") OR l.result like lower("DE%"))
				OR (l.result2 like ("2%") OR l.result2 like lower("DE%"))
				OR (l.result3 like ("2%") OR l.result3 like lower("DE%"))
				OR (l.result4 like ("2%") OR l.result4 like lower("DE%"))
			  ) THEN 1363
		WHEN (
				(l.result like ("3%") OR l.result like lower("TROIS%"))
				OR (l.result2 like ("3%") OR l.result2 like lower("TROIS%"))
				OR (l.result3 like ("3%") OR l.result3 like lower("TROIS%"))
				OR (l.result4 like ("3%") OR l.result4 like lower("TROIS%"))
			  ) THEN 1364
			  
	END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg, itech.patient p 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.patientID=p.patientID
	AND p.sex=1
	AND l.labID=1485
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
		
		/*End Levures Bourgeonantes pour femmes*/
		
		/*Migration for Levures Bourgeonantes (have concept group) (pour hommes)*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163647,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.patient p
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and l.patientID=p.patientID
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	and p.sex=2
	AND l.labID=1485
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163652,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l, itech.patient p 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum 
	and l.patientID=p.patientID and p.sex=2
	and c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1485
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163652
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163647,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
	CASE WHEN (
				(l.result like lower("N%"))
				OR (l.result2 like lower("N"))
				OR (l.result3 like lower("N%"))
				OR (l.result4 like lower("N%"))
			  ) THEN 664
		WHEN (
				(l.result like ("1%") OR l.result like lower("UN%"))
				OR (l.result2 like ("1%") OR l.result2 like lower("UN%"))
				OR (l.result3 like ("1%") OR l.result3 like lower("UN%"))
				OR (l.result4 like ("1%") OR l.result4 like lower("UN%"))
			  ) THEN 1362
		WHEN (
				(l.result like ("2%") OR l.result like lower("DE%"))
				OR (l.result2 like ("2%") OR l.result2 like lower("DE%"))
				OR (l.result3 like ("2%") OR l.result3 like lower("DE%"))
				OR (l.result4 like ("2%") OR l.result4 like lower("DE%"))
			  ) THEN 1363
		WHEN (
				(l.result like ("3%") OR l.result like lower("TROIS%"))
				OR (l.result2 like ("3%") OR l.result2 like lower("TROIS%"))
				OR (l.result3 like ("3%") OR l.result3 like lower("TROIS%"))
				OR (l.result4 like ("3%") OR l.result4 like lower("TROIS%"))
			  ) THEN 1364
			  
	END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg, itech.patient p 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.patientID=p.patientID
	AND p.sex=2
	AND l.labID=1485
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
		/*End Levures Bourgeonantes pour hommes*/
		/*Migration for levures simples (pour femmes) (have concept group)*/
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163646,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.patient p
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and l.patientID=p.patientID
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	and p.sex=1
	AND l.labID=1476
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,161458,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l, itech.patient p 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum 
	and l.patientID=p.patientID and p.sex=1
	and c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1476
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=161458
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163646,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
	CASE WHEN (
				(l.result like lower("N%"))
				OR (l.result2 like lower("N"))
				OR (l.result3 like lower("N%"))
				OR (l.result4 like lower("N%"))
			  ) THEN 664
		WHEN (
				(l.result like ("1%") OR l.result like lower("UN%"))
				OR (l.result2 like ("1%") OR l.result2 like lower("UN%"))
				OR (l.result3 like ("1%") OR l.result3 like lower("UN%"))
				OR (l.result4 like ("1%") OR l.result4 like lower("UN%"))
			  ) THEN 1362
		WHEN (
				(l.result like ("2%") OR l.result like lower("DE%"))
				OR (l.result2 like ("2%") OR l.result2 like lower("DE%"))
				OR (l.result3 like ("2%") OR l.result3 like lower("DE%"))
				OR (l.result4 like ("2%") OR l.result4 like lower("DE%"))
			  ) THEN 1363
		WHEN (
				(l.result like ("3%") OR l.result like lower("TROIS%"))
				OR (l.result2 like ("3%") OR l.result2 like lower("TROIS%"))
				OR (l.result3 like ("3%") OR l.result3 like lower("TROIS%"))
				OR (l.result4 like ("3%") OR l.result4 like lower("TROIS%"))
			  ) THEN 1364
			  
	END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg, itech.patient p 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.patientID=p.patientID
	AND p.sex=1
	AND l.labID=1476
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
		/*END migration for levures simples (pour femmes)*/
		/*Migration for levures simples (pour hommes)*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163646,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.patient p
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and l.patientID=p.patientID
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	and p.sex=1
	AND l.labID=1476
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163652,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l, itech.patient p 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum 
	and l.patientID=p.patientID and p.sex=1
	and c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1476
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163652
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163646,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
	CASE WHEN (
				(l.result like lower("N%"))
				OR (l.result2 like lower("N"))
				OR (l.result3 like lower("N%"))
				OR (l.result4 like lower("N%"))
			  ) THEN 664
		WHEN (
				(l.result like ("1%") OR l.result like lower("UN%"))
				OR (l.result2 like ("1%") OR l.result2 like lower("UN%"))
				OR (l.result3 like ("1%") OR l.result3 like lower("UN%"))
				OR (l.result4 like ("1%") OR l.result4 like lower("UN%"))
			  ) THEN 1362
		WHEN (
				(l.result like ("2%") OR l.result like lower("DE%"))
				OR (l.result2 like ("2%") OR l.result2 like lower("DE%"))
				OR (l.result3 like ("2%") OR l.result3 like lower("DE%"))
				OR (l.result4 like ("2%") OR l.result4 like lower("DE%"))
			  ) THEN 1363
		WHEN (
				(l.result like ("3%") OR l.result like lower("TROIS%"))
				OR (l.result2 like ("3%") OR l.result2 like lower("TROIS%"))
				OR (l.result3 like ("3%") OR l.result3 like lower("TROIS%"))
				OR (l.result4 like ("3%") OR l.result4 like lower("TROIS%"))
			  ) THEN 1364
			  
	END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg, itech.patient p 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.patientID=p.patientID
	AND p.sex=1
	AND l.labID=1476
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
		/*End migration for levures simples (pour hommes)*/
		/*Starting migration for Liquefaction (have concept group)*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163658,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1516
	AND (l.result <> "" AND digits(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,161468,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1516 and (l.result <> "" AND digits(l.result) >= 0);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=161468
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163658,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1516
	AND (l.result <> "" AND digits(l.result) >= 0);
		/*End migration for Liquefaction*/
	/*Start migration for Motilite 1 heure*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		163663,1,e.createDate,
		UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1524
		AND (l.result <> "" AND digits(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163663,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,l.result,l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1524
		AND (l.result <> "" AND digits(l.result) >= 0);
	/*End migration for Motilite 1 heure*/
	/*Start migration for ph*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		161455,1,e.createDate,
		UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1517
		AND (l.result <> "" AND digits(l.result) >= 0);
		
		
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,161455,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,l.result,l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1517
		AND (l.result <> "" AND digits(l.result) >= 0);
	/*End migration for ph*/
	/*Start migration for Test de Rivalta*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163653,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1492
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	 
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163653,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (
				(l.result like lower("N%"))
				OR (l.result2 like lower("N"))
				OR (l.result3 like lower("N%"))
				OR (l.result4 like lower("N%"))
			  ) THEN 664
		WHEN (
				(l.result like lower("POS%"))
				OR (l.result2 like lower("POS%"))
				OR (l.result3 like lower("POS%"))
				OR (l.result4 like lower("POS%"))
			  ) THEN 703
		WHEN (
				(l.result like lower("IND%"))
				OR (l.result2 like lower("IND%"))
				OR (l.result3 like lower("IND%"))
				OR (l.result4 like lower("IND%"))
			  ) THEN 1138
			  
	END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1492
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*End migration for Test de Rivalta*/
	/*Migration for Trichomonas hominis (have concept group)*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163651,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1486
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163652,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum
	and c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1486
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163652
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163651,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
	CASE WHEN (
				(l.result like lower("N%"))
				OR (l.result2 like lower("N"))
				OR (l.result3 like lower("N%"))
				OR (l.result4 like lower("N%"))
			  ) THEN 664
		WHEN (
				(l.result like ("1%") OR l.result like lower("UN%"))
				OR (l.result2 like ("1%") OR l.result2 like lower("UN%"))
				OR (l.result3 like ("1%") OR l.result3 like lower("UN%"))
				OR (l.result4 like ("1%") OR l.result4 like lower("UN%"))
			  ) THEN 1362
		WHEN (
				(l.result like ("2%") OR l.result like lower("DE%"))
				OR (l.result2 like ("2%") OR l.result2 like lower("DE%"))
				OR (l.result3 like ("2%") OR l.result3 like lower("DE%"))
				OR (l.result4 like ("2%") OR l.result4 like lower("DE%"))
			  ) THEN 1363
		WHEN (
				(l.result like ("3%") OR l.result like lower("TROIS%"))
				OR (l.result2 like ("3%") OR l.result2 like lower("TROIS%"))
				OR (l.result3 like ("3%") OR l.result3 like lower("TROIS%"))
				OR (l.result4 like ("3%") OR l.result4 like lower("TROIS%"))
			  ) THEN 1364
			  
	END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1486
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*END migration for Trichomonas hominis*/
	/*Start migration for Trichomonas vaginalis*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163648,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1478
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,161458,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum
	and c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1478
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=161458
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163648,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
	CASE WHEN (
				(l.result like lower("N%"))
				OR (l.result2 like lower("N"))
				OR (l.result3 like lower("N%"))
				OR (l.result4 like lower("N%"))
			  ) THEN 664
		WHEN (
				(l.result like ("1%") OR l.result like lower("UN%"))
				OR (l.result2 like ("1%") OR l.result2 like lower("UN%"))
				OR (l.result3 like ("1%") OR l.result3 like lower("UN%"))
				OR (l.result4 like ("1%") OR l.result4 like lower("UN%"))
			  ) THEN 1362
		WHEN (
				(l.result like ("2%") OR l.result like lower("DE%"))
				OR (l.result2 like ("2%") OR l.result2 like lower("DE%"))
				OR (l.result3 like ("2%") OR l.result3 like lower("DE%"))
				OR (l.result4 like ("2%") OR l.result4 like lower("DE%"))
			  ) THEN 1363
		WHEN (
				(l.result like ("3%") OR l.result like lower("TROIS%"))
				OR (l.result2 like ("3%") OR l.result2 like lower("TROIS%"))
				OR (l.result3 like ("3%") OR l.result3 like lower("TROIS%"))
				OR (l.result4 like ("3%") OR l.result4 like lower("TROIS%"))
			  ) THEN 1364
			  
	END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1478
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*End migration for Trichomonas vaginalis*/
	
	/*Start Migration for Volume (have concept group)*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163660,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1519
	AND (l.result <> "" AND digits(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,161468,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1519 and (l.result <> "" AND digits(l.result) >= 0);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=161468
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163660,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1519
	AND (l.result <> "" AND digits(l.result) >= 0);
	/*End migration for Volume*/
	
	/*End Migration for Cytobacteriologie part*/
	
	/*Start migration for Bacteriologie Part*/
		/*Start migration for Camp-test */
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163675,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1504
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163679,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum
	and c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1504
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163679
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163675,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
	CASE WHEN (l.result <> "" AND l.result is not null) THEN l.result
		WHEN (l.result2 <> "" AND l.result2 is not null) THEN l.result2	
		WHEN (l.result3 <> "" AND l.result3 is not null) THEN l.result3
		WHEN (l.result4 <> "" AND l.result4 is not null) THEN l.result4
	END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1504
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	    /*End migration for Camp-test*/
		/*Start migration for Catalase*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163664,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1493
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163679,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum
	and c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1493
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163679
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163664,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
	CASE WHEN (l.result <> "" AND l.result is not null) THEN l.result
		WHEN (l.result2 <> "" AND l.result2 is not null) THEN l.result2	
		WHEN (l.result3 <> "" AND l.result3 is not null) THEN l.result3
		WHEN (l.result4 <> "" AND l.result4 is not null) THEN l.result4
	END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1493
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
		/*End migration for Catalase*/
		/*Start migration for Coagulase libre*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163666,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1495
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163679,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum
	and c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1495
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163679
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163666,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
	CASE WHEN (l.result <> "" AND l.result is not null) THEN l.result
		WHEN (l.result2 <> "" AND l.result2 is not null) THEN l.result2	
		WHEN (l.result3 <> "" AND l.result3 is not null) THEN l.result3
		WHEN (l.result4 <> "" AND l.result4 is not null) THEN l.result4
	END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1495
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
		/*End migration for Coagulase libre*/
		/*Start migration for Coloration à l’acridine orange*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163678,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1509
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163679,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum
	and c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1509
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163679
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163678,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
	CASE WHEN (l.result <> "" AND l.result is not null) THEN l.result
		WHEN (l.result2 <> "" AND l.result2 is not null) THEN l.result2	
		WHEN (l.result3 <> "" AND l.result3 is not null) THEN l.result3
		WHEN (l.result4 <> "" AND l.result4 is not null) THEN l.result4
	END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1509
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
		
		/*End migration for Coloration à l’acridine orange*/
		/*Start migration for Coloration à l’auramine*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163677,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1508
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163679,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum
	and c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1508
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163679
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163677,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
	CASE WHEN (l.result <> "" AND l.result is not null) THEN l.result
		WHEN (l.result2 <> "" AND l.result2 is not null) THEN l.result2	
		WHEN (l.result3 <> "" AND l.result3 is not null) THEN l.result3
		WHEN (l.result4 <> "" AND l.result4 is not null) THEN l.result4
	END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1508
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
		/*End migration for Coloration à l’auramine*/
		
		/*Start Migration for Coloration de Gram*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	161454,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1506
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163679,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum
	and c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1506
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163679
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161454,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
	CASE WHEN (l.result <> "" AND l.result is not null) THEN l.result
		WHEN (l.result2 <> "" AND l.result2 is not null) THEN l.result2	
		WHEN (l.result3 <> "" AND l.result3 is not null) THEN l.result3
		WHEN (l.result4 <> "" AND l.result4 is not null) THEN l.result4
	END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1506
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
		/*End migration for Coloration de Gram*/
		
		/*Start migration for Coloration de Kinyoun*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	161448,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1510
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163679,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum
	and c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1510
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163679
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161448,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
	CASE WHEN (l.result <> "" AND l.result is not null) THEN l.result
		WHEN (l.result2 <> "" AND l.result2 is not null) THEN l.result2	
		WHEN (l.result3 <> "" AND l.result3 is not null) THEN l.result3
		WHEN (l.result4 <> "" AND l.result4 is not null) THEN l.result4
	END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1510
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
		/*End migration for Coloration de Kinyoun*/
		/*Start migration for Coloration de Ziehl-Neelsen (Correction imp)*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	307,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1507
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163679,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum
	and c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1507
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163679
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,307,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
	CASE WHEN (
				(l.result like lower("N%"))
				OR (l.result2 like lower("N%"))
				OR (l.result3 like lower("N%"))
				OR (l.result4 like lower("N%"))
			  ) THEN 664
		WHEN (
				(l.result like lower("POS%"))
				OR (l.result2 like lower("POS%"))
				OR (l.result3 like lower("POS%"))
				OR (l.result4 like lower("POS%"))
			  ) THEN 703
		WHEN (
				(l.result like ("1%") OR l.result like lower("UN%") OR l.result like ("+"))
				OR (l.result2 like ("1%") OR l.result2 like lower("UN%") OR l.result like ("+"))
				OR (l.result3 like ("1%") OR l.result3 like lower("UN%") OR l.result like ("+"))
				OR (l.result4 like ("1%") OR l.result4 like lower("UN%") OR l.result like ("+"))
			  ) THEN 1362
		WHEN (
				(l.result like ("2%") OR l.result like lower("DE%") OR l.result like ("++"))
				OR (l.result2 like ("2%") OR l.result2 like lower("DE%") OR l.result2 like ("++"))
				OR (l.result3 like ("2%") OR l.result3 like lower("DE%") OR l.result3 like ("++"))
				OR (l.result4 like ("2%") OR l.result4 like lower("DE%") OR l.result4 like ("+++"))
			  ) THEN 1363
		WHEN (
				(l.result like ("3%") OR l.result like lower("TROIS%") OR l.result like ("+++"))
				OR (l.result2 like ("3%") OR l.result2 like lower("TROIS%") OR l.result2 like ("+++"))
				OR (l.result3 like ("3%") OR l.result3 like lower("TROIS%") OR l.result3 like ("+++"))
				OR (l.result4 like ("3%") OR l.result4 like lower("TROIS%") OR l.result4 like ("+++"))
			  ) THEN 1364
		WHEN (
				(l.result like lower("FAIBLE") OR l.result like lower("MINIMES"))
				OR (l.result2 like lower("FAIBLE") OR l.result2 like lower("MINIMES"))
				OR (l.result3 like lower("FAIBLE") OR l.result3 like lower("MINIMES"))
				OR (l.result4 like lower("FAIBLE") OR l.result4 like lower("MINIMES"))
			  ) THEN 159985
		WHEN (
				(l.result like lower("%CONTAMIN%"))
				OR (l.result2 like lower("%CONTAMIN%"))
				OR (l.result3 like lower("%CONTAMIN%"))
				OR (l.result4 like lower("%CONTAMIN%"))
			  ) THEN 160008
			  END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1507
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
		/*End migration for Coloration de Ziehl-Neelsen*/
		/*Start migration for Culture LCR*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	159648,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=300
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	 
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_text,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159648,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (l.result <> "" AND l.result is not null) THEN l.result
		WHEN (l.result2 <> "" AND l.result2 is not null) THEN l.result2	
		WHEN (l.result3 <> "" AND l.result3 is not null) THEN l.result3
		WHEN (l.result4 <> "" AND l.result4 is not null) THEN l.result4
	END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=300
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
		/*End migration for Culture LCR*/
		/*Start Migration for DNAse*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163667,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1496
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163679,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum
	and c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1496
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163679
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163667,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
	CASE WHEN (l.result <> "" AND l.result is not null) THEN l.result
		WHEN (l.result2 <> "" AND l.result2 is not null) THEN l.result2	
		WHEN (l.result3 <> "" AND l.result3 is not null) THEN l.result3
		WHEN (l.result4 <> "" AND l.result4 is not null) THEN l.result4
	END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1496
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
		/*End migration for DNAse*/
		/*Start migration for Hemoculture*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	161155,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1528
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,161486,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum
	and c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1528
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=161486
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161155,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
	CASE WHEN (l.result <> "" AND l.result is not null) THEN l.result
		WHEN (l.result2 <> "" AND l.result2 is not null) THEN l.result2	
		WHEN (l.result3 <> "" AND l.result3 is not null) THEN l.result3
		WHEN (l.result4 <> "" AND l.result4 is not null) THEN l.result4
	END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1528
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
		/*End migration for Hemoculture*/
		
	/*Start Migration for Hydrolyse de l’esculine */	
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163668,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1497
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163679,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum
	and c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1497
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163679
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163668,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
	CASE WHEN (l.result <> "" AND l.result is not null) THEN l.result
		WHEN (l.result2 <> "" AND l.result2 is not null) THEN l.result2	
		WHEN (l.result3 <> "" AND l.result3 is not null) THEN l.result3
		WHEN (l.result4 <> "" AND l.result4 is not null) THEN l.result4
	END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1497
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*End migration for Hydrolyse de l’esculine*/
	/*Start migration for Mobilité*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163670,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1499
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163679,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum
	and c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1499
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163679
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163670,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
	CASE WHEN (l.result <> "" AND l.result is not null) THEN l.result
		WHEN (l.result2 <> "" AND l.result2 is not null) THEN l.result2	
		WHEN (l.result3 <> "" AND l.result3 is not null) THEN l.result3
		WHEN (l.result4 <> "" AND l.result4 is not null) THEN l.result4
	END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1499
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*End migration for Mobilité*/
	
	/*Start migration for ONPG*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163672,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1502
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163679,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum
	and c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1502
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163679
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163672,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
	CASE WHEN (l.result <> "" AND l.result is not null) THEN l.result
		WHEN (l.result2 <> "" AND l.result2 is not null) THEN l.result2	
		WHEN (l.result3 <> "" AND l.result3 is not null) THEN l.result3
		WHEN (l.result4 <> "" AND l.result4 is not null) THEN l.result4
	END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1502
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*End migration for ONPG*/
	/*Start migration for Oxydase*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163665,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1494
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163679,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum
	and c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1494
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163679
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163665,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
	CASE WHEN (l.result <> "" AND l.result is not null) THEN l.result
		WHEN (l.result2 <> "" AND l.result2 is not null) THEN l.result2	
		WHEN (l.result3 <> "" AND l.result3 is not null) THEN l.result3
		WHEN (l.result4 <> "" AND l.result4 is not null) THEN l.result4
	END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1494
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*End migration for Oxydase*/
	/*Start migration for Réaction de Voges-Proskauer*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163674,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1503
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163679,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum
	and c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1503
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163679
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163674,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
	CASE WHEN (l.result <> "" AND l.result is not null) THEN l.result
		WHEN (l.result2 <> "" AND l.result2 is not null) THEN l.result2	
		WHEN (l.result3 <> "" AND l.result3 is not null) THEN l.result3
		WHEN (l.result4 <> "" AND l.result4 is not null) THEN l.result4
	END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1503
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	
	/*End migration for Réaction de Voges-Proskauer*/
	
	/*Start Migration for Techniques d’agglutination*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163676,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1505
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163679,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum
	and c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1505
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163679
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163676,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
	CASE WHEN (
				(l.result like lower("NEG%"))
				OR (l.result2 like lower("NEG%"))
				OR (l.result3 like lower("NEG%")) 
				OR (l.result4 like lower("NEG%"))
			  ) THEN 664
		WHEN (
				(l.result like lower("POS%"))
				OR (l.result2 like lower("POS%"))
				OR (l.result3 like lower("POS%"))
				OR (l.result4 like lower("POS%"))
			  ) THEN 703
		WHEN (
				(l.result like lower("IND%"))
				OR (l.result2 like lower("IND%"))
				OR (l.result3 like lower("IND%"))
				OR (l.result4 like lower("IND%"))
			  ) THEN 1138
	END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1505
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*End migration for Techniques d’agglutination*/
	/*Start migration for Test à la porphyrine*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163671,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1501
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163679,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum
	and c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1501
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163679
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163671,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
	CASE WHEN (l.result <> "" AND l.result is not null) THEN l.result
		WHEN (l.result2 <> "" AND l.result2 is not null) THEN l.result2	
		WHEN (l.result3 <> "" AND l.result3 is not null) THEN l.result3
		WHEN (l.result4 <> "" AND l.result4 is not null) THEN l.result4
	END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1501
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*End migration for Test à la porphyrine*/
	/*Start migration for Test à la potasse*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	161456,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1500
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161456,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (
				(l.result like lower("NEG%"))
				OR (l.result2 like lower("NEG%"))
				OR (l.result3 like lower("NEG%"))
				OR (l.result4 like lower("NEG%"))
			  ) THEN 664
		WHEN (
				(l.result like lower("POS%"))
				OR (l.result2 like lower("POS%"))
				OR (l.result3 like lower("POS%"))
				OR (l.result4 like lower("POS%"))
			  ) THEN 703
	END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1500
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*End migration for Test à la potasse*/
	/*Start migration for Urée-tryptophane*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163669,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1498
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163679,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum
	and c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1498
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163679
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163669,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
	CASE WHEN (l.result <> "" AND l.result is not null) THEN l.result
		WHEN (l.result2 <> "" AND l.result2 is not null) THEN l.result2	
		WHEN (l.result3 <> "" AND l.result3 is not null) THEN l.result3
		WHEN (l.result4 <> "" AND l.result4 is not null) THEN l.result4
	END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1498
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*End migration for Urée-tryptophane*/
	
	/*Start migration for Uroculture*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	161156,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=301
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,161486,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum
	and c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=301
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=161486
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161156,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
	CASE WHEN (l.result <> "" AND l.result is not null) THEN l.result
		WHEN (l.result2 <> "" AND l.result2 is not null) THEN l.result2	
		WHEN (l.result3 <> "" AND l.result3 is not null) THEN l.result3
		WHEN (l.result4 <> "" AND l.result4 is not null) THEN l.result4
	END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=301
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*End migration for Uroculture*/
	/*End migration for Bacteriologie part*/
	
	/*Start migration for for ECBU part*/
	/*Start migration for Acide ascorbique*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163681,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1539
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163681,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (
				(l.result like lower("NEG%"))
				OR (l.result2 like lower("NEG%"))
				OR (l.result3 like lower("NEG%"))
				OR (l.result4 like lower("NEG%"))
			  ) THEN 664
		WHEN (
				(l.result like ("1%") OR l.result like lower("UN%") OR l.result like ("+"))
				OR (l.result2 like ("1%") OR l.result2 like lower("UN%") OR l.result like ("+"))
				OR (l.result3 like ("1%") OR l.result3 like lower("UN%") OR l.result like ("+"))
				OR (l.result4 like ("1%") OR l.result4 like lower("UN%") OR l.result like ("+"))
			  ) THEN 1362
		WHEN (
				(l.result like ("2%") OR l.result like lower("DE%") OR l.result like ("++"))
				OR (l.result2 like ("2%") OR l.result2 like lower("DE%") OR l.result2 like ("++"))
				OR (l.result3 like ("2%") OR l.result3 like lower("DE%") OR l.result3 like ("++"))
				OR (l.result4 like ("2%") OR l.result4 like lower("DE%") OR l.result4 like ("+++"))
			  ) THEN 1363
		WHEN (
				(l.result like ("3%") OR l.result like lower("TROIS%") OR l.result like ("+++"))
				OR (l.result2 like ("3%") OR l.result2 like lower("TROIS%") OR l.result2 like ("+++"))
				OR (l.result3 like ("3%") OR l.result3 like lower("TROIS%") OR l.result3 like ("+++"))
				OR (l.result4 like ("3%") OR l.result4 like lower("TROIS%") OR l.result4 like ("+++"))
			  ) THEN 1364
		WHEN (
				(l.result like lower("TRACE"))
				OR (l.result2 like lower("TRACE"))
				OR (l.result3 like lower("TRACE"))
				OR (l.result4 like lower("TRACE"))
			  ) THEN 1874
			  END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1539
	AND ((l.result <> "" AND l.result is not null) 
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*End migration for Acide ascorbique*/
	/*Start migration for Aspect*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	162101,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1530
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,161446,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum
	and c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1530
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=161446
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,162101,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
	CASE WHEN (
				(l.result like lower("%CLAIR%"))
				OR (l.result2 like lower("%CLAIR%"))
				OR (l.result3 like lower("%CLAIR%"))
				OR (l.result4 like lower("%CLAIR%"))
			  ) THEN 162102
		WHEN (
				(l.result like lower("%TROUBLE%"))
				OR (l.result2 like lower("%TROUBLE%"))
				OR (l.result3 like lower("%TROUBLE%"))
				OR (l.result4 like lower("%TROUBLE%"))
			  ) THEN 162103
		WHEN (
				(l.result like lower("%TURBINE%"))
				OR (l.result2 like lower("%TURBINE%"))
				OR (l.result3 like lower("%TURBINE%"))
				OR (l.result4 like lower("%TURBINE%"))
			  ) THEN 162104
		END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1530
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	
	/*End migration for Aspect*/
	
	/*Start migration for Bacteries*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	160735,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1544
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163697,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum
	and c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1544
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163697
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,160735,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
	CASE WHEN (
				(l.result like lower("NEG%"))
				OR (l.result2 like lower("NEG%"))
				OR (l.result3 like lower("NEG%"))
				OR (l.result4 like lower("NEG%"))
			  ) THEN 664
		WHEN (
				(l.result like lower("POS%"))
				OR (l.result2 like lower("POS%"))
				OR (l.result3 like lower("POS%"))
				OR (l.result4 like lower("POS%"))
			  ) THEN 703
		END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1544
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*End migration for Bacteries*/
	
	/*Start migration for cellules epitheliales*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163685,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1543
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163685,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (
				(l.result like lower("NEG%"))
				OR (l.result2 like lower("NEG%"))
				OR (l.result3 like lower("NEG%"))
				OR (l.result4 like lower("NEG%"))
			  ) THEN 664
		WHEN (
				(l.result like ("1%") OR l.result like lower("UN%") OR l.result like ("+"))
				OR (l.result2 like ("1%") OR l.result2 like lower("UN%") OR l.result like ("+"))
				OR (l.result3 like ("1%") OR l.result3 like lower("UN%") OR l.result like ("+"))
				OR (l.result4 like ("1%") OR l.result4 like lower("UN%") OR l.result like ("+"))
			  ) THEN 1362
		WHEN (
				(l.result like ("2%") OR l.result like lower("DE%") OR l.result like ("++"))
				OR (l.result2 like ("2%") OR l.result2 like lower("DE%") OR l.result2 like ("++"))
				OR (l.result3 like ("2%") OR l.result3 like lower("DE%") OR l.result3 like ("++"))
				OR (l.result4 like ("2%") OR l.result4 like lower("DE%") OR l.result4 like ("+++"))
			  ) THEN 1363
		WHEN (
				(l.result like ("3%") OR l.result like lower("TROIS%") OR l.result like ("+++"))
				OR (l.result2 like ("3%") OR l.result2 like lower("TROIS%") OR l.result2 like ("+++"))
				OR (l.result3 like ("3%") OR l.result3 like lower("TROIS%") OR l.result3 like ("+++"))
				OR (l.result4 like ("3%") OR l.result4 like lower("TROIS%") OR l.result4 like ("+++"))
			  ) THEN 1364
		WHEN (
				(l.result like lower("RARE%"))
				OR (l.result2 like lower("RARE%"))
				OR (l.result3 like lower("RARE%"))
				OR (l.result4 like lower("RARE%"))
			  ) THEN 159416
			  END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1543
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*End migration for cellules epitheliales*/
	/*Start migration for Cetones*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	161442,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1535
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	
	/*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,161446,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum
	and c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1535
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=161446
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161442,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
	CASE WHEN (
				(l.result like lower("N%"))
				OR (l.result2 like lower("N%"))
				OR (l.result3 like lower("N%"))
				OR (l.result4 like lower("N%"))
			  ) THEN 664
		WHEN (
				(l.result like ("1%") OR l.result like lower("UN%") OR l.result like ("+"))
				OR (l.result2 like ("1%") OR l.result2 like lower("UN%") OR l.result like ("+"))
				OR (l.result3 like ("1%") OR l.result3 like lower("UN%") OR l.result like ("+"))
				OR (l.result4 like ("1%") OR l.result4 like lower("UN%") OR l.result like ("+"))
			  ) THEN 1362
		WHEN (
				(l.result like ("2%") OR l.result like lower("DE%") OR l.result like ("++"))
				OR (l.result2 like ("2%") OR l.result2 like lower("DE%") OR l.result2 like ("++"))
				OR (l.result3 like ("2%") OR l.result3 like lower("DE%") OR l.result3 like ("++"))
				OR (l.result4 like ("2%") OR l.result4 like lower("DE%") OR l.result4 like ("+++"))
			  ) THEN 1363
		WHEN (
				(l.result like ("3%") OR l.result like lower("TROIS%") OR l.result like ("+++"))
				OR (l.result2 like ("3%") OR l.result2 like lower("TROIS%") OR l.result2 like ("+++"))
				OR (l.result3 like ("3%") OR l.result3 like lower("TROIS%") OR l.result3 like ("+++"))
				OR (l.result4 like ("3%") OR l.result4 like lower("TROIS%") OR l.result4 like ("+++"))
			  ) THEN 1364
		WHEN (
				(l.result like ("4%") OR l.result like lower("QUATRE%") OR l.result like ("++++"))
				OR (l.result2 like ("4%") OR l.result2 like lower("QUATRE%") OR l.result2 like ("++++"))
				OR (l.result3 like ("4%") OR l.result3 like lower("QUATRE%") OR l.result3 like ("++++"))
				OR (l.result4 like ("4%") OR l.result4 like lower("QUATRE%") OR l.result4 like ("++++"))
			  ) THEN 1365
			  END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1535
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*End migration for Cetones*/
	
	/*Start migration for Couleur*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		162106,1,e.createDate,UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1529
		AND (
			  (l.result <> "" AND l.result is not null) 
			   OR (l.result2 <> "" AND l.result2 is not null)
			   OR (l.result3 <> "" AND l.result3 is not null)
			   OR (l.result4 <> "" AND l.result4 is not null)
			);
		
		 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,161446,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1529
	AND (
			  (l.result <> "" AND l.result is not null) 
			   OR (l.result2 <> "" AND l.result2 is not null)
			   OR (l.result3 <> "" AND l.result3 is not null)
			   OR (l.result4 <> "" AND l.result4 is not null)
			);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=161446
	GROUP BY openmrs.obs.person_id,encounter_id;
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,162106,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
		CASE WHEN ((l.result like lower("INCOLORE")) OR (l.result2 like lower("INCOLORE")) 
		OR (l.result3 like lower("INCOLORE")) OR (l.result4 like lower("INCOLORE"))) THEN 162099
		WHEN ((l.result like lower("ROUGE")) OR (l.result2 like lower("ROUGE")) 
		OR (l.result3 like lower("ROUGE")) OR (l.result4 like lower("ROUGE"))) THEN 127778
		WHEN ((l.result like lower("JAUNE CLAIR")) OR (l.result2 like lower("JAUNE CLAIR")) 
		OR (l.result3 like lower("JAUNE CLAIR")) OR (l.result4 like lower("JAUNE CLAIR"))) THEN 162097
		WHEN ((l.result like lower("JAUNE VERT")) OR (l.result2 like lower("JAUNE VERT")) 
		OR (l.result3 like lower("JAUNE VERT")) OR (l.result4 like lower("JAUNE VERT"))) THEN 162105
		WHEN ((l.result like lower("JAUNE FONC%")) OR (l.result2 like lower("JAUNE FONC%")) 
		OR (l.result3 like lower("JAUNE FONC%")) OR (l.result4 like lower("JAUNE FONC%"))) THEN 162098
		WHEN ((l.result like lower("MARRON")) OR (l.result2 like lower("MARRON")) 
		OR (l.result3 like lower("MARRON")) OR (l.result4 like lower("MARRON"))) THEN 162100
		END,l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND c.encounter_id=cg.encounter_id
		AND c.patient_id=cg.person_id
		AND l.labID=1529
		AND (
			  (l.result <> "" AND l.result is not null) 
			   OR (l.result2 <> "" AND l.result2 is not null)
			   OR (l.result3 <> "" AND l.result3 is not null)
			   OR (l.result4 <> "" AND l.result4 is not null)
			);
	/*End migration for Couleur*/
	/*Start migration for Cristaux*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		163695,1,e.createDate,UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1550
		AND (
			  (l.result <> "" AND l.result is not null) 
			   OR (l.result2 <> "" AND l.result2 is not null)
			   OR (l.result3 <> "" AND l.result3 is not null)
			   OR (l.result4 <> "" AND l.result4 is not null)
			);
		
		 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163697,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1550
	AND (
			  (l.result <> "" AND l.result is not null) 
			   OR (l.result2 <> "" AND l.result2 is not null)
			   OR (l.result3 <> "" AND l.result3 is not null)
			   OR (l.result4 <> "" AND l.result4 is not null)
			);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163697
	GROUP BY openmrs.obs.person_id,encounter_id;
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163695,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
		CASE WHEN ((l.result like lower("PEU")) OR (l.result2 like lower("PEU")) 
		OR (l.result3 like lower("PEU")) OR (l.result4 like lower("PEU"))) THEN 1160
		WHEN ((l.result like lower("MODERE")) OR (l.result2 like lower("MODERE")) 
		OR (l.result3 like lower("MODERE")) OR (l.result4 like lower("MODERE"))) THEN 1499
		WHEN ((l.result like lower("ELEVE")) OR (l.result2 like lower("ELEVE")) 
		OR (l.result3 like lower("ELEVE")) OR (l.result4 like lower("ELEVE"))) THEN 1408
		WHEN ((l.result like lower("PHOSPHATE DE MG")) OR (l.result2 like lower("PHOSPHATE DE MG")) 
		OR (l.result3 like lower("PHOSPHATE DE MG")) OR (l.result4 like lower("PHOSPHATE DE MG"))) THEN 79241
		WHEN ((l.result like lower("SULFATE DE CA%")) OR (l.result2 like lower("SULFATE DE CA%")) 
		OR (l.result3 like lower("SULFATE DE CA%")) OR (l.result4 like lower("SULFATE DE CA%"))) THEN 72703
		WHEN ((l.result like lower("TRIPLE DE PHOSPHATE")) OR (l.result2 like lower("TRIPLE DE PHOSPHATE")) 
		OR (l.result3 like lower("TRIPLE DE PHOSPHATE")) OR (l.result4 like lower("TRIPLE DE PHOSPHATE"))) THEN 163644
		WHEN ((l.result like lower("%URATES AMORPHES%")) OR (l.result2 like lower("%URATES AMORPHES%")) 
		OR (l.result3 like lower("%URATES AMORPHES%")) OR (l.result4 like lower("%URATES AMORPHES%"))) THEN 163643
		WHEN ((l.result like lower("%URATES AMMONIUM%")) OR (l.result2 like lower("%URATES AMMONIUM%")) 
		OR (l.result3 like lower("%URATES AMMONIUM%")) OR (l.result4 like lower("%URATES AMMONIUM%"))) THEN 163642
		WHEN ((l.result like lower("%OXALATE DE CALCIUM%")) OR (l.result2 like lower("%OXALATE DE CALCIUM%")) 
		OR (l.result3 like lower("%OXALATE DE CALCIUM%")) OR (l.result4 like lower("%OXALATE DE CALCIUM%"))) THEN 725
		WHEN ((l.result like lower("%ACIDE URIQUE%")) OR (l.result2 like lower("%ACIDE URIQUE%")) 
		OR (l.result3 like lower("%ACIDE URIQUE%")) OR (l.result4 like lower("%ACIDE URIQUE%"))) THEN 123505
		WHEN ((l.result like lower("%CYSTINE%")) OR (l.result2 like lower("%CYSTINE%")) 
		OR (l.result3 like lower("%CYSTINE%")) OR (l.result4 like lower("%CYSTINE%"))) THEN 74167
		WHEN ((l.result like lower("%CRISTAUX DE PHOSPHATE AMORPHES%")) OR (l.result2 like lower("%CRISTAUX DE PHOSPHATE AMORPHES%")) 
		OR (l.result3 like lower("%CRISTAUX DE PHOSPHATE AMORPHES%")) OR (l.result4 like lower("%CRISTAUX DE PHOSPHATE AMORPHES%"))) THEN 722
		WHEN ((l.result like lower("AUCUN")) OR (l.result2 like lower("AUCUN")) 
		OR (l.result3 like lower("AUCUN")) OR (l.result4 like lower("AUCUN"))) THEN 1107
		END,l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND c.encounter_id=cg.encounter_id
		AND c.patient_id=cg.person_id
		AND l.labID=1550
		AND (
			  (l.result <> "" AND l.result is not null) 
			   OR (l.result2 <> "" AND l.result2 is not null)
			   OR (l.result3 <> "" AND l.result3 is not null)
			   OR (l.result4 <> "" AND l.result4 is not null)
			);
	/*End migration for Cristaux*/
	/*Start migration for Cylindres*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
		163696,1,e.createDate,UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=1549
		AND (
			  (l.result <> "" AND l.result is not null) 
			   OR (l.result2 <> "" AND l.result2 is not null)
			   OR (l.result3 <> "" AND l.result3 is not null)
			   OR (l.result4 <> "" AND l.result4 is not null)
			);
		
		 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163697,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1549
	AND (
			  (l.result <> "" AND l.result is not null) 
			   OR (l.result2 <> "" AND l.result2 is not null)
			   OR (l.result3 <> "" AND l.result3 is not null)
			   OR (l.result4 <> "" AND l.result4 is not null)
			);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163697
	GROUP BY openmrs.obs.person_id,encounter_id;
		/*concept*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,comments,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,163696,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
		CASE WHEN ((l.result like lower("PEU")) OR (l.result2 like lower("PEU")) 
		OR (l.result3 like lower("PEU")) OR (l.result4 like lower("PEU"))) THEN 1160
		WHEN ((l.result like lower("MODERE")) OR (l.result2 like lower("MODERE")) 
		OR (l.result3 like lower("MODERE")) OR (l.result4 like lower("MODERE"))) THEN 1499
		WHEN ((l.result like lower("ELEVE")) OR (l.result2 like lower("ELEVE")) 
		OR (l.result3 like lower("ELEVE")) OR (l.result4 like lower("ELEVE"))) THEN 1408
		WHEN ((l.result like lower("%GRANULEUX%")) OR (l.result2 like lower("%GRANULEUX%")) 
		OR (l.result3 like lower("%GRANULEUX%")) OR (l.result4 like lower("%GRANULEUX%"))) THEN 163690
		WHEN ((l.result like lower("%GRAISSEUX%")) OR (l.result2 like lower("%GRAISSEUX%")) 
		OR (l.result3 like lower("%GRAISSEUX%")) OR (l.result4 like lower("%GRAISSEUX%"))) THEN 163691
		WHEN ((l.result like lower("%EPITHELIALE%")) OR (l.result2 like lower("%EPITHELIALE%")) 
		OR (l.result3 like lower("%EPITHELIALE%")) OR (l.result4 like lower("%EPITHELIALE%"))) THEN 163692
		WHEN ((l.result like lower("%LEUCOCYTAIRE%")) OR (l.result2 like lower("%LEUCOCYTAIRE%")) 
		OR (l.result3 like lower("%LEUCOCYTAIRE%")) OR (l.result4 like lower("%LEUCOCYTAIRE%"))) THEN 163693
		WHEN ((l.result like lower("%CIREUX%")) OR (l.result2 like lower("%CIREUX%")) 
		OR (l.result3 like lower("%CIREUX%")) OR (l.result4 like lower("%CIREUX%"))) THEN 163694
		WHEN ((l.result like lower("AUCUN")) OR (l.result2 like lower("AUCUN")) 
		OR (l.result3 like lower("AUCUN")) OR (l.result4 like lower("AUCUN"))) THEN 1107
		END,l.resultRemarks,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND c.encounter_id=cg.encounter_id
		AND c.patient_id=cg.person_id
		AND l.labID=1549
		AND (
			  (l.result <> "" AND l.result is not null) 
			   OR (l.result2 <> "" AND l.result2 is not null)
			   OR (l.result3 <> "" AND l.result3 is not null)
			   OR (l.result4 <> "" AND l.result4 is not null)
			);
	/*End migration for Cylindres*/
	/*Start migration for Densité*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	161439,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1531
	AND (l.result <> "" AND digits(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,161446,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1531 and (l.result <> "" AND digits(l.result) >= 0);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=161446
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161439,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1531
	AND (l.result <> "" AND digits(l.result) >= 0);
	
	/*Start migration for Densité*/
	/*Start migration for Filaments myceliens*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163687,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1546
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	
	/*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163697,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum
	and c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1546
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163697
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163687,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
	CASE WHEN (
				(l.result like lower("N%"))
				OR (l.result2 like lower("N%"))
				OR (l.result3 like lower("N%"))
				OR (l.result4 like lower("N%"))
			  ) THEN 664
		WHEN (
				(l.result like lower("POS%"))
				OR (l.result2 like lower("POS%"))
				OR (l.result3 like lower("POS%"))
				OR (l.result4 like lower("POS%"))
			  ) THEN 703
		WHEN (
				(l.result like ("1%") OR l.result like lower("UN%") OR l.result like ("+"))
				OR (l.result2 like ("1%") OR l.result2 like lower("UN%") OR l.result like ("+"))
				OR (l.result3 like ("1%") OR l.result3 like lower("UN%") OR l.result like ("+"))
				OR (l.result4 like ("1%") OR l.result4 like lower("UN%") OR l.result like ("+"))
			  ) THEN 1362
		WHEN (
				(l.result like ("2%") OR l.result like lower("DE%") OR l.result like ("++"))
				OR (l.result2 like ("2%") OR l.result2 like lower("DE%") OR l.result2 like ("++"))
				OR (l.result3 like ("2%") OR l.result3 like lower("DE%") OR l.result3 like ("++"))
				OR (l.result4 like ("2%") OR l.result4 like lower("DE%") OR l.result4 like ("+++"))
			  ) THEN 1363
		WHEN (
				(l.result like ("3%") OR l.result like lower("TROIS%") OR l.result like ("+++"))
				OR (l.result2 like ("3%") OR l.result2 like lower("TROIS%") OR l.result2 like ("+++"))
				OR (l.result3 like ("3%") OR l.result3 like lower("TROIS%") OR l.result3 like ("+++"))
				OR (l.result4 like ("3%") OR l.result4 like lower("TROIS%") OR l.result4 like ("+++"))
			  ) THEN 1364
			  END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1546
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*End migration for Filaments myceliens*/
	/*Start migration for Glucose*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	159733,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1534
	AND (l.result <> "" AND digits(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,161446,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1534 and (l.result <> "" AND digits(l.result) >= 0);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=161446
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159733,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1534
	AND (l.result <> "" AND digits(l.result) >= 0);
	/*End migration for Glucose*/
	
	/*Start migration for Hematies*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163683,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1542
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	
	/*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163697,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum
	and c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1542
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163697
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163683,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
	CASE WHEN (
				(l.result like lower("MODERE%"))
				OR (l.result2 like lower("MODERE%"))
				OR (l.result3 like lower("MODERE%"))
				OR (l.result4 like lower("MODERE%"))
			  ) THEN 1499
		WHEN (
				(l.result like lower("ELEVE%"))
				OR (l.result2 like lower("ELEVE%"))
				OR (l.result3 like lower("ELEVE%"))
				OR (l.result4 like lower("ELEVE%"))
			  ) THEN 1408
		WHEN (
				(l.result like lower("AUCUN%"))
				OR (l.result2 like lower("AUCUN%"))
				OR (l.result3 like lower("AUCUN%"))
				OR (l.result4 like lower("AUCUN%"))
			  ) THEN 1107
		END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1542
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*End migration for Hematies*/
	/*Start migration for Leucocytes*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	161441,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1538
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	
	/*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,161446,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum
	and c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1538
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=161446
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161441,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
	CASE WHEN (
				(l.result like lower("NEG%"))
				OR (l.result2 like lower("NEG%"))
				OR (l.result3 like lower("NEG%"))
				OR (l.result4 like lower("NEG%"))
			  ) THEN 664
		WHEN (
				(l.result like lower("POS%"))
				OR (l.result2 like lower("POS%"))
				OR (l.result3 like lower("POS%"))
				OR (l.result4 like lower("POS%"))
			  ) THEN 703
		WHEN (
				(l.result like lower("IND%"))
				OR (l.result2 like lower("IND%"))
				OR (l.result3 like lower("IND%"))
				OR (l.result4 like lower("IND%"))
			  ) THEN 1138
		END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1538
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*End migration for Leucocytes*/
	/*Start migration for Levures*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163686,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1545
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	
	/*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163697,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum
	and c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1545
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163697
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163686,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
	CASE WHEN (
				(l.result like lower("N%"))
				OR (l.result2 like lower("N%"))
				OR (l.result3 like lower("N%"))
				OR (l.result4 like lower("N%"))
			  ) THEN 664
		WHEN (
				(l.result like ("1%") OR l.result like lower("UN%") OR l.result like ("+"))
				OR (l.result2 like ("1%") OR l.result2 like lower("UN%") OR l.result like ("+"))
				OR (l.result3 like ("1%") OR l.result3 like lower("UN%") OR l.result like ("+"))
				OR (l.result4 like ("1%") OR l.result4 like lower("UN%") OR l.result like ("+"))
			  ) THEN 1362
		WHEN (
				(l.result like ("2%") OR l.result like lower("DE%") OR l.result like ("++"))
				OR (l.result2 like ("2%") OR l.result2 like lower("DE%") OR l.result2 like ("++"))
				OR (l.result3 like ("2%") OR l.result3 like lower("DE%") OR l.result3 like ("++"))
				OR (l.result4 like ("2%") OR l.result4 like lower("DE%") OR l.result4 like ("+++"))
			  ) THEN 1363
		WHEN (
				(l.result like ("3%") OR l.result like lower("TROIS%") OR l.result like ("+++"))
				OR (l.result2 like ("3%") OR l.result2 like lower("TROIS%") OR l.result2 like ("+++"))
				OR (l.result3 like ("3%") OR l.result3 like lower("TROIS%") OR l.result3 like ("+++"))
				OR (l.result4 like ("3%") OR l.result4 like lower("TROIS%") OR l.result4 like ("+++"))
			  ) THEN 1364
			  END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1545
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*End migration for Levures*/
	/*Start migration for Nitrites*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	161440,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1541
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	
	/*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,161446,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum
	and c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1541
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=161446
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161440,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
	CASE WHEN (
				(l.result like lower("NEG%"))
				OR (l.result2 like lower("NEG%"))
				OR (l.result3 like lower("NEG%"))
				OR (l.result4 like lower("NEG%"))
			  ) THEN 664
		WHEN (
				(l.result like lower("POS%"))
				OR (l.result2 like lower("POS%"))
				OR (l.result3 like lower("POS%"))
				OR (l.result4 like lower("POS%"))
			  ) THEN 703
		WHEN (
				(l.result like lower("IND%"))
				OR (l.result2 like lower("IND%"))
				OR (l.result3 like lower("IND%"))
				OR (l.result4 like lower("IND%"))
			  ) THEN 1138
		END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1541
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	
	/*End migration for Nitrites*/
	/*Start migration for pH*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	161438,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1532
	AND (l.result <> "" AND digits(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,161446,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1532 and (l.result <> "" AND digits(l.result) >= 0);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=161446
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161438,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1532
	AND (l.result <> "" AND digits(l.result) >= 0);
	
	/*End migration for pH*/
	/*Start migration for Proteines*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	1875,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1533
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	
	/*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,161446,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum
	and c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1533
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=161446
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1875,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
	CASE WHEN (
				(l.result like lower("NEG%"))
				OR (l.result2 like lower("NEG%"))
				OR (l.result3 like lower("NEG%"))
				OR (l.result4 like lower("NEG%"))
			  ) THEN 664
		WHEN (
				(l.result like lower("POS%"))
				OR (l.result2 like lower("POS%"))
				OR (l.result3 like lower("POS%"))
				OR (l.result4 like lower("POS%"))
			  ) THEN 703
		WHEN (
				(l.result like ("1%") OR l.result like lower("UN%") OR l.result like ("+"))
				OR (l.result2 like ("1%") OR l.result2 like lower("UN%") OR l.result like ("+"))
				OR (l.result3 like ("1%") OR l.result3 like lower("UN%") OR l.result like ("+"))
				OR (l.result4 like ("1%") OR l.result4 like lower("UN%") OR l.result like ("+"))
			  ) THEN 1362
		WHEN (
				(l.result like ("2%") OR l.result like lower("DE%") OR l.result like ("++"))
				OR (l.result2 like ("2%") OR l.result2 like lower("DE%") OR l.result2 like ("++"))
				OR (l.result3 like ("2%") OR l.result3 like lower("DE%") OR l.result3 like ("++"))
				OR (l.result4 like ("2%") OR l.result4 like lower("DE%") OR l.result4 like ("+++"))
			  ) THEN 1363
		WHEN (
				(l.result like ("3%") OR l.result like lower("TROIS%") OR l.result like ("+++"))
				OR (l.result2 like ("3%") OR l.result2 like lower("TROIS%") OR l.result2 like ("+++"))
				OR (l.result3 like ("3%") OR l.result3 like lower("TROIS%") OR l.result3 like ("+++"))
				OR (l.result4 like ("3%") OR l.result4 like lower("TROIS%") OR l.result4 like ("+++"))
			  ) THEN 1364
		WHEN (
				(l.result like ("4%") OR l.result like lower("QUATRE%") OR l.result like ("++++"))
				OR (l.result2 like ("4%") OR l.result2 like lower("QUATRE%") OR l.result2 like ("++++"))
				OR (l.result3 like ("4%") OR l.result3 like lower("QUATRE%") OR l.result3 like ("++++"))
				OR (l.result4 like ("4%") OR l.result4 like lower("QUATRE%") OR l.result4 like ("++++"))
			  ) THEN 1365
		END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1533
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*End migration for Proteines*/
	
	/*Start migration for Sang*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	162096,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1537
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	
	/*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,161446,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum
	and c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1537
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=161446
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,162096,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
	CASE WHEN (
				(l.result like lower("NEG%"))
				OR (l.result2 like lower("NEG%"))
				OR (l.result3 like lower("NEG%"))
				OR (l.result4 like lower("NEG%"))
			  ) THEN 664
		WHEN (
				(l.result like ("1%") OR l.result like lower("UN%") OR l.result like ("+"))
				OR (l.result2 like ("1%") OR l.result2 like lower("UN%") OR l.result like ("+"))
				OR (l.result3 like ("1%") OR l.result3 like lower("UN%") OR l.result like ("+"))
				OR (l.result4 like ("1%") OR l.result4 like lower("UN%") OR l.result like ("+"))
			  ) THEN 1362
		WHEN (
				(l.result like ("2%") OR l.result like lower("DE%") OR l.result like ("++"))
				OR (l.result2 like ("2%") OR l.result2 like lower("DE%") OR l.result2 like ("++"))
				OR (l.result3 like ("2%") OR l.result3 like lower("DE%") OR l.result3 like ("++"))
				OR (l.result4 like ("2%") OR l.result4 like lower("DE%") OR l.result4 like ("+++"))
			  ) THEN 1363
		WHEN (
				(l.result like ("3%") OR l.result like lower("TROIS%") OR l.result like ("+++"))
				OR (l.result2 like ("3%") OR l.result2 like lower("TROIS%") OR l.result2 like ("+++"))
				OR (l.result3 like ("3%") OR l.result3 like lower("TROIS%") OR l.result3 like ("+++"))
				OR (l.result4 like ("3%") OR l.result4 like lower("TROIS%") OR l.result4 like ("+++"))
			  ) THEN 1364
		END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1537
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*End migration for Sang*/
	/*Start migration for Spores*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163688,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1547
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	
	/*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163697,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum
	and c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1547
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163697
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163688,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
	CASE WHEN (
				(l.result like lower("NEG%"))
				OR (l.result2 like lower("NEG%"))
				OR (l.result3 like lower("NEG%"))
				OR (l.result4 like lower("NEG%"))
			  ) THEN 664
		WHEN (
				(l.result like ("1%") OR l.result like lower("UN%") OR l.result like ("+"))
				OR (l.result2 like ("1%") OR l.result2 like lower("UN%") OR l.result like ("+"))
				OR (l.result3 like ("1%") OR l.result3 like lower("UN%") OR l.result like ("+"))
				OR (l.result4 like ("1%") OR l.result4 like lower("UN%") OR l.result like ("+"))
			  ) THEN 1362
		WHEN (
				(l.result like ("2%") OR l.result like lower("DE%") OR l.result like ("++"))
				OR (l.result2 like ("2%") OR l.result2 like lower("DE%") OR l.result2 like ("++"))
				OR (l.result3 like ("2%") OR l.result3 like lower("DE%") OR l.result3 like ("++"))
				OR (l.result4 like ("2%") OR l.result4 like lower("DE%") OR l.result4 like ("+++"))
			  ) THEN 1363
		WHEN (
				(l.result like ("3%") OR l.result like lower("TROIS%") OR l.result like ("+++"))
				OR (l.result2 like ("3%") OR l.result2 like lower("TROIS%") OR l.result2 like ("+++"))
				OR (l.result3 like ("3%") OR l.result3 like lower("TROIS%") OR l.result3 like ("+++"))
				OR (l.result4 like ("3%") OR l.result4 like lower("TROIS%") OR l.result4 like ("+++"))
			  ) THEN 1364
		END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1547
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*End migration for Spores*/
	/*Start migration for Trichomonas*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163689,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1548
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	
	/*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163697,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum
	and c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1548
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163697
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163689,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
	CASE WHEN (
				(l.result like lower("PEU%"))
				OR (l.result2 like lower("PEU%"))
				OR (l.result3 like lower("PEU%"))
				OR (l.result4 like lower("PEU%"))
			  ) THEN 1160
		 WHEN (
				(l.result like lower("MODERE%"))
				OR (l.result2 like lower("MODERE%"))
				OR (l.result3 like lower("MODERE%"))
				OR (l.result4 like lower("MODERE%"))
			  ) THEN 1499
		WHEN (
				(l.result like lower("ELEVE%"))
				OR (l.result2 like lower("ELEVE%"))
				OR (l.result3 like lower("ELEVE%"))
				OR (l.result4 like lower("ELEVE%"))
			  ) THEN 1408
		WHEN (
				(l.result like lower("ELEVE%"))
				OR (l.result2 like lower("ELEVE%"))
				OR (l.result3 like lower("ELEVE%"))
				OR (l.result4 like lower("ELEVE%"))
			  ) THEN 1107
		END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1548
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*End migration for Trichomonas*/
	/*Start migration for Urobilinogene*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163682,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1540
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163682,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (
				(l.result like lower("NEG%"))
				OR (l.result2 like lower("NEG%"))
				OR (l.result3 like lower("NEG%"))
				OR (l.result4 like lower("NEG%"))
			  ) THEN 664
		WHEN (
				(l.result like ("1%") OR l.result like lower("UN%") OR l.result like ("+"))
				OR (l.result2 like ("1%") OR l.result2 like lower("UN%") OR l.result like ("+"))
				OR (l.result3 like ("1%") OR l.result3 like lower("UN%") OR l.result like ("+"))
				OR (l.result4 like ("1%") OR l.result4 like lower("UN%") OR l.result like ("+"))
			  ) THEN 1362
		WHEN (
				(l.result like ("2%") OR l.result like lower("DE%") OR l.result like ("++"))
				OR (l.result2 like ("2%") OR l.result2 like lower("DE%") OR l.result2 like ("++"))
				OR (l.result3 like ("2%") OR l.result3 like lower("DE%") OR l.result3 like ("++"))
				OR (l.result4 like ("2%") OR l.result4 like lower("DE%") OR l.result4 like ("+++"))
			  ) THEN 1363
		WHEN (
				(l.result like ("3%") OR l.result like lower("TROIS%") OR l.result like ("+++"))
				OR (l.result2 like ("3%") OR l.result2 like lower("TROIS%") OR l.result2 like ("+++"))
				OR (l.result3 like ("3%") OR l.result3 like lower("TROIS%") OR l.result3 like ("+++"))
				OR (l.result4 like ("3%") OR l.result4 like lower("TROIS%") OR l.result4 like ("+++"))
			  ) THEN 1364
		WHEN (
				(l.result like ("TRACE%"))
				OR (l.result2 like ("TRACE%"))
				OR (l.result3 like ("TRACE%"))
				OR (l.result4 like ("TRACE%"))
			  ) THEN 1874
		END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1540
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*End migration for Urobilinogene*/
	
	/*End migration for ECBU part*/
	
	/*Start migration for Parasitologie part*/
		/*Start migration for Aspect*/
		 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	162101,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1552
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,162101,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (
				(l.result like lower("%URINE CLAIR%"))
				OR (l.result2 like lower("%URINE CLAIR%"))
				OR (l.result3 like lower("%URINE CLAIR%"))
				OR (l.result4 like lower("%URINE CLAIR%"))
			  ) THEN 162102
		 WHEN (
				(l.result like lower("%URINE PAS CLAIR%"))
				OR (l.result2 like lower("%URINE PAS CLAIR%"))
				OR (l.result3 like lower("%URINE PAS CLAIR%"))
				OR (l.result4 like lower("%URINE PAS CLAIR%"))
			  ) THEN 162103
		END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1552
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
		/*End migration for Aspect*/
	/*Start migration for Bleu de Methylene*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163634,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1554
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	 
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_text,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163634,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (l.result <> "" AND l.result is not null) THEN l.result
		WHEN (l.result2 <> "" AND l.result2 is not null) THEN l.result2	
		WHEN (l.result3 <> "" AND l.result3 is not null) THEN l.result3
		WHEN (l.result4 <> "" AND l.result4 is not null) THEN l.result4
	END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1554
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*End migration for Bleu de Methylene*/
	/*Start migration for Couleur*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163641,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1551
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163641,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (
				(l.result like lower("% NOIR%"))
				OR (l.result2 like lower("% NOIR%"))
				OR (l.result3 like lower("% NOIR%"))
				OR (l.result4 like lower("% NOIR%"))
			  ) THEN 162065
		 WHEN (
				(l.result like lower("% JAUNE%"))
				OR (l.result2 like lower("% JAUNE%"))
				OR (l.result3 like lower("% JAUNE%"))
				OR (l.result4 like lower("% JAUNE%"))
			  ) THEN 160910
		WHEN (
				(l.result like lower("% MARRON%"))
				OR (l.result2 like lower("% MARRON%"))
				OR (l.result3 like lower("% MARRON%"))
				OR (l.result4 like lower("% MARRON%"))
			  ) THEN 162100
		WHEN (
				(l.result like lower("% VERT%"))
				OR (l.result2 like lower("% VERT%"))
				OR (l.result3 like lower("% VERT%"))
				OR (l.result4 like lower("% VERT%"))
			  ) THEN 160909
		WHEN (
				(l.result like lower("% SANGLAN%"))
				OR (l.result2 like lower("% SANGLAN%"))
				OR (l.result3 like lower("% SANGLAN%"))
				OR (l.result4 like lower("% SANGLAN%"))
			  ) THEN 1077
		ELSE 5622
		END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1551
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*End migration for Couleur*/
	/*Start migration for Examen Microscopique apres concentration*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	161447,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1556
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	 
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_text,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161447,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (l.result <> "" AND l.result is not null) THEN l.result
		WHEN (l.result2 <> "" AND l.result2 is not null) THEN l.result2	
		WHEN (l.result3 <> "" AND l.result3 is not null) THEN l.result3
		WHEN (l.result4 <> "" AND l.result4 is not null) THEN l.result4
	END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1556
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*End migration for Examen Microscopique apres concentration*/
	/*Start migration for Examen Microscopique direct*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	304,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1555
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,304,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (
				(l.result like lower("%CESTODE%"))
				OR (l.result2 like lower("%CESTODE%"))
				OR (l.result3 like lower("%CESTODE%"))
				OR (l.result4 like lower("%CESTODE%"))
			  ) THEN 120759
		 WHEN (
				(l.result like lower("% LARVE%"))
				OR (l.result2 like lower("% LARVE%"))
				OR (l.result3 like lower("% LARVE%"))
				OR (l.result4 like lower("% LARVE%"))
			  ) THEN 137504
		END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1555
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*End migration for Examen Microscopique direct*/
	
	/*Start migration for Malaria*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	1366,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1559
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1366,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (
				(l.result like lower("NEG%"))
				OR (l.result2 like lower("NEG%"))
				OR (l.result3 like lower("NEG%"))
				OR (l.result4 like lower("NEG%"))
			  ) THEN 664
		WHEN (
				(l.result like ("1%") OR l.result like lower("UN%") OR l.result like ("+"))
				OR (l.result2 like ("1%") OR l.result2 like lower("UN%") OR l.result like ("+"))
				OR (l.result3 like ("1%") OR l.result3 like lower("UN%") OR l.result like ("+"))
				OR (l.result4 like ("1%") OR l.result4 like lower("UN%") OR l.result like ("+"))
			  ) THEN 1362
		WHEN (
				(l.result like ("2%") OR l.result like lower("DE%") OR l.result like ("++"))
				OR (l.result2 like ("2%") OR l.result2 like lower("DE%") OR l.result2 like ("++"))
				OR (l.result3 like ("2%") OR l.result3 like lower("DE%") OR l.result3 like ("++"))
				OR (l.result4 like ("2%") OR l.result4 like lower("DE%") OR l.result4 like ("+++"))
			  ) THEN 1363
		WHEN (
				(l.result like ("3%") OR l.result like lower("TROIS%") OR l.result like ("+++"))
				OR (l.result2 like ("3%") OR l.result2 like lower("TROIS%") OR l.result2 like ("+++"))
				OR (l.result3 like ("3%") OR l.result3 like lower("TROIS%") OR l.result3 like ("+++"))
				OR (l.result4 like ("3%") OR l.result4 like lower("TROIS%") OR l.result4 like ("+++"))
			  ) THEN 1364
		WHEN (
				(l.result like ("4%") OR l.result like lower("QUATRE%") OR l.result like ("++++"))
				OR (l.result2 like ("4%") OR l.result2 like lower("QUATRE%") OR l.result2 like ("++++"))
				OR (l.result3 like ("4%") OR l.result3 like lower("QUATRE%") OR l.result3 like ("++++"))
				OR (l.result4 like ("4%") OR l.result4 like lower("QUATRE%") OR l.result4 like ("++++"))
			  ) THEN 1365
		END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1559
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*End migration for Malaria*/
	/*Start Migration for Malaria Test Rapide*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	1643,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1560
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1643,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (
				(l.result like lower("NEG%"))
				OR (l.result2 like lower("NEG%"))
				OR (l.result3 like lower("NEG%"))
				OR (l.result4 like lower("NEG%"))
			  ) THEN 664
		WHEN (
				(l.result like lower("POS%"))
				OR (l.result2 like lower("POS%"))
				OR (l.result3 like lower("POS%"))
				OR (l.result4 like lower("POS%"))
			  ) THEN 703
		WHEN (
				(l.result like lower("IND%"))
				OR (l.result2 like lower("IND%"))
				OR (l.result3 like lower("IND%"))
				OR (l.result4 like lower("IND%"))
			  ) THEN 1138
		END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1560
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*End migration for Malaria Test Rapide*/
	/*Start migration for Recherche de microfilaire*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	161427,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1558
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161427,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (
				(l.result like lower("NEG%"))
				OR (l.result2 like lower("NEG%"))
				OR (l.result3 like lower("NEG%"))
				OR (l.result4 like lower("NEG%"))
			  ) THEN 664
		WHEN (
				(l.result like lower("%FILARIOSE%"))
				OR (l.result2 like lower("%FILARIOSE%"))
				OR (l.result3 like lower("%FILARIOSE%"))
				OR (l.result4 like lower("%FILARIOSE%"))
			  ) THEN 161565
		WHEN (
				(l.result like lower("%MANSONELLA%"))
				OR (l.result2 like lower("%MANSONELLA%"))
				OR (l.result3 like lower("%MANSONELLA%"))
				OR (l.result4 like lower("%MANSONELLA%"))
			  ) THEN 114412
		END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1558
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*End migration for Recherche de microfilaire*/
	/*Start migration for Recherche de cryptosporidium et Oocyste*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163633,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1557
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	 
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_text,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163633,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (l.result <> "" AND l.result is not null) THEN l.result
		WHEN (l.result2 <> "" AND l.result2 is not null) THEN l.result2	
		WHEN (l.result3 <> "" AND l.result3 is not null) THEN l.result3
		WHEN (l.result4 <> "" AND l.result4 is not null) THEN l.result4
	END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1557
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*End migration for Recherche de cryptosporidium et Oocyste*/
	/*Start migration for Sang Occulte*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	159362,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1553
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159362,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (
				(l.result like lower("NEG%"))
				OR (l.result2 like lower("NEG%"))
				OR (l.result3 like lower("NEG%"))
				OR (l.result4 like lower("NEG%"))
			  ) THEN 664
		WHEN (
				(l.result like lower("POS%"))
				OR (l.result2 like lower("POS%"))
				OR (l.result3 like lower("POS%"))
				OR (l.result4 like lower("POS%"))
			  ) THEN 703
		WHEN (
				(l.result like lower("IND%"))
				OR (l.result2 like lower("IND%"))
				OR (l.result3 like lower("IND%"))
				OR (l.result4 like lower("IND%"))
			  ) THEN 1138
		END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1553
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*End migration for Sang Occulte*/
	
	/*End migration for Parasitologie part*/
	
	/*Start migration for Immuno-virologie Part*/
		/*Start migration for Dengue*/
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163632,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1577
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163632,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (
				(l.result like lower("NEG%"))
				OR (l.result2 like lower("NEG%"))
				OR (l.result3 like lower("NEG%"))
				OR (l.result4 like lower("NEG%"))
			  ) THEN 664
		WHEN (
				(l.result like lower("POS%"))
				OR (l.result2 like lower("POS%"))
				OR (l.result3 like lower("POS%"))
				OR (l.result4 like lower("POS%"))
			  ) THEN 703
		END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1577
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
		/*End migration for Dengue*/
		/*Start migration for Hépatite B Ag*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	1322,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1569
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1322,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (
				(l.result like lower("NEG%"))
				OR (l.result2 like lower("NEG%"))
				OR (l.result3 like lower("NEG%"))
				OR (l.result4 like lower("NEG%"))
			  ) THEN 664
		WHEN (
				(l.result like lower("POS%"))
				OR (l.result2 like lower("POS%"))
				OR (l.result3 like lower("POS%"))
				OR (l.result4 like lower("POS%"))
			  ) THEN 703
		WHEN (
				(l.result like lower("IND%"))
				OR (l.result2 like lower("IND%"))
				OR (l.result3 like lower("IND%"))
				OR (l.result4 like lower("IND%"))
			  ) THEN 1138
		WHEN (
				(l.result like lower("ECHANTILLON DE PAUVRE%"))
				OR (l.result2 like lower("ECHANTILLON DE PAUVRE%"))
				OR (l.result3 like lower("ECHANTILLON DE PAUVRE%"))
				OR (l.result4 like lower("ECHANTILLON DE PAUVRE%"))
			  ) THEN 1304
		END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1569
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
		/*End migration for Hépatite B Ag*/
		
		/*Start migration for Hépatite C IgM*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	1325,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1572
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1325,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (
				(l.result like lower("NEG%"))
				OR (l.result2 like lower("NEG%"))
				OR (l.result3 like lower("NEG%"))
				OR (l.result4 like lower("NEG%"))
			  ) THEN 664
		WHEN (
				(l.result like lower("POS%"))
				OR (l.result2 like lower("POS%"))
				OR (l.result3 like lower("POS%"))
				OR (l.result4 like lower("POS%"))
			  ) THEN 703
		WHEN (
				(l.result like lower("IND%"))
				OR (l.result2 like lower("IND%"))
				OR (l.result3 like lower("IND%"))
				OR (l.result4 like lower("IND%"))
			  ) THEN 1138
		WHEN (
				(l.result like lower("ECHANTILLON DE PAUVRE%"))
				OR (l.result2 like lower("ECHANTILLON DE PAUVRE%"))
				OR (l.result3 like lower("ECHANTILLON DE PAUVRE%"))
				OR (l.result4 like lower("ECHANTILLON DE PAUVRE%"))
			  ) THEN 1304
		END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1572
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
		
		/*End migration for Hépatite C IgM*/
		/*Start migration for VIH Elisa*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	1042,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1568
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1042,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (
				(l.result like lower("NEG%"))
				OR (l.result2 like lower("NEG%"))
				OR (l.result3 like lower("NEG%"))
				OR (l.result4 like lower("NEG%"))
			  ) THEN 664
		WHEN (
				(l.result like lower("POS%"))
				OR (l.result2 like lower("POS%"))
				OR (l.result3 like lower("POS%"))
				OR (l.result4 like lower("POS%"))
			  ) THEN 703
		WHEN (
				(l.result like lower("IND%"))
				OR (l.result2 like lower("IND%"))
				OR (l.result3 like lower("IND%"))
				OR (l.result4 like lower("IND%"))
			  ) THEN 1138
		WHEN (
				(l.result like lower("ECHANTILLON DE PAUVRE%"))
				OR (l.result2 like lower("ECHANTILLON DE PAUVRE%"))
				OR (l.result3 like lower("ECHANTILLON DE PAUVRE%"))
				OR (l.result4 like lower("ECHANTILLON DE PAUVRE%"))
			  ) THEN 1304
		END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1568
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
		
		/*End migration for VIH Elisa*/
		/*Start migration for VIH test rapide*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	1040,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1563
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1040,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (
				(l.result like lower("NEG%"))
				OR (l.result2 like lower("NEG%"))
				OR (l.result3 like lower("NEG%"))
				OR (l.result4 like lower("NEG%"))
			  ) THEN 664
		WHEN (
				(l.result like lower("POS%"))
				OR (l.result2 like lower("POS%"))
				OR (l.result3 like lower("POS%"))
				OR (l.result4 like lower("POS%"))
			  ) THEN 703
		WHEN (
				(l.result like lower("IND%"))
				OR (l.result2 like lower("IND%"))
				OR (l.result3 like lower("IND%"))
				OR (l.result4 like lower("IND%"))
			  ) THEN 1138
		WHEN (
				(l.result like lower("ECHANTILLON DE PAUVRE%"))
				OR (l.result2 like lower("ECHANTILLON DE PAUVRE%"))
				OR (l.result3 like lower("ECHANTILLON DE PAUVRE%"))
				OR (l.result4 like lower("ECHANTILLON DE PAUVRE%"))
			  ) THEN 1304
		END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1563
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
		/*End migration for VIH test rapide*/
	/*END migration for Immuno-virologie Part*/
	/*Start migration for Mycobacteriologie part*/
		/*Start migration for Culture de M. tuberculosis*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	159982,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1590
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159982,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (
				(l.result like lower("NEG%"))
				OR (l.result2 like lower("NEG%"))
				OR (l.result3 like lower("NEG%"))
				OR (l.result4 like lower("NEG%"))
			  ) THEN 664
		WHEN (
				(l.result like lower("POS%"))
				OR (l.result2 like lower("POS%"))
				OR (l.result3 like lower("POS%"))
				OR (l.result4 like lower("POS%"))
			  ) THEN 703
		WHEN (
				(l.result like ("1%") OR l.result like lower("UN%") OR l.result like ("+"))
				OR (l.result2 like ("1%") OR l.result2 like lower("UN%") OR l.result like ("+"))
				OR (l.result3 like ("1%") OR l.result3 like lower("UN%") OR l.result like ("+"))
				OR (l.result4 like ("1%") OR l.result4 like lower("UN%") OR l.result like ("+"))
			  ) THEN 1362
		WHEN (
				(l.result like ("2%") OR l.result like lower("DE%") OR l.result like ("++"))
				OR (l.result2 like ("2%") OR l.result2 like lower("DE%") OR l.result2 like ("++"))
				OR (l.result3 like ("2%") OR l.result3 like lower("DE%") OR l.result3 like ("++"))
				OR (l.result4 like ("2%") OR l.result4 like lower("DE%") OR l.result4 like ("+++"))
			  ) THEN 1363
		WHEN (
				(l.result like ("3%") OR l.result like lower("TROIS%") OR l.result like ("+++"))
				OR (l.result2 like ("3%") OR l.result2 like lower("TROIS%") OR l.result2 like ("+++"))
				OR (l.result3 like ("3%") OR l.result3 like lower("TROIS%") OR l.result3 like ("+++"))
				OR (l.result4 like ("3%") OR l.result4 like lower("TROIS%") OR l.result4 like ("+++"))
			  ) THEN 1364
		WHEN (
				(l.result like ("%CONTAMINE%"))
				OR (l.result2 like ("%CONTAMINE%"))
				OR (l.result3 like ("%CONTAMINE%"))
				OR (l.result4 like ("%CONTAMINE%"))
			  ) THEN 160008
		END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1590
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
		/*End migration for Culture de M. tuberculosis*/
		/*Start migration for PPD Qualitatif*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163630,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1591
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	
	/*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163631,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum
	and c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1591
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163631
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163630,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
	CASE WHEN (
				(l.result like lower("REACTI%"))
				OR (l.result2 like lower("REACTI%"))
				OR (l.result3 like lower("REACTI%"))
				OR (l.result4 like lower("REACTI%"))
			  ) THEN 1228
		 WHEN (
				(l.result like lower("NON REACTI%") OR l.result like lower("NON-REACTI%"))
				OR (l.result2 like lower("NON REACTI%") OR l.result2 like lower("NON-REACTI%"))
				OR (l.result3 like lower("NON REACTI%") OR l.result3 like lower("NON-REACTI%"))
				OR (l.result4 like lower("NON REACTI%") OR l.result4 like lower("NON-REACTI%"))
			  ) THEN 1229
		END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1591
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
		/*End migration for PPD Qualitatif*/
		/*Start migration for PPD Quantitatif*/
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	5475,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1592
	AND (l.result <> "" AND digits(l.result) >= 0);
	 /*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163631,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1592 and (l.result <> "" AND digits(l.result) >= 0);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163631
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,5475,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1592
	AND (l.result <> "" AND digits(l.result) >= 0);
		/*End migration for PPD Quantitatif*/
	  /*Start migration for Recherche de BARR par Fluorochrome Specimen 1*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163677,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1581
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	 
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_text,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163677,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (l.result <> "" AND l.result is not null) THEN l.result
		WHEN (l.result2 <> "" AND l.result2 is not null) THEN l.result2	
		WHEN (l.result3 <> "" AND l.result3 is not null) THEN l.result3
		WHEN (l.result4 <> "" AND l.result4 is not null) THEN l.result4
	END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1581
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	  
	  /*End migration for Recherche de BARR par Fluorochrome Specimen 1*/
	  /*Migration for Specimen 2 a verifier*/
	/*End migration for Mycobacteriologie part*/
	
	/*Start migration for Endocrinologie Part*/
		/*Start migration for B-HCG*/
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	1945,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1601
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1945,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (
				(l.result like lower("NEG%"))
				OR (l.result2 like lower("NEG%"))
				OR (l.result3 like lower("NEG%"))
				OR (l.result4 like lower("NEG%"))
			  ) THEN 664
		WHEN (
				(l.result like lower("POS%"))
				OR (l.result2 like lower("POS%"))
				OR (l.result3 like lower("POS%"))
				OR (l.result4 like lower("POS%"))
			  ) THEN 703
		WHEN (
				(l.result like lower("IND%"))
				OR (l.result2 like lower("IND%"))
				OR (l.result3 like lower("IND%"))
				OR (l.result4 like lower("IND%"))
			  ) THEN 1138
		END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1601
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
		/*End migration for B-HCG*/
		/*Start migration for FSH*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	161489,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1594
	AND (l.result <> "" AND digits(l.result) >= 0);
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161489,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1594
	AND (l.result <> "" AND digits(l.result) >= 0);
		/*End migration for FSH*/
		
		/*Start migration for LH*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	161490,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1596
	AND (l.result <> "" AND digits(l.result) >= 0);
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161490,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1596
	AND (l.result <> "" AND digits(l.result) >= 0);
		/*End migration for LH*/
		/*Start migration for Oestrogene*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163629,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1598
	AND (l.result <> "" AND digits(l.result) >= 0);
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163629,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1598
	AND (l.result <> "" AND digits(l.result) >= 0);
		/*End migration for Oestrogene*/
		/*Start migration for Progesterone*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	161159,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1599
	AND (l.result <> "" AND digits(l.result) >= 0);
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161159,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1599
	AND (l.result <> "" AND digits(l.result) >= 0);
		/*End migration for Progesterone*/
		/*Start migration for Prolactine*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	161516,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1593
	AND (l.result <> "" AND digits(l.result) >= 0);
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161516,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1593
	AND (l.result <> "" AND digits(l.result) >= 0);
		/*End migration for Prolactine*/
		/*Start migration for T3*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	161503,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1600
	AND (l.result <> "" AND digits(l.result) >= 0);
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161503,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1600
	AND (l.result <> "" AND digits(l.result) >= 0);
		/*End migration for T3*/
		/*Start migration for T4*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	161504,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1604
	AND (l.result <> "" AND digits(l.result) >= 0);
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161504,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1604
	AND (l.result <> "" AND digits(l.result) >= 0);
		
		/*End migration for T4*/
		/*Start migration for Test de Grossesse*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	45,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1603
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,45,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (
				(l.result like lower("NEG%"))
				OR (l.result2 like lower("NEG%"))
				OR (l.result3 like lower("NEG%"))
				OR (l.result4 like lower("NEG%"))
			  ) THEN 664
		WHEN (
				(l.result like lower("POS%"))
				OR (l.result2 like lower("POS%"))
				OR (l.result3 like lower("POS%"))
				OR (l.result4 like lower("POS%"))
			  ) THEN 703
		WHEN (
				(l.result like lower("IND%"))
				OR (l.result2 like lower("IND%"))
				OR (l.result3 like lower("IND%"))
				OR (l.result4 like lower("IND%"))
			  ) THEN 1138
		WHEN (
				(l.result like lower("ECHANTILLON DE PAUVRE%"))
				OR (l.result2 like lower("ECHANTILLON DE PAUVRE%"))
				OR (l.result3 like lower("ECHANTILLON DE PAUVRE%"))
				OR (l.result4 like lower("ECHANTILLON DE PAUVRE%"))
			  ) THEN 1304
		END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1603
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
		/*End migration for Test de Grossesse*/

		/*Start migration for TSH*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	161505,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1605
	AND (l.result <> "" AND digits(l.result) >= 0);
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161505,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1605
	AND (l.result <> "" AND digits(l.result) >= 0);
		/*End migration for TSH*/
	/*End migration for Endocrinologie Part*/
	/*Start migration for Liquides Biologiques Part*/
		/*Start migration for LCR ZIELH NIELSEN*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	161466,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1607
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161466,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (
				(l.result like lower("NEG%"))
				OR (l.result2 like lower("NEG%"))
				OR (l.result3 like lower("NEG%"))
				OR (l.result4 like lower("NEG%"))
			  ) THEN 664
		WHEN (
				(l.result like ("1%") OR l.result like lower("UN%") OR l.result like ("+"))
				OR (l.result2 like ("1%") OR l.result2 like lower("UN%") OR l.result like ("+"))
				OR (l.result3 like ("1%") OR l.result3 like lower("UN%") OR l.result like ("+"))
				OR (l.result4 like ("1%") OR l.result4 like lower("UN%") OR l.result like ("+"))
			  ) THEN 1362
		WHEN (
				(l.result like ("2%") OR l.result like lower("DE%") OR l.result like ("++"))
				OR (l.result2 like ("2%") OR l.result2 like lower("DE%") OR l.result2 like ("++"))
				OR (l.result3 like ("2%") OR l.result3 like lower("DE%") OR l.result3 like ("++"))
				OR (l.result4 like ("2%") OR l.result4 like lower("DE%") OR l.result4 like ("+++"))
			  ) THEN 1363
		WHEN (
				(l.result like ("3%") OR l.result like lower("TROIS%") OR l.result like ("+++"))
				OR (l.result2 like ("3%") OR l.result2 like lower("TROIS%") OR l.result2 like ("+++"))
				OR (l.result3 like ("3%") OR l.result3 like lower("TROIS%") OR l.result3 like ("+++"))
				OR (l.result4 like ("3%") OR l.result4 like lower("TROIS%") OR l.result4 like ("+++"))
			  ) THEN 1364
		WHEN (
				(l.result like ("4%") OR l.result like lower("QUATRE%") OR l.result like ("++++"))
				OR (l.result2 like ("4%") OR l.result2 like lower("QUATRE%") OR l.result2 like ("++++"))
				OR (l.result3 like ("4%") OR l.result3 like lower("QUATRE%") OR l.result3 like ("++++"))
				OR (l.result4 like ("4%") OR l.result4 like lower("QUATRE%") OR l.result4 like ("++++"))
			  ) THEN 1365
		END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1607
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
		/*End migration for LCR ZIELH NIELSEN*/
	/*End migration for Liquides Biologiques Part*/
	/*Start migration for Serologie Part*/
		/*Start migration for ASO*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	161469,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1634
	AND (l.result <> "");
	 /*Migration for obsgroup of CCMH*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,161478,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l 
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum and 
	c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1634 and l.result is not null;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=161478 
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161469,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1634
	AND (l.result <> "" AND digits(l.result) >= 0);
		/*End migration for ASO*/
		/*Start migration for Chlamydia Ab*/
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163618,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1629
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163618,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (
				(l.result like lower("NEG%"))
				OR (l.result2 like lower("NEG%"))
				OR (l.result3 like lower("NEG%"))
				OR (l.result4 like lower("NEG%"))
			  ) THEN 664
		WHEN (
				(l.result like lower("POS%"))
				OR (l.result2 like lower("POS%"))
				OR (l.result3 like lower("POS%"))
				OR (l.result4 like lower("POS%"))
			  ) THEN 703
		END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1629
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
		/*End migration for Chlamydia Ab*/
		/*Start migration for Chlamydia Ag*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163619,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1630
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163619,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (
				(l.result like lower("NEG%"))
				OR (l.result2 like lower("NEG%"))
				OR (l.result3 like lower("NEG%"))
				OR (l.result4 like lower("NEG%"))
			  ) THEN 664
		WHEN (
				(l.result like lower("POS%"))
				OR (l.result2 like lower("POS%"))
				OR (l.result3 like lower("POS%"))
				OR (l.result4 like lower("POS%"))
			  ) THEN 703
		END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1630
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
		/*End migration for Chlamydia Ag*/
		/*Start migration for Clostridium Difficile Toxin A &amp; B*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163612,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1648
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163612,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (
				(l.result like lower("NEG%"))
				OR (l.result2 like lower("NEG%"))
				OR (l.result3 like lower("NEG%"))
				OR (l.result4 like lower("NEG%"))
			  ) THEN 664
		WHEN (
				(l.result like lower("POS%"))
				OR (l.result2 like lower("POS%"))
				OR (l.result3 like lower("POS%"))
				OR (l.result4 like lower("POS%"))
			  ) THEN 703
		END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1648
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
		/*End migration for Clostridium Difficile Toxin A &amp; B*/
		
		/*Start migration for CMV Ig A*/
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	161527,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1646
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161527,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (
				(l.result like lower("NEG%"))
				OR (l.result2 like lower("NEG%"))
				OR (l.result3 like lower("NEG%"))
				OR (l.result4 like lower("NEG%"))
			  ) THEN 664
		WHEN (
				(l.result like lower("POS%"))
				OR (l.result2 like lower("POS%"))
				OR (l.result3 like lower("POS%"))
				OR (l.result4 like lower("POS%"))
			  ) THEN 703
		WHEN (
				(l.result like lower("IND%"))
				OR (l.result2 like lower("IND%"))
				OR (l.result3 like lower("IND%"))
				OR (l.result4 like lower("IND%"))
			  ) THEN 1138
		END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1646
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
		/*End migration for CMV Ig A*/
		
		/*Start migration for CMV Ig G*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	161526,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1645
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161526,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (
				(l.result like lower("NEG%"))
				OR (l.result2 like lower("NEG%"))
				OR (l.result3 like lower("NEG%"))
				OR (l.result4 like lower("NEG%"))
			  ) THEN 664
		WHEN (
				(l.result like lower("POS%"))
				OR (l.result2 like lower("POS%"))
				OR (l.result3 like lower("POS%"))
				OR (l.result4 like lower("POS%"))
			  ) THEN 703
		WHEN (
				(l.result like lower("IND%"))
				OR (l.result2 like lower("IND%"))
				OR (l.result3 like lower("IND%"))
				OR (l.result4 like lower("IND%"))
			  ) THEN 1138
		END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1645
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
		/*End migration for CMV Ig G*/
		
		/*Start migration for CRP*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	161500,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1631
	AND (l.result <> "" AND digits(l.result) >= 0);
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161500,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1631
	AND (l.result <> "" AND digits(l.result) >= 0);
		/*End migration for CRP*/
		/*Start migration for Cryptococcus Antigene dipstick*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163613,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1647
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	 
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_text,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163613,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (l.result <> "" AND l.result is not null) THEN l.result
		WHEN (l.result2 <> "" AND l.result2 is not null) THEN l.result2	
		WHEN (l.result3 <> "" AND l.result3 is not null) THEN l.result3
		WHEN (l.result4 <> "" AND l.result4 is not null) THEN l.result4
	END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1647
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
		/*End migration for Cryptococcus Antigene dipstick*/
	   /*Start migration for Dengue Ig A*/
	   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163617,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1644
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163617,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (
				(l.result like lower("NEG%"))
				OR (l.result2 like lower("NEG%"))
				OR (l.result3 like lower("NEG%"))
				OR (l.result4 like lower("NEG%"))
			  ) THEN 664
		WHEN (
				(l.result like lower("POS%"))
				OR (l.result2 like lower("POS%"))
				OR (l.result3 like lower("POS%"))
				OR (l.result4 like lower("POS%"))
			  ) THEN 703
		END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1644
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	   /*End migration for Dengue Ig A*/
	   /*Start migration for Dengue Ig G*/
	   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163616,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1643
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163616,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (
				(l.result like lower("NEG%"))
				OR (l.result2 like lower("NEG%"))
				OR (l.result3 like lower("NEG%"))
				OR (l.result4 like lower("NEG%"))
			  ) THEN 664
		WHEN (
				(l.result like lower("POS%"))
				OR (l.result2 like lower("POS%"))
				OR (l.result3 like lower("POS%"))
				OR (l.result4 like lower("POS%"))
			  ) THEN 703
		END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1643
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	   /*End migration for Dengue Ig G*/
	   /*Start migration for Helicobacter Pilori*/
	    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163620,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1624
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163620,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (
				(l.result like lower("NEG%"))
				OR (l.result2 like lower("NEG%"))
				OR (l.result3 like lower("NEG%"))
				OR (l.result4 like lower("NEG%"))
			  ) THEN 664
		WHEN (
				(l.result like lower("POS%"))
				OR (l.result2 like lower("POS%"))
				OR (l.result3 like lower("POS%"))
				OR (l.result4 like lower("POS%"))
			  ) THEN 703
		END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1624
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	   /*End migration for Helicobacter Pilori*/
	   
	   /*Start migration for Herpes Simplex*/
	   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	908,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1627
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,908,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (
				(l.result like lower("NEG%"))
				OR (l.result2 like lower("NEG%"))
				OR (l.result3 like lower("NEG%"))
				OR (l.result4 like lower("NEG%"))
			  ) THEN 664
		WHEN (
				(l.result like lower("POS%"))
				OR (l.result2 like lower("POS%"))
				OR (l.result3 like lower("POS%"))
				OR (l.result4 like lower("POS%"))
			  ) THEN 703
		WHEN (
				(l.result like lower("ECHANTILLON DE PAUVRE QUALITE"))
				OR (l.result2 like lower("ECHANTILLON DE PAUVRE QUALITE"))
				OR (l.result3 like lower("ECHANTILLON DE PAUVRE QUALITE"))
				OR (l.result4 like lower("ECHANTILLON DE PAUVRE QUALITE"))
			  ) THEN 1304
		WHEN (
				(l.result like lower("%EQUIVOQUE%"))
				OR (l.result2 like lower("%EQUIVOQUE%"))
				OR (l.result3 like lower("%EQUIVOQUE%"))
				OR (l.result4 like lower("%EQUIVOQUE%"))
			  ) THEN 1300
		END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1627
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	   /*End migration for Herpes Simplex*/
	   /*Start migration for HTLV I et II*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163627,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1616
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163627,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (
				(l.result like lower("NEG%"))
				OR (l.result2 like lower("NEG%"))
				OR (l.result3 like lower("NEG%"))
				OR (l.result4 like lower("NEG%"))
			  ) THEN 664
		WHEN (
				(l.result like lower("POS%"))
				OR (l.result2 like lower("POS%"))
				OR (l.result3 like lower("POS%"))
				OR (l.result4 like lower("POS%"))
			  ) THEN 703
		END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1616
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	   /*End migration for HTLV I et II*/
	   
	  /*Start migration for LE Cell*/ 
	  INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163615,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1642
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163615,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (
				(l.result like lower("NEG%"))
				OR (l.result2 like lower("NEG%"))
				OR (l.result3 like lower("NEG%"))
				OR (l.result4 like lower("NEG%"))
			  ) THEN 664
		WHEN (
				(l.result like lower("POS%"))
				OR (l.result2 like lower("POS%"))
				OR (l.result3 like lower("POS%"))
				OR (l.result4 like lower("POS%"))
			  ) THEN 703
		WHEN (
				(l.result like lower("IND%"))
				OR (l.result2 like lower("IND%"))
				OR (l.result3 like lower("IND%"))
				OR (l.result4 like lower("IND%"))
			  ) THEN 1138
		END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1642
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	
	/*End migration for LE Cell*/
	/*Start migration for Mono Test*/ 
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163614,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1641
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163614,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (
				(l.result like lower("NEG%"))
				OR (l.result2 like lower("NEG%"))
				OR (l.result3 like lower("NEG%"))
				OR (l.result4 like lower("NEG%"))
			  ) THEN 664
		WHEN (
				(l.result like lower("POS%"))
				OR (l.result2 like lower("POS%"))
				OR (l.result3 like lower("POS%"))
				OR (l.result4 like lower("POS%"))
			  ) THEN 703
		END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1641
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*End migration for Mono Test*/
	
	/*Start migration for Syphilis RPR*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	1619,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1618
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1619,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (
				(l.result like lower("NEG%"))
				OR (l.result2 like lower("NEG%"))
				OR (l.result3 like lower("NEG%"))
				OR (l.result4 like lower("NEG%"))
			  ) THEN 664
		WHEN (
				(l.result like lower("POS%"))
				OR (l.result2 like lower("POS%"))
				OR (l.result3 like lower("POS%"))
				OR (l.result4 like lower("POS%"))
			  ) THEN 703
		WHEN (
				(l.result like lower("INCONNU%"))
				OR (l.result2 like lower("INCONNU%"))
				OR (l.result3 like lower("INCONNU%"))
				OR (l.result4 like lower("INCONNU%"))
			  ) THEN 1067
		END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1618
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*End migration for Syphilis RPR*/
	 /*Start migration for Syphilis Test Rapide*/ 
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163626,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1611
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163626,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (
				(l.result like lower("NEG%"))
				OR (l.result2 like lower("NEG%"))
				OR (l.result3 like lower("NEG%"))
				OR (l.result4 like lower("NEG%"))
			  ) THEN 664
		WHEN (
				(l.result like lower("POS%"))
				OR (l.result2 like lower("POS%"))
				OR (l.result3 like lower("POS%"))
				OR (l.result4 like lower("POS%"))
			  ) THEN 703
		END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1611
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*End migration for Syphilis Test Rapide*/
	/*Start migration for Syphilis TPHA*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	1031,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1620
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1031,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (
				(l.result like lower("<1:2"))
				OR (l.result2 like lower("<1:2"))
				OR (l.result3 like lower("<1:2"))
				OR (l.result4 like lower("<1:2"))
			  ) THEN 1311
		WHEN (
				(l.result like lower("1:2"))
				OR (l.result2 like lower("1:2"))
				OR (l.result3 like lower("1:2"))
				OR (l.result4 like lower("1:2"))
			  ) THEN 1312
		WHEN (
				(l.result like lower("1:4"))
				OR (l.result2 like lower("1:4"))
				OR (l.result3 like lower("1:4"))
				OR (l.result4 like lower("1:4"))
			  ) THEN 1313
		WHEN (
				(l.result like lower("1:8"))
				OR (l.result2 like lower("1:8"))
				OR (l.result3 like lower("1:8"))
				OR (l.result4 like lower("1:8"))
			  ) THEN 1314
		WHEN (
				(l.result like lower("1:16"))
				OR (l.result2 like lower("1:16"))
				OR (l.result3 like lower("1:16"))
				OR (l.result4 like lower("1:16"))
			  ) THEN 1315
		WHEN (
				(l.result like lower("1:32"))
				OR (l.result2 like lower("1:32"))
				OR (l.result3 like lower("1:32"))
				OR (l.result4 like lower("1:32"))
			  ) THEN 1316
		WHEN (
				(l.result like lower(">1:32"))
				OR (l.result2 like lower(">1:32"))
				OR (l.result3 like lower(">1:32"))
				OR (l.result4 like lower(">1:32"))
			  ) THEN 1317
		WHEN (
				(l.result like lower("1:64"))
				OR (l.result2 like lower("1:64"))
				OR (l.result3 like lower("1:64"))
				OR (l.result4 like lower("1:64"))
			  ) THEN 163621
		WHEN (
				(l.result like lower("1:128"))
				OR (l.result2 like lower("1:128"))
				OR (l.result3 like lower("1:128"))
				OR (l.result4 like lower("1:128"))
			  ) THEN 163622
		WHEN (
				(l.result like lower("1:256"))
				OR (l.result2 like lower("1:256"))
				OR (l.result3 like lower("1:256"))
				OR (l.result4 like lower("1:256"))
			  ) THEN 163623
		WHEN (
				(l.result like lower(">1:572"))
				OR (l.result2 like lower(">1:572"))
				OR (l.result3 like lower(">1:572"))
				OR (l.result4 like lower(">1:572"))
			  ) THEN 163624
		END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1620
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*End migration for Syphilis TPHA*/
	/*Start migration for Test de Widal Ag O/H*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	306,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1638
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,306,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (
				(l.result like lower("REACTI%"))
				OR (l.result2 like lower("REACTI%"))
				OR (l.result3 like lower("REACTI%"))
				OR (l.result4 like lower("REACTI%"))
			  ) THEN 1228
		WHEN (
				(l.result like lower("NON REACTI%"))
				OR (l.result2 like lower("NON REACTI%"))
				OR (l.result3 like lower("NON REACTI%"))
				OR (l.result4 like lower("NON REACTI%"))
			  ) THEN 1229
		END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1638
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*End migration for Test de Widal Ag O/H*/
	/*Start migration for TOXOPLASMOSE GONDII Ig M Ac*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	161523,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1609
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161523,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (
				(l.result like lower("NEG%"))
				OR (l.result2 like lower("NEG%"))
				OR (l.result3 like lower("NEG%"))
				OR (l.result4 like lower("NEG%"))
			  ) THEN 664
		WHEN (
				(l.result like lower("POS%"))
				OR (l.result2 like lower("POS%"))
				OR (l.result3 like lower("POS%"))
				OR (l.result4 like lower("POS%"))
			  ) THEN 703
		WHEN (
				(l.result like lower("IND%"))
				OR (l.result2 like lower("IND%"))
				OR (l.result3 like lower("IND%"))
				OR (l.result4 like lower("IND%"))
			  ) THEN 1138
		END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1609
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*End migration for TOXOPLASMOSE GONDII Ig M Ac*/
	/*Start migration for TOXOPLASMOSE GONDII IgG Ac*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	161522,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1608
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161522,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (
				(l.result like lower("NEG%"))
				OR (l.result2 like lower("NEG%"))
				OR (l.result3 like lower("NEG%"))
				OR (l.result4 like lower("NEG%"))
			  ) THEN 664
		WHEN (
				(l.result like lower("POS%"))
				OR (l.result2 like lower("POS%"))
				OR (l.result3 like lower("POS%"))
				OR (l.result4 like lower("POS%"))
			  ) THEN 703
		WHEN (
				(l.result like lower("IND%"))
				OR (l.result2 like lower("IND%"))
				OR (l.result3 like lower("IND%"))
				OR (l.result4 like lower("IND%"))
			  ) THEN 1138
		END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1608
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*End migration for TOXOPLASMOSE GONDII IgG Ac*/
	
	/*End migration for Serologie Part*/
	
	/*Start migration for CDV*/
		/*Start migration for Determine VIH*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	1040,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1649
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	
	/*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,163628,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum
	and c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=1649
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=163628
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1040,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
	CASE WHEN (
				(l.result like lower("NEG%"))
				OR (l.result2 like lower("NEG%"))
				OR (l.result3 like lower("NEG%"))
				OR (l.result4 like lower("NEG%"))
			  ) THEN 664
		 WHEN (
				(l.result like lower("POS%"))
				OR (l.result2 like lower("POS%"))
				OR (l.result3 like lower("POS%"))
				OR (l.result4 like lower("POS%"))
			  ) THEN 703
		END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=1649
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
		/*End migration for Determine VIH*/
		
	/*Start migration for Colloidal Gold*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	1326,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1652
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1326,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (
				(l.result like lower("NEG%"))
				OR (l.result2 like lower("NEG%"))
				OR (l.result3 like lower("NEG%"))
				OR (l.result4 like lower("NEG%"))
			  ) THEN 664
		WHEN (
				(l.result like lower("POS%"))
				OR (l.result2 like lower("POS%"))
				OR (l.result3 like lower("POS%"))
				OR (l.result4 like lower("POS%"))
			  ) THEN 703
		END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1652
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*End migration for Colloidal Gold*/
	
	/*Start migration for Syphilis test rapide*/

	/*End migration for Syphilis test rapide*/

	/*End migration for CDV PART*/
	
	/*Start migration for Autres Test Part*/
	/*Start migration for PSA*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	160913,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1658
	AND (l.result <> "" AND digits(l.result) >= 0);
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,160913,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,digits(l.result) as resultat,l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=1658
	AND (l.result <> "" AND digits(l.result) >= 0);
	/*End migration for PSA*/
	/*End migration for Autres Tests Part*/
	/*Start migration for Biologie Moleculaire Part*/
		/*Start migration for Charge virale*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	856,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l 
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=103
	AND (
		(l.result <> "" AND digits(l.result) >= 0)
		OR
		(l.result2 <> "" AND digits(l.result2) >= 0)
		OR
		(l.result3 <> "" AND digits(l.result3) >= 0)
		OR
		(l.result4 <> "" AND digits(l.result4) >= 0)
	);
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,856,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (digits(l.result) > 0) THEN digits(l.result)
		WHEN (digits(l.result2) > 0) THEN digits(l.result2)
		WHEN (digits(l.result3) > 0) THEN digits(l.result3)
		WHEN (digits(l.result4) > 0) THEN digits(l.result4)
	END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=103
	AND (
		(l.result <> "" AND digits(l.result) > 0)
		OR
		(l.result2 <> "" AND digits(l.result2) > 0)
		OR
		(l.result3 <> "" AND digits(l.result3) > 0)
		OR
		(l.result4 <> "" AND digits(l.result4) > 0)
	);
		/*End migration for Charge virale*/
		/*Start migration for PCR (Important to discuss)*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	844,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=181
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,844,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (
				(l.result like lower("NEG%"))
				OR (l.result2 like lower("NEG%"))
				OR (l.result3 like lower("NEG%"))
				OR (l.result4 like lower("NEG%"))
			  ) THEN 1302
		WHEN (
				(l.result like lower("POS%"))
				OR (l.result2 like lower("POS%"))
				OR (l.result3 like lower("POS%"))
				OR (l.result4 like lower("POS%"))
			  ) THEN 1301
		END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=181
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
		/*End migration for PCR*/
		
		/*Start migration for Test de resistance TB*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	159984,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=305
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	
	/*Migration for obsgroup*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT e.patient_id,159983,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
	FROM itech.encounter c, encounter e, itech.labs l
	WHERE e.uuid = c.encGuid and c.patientID = l.patientID and c.seqNum = l.seqNum
	and c.sitecode = l.sitecode and DATE(e.encounter_datetime) = DATE_FORMAT(concat(l.visitDateYy,'-',l.visitDateMm,'-',l.visitDateDd),"%Y-%m-%d") AND 
	l.labID=305
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=159983
	GROUP BY openmrs.obs.person_id,encounter_id;
   /*Answer*/
   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159984,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
	CASE WHEN (
				(l.result like lower("RESISTANTES AUX MEDICAMENTS ANTI-TUBERCULOSE%"))
				OR (l.result2 like lower("RESISTANTES AUX MEDICAMENTS ANTI-TUBERCULOSE%"))
				OR (l.result3 like lower("RESISTANTES AUX MEDICAMENTS ANTI-TUBERCULOSE%"))
				OR (l.result4 like lower("RESISTANTES AUX MEDICAMENTS ANTI-TUBERCULOSE%"))
			  ) THEN 159956
		 WHEN (
				(l.result like lower("%RIFAMPICINE%"))
				OR (l.result2 like lower("%RIFAMPICINE%"))
				OR (l.result3 like lower("%RIFAMPICINE%"))
				OR (l.result4 like lower("%RIFAMPICINE%"))
			  ) THEN 767
		WHEN (
				(l.result like lower("%ISONIAZID%"))
				OR (l.result2 like lower("%ISONIAZID%"))
				OR (l.result3 like lower("%ISONIAZID%"))
				OR (l.result4 like lower("%ISONIAZID%"))
			  ) THEN 78280
		WHEN (
				(l.result like lower("%SENSIBLES AUX MEDICAMENTS ANTITUBERCULEUX%"))
				OR (l.result2 like lower("%SENSIBLES AUX MEDICAMENTS ANTITUBERCULEUX%"))
				OR (l.result3 like lower("%SENSIBLES AUX MEDICAMENTS ANTITUBERCULEUX%"))
				OR (l.result4 like lower("%SENSIBLES AUX MEDICAMENTS ANTITUBERCULEUX%"))
			  ) THEN 159958
		WHEN (
				(l.result like lower("INVALID%"))
				OR (l.result2 like lower("INVALID%"))
				OR (l.result3 like lower("INVALID%"))
				OR (l.result4 like lower("INVALID%"))
			  ) THEN 163611
		END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND l.labID=305
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
		/*End migration for Test de resistance TB*/
		
		/*Start migration for Test de resistance VIH*/
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1271,c.encounter_id,e.createDate,c.location_id,
	163610,1,e.createDate,
	UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=304
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
	 
   /*Answer*/
    INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_text,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163610,c.encounter_id,
	CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
			AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.resultDateMm) < 1 OR FindNumericValue(l.resultDateMm) is null)
		AND (FindNumericValue(l.resultDateDd) > 0 AND FindNumericValue(l.resultDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null)
	    AND (FindNumericValue(l.resultDateMm) > 0 AND FindNumericValue(l.resultDateMm) is not null)
		AND (FindNumericValue(l.resultDateDd) < 1) OR FindNumericValue(l.resultDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",FindNumericValue(l.resultDateMm),"-",FindNumericValue(l.resultDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (l.result <> "" AND l.result is not null) THEN l.result
		WHEN (l.result2 <> "" AND l.result2 is not null) THEN l.result2	
		WHEN (l.result3 <> "" AND l.result3 is not null) THEN l.result3
		WHEN (l.result4 <> "" AND l.result4 is not null) THEN l.result4
	END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
	and e.seqNum = l.seqNum
	AND l.labID=304
	AND ((l.result <> "" AND l.result is not null)
		OR (l.result2 <> "" AND l.result2 is not null)
		OR (l.result3 <> "" AND l.result3 is not null)
		OR (l.result4 <> "" AND l.result4 is not null)
	);
		/*End migration for Test de resistance VIH*/
		
	/*End migration for Biologie Moleculaire Part*/
	
	
	/*Ending migration for labs data*/
	
 END$$
	DELIMITER ;