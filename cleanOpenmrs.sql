
DELIMITER $$ 
DROP PROCEDURE IF EXISTS cleanOpenmrs$$
CREATE PROCEDURE cleanOpenmrs()
BEGIN

	 SET SQL_SAFE_UPDATES = 0;
	 SET FOREIGN_KEY_CHECKS=0;

	 
update obs set obs_group_id=null;
delete from obs ;
delete from isanteplus_form_history;
delete from encounter;
delete from visit;


delete from person_attribute where person_id in (select p.person_id from person p, itech.patient j where  j.patGuid = p.uuid);

delete from patient_identifier where patient_id in (select p.person_id from person p, itech.patient j where  j.patGuid = p.uuid);

delete from patient where patient_id in (select p.person_id from person p, itech.patient j where  j.patGuid = p.uuid);
delete from person_address where person_id in (select p.person_id from person p, itech.patient j where  j.patGuid = p.uuid);

delete from person_name where person_id in (select p.person_id from person p, itech.patient j where  j.patGuid = p.uuid);

delete from person where uuid in (select patGuid from itech.patient);

 END$$
	DELIMITER ;