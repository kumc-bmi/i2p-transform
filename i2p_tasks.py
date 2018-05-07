"""i2p_tasks -- Luigi CDM task support.
"""

from typing import List

import luigi
from sqlalchemy.engine import RowProxy
from sqlalchemy.exc import DatabaseError

from csv_load import LoadCSV
from etl_tasks import SqlScriptTask
from param_val import IntParam
from script_lib import Script
from sql_syntax import Environment, Params


class CDMScriptTask(SqlScriptTask):

    @property
    def variables(self) -> Environment:
        return dict(datamart_id='C4UK', datamart_name='University of Kansas', i2b2_data_schema='BLUEHERONDATA',
                    min_pat_list_date_dd_mon_rrrr='01-Jan-2010', min_visit_date_dd_mon_rrrr='01-Jan-2010',
                    i2b2_meta_schema='BLUEHERONMETADATA', enrollment_months_back='42', network_id='C4',
                    network_name='GPC', i2b2_etl_schema='HERON_ETL_3')


class condition(CDMScriptTask):
    script = Script.condition

    def requires(self) -> List[luigi.Task]:
        return [encounter()]


class death(CDMScriptTask):
    script = Script.death

    def requires(self) -> List[luigi.Task]:
        return [demographic()]


class death_cause(CDMScriptTask):
    script = Script.death_cause

    def requires(self) -> List[luigi.Task]:
        return [pcornet_init()]


class demographic(CDMScriptTask):
    script = Script.demographic

    def requires(self) -> List[luigi.Task]:
        return [pcornet_init()]


class diagnosis(CDMScriptTask):
    script = Script.diagnosis

    def requires(self) -> List[luigi.Task]:
        return [encounter()]


class dispensing(CDMScriptTask):
    script = Script.dispensing

    def requires(self) -> List[luigi.Task]:
        return [encounter()]


class encounter(CDMScriptTask):
    script = Script.encounter

    def requires(self) -> List[luigi.Task]:
        return [demographic()]


class enrollment(CDMScriptTask):
    script = Script.enrollment

    def requires(self) -> List[luigi.Task]:
        return [pcornet_init()]


class harvest(CDMScriptTask):
    script = Script.harvest

    def requires(self) -> List[luigi.Task]:
        return [condition(), death(), death_cause(), diagnosis(), dispensing(), enrollment(),
                lab_result_cm(), med_admin(), obs_clin(), obs_gen(), pcornet_trial(),
                prescribing(), pro_cm(), procedures(), provider(), vital()]


class lab_result_cm(CDMScriptTask):
    script = Script.lab_result_cm

    def requires(self) -> List[luigi.Task]:
        return [encounter()]


class med_admin(CDMScriptTask):
    script = Script.med_admin

    def requires(self) -> List[luigi.Task]:
        return [pcornet_init()]


class obs_clin(CDMScriptTask):
    script = Script.obs_clin


class obs_gen(CDMScriptTask):
    script = Script.obs_gen


class patient_chunks_survey(SqlScriptTask):
    script = Script.patient_chunks_survey
    patient_chunks = IntParam(default=200)
    patient_chunk_max = IntParam(default=None)

    def results(self) -> List[RowProxy]:
        with self.connection(event='survey results') as lc:
            q = '''
               select patient_num
                 , patient_num_qty
                 , patient_num_first
                 , patient_num_last
               from patient_chunks
               where chunk_qty = :chunk_qty
                 and (:chunk_max is null or
                      chunk_num <= :chunk_max)
               order by chunk_num
             '''
            Params
            params = dict(chunk_max=self.patient_chunk_max, chunk_qty=self.patient_chunks)  # type: Params

            try:
                return lc.execute(q, params=params).fetchall()
            except DatabaseError:
                return []


class pcornet_init(CDMScriptTask):
    script = Script.pcornet_init

    def requires(self) -> List[luigi.Task]:
        return [loadLabNormal(), loadHarvestLocal()]


class pcornet_loader(CDMScriptTask):
    script = Script.pcornet_loader

    def requires(self) -> List[luigi.Task]:
        return [harvest()]


class pcornet_trial(CDMScriptTask):
    script = Script.pcornet_trial

    def requires(self) -> List[luigi.Task]:
        return [pcornet_init()]


class prescribing(CDMScriptTask):
    script = Script.prescribing

    def requires(self) -> List[luigi.Task]:
        return [encounter()]


class pro_cm(CDMScriptTask):
    script = Script.pro_cm

    def requires(self) -> List[luigi.Task]:
        return [pcornet_init()]


class procedures(CDMScriptTask):
    script = Script.procedures

    def requires(self) -> List[luigi.Task]:
        return [encounter()]


class provider(CDMScriptTask):
    script = Script.provider


class vital(CDMScriptTask):
    script = Script.vital

    def requires(self) -> List[luigi.Task]:
        return [encounter()]


class loadLabNormal(LoadCSV):
    tablename = 'LABNORMAL'
    csvname = 'Oracle/labnormal.csv'


class loadHarvestLocal(LoadCSV):
    tablename = 'HARVEST_LOCAL'
    csvname = 'Oracle/harvest_local.csv'


class loadLanguage(LoadCSV):
    tablename = 'LANGUAGE_MAP'
    csvname = 'Oracle/language.csv'
