drop procedure if exists migrationIsante;
DELIMITER $$ 
CREATE PROCEDURE migrationIsante()
BEGIN

/* patient registration migration */
   call patientDemographics();
/* visit and Encounter migration*/
   call encounter_Migration();
/* fistVisit migration VIH form */
   call adult_visit_Migration();
/* pediatric visit HIV migration */
   call pediatric_visit_Migration();
 /* Lab migration  */
   call labsMigration();
/* ordonance migration */ 
   call ordonanceMigration();
/* discontinutation */   
   call discontinuationMigration();
/* travail et accouchemnet*/
   call travailAccMigration();
/* Adherence */
   call  adherenceMigration();
   
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
	     WHEN encStatus=1 or encStatus=3 THEN 1267	 
		ELSE NULL
	END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e
WHERE e.uuid = c.encGuid ;

/* La fiche doit être passée en revue par la personne responsable de la qualité des données. */
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,163341,e.encounter_id,e.encounter_datetime,e.location_id,
    CASE WHEN encStatus=3 or encStatus=7 THEN 1065	 
		ELSE NULL
	END,1,e.date_created,UUID()
FROM itech.encounter c, encounter e
WHERE e.uuid = c.encGuid ;

   
END$$