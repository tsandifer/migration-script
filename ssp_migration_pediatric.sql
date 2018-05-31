DELIMITER $$
DROP PROCEDURE IF EXISTS sspPediatricMigration$$
CREATE PROCEDURE sspPediatricMigration()
BEGIN
SET SQL_SAFE_UPDATES = 0;
	/*Start migration for Informations generales*/
	/*Start migration for Référé(e) :*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,1648,c.encounter_id,c.encounter_datetime,c.location_id,
	CASE WHEN(ito.value_numeric = 1) THEN 1
	WHEN(ito.value_numeric = 2) THEN 2
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id = 70763
	AND ito.value_numeric IN(1,2);
	/*End migration for Référé(e) :*/
	create table if not exists itech.precisez 
	(obs_id int,person_id int,concept_id int,encounter_id int,
	location_id int, obs_group_id int, value_coded int);	
/*Start migration for Scolarisé :*/
INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,5629,c.encounter_id,c.encounter_datetime,c.location_id,
	CASE WHEN(ito.value_numeric = 1) THEN 1
	WHEN(ito.value_numeric = 2) THEN 2
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id = 70765
	AND ito.value_numeric IN(1,2);
	
	/*si oui, precisez*/
	TRUNCATE TABLE itech.precisez;
	INSERT INTO itech.precisez(obs_id,person_id,concept_id,encounter_id,location_id, value_coded)
	SELECT MAX(o.obs_id) as obs_id,o.person_id,
	o.concept_id,o.encounter_id, o.location_id, o.value_coded
	FROM openmrs.obs o
	WHERE o.concept_id=5629
    AND o.value_coded=1	
	GROUP BY o.person_id, o.encounter_id;
	
	UPDATE openmrs.obs ob, itech.obs ito, encounter c, itech.encounter e, itech.precisez ip
		   SET ob.comments=ito.value_text
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id = 70766
	AND (ito.value_text <> '' AND ito.value_text is not null)
	AND ip.person_id = ob.person_id
	AND ip.concept_id = ob.concept_id
	AND ip.encounter_id = ob.encounter_id
	AND ip.location_id = ob.location_id
	AND ip.value_coded = ob.value_coded
	AND ip.concept_id = 5629
	AND ip.value_coded = 1; 
	
	/*End migration for Scolarisé :*/
    /*Start migration for Poids de naissance :*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,
	creator,date_created,uuid)
	SELECT DISTINCT c.patient_id,5916,c.encounter_id,c.encounter_datetime,c.location_id,
	CASE WHEN(ito1.value_numeric = 1) THEN (digits(ito.value_text) * 0.45)
	WHEN(ito1.value_numeric = 2) THEN digits(ito.value_text)
	END,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs ito1
	WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.encounter_id = ito1.encounter_id
	AND ito.concept_id = 70767
	AND ito1.concept_id = 70768
	AND ito1.value_numeric IN(1,2);
	/*End migration for Poids de naissance :*/
	
	/*End migration for informations generales*/
	/*ANTECEDENTS PERSONNELS/HABITUDES*/
		 /*Create table obs_concept_group for the obs_group_id*/
	create table if not exists 
	itech.obs_concept_group (obs_id int,person_id int,concept_id int,encounter_id int);
		/*Malf. Congénitales, précisez:*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1633,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
		FROM itech.encounter e, encounter c, itech.obs ito
		WHERE c.uuid = e.encGuid
		AND e.siteCode = ito.location_id 
		AND e.encounter_id = ito.encounter_id
		AND ito.concept_id = 70740
		AND ito.value_boolean = 1;
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
	SELECT DISTINCT c.patient_id,1628,c.encounter_id,c.encounter_datetime,c.location_id,cg.obs_id,163390,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id=cg.encounter_id
	AND c.patient_id=cg.person_id
	AND ito.concept_id=70740
	AND ito.value_boolean=1;
	/*Update for précisez*/
	TRUNCATE TABLE itech.precisez;
	INSERT INTO itech.precisez(obs_id,person_id,concept_id,encounter_id,location_id, value_coded)
	SELECT MAX(o.obs_id) as obs_id,o.person_id,
	o.concept_id,o.encounter_id, o.location_id, o.value_coded
	FROM openmrs.obs o
	WHERE o.concept_id = 1628
    AND o.value_coded = 163390	
	GROUP BY o.person_id, o.encounter_id;
	
	UPDATE openmrs.obs ob, itech.obs ito, encounter c, itech.encounter e, itech.precisez ip
		   SET ob.comments=ito.value_text
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND ito.concept_id = 71071
	AND (ito.value_text <> '' AND ito.value_text is not null)
	AND ip.person_id = ob.person_id
	AND ip.concept_id = ob.concept_id
	AND ip.encounter_id = ob.encounter_id
	AND ip.location_id = ob.location_id
	AND ip.value_coded = ob.value_coded
	AND ip.concept_id = 1628
	AND ip.value_coded = 163390; 
		/*Malf. Congénitales, précisez:*/
		/*Start migration for RAA*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1633,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
		FROM itech.encounter e, encounter c, itech.obs ito
		WHERE c.uuid = e.encGuid
		AND e.siteCode = ito.location_id 
		AND e.encounter_id = ito.encounter_id
		AND ito.concept_id = 71017 	
		AND ito.value_boolean = 1;
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
	SELECT DISTINCT c.patient_id,1628,c.encounter_id,c.encounter_datetime,c.location_id,cg.obs_id,1870,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id = 71017 	
	AND ito.value_boolean=1;
		/*Stop migration for RAA*/
	  /*Start migration for Rougeole*/
	  INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1633,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
		FROM itech.encounter e, encounter c, itech.obs ito
		WHERE c.uuid = e.encGuid
		AND e.siteCode = ito.location_id 
		AND e.encounter_id = ito.encounter_id
		AND ito.concept_id = 71018 	
		AND ito.value_boolean = 1;
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
	SELECT DISTINCT c.patient_id,1628,c.encounter_id,c.encounter_datetime,c.location_id,cg.obs_id,163396,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id = 71018	
	AND ito.value_boolean=1;
	  /*Stop migration for Rougeole*/
	  /*Start migration for Prématurité*/
	  INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1633,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
		FROM itech.encounter e, encounter c, itech.obs ito
		WHERE c.uuid = e.encGuid
		AND e.siteCode = ito.location_id 
		AND e.encounter_id = ito.encounter_id
		AND ito.concept_id = 70741	
		AND ito.value_boolean = 1;
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
	SELECT DISTINCT c.patient_id,1628,c.encounter_id,c.encounter_datetime,c.location_id,cg.obs_id,1860,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id = 70741	
	AND ito.value_boolean=1;
	  /*End migration for Prématurité*/
	  /*Start migration for Varicelle*/
	   INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,1633,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
		FROM itech.encounter e, encounter c, itech.obs ito
		WHERE c.uuid = e.encGuid
		AND e.siteCode = ito.location_id 
		AND e.encounter_id = ito.encounter_id
		AND ito.concept_id = 71019	
		AND ito.value_boolean = 1;
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
	SELECT DISTINCT c.patient_id,1628,c.encounter_id,c.encounter_datetime,c.location_id,cg.obs_id,156655,1,e.createDate, UUID()
	from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
	WHERE c.uuid = e.encGuid
	AND e.siteCode = ito.location_id 
	AND e.encounter_id = ito.encounter_id
	AND c.encounter_id = cg.encounter_id
	AND c.patient_id = cg.person_id
	AND ito.concept_id = 71019	
	AND ito.value_boolean=1;
	  /*End migration for Varicelle*/
	  
	/*ANTECEDENTS PERSONNELS/HABITUDES*/
	/*Start migration for HISTOIRE ALIMENTAIRE*/
		/*Start migration for Allaitement maternel exclusif :*/
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
			creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,5526,c.encounter_id,c.encounter_datetime,c.location_id,
			CASE WHEN(ito.value_numeric = 1) THEN 1065
			WHEN(ito.value_numeric = 2) THEN 1066
			END,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND ito.concept_id = 70662
			AND ito.value_numeric IN(1,2);
		/*End migration for Allaitement maternel exclusif :*/
		/*Start migration for Si oui, durée en mois :*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,
			creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,163548,c.encounter_id,c.encounter_datetime,c.location_id,digits(ito.value_numeric),1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND ito.concept_id = 70659
			AND digits(ito.value_numeric)>0;
		/*End migrat for Si oui, durée en mois :*/
		/* Start migration for Préparation pour nourrissons (LM) :*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
			creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,5254,c.encounter_id,c.encounter_datetime,c.location_id,
			CASE WHEN(ito.value_numeric = 1) THEN 1065
			WHEN(ito.value_numeric = 2) THEN 1066
			END,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND ito.concept_id = 70663
			AND ito.value_numeric IN(1,2);
		/*End migration for Préparation pour nourrissons (LM) :*/
		/*Start migration for Si oui, précisez le lait :*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_text,
			creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,163553,c.encounter_id,c.encounter_datetime,c.location_id,ito.value_text,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND ito.concept_id = 70652
			AND (ito.value_text <> "" AND ito.value_text is not null);
		/*End migration for Si oui, précisez le lait :*/
		
		/*Start migration for Alimentation mixte :*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
			creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,6046,c.encounter_id,c.encounter_datetime,c.location_id,
			CASE WHEN(ito.value_numeric = 1) THEN 1065
			WHEN(ito.value_numeric = 2) THEN 1066
			END,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND ito.concept_id = 70664
			AND ito.value_numeric IN(1,2);
		/*End migration for Alimentation mixte :*/
		/*Start migration Diversification alimentaire :*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
			creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,163551,c.encounter_id,c.encounter_datetime,c.location_id,
			CASE WHEN(ito.value_numeric = 1) THEN 1065
			WHEN(ito.value_numeric = 2) THEN 1066
			END,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND ito.concept_id = 70665
			AND ito.value_numeric IN(1,2);
		/*End migration for Diversification alimentaire :*/
		/*Start migration for Si oui, âge en mois :*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_numeric,
			creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,163548,c.encounter_id,c.encounter_datetime,c.location_id,digits(ito.value_numeric),1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND ito.concept_id = 70651
			AND digits(ito.value_numeric)>0;	
		/*End migration for Si oui, âge en mois :*/

	/*End migration for HISTOIRE ALIMENTAIRE*/
	
	/*Start migration for SUPPLEMENTATION EN VITAMINE A (VIT.A),FER,IODE,ZINC,DEPARASITAGE(DEP.)*/
			/*Start migration for Vitamine A*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,160741,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
		FROM itech.encounter e, encounter c, itech.obs ito
		WHERE c.uuid = e.encGuid
		AND e.siteCode = ito.location_id 
		AND e.encounter_id = ito.encounter_id
		AND ito.concept_id IN(70698,70771,70776,70781,70786,70791,71121)
		AND (ito.value_datetime <> "" AND ito.value_datetime is not null);
		/*Finding the last obs_group_id inserted */
		TRUNCATE TABLE itech.obs_concept_group;
		INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
		SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
		FROM openmrs.obs
		WHERE openmrs.obs.concept_id=160741 
		GROUP BY openmrs.obs.person_id,encounter_id;
			
			
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,
			value_coded,creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,1282,c.encounter_id,c.encounter_datetime,c.location_id,cg.obs_id,86339,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND c.encounter_id=cg.encounter_id
			AND ito.concept_id IN(70698,70771,70776,70781,70786,70791,71121)
			AND (ito.value_datetime <> "" AND ito.value_datetime is not null);
			/* Dates */
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,
			value_datetime,creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,1190,c.encounter_id,c.encounter_datetime,c.location_id,cg.obs_id,ito.value_datetime,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND c.encounter_id=cg.encounter_id
			AND ito.concept_id = 70698
			AND (ito.value_datetime <> "" AND ito.value_datetime is not null);
			
			
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,
			value_datetime,creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,1190,c.encounter_id,c.encounter_datetime,c.location_id,cg.obs_id,ito.value_datetime,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND c.encounter_id=cg.encounter_id
			AND ito.concept_id = 70771
			AND (ito.value_datetime <> "" AND ito.value_datetime is not null);
			
			
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,
			value_datetime,creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,1190,c.encounter_id,c.encounter_datetime,c.location_id,cg.obs_id,ito.value_datetime,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND c.encounter_id=cg.encounter_id
			AND ito.concept_id = 70776
			AND (ito.value_datetime <> "" AND ito.value_datetime is not null);
			
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,
			value_datetime,creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,1190,c.encounter_id,c.encounter_datetime,c.location_id,cg.obs_id,ito.value_datetime,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND c.encounter_id=cg.encounter_id
			AND ito.concept_id = 70781
			AND (ito.value_datetime <> "" AND ito.value_datetime is not null);
			
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,
			value_datetime,creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,1190,c.encounter_id,c.encounter_datetime,c.location_id,cg.obs_id,ito.value_datetime,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito,itech.obs_concept_group cg
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND c.encounter_id=cg.encounter_id
			AND ito.concept_id = 70786
			AND (ito.value_datetime <> "" AND ito.value_datetime is not null);
			
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,
			value_datetime,creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,1190,c.encounter_id,c.encounter_datetime,c.location_id,cg.obs_id,ito.value_datetime,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND c.encounter_id=cg.encounter_id
			AND ito.concept_id = 70791
			AND (ito.value_datetime <> "" AND ito.value_datetime is not null);
			
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,
			value_datetime,creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,1190,c.encounter_id,c.encounter_datetime,c.location_id,cg.obs_id,ito.value_datetime,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND c.encounter_id=cg.encounter_id
			AND ito.concept_id = 71121
			AND (ito.value_datetime <> "" AND ito.value_datetime is not null);
			/*End migration for Vitamine A*/
			/*Start migration for Fer.*/
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
		SELECT DISTINCT c.patient_id,160741,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
		FROM itech.encounter e, encounter c, itech.obs ito
		WHERE c.uuid = e.encGuid
		AND e.siteCode = ito.location_id 
		AND e.encounter_id = ito.encounter_id
		AND ito.concept_id IN(70699,70772,70777,70782,70787,70792,71122)
		AND (ito.value_datetime <> "" AND ito.value_datetime is not null);
		/*Finding the last obs_group_id inserted */
		TRUNCATE TABLE itech.obs_concept_group;
		INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
		SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
		FROM openmrs.obs
		WHERE openmrs.obs.concept_id=160741 
		GROUP BY openmrs.obs.person_id,encounter_id;
			
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
			creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,1282,c.encounter_id,c.encounter_datetime,c.location_id,5843,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND ito.concept_id IN(70699,70772,70777,70782,70787,70792,71122)
			AND (ito.value_datetime <> "" AND ito.value_datetime is not null);
			
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,
			value_datetime,creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,1190,c.encounter_id,c.encounter_datetime,c.location_id,cg.obs_id,ito.value_datetime,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND c.encounter_id=cg.encounter_id
			AND ito.concept_id = 70699
			AND (ito.value_datetime <> "" AND ito.value_datetime is not null);
			
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,
			value_datetime,creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,1190,c.encounter_id,c.encounter_datetime,c.location_id,cg.obs_id,ito.value_datetime,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND c.encounter_id=cg.encounter_id
			AND ito.concept_id = 70772
			AND (ito.value_datetime <> "" AND ito.value_datetime is not null);
			
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,
			value_datetime,creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,1190,c.encounter_id,c.encounter_datetime,c.location_id,cg.obs_id,ito.value_datetime,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND c.encounter_id=cg.encounter_id
			AND ito.concept_id = 70777
			AND (ito.value_datetime <> "" AND ito.value_datetime is not null);
			
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,
			value_datetime,creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,1190,c.encounter_id,c.encounter_datetime,c.location_id,cg.obs_id,ito.value_datetime,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND c.encounter_id=cg.encounter_id
			AND ito.concept_id = 70782
			AND (ito.value_datetime <> "" AND ito.value_datetime is not null);
			
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,
			value_datetime,creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,1190,c.encounter_id,c.encounter_datetime,c.location_id,cg.obs_id,ito.value_datetime,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND c.encounter_id=cg.encounter_id
			AND ito.concept_id = 70787
			AND (ito.value_datetime <> "" AND ito.value_datetime is not null);
			
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,
			value_datetime,creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,1190,c.encounter_id,c.encounter_datetime,c.location_id,cg.obs_id,ito.value_datetime,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND c.encounter_id=cg.encounter_id
			AND ito.concept_id = 70792
			AND (ito.value_datetime <> "" AND ito.value_datetime is not null);
			
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,
			value_datetime,creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,1190,c.encounter_id,c.encounter_datetime,c.location_id,cg.obs_id,ito.value_datetime,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND c.encounter_id=cg.encounter_id
			AND ito.concept_id = 71122
			AND (ito.value_datetime <> "" AND ito.value_datetime is not null);
			/*End migration for Fer.*/
			
			/*Start migration for Iode*/
				INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
				SELECT DISTINCT c.patient_id,160741,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
				FROM itech.encounter e, encounter c, itech.obs ito
				WHERE c.uuid = e.encGuid
				AND e.siteCode = ito.location_id 
				AND e.encounter_id = ito.encounter_id
				AND ito.concept_id IN(70700,70773,70778,70783,70788,70793,71123)
				AND (ito.value_datetime <> "" AND ito.value_datetime is not null);
				/*Finding the last obs_group_id inserted */
				TRUNCATE TABLE itech.obs_concept_group;
				INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
				SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
				FROM openmrs.obs
				WHERE openmrs.obs.concept_id=160741 
				GROUP BY openmrs.obs.person_id,encounter_id;
			
			
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,
			value_coded,creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,1282,c.encounter_id,c.encounter_datetime,c.location_id,cg.obs_id,78130,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND c.encounter_id = cg.encounter_id
			AND ito.concept_id IN(70700,70773,70778,70783,70788,70793,71123)
			AND (ito.value_datetime <> "" AND ito.value_datetime is not null);
			
				INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,
			value_datetime,creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,1190,c.encounter_id,c.encounter_datetime,c.location_id,cg.obs_id,ito.value_datetime,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND c.encounter_id=cg.encounter_id
			AND ito.concept_id = 70700
			AND (ito.value_datetime <> "" AND ito.value_datetime is not null);
			
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,
			value_datetime,creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,1190,c.encounter_id,c.encounter_datetime,c.location_id,cg.obs_id,ito.value_datetime,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND c.encounter_id=cg.encounter_id
			AND ito.concept_id = 70773
			AND (ito.value_datetime <> "" AND ito.value_datetime is not null);
			
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,
			value_datetime,creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,1190,c.encounter_id,c.encounter_datetime,c.location_id,cg.obs_id,ito.value_datetime,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND c.encounter_id=cg.encounter_id
			AND ito.concept_id = 70778
			AND (ito.value_datetime <> "" AND ito.value_datetime is not null);
			
			
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,
			value_datetime,creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,1190,c.encounter_id,c.encounter_datetime,c.location_id,cg.obs_id,ito.value_datetime,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND c.encounter_id=cg.encounter_id
			AND ito.concept_id = 70783
			AND (ito.value_datetime <> "" AND ito.value_datetime is not null);
			
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,
			value_datetime,creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,1190,c.encounter_id,c.encounter_datetime,c.location_id,cg.obs_id,ito.value_datetime,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND c.encounter_id=cg.encounter_id
			AND ito.concept_id = 70788
			AND (ito.value_datetime <> "" AND ito.value_datetime is not null);
			
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,
			value_datetime,creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,1190,c.encounter_id,c.encounter_datetime,c.location_id,cg.obs_id,ito.value_datetime,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND c.encounter_id=cg.encounter_id
			AND ito.concept_id = 70793
			AND (ito.value_datetime <> "" AND ito.value_datetime is not null);
			
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,
			value_datetime,creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,1190,c.encounter_id,c.encounter_datetime,c.location_id,cg.obs_id,ito.value_datetime,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND c.encounter_id=cg.encounter_id
			AND ito.concept_id = 71123
			AND (ito.value_datetime <> "" AND ito.value_datetime is not null);
			/*End migration for Iode*/
			
			/*Start migration for Déparasitage*/
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
				SELECT DISTINCT c.patient_id,160741,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
				FROM itech.encounter e, encounter c, itech.obs ito
				WHERE c.uuid = e.encGuid
				AND e.siteCode = ito.location_id 
				AND e.encounter_id = ito.encounter_id
				AND ito.concept_id IN(70769,70774,70779,70784,70789,70794,71124)
				AND (ito.value_datetime <> "" AND ito.value_datetime is not null);
				/*Finding the last obs_group_id inserted */
				TRUNCATE TABLE itech.obs_concept_group;
				INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
				SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
				FROM openmrs.obs
				WHERE openmrs.obs.concept_id=160741 
				GROUP BY openmrs.obs.person_id,encounter_id;
				
				INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,
			value_coded,creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,1282,c.encounter_id,c.encounter_datetime,c.location_id,cg.obs_id,163395,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND c.encounter_id = cg.encounter_id
			AND ito.concept_id IN(70769,70774,70779,70784,70789,70794,71124)
			AND (ito.value_datetime <> "" AND ito.value_datetime is not null);
			
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,
			value_datetime,creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,1190,c.encounter_id,c.encounter_datetime,c.location_id,cg.obs_id,ito.value_datetime,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND c.encounter_id=cg.encounter_id
			AND ito.concept_id = 70769
			AND (ito.value_datetime <> "" AND ito.value_datetime is not null);
			
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,
			value_datetime,creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,1190,c.encounter_id,c.encounter_datetime,c.location_id,cg.obs_id,ito.value_datetime,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND c.encounter_id=cg.encounter_id
			AND ito.concept_id = 70774
			AND (ito.value_datetime <> "" AND ito.value_datetime is not null);
			
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,
			value_datetime,creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,1190,c.encounter_id,c.encounter_datetime,c.location_id,cg.obs_id,ito.value_datetime,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND c.encounter_id=cg.encounter_id
			AND ito.concept_id = 70779
			AND (ito.value_datetime <> "" AND ito.value_datetime is not null);
			
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,
			value_datetime,creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,1190,c.encounter_id,c.encounter_datetime,c.location_id,cg.obs_id,ito.value_datetime,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND c.encounter_id=cg.encounter_id
			AND ito.concept_id = 70784
			AND (ito.value_datetime <> "" AND ito.value_datetime is not null);
			
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,
			value_datetime,creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,1190,c.encounter_id,c.encounter_datetime,c.location_id,cg.obs_id,ito.value_datetime,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND c.encounter_id=cg.encounter_id
			AND ito.concept_id = 70789
			AND (ito.value_datetime <> "" AND ito.value_datetime is not null);
			
				INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,
			value_datetime,creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,1190,c.encounter_id,c.encounter_datetime,c.location_id,cg.obs_id,ito.value_datetime,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND c.encounter_id=cg.encounter_id
			AND ito.concept_id = 70794
			AND (ito.value_datetime <> "" AND ito.value_datetime is not null);
			
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,
			value_datetime,creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,1190,c.encounter_id,c.encounter_datetime,c.location_id,cg.obs_id,ito.value_datetime,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND c.encounter_id=cg.encounter_id
			AND ito.concept_id = 71124
			AND (ito.value_datetime <> "" AND ito.value_datetime is not null);
			
			/*End migration for Déparasitage*/
			
			/*Start migration for Zinc*/
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
				SELECT DISTINCT c.patient_id,160741,c.encounter_id,c.encounter_datetime,c.location_id,1,c.date_created,UUID()
				FROM itech.encounter e, encounter c, itech.obs ito
				WHERE c.uuid = e.encGuid
				AND e.siteCode = ito.location_id 
				AND e.encounter_id = ito.encounter_id
				AND ito.concept_id IN(70770,70775,70780,70785,70790,70795,71125)
				AND (ito.value_datetime <> "" AND ito.value_datetime is not null);
				/*Finding the last obs_group_id inserted */
				TRUNCATE TABLE itech.obs_concept_group;
				INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
				SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
				FROM openmrs.obs
				WHERE openmrs.obs.concept_id=160741 
				GROUP BY openmrs.obs.person_id,encounter_id;
				
				INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,
			value_coded,creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,1282,c.encounter_id,c.encounter_datetime,c.location_id,cg.obs_id,86672,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND c.encounter_id = cg.encounter_id
			AND ito.concept_id IN(70770,70775,70780,70785,70790,70795,71125)
			AND (ito.value_datetime <> "" AND ito.value_datetime is not null);
			
				INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,
			value_datetime,creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,1190,c.encounter_id,c.encounter_datetime,c.location_id,cg.obs_id,ito.value_datetime,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND c.encounter_id=cg.encounter_id
			AND ito.concept_id = 70770
			AND (ito.value_datetime <> "" AND ito.value_datetime is not null);
			
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,
			value_datetime,creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,1190,c.encounter_id,c.encounter_datetime,c.location_id,cg.obs_id,ito.value_datetime,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND c.encounter_id=cg.encounter_id
			AND ito.concept_id = 70775 
			AND (ito.value_datetime <> "" AND ito.value_datetime is not null);
			
			
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,
			value_datetime,creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,1190,c.encounter_id,c.encounter_datetime,c.location_id,cg.obs_id,ito.value_datetime,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND c.encounter_id=cg.encounter_id
			AND ito.concept_id = 70780
			AND (ito.value_datetime <> "" AND ito.value_datetime is not null);
			
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,
			value_datetime,creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,1190,c.encounter_id,c.encounter_datetime,c.location_id,cg.obs_id,ito.value_datetime,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND c.encounter_id=cg.encounter_id
			AND ito.concept_id = 70785
			AND (ito.value_datetime <> "" AND ito.value_datetime is not null);
			
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,
			value_datetime,creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,1190,c.encounter_id,c.encounter_datetime,c.location_id,cg.obs_id,ito.value_datetime,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND c.encounter_id=cg.encounter_id
			AND ito.concept_id = 70790
			AND (ito.value_datetime <> "" AND ito.value_datetime is not null);
			
			
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,
			value_datetime,creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,1190,c.encounter_id,c.encounter_datetime,c.location_id,cg.obs_id,ito.value_datetime,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND c.encounter_id=cg.encounter_id
			AND ito.concept_id = 70795
			AND (ito.value_datetime <> "" AND ito.value_datetime is not null);
			
			
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,
			value_datetime,creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,1190,c.encounter_id,c.encounter_datetime,c.location_id,cg.obs_id,ito.value_datetime,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito, itech.obs_concept_group cg
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND c.encounter_id=cg.encounter_id
			AND ito.concept_id = 71125
			AND (ito.value_datetime <> "" AND ito.value_datetime is not null);
			/*End migration for Zinc*/
			
    /*End migration for SUPPLEMENTATION EN VITAMINE A (VIT.A),FER,IODE,ZINC,DEPARASITAGE(DEP.)*/
	
	/*Start migration for MOTIFS DE CONSULTATION*/
		/*Start migration for Insuffisance gain de poids*/
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
			creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,159614,c.encounter_id,c.encounter_datetime,c.location_id,140707,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito
			WHERE c.uuid = e.encGuid 
			AND e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND ito.concept_id = 70829
			AND ito.value_boolean=1;
	/*End migration for Insuffisance gain de poids*/
	/*Start migration for Malaise*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
			creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,159614,c.encounter_id,c.encounter_datetime,c.location_id,116130,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito
			WHERE c.uuid = e.encGuid 
			AND e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND ito.concept_id = 70830
			AND ito.value_boolean=1;
	/*End migration for Malaise*/
	/*Start migration for Myalgie*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
			creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,159614,c.encounter_id,c.encounter_datetime,c.location_id,121,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito
			WHERE c.uuid = e.encGuid 
			AND e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND ito.concept_id = 71338
			AND ito.value_boolean=1;
	/*End migration for Myalgie*/
	/*Start migration for Pleurs incessants inexpliqués*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
			creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,159614,c.encounter_id,c.encounter_datetime,c.location_id,143582,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito
			WHERE c.uuid = e.encGuid 
			AND e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND ito.concept_id = 70831
			AND ito.value_boolean=1;
	/*End migration for Pleurs incessants inexpliqués*/
	/*Start migration for Refus de téter / boire*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
			creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,159614,c.encounter_id,c.encounter_datetime,c.location_id,159861,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito
			WHERE c.uuid = e.encGuid 
			AND e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND ito.concept_id = 70832
			AND ito.value_boolean=1;
	/*End migration for Refus de téter / boire*/
	
	/*Start migration for Ecoulement de pus dans les yeux*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
			creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,159614,c.encounter_id,c.encounter_datetime,c.location_id,139098,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito
			WHERE c.uuid = e.encGuid 
			AND e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND ito.concept_id = 70833
			AND ito.value_boolean = 1;
	/*End migration for Ecoulement de pus dans les yeux*/
	/*Start migration for Pétéchie/Ecchymose*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
			creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,159614,c.encounter_id,c.encounter_datetime,c.location_id,130324,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito
			WHERE c.uuid = e.encGuid 
			AND e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND ito.concept_id = 70835
			AND ito.value_boolean = 1;
	/*End migration for Pétéchie/Ecchymose*/
	/*Start migration for Purpura*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
			creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,159614,c.encounter_id,c.encounter_datetime,c.location_id,113478,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito
			WHERE c.uuid = e.encGuid 
			AND e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND ito.concept_id = 71436
			AND ito.value_boolean = 1;
	/*End migration for Purpura*/
	/*Start migration for Urticaire*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
			creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,159614,c.encounter_id,c.encounter_datetime,c.location_id,123468,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito
			WHERE c.uuid = e.encGuid 
			AND e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND ito.concept_id = 70836
			AND ito.value_boolean = 1;
	/*End migration for Urticaire*/
	/*Start migration for Arthralgie*/
	INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
			creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,159614,c.encounter_id,c.encounter_datetime,c.location_id,80,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito
			WHERE c.uuid = e.encGuid 
			AND e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND ito.concept_id = 70837
			AND ito.value_boolean = 1;
	/*End migration for Arthralgie*/
	/*Start migration for Irritablilité/agitation*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
			creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,159614,c.encounter_id,c.encounter_datetime,c.location_id,6023,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito
			WHERE c.uuid = e.encGuid 
			AND e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND ito.concept_id = 70838
			AND ito.value_boolean = 1;
	/*End migration for Irritablilité/agitation*/
	
	/*Start migration for Léthargie/inconscient (verifier)*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
			creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,159614,c.encounter_id,c.encounter_datetime,c.location_id,116334,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito
			WHERE c.uuid = e.encGuid 
			AND e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND ito.concept_id = 7033
			AND ito.value_boolean = 1;
	/*End migration for Léthargie/inconscient*/
	/*Start migration for Enurésie*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
			creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,159614,c.encounter_id,c.encounter_datetime,c.location_id,115243,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito
			WHERE c.uuid = e.encGuid 
			AND e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND ito.concept_id = 70839
			AND ito.value_boolean = 1;
	/*End migration for Enurésie*/
	
	/*End migration for MOTIFS DE CONSULTATION*/
	
	/*Start migration for ÉVALUATION DU DÉVELOPPEMENT PSYCHOMOTEUR */
		/*Start migration for Motricité globale*/
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
			creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,163578,c.encounter_id,c.encounter_datetime,c.location_id,
			CASE WHEN(ito.value_numeric = 1) THEN 160275
			WHEN(ito.value_numeric = 2) THEN 160276
			END,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND ito.concept_id = 70746
			AND ito.value_numeric IN(1,2);
		/*End migration for Motricité globale*/
		/*Start migration for Motricité Fine*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
			creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,163579,c.encounter_id,c.encounter_datetime,c.location_id,
			CASE WHEN(ito.value_numeric = 1) THEN 160275
			WHEN(ito.value_numeric = 2) THEN 160276
			END,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND ito.concept_id = 70747
			AND ito.value_numeric IN(1,2);
		/*End migration for Motricité Fine*/
		/*Start migration for Langage/Compréhension*/
			INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
			creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,163787,c.encounter_id,c.encounter_datetime,c.location_id,
			CASE WHEN(ito.value_numeric = 1) THEN 160275
			WHEN(ito.value_numeric = 2) THEN 160276
			END,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND ito.concept_id = 70748
			AND ito.value_numeric IN(1,2);
		/*End migration for Langage/Compréhension*/
		/*Start migration for Contact Social*/
		INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,
			creator,date_created,uuid)
			SELECT DISTINCT c.patient_id,163580,c.encounter_id,c.encounter_datetime,c.location_id,
			CASE WHEN(ito.value_numeric = 1) THEN 160275
			WHEN(ito.value_numeric = 2) THEN 160276
			END,1,e.createDate, UUID()
			from encounter c, itech.encounter e, itech.obs ito
			WHERE c.uuid = e.encGuid and e.siteCode = ito.location_id 
			AND e.encounter_id = ito.encounter_id
			AND ito.concept_id = 70749
			AND ito.value_numeric IN(1,2);
		/*End migration for Contact Social*/
		
	/*End migration for ÉVALUATION DU DÉVELOPPEMENT PSYCHOMOTEUR */
	
	/*IMPRESSIONS CLINIQUES/DIAGNOSTIQUES*/
	/* Anémie Carentielle [281.0] */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70911,70949,70950) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,1226,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70911,70949,70950) and o.value_boolean=1;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70911,70949,70950) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70911,70949,70950) and o.value_boolean=1;
