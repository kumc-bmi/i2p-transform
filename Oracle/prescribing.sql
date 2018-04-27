/** prescribing - create and populate the prescribing table.
*/
alter session set current_schema = pcornet_cdm;  -- @@@@

BEGIN
PMN_DROPSQL('DROP TABLE prescribing');
END;
/
CREATE TABLE prescribing(
	PRESCRIBINGID varchar(19)  primary key,
	PATID varchar(50) NOT NULL,
	ENCOUNTERID  varchar(50) NULL,
	RX_PROVIDERID varchar(50) NULL, -- NOTE: The spec has a _ before the ID, but this is inconsistent.
	RX_ORDER_DATE date NULL,
	RX_ORDER_TIME varchar (5) NULL,
	RX_START_DATE date NULL,
	RX_END_DATE date NULL,
	RX_QUANTITY number(18,5) NULL,
    RX_QUANTITY_UNIT varchar(2) NULL,
	RX_REFILLS number(18,5) NULL,
	RX_DAYS_SUPPLY number (18,5) NULL,
	RX_FREQUENCY varchar(2) NULL,
	RX_BASIS varchar (2) NULL,
	RXNORM_CUI varchar(8) NULL,
	RAW_RX_MED_NAME varchar (50) NULL,
	RAW_RX_FREQUENCY varchar (50) NULL,
    RAW_RX_QUANTITY varchar(50) NULL,
    RAW_RX_NDC varchar(50) NULL,
	RAW_RXNORM_CUI varchar (50) NULL
)
/

BEGIN
PMN_DROPSQL('DROP sequence  prescribing_seq');
END;
/
create sequence  prescribing_seq cache 2000
/


/** prescribing_key -- one row per order (inpatient or outpatient)

Design note on modifiers:
create or replace view rx_mod_design as
  select c_basecode
  from blueheronmetadata.pcornet_med
  -- TODO: fix pcornet_mapping.csv
  where c_fullname like '\PCORI_MOD\RX_BASIS\PR\_%'
  and c_basecode not in ('MedObs:PRN',   -- that's a supplementary flag, not a basis
                         'MedObs:Other'  -- that's as opposed to Historical; not same category as Inpatient, Outpatient
                         )
  and c_basecode not like 'RX_BASIS:%'
;

select case when (
  select listagg(c_basecode, ',') within group (order by c_basecode) modifiers
  from rx_mod_design
  ) = 'MedObs:Inpatient,MedObs:Outpatient'
then 1 -- pass
else 1/0 -- fail
end modifiers_as_expected
from dual
;
*/
drop table prescribing_key;  -- @@@

create table prescribing_key as
select prescribing_seq.nextval prescribingid
, instance_num
, patient_num
, encounter_num
, provider_id
, start_date
, end_date
, concept_cd
, modifier_cd
from blueherondata.observation_fact rx
where rx.modifier_cd in ('MedObs:Inpatient', 'MedObs:Outpatient') ;

select * from prescribing_key;  -- @@@
--     23,445 in STAGEDEV
-- 39,154,835 in BHERONA1@@

create unique index prescribing_key_ix on prescribing_key (concept_cd, instance_num);

/** prescribing_w_cui

take care with cardinalities...

select count(distinct c_name), c_basecode
from pcornet_med
group by c_basecode, c_name
having count(distinct c_name) > 1
order by c_basecode
;
*/
create table prescribing_w_cui as
select rx.*
, mo.pcori_cui rxnorm_cui
, substr(mo.c_basecode, 1, 50) raw_rxnorm_cui
, substr(mo.c_name, 1, 50) raw_rx_med_name
from prescribing_key rx
join
  (select distinct c_basecode
  , c_name
  , pcori_cui
  from pcornet_med
  ) mo
on rx.concept_cd = mo.c_basecode ;


drop table prescribing_w_refills;

/** prescribing_w_refills
This join isn't guaranteed not to introduce more rows,
but at least one measurement showed it does not.
 */
create table prescribing_w_refills as
select rx.*
, refills.nval_num rx_refills
from prescribing_w_cui rx
left join
  (select instance_num
  , concept_cd
  , nval_num
  from blueherondata.observation_fact
  where modifier_cd = 'RX_REFILLS'
    /* aka:
    select c_basecode from pcornet_med refillscode
    where refillscode.c_fullname = '\PCORI_MOD\RX_REFILLS\' */
  ) refills on refills.instance_num = rx.instance_num and refills.concept_cd = rx.concept_cd;
select * from prescribing_w_refills;


drop table prescribing; -- wrap@@

