<<<<<<< HEAD

drop procedure if exists migrationIsante;

CREATE PROCEDURE migrationIsante()
BEGIN

/* visit en Encounter migration*/
   call visitEncounterMigration();
/* fistVisit migration form */
   call firstVisitMigration();
/* patient registration migration */
   call patientDemographics();
/* migration encounter/Adult visit HIV */
   call clinicMigration();
/* pediatric visit HIV migration */
   call clinicPediatricMigration();
 /* Lab migration  */
   call labsMigration();
/* ordonance migration */ 
   call ordonanceMigration();
=======
CREATE PROCEDURE migrationIsante()
BEGIN

/* patient registration migration */
   call patientDemographics();
/* migration encounter/Adult visit HIV */
   call clinicMigration();
/* pediatric visit HIV migration */
   call clinicPediatricMigration();

>>>>>>> d0e3541c99b31eba5d47ab9e3a5fdf522593a760
END;