/* End of Anémie Carentielle [281.0] */

	/* Anémie Falciforme [282.6] */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70912,70951,70952) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,117703,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70912,70951,70952) and o.value_boolean=1;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70912,70951,70952) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70912,70951,70952) and o.value_boolean=1;
/* End of Anémie Falciforme [282.6] */	
	
	

/*Bronchite [490] */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70913,70953,70954) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,47,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70913,70953,70954) and o.value_boolean=1;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70913,70953,70954) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70913,70953,70954) and o.value_boolean=1;
/*END OF Bronchite [490]*/


/*Crises convulsives fébriles [780.31]*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70914,70955,70956) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,140485,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70914,70955,70956) and o.value_boolean=1;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70914,70955,70956) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70914,70955,70956) and o.value_boolean=1;
/* end of Crises convulsives fébriles [780.31]*/


/* Malnutrition aigue légère [263.1] */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70915,70957,70958) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,134723,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70915,70957,70958) and o.value_boolean=1;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70915,70957,70958) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70915,70957,70958) and o.value_boolean=1;
/* END of Malnutrition aigue légère [263.1]*/


/* Malnutrition aigue modérée [263]*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70916,70959,70960) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,134722,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70916,70959,70960) and o.value_boolean=1;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70916,70959,70960) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70916,70959,70960) and o.value_boolean=1;
/* END of Malnutrition aigue modérée [263] */