create table prescribing as
select rx.prescribingid
, rx.patient_num patid
, rx.encounter_num encounterid
, provider_id rx_providerid
, trunc(start_date) rx_order_date
, to_char(rx.start_date, 'HH24:MI') rx_order_time
, trunc(start_date) rx_start_date
, trunc(end_date) rx_end_date
-- RX_QUANTITY
, 'NI' RX_QUANTITY_UNIT
, rx.rx_refills
-- RX_DAYS_SUPPLY number (18,5) NULL,
--	RX_FREQUENCY varchar(2) NULL,
, decode(rx.modifier_cd, 'MedObs:Inpatient', '01', 'MedObs:Outpatient', '02') rx_basis
, rx.rxnorm_cui
, rx.raw_rx_med_name
-- RAW_RX_FREQUENCY
-- RAW_RX_QUANTITY
-- RAW_RX_NDC
, rx.RAW_RXNORM_CUI
/* ISSUE: HERON should have an actual order time.
   idea: store real difference between order date start data, possibly using the update date */
from prescribing_w_refills rx
;

begin
PMN_DROPSQL('DROP TABLE prescribing_transfer');
end;
/
create table prescribing_transfer as
select * from prescribing where 1 = 0
/

create or replace procedure PCORNetPrescribing as
begin

PMN_DROPSQL('drop index prescribing_idx');
PMN_DROPSQL('drop index basis_idx');
PMN_DROPSQL('drop index freq_idx');
PMN_DROPSQL('drop index quantity_idx');
PMN_DROPSQL('drop index refills_idx');
PMN_DROPSQL('drop index supply_idx');

execute immediate 'truncate table prescribing';
execute immediate 'truncate table basis';
execute immediate 'truncate table freq';
execute immediate 'truncate table quantity';
execute immediate 'truncate table refills';
execute immediate 'truncate table supply';

insert into basis
select pcori_basecode,c_fullname,instance_num,start_date,provider_id,concept_cd,encounter_num,modifier_cd
from i2b2medfact basis
inner join encounter enc on enc.patid = basis.patient_num and enc.encounterid = basis.encounter_Num
join pcornet_med basiscode
        on basis.modifier_cd = basiscode.c_basecode
        and basiscode.c_fullname like '\PCORI_MOD\RX_BASIS\%';

commit;

execute immediate 'create index basis_idx on basis (instance_num, start_date, provider_id, concept_cd, encounter_num, modifier_cd)';
GATHER_TABLE_STATS('BASIS');

insert into freq
select pcori_basecode,instance_num,start_date,provider_id,concept_cd,encounter_num,modifier_cd from i2b2medfact freq
        inner join encounter enc on enc.patid = freq.patient_num and enc.encounterid = freq.encounter_Num
     join pcornet_med freqcode
        on freq.modifier_cd = freqcode.c_basecode
        and freqcode.c_fullname like '\PCORI_MOD\RX_FREQUENCY\%';

commit;

execute immediate 'create index freq_idx on freq (instance_num, start_date, provider_id, concept_cd, encounter_num, modifier_cd)';
GATHER_TABLE_STATS('FREQ');

insert into quantity
select nval_num,instance_num,start_date,provider_id,concept_cd,encounter_num,modifier_cd from i2b2medfact quantity
        inner join encounter enc on enc.patid = quantity.patient_num and enc.encounterid = quantity.encounter_Num
     join pcornet_med quantitycode
        on quantity.modifier_cd = quantitycode.c_basecode
        and quantitycode.c_fullname like '\PCORI_MOD\RX_QUANTITY\';

commit;

execute immediate 'create index quantity_idx on quantity (instance_num, start_date, provider_id, concept_cd, encounter_num, modifier_cd)';
GATHER_TABLE_STATS('QUANTITY');

insert into refills
select nval_num,instance_num,start_date,provider_id,concept_cd,encounter_num,modifier_cd from i2b2medfact refills
        inner join encounter enc on enc.patid = refills.patient_num and enc.encounterid = refills.encounter_Num
     join pcornet_med refillscode
        on refills.modifier_cd = refillscode.c_basecode
        and refillscode.c_fullname like '\PCORI_MOD\RX_REFILLS\';

commit;

execute immediate 'create index refills_idx on refills (instance_num, start_date, provider_id, concept_cd, encounter_num, modifier_cd)';
GATHER_TABLE_STATS('REFILLS');

insert into supply
select nval_num,instance_num,start_date,provider_id,concept_cd,encounter_num,modifier_cd from i2b2medfact supply
        inner join encounter enc on enc.patid = supply.patient_num and enc.encounterid = supply.encounter_Num
     join pcornet_med supplycode
        on supply.modifier_cd = supplycode.c_basecode
        and supplycode.c_fullname like '\PCORI_MOD\RX_DAYS_SUPPLY\';

commit;

