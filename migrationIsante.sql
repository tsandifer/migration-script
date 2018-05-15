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

DROP FUNCTION if exists `formatDate`;
DELIMITER $$
CREATE FUNCTION `formatDate`( dateYy int,dateMm int,dateDd int ) RETURNS char(32) CHARSET utf8
BEGIN
  IF (FindNumericValue(dateYy)<=0)
  THEN 
    RETURN null;
  END IF;
  
  IF(length(dateYy)<=2) 
  THEN 
   set dateYy=concat('20',FindNumericValue(dateYy));
   END IF;
  
  IF(dateMm is null or dateMm='XX' or dateMm='' or dateMm>12 or dateMm<1)
  THEN 
   set dateMm='01';
   END IF;
 
  IF(dateDd is null or dateDd='XX' or dateDd='' or dateDd>31 or dateDd<1)
  THEN 
   set dateDd='01';
   END IF;
 
 IF((dateMm='01' or dateMm='03' or dateMm='05' or dateMm='07' or dateMm='08' or dateMm='10' or dateMm='12') and dateDd>31)
 THEN 
  set dateDd='31';
  END IF;
 
  IF((dateMm='04' or dateMm='06' or dateMm='09' or dateMm='11') and dateDd>30)
 THEN 
  set dateDd='30';
  END IF;
  
 IF((dateMm='02') and dateDd>29)
 THEN 
  set dateDd='28';
  END IF;
 
  RETURN concat (dateYy,'-',dateMm,'-',dateDd);
END$$
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


drop procedure if exists migrationIsante;
DELIMITER $$ 
CREATE PROCEDURE migrationIsante()
BEGIN

SET SQL_SAFE_UPDATES = 0;
/* Clean openmrs database before import */
 call cleanOpenmrs();
select 1  as CleanOpenmrs;
/* patient registration migration */
SET SQL_SAFE_UPDATES = 0;
   call patientDemographics();
   select 2 as Demographic;
/* visit and Encounter migration*/
SET SQL_SAFE_UPDATES = 0;
   call encounter_Migration();
   select 3 as Encounter;
/* fistVisit migration VIH form */
SET SQL_SAFE_UPDATES = 0;
   call adult_visit_Migration();
   select 4 as Adult;
   SET SQL_SAFE_UPDATES = 0;
/* pediatric visit HIV migration */
   call pediatric_visit_Migration();
   
   select 5 as Pediatric;
   SET SQL_SAFE_UPDATES = 0;
 /* Lab migration  */
   call labsMigration();
   select 6 as Lab;
   SET SQL_SAFE_UPDATES = 0;
/* ordonance migration */ 
   call ordonanceMigration();
   select 7 as Ordonance;
   SET SQL_SAFE_UPDATES = 0;
/* discontinutation */   
   call discontinuationMigration();
   SET SQL_SAFE_UPDATES = 0;
/* travail et accouchemnet*/
   call travailAccMigration();
   SET SQL_SAFE_UPDATES = 0;
/* Adherence */
   call  adherenceMigration();
   SET SQL_SAFE_UPDATES = 0;
   
/* OBGYN */   
 call obgynMigration();
 SET SQL_SAFE_UPDATES = 0;

/* SOINS SANTE PRIMAIRE ADULTE */ 
 call sspAdultMigration();
SET SQL_SAFE_UPDATES = 0;
/* SOINS SANTE PRIMAIRE ADULTE */  
 call sspPediatricMigration();
SET SQL_SAFE_UPDATES = 0;
 
 /* migration for next VisitDate*/  
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_datetime,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,5096,e.encounter_id,e.encounter_datetime,e.location_id,
    CASE WHEN c.nxtVisitYy>0 and c.nxtVisitMm>0 and c.nxtVisitDd>0 THEN date(concat(c.nxtVisitYy,'-',c.nxtVisitMm,'-',c.nxtVisitDd))
	     WHEN c.nxtVisitYy>0 and c.nxtVisitMm>0 and c.nxtVisitDd<1 THEN date(concat(c.nxtVisitYy,'-',c.nxtVisitMm,'-01'))
	     WHEN c.nxtVisitYy>0 and c.nxtVisitMm<1 and c.nxtVisitDd<1 THEN date(concat(c.nxtVisitYy,'-01-01'))
		ELSE NULL
	END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e
WHERE e.uuid = c.encGuid ;

/*Statut de la fiche*/
/* complete/Incomplete */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163340,e.encounter_id,e.encounter_datetime,e.location_id,
    CASE WHEN encStatus=5 or encStatus=7 THEN 163339
	     WHEN encStatus=1 or encStatus=3 or encStatus=0 THEN 1267	 
		ELSE NULL
	END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e
WHERE e.uuid = c.encGuid and encStatus in (0,1,3,5,7);

/* La fiche doit être passée en revue par la personne responsable de la qualité des données. */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163341,e.encounter_id,e.encounter_datetime,e.location_id,
    CASE WHEN encStatus=3 or encStatus=7 THEN 1065	 
		ELSE NULL
	END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e
WHERE e.uuid = c.encGuid and encStatus in (3,7);

/*Evaluation et plan */



/*visit suivi */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159395,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.followupComments<>'' then v.followupComments
ELSE NULL
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.followupTreatment v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')= concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.followupComments<>'';



/* premiere visit  */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159395,e.encounter_id,e.encounter_datetime,e.location_id,
CASE WHEN v.assessmentPlan<>'' then v.assessmentPlan
ELSE NULL
END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e, itech.vitals v 
WHERE e.uuid = c.encGuid and c.patientID = v.patientID and c.seqNum = v.seqNum and 
c.sitecode = v.sitecode and date_format(date(e.encounter_datetime),'%y-%m-%d')= concat(v.visitDateYy,'-',v.visitDateMm,'-',v.visitDateDd) AND 
v.assessmentPlan<>'';



 /* migration for From Autor*/  
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_text,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1473,e.encounter_id,e.encounter_datetime,e.location_id,
    CASE WHEN ifnull(formAuthor,'')<>'' and  ifnull(formAuthor2,'')<>'' then concat(formAuthor,' / ',formAuthor2)
	     WHEN ifnull(formAuthor,'')<>'' and  ifnull(formAuthor2,'')='' then formAuthor
		 WHEN ifnull(formAuthor,'')='' and  ifnull(formAuthor2,'')<>'' then formAuthor2
		ELSE NULL
	END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e
WHERE e.uuid = c.encGuid ;


   
END$$