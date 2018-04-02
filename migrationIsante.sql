drop procedure if exists migrationIsante;
DELIMITER $$ 
CREATE PROCEDURE migrationIsante()
BEGIN

SET SQL_SAFE_UPDATES = 0;
/* Clean openmrs database before import */
 call cleanOpenmrs();

/* patient registration migration */
SET SQL_SAFE_UPDATES = 0;
   call patientDemographics();
/* visit and Encounter migration*/
SET SQL_SAFE_UPDATES = 0;
   call encounter_Migration();
/* fistVisit migration VIH form */
SET SQL_SAFE_UPDATES = 0;
   call adult_visit_Migration();
   SET SQL_SAFE_UPDATES = 0;
/* pediatric visit HIV migration */
   call pediatric_visit_Migration();
   SET SQL_SAFE_UPDATES = 0;
 /* Lab migration  */
   call labsMigration();
   SET SQL_SAFE_UPDATES = 0;
/* ordonance migration */ 
   call ordonanceMigration();
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