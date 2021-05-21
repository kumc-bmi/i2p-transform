# Usage
 
Before running `prep_data_views.sas`, a file or link needs to be established for database configuration:

For postgres:

```
ln -s pg_config.sas config.sas
```

For oracle:

```
ln -s oracle_config.sas config.sas
```

Do not check `config.sas` into version control.

If using postgres, the following are fetched from environment variables:

- `PGHOST`: see postgres documentation if needed
- `PGUSER`
- `PGPASSWORD`
- `PGDATABASE`
- `cdm_working_dir`: this should be the full path to the "dsv" directory under the unzipped cdm project directory.  For example, `/home/nhensel/sas/scratch/PROD_P02_DQA_FDPRO_DCQ_NSD_q601_v01/dsv`.

Then to run the data view prep task:

```
sas prep_data_views.sas
```