/* Malnutrition aigue sévère [261] (compl.) */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70917,70961,70962) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,126598,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70917,70961,70962) and o.value_boolean=1;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70917,70961,70962) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70917,70961,70962) and o.value_boolean=1;
/* END of Malnutrition aigue sévère [261] (compl.) */
	
/* Dermatite atopique [691] */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70918,70963,70964) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,121348,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70918,70963,70964) and o.value_boolean=1;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70918,70963,70964) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70918,70963,70964) and o.value_boolean=1;
/* END of Dermatite atopique [691] */	

/* Diarrhée cause indéterminée [R19.7] */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70255,70256,70257) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,145443,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70255,70256,70257) and o.value_boolean=1;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70255,70256,70257) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70255,70256,70257) and o.value_boolean=1;
/* END of Diarrhée cause indéterminée [R19.7] */	

/* Gastro-entérite [558.9] avec:*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70919,70965,70966,70920,70967,70968,70921,70969,70970) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,117889,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70919,70965,70966,70920,70967,70968,70921,70969,70970) and o.value_boolean=1;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70919,70965,70966,70920,70967,70968,70921,70969,70970) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70919,70965,70966,70920,70967,70968,70921,70969,70970) and o.value_boolean=1;
/* END of Gastro-entérite [558.9] avec:*/

