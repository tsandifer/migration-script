CREATE PROCEDURE migrationIsante()
BEGIN

/* patient registration migration */
   call patientDemographics();
/* migration encounter/Adult visit HIV */
   call clinicMigration();
/* pediatric visit HIV migration */
   call clinicPediatricMigration();

END;