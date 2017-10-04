drop table pcornet_trial.pcornet_trial;

create table pcornet_trial.pcornet_trial as
select distinct pm.patient_num,cdm.trialid,cdm.participantid,cdm.trial_siteid,
cdm.trial_enroll_date + pd.date_shift as trial_enroll_date,cdm.trial_end_date + pd.date_shift as trial_end_date,
cdm.trial_withdraw_date + pd.date_shift as trial_withdraw_date,cdm.trial_invite_code from pcornet_trial.cdm@id cdm
left join schandaka.adaptableemails@id ae on cdm.trial_invite_code=ae.golden_ticket_code
join nightherondata.patient_mapping@id pm on pm.patient_ide=ae.pat_id
join nightherondata.patient_dimension@id pd on pd.patient_num=pm.patient_num;	