/* déshydratation légère */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70919,70965,70966) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,154017,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70919,70965,70966) and o.value_boolean=1;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70919,70965,70966) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70919,70965,70966) and o.value_boolean=1;
/* END of déshydratation légère */


/* déshydratation modérée */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70920,70967,70968) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,154016,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70920,70967,70968) and o.value_boolean=1;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70920,70967,70968) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70920,70967,70968) and o.value_boolean=1;
/* END of déshydratation modérée */

/* déshydratation sévère */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70921,70969,70970) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,154015,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70921,70969,70970) and o.value_boolean=1;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70921,70969,70970) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70921,70969,70970) and o.value_boolean=1;
/* END of déshydratation sévère */
	

/* Obésité [278.00]*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70922,70971,70972) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,115115,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70922,70971,70972) and o.value_boolean=1;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70922,70971,70972) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70922,70971,70972) and o.value_boolean=1;
/* END of Obésité [278.00] */	
	

/* Rhumatisme articulaire aigu [714.30] */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70742,70973,70974) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,127447,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70742,70973,70974) and o.value_boolean=1;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70742,70973,70974) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70742,70973,70974) and o.value_boolean=1;
/* END of Rhumatisme articulaire aigu [714.30] */	

/* Rhinite allergique [477] */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70923,70975,70976) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,113119,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70923,70975,70976) and o.value_boolean=1;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70923,70975,70976) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70923,70975,70976) and o.value_boolean=1;
/* END of Rhinite allergique [477] */


