insert into patient_identifier (patient_id,identifier,identifier_type,preferred,location_id,creator,date_created,uuid)
SELECT pt.patient_id, ident.identifier, (select patient_identifier_type_id from patient_identifier_type where name = "iSantePlus ID") as identifier_type, 1 as preferred, 1 as location_id, 1 as creator, NOW() as date_created, UUID() as uuid from patient pt
LEFT JOIN (SELECT id, identifier FROM idgen_log_entry WHERE identifier NOT IN (SELECT pid.identifier FROM patient_identifier pid, patient_identifier_type pit
 WHERE pid.identifier_type=pit.patient_identifier_type_id
 AND pit.uuid='05a29f94-c0ed-11e2-94be-8c13b969e334')) as ident
ON pt.patient_id = ident.id
where pt.patient_id NOT IN (select pid.patient_id from patient_identifier pid,patient_identifier_type p1 where p1.patient_identifier_type_id=pid.identifier_type and p1.name = "iSantePlus ID");