execute immediate 'create index supply_idx on supply (instance_num, start_date, provider_id, concept_cd, encounter_num, modifier_cd)';
GATHER_TABLE_STATS('SUPPLY');

insert /*+ append */ into prescribing_transfer (
	PATID, ENCOUNTERID, RX_PROVIDERID, RX_ORDER_DATE, RX_ORDER_TIME, RX_START_DATE, RX_END_DATE, RXNORM_CUI,
    RX_QUANTITY, RX_QUANTITY_UNIT, RX_REFILLS, RX_DAYS_SUPPLY, RX_FREQUENCY, RX_BASIS, RAW_RX_MED_NAME, RAW_RXNORM_CUI
)
    select /*+ use_nl(freq quantity supply refills) */
    m.patient_num PATID,
    m.Encounter_Num ENCOUNTERID,
    m.provider_id RX_PROVIDERID,
    m.start_date RX_ORDER_DATE,
    to_char(m.start_date,'HH24:MI') RX_ORDER_TIME,
    m.start_date RX_START_DATE,
    m.end_date RX_END_DATE,
    mo.pcori_cui RXNORM_CUI,
    quantity.nval_num RX_QUANTITY,
    'NI' RX_QUANTITY_UNIT,
    refills.nval_num RX_REFILLS,
    supply.nval_num RX_DAYS_SUPPLY,
    substr(freq.pcori_basecode, instr(freq.pcori_basecode, ':') + 1, 2) RX_FREQUENCY,
    substr(basis.pcori_basecode, instr(basis.pcori_basecode, ':') + 1, 2) RX_BASIS,
    substr(mo.c_name, 1, 50) RAW_RX_MED_NAME,
    substr(mo.c_basecode, 1, 50) RAW_RXNORM_CUI

    from i2b2medfact m inner join pcornet_med mo on m.concept_cd = mo.c_basecode
    inner join encounter enc on enc.encounterid = m.encounter_Num

    left join basis
    on m.encounter_num = basis.encounter_num
    and m.concept_cd = basis.concept_Cd
    and m.start_date = basis.start_date
    and m.provider_id = basis.provider_id
    and m.instance_num = basis.instance_num

    left join  freq
    on m.encounter_num = freq.encounter_num
    and m.concept_cd = freq.concept_Cd
    and m.start_date = freq.start_date
    and m.provider_id = freq.provider_id
    and m.instance_num = freq.instance_num

    left join quantity
    on m.encounter_num = quantity.encounter_num
    and m.concept_cd = quantity.concept_Cd
    and m.start_date = quantity.start_date
    and m.provider_id = quantity.provider_id
    and m.instance_num = quantity.instance_num

    left join refills
    on m.encounter_num = refills.encounter_num
    and m.concept_cd = refills.concept_Cd
    and m.start_date = refills.start_date
    and m.provider_id = refills.provider_id
    and m.instance_num = refills.instance_num

    left join supply
    on m.encounter_num = supply.encounter_num
    and m.concept_cd = supply.concept_Cd
    and m.start_date = supply.start_date
    and m.provider_id = supply.provider_id
    and m.instance_num = supply.instance_num

    where (basis.c_fullname is null or basis.c_fullname like '\PCORI_MOD\RX_BASIS\PR\%');

commit;

insert /*+ append */ into prescribing (
	PATID, ENCOUNTERID, RX_PROVIDERID, RX_ORDER_DATE, RX_ORDER_TIME, RX_START_DATE, RX_END_DATE, RXNORM_CUI,
    RX_QUANTITY, RX_QUANTITY_UNIT, RX_REFILLS, RX_DAYS_SUPPLY, RX_FREQUENCY, RX_BASIS, RAW_RX_MED_NAME, RAW_RXNORM_CUI
)
select distinct
    PATID, ENCOUNTERID, RX_PROVIDERID, RX_ORDER_DATE, RX_ORDER_TIME, RX_START_DATE, RX_END_DATE, RXNORM_CUI,
    RX_QUANTITY, RX_QUANTITY_UNIT, RX_REFILLS, RX_DAYS_SUPPLY, RX_FREQUENCY, RX_BASIS, RAW_RX_MED_NAME, RAW_RXNORM_CUI
from prescribing_transfer;

commit;

execute immediate 'create index prescribing_idx on prescribing (PATID, ENCOUNTERID)';
GATHER_TABLE_STATS('PRESCRIBING');

end PCORNetPrescribing;
/
BEGIN
PCORNetPrescribing();
END;
/
BEGIN
PMN_DROPSQL('DROP TABLE prescribing_transfer');
END;
/
insert into cdm_status (status, last_update, records) select 'prescribing', sysdate, count(*) from prescribing
/
select 1 from cdm_status where status = 'prescribing'