/* Reflux gastro-œsophagien [530.81]*/
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70924,70977,70978) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,1293,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70924,70977,70978) and o.value_boolean=1;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70924,70977,70978) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70924,70977,70978) and o.value_boolean=1;
/* END of Reflux gastro-œsophagien [530.81] */


/* Syndrome néphrotique [581] */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70925,70979,70980) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,115303,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70925,70979,70980) and o.value_boolean=1;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70925,70979,70980) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70925,70979,70980) and o.value_boolean=1;
/* END of Syndrome néphrotique [581] */


/* Bonne Sante Apparente [Z00.129] */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (71634) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,1855,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71634) and o.value_boolean=1;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71634) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (71634) and o.value_boolean=1;
/* END of Bonne Sante Apparente [Z00.129] */


/* Abcès [682.9], précisez: */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70927,70981,70982) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,111145,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70927,70981,70982) and o.value_boolean=1;
	
TRUNCATE TABLE itech.precisez;
 INSERT INTO itech.precisez(obs_id,person_id,concept_id,encounter_id,location_id, value_coded)
 SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,
 openmrs.obs.concept_id,openmrs.obs.encounter_id, openmrs.obs.location_id, openmrs.obs.value_coded
 FROM openmrs.obs
 WHERE openmrs.obs.concept_id=1284
    AND openmrs.obs.value_coded=111145 
 GROUP BY openmrs.obs.person_id,encounter_id;
 
 UPDATE openmrs.obs ob, itech.obs ito, encounter c, itech.encounter e, itech.precisez ip
     SET ob.comments=ito.value_text
 WHERE c.uuid = e.encGuid
 AND e.siteCode = ito.location_id 
 AND e.encounter_id = ito.encounter_id
 AND ito.concept_id=70928 
 AND (ito.value_text <> '' AND ito.value_text is not null)
 AND ip.person_id=ob.person_id
 AND ip.concept_id=ob.concept_id
 AND ip.encounter_id=ob.encounter_id
 AND ip.location_id=ob.location_id
 AND ip.value_coded=ob.value_coded
 AND ip.concept_id=1284
 AND ip.value_coded=111145;		
	
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70927,70981,70982) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70927,70981,70982) and o.value_boolean=1;
/* end of Abcès [682.9], précisez: */
	
