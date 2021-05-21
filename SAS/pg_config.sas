* postgres datasource configuration;
libname oracdata postgres server=%sysget(PGHOST) port=5432 user=%sysget(PGUSER) password=%sysget(PGPASSWORD) database=%sysget(PGDATABASE) schema=cdm60_build conopts="sslmode=require";
libname sasdata %sysget(cdm_working_dir);
