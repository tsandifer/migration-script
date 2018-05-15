
DELIMITER $$
DROP PROCEDURE IF EXISTS sspAdultMigration$$
CREATE PROCEDURE sspAdultMigration()
BEGIN

SET SQL_SAFE_UPDATES = 0;
  /*Start migration for SSP data*/
  /*Start migration for Électrophorèse de l’hémoglobine :*/
  INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_text,
		creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,161421,c.encounter_id,
		CASE WHEN ((FindNumericValue(l.resultDateYy)<1 OR FindNumericValue(l.resultDateYy) is null)
			AND (FindNumericValue(l.visitDateMm) < 1 OR FindNumericValue(l.visitDateMm) is null)
			AND (FindNumericValue(l.visitDateDd) < 1) OR FindNumericValue(l.visitDateDd) is null) 
			THEN e.createDate
	WHEN((FindNumericValue(l.resultDateYy)>0 AND FindNumericValue(l.resultDateYy) is not null) 
		AND (FindNumericValue(l.visitDateMm) < 1 OR FindNumericValue(l.visitDateMm) is null)
		AND (FindNumericValue(l.visitDateDd) > 0 AND FindNumericValue(l.visitDateDd) is not null)) 
		THEN DATE_FORMAT(concat(FindNumericValue(l.resultDateYy),"-",01,"-",FindNumericValue(l.visitDateDd)),"%Y-%m-%d")
	WHEN((FindNumericValue(l.visitDateYy)>0 AND FindNumericValue(l.visitDateYy) is not null)
	    AND (FindNumericValue(l.visitDateMm) > 0 AND FindNumericValue(l.visitDateMm) is not null)
		AND (FindNumericValue(l.visitDateDd) < 1) OR FindNumericValue(l.visitDateDd) is null) 
	THEN DATE_FORMAT(concat(FindNumericValue(l.visitDateYy),"-",FindNumericValue(l.visitDateMm),"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(FindNumericValue(l.visitDateYy),"-",FindNumericValue(l.visitDateMm),"-",FindNumericValue(l.visitDateDd)),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN (l.result=1) THEN 'AS'
		WHEN (l.result=2) THEN 'SS'
		WHEN (l.result=4) THEN 'AC'
		WHEN (l.result=8) THEN 'SC'
		WHEN (l.result=16) THEN 'AA'
	END,1,e.createDate, UUID()
		from encounter c, itech.encounter e, itech.labs l 
		WHERE c.uuid = e.encGuid and 
		e.patientID = l.patientID and e.siteCode = l.siteCode 
		and concat(e.visitdateYy,'-',e.visitDateMm,'-',e.visitDateDd) = 
		concat(l.visitdateYy,'-',l.visitDateMm,'-',l.visitDateDd) 
		and e.seqNum = l.seqNum
		AND l.labID=150
		AND l.result IN(1,2,4,8,16);
		/*Autre Precisez*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_text,comments,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,161421,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,'Autre',ito.value_text,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid 
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=71120
	AND (ito.value_text is not null AND ito.value_text<>'');
  /*End migration for Électrophorèse de l’hémoglobine :*/
  /*Migration for Dépistage CA du Col*/ 
  /*Create table obs_concept_group for the obs_group_id*/
	create table if not exists itech.obs_concept_group (obs_id int,person_id int,concept_id int,encounter_id int);
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,160714,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70073,70075)
	AND (ito.value_boolean=1 OR ito.value_datetime is not null);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=160714 
	GROUP BY openmrs.obs.person_id,encounter_id;
	
	/*Concept*/
  INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1651,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,151185,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid 
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id=70073
	AND ito.value_boolean=1;
	/*Date*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,160715,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,DATE(ito.value_datetime),1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid 
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id=70075
	AND ito.value_datetime is not null;
  /*End migration for Dépistage CA du Col*/
  /*Start migration for Dépistage CA de la Prostate (Homme > 40ans)*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,160714,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70074,70076)
	AND (ito.value_boolean=1 OR ito.value_datetime is not null);
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=160714 
	GROUP BY openmrs.obs.person_id,encounter_id;
  
  /*Concept*/
  INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1651,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,163464,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid 
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id=70074
	AND ito.value_boolean=1;
	/*Date*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_datetime,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,160715,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,DATE(ito.value_datetime),1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid 
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id=70076
	AND ito.value_datetime is not null;
  /*End migration for Start migration for Dépistage CA de la Prostate (Homme > 40ans)*/
  
  /*Start migration for Résultats:*/
  INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,160714,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=70432
	AND (ito.value_text is not null AND ito.value_text<>'');
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=160714 
	GROUP BY openmrs.obs.person_id,encounter_id;
	
  INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_text,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,160716,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,ito.value_text,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid 
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id=70432
	AND ito.value_text is not null
	AND ito.value_text<>'';
  /*End migration for Résultats*/
 /*Start migration for ANTECEDENTS PERSONNELS/HABITUDES*/
	/*Start migration for Grossesse*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1633,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=70010
	AND ito.value_boolean=1;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=1633 
	GROUP BY openmrs.obs.person_id,encounter_id;
	/*Concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1628,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,1434,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id=70010
	AND ito.value_boolean=1;
	/*End migration for Grossesse*/
	
 /*End migration for ANTECEDENTS PERSONNELS/HABITUDES*/
 /*Migration for MOTIFS DE CONSULTATION*/
	/*Start migration for Adénopathie*/
		  INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159614,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,135488,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid 
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=71274
	AND ito.value_boolean=1;
	/*End migration for Adénopathie*/
	/*Start migration for Douleur, précisez:*/
	/*Create a table for précisez 
	because the concept and the précisez comment have different concept_id*/
	/*start table */
	create table if not exists itech.precisez 
	(obs_id int,person_id int,concept_id int,encounter_id int,
	location_id int, obs_group_id int, value_coded int);
	/*end table*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159614,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,151,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=70458
	AND ito.value_boolean=1;
	/*Update for précisez*/
	TRUNCATE TABLE itech.precisez;
	INSERT INTO itech.precisez(obs_id,person_id,concept_id,encounter_id,location_id, value_coded)
	SELECT MAX(o.obs_id) as obs_id,o.person_id,
	o.concept_id,o.encounter_id, o.location_id, o.value_coded
	FROM openmrs.obs o
	WHERE o.concept_id=159614
    AND o.value_coded=151	
	GROUP BY o.person_id, o.encounter_id;
	
	UPDATE openmrs.obs ob, itech.obs ito, encounter c, itech.encounter e, itech.precisez ip
		   SET ob.comments=ito.value_text
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=70617
	AND (ito.value_text <> '' AND ito.value_text is not null)
	AND ip.person_id=ob.person_id
	AND ip.concept_id=ob.concept_id
	AND ip.encounter_id=ob.encounter_id
	AND ip.location_id=ob.location_id
	AND ip.value_coded=ob.value_coded
	AND ip.concept_id=159614
	AND ip.value_coded=151; 
	/*End migration for Douleur, précisez:*/
	/*Start migration for Agression Auto-infligée*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159614,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,128808,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=70175
	AND ito.value_boolean=1;
	/*End migration for Agression Auto-infligée*/
	/*Start migration for Accident Voie Publique*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159614,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,119964,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=70177
	AND ito.value_boolean=1;
	/*End migration Accident Voie Publique*/
	/*Start migration for Brûlures, précisez:*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159614,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,146623,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=70178
	AND ito.value_boolean=1;
	
	/*Update for précisez*/
	TRUNCATE TABLE itech.precisez;
	INSERT INTO itech.precisez(obs_id,person_id,concept_id,encounter_id,location_id, value_coded)
	SELECT MAX(o.obs_id) as obs_id,o.person_id,
	o.concept_id,o.encounter_id, o.location_id, o.value_coded
	FROM openmrs.obs o
	WHERE o.concept_id=159614
    AND o.value_coded=146623	
	GROUP BY o.person_id,o.encounter_id;
	
	UPDATE openmrs.obs ob, itech.obs ito, encounter c, itech.encounter e, itech.precisez ip
		   SET ob.comments=ito.value_text
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=70179
	AND (ito.value_text <> '' AND ito.value_text is not null)
	AND ip.person_id=ob.person_id
	AND ip.concept_id=ob.concept_id
	AND ip.encounter_id=ob.encounter_id
	AND ip.location_id=ob.location_id
	AND ip.value_coded=ob.value_coded
	AND ip.concept_id=159614
	AND ip.value_coded=146623; 
	/*End migration for Brûlures, précisez:*/
	
	/*Start migration for Fracture osseuse*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159614,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,177,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=70180
	AND ito.value_boolean=1;
	/*End migration for Fracture osseuse*/
	/*Start migration for Plaie, précisez:*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159614,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,159328,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70182,70183,70181)
	AND ito.value_boolean=1;
	/*End migration for Plaie, précisez:*/
	/*Start migration for Arme à feu*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159614,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,117746,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=70182
	AND ito.value_boolean=1;
	/*End migration for Arme à feu*/
	/*Start migration for Arme blanche*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159614,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,158843,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=70183
	AND ito.value_boolean=1;
	/*End migration for Arme blanche*/
	/*Start migration for Autres:*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	comments,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159614,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,114767,ito.value_text,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=70181
	AND (ito.value_text<>'' AND ito.value_text is not null);
	/*End migration for Autres:*/
	/*Start migration for Trauma crânien*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159614,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,116838,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=71020
	AND ito.value_boolean=1;
	/*End migration for Trauma crânien*/
	/*Start migration for Epistaxis*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159614,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,133499,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=70186
	AND ito.value_boolean=1;
	/*End migration for Epistaxis*/
	/*Start migration for Œil rouge*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159614,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,130184,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=70187
	AND ito.value_boolean=1;
	/*End migration for Œil rouge*/
	/*Start migration for Otalgie*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159614,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,131602,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=70604
	AND ito.value_boolean=1;
	/*End migration for Otalgie*/
	/*Start migration for Otorrhée*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159614,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,151702,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=70605
	AND ito.value_boolean=1;
	/*End migration for Otorrhée*/
	/*Start migration for Brûlures mictionnelles*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159614,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,163606,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=70188
	AND ito.value_boolean=1;
	/*End migration for Brûlures mictionnelles*/
	/*Start migration for Ecoulement uréthral*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159614,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,123529,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=70189
	AND ito.value_boolean=1;
	/*End migration for Ecoulement uréthral*/
	/*Start migration for Hématurie*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159614,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,840,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=70606
	AND ito.value_boolean=1;
	/*End migration for Hématurie*/
	/*Start migration for Hémorragie vaginale*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159614,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,147232,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=70190
	AND ito.value_boolean=1;
	/*End migration for Hémorragie vaginale*/
	/*Start migration for Pertes vaginales*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159614,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,123396,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=70192
	AND ito.value_boolean=1;
	/*End migration for Pertes vaginales*/
	/*Start migration for Polyurie*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159614,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,129510,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=70607
	AND ito.value_boolean=1;
	/*End migration for Polyurie*/
	/*Start migration for Ulcération(s)*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159614,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,145762,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=70195
	AND ito.value_boolean=1;
	/*End migration for Ulcération(s)*/
	/*Start migration for Retard des Règles*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159614,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,134340,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=70196
	AND ito.value_boolean=1;
	/*End migration for Retard des Règles*/
	/*Start migration for Troubles mentaux, précisez:*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159614,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,134337,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=70197
	AND ito.value_boolean=1;
	
	/*Update for précisez*/
	TRUNCATE TABLE itech.precisez;
	INSERT INTO itech.precisez(obs_id,person_id,concept_id,encounter_id,location_id, value_coded)
	SELECT MAX(o.obs_id) as obs_id,o.person_id,
	o.concept_id,o.encounter_id, o.location_id, o.value_coded
	FROM openmrs.obs o
	WHERE o.concept_id=159614
    AND o.value_coded=134337	
	GROUP BY o.person_id,o.encounter_id;
	
	UPDATE openmrs.obs ob, itech.obs ito, encounter c, itech.encounter e, itech.precisez ip
		   SET ob.comments=ito.value_text
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=70230
	AND (ito.value_text <> '' AND ito.value_text is not null)
	AND ip.person_id=ob.person_id
	AND ip.concept_id=ob.concept_id
	AND ip.encounter_id=ob.encounter_id
	AND ip.location_id=ob.location_id
	AND ip.value_coded=ob.value_coded
	AND ip.concept_id=159614
	AND ip.value_coded=134337; 
	/*End migration for Troubles mentaux, précisez:*/
	
	/*Start migration for Aphasie*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159614,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,121529,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=70198
	AND ito.value_boolean=1;
	/*End migration for Aphasie*/
	/*Start migration for Boiterie/Steppage*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159614,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,122936,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=70199
	AND ito.value_boolean=1;
	/*End migration for Boiterie/Steppage*/
	/*Start migration for Céphalée/Maux de tète*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159614,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,139084,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=70601
	AND ito.value_boolean=1;
	/*End migration for Céphalée/Maux de tète*/
	/*Start migration for Hémiplégie*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159614,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,117655,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=70200
	AND ito.value_boolean=1;
	/*End migration for Hémiplégie*/
	/*Start migration for Paralysie flasque*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159614,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,160426,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=70201
	AND ito.value_boolean=1;
	/*End migration for Paralysie flasque*/
	/*Start migration for Paraplégie*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159614,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,130843,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=70202
	AND ito.value_boolean=1;
	/*End migration for Paraplégie*/
	/*Start migration for Syncope*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159614,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,125166,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=70608
	AND ito.value_boolean=1;
	/*End migration for Syncope*/
	/*Start migration for Vertiges*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159614,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,111525,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=70203
	AND ito.value_boolean=1;
	/*End migration for Vertiges*/
	/*Start migration for Palpitations*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159614,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,130987,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=70205
	AND ito.value_boolean=1;
	/*End migration for Palpitations*/
	/*Start migration for Eruptions cutanées, précisez:*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159614,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,512,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=70209
	AND ito.value_boolean=1;
	
	/*Update for précisez*/
	TRUNCATE TABLE itech.precisez;
	INSERT INTO itech.precisez(obs_id,person_id,concept_id,encounter_id,location_id, value_coded)
	SELECT MAX(o.obs_id) as obs_id,o.person_id,
	o.concept_id,o.encounter_id, o.location_id, o.value_coded
	FROM openmrs.obs o
	WHERE o.concept_id=159614
    AND o.value_coded=512	
	GROUP BY o.person_id,o.encounter_id;
	
	UPDATE openmrs.obs ob, itech.obs ito, encounter c, itech.encounter e, itech.precisez ip
		   SET ob.comments=ito.value_text
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=70210
	AND (ito.value_text <> '' AND ito.value_text is not null)
	AND ip.person_id=ob.person_id
	AND ip.concept_id=ob.concept_id
	AND ip.encounter_id=ob.encounter_id
	AND ip.location_id=ob.location_id
	AND ip.value_coded=ob.value_coded
	AND ip.concept_id=159614
	AND ip.value_coded=512;
	/*End migration for Eruptions cutanées, précisez:*/
	/*Start migration for Prurit*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159614,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,128310,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=70208
	AND ito.value_boolean=1;
	/*End migration for Prurit*/
	/*Start migration for Constipation*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159614,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,996,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=70611
	AND ito.value_boolean=1;
	/*End migration for Constipation*/
	/*Start migration for Diarrhée < 2 semaines*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159614,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,163465,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=70211
	AND ito.value_boolean=1;
	/*End migration for Diarrhée < 2 semaines*/
	/*Start migration for Diarrhée ≥ 2 semaines*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159614,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,5018,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=70212
	AND ito.value_boolean=1;
	/*End migration for Diarrhée ≥ 2 semaines*/
	
	/*Start migration for Dysphagie*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159614,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,118789,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=70612
	AND ito.value_boolean=1;
	/*End migration for Dysphagie*/
	/*Start migration for Hématémèse*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159614,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,139006,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=70613
	AND ito.value_boolean=1;
	/*End migration for Hématémèse*/
	/*Start migration for Ictère/jaunisse*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159614,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,136443,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=70213
	AND ito.value_boolean=1;
	/*End migration for Ictère/jaunisse*/
	/*Start migration for Inappétence / anorexie*/
	 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159614,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,6031,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=70214
	AND ito.value_boolean=1;
	/*End migration for Inappétence / anorexie*/
	/*Start migration for Méléna*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159614,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,134394,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=70614
	AND ito.value_boolean=1;
	/*End migration for Méléna*/
	/*Start migration for Nausée*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159614,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,5978,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=7013
	AND ito.value_boolean=1;
	/*End migration for Nausée*/
	/*Start migration for Pyrosis*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159614,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,139059,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=70616
	AND ito.value_boolean=1;
	/*End migration for Pyrosis*/
	/*Start migration for Vomissements*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159614,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,122983,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id=70215
	AND ito.value_boolean=1;
	/*End migration for Vomissements*/
 /*End migration for MOTIFS DE CONSULTATION*/
 /*Start migration for IMPRESSIONS CLINIQUES/DIAGNOSTIQUES*/
	/*Start migration for Accident cérébro-vasculaire [I63.50]*/
	/*Insert obs_group_id*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159947,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70231,70232,70233)
	AND ito.value_boolean=1;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=159947 
	GROUP BY openmrs.obs.person_id,encounter_id;
	/*Concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,111103,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70231,70232,70233)
	AND ito.value_boolean=1;
	/*Confirmé,Suspecté*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159394,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159392,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70231,70232,70233)
	AND ito.value_boolean=1;
	/*Primaire,Secondaire*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159946,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159943,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70231,70232,70233)
	AND ito.value_boolean=1;
	/*End migration for Accident cérébro-vasculaire [I63.50]*/
	/*Start migration for Anémie, précisez :*/
	/*Insert obs_group_id*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159947,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70234,70235,70236)
	AND ito.value_boolean=1;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=159947 
	GROUP BY openmrs.obs.person_id,encounter_id;
	/*Concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,121629,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70234,70235,70236)
	AND ito.value_boolean=1;
	/*Confirmé,Suspecté*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159394,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159392,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70234,70235,70236)
	AND ito.value_boolean=1;
	/*Primaire,Secondaire*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159946,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159943,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id IN(70234,70235,70236)
	AND ito.value_boolean = 1;
	
	TRUNCATE TABLE itech.precisez;
	INSERT INTO itech.precisez(obs_id,person_id,concept_id,encounter_id,location_id, obs_group_id,value_coded)
	SELECT MAX(o.obs_id) as obs_id,o.person_id,
	o.concept_id,o.encounter_id, o.location_id, o.obs_group_id, o.value_coded 
	FROM openmrs.obs og, openmrs.obs o
	WHERE og.obs_id = o.obs_group_id
	AND o.concept_id = 1284
    AND o.value_coded = 121629
	AND og.concept_id = 159947
	GROUP BY o.person_id,o.encounter_id;
	
	UPDATE openmrs.obs ob, itech.obs ito, encounter c, itech.encounter e, itech.precisez ip
		   SET ob.comments = ito.value_text
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id = 70237
	AND (ito.value_text <> '' AND ito.value_text is not null)
	AND ip.person_id = ob.person_id
	AND ip.concept_id = ob.concept_id
	AND ip.encounter_id = ob.encounter_id
	AND ip.location_id = ob.location_id
	AND ip.obs_group_id = ob.obs_group_id
	AND ip.value_coded = ob.value_coded
	AND ip.concept_id = 1284
	AND ip.value_coded = 121629; 
	
	
	/*End migration for Anémie, précisez :*/
	/*Start migration for Asthme [J45]*/
	/*Insert obs_group_id*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159947,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70842,70843,70844)
	AND ito.value_boolean=1;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(o.obs_id) as obs_id,o.person_id,o.concept_id,o.encounter_id
	FROM openmrs.obs o
	WHERE o.concept_id=159947 
	GROUP BY o.person_id,o.encounter_id;
	/*Concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,121375,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70842,70843,70844)
	AND ito.value_boolean=1;
	/*Confirmé,Suspecté*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159394,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159392,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70842,70843,70844)
	AND ito.value_boolean=1;
	/*Primaire,Secondaire*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159946,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159943,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id IN(70842,70843,70844)
	AND ito.value_boolean = 1;
	/*End migration for Asthme [J45]*/
	/*Start migration for Diabète Type 1 [E10.9]*/
	/*Insert obs_group_id*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159947,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70249,70250,70251)
	AND ito.value_boolean=1;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(o.obs_id) as obs_id,o.person_id,o.concept_id,o.encounter_id
	FROM openmrs.obs o
	WHERE o.concept_id=159947 
	GROUP BY o.person_id,o.encounter_id;
	/*Concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,142474,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70249,70250,70251)
	AND ito.value_boolean=1;
	/*Confirmé,Suspecté*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159394,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159392,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70249,70250,70251)
	AND ito.value_boolean=1;
	/*Primaire,Secondaire*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159946,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159943,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id IN(70249,70250,70251)
	AND ito.value_boolean = 1;
	/*End migration for Diabète Type 1 [E10.9]*/
	/*Start migration for Diabète Type 2 [E11.9]*/
	/*Insert obs_group_id*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159947,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70252,70253,70254)
	AND ito.value_boolean=1;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(o.obs_id) as obs_id,o.person_id,o.concept_id,o.encounter_id
	FROM openmrs.obs o
	WHERE o.concept_id=159947 
	GROUP BY o.person_id,o.encounter_id;
	/*Concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,142473,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70252,70253,70254)
	AND ito.value_boolean=1;
	/*Confirmé,Suspecté*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159394,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159392,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70252,70253,70254)
	AND ito.value_boolean=1;
	/*Primaire,Secondaire*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159946,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159943,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id IN(70252,70253,70254)
	AND ito.value_boolean = 1;
	/*End migration for Diabète Type 2 [E11.9]*/
	
	/*Start migration for Diarrhée aigue aqueuse [R19.7]*/
	/*Insert obs_group_id*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159947,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70258,70259,70260)
	AND ito.value_boolean=1;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(o.obs_id) as obs_id,o.person_id,o.concept_id,o.encounter_id
	FROM openmrs.obs o
	WHERE o.concept_id=159947 
	GROUP BY o.person_id,o.encounter_id;
	/*Concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,161887,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70258,70259,70260)
	AND ito.value_boolean=1;
	/*Confirmé,Suspecté*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159394,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159392,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70258,70259,70260)
	AND ito.value_boolean=1;
	/*Primaire,Secondaire*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159946,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159943,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id IN(70258,70259,70260)
	AND ito.value_boolean = 1;
	/*End migration for Diarrhée aigue aqueuse [R19.7]**/
	/*Start migration for Diarrhée aigue sanguinolente [R19.7]**/
	/*Insert obs_group_id*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159947,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70261,70262,70263)
	AND ito.value_boolean=1;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(o.obs_id) as obs_id,o.person_id,o.concept_id,o.encounter_id
	FROM openmrs.obs o
	WHERE o.concept_id=159947 
	GROUP BY o.person_id,o.encounter_id;
	/*Concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,138868,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70261,70262,70263)
	AND ito.value_boolean=1;
	/*Confirmé,Suspecté*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159394,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159392,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70261,70262,70263)
	AND ito.value_boolean=1;
	/*Primaire,Secondaire*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159946,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159943,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id IN(70261,70262,70263)
	AND ito.value_boolean = 1;
	/*End migration for Diarrhée aigue sanguinolente [R19.7]**/
	/*Start migration for Drépanocytose : SS/SC [D57.1]*/
	/*Insert obs_group_id*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159947,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70875,70876,70877)
	AND ito.value_boolean=1;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(o.obs_id) as obs_id,o.person_id,o.concept_id,o.encounter_id
	FROM openmrs.obs o
	WHERE o.concept_id=159947 
	GROUP BY o.person_id,o.encounter_id;
	/*Concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,126513,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70875,70876,70877)
	AND ito.value_boolean=1;
	/*Confirmé,Suspecté*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159394,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159392,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70875,70876,70877)
	AND ito.value_boolean=1;
	/*Primaire,Secondaire*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159946,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159943,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id IN(70875,70876,70877)
	AND ito.value_boolean = 1;
	/*End migration for Drépanocytose : SS/SC [D57.1]*/
	/*Start migration for Epilepsie [G40.901]*/
	/*Insert obs_group_id*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159947,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70243,70244,70245)
	AND ito.value_boolean=1;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(o.obs_id) as obs_id,o.person_id,o.concept_id,o.encounter_id
	FROM openmrs.obs o
	WHERE o.concept_id=159947 
	GROUP BY o.person_id,o.encounter_id;
	/*Concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,155,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70243,70244,70245)
	AND ito.value_boolean=1;
	/*Confirmé,Suspecté*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159394,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159392,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70243,70244,70245)
	AND ito.value_boolean=1;
	/*Primaire,Secondaire*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159946,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159943,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id IN(70243,70244,70245)
	AND ito.value_boolean = 1;
	/*End migration for Epilepsie [G40.901]*/
	/*Start migration for Fièvre, cause indéterminée [R50.9]**/
	/*Insert obs_group_id*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159947,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70246,70247,70248)
	AND ito.value_boolean=1;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(o.obs_id) as obs_id,o.person_id,o.concept_id,o.encounter_id
	FROM openmrs.obs o
	WHERE o.concept_id=159947 
	GROUP BY o.person_id,o.encounter_id;
	/*Concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,127990,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70246,70247,70248)
	AND ito.value_boolean=1;
	/*Confirmé,Suspecté*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159394,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159392,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70246,70247,70248)
	AND ito.value_boolean=1;
	/*Primaire,Secondaire*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159946,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159943,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id IN(70246,70247,70248)
	AND ito.value_boolean = 1;
	/*End migration for Fièvre, cause indéterminée [R50.9]*/
	/*Start migration for Grossesse [Z33.1]*/
	/*Insert obs_group_id*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159947,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70264,70265,70266)
	AND ito.value_boolean=1;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(o.obs_id) as obs_id,o.person_id,o.concept_id,o.encounter_id
	FROM openmrs.obs o
	WHERE o.concept_id=159947 
	GROUP BY o.person_id,o.encounter_id;
	/*Concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,1434,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70264,70265,70266)
	AND ito.value_boolean=1;
	/*Confirmé,Suspecté*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159394,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159392,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70264,70265,70266)
	AND ito.value_boolean=1;
	/*Primaire,Secondaire*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159946,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159943,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id IN(70264,70265,70266)
	AND ito.value_boolean = 1;
	/*END migration for Grossesse [Z33.1] */
	/*Start migration for Hypertension artérielle [I10]*/
	/*Insert obs_group_id*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159947,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70267,70268,70269)
	AND ito.value_boolean=1;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(o.obs_id) as obs_id,o.person_id,o.concept_id,o.encounter_id
	FROM openmrs.obs o
	WHERE o.concept_id=159947 
	GROUP BY o.person_id,o.encounter_id;
	/*Concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,117399,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70267,70268,70269)
	AND ito.value_boolean=1;
	/*Confirmé,Suspecté*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159394,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159392,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70267,70268,70269)
	AND ito.value_boolean=1;
	/*Primaire,Secondaire*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159946,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159943,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id IN(70267,70268,70269)
	AND ito.value_boolean = 1;
	/*End migration for Hypertension artérielle [I10]*/
	/*Start migration for Malnutrition/Perte de poids [E46]*/
	/*Insert obs_group_id*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159947,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70878,70879,70880)
	AND ito.value_boolean=1;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(o.obs_id) as obs_id,o.person_id,o.concept_id,o.encounter_id
	FROM openmrs.obs o
	WHERE o.concept_id=159947 
	GROUP BY o.person_id,o.encounter_id;
	/*Concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,832,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70878,70879,70880)
	AND ito.value_boolean=1;
	/*Confirmé,Suspecté*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159394,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159392,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70878,70879,70880)
	AND ito.value_boolean=1;
	/*Primaire,Secondaire*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159946,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159943,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id IN(70878,70879,70880)
	AND ito.value_boolean = 1;
	/*End migration for Malnutrition/Perte de poids [E46]*/
	/*Start migration for Urgence Chirurgicale*/
	/*Insert obs_group_id*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159947,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70273,70274,70275)
	AND ito.value_boolean=1;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(o.obs_id) as obs_id,o.person_id,o.concept_id,o.encounter_id
	FROM openmrs.obs o
	WHERE o.concept_id=159947 
	GROUP BY o.person_id,o.encounter_id;
	/*Concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159619,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70273,70274,70275)
	AND ito.value_boolean=1;
	/*Confirmé,Suspecté*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159394,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159392,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70273,70274,70275)
	AND ito.value_boolean=1;
	/*Primaire,Secondaire*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159946,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159943,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id IN(70273,70274,70275)
	AND ito.value_boolean = 1;
	/*End migration for Urgence Chirurgicale*/
	/*Start migration for Amygdalite [J03.90]*/
	/*Insert obs_group_id*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159947,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70276,70277,70278)
	AND ito.value_boolean=1;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(o.obs_id) as obs_id,o.person_id,o.concept_id,o.encounter_id
	FROM openmrs.obs o
	WHERE o.concept_id=159947 
	GROUP BY o.person_id,o.encounter_id;
	/*Concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,112,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70276,70277,70278)
	AND ito.value_boolean=1;
	/*Confirmé,Suspecté*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159394,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159392,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70276,70277,70278)
	AND ito.value_boolean=1;
	/*Primaire,Secondaire*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159946,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159943,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id IN(70276,70277,70278)
	AND ito.value_boolean = 1;
	/*End migration for Amygdalite [J03.90]*/
	/*Start migration for Charbon [A22.9]*, précisez :*/
	
	/*Insert obs_group_id*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159947,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70279,70280,70281)
	AND ito.value_boolean=1;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=159947 
	GROUP BY openmrs.obs.person_id,encounter_id;
	/*Concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,121555,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70279,70280,70281)
	AND ito.value_boolean=1;
	/*Confirmé,Suspecté*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159394,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159392,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70279,70280,70281)
	AND ito.value_boolean=1;
	/*Primaire,Secondaire*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159946,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159943,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id IN(70279,70280,70281)
	AND ito.value_boolean = 1;
	
	TRUNCATE TABLE itech.precisez;
	INSERT INTO itech.precisez(obs_id,person_id,concept_id,encounter_id,location_id, obs_group_id,value_coded)
	SELECT MAX(o.obs_id) as obs_id,o.person_id,
	o.concept_id,o.encounter_id, o.location_id, o.obs_group_id, o.value_coded 
	FROM openmrs.obs og, openmrs.obs o
	WHERE og.obs_id = o.obs_group_id
	AND o.concept_id = 1284
    AND o.value_coded = 121555
	AND og.concept_id = 159947
	GROUP BY o.person_id,o.encounter_id;
	
	UPDATE openmrs.obs ob, itech.obs ito, encounter c, itech.encounter e, itech.precisez ip
		   SET ob.comments = ito.value_text
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id = 70881
	AND (ito.value_text <> '' AND ito.value_text is not null)
	AND ip.person_id = ob.person_id
	AND ip.concept_id = ob.concept_id
	AND ip.encounter_id = ob.encounter_id
	AND ip.location_id = ob.location_id
	AND ip.obs_group_id = ob.obs_group_id
	AND ip.value_coded = ob.value_coded
	AND ip.concept_id = 1284
	AND ip.value_coded = 121555;
	
	/*End migration for Charbon [A22.9]*, précisez :*/
	/*Start migration for Choléra [A00.9]**/
	/*Insert obs_group_id*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159947,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70282,70283,70284)
	AND ito.value_boolean=1;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(o.obs_id) as obs_id,o.person_id,o.concept_id,o.encounter_id
	FROM openmrs.obs o
	WHERE o.concept_id=159947 
	GROUP BY o.person_id,o.encounter_id;
	/*Concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,122604,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70282,70283,70284)
	AND ito.value_boolean=1;
	/*Confirmé,Suspecté*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159394,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159392,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70282,70283,70284)
	AND ito.value_boolean=1;
	/*Primaire,Secondaire*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159946,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159943,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id IN(70282,70283,70284)
	AND ito.value_boolean = 1;
	/*End migration for Choléra [A00.9]**/
	
	
	/*Start migration for Conjonctivite [H10.9], précisez :*/
	/*Insert obs_group_id*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159947,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70285,70286,70287)
	AND ito.value_boolean=1;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=159947 
	GROUP BY openmrs.obs.person_id,encounter_id;
	/*Concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,119905,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70285,70286,70287)
	AND ito.value_boolean=1;
	/*Confirmé,Suspecté*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159394,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159392,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70285,70286,70287)
	AND ito.value_boolean=1;
	/*Primaire,Secondaire*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159946,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159943,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id IN(70285,70286,70287)
	AND ito.value_boolean = 1;
	
	TRUNCATE TABLE itech.precisez;
	INSERT INTO itech.precisez(obs_id,person_id,concept_id,encounter_id,location_id, obs_group_id,value_coded)
	SELECT MAX(o.obs_id) as obs_id,o.person_id,
	o.concept_id,o.encounter_id, o.location_id, o.obs_group_id, o.value_coded 
	FROM openmrs.obs og, openmrs.obs o
	WHERE og.obs_id = o.obs_group_id
	AND o.concept_id = 1284
    AND o.value_coded = 119905
	AND og.concept_id = 159947
	GROUP BY o.person_id,o.encounter_id;
	
	UPDATE openmrs.obs ob, itech.obs ito, encounter c, itech.encounter e, itech.precisez ip
		   SET ob.comments = ito.value_text
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id = 70288
	AND (ito.value_text <> '' AND ito.value_text is not null)
	AND ip.person_id = ob.person_id
	AND ip.concept_id = ob.concept_id
	AND ip.encounter_id = ob.encounter_id
	AND ip.location_id = ob.location_id
	AND ip.obs_group_id = ob.obs_group_id
	AND ip.value_coded = ob.value_coded
	AND ip.concept_id = 1284
	AND ip.value_coded = 119905;
	
	/*End migration for Conjonctivite [H10.9], précisez :*/
	/*Start migration for Coqueluche [A37.90]*/
	/*Insert obs_group_id*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159947,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70289,70290,70291)
	AND ito.value_boolean=1;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(o.obs_id) as obs_id,o.person_id,o.concept_id,o.encounter_id
	FROM openmrs.obs o
	WHERE o.concept_id=159947 
	GROUP BY o.person_id,o.encounter_id;
	/*Concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,114190,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70289,70290,70291)
	AND ito.value_boolean=1;
	/*Confirmé,Suspecté*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159394,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159392,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70289,70290,70291)
	AND ito.value_boolean=1;
	/*Primaire,Secondaire*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159946,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159943,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id IN(70289,70290,70291)
	AND ito.value_boolean = 1;
	/*End migration for Coqueluche [A37.90]**/
	/*Start migration for Dengue [A90]*, précisez :*/
	/*Insert obs_group_id*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159947,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70292,70293,70294)
	AND ito.value_boolean=1;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=159947 
	GROUP BY openmrs.obs.person_id,encounter_id;
	/*Concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,142592,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70292,70293,70294)
	AND ito.value_boolean=1;
	/*Confirmé,Suspecté*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159394,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159392,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70292,70293,70294)
	AND ito.value_boolean=1;
	/*Primaire,Secondaire*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159946,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159943,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id IN(70292,70293,70294)
	AND ito.value_boolean = 1;
	
	TRUNCATE TABLE itech.precisez;
	INSERT INTO itech.precisez(obs_id,person_id,concept_id,encounter_id,location_id, obs_group_id,value_coded)
	SELECT MAX(o.obs_id) as obs_id,o.person_id,
	o.concept_id,o.encounter_id, o.location_id, o.obs_group_id, o.value_coded 
	FROM openmrs.obs og, openmrs.obs o
	WHERE og.obs_id = o.obs_group_id
	AND o.concept_id = 1284
    AND o.value_coded = 142592
	AND og.concept_id = 159947
	GROUP BY o.person_id,o.encounter_id;
	
	UPDATE openmrs.obs ob, itech.obs ito, encounter c, itech.encounter e, itech.precisez ip
		   SET ob.comments = ito.value_text
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id = 70295
	AND (ito.value_text <> '' AND ito.value_text is not null)
	AND ip.person_id = ob.person_id
	AND ip.concept_id = ob.concept_id
	AND ip.encounter_id = ob.encounter_id
	AND ip.location_id = ob.location_id
	AND ip.obs_group_id = ob.obs_group_id
	AND ip.value_coded = ob.value_coded
	AND ip.concept_id = 1284
	AND ip.value_coded = 142592;
	/*End migration for Dengue [A90]*, précisez :*/
	/*Start migration for Diphtérie [A36]**/
	/*Insert obs_group_id*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159947,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70296,70297,70298)
	AND ito.value_boolean=1;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(o.obs_id) as obs_id,o.person_id,o.concept_id,o.encounter_id
	FROM openmrs.obs o
	WHERE o.concept_id=159947 
	GROUP BY o.person_id,o.encounter_id;
	/*Concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,119399,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70296,70297,70298)
	AND ito.value_boolean=1;
	/*Confirmé,Suspecté*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159394,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159392,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70296,70297,70298)
	AND ito.value_boolean=1;
	/*Primaire,Secondaire*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159946,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159943,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id IN(70296,70297,70298)
	AND ito.value_boolean = 1;
	/*End migration for Diphtérie [A36]**/
	/*Start migration for Fièvre hémorragique aiguë [N/A]*/
	/*Insert obs_group_id*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159947,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70882,70883,70884)
	AND ito.value_boolean=1;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(o.obs_id) as obs_id,o.person_id,o.concept_id,o.encounter_id
	FROM openmrs.obs o
	WHERE o.concept_id=159947 
	GROUP BY o.person_id,o.encounter_id;
	/*Concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,163392,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70882,70883,70884)
	AND ito.value_boolean=1;
	/*Confirmé,Suspecté*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159394,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159392,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70882,70883,70884)
	AND ito.value_boolean=1;
	/*Primaire,Secondaire*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159946,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159943,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id IN(70882,70883,70884)
	AND ito.value_boolean = 1;
	/*End migration for Fièvre hémorragique aiguë [N/A]*/
	/*Start migration for Fièvre Typhoïde * [Z22.0]**/
	/*Insert obs_group_id*/
	/*70302 = Fièvre Typhoïde * confirmé [Z22.0]*, 71340 = Fièvre Typhoïde * suspect [A01.00]**/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159947,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70302,70303,70304,71340,71341,71342)
	AND ito.value_boolean=1;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(o.obs_id) as obs_id,o.person_id,o.concept_id,o.encounter_id
	FROM openmrs.obs o
	WHERE o.concept_id=159947 
	GROUP BY o.person_id,o.encounter_id;
	/*Concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,141,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70302,70303,70304,71340,71341,71342)
	AND ito.value_boolean=1;
	/*Confirmé,Suspecté*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159394,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,
	CASE WHEN (ito.concept_id = 70302) THEN 159392
	WHEN (ito.concept_id = 71340) THEN 159393
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70302,70303,70304,71340,71341,71342)
	AND ito.value_boolean=1;
	/*Primaire,Secondaire*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159946,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159943,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id IN(70302,70303,70304,71340,71341,71342)
	AND ito.value_boolean = 1;
	/*End migration for Fièvre Typhoïde * [Z22.0]**/
	/*Start migration for Filariose lymphatique [B74.9]*/
	/*Insert obs_group_id*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159947,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70461,70845,70846)
	AND ito.value_boolean=1;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(o.obs_id) as obs_id,o.person_id,o.concept_id,o.encounter_id
	FROM openmrs.obs o
	WHERE o.concept_id=159947 
	GROUP BY o.person_id,o.encounter_id;
	/*Concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,119354,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70461,70845,70846)
	AND ito.value_boolean=1;
	/*Confirmé,Suspecté*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159394,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159392,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70461,70845,70846)
	AND ito.value_boolean=1;
	/*Primaire,Secondaire*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159946,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159943,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id IN(70461,70845,70846)
	AND ito.value_boolean = 1;
	/*End migration for Filariose lymphatique [B74.9]*/
	/*Start migration for Gale [B86]*/
	/*Insert obs_group_id*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159947,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70305,70306,70307)
	AND ito.value_boolean=1;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(o.obs_id) as obs_id,o.person_id,o.concept_id,o.encounter_id
	FROM openmrs.obs o
	WHERE o.concept_id=159947 
	GROUP BY o.person_id,o.encounter_id;
	/*Concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,140,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70305,70306,70307)
	AND ito.value_boolean=1;
	/*Confirmé,Suspecté*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159394,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159392,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70305,70306,70307)
	AND ito.value_boolean=1;
	/*Primaire,Secondaire*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159946,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159943,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id IN(70305,70306,70307)
	AND ito.value_boolean = 1;
	/*End migration for Gale [B86]*/
	/*Start migration for Infection respiratoire aiguë [J06.9]*/
	/*Insert obs_group_id*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159947,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70308,70309,70310)
	AND ito.value_boolean=1;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(o.obs_id) as obs_id,o.person_id,o.concept_id,o.encounter_id
	FROM openmrs.obs o
	WHERE o.concept_id=159947 
	GROUP BY o.person_id,o.encounter_id;
	/*Concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,154983,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70308,70309,70310)
	AND ito.value_boolean=1;
	/*Confirmé,Suspecté*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159394,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159392,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70308,70309,70310)
	AND ito.value_boolean=1;
	/*Primaire,Secondaire*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159946,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159943,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id IN(70308,70309,70310)
	AND ito.value_boolean = 1;
	/*End migration for Infection respiratoire aiguë [J06.9]*/
	
	/*Start migration for Infection génito-urinaire*/
	
	/*End migration for Infection génito-urinaire*/
	
	/*Start migration for Infection des tissus mous*/
	/*Insert obs_group_id*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159947,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70311,70312,70313)
	AND ito.value_boolean=1;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(o.obs_id) as obs_id,o.person_id,o.concept_id,o.encounter_id
	FROM openmrs.obs o
	WHERE o.concept_id=159947 
	GROUP BY o.person_id,o.encounter_id;
	/*Concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,158842,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70311,70312,70313)
	AND ito.value_boolean=1;
	/*Confirmé,Suspecté*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159394,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159392,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70311,70312,70313)
	AND ito.value_boolean=1;
	/*Primaire,Secondaire*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159946,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159943,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id IN(70311,70312,70313)
	AND ito.value_boolean = 1;
	/*End migration for Infection des tissus mous*/
	/*Start migration for Lèpre [A30]*/
	/*Insert obs_group_id*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159947,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70314,70315,70316)
	AND ito.value_boolean=1;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(o.obs_id) as obs_id,o.person_id,o.concept_id,o.encounter_id
	FROM openmrs.obs o
	WHERE o.concept_id=159947 
	GROUP BY o.person_id,o.encounter_id;
	/*Concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,116344,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70314,70315,70316)
	AND ito.value_boolean=1;
	/*Confirmé,Suspecté*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159394,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159392,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70314,70315,70316)
	AND ito.value_boolean=1;
	/*Primaire,Secondaire*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159946,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159943,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id IN(70314,70315,70316)
	AND ito.value_boolean = 1;
	/*End migration for Lèpre [A30]*/
	/*Start migration Méningites [G03.9]*, précisez :*/
	/*Insert obs_group_id*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159947,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70320,70321,70322)
	AND ito.value_boolean = 1;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=159947 
	GROUP BY openmrs.obs.person_id,encounter_id;
	/*Concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,115835,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70320,70321,70322)
	AND ito.value_boolean=1;
	/*Confirmé,Suspecté*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159394,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159392,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70320,70321,70322)
	AND ito.value_boolean=1;
	/*Primaire,Secondaire*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159946,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159943,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id IN(70320,70321,70322)
	AND ito.value_boolean = 1;
	
	TRUNCATE TABLE itech.precisez;
	INSERT INTO itech.precisez(obs_id,person_id,concept_id,encounter_id,location_id, obs_group_id,value_coded)
	SELECT MAX(o.obs_id) as obs_id,o.person_id,
	o.concept_id,o.encounter_id, o.location_id, o.obs_group_id, o.value_coded 
	FROM openmrs.obs og, openmrs.obs o
	WHERE og.obs_id = o.obs_group_id
	AND o.concept_id = 1284
    AND o.value_coded = 115835
	AND og.concept_id = 159947
	GROUP BY o.person_id,o.encounter_id;
	
	UPDATE openmrs.obs ob, itech.obs ito, encounter c, itech.encounter e, itech.precisez ip
		   SET ob.comments = ito.value_text
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id = 70853
	AND (ito.value_text <> '' AND ito.value_text is not null)
	AND ip.person_id = ob.person_id
	AND ip.concept_id = ob.concept_id
	AND ip.encounter_id = ob.encounter_id
	AND ip.location_id = ob.location_id
	AND ip.obs_group_id = ob.obs_group_id
	AND ip.value_coded = ob.value_coded
	AND ip.concept_id = 1284
	AND ip.value_coded = 115835;
	/*End migration for Méningites [G03.9]*, précisez :*/
	
	/*Start migration for Otite, précisez :*/
	/*Insert obs_group_id*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159947,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70323,70324,70325)
	AND ito.value_boolean = 1;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=159947 
	GROUP BY openmrs.obs.person_id,encounter_id;
	/*Concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,131115,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70323,70324,70325)
	AND ito.value_boolean=1;
	/*Confirmé,Suspecté*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159394,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159392,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70323,70324,70325)
	AND ito.value_boolean=1;
	/*Primaire,Secondaire*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159946,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159943,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id IN(70323,70324,70325)
	AND ito.value_boolean = 1;
	
	TRUNCATE TABLE itech.precisez;
	INSERT INTO itech.precisez(obs_id,person_id,concept_id,encounter_id,location_id, obs_group_id,value_coded)
	SELECT MAX(o.obs_id) as obs_id,o.person_id,
	o.concept_id,o.encounter_id, o.location_id, o.obs_group_id, o.value_coded 
	FROM openmrs.obs og, openmrs.obs o
	WHERE og.obs_id = o.obs_group_id
	AND o.concept_id = 1284
    AND o.value_coded = 131115
	AND og.concept_id = 159947
	GROUP BY o.person_id,o.encounter_id;
	
	UPDATE openmrs.obs ob, itech.obs ito, encounter c, itech.encounter e, itech.precisez ip
		   SET ob.comments = ito.value_text
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id = 70326 
	AND (ito.value_text <> '' AND ito.value_text is not null)
	AND ip.person_id = ob.person_id
	AND ip.concept_id = ob.concept_id
	AND ip.encounter_id = ob.encounter_id
	AND ip.location_id = ob.location_id
	AND ip.obs_group_id = ob.obs_group_id
	AND ip.value_coded = ob.value_coded
	AND ip.concept_id = 1284
	AND ip.value_coded = 131115;
	/*End migration for Otite, précisez :*/
	
	/*Start migration for Parasitose [B89]*/
	/*Insert obs_group_id*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159947,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70330,70331,70332)
	AND ito.value_boolean = 1;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=159947 
	GROUP BY openmrs.obs.person_id,encounter_id;
	/*Concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,119387,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70330,70331,70332)
	AND ito.value_boolean=1;
	/*Confirmé,Suspecté*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159394,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159392,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70330,70331,70332)
	AND ito.value_boolean=1;
	/*Primaire,Secondaire*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159946,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159943,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id IN(70330,70331,70332)
	AND ito.value_boolean = 1;
	/*End migration for Parasitose [B89]*/
	/*Start migration for Pneumonie [J18.9]*/
	/*Insert obs_group_id*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159947,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70327,70328,70329)
	AND ito.value_boolean = 1;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=159947 
	GROUP BY openmrs.obs.person_id,encounter_id;
	/*Concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,114100,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70327,70328,70329)
	AND ito.value_boolean=1;
	/*Confirmé,Suspecté*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159394,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159392,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70327,70328,70329)
	AND ito.value_boolean=1;
	/*Primaire,Secondaire*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159946,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159943,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id IN(70327,70328,70329)
	AND ito.value_boolean = 1;
	/*End migration for Pneumonie [J18.9]*/
	/*Start migration for Poliomyélite [A80.9]**/
	/*Insert obs_group_id*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159947,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70333,70334,70335)
	AND ito.value_boolean = 1;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=159947 
	GROUP BY openmrs.obs.person_id,encounter_id;
	/*Concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,5258,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70333,70334,70335)
	AND ito.value_boolean=1;
	/*Confirmé,Suspecté*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159394,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159392,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70333,70334,70335)
	AND ito.value_boolean=1;
	/*Primaire,Secondaire*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159946,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159943,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id IN(70333,70334,70335)
	AND ito.value_boolean = 1;
	/*End migration for Poliomyélite [A80.9]**/
	/*Start migration for Rage [A82.9]**/
	/*Insert obs_group_id*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159947,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70336,70337,70338)
	AND ito.value_boolean = 1;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=159947 
	GROUP BY openmrs.obs.person_id,encounter_id;
	/*Concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,160146,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70336,70337,70338)
	AND ito.value_boolean=1;
	/*Confirmé,Suspecté*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159394,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159392,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70336,70337,70338)
	AND ito.value_boolean=1;
	/*Primaire,Secondaire*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159946,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159943,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id IN(70336,70337,70338)
	AND ito.value_boolean = 1;
	/*End migration for Rage [A82.9]**/
	/*Start migration for Rougeole [B05.89]**/
	/*Insert obs_group_id*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159947,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70339,70340,70341)
	AND ito.value_boolean = 1;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=159947 
	GROUP BY openmrs.obs.person_id,encounter_id;
	/*Concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,134561,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70339,70340,70341)
	AND ito.value_boolean=1;
	/*Confirmé,Suspecté*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159394,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159392,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70339,70340,70341)
	AND ito.value_boolean=1;
	/*Primaire,Secondaire*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159946,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159943,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id IN(70339,70340,70341)
	AND ito.value_boolean = 1;
	/*End migration for Rougeole [B05.89]**/
	/*Start migration for Rubéole [B06.89]**/
		/*Insert obs_group_id*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159947,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70317,70318,70319)
	AND ito.value_boolean = 1;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=159947 
	GROUP BY openmrs.obs.person_id,encounter_id;
	/*Concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,113205,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70317,70318,70319)
	AND ito.value_boolean=1;
	/*Confirmé,Suspecté*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159394,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159392,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70317,70318,70319)
	AND ito.value_boolean=1;
	/*Primaire,Secondaire*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159946,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159943,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id IN(70317,70318,70319)
	AND ito.value_boolean = 1;
	/*End migration for Rubéole [B06.89]**/
	/*Start migration Syndrome ictérique fébrile [B15.9]**/
	/*Insert obs_group_id*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159947,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70342,70343,70344)
	AND ito.value_boolean = 1;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=159947 
	GROUP BY openmrs.obs.person_id,encounter_id;
	/*Concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,163402,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70342,70343,70344)
	AND ito.value_boolean=1;
	/*Confirmé,Suspecté*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159394,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159392,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70342,70343,70344)
	AND ito.value_boolean=1;
	/*Primaire,Secondaire*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159946,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159943,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id IN(70342,70343,70344)
	AND ito.value_boolean = 1;
	/*End migration for Syndrome ictérique fébrile [B15.9]**/
	/*Start migration for Teigne [B35.9]*/
	/*Insert obs_group_id*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159947,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70345,70346,70347)
	AND ito.value_boolean = 1;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=159947 
	GROUP BY openmrs.obs.person_id,encounter_id;
	/*Concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,119508,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70345,70346,70347)
	AND ito.value_boolean=1;
	/*Confirmé,Suspecté*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159394,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159392,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70345,70346,70347)
	AND ito.value_boolean=1;
	/*Primaire,Secondaire*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159946,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159943,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id IN(70345,70346,70347)
	AND ito.value_boolean = 1;
	/*End migration for Teigne [B35.9]*/
	/*Start migration for Tétanos [A35]**/
	/*Insert obs_group_id*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159947,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70855,70856,70857)
	AND ito.value_boolean = 1;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=159947 
	GROUP BY openmrs.obs.person_id,encounter_id;
	/*Concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,124957,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70855,70856,70857)
	AND ito.value_boolean=1;
	/*Confirmé,Suspecté*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159394,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159392,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70855,70856,70857)
	AND ito.value_boolean=1;
	/*Primaire,Secondaire*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159946,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159943,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id IN(70855,70856,70857)
	AND ito.value_boolean = 1;
	/*End migration for Tétanos [A35]**/
	/*Start migration for Varicelle [B01.9]*/
	/*Insert obs_group_id*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159947,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70354,70355,70356)
	AND ito.value_boolean = 1;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=159947 
	GROUP BY openmrs.obs.person_id,encounter_id;
	/*Concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,892,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70354,70355,70356)
	AND ito.value_boolean=1;
	/*Confirmé,Suspecté*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159394,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159392,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70354,70355,70356)
	AND ito.value_boolean=1;
	/*Primaire,Secondaire*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159946,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159943,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id IN(70354,70355,70356)
	AND ito.value_boolean = 1;
	/*End migration for Varicelle [B01.9]*/
	/*Start migration for Trouble psychiatrique d’étiologie à investiguer [F99]*/
	/*Insert obs_group_id*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159947,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70357,70358,70359)
	AND ito.value_boolean = 1;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=159947 
	GROUP BY openmrs.obs.person_id,encounter_id;
	/*Concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,131715,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70357,70358,70359)
	AND ito.value_boolean=1;
	/*Confirmé,Suspecté*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159394,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159392,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70357,70358,70359)
	AND ito.value_boolean=1;
	/*Primaire,Secondaire*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159946,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159943,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id IN(70357,70358,70359)
	AND ito.value_boolean = 1;
	/*End migration for Trouble psychiatrique d’étiologie à investiguer [F99]*/
	/*Start migration for Stress post traumatique [F43.10]*/
	/*Insert obs_group_id*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159947,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(1345,71346,71347)
	AND ito.value_boolean = 1;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=159947 
	GROUP BY openmrs.obs.person_id,encounter_id;
	/*Concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,113881,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(1345,71346,71347)
	AND ito.value_boolean=1;
	/*Confirmé,Suspecté*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159394,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159392,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(1345,71346,71347)
	AND ito.value_boolean=1;
	/*Primaire,Secondaire*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159946,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159943,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id IN(1345,71346,71347)
	AND ito.value_boolean = 1;
	/*End migration for Stress post traumatique [F43.10]*/
	
	/*Start migration for Brûlure [T30.0], précisez :*/
	/*Insert obs_group_id*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159947,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70363,70364,70365)
	AND ito.value_boolean = 1;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=159947 
	GROUP BY openmrs.obs.person_id,encounter_id;
	/*Concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,146623,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70363,70364,70365)
	AND ito.value_boolean=1;
	/*Confirmé,Suspecté*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159394,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159392,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70363,70364,70365)
	AND ito.value_boolean=1;
	/*Primaire,Secondaire*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159946,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159943,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id IN(70363,70364,70365)
	AND ito.value_boolean = 1;
	
	TRUNCATE TABLE itech.precisez;
	INSERT INTO itech.precisez(obs_id,person_id,concept_id,encounter_id,location_id, obs_group_id,value_coded)
	SELECT MAX(o.obs_id) as obs_id,o.person_id,
	o.concept_id,o.encounter_id, o.location_id, o.obs_group_id, o.value_coded 
	FROM openmrs.obs og, openmrs.obs o
	WHERE og.obs_id = o.obs_group_id
	AND o.concept_id = 1284
    AND o.value_coded = 146623
	AND og.concept_id = 159947
	GROUP BY o.person_id,o.encounter_id;
	
	UPDATE openmrs.obs ob, itech.obs ito, encounter c, itech.encounter e, itech.precisez ip
		   SET ob.comments = ito.value_text
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id = 70415 
	AND (ito.value_text <> '' AND ito.value_text is not null)
	AND ip.person_id = ob.person_id
	AND ip.concept_id = ob.concept_id
	AND ip.encounter_id = ob.encounter_id
	AND ip.location_id = ob.location_id
	AND ip.obs_group_id = ob.obs_group_id
	AND ip.value_coded = ob.value_coded
	AND ip.concept_id = 1284
	AND ip.value_coded = 146623 ;
	/*End migration for Brûlure [T30.0], précisez :*/
	/*Start migration for Fracture osseuse [T14.8], précisez*/
	/*Insert obs_group_id*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159947,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70366,70367,70368)
	AND ito.value_boolean = 1;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=159947 
	GROUP BY openmrs.obs.person_id,encounter_id;
	/*Concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,177,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70366,70367,70368)
	AND ito.value_boolean=1;
	/*Confirmé,Suspecté*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159394,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159392,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70366,70367,70368)
	AND ito.value_boolean=1;
	/*Primaire,Secondaire*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159946,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159943,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id IN(70366,70367,70368)
	AND ito.value_boolean = 1;
	
	TRUNCATE TABLE itech.precisez;
	INSERT INTO itech.precisez(obs_id,person_id,concept_id,encounter_id,location_id, obs_group_id,value_coded)
	SELECT MAX(o.obs_id) as obs_id,o.person_id,
	o.concept_id,o.encounter_id, o.location_id, o.obs_group_id, o.value_coded 
	FROM openmrs.obs og, openmrs.obs o
	WHERE og.obs_id = o.obs_group_id
	AND o.concept_id = 1284
    AND o.value_coded = 177
	AND og.concept_id = 159947
	GROUP BY o.person_id,o.encounter_id;
	
	UPDATE openmrs.obs ob, itech.obs ito, encounter c, itech.encounter e, itech.precisez ip
		   SET ob.comments = ito.value_text
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id = 70369
	AND (ito.value_text <> '' AND ito.value_text is not null)
	AND ip.person_id = ob.person_id
	AND ip.concept_id = ob.concept_id
	AND ip.encounter_id = ob.encounter_id
	AND ip.location_id = ob.location_id
	AND ip.obs_group_id = ob.obs_group_id
	AND ip.value_coded = ob.value_coded
	AND ip.concept_id = 1284
	AND ip.value_coded = 177;
	/*End migration for Fracture osseuse [T14.8], précisez*/
	
	/*Start migration for Plaie, précisez :*/
	/*Insert obs_group_id*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159947,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70370,70371,70372)
	AND ito.value_boolean = 1;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=159947 
	GROUP BY openmrs.obs.person_id,encounter_id;
	/*Concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159328,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70370,70371,70372)
	AND ito.value_boolean=1;
	/*Confirmé,Suspecté*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159394,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159392,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70370,70371,70372)
	AND ito.value_boolean=1;
	/*Primaire,Secondaire*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159946,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159943,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id IN(70370,70371,70372)
	AND ito.value_boolean = 1;
	
	TRUNCATE TABLE itech.precisez;
	INSERT INTO itech.precisez(obs_id,person_id,concept_id,encounter_id,location_id, obs_group_id,value_coded)
	SELECT MAX(o.obs_id) as obs_id,o.person_id,
	o.concept_id,o.encounter_id, o.location_id, o.obs_group_id, o.value_coded 
	FROM openmrs.obs og, openmrs.obs o
	WHERE og.obs_id = o.obs_group_id
	AND o.concept_id = 1284
    AND o.value_coded = 159328 
	AND og.concept_id = 159947
	GROUP BY o.person_id,o.encounter_id;
	
	UPDATE openmrs.obs ob, itech.obs ito, encounter c, itech.encounter e, itech.precisez ip
		   SET ob.comments = ito.value_text
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id = 70373
	AND (ito.value_text <> '' AND ito.value_text is not null)
	AND ip.person_id = ob.person_id
	AND ip.concept_id = ob.concept_id
	AND ip.encounter_id = ob.encounter_id
	AND ip.location_id = ob.location_id
	AND ip.obs_group_id = ob.obs_group_id
	AND ip.value_coded = ob.value_coded
	AND ip.concept_id = 1284
	AND ip.value_coded = 159328;
	/*End migration for Plaie, précisez : */
	
	/*Start migration for Trauma crânien [S09.90XA]*/
	/*Insert obs_group_id*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159947,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70374,70375,70376)
	AND ito.value_boolean = 1;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=159947 
	GROUP BY openmrs.obs.person_id,encounter_id;
	/*Concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,116838,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70374,70375,70376)
	AND ito.value_boolean=1;
	/*Confirmé,Suspecté*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159394,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159392,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70374,70375,70376)
	AND ito.value_boolean=1;
	/*Primaire,Secondaire*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159946,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159943,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id IN(70374,70375,70376)
	AND ito.value_boolean = 1;
	/*End migration for Trauma crânien [S09.90XA]*/
	
	/*Start migration for Cancer du col [C53.9]*/
	/*Insert obs_group_id*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159947,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70861,70862,70863)
	AND ito.value_boolean = 1;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=159947 
	GROUP BY openmrs.obs.person_id,encounter_id;
	/*Concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,116023,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70861,70862,70863)
	AND ito.value_boolean=1;
	/*Confirmé,Suspecté*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159394,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159392,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70861,70862,70863)
	AND ito.value_boolean=1;
	/*Primaire,Secondaire*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159946,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159943,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id IN(70861,70862,70863)
	AND ito.value_boolean = 1;
	/*End migration for Cancer du col [C53.9]*/
	/*Start migration for Cancer de la prostate [C61]*/
	/*Insert obs_group_id*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159947,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
	FROM itech.encounter e, encounter c, itech.obs ito
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(70864,70865,70866)
	AND ito.value_boolean = 1;
	/*Finding the last obs_group_id inserted */
	TRUNCATE TABLE itech.obs_concept_group;
	INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
	SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
	FROM openmrs.obs
	WHERE openmrs.obs.concept_id=159947 
	GROUP BY openmrs.obs.person_id,encounter_id;
	/*Concept*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1284,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,146221,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70864,70865,70866)
	AND ito.value_boolean=1;
	/*Confirmé,Suspecté*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159394,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159392,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id IN(70864,70865,70866)
	AND ito.value_boolean=1;
	/*Primaire,Secondaire*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159946,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,cg.obs_id,159943,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id IN(70864,70865,70866)
	AND ito.value_boolean = 1;
	/*End migration for Cancer de la prostate [C61]*/
	
 /*End migration for IMPRESSIONS CLINIQUES/DIAGNOSTIQUES*/
 /*Start migration for TURBERCULOSE*/
	/*Start migration for Statut VIH*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1169,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN(ito.value_numeric = 1) THEN 1402
	WHEN(ito.value_numeric = 2) THEN 664
	WHEN(ito.value_numeric = 4) THEN 703
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id = 71205
	AND ito.value_numeric IN(1,2,4);
	/*Date*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_datetime,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,160554,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,ito.value_datetime,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id = 71206
	AND (ito.value_datetime <>"" AND ito.value_datetime is not null);
	/*End migration for Statut VIH*/
	/*Start migration for Si positif, enrôlé(e) en soins :*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159811,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN(ito.value_numeric = 1) THEN 1065
	WHEN(ito.value_numeric = 2) THEN 1066
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id = 71212
	AND ito.value_numeric IN(1,2);
	/*End migration for Si positif, enrôlé(e) en soins :*/
	/*Start migration CD4:*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,5497,c.encounter_id,
	IF(ito1.value_datetime <>'' AND ito1.value_datetime is not null, DATE(ito1.value_datetime),
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
		WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
		WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
		ELSE
			DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
		END
	),c.location_id,digits(ito.value_numeric),1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs ito1
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.encounter_id = ito1.encounter_id
	AND ito.concept_id = 71208
	AND ito1.concept_id = 71226
	AND (ito.value_numeric <>'' AND ito.value_numeric is not null);
	/*End migration for CD4:*/
	/*Start migration for ARV*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,160117,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,
	CASE WHEN(ito.value_numeric = 1) THEN 160119
	WHEN(ito.value_numeric = 2) THEN 1461
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id = 71209
	AND ito.value_numeric IN(1,2);
	
	/*Si oui, médicaments :*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_text,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,163322,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,ito.value_text,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id = 71210
	AND (ito.value_text <>"" AND ito.value_text is not null);
	
	/*Date de début :*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_datetime,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,159599,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,ito.value_datetime,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id = 71211
	AND (ito.value_datetime <>"" AND ito.value_datetime is not null);
	
	/*End migration for ARV*/
	/*Start migration for Prophylaxie :*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1110,c.encounter_id,
	CASE WHEN (e.visitDateYy is null AND e.visitDateMm < 1 AND e.visitDateDd < 1) THEN NULL
	WHEN(e.visitDateMm < 1 AND e.visitDateDd > 0) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",01,"-",e.visitDateDd),"%Y-%m-%d")
	WHEN(e.visitDateMm > 0 AND e.visitDateDd < 1) THEN 
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",01),"%Y-%m-%d")
	ELSE
		DATE_FORMAT(concat(e.visitDateYy,"-",e.visitDateMm,"-",e.visitDateDd),"%Y-%m-%d")
	END,c.location_id,1679,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id IN(71409,71410)
	AND ito.value_boolean = 1;
	/*End migration for Prophylaxie :*/
	
	
	
	
	
 /*End migration for TURBERCULOSE*/
 
 
 
  /*Ending migration for SSP data*/
	SET SQL_SAFE_UPDATES = 1;
 END$$
	DELIMITER ;