/* Glomérulonéphrite aiguë [580.9] */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70929,70983,70984) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,122041,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70929,70983,70984) and o.value_boolean=1;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70929,70983,70984) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70929,70983,70984) and o.value_boolean=1;
/* END OF Glomérulonéphrite aiguë [580.9] */	

/* Impétigo [684] */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70930,70985,70986) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,137693,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70930,70985,70986) and o.value_boolean=1;
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70930,70985,70986) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70930,70985,70986) and o.value_boolean=1;
/* END OF Impétigo [684] */
	
/* Mycose cutanée [111.9], */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70932,70987,70988) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,119525,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70932,70987,70988) and o.value_boolean=1;
	
TRUNCATE TABLE itech.precisez;
 INSERT INTO itech.precisez(obs_id,person_id,concept_id,encounter_id,location_id, value_coded)
 SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,
 openmrs.obs.concept_id,openmrs.obs.encounter_id, openmrs.obs.location_id, openmrs.obs.value_coded
 FROM openmrs.obs
 WHERE openmrs.obs.concept_id=1284
    AND openmrs.obs.value_coded=119525 
 GROUP BY openmrs.obs.person_id,encounter_id;
 
 UPDATE openmrs.obs ob, itech.obs ito, encounter c, itech.encounter e, itech.precisez ip
     SET ob.comments=ito.value_text
 WHERE c.uuid = e.encGuid
 AND e.siteCode = ito.location_id 
 AND e.encounter_id = ito.encounter_id
 AND ito.concept_id=70933 
 AND (ito.value_text <> '' AND ito.value_text is not null)
 AND ip.person_id=ob.person_id
 AND ip.concept_id=ob.concept_id
 AND ip.encounter_id=ob.encounter_id
 AND ip.location_id=ob.location_id
 AND ip.value_coded=ob.value_coded
 AND ip.concept_id=1284
 AND ip.value_coded=119525;		
	
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70932,70987,70988) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70932,70987,70988) and o.value_boolean=1;
/* end of Mycose cutanée [111.9], */	


