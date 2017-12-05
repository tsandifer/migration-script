DELIMITER $$ 
DROP PROCEDURE IF EXISTS discontinuationMigration$$
CREATE PROCEDURE discontinuationMigration()
BEGIN

	 /*Delete all inserted discontinuations data if the script fail*/
 SET SQL_SAFE_UPDATES = 0;
 SET FOREIGN_KEY_CHECKS=0;
 DELETE FROM obs WHERE encounter_id IN
 (
	SELECT en.encounter_id FROM encounter en, encounter_type ent
	WHERE en.encounter_type=ent.encounter_type_id
	AND ent.uuid='9d0113c6-f23a-4461-8428-7e9a7344f2ba'
 );
  SET SQL_SAFE_UPDATES = 1;
  SET FOREIGN_KEY_CHECKS=1;
  /*End of delete all inserted discontinuations data*/
  
	/*Start migration for discontinuation*/
		/*Start migration for 
		Est-ce que le patient a arrêté définitif de la participation au programme 
		de soins et traitment VIH/SIDA? */
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159811,c.encounter_id,
	CASE WHEN (de.visitDateYy is null AND de.visitDateMm < 1 AND de.visitDateDd < 1) THEN NULL
	WHEN(de.visitDateMm < 1 AND de.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(de.visitDateYy,"-",01,"-",de.visitDateDd),"%Y-%m-%d")
	WHEN(de.visitDateMm > 0 AND de.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(de.visitDateYy,"-",de.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(de.visitDateYy,"-",de.visitDateMm,"-",de.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN de.partStop=1 THEN 1065
	WHEN de.partStop=2 THEN 1066
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.discEnrollment de
	WHERE c.uuid = e.encGuid and 
	e.patientID = de.patientID and e.siteCode = de.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(de.visitdateYy,'-',de.visitDateMm,'-',de.visitDateDd) 
	and e.seqNum = de.seqNum
	AND(de.partStop=1 OR de.partStop=2);
		/*End migration for Est-ce que le patient a arrêté définitif 
		de la participation au programme de soins et traitment VIH/SIDA? */
		
		/*Start migration for Date d'arrêt du programme des soins et traitement VIH/SIDA*/
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_datetime,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,164094,c.encounter_id,
	CASE WHEN (de.visitDateYy is null AND de.visitDateMm < 1 AND de.visitDateDd < 1) THEN NULL
	WHEN(de.visitDateMm < 1 AND de.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(de.visitDateYy,"-",01,"-",de.visitDateDd),"%Y-%m-%d")
	WHEN(de.visitDateMm > 0 AND de.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(de.visitDateYy,"-",de.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(de.visitDateYy,"-",de.visitDateMm,"-",de.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (de.disEnrollYy is null AND de.disEnrollMm < 1 AND de.disEnrollDd < 1) THEN NULL
	WHEN(de.disEnrollMm < 1 AND de.disEnrollDd > 0) THEN 
		DATE_FORMAT(concat(de.disEnrollYy,"-",01,"-",de.disEnrollDd),"%Y-%m-%d")
	WHEN(de.disEnrollMm > 0 AND de.disEnrollDd < 1) THEN 
		DATE_FORMAT(concat(de.disEnrollYy,"-",de.disEnrollMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(de.disEnrollYy,"-",de.disEnrollMm,"-",de.disEnrollDd),"%Y-%m-%d")
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.discEnrollment de
	WHERE c.uuid = e.encGuid and 
	e.patientID = de.patientID and e.siteCode = de.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(de.visitdateYy,'-',de.visitDateMm,'-',de.visitDateDd) 
	and e.seqNum = de.seqNum
	AND(de.disEnrollYy <> "" AND de.disEnrollYy is not null);
		/*End migration for Date d'arrêt du programme des soins et traitement VIH/SIDA*/
		
		/*Start migration for Date du dernier contact avec le patient*/
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_datetime,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,164093,c.encounter_id,
	CASE WHEN (de.visitDateYy is null AND de.visitDateMm < 1 AND de.visitDateDd < 1) THEN NULL
	WHEN(de.visitDateMm < 1 AND de.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(de.visitDateYy,"-",01,"-",de.visitDateDd),"%Y-%m-%d")
	WHEN(de.visitDateMm > 0 AND de.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(de.visitDateYy,"-",de.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(de.visitDateYy,"-",de.visitDateMm,"-",de.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (de.lastContactYy is null AND de.lastContactMm < 1 AND de.lastContactDd < 1) THEN NULL
	WHEN(de.lastContactMm < 1 AND de.lastContactDd > 0) THEN 
		DATE_FORMAT(concat(de.lastContactYy,"-",01,"-",de.lastContactDd),"%Y-%m-%d")
	WHEN(de.lastContactMm > 0 AND de.lastContactDd < 1) THEN 
		DATE_FORMAT(concat(de.lastContactYy,"-",de.lastContactMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(de.lastContactYy,"-",de.lastContactMm,"-",de.lastContactDd),"%Y-%m-%d")
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.discEnrollment de
	WHERE c.uuid = e.encGuid and 
	e.patientID = de.patientID and e.siteCode = de.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(de.visitdateYy,'-',de.visitDateMm,'-',de.visitDateDd) 
	and e.seqNum = de.seqNum
	AND(de.lastContactYy <> "" AND de.lastContactYy is not null);
		/*End migration for Date du dernier contact avec le patient*/
		/*Start migration for Est-ce que le patient recevait traitement ARV?*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1192,c.encounter_id,
	CASE WHEN (de.visitDateYy is null AND de.visitDateMm < 1 AND de.visitDateDd < 1) THEN NULL
	WHEN(de.visitDateMm < 1 AND de.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(de.visitDateYy,"-",01,"-",de.visitDateDd),"%Y-%m-%d")
	WHEN(de.visitDateMm > 0 AND de.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(de.visitDateYy,"-",de.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(de.visitDateYy,"-",de.visitDateMm,"-",de.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN de.everOn=1 THEN 1
	WHEN de.everOn=2 THEN 2
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.discEnrollment de
	WHERE c.uuid = e.encGuid and 
	e.patientID = de.patientID and e.siteCode = de.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(de.visitdateYy,'-',de.visitDateMm,'-',de.visitDateDd) 
	and e.seqNum = de.seqNum
	AND(de.everOn=1 OR de.everOn=2);
		/*End migration for Est-ce que le patient recevait traitement ARV?*/
	    /*Start migration for Est-ce que le patient a arrêté définitif de prendre les médicaments ARV? */
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,160121,c.encounter_id,
	CASE WHEN (de.visitDateYy is null AND de.visitDateMm < 1 AND de.visitDateDd < 1) THEN NULL
	WHEN(de.visitDateMm < 1 AND de.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(de.visitDateYy,"-",01,"-",de.visitDateDd),"%Y-%m-%d")
	WHEN(de.visitDateMm > 0 AND de.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(de.visitDateYy,"-",de.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(de.visitDateYy,"-",de.visitDateMm,"-",de.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN de.ending=1 THEN 1065
	WHEN de.ending=2 THEN 1066
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.discEnrollment de
	WHERE c.uuid = e.encGuid and 
	e.patientID = de.patientID and e.siteCode = de.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(de.visitdateYy,'-',de.visitDateMm,'-',de.visitDateDd) 
	and e.seqNum = de.seqNum
	AND(de.ending=1 OR de.ending=2);
		/*End migration for Est-ce que le patient a arrêté définitif de prendre les médicaments ARV? */
		/*Start migration for Perte de contact avec le patient depuis plus de trois mois*/
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161555,c.encounter_id,
	CASE WHEN (de.visitDateYy is null AND de.visitDateMm < 1 AND de.visitDateDd < 1) THEN NULL
	WHEN(de.visitDateMm < 1 AND de.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(de.visitDateYy,"-",01,"-",de.visitDateDd),"%Y-%m-%d")
	WHEN(de.visitDateMm > 0 AND de.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(de.visitDateYy,"-",de.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(de.visitDateYy,"-",de.visitDateMm,"-",de.visitDateDd),"%Y-%m-%d")
	END,c.location_id,5240,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.discEnrollment de
	WHERE c.uuid = e.encGuid and 
	e.patientID = de.patientID and e.siteCode = de.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(de.visitdateYy,'-',de.visitDateMm,'-',de.visitDateDd) 
	and e.seqNum = de.seqNum
	AND(de.reasonDiscNoFollowup=1);
		/*End migration for Perte de contact avec le patient depuis plus de trois mois*/
		
		/*Start migration for Si arrêt dû à la perte de contact avec le patient, y a-t-il eu un minimum
		de 3 visites à domicile afin d'assurer la continuité des services?*/
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,164090,c.encounter_id,
	CASE WHEN (de.visitDateYy is null AND de.visitDateMm < 1 AND de.visitDateDd < 1) THEN NULL
	WHEN(de.visitDateMm < 1 AND de.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(de.visitDateYy,"-",01,"-",de.visitDateDd),"%Y-%m-%d")
	WHEN(de.visitDateMm > 0 AND de.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(de.visitDateYy,"-",de.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(de.visitDateYy,"-",de.visitDateMm,"-",de.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN de.min3homeVisits=1 THEN 1065
	WHEN de.min3homeVisits=2 THEN 1066
	WHEN de.min3homeVisits=4 THEN 1067
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.discEnrollment de
	WHERE c.uuid = e.encGuid and 
	e.patientID = de.patientID and e.siteCode = de.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(de.visitdateYy,'-',de.visitDateMm,'-',de.visitDateDd) 
	and e.seqNum = de.seqNum
	AND(de.min3homeVisits=1 OR de.min3homeVisits=2 OR de.min3homeVisits=4);
		/*End migration for Si arrêt dû à la perte de contact avec le patient, y a-t-il eu un minimum
		de 3 visites à domicile afin d'assurer la continuité des services?*/
		
		/*Start migration for Si non, expliquer*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_text,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,164091,c.encounter_id,
	CASE WHEN (de.visitDateYy is null AND de.visitDateMm < 1 AND de.visitDateDd < 1) THEN NULL
	WHEN(de.visitDateMm < 1 AND de.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(de.visitDateYy,"-",01,"-",de.visitDateDd),"%Y-%m-%d")
	WHEN(de.visitDateMm > 0 AND de.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(de.visitDateYy,"-",de.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(de.visitDateYy,"-",de.visitDateMm,"-",de.visitDateDd),"%Y-%m-%d")
	END,c.location_id,de.min3homeVisitsText,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.discEnrollment de
	WHERE c.uuid = e.encGuid and 
	e.patientID = de.patientID and e.siteCode = de.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(de.visitdateYy,'-',de.visitDateMm,'-',de.visitDateDd) 
	and e.seqNum = de.seqNum
	AND(de.min3homeVisitsText <> "" AND de.min3homeVisitsText is not null);
		/*End migration for Si non, expliquer*/
		/*Start migration for Transfert vers un autre établissement*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161555,c.encounter_id,
	CASE WHEN (de.visitDateYy is null AND de.visitDateMm < 1 AND de.visitDateDd < 1) THEN NULL
	WHEN(de.visitDateMm < 1 AND de.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(de.visitDateYy,"-",01,"-",de.visitDateDd),"%Y-%m-%d")
	WHEN(de.visitDateMm > 0 AND de.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(de.visitDateYy,"-",de.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(de.visitDateYy,"-",de.visitDateMm,"-",de.visitDateDd),"%Y-%m-%d")
	END,c.location_id,159492,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.discEnrollment de
	WHERE c.uuid = e.encGuid and 
	e.patientID = de.patientID and e.siteCode = de.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(de.visitdateYy,'-',de.visitDateMm,'-',de.visitDateDd) 
	and e.seqNum = de.seqNum
	AND(de.reasonDiscTransfer=1);
		/*End migration for Transfert vers un autre établissement*/
		/*Start migration for Préférence du patient et Référence du médecin*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,164089,c.encounter_id,
	CASE WHEN (de.visitDateYy is null AND de.visitDateMm < 1 AND de.visitDateDd < 1) THEN NULL
	WHEN(de.visitDateMm < 1 AND de.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(de.visitDateYy,"-",01,"-",de.visitDateDd),"%Y-%m-%d")
	WHEN(de.visitDateMm > 0 AND de.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(de.visitDateYy,"-",de.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(de.visitDateYy,"-",de.visitDateMm,"-",de.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN de.reasonDiscRef=1 THEN 162571
	WHEN de.reasonDiscRef=2 THEN 162591
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.discEnrollment de
	WHERE c.uuid = e.encGuid and 
	e.patientID = de.patientID and e.siteCode = de.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(de.visitdateYy,'-',de.visitDateMm,'-',de.visitDateDd) 
	and e.seqNum = de.seqNum
	AND(de.reasonDiscRef=1 OR de.reasonDiscRef=2);
		
		/*End migration for Préférence du patient et Référence du médecin*/
		/*Start migration for Nom de l'établissement*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_text,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,162724,c.encounter_id,
	CASE WHEN (de.visitDateYy is null AND de.visitDateMm < 1 AND de.visitDateDd < 1) THEN NULL
	WHEN(de.visitDateMm < 1 AND de.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(de.visitDateYy,"-",01,"-",de.visitDateDd),"%Y-%m-%d")
	WHEN(de.visitDateMm > 0 AND de.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(de.visitDateYy,"-",de.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(de.visitDateYy,"-",de.visitDateMm,"-",de.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cl.clinic,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.discEnrollment de, itech.clinicLookup cl
	WHERE c.uuid = e.encGuid and 
	e.patientID = de.patientID and e.siteCode = de.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(de.visitdateYy,'-',de.visitDateMm,'-',de.visitDateDd) 
	and e.seqNum = de.seqNum
	AND de.clinicName=cl.siteCode
	AND(de.clinicName <> "" AND de.clinicName is not null);
		/*End migration for Nom de l'établissement*/
		/*Start migration for Décès*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161555,c.encounter_id,
	CASE WHEN (de.visitDateYy is null AND de.visitDateMm < 1 AND de.visitDateDd < 1) THEN NULL
	WHEN(de.visitDateMm < 1 AND de.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(de.visitDateYy,"-",01,"-",de.visitDateDd),"%Y-%m-%d")
	WHEN(de.visitDateMm > 0 AND de.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(de.visitDateYy,"-",de.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(de.visitDateYy,"-",de.visitDateMm,"-",de.visitDateDd),"%Y-%m-%d")
	END,c.location_id,159,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.discEnrollment de
	WHERE c.uuid = e.encGuid and 
	e.patientID = de.patientID and e.siteCode = de.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(de.visitdateYy,'-',de.visitDateMm,'-',de.visitDateDd) 
	and e.seqNum = de.seqNum
	AND(de.reasonDiscDeath=1);
		/*End migration for Décès*/
		
		/*Start migration for Date (Décès)*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_datetime,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1543,c.encounter_id,
	CASE WHEN (de.visitDateYy is null AND de.visitDateMm < 1 AND de.visitDateDd < 1) THEN NULL
	WHEN(de.visitDateMm < 1 AND de.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(de.visitDateYy,"-",01,"-",de.visitDateDd),"%Y-%m-%d")
	WHEN(de.visitDateMm > 0 AND de.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(de.visitDateYy,"-",de.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(de.visitDateYy,"-",de.visitDateMm,"-",de.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (de.reasonDiscDeathYy is null AND de.reasonDiscDeathMm < 1 AND de.reasonDiscDeathDd < 1) THEN NULL
	WHEN(de.reasonDiscDeathMm < 1 AND de.reasonDiscDeathDd > 0) THEN 
		DATE_FORMAT(concat(de.reasonDiscDeathYy,"-",01,"-",de.reasonDiscDeathDd),"%Y-%m-%d")
	WHEN(de.reasonDiscDeathMm > 0 AND de.reasonDiscDeathDd < 1) THEN 
		DATE_FORMAT(concat(de.reasonDiscDeathYy,"-",de.reasonDiscDeathMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(de.reasonDiscDeathYy,"-",de.reasonDiscDeathMm,"-",de.reasonDiscDeathDd),"%Y-%m-%d")
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.discEnrollment de
	WHERE c.uuid = e.encGuid and 
	e.patientID = de.patientID and e.siteCode = de.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(de.visitdateYy,'-',de.visitDateMm,'-',de.visitDateDd) 
	and e.seqNum = de.seqNum
	AND(de.reasonDiscDeathYy <> "" AND de.reasonDiscDeathYy is not null);
		/*End migration for Date (Décès)*/
	/*Start migration for Effets secondaires, Infection opportuniste, Autre cause*/	
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1599,c.encounter_id,
	CASE WHEN (de.visitDateYy is null AND de.visitDateMm < 1 AND de.visitDateDd < 1) THEN NULL
	WHEN(de.visitDateMm < 1 AND de.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(de.visitDateYy,"-",01,"-",de.visitDateDd),"%Y-%m-%d")
	WHEN(de.visitDateMm > 0 AND de.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(de.visitDateYy,"-",de.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(de.visitDateYy,"-",de.visitDateMm,"-",de.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN de.sideEffects=1 THEN 156671
	WHEN de.opportunInf=1 THEN 131768
	WHEN de.discDeathOther=1 THEN 5622
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.discEnrollment de
	WHERE c.uuid = e.encGuid and 
	e.patientID = de.patientID and e.siteCode = de.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(de.visitdateYy,'-',de.visitDateMm,'-',de.visitDateDd) 
	and e.seqNum = de.seqNum
	AND(de.opportunInf=1 OR de.opportunInf=1 OR de.discDeathOther=1);
	/*Start migration for Effets secondaires, Infection opportuniste, Autre cause*/	
	/*Start migration for Préciser*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_text,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161602,c.encounter_id,
	CASE WHEN (de.visitDateYy is null AND de.visitDateMm < 1 AND de.visitDateDd < 1) THEN NULL
	WHEN(de.visitDateMm < 1 AND de.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(de.visitDateYy,"-",01,"-",de.visitDateDd),"%Y-%m-%d")
	WHEN(de.visitDateMm > 0 AND de.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(de.visitDateYy,"-",de.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(de.visitDateYy,"-",de.visitDateMm,"-",de.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (de.opportunInfText <> "" AND de.opportunInfText is not null) THEN de.opportunInfText
		 WHEN (de.sideEffectsText <> "" AND de.sideEffectsText is not null) THEN de.sideEffectsText
		 WHEN (de.discDeathOtherText <> "" AND de.discDeathOtherText is not null) THEN de.discDeathOtherText
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.discEnrollment de
	WHERE c.uuid = e.encGuid and 
	e.patientID = de.patientID and e.siteCode = de.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(de.visitdateYy,'-',de.visitDateMm,'-',de.visitDateDd) 
	and e.seqNum = de.seqNum
	AND(
		(de.opportunInfText <> "" AND de.opportunInfText is not null)
	     OR
		(de.sideEffectsText <> "" AND de.sideEffectsText is not null)
		OR
		(de.discDeathOtherText <> "" AND de.discDeathOtherText is not null)
	  );
	/*End migration for Préciser*/
	/*Start migration for Discontinuations, préciser et Raison d'arrêt inconnue*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161555,c.encounter_id,
	CASE WHEN (de.visitDateYy is null AND de.visitDateMm < 1 AND de.visitDateDd < 1) THEN NULL
	WHEN(de.visitDateMm < 1 AND de.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(de.visitDateYy,"-",01,"-",de.visitDateDd),"%Y-%m-%d")
	WHEN(de.visitDateMm > 0 AND de.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(de.visitDateYy,"-",de.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(de.visitDateYy,"-",de.visitDateMm,"-",de.visitDateDd),"%Y-%m-%d")
	END,c.location_id,1667,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.discEnrollment de
	WHERE c.uuid = e.encGuid and 
	e.patientID = de.patientID and e.siteCode = de.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(de.visitdateYy,'-',de.visitDateMm,'-',de.visitDateDd) 
	and e.seqNum = de.seqNum
	AND de.reasonDiscOther=1;
	/*End migration for Discontinuations, préciser*/
	/*Start migration for Raison d'arrêt inconnue*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161555,c.encounter_id,
	CASE WHEN (de.visitDateYy is null AND de.visitDateMm < 1 AND de.visitDateDd < 1) THEN NULL
	WHEN(de.visitDateMm < 1 AND de.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(de.visitDateYy,"-",01,"-",de.visitDateDd),"%Y-%m-%d")
	WHEN(de.visitDateMm > 0 AND de.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(de.visitDateYy,"-",de.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(de.visitDateYy,"-",de.visitDateMm,"-",de.visitDateDd),"%Y-%m-%d")
	END,c.location_id,1067,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.discEnrollment de
	WHERE c.uuid = e.encGuid and 
	e.patientID = de.patientID and e.siteCode = de.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(de.visitdateYy,'-',de.visitDateMm,'-',de.visitDateDd) 
	and e.seqNum = de.seqNum
	AND de.reasonUnknownClosing=1;
	/*End migration for Raison d'arrêt inconnue*/
	/*Start migration for Discontinuations (Types)*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1667,c.encounter_id,
	CASE WHEN (de.visitDateYy is null AND de.visitDateMm < 1 AND de.visitDateDd < 1) THEN NULL
	WHEN(de.visitDateMm < 1 AND de.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(de.visitDateYy,"-",01,"-",de.visitDateDd),"%Y-%m-%d")
	WHEN(de.visitDateMm > 0 AND de.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(de.visitDateYy,"-",de.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(de.visitDateYy,"-",de.visitDateMm,"-",de.visitDateDd),"%Y-%m-%d")
	END,c.location_id,1754,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.discEnrollment de
	WHERE c.uuid = e.encGuid and 
	e.patientID = de.patientID and e.siteCode = de.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(de.visitdateYy,'-',de.visitDateMm,'-',de.visitDateDd) 
	and e.seqNum = de.seqNum
	AND de.noARVs=1;
	/*Patient a déménagé*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1667,c.encounter_id,
	CASE WHEN (de.visitDateYy is null AND de.visitDateMm < 1 AND de.visitDateDd < 1) THEN NULL
	WHEN(de.visitDateMm < 1 AND de.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(de.visitDateYy,"-",01,"-",de.visitDateDd),"%Y-%m-%d")
	WHEN(de.visitDateMm > 0 AND de.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(de.visitDateYy,"-",de.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(de.visitDateYy,"-",de.visitDateMm,"-",de.visitDateDd),"%Y-%m-%d")
	END,c.location_id,160415,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.discEnrollment de
	WHERE c.uuid = e.encGuid and 
	e.patientID = de.patientID and e.siteCode = de.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(de.visitdateYy,'-',de.visitDateMm,'-',de.visitDateDd) 
	and e.seqNum = de.seqNum
	AND de.patientMoved=1;
	 /*Adhérence inadéquate*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1667,c.encounter_id,
	CASE WHEN (de.visitDateYy is null AND de.visitDateMm < 1 AND de.visitDateDd < 1) THEN NULL
	WHEN(de.visitDateMm < 1 AND de.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(de.visitDateYy,"-",01,"-",de.visitDateDd),"%Y-%m-%d")
	WHEN(de.visitDateMm > 0 AND de.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(de.visitDateYy,"-",de.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(de.visitDateYy,"-",de.visitDateMm,"-",de.visitDateDd),"%Y-%m-%d")
	END,c.location_id,115198,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.discEnrollment de
	WHERE c.uuid = e.encGuid and 
	e.patientID = de.patientID and e.siteCode = de.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(de.visitdateYy,'-',de.visitDateMm,'-',de.visitDateDd) 
	and e.seqNum = de.seqNum
	AND de.poorAdherence=1;
	/*Préférence du patient*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1667,c.encounter_id,
	CASE WHEN (de.visitDateYy is null AND de.visitDateMm < 1 AND de.visitDateDd < 1) THEN NULL
	WHEN(de.visitDateMm < 1 AND de.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(de.visitDateYy,"-",01,"-",de.visitDateDd),"%Y-%m-%d")
	WHEN(de.visitDateMm > 0 AND de.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(de.visitDateYy,"-",de.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(de.visitDateYy,"-",de.visitDateMm,"-",de.visitDateDd),"%Y-%m-%d")
	END,c.location_id,159737,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.discEnrollment de
	WHERE c.uuid = e.encGuid and 
	e.patientID = de.patientID and e.siteCode = de.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(de.visitdateYy,'-',de.visitDateMm,'-',de.visitDateDd) 
	and e.seqNum = de.seqNum
	AND de.patientPreference=1;
	/*End migration for Discontinuations (Types)*/
	/*Start migration for Discontinuations (Autre raison)*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1667,c.encounter_id,
	CASE WHEN (de.visitDateYy is null AND de.visitDateMm < 1 AND de.visitDateDd < 1) THEN NULL
	WHEN(de.visitDateMm < 1 AND de.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(de.visitDateYy,"-",01,"-",de.visitDateDd),"%Y-%m-%d")
	WHEN(de.visitDateMm > 0 AND de.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(de.visitDateYy,"-",de.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(de.visitDateYy,"-",de.visitDateMm,"-",de.visitDateDd),"%Y-%m-%d")
	END,c.location_id,5622,de.discReasonOtherText,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.discEnrollment de
	WHERE c.uuid = e.encGuid and 
	e.patientID = de.patientID and e.siteCode = de.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(de.visitdateYy,'-',de.visitDateMm,'-',de.visitDateDd) 
	and e.seqNum = de.seqNum
	AND de.discReasonOther=1;
	/*End migration for Discontinuations (Autre raison)*/
	
	/*Start migration for REMARQUES*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_text,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161011,c.encounter_id,
	CASE WHEN (de.visitDateYy is null AND de.visitDateMm < 1 AND de.visitDateDd < 1) THEN NULL
	WHEN(de.visitDateMm < 1 AND de.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(de.visitDateYy,"-",01,"-",de.visitDateDd),"%Y-%m-%d")
	WHEN(de.visitDateMm > 0 AND de.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(de.visitDateYy,"-",de.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(de.visitDateYy,"-",de.visitDateMm,"-",de.visitDateDd),"%Y-%m-%d")
	END,c.location_id,de.discRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.discEnrollment de
	WHERE c.uuid = e.encGuid and 
	e.patientID = de.patientID and e.siteCode = de.siteCode 
	and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(de.visitdateYy,'-',de.visitDateMm,'-',de.visitDateDd) 
	and e.seqNum = de.seqNum
	AND(de.discRemarks <> "" AND de.discRemarks is not null);
	/*End migration for REMARQUES*/
	
	/*End migration for discontinuation*/
	/*Add data migration for Imagerie et autre form*/
	
		 /*Delete all inserted Imagerie data if the script fail*/
		 SET SQL_SAFE_UPDATES = 0;
		 SET FOREIGN_KEY_CHECKS=0;
		 DELETE FROM obs WHERE encounter_id IN
		 (
			SELECT en.encounter_id FROM encounter en, encounter_type ent
			WHERE en.encounter_type=ent.encounter_type_id
			AND ent.uuid='a4cab59f-f0ce-46c3-bd76-416db36ec719'
		 );
		  SET SQL_SAFE_UPDATES = 1;
		  SET FOREIGN_KEY_CHECKS=1;
		  /*End of delete all inserted Imagerie data*/
		  
			/*Start migration for Radiographie pulmonaire:*/
			 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,12,c.encounter_id,
	CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
	WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
		DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
	WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
		DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (l.result = 1) THEN 1115
		WHEN (l.result = 2) THEN 1116
	END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitDateYy,'-',e.visitDateMm,'-',e.visitDateDd) =
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd)
	and e.seqNum = l.seqNum
	AND l.labID=137
	AND l.result3='chest'
	AND (l.result=1 OR l.result=2);
			/*End migration for Radiographie pulmonaire:*/
			
			/*Start migration for Radiographie (Autre):*/
		 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,309,c.encounter_id,
	CASE WHEN (l.resultDateYy is null AND l.resultDateMm < 1 AND l.resultDateDd < 1) THEN NULL
	WHEN(l.resultDateMm < 1 AND l.resultDateDd > 0) THEN 
		DATE_FORMAT(concat(l.resultDateYy,"-",01,"-",l.resultDateDd),"%Y-%m-%d")
	WHEN(l.resultDateMm > 0 AND l.resultDateDd < 1) THEN 
		DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(l.resultDateYy,"-",l.resultDateMm,"-",l.resultDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (l.result = 1) THEN 1115
		WHEN (l.result = 2) THEN 1116
	END,
	l.resultRemarks,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.labs l
	WHERE c.uuid = e.encGuid and 
	e.patientID = l.patientID and e.siteCode = l.siteCode 
	and concat(e.visitDateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
	concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd)
	and e.seqNum = l.seqNum
	AND l.labID=137
	AND l.result3='otherChest'
	AND (l.result=1 OR l.result=2);	
			/*End migration for Radiographie (Autre):*/
			
	/*End data migration for Imagerie et autre form*/
	
 END$$
	DELIMITER ;
	call discontinuationMigration();