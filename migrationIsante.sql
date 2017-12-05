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
END;