/* Entorse [848.9], précisez */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70935,70991,70992) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,112770,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70935,70991,70992) and o.value_boolean=1;
	
TRUNCATE TABLE itech.precisez;
 INSERT INTO itech.precisez(obs_id,person_id,concept_id,encounter_id,location_id, value_coded)
 SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,
 openmrs.obs.concept_id,openmrs.obs.encounter_id, openmrs.obs.location_id, openmrs.obs.value_coded
 FROM openmrs.obs
 WHERE openmrs.obs.concept_id=1284
    AND openmrs.obs.value_coded=112770 
 GROUP BY openmrs.obs.person_id,encounter_id;
 
 UPDATE openmrs.obs ob, itech.obs ito, encounter c, itech.encounter e, itech.precisez ip
     SET ob.comments=ito.value_text
 WHERE c.uuid = e.encGuid
 AND e.siteCode = ito.location_id 
 AND e.encounter_id = ito.encounter_id
 AND ito.concept_id=70936 
 AND (ito.value_text <> '' AND ito.value_text is not null)
 AND ip.person_id=ob.person_id
 AND ip.concept_id=ob.concept_id
 AND ip.encounter_id=ob.encounter_id
 AND ip.location_id=ob.location_id
 AND ip.value_coded=ob.value_coded
 AND ip.concept_id=1284
 AND ip.value_coded=112770;		
	
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70935,70991,70992) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70935,70991,70992) and o.value_boolean=1;
/* end of Entorse [848.9], précisez */

/* Luxation [839.8], précisez */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159947,e.encounter_id,e.encounter_datetime,e.location_id,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id in (70937,70993,70994) and o.value_boolean=1;

delete from itech.obs_concept_group where 1;		
INSERT INTO itech.obs_concept_group (obs_id,person_id,concept_id,encounter_id)
SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,openmrs.obs.concept_id,openmrs.obs.encounter_id
FROM openmrs.obs
WHERE openmrs.obs.concept_id=159947 
GROUP BY openmrs.obs.person_id,encounter_id;
 
 /* name of the concept */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,1284,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,481,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70937,70993,70994) and o.value_boolean=1;
	
TRUNCATE TABLE itech.precisez;
 INSERT INTO itech.precisez(obs_id,person_id,concept_id,encounter_id,location_id, value_coded)
 SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,
 openmrs.obs.concept_id,openmrs.obs.encounter_id, openmrs.obs.location_id, openmrs.obs.value_coded
 FROM openmrs.obs
 WHERE openmrs.obs.concept_id=1284
    AND openmrs.obs.value_coded=481 
 GROUP BY openmrs.obs.person_id,encounter_id;
 
 UPDATE openmrs.obs ob, itech.obs ito, encounter c, itech.encounter e, itech.precisez ip
     SET ob.comments=ito.value_text
 WHERE c.uuid = e.encGuid
 AND e.siteCode = ito.location_id 
 AND e.encounter_id = ito.encounter_id
 AND ito.concept_id=70938 
 AND (ito.value_text <> '' AND ito.value_text is not null)
 AND ip.person_id=ob.person_id
 AND ip.concept_id=ob.concept_id
 AND ip.encounter_id=ob.encounter_id
 AND ip.location_id=ob.location_id
 AND ip.value_coded=ob.value_coded
 AND ip.concept_id=1284
 AND ip.value_coded=481;		
	
	
/* Confirmé,Suspecté */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159394,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159392,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70937,70993,70994) and o.value_boolean=1;

/* Primaire,Secondaire */	
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,obs_group_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,159946,e.encounter_id,e.encounter_datetime,e.location_id,og.obs_id,159943,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o,itech.obs_concept_group og
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and og.person_id=e.patient_id and e.encounter_id=og.encounter_id and
o.concept_id in (70937,70993,70994) and o.value_boolean=1;
/* Luxation [839.8], précisez */
	/* END OF IMPRESSIONS CLINIQUES/DIAGNOSTIQUES*/
	
	
	
/* CONDUITE A TENIR */
/*Support Nutritionel */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,161542,e.encounter_id,e.encounter_datetime,e.location_id,
case when o.value_numeric=1 then 1065
     when o.value_numeric=2 then 1066
	 else null
end,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71054 and o.value_numeric in (1,2);
	
TRUNCATE TABLE itech.precisez;
 INSERT INTO itech.precisez(obs_id,person_id,concept_id,encounter_id,location_id, value_coded)
 SELECT MAX(openmrs.obs.obs_id) as obs_id,openmrs.obs.person_id,
 openmrs.obs.concept_id,openmrs.obs.encounter_id, openmrs.obs.location_id, openmrs.obs.value_coded
 FROM openmrs.obs
 WHERE openmrs.obs.concept_id=161542
    AND openmrs.obs.value_coded=1065 
 GROUP BY openmrs.obs.person_id,encounter_id;
 
 UPDATE openmrs.obs ob, itech.obs ito, encounter c, itech.encounter e, itech.precisez ip
     SET ob.comments=ito.value_text
 WHERE c.uuid = e.encGuid
 AND e.siteCode = ito.location_id 
 AND e.encounter_id = ito.encounter_id
 AND ito.concept_id=71039 
 AND (ito.value_text <> '' AND ito.value_text is not null)
 AND ip.person_id=ob.person_id
 AND ip.concept_id=ob.concept_id
 AND ip.encounter_id=ob.encounter_id
 AND ip.location_id=ob.location_id
 AND ip.value_coded=ob.value_coded
 AND ip.concept_id=161542
 AND ip.value_coded=1065;
 
 /*Lait enrichi*/
  INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,5484,e.encounter_id,e.encounter_datetime,e.location_id,163404,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71034 and o.value_boolean=1;

 /*Préparation pour nourrissons (LM)*/
  INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,5484,e.encounter_id,e.encounter_datetime,e.location_id,5254,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71035 and o.value_boolean=1;

 /* Medica mamba */
  INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,5484,e.encounter_id,e.encounter_datetime,e.location_id,163394,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71036 and o.value_boolean=1;

 /* Ration sèche */
  INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,5484,e.encounter_id,e.encounter_datetime,e.location_id,161648,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71037 and o.value_boolean=1;

/* Autre, précisez */
 INSERT INTO obs(person_id,concept_id,encounter_id,obs_datetime,location_id,value_coded,comments,creator,date_created,uuid)
SELECT DISTINCT e.patient_id,5484,e.encounter_id,e.encounter_datetime,e.location_id,5622,o.value_text,1,e.date_created,UUID()
 FROM itech.encounter c, encounter e,itech.obs o
where e.uuid = c.encGuid and c.encounter_id=o.encounter_id and 
o.concept_id=71039 and o.value_text<>'';
	
 
/* END OF CONDUITE A TENIR */	
	
	
SET SQL_SAFE_UPDATES = 1;
 END$$
	DELIMITER ;