/* SAS Program COVID_19 
Cleveland Clinic and SAS Collaboarion

These models are only as good as their inputs. Input values for this type of model are very dynamic and may need to be evaluated across wide ranges and reevaluated as the epidemic progresses.  This work is currently defaulting to values for the population studied in the Cleveland Clinic and SAS collaboration.  You need to evaluate each parameter for your population of interest.

SAS and Cleveland Clinic are not responsible for any misuse of these techniques.
*/

/* directory path for files: COVID_19.sas (this file), libname store */
    %let homedir = /Local_Files/covid-19-sas/ccf;

/* the storage location for the MODEL_FINAL table and other output tables - when &ScenarioSource=BATCH */
    libname store "&homedir.";

/* Depending on which SAS products you have and which releases you have these options will turn components of this code on/off */
    %LET HAVE_SASETS = YES; /* YES implies you have SAS/ETS software, this enable the PROC MODEL methods in this code.  Without this the Data Step SIR model still runs */
    %LET HAVE_V151 = NO; /* YES implies you have products verison 15.1 (latest) and switches PROC MODEL to PROC TMODEL for faster execution */

/* User Interface Switches - these are used if you using the code within SAS Visual Analytics UI */
    %LET ScenarioSource = BATCH;
/* the following is specific to CCF coding and included prior to the %EasyRun Macro */
	libname DL_RA teradata server=tdprod1 database=DL_RiskAnalytics;
	libname DL_COV teradata server=tdprod1 database=DL_COVID;
	libname CovData '/sas/data/ccf_preprod/finance/sas/EA_COVID_19/CovidData';
	proc datasets lib=work kill;run;quit;

	proc sql; 
	connect to teradata(Server=tdprod1);
	create table CovData.PullRealCovid as select * from connection to teradata 

	(
	Select COVID_RESULT_V.*, DEP_STATE from DL_COVID.COVID_RESULT_V
	LEFT JOIN (SELECT DISTINCT COVID_FACT_V.patient_identifier,COVID_FACT_V.DEP_STATE from DL_COVID.COVID_FACT_V) dep_st
	on dep_st.patient_identifier = COVID_RESULT_V.patient_identifier
	WHERE COVIDYN = 'YES' and DEP_STATE='OH'and discharge_Cat in ('Inpatient','Discharged To Home');
	)

	;quit;
	PROC SQL;
	CREATE TABLE CovData.PullRealAdmitCovid AS 
	SELECT /* AdmitDate */
				(datepart(t1.HSP_ADMIT_DTTM)) FORMAT=Date9. AS AdmitDate, 
			/* COUNT_DISTINCT_of_patient_identi */
				(COUNT(DISTINCT(t1.patient_identifier))) AS TrueDailyAdmits, 
			/* SumICUNum_1 */
				(SUM(input(t1.ICU, 3.))) AS SumICUNum_1, 
			/* SumICUNum */
				(SUM(case when t1.ICU='YES' then 1
				else case when t1.ICU='1' then 1 else 0
				end end)) AS SumICUNum
		FROM CovData.PULLREALCOVID t1
		GROUP BY (CALCULATED AdmitDate);
	QUIT;
	PROC SQL;
	CREATE TABLE CovData.RealCovid_DischargeDt AS 
	SELECT /* COUNT_of_patient_identifier */
				(COUNT(t1.patient_identifier)) AS TrueDailyDischarges, 
			/* DischargDate */
				(datepart(t1.HSP_DISCH_DTTM)) FORMAT=Date9. AS DischargDate, 
			/* SUMICUDISCHARGE */
				(SUM(Case when t1.DISCHARGEICUYN ='YES' then 1
				else case when t1.DISCHARGEICUYN ='1' then 1
				else 0
				end end)) AS SUMICUDISCHARGE
		FROM CovData.PULLREALCOVID t1
		WHERE (CALCULATED DischargDate) NOT = .
		GROUP BY (CALCULATED DischargDate);
	QUIT;

%macro EasyRun(Scenario,IncubationPeriod,InitRecovered,RecoveryDays,doublingtime,Population,KnownAdmits,
                SocialDistancing,ISOChangeDate,SocialDistancingChange,ISOChangeDateTwo,SocialDistancingChangeTwo,
                ISOChangeDate3,SocialDistancingChange3,ISOChangeDate4,SocialDistancingChange4,
                MarketSharePercent,Admission_Rate,ICUPercent,VentPErcent,FatalityRate,
                plots=no,N_DAYS=365,DiagnosedRate=1.0,E=0,SIGMA=0.90,DAY_ZERO='13MAR2020'd,BETA_DECAY=0.0,
                ECMO_RATE=0.03,DIAL_RATE=0.05,HOSP_LOS=7,ICU_LOS=9,VENT_LOS=10,ECMO_LOS=6,DIAL_LOS=11);

    DATA INPUTS;
        FORMAT
            Scenario                    $200.     
            IncubationPeriod            BEST12.    
            InitRecovered               BEST12.  
            RecoveryDays                BEST12.    
            doublingtime                BEST12.    
            Population                  BEST12.    
            KnownAdmits                 BEST12.    
            SocialDistancing            BEST12.    
            ISOChangeDate               DATE9.    
            SocialDistancingChange      BEST12.    
            ISOChangeDateTwo            DATE9.    
            SocialDistancingChangeTwo   BEST12.    
            ISOChangeDate3              DATE9.    
            SocialDistancingChange3     BEST12.    
            ISOChangeDate4              DATE9.    
            SocialDistancingChange4     BEST12.    
            MarketSharePercent          BEST12.    
            Admission_Rate              BEST12.    
            ICUPercent                  BEST12.    
            VentPErcent                 BEST12.    
            FatalityRate                BEST12.   
            plots                       $3.
            N_DAYS                      BEST12.
            DiagnosedRate               BEST12.
            E                           BEST12.
            SIGMA                       BEST12.
            DAY_ZERO                    DATE9.
            BETA_DECAY                  BEST12.
            ECMO_RATE                   BEST12.
            DIAL_RATE                   BEST12.
            HOSP_LOS                    BEST12.
            ICU_LOS                     BEST12.
            VENT_LOS                    BEST12.
            ECMO_LOS                    BEST12.
            DIAL_LOS                    BEST12.
        ;
        LABEL
            Scenario                    =   "Scenario Name to be stored as a character variable, combined with automatically-generated ScenarioIndex to create a unique ID"
            IncubationPeriod            =   "Number of days by which to offset hospitalization from infection, effectively shifting utilization curves to the right"
            InitRecovered               =   "Initial number of Recovered patients, assumed to have immunity to future infection"
            RecoveryDays                =   "Number of days a patient is considered infectious (the amount of time it takes to recover or die)"
            doublingtime                =   "Baseline Infection Doubling Time without social distancing"
            Population                  =   "Number of people in region of interest, assumed to be well mixed and independent of other populations"
            KnownAdmits                 =   "Number of COVID-19 patients at hospital of interest at Day 0, used to calculate the assumed number of Day 0 Infections"
            SocialDistancing            =   "Baseline Social distancing (% reduction in social contact compared to normal activity)"
            ISOChangeDate               =   "Date of first change from baseline in social distancing parameter"
            SocialDistancingChange      =   "Second value of social distancing (% reduction in social contact compared to normal activity)"
            ISOChangeDateTwo            =   "Date of second change in social distancing parameter"
            SocialDistancingChangeTwo   =   "Third value of social distancing (% reduction in social contact compared to normal activity)"
            ISOChangeDate3              =   "Date of third change in social distancing parameter"
            SocialDistancingChange3     =   "Fourth value of social distancing (% reduction in social contact compared to normal activity)"
            ISOChangeDate4              =   "Date of fourth change in social distancing parameter"
            SocialDistancingChange4     =   "Fifth value of social distancing (% reduction in social contact compared to normal activity)"
            MarketSharePercent          =   "Anticipated share (%) of hospitalized COVID-19 patients in region that will be admitted to hospital of interest"
            Admission_Rate              =   "Percentage of Infected patients in the region who will be hospitalized"
            ICUPercent                  =   "Percentage of hospitalized patients who will require ICU"
            VentPErcent                 =   "Percentage of hospitalized patients who will require Ventilators"
            FatalityRate                =   "Percentage of hospitalized patients who will die"
            plots                       =   "YES/NO display plots in output"
            N_DAYS                      =   "Number of days to project"
            DiagnosedRate               =   "Factor to adjust admission_rate contributing to via MarketSharePercent I (see calculation for I)"
            E                           =   "Initial Number of Exposed (infected but not yet infectious)"
            SIGMA                       =   "Rate of latent individuals Exposed and transported to the infectious stage during each time period"
            DAY_ZERO                    =   "Date of the first COVID-19 case"
            BETA_DECAY                  =   "Factor (%) used for daily reduction of Beta"
            ECMO_RATE                   =   "Default percent of total admissions that need ECMO"
            DIAL_RATE                   =   "Default percent of admissions that need Dialysis"
            HOSP_LOS                    =   "Average Hospital Length of Stay"
            ICU_LOS                     =   "Average ICU Length of Stay"
            VENT_LOS                    =   "Average Vent Length of Stay"
            ECMO_LOS                    =   "Average ECMO Length of Stay"
            DIAL_LOS                    =   "Average DIAL Length of Stay"
        ;
        Scenario                    =   "&Scenario.";
        IncubationPeriod            =   &IncubationPeriod.;
        InitRecovered               =   &InitRecovered.;
        RecoveryDays                =   &RecoveryDays.;
        doublingtime                =   &doublingtime.;
        Population                  =   &Population.;
        KnownAdmits                 =   &KnownAdmits.;
        SocialDistancing            =   &SocialDistancing.;
        ISOChangeDate               =   &ISOChangeDate.;
        SocialDistancingChange      =   &SocialDistancingChange.;
        ISOChangeDateTwo            =   &ISOChangeDateTwo.;
        SocialDistancingChangeTwo   =   &SocialDistancingChangeTwo.;
        ISOChangeDate3              =   &ISOChangeDate3.;
        SocialDistancingChange3     =   &SocialDistancingChange3.;
        ISOChangeDate4              =   &ISOChangeDate4.;
        SocialDistancingChange4     =   &SocialDistancingChange4.;
        MarketSharePercent          =   &MarketSharePercent.;
        Admission_Rate              =   &Admission_Rate.;
        ICUPercent                  =   &ICUPercent.;
        VentPErcent                 =   &VentPErcent.;
        FatalityRate                =   &FatalityRate.;
        plots                       =   "&plots.";
        N_DAYS                      =   &N_DAYS.;
        DiagnosedRate               =   &DiagnosedRate.;
        E                           =   &E.;
        SIGMA                       =   &SIGMA.;
        DAY_ZERO                    =   &DAY_ZERO.;
        BETA_DECAY                  =   &BETA_DECAY.;
        ECMO_RATE                   =   &ECMO_RATE.;
        DIAL_RATE                   =   &DIAL_RATE.;
        HOSP_LOS                    =   &HOSP_LOS.;
        ICU_LOS                     =   &ICU_LOS.;
        VENT_LOS                    =   &VENT_LOS.;
        ECMO_LOS                    =   &ECMO_LOS.;
        DIAL_LOS                    =   &DIAL_LOS.;
    RUN;

    %IF &ScenarioSource = UI %THEN %DO;
        /* this session is only used for reading the SCENARIOS table in the global caslib when the UI is running the scenario */
        %LET PULLLIB=&CASSource.;
    %END;
    %ELSE %DO;
        %LET PULLLIB=store;
    %END;

    /* create an index, ScenarioIndex for this run by incrementing the max value of ScenarioIndex in SCENARIOS dataset */
        %IF %SYSFUNC(exist(&PULLLIB..scenarios)) %THEN %DO;
            PROC SQL noprint; select max(ScenarioIndex) into :ScenarioIndex_Base from &PULLLIB..scenarios where ScenarioSource="&ScenarioSource."; quit;
            /* this may be the first ScenarioIndex for the ScenarioSource - catch and set to 0 */
            %IF &ScenarioIndex_Base = . %THEN %DO; %LET ScenarioIndex_Base = 0; %END;
        %END;
        %ELSE %DO; %LET ScenarioIndex_Base = 0; %END;
        %LET ScenarioIndex = %EVAL(&ScenarioIndex_Base + 1);

    /* store all the macro variables that set up this scenario in SCENARIOS dataset */
        DATA SCENARIOS;
            set sashelp.vmacro(where=(scope='EASYRUN'));
            if name in ('SQLEXITCODE','SQLOBS','SQLOOPS','SQLRC','SQLXOBS','SQLXOPENERRS','SCENARIOINDEX_BASE','PULLLIB') then delete;
				ScenarioIndex=&ScenarioIndex.;
				ScenarioUser="&SYSUSERID.";
				ScenarioSource="&ScenarioSource.";
				ScenarioNameUnique=cats("&Scenario.",' (',ScenarioIndex,'-',"&SYSUSERID.",'-',"&ScenarioSource.",')');
            STAGE='INPUT';
        RUN;
        DATA INPUTS; 
            set INPUTS;
				ScenarioIndex=&ScenarioIndex.;
				ScenarioUser="&SYSUSERID.";
				ScenarioSource="&ScenarioSource.";
				ScenarioNameUnique=cats("&Scenario.",' (',ScenarioIndex,'-',"&SYSUSERID.",'-',"&ScenarioSource.",')');
            label ScenarioIndex="Unique Scenario ID";
        RUN;

        /* Calculate Parameters form Macro Inputs Here - these are repeated as comments at the start of each model phase below */
			* calculated parameters used in model post-processing;
				%LET HOSP_RATE = %SYSEVALF(&Admission_Rate. * &DiagnosedRate.);
				%LET ICU_RATE = %SYSEVALF(&ICUPercent. * &DiagnosedRate.);
				%LET VENT_RATE = %SYSEVALF(&VentPErcent. * &DiagnosedRate.);
			* calculated parameters used in models;
				%LET I = %SYSEVALF(&KnownAdmits. / 
											&MarketSharePercent. / 
												(&Admission_Rate. * &DiagnosedRate.));
				%LET GAMMA = %SYSEVALF(1 / &RecoveryDays.);
				%LET BETA = %SYSEVALF(((2 ** (1 / &doublingtime.) - 1) + &GAMMA.) / 
												&Population. * (1 - &SocialDistancing.));
				%LET BETAChange = %SYSEVALF(((2 ** (1 / &doublingtime.) - 1) + &GAMMA.) / 
												&Population. * (1 - &SocialDistancingChange.));
				%LET BETAChangeTwo = %SYSEVALF(((2 ** (1 / &doublingtime.) - 1) + &GAMMA.) / 
												&Population. * (1 - &SocialDistancingChangeTwo.));
				%LET BETAChange3 = %SYSEVALF(((2 ** (1 / &doublingtime.) - 1) + &GAMMA.) / 
												&Population. * (1 - &SocialDistancingChange3.));
				%LET BETAChange4 = %SYSEVALF(((2 ** (1 / &doublingtime.) - 1) + &GAMMA.) / 
												&Population. * (1 - &SocialDistancingChange4.));
				%LET R_T = %SYSEVALF(&BETA. / &GAMMA. * &Population.);
				%LET R_T_Change = %SYSEVALF(&BETAChange. / &GAMMA. * &Population.);
				%LET R_T_Change_Two = %SYSEVALF(&BETAChangeTwo. / &GAMMA. * &Population.);
				%LET R_T_Change_3 = %SYSEVALF(&BETAChange3. / &GAMMA. * &Population.);
				%LET R_T_Change_4 = %SYSEVALF(&BETAChange4. / &GAMMA. * &Population.);

        DATA SCENARIOS;
            set SCENARIOS sashelp.vmacro(in=i where=(scope='EASYRUN'));
            if name in ('SQLEXITCODE','SQLOBS','SQLOOPS','SQLRC','SQLXOBS','SQLXOPENERRS','SCENARIOINDEX_BASE','PULLLIB') then delete;
				ScenarioIndex=&ScenarioIndex.;
				ScenarioUser="&SYSUSERID.";
				ScenarioSource="&ScenarioSource.";
				ScenarioNameUnique=cats("&Scenario.",' (',ScenarioIndex,'-',"&SYSUSERID.",'-',"&ScenarioSource.",')');
            if i then STAGE='MODEL';
        RUN;
    /* Check to see if SCENARIOS (this scenario) has already been run before in SCENARIOS dataset */
        %GLOBAL ScenarioExist;
        %IF %SYSFUNC(exist(&PULLLIB..scenarios)) %THEN %DO;
            PROC SQL noprint;
                /* has this scenario been run before - all the same parameters and value - no more and no less */
                select count(*) into :ScenarioExist from
                    (select t1.ScenarioIndex, t2.ScenarioIndex, t2.ScenarioSource, t2.ScenarioUser
                        from 
                            (select *, count(*) as cnt 
                                from work.SCENARIOS
                                where name not in ('SCENARIO','SCENARIOINDEX_BASE','SCENARIONNAMEUNIQUE','SCENARIOINDEX','SCENARIOSOURCE','SCENARIOUSER','SCENPLOT','PLOTS')
                                group by ScenarioIndex, ScenarioSource, ScenarioUser) t1
                            join
                            (select * from &PULLLIB..SCENARIOS
                                where name not in ('SCENARIO','SCENARIOINDEX_BASE','SCENARIONNAMEUNIQUE','SCENARIOINDEX','SCENARIOSOURCE','SCENARIOUSER','SCENPLOT','PLOTS')) t2
                            on t1.name=t2.name and t1.value=t2.value and t1.STAGE=t2.STAGE
                        group by t1.ScenarioIndex, t2.ScenarioIndex, t2.ScenarioSource, t2.ScenarioUser, t1.cnt
                        having count(*) = t1.cnt)
                ; 
            QUIT;
        %END; 
        %ELSE %DO; 
            %LET ScenarioExist = 0;
        %END;

    /* recall an existing scenario to SASWORK if it matched */
        %GLOBAL ScenarioIndex_recall ScenarioSource_recall ScenarioUser_recall ScenarioNameUnique_recall;
        %IF &ScenarioExist = 0 %THEN %DO;
            PROC SQL noprint; select max(ScenarioIndex) into :ScenarioIndex from work.SCENARIOS; QUIT;
        %END;
        /*%ELSE %IF &PLOTS. = YES %THEN %DO;*/
        %ELSE %DO;
            /* what was a ScenarioIndex value that matched the requested scenario - store that in ScenarioIndex_recall ... */
            PROC SQL noprint; /* can this be combined with the similar code above that counts matching scenarios? */
				select t2.ScenarioIndex, t2.ScenarioSource, t2.ScenarioUser, t2.ScenarioNameUnique into :ScenarioIndex_recall, :ScenarioSource_recall, :ScenarioUser_recall, :ScenarioNameUnique_recall from
                    (select t1.ScenarioIndex, t2.ScenarioIndex, t2.ScenarioSource, t2.ScenarioUser, t2.ScenarioNameUnique
                        from 
                            (select *, count(*) as cnt 
                                from work.SCENARIOS
                                where name not in ('SCENARIO','SCENARIOINDEX_BASE','SCENARIONNAMEUNIQUE','SCENARIOINDEX','SCENARIOSOURCE','SCENARIOUSER','SCENPLOT','PLOTS')
                                group by ScenarioIndex) t1
                            join
                            (select * from &PULLLIB..SCENARIOS
                                where name not in ('SCENARIO','SCENARIOINDEX_BASE','SCENARIONNAMEUNIQUE','SCENARIOINDEX','SCENARIOSOURCE','SCENARIOUSER','SCENPLOT','PLOTS')) t2
                            on t1.name=t2.name and t1.value=t2.value and t1.STAGE=t2.STAGE
                        group by t1.ScenarioIndex, t2.ScenarioIndex, t2.ScenarioSource, t2.ScenarioUser, t1.cnt
                        having count(*) = t1.cnt)
                ;
            QUIT;
            /* pull the current scenario data to work for plots below */
            data work.MODEL_FINAL; set &PULLLIB..MODEL_FINAL; where ScenarioIndex=&ScenarioIndex_recall. and ScenarioSource="&ScenarioSource_recall." and ScenarioUser="&ScenarioUser_recall."; run;
            data work.FIT_PRED; set &PULLLIB..FIT_PRED; where ScenarioIndex=&ScenarioIndex_recall. and ScenarioSource="&ScenarioSource_recall." and ScenarioUser="&ScenarioUser_recall."; run;
            data work.FIT_PARMS; set &PULLLIB..FIT_PARMS; where ScenarioIndex=&ScenarioIndex_recall. and ScenarioSource="&ScenarioSource_recall." and ScenarioUser="&ScenarioUser_recall."; run;
            %LET ScenarioIndex = &ScenarioIndex_recall.;
        %END;

    /* Prepare to create request plots from input parameter plots= */
        %IF %UPCASE(&plots.) = YES %THEN %DO; %LET plots = YES; %END;
        %ELSE %DO; %LET plots = NO; %END;




	/* DATA STEP APPROACH FOR SIR */
		/* these are the calculations for variablez used from above:
			* calculated parameters used in model post-processing;
				%LET HOSP_RATE = %SYSEVALF(&Admission_Rate. * &DiagnosedRate.);
				%LET ICU_RATE = %SYSEVALF(&ICUPercent. * &DiagnosedRate.);
				%LET VENT_RATE = %SYSEVALF(&VentPErcent. * &DiagnosedRate.);
			* calculated parameters used in models;
				%LET I = %SYSEVALF(&KnownAdmits. / 
											&MarketSharePercent. / 
												(&Admission_Rate. * &DiagnosedRate.));
				%LET GAMMA = %SYSEVALF(1 / &RecoveryDays.);
				%LET BETA = %SYSEVALF(((2 ** (1 / &doublingtime.) - 1) + &GAMMA.) / 
												&Population. * (1 - &SocialDistancing.));
				%LET BETAChange = %SYSEVALF(((2 ** (1 / &doublingtime.) - 1) + &GAMMA.) / 
												&Population. * (1 - &SocialDistancingChange.));
				%LET BETAChangeTwo = %SYSEVALF(((2 ** (1 / &doublingtime.) - 1) + &GAMMA.) / 
												&Population. * (1 - &SocialDistancingChangeTwo.));
				%LET BETAChange3 = %SYSEVALF(((2 ** (1 / &doublingtime.) - 1) + &GAMMA.) / 
												&Population. * (1 - &SocialDistancingChange3.));
				%LET BETAChange4 = %SYSEVALF(((2 ** (1 / &doublingtime.) - 1) + &GAMMA.) / 
												&Population. * (1 - &SocialDistancingChange4.));
				%LET R_T = %SYSEVALF(&BETA. / &GAMMA. * &Population.);
				%LET R_T_Change = %SYSEVALF(&BETAChange. / &GAMMA. * &Population.);
				%LET R_T_Change_Two = %SYSEVALF(&BETAChangeTwo. / &GAMMA. * &Population.);
				%LET R_T_Change_3 = %SYSEVALF(&BETAChange3. / &GAMMA. * &Population.);
				%LET R_T_Change_4 = %SYSEVALF(&BETAChange4. / &GAMMA. * &Population.);
		*/
		/* If this is a new scenario then run it */
    	%IF &ScenarioExist = 0 %THEN %DO;
			DATA DS_SIR;
				FORMAT ModelType $30.DATE ADMIT_DATE DATE9. Scenarioname $30. ScenarioNameUnique $100.;		
				ModelType="DS - SIR";
				ScenarioName="&Scenario.";
				ScenarioIndex=&ScenarioIndex.;
				ScenarioUser="&SYSUSERID.";
				ScenarioSource="&ScenarioSource.";
				ScenarioNameUnique=cats("&Scenario.",' (',ScenarioIndex,'-',"&SYSUSERID.",'-',"&ScenarioSource.",')');
				LABEL HOSPITAL_OCCUPANCY="Hospital Occupancy" ICU_OCCUPANCY="ICU Occupancy" VENT_OCCUPANCY="Ventilator Utilization"
					ECMO_OCCUPANCY="ECMO Utilization" DIAL_OCCUPANCY="Dialysis Utilization";
				byinc = 0.1;
				DO DAY = 0 TO &N_DAYS. by byinc;
					IF DAY = 0 THEN DO;
						S_N = &Population. - (&I. / &DiagnosedRate.) - &InitRecovered.;
						I_N = &I./&DiagnosedRate.;
						R_N = &InitRecovered.;
						BETA = &BETA.;
						N = SUM(S_N, I_N, R_N);
					END;
					ELSE DO;
						BETA = LAG_BETA * (1- &BETA_DECAY.);
						S_N = LAG_S - (BETA * LAG_S * LAG_I)*byinc;
						I_N = LAG_I + (BETA * LAG_S * LAG_I - &GAMMA. * LAG_I)*byinc;
						R_N = LAG_R + (&GAMMA. * LAG_I)*byinc;
						N = SUM(S_N, I_N, R_N);
						SCALE = LAG_N / N;
						IF S_N < 0 THEN S_N = 0;
						IF I_N < 0 THEN I_N = 0;
						IF R_N < 0 THEN R_N = 0;
						S_N = SCALE*S_N;
						I_N = SCALE*I_N;
						R_N = SCALE*R_N;
					END;
					LAG_S = S_N;
					E_N = 0; LAG_E = E_N; /* placeholder for post-processing of SIR model */
					LAG_I = I_N;
					LAG_R = R_N;
					LAG_N = N;
					IF date = &ISOChangeDate. THEN BETA = &BETAChange.;
					ELSE IF date = &ISOChangeDateTwo. THEN BETA = &BETAChangeTwo.;
					ELSE IF date = &ISOChangeDate3. THEN BETA = &BETAChange3.;
					ELSE IF date = &ISOChangeDate4. THEN BETA = &BETAChange4.;
					LAG_BETA = BETA;
					IF abs(DAY - round(DAY,1)) < byinc/10 THEN DO;
				/* START: Common Post-Processing Across each Model Type and Approach */
					NEWINFECTED=LAG&IncubationPeriod(SUM(LAG(SUM(S_N,E_N)),-1*SUM(S_N,E_N)));
					IF NEWINFECTED < 0 THEN NEWINFECTED=0;
					HOSP = NEWINFECTED * &HOSP_RATE. * &MarketSharePercent.;
					ICU = NEWINFECTED * &ICU_RATE. * &MarketSharePercent. * &HOSP_RATE.;
					VENT = NEWINFECTED * &VENT_RATE. * &MarketSharePercent. * &HOSP_RATE.;
					ECMO = NEWINFECTED * &ECMO_RATE. * &MarketSharePercent. * &HOSP_RATE.;
					DIAL = NEWINFECTED * &DIAL_RATE. * &MarketSharePercent. * &HOSP_RATE.;
					Fatality = NEWINFECTED * &FatalityRate * &MarketSharePercent. * &HOSP_RATE.;
					MARKET_HOSP = NEWINFECTED * &HOSP_RATE.;
					MARKET_ICU = NEWINFECTED * &ICU_RATE. * &HOSP_RATE.;
					MARKET_VENT = NEWINFECTED * &VENT_RATE. * &HOSP_RATE.;
					MARKET_ECMO = NEWINFECTED * &ECMO_RATE. * &HOSP_RATE.;
					MARKET_DIAL = NEWINFECTED * &DIAL_RATE. * &HOSP_RATE.;
					Market_Fatality = NEWINFECTED * &FatalityRate. * &HOSP_RATE.;
					CUMULATIVE_SUM_HOSP + HOSP;
					CUMULATIVE_SUM_ICU + ICU;
					CUMULATIVE_SUM_VENT + VENT;
					CUMULATIVE_SUM_ECMO + ECMO;
					CUMULATIVE_SUM_DIAL + DIAL;
					Cumulative_sum_fatality + Fatality;
					CUMULATIVE_SUM_MARKET_HOSP + MARKET_HOSP;
					CUMULATIVE_SUM_MARKET_ICU + MARKET_ICU;
					CUMULATIVE_SUM_MARKET_VENT + MARKET_VENT;
					CUMULATIVE_SUM_MARKET_ECMO + MARKET_ECMO;
					CUMULATIVE_SUM_MARKET_DIAL + MARKET_DIAL;
					cumulative_Sum_Market_Fatality + Market_Fatality;
					CUMADMITLAGGED=ROUND(LAG&HOSP_LOS.(CUMULATIVE_SUM_HOSP),1) ;
					CUMICULAGGED=ROUND(LAG&ICU_LOS.(CUMULATIVE_SUM_ICU),1) ;
					CUMVENTLAGGED=ROUND(LAG&VENT_LOS.(CUMULATIVE_SUM_VENT),1) ;
					CUMECMOLAGGED=ROUND(LAG&ECMO_LOS.(CUMULATIVE_SUM_ECMO),1) ;
					CUMDIALLAGGED=ROUND(LAG&DIAL_LOS.(CUMULATIVE_SUM_DIAL),1) ;
					CUMMARKETADMITLAG=ROUND(LAG&HOSP_LOS.(CUMULATIVE_SUM_MARKET_HOSP));
					CUMMARKETICULAG=ROUND(LAG&ICU_LOS.(CUMULATIVE_SUM_MARKET_ICU));
					CUMMARKETVENTLAG=ROUND(LAG&VENT_LOS.(CUMULATIVE_SUM_MARKET_VENT));
					CUMMARKETECMOLAG=ROUND(LAG&ECMO_LOS.(CUMULATIVE_SUM_MARKET_ECMO));
					CUMMARKETDIALLAG=ROUND(LAG&DIAL_LOS.(CUMULATIVE_SUM_MARKET_DIAL));
					ARRAY FIXINGDOT _NUMERIC_;
					DO OVER FIXINGDOT;
						IF FIXINGDOT=. THEN FIXINGDOT=0;
					END;
					HOSPITAL_OCCUPANCY= ROUND(CUMULATIVE_SUM_HOSP-CUMADMITLAGGED,1);
					ICU_OCCUPANCY= ROUND(CUMULATIVE_SUM_ICU-CUMICULAGGED,1);
					VENT_OCCUPANCY= ROUND(CUMULATIVE_SUM_VENT-CUMVENTLAGGED,1);
					ECMO_OCCUPANCY= ROUND(CUMULATIVE_SUM_ECMO-CUMECMOLAGGED,1);
					DIAL_OCCUPANCY= ROUND(CUMULATIVE_SUM_DIAL-CUMDIALLAGGED,1);
					Deceased_Today = Fatality;
					Total_Deaths = Cumulative_sum_fatality;
					MedSurgOccupancy=Hospital_Occupancy-ICU_Occupancy;
					MARKET_HOSPITAL_OCCUPANCY= ROUND(CUMULATIVE_SUM_MARKET_HOSP-CUMMARKETADMITLAG,1);
					MARKET_ICU_OCCUPANCY= ROUND(CUMULATIVE_SUM_MARKET_ICU-CUMMARKETICULAG,1);
					MARKET_VENT_OCCUPANCY= ROUND(CUMULATIVE_SUM_MARKET_VENT-CUMMARKETVENTLAG,1);
					MARKET_ECMO_OCCUPANCY= ROUND(CUMULATIVE_SUM_MARKET_ECMO-CUMMARKETECMOLAG,1);
					MARKET_DIAL_OCCUPANCY= ROUND(CUMULATIVE_SUM_MARKET_DIAL-CUMMARKETDIALLAG,1);	
					Market_Deceased_Today = Market_Fatality;
					Market_Total_Deaths = cumulative_Sum_Market_Fatality;
					Market_MEdSurg_Occupancy=Market_Hospital_Occupancy-MArket_ICU_Occupancy;
					DATE = &DAY_ZERO. + round(DAY,1);
					ADMIT_DATE = SUM(DATE, &IncubationPeriod.);
					LABEL
						ADMIT_DATE = "Date of Admission"
						DATE = "Date of Infection"
						DAY = "Day of Pandemic"
						HOSP = "New Hospitalized Patients"
						HOSPITAL_OCCUPANCY = "Current Hospitalized Census"
						MARKET_HOSP = "New Region Hospitalized Patients"
						MARKET_HOSPITAL_OCCUPANCY = "Current Region Hospitalized Census"
						ICU = "New Hospital ICU Patients"
						ICU_OCCUPANCY = "Current Hospital ICU Census"
						MARKET_ICU = "New Region ICU Patients"
						MARKET_ICU_OCCUPANCY = "Current Region ICU Census"
						MedSurgOccupancy = "Current Hospital Medical and Surgical Census (non-ICU)"
						Market_MedSurg_Occupancy = "Current Region Medical and Surgical Census (non-ICU)"
						VENT = "New Hospital Ventilator Patients"
						VENT_OCCUPANCY = "Current Hospital Ventilator Patients"
						MARKET_VENT = "New Region Ventilator Patients"
						MARKET_VENT_OCCUPANCY = "Current Region Ventilator Patients"
						DIAL = "New Hospital Dialysis Patients"
						DIAL_OCCUPANCY = "Current Hospital Dialysis Patients"
						MARKET_DIAL = "New Region Dialysis Patients"
						MARKET_DIAL_OCCUPANCY = "Current Region Dialysis Patients"
						ECMO = "New Hospital ECMO Patients"
						ECMO_OCCUPANCY = "Current Hospital ECMO Patients"
						MARKET_ECMO = "New Region ECMO Patients"
						MARKET_ECMO_OCCUPANCY = "Current Region ECMO Patients"
						Deceased_Today = "New Hospital Mortality: Fatality=Deceased_Today"
						Fatality = "New Hospital Mortality: Fatality=Deceased_Today"
						Total_Deaths = "Cumulative Hospital Mortality"
						Market_Deceased_Today = "New Region Mortality"
						Market_Fatality = "New Region Mortality"
						Market_Total_Deaths = "Cumulative Region Mortality"
						N = "Region Population"
						S_N = "Current Susceptible Population"
						E_N = "Current Exposed Population"
						I_N = "Current Infected Population"
						R_N = "Current Recovered Population"
						NEWINFECTED = "New Infected Population"
						ModelType = "Model Type Used to Generate Scenario"
						SCALE = "Ratio of Previous Day Population to Current Day Population"
						ScenarioIndex = "Scenario ID: Order"
						ScenarioSource = "Scenario ID: Source (BATCH or UI)"
						ScenarioUser = "Scenario ID: User who created Scenario"
						ScenarioNameUnique = "Unique Scenario Name"
						Scenarioname = "Scenario Name"
						;
				/* END: Common Post-Processing Across each Model Type and Approach */
						OUTPUT;
					END;
				END;
				DROP LAG: BETA CUM: byinc;
			RUN;

			PROC APPEND base=work.MODEL_FINAL data=DS_SIR NOWARN FORCE; run;
			PROC SQL; drop table DS_SIR; QUIT;

		%END;

		%IF &PLOTS. = YES %THEN %DO;
			PROC SGPLOT DATA=work.MODEL_FINAL;
				where ModelType='DS - SIR' and ScenarioIndex=&ScenarioIndex.;
				TITLE "Daily Occupancy - Data Step SIR Approach";
				TITLE2 "Scenario: &Scenario., Initial R0: %SYSFUNC(round(&R_T.,.01)) with Initial Social Distancing of %SYSEVALF(&SocialDistancing.*100)%";
				TITLE3 "Adjusted R0 after %sysfunc(INPUTN(&ISOChangeDate., date10.), date9.): %SYSFUNC(round(&R_T_Change.,.01)) with Adjusted Social Distancing of %SYSEVALF(&SocialDistancingChange.*100)%";
				TITLE4 "Adjusted R0 after %sysfunc(INPUTN(&ISOChangeDateTwo., date10.), date9.): %SYSFUNC(round(&R_T_Change_Two.,.01)) with Adjusted Social Distancing of %SYSEVALF(&SocialDistancingChangeTwo.*100)%";
				TITLE5 "Adjusted R0 after %sysfunc(INPUTN(&ISOChangeDate3., date10.), date9.): %SYSFUNC(round(&R_T_Change_3.,.01)) with Adjusted Social Distancing of %SYSEVALF(&SocialDistancingChange3.*100)%";
				TITLE6 "Adjusted R0 after %sysfunc(INPUTN(&ISOChangeDate4., date10.), date9.): %SYSFUNC(round(&R_T_Change_4.,.01)) with Adjusted Social Distancing of %SYSEVALF(&SocialDistancingChange4.*100)%";
				SERIES X=DATE Y=HOSPITAL_OCCUPANCY / LINEATTRS=(THICKNESS=2);
				SERIES X=DATE Y=ICU_OCCUPANCY / LINEATTRS=(THICKNESS=2);
				SERIES X=DATE Y=VENT_OCCUPANCY / LINEATTRS=(THICKNESS=2);
				SERIES X=DATE Y=ECMO_OCCUPANCY / LINEATTRS=(THICKNESS=2);
				SERIES X=DATE Y=DIAL_OCCUPANCY / LINEATTRS=(THICKNESS=2);
				XAXIS LABEL="Date";
				YAXIS LABEL="Daily Occupancy";
			RUN;
			TITLE; TITLE2; TITLE3; TITLE4; TITLE5; TITLE6;
		%END;


    %IF &PLOTS. = YES %THEN %DO;
        /* if multiple models for a single scenarioIndex then plot them */
        PROC SQL noprint;
            select count(*) into :scenplot from (select distinct ModelType from work.MODEL_FINAL where ScenarioIndex=&ScenarioIndex.);
        QUIT;
        %IF &scenplot > 1 %THEN %DO;
            PROC SGPLOT DATA=work.MODEL_FINAL;
                where ScenarioIndex=&ScenarioIndex.;
                TITLE "Daily Hospital Occupancy - All Approaches";
                TITLE2 "Scenario: &Scenario., Initial R0: %SYSFUNC(round(&R_T.,.01)) with Initial Social Distancing of %SYSEVALF(&SocialDistancing.*100)%";
                TITLE3 "Adjusted R0 after %sysfunc(INPUTN(&ISOChangeDate., date10.), date9.): %SYSFUNC(round(&R_T_Change.,.01)) with Adjusted Social Distancing of %SYSEVALF(&SocialDistancingChange.*100)%";
                TITLE4 "Adjusted R0 after %sysfunc(INPUTN(&ISOChangeDateTwo., date10.), date9.): %SYSFUNC(round(&R_T_Change_Two.,.01)) with Adjusted Social Distancing of %SYSEVALF(&SocialDistancingChangeTwo.*100)%";
				TITLE5 "Adjusted R0 after %sysfunc(INPUTN(&ISOChangeDate3., date10.), date9.): %SYSFUNC(round(&R_T_Change_3.,.01)) with Adjusted Social Distancing of %SYSEVALF(&SocialDistancingChange3.*100)%";
				TITLE6 "Adjusted R0 after %sysfunc(INPUTN(&ISOChangeDate4., date10.), date9.): %SYSFUNC(round(&R_T_Change_4.,.01)) with Adjusted Social Distancing of %SYSEVALF(&SocialDistancingChange4.*100)%";
                SERIES X=DATE Y=HOSPITAL_OCCUPANCY / GROUP=MODELTYPE LINEATTRS=(THICKNESS=2);
                XAXIS LABEL="Date";
                YAXIS LABEL="Daily Occupancy";
            RUN;
            TITLE; TITLE2; TITLE3; TITLE4; TITLE5; TITLE6;
        %END;	
    %END;

    /* code to manage output tables in STORE and CAS table management (coming soon) */
        %IF &ScenarioExist = 0 %THEN %DO;

				/*CREATE FLAGS FOR DAYS WITH PEAK VALUES OF DIFFERENT METRICS*/
					PROC SQL;
						CREATE TABLE work.MODEL_FINAL AS
							SELECT MF.*, HOSP.PEAK_HOSPITAL_OCCUPANCY, ICU.PEAK_ICU_OCCUPANCY, VENT.PEAK_VENT_OCCUPANCY, 
								ECMO.PEAK_ECMO_OCCUPANCY, DIAL.PEAK_DIAL_OCCUPANCY, I.PEAK_I_N, FATAL.PEAK_FATALITY
							FROM work.MODEL_FINAL MF
								LEFT JOIN
									(SELECT *
										FROM (SELECT MODELTYPE, SCENARIONAMEUNIQUE, DATE, HOSPITAL_OCCUPANCY, 1 AS PEAK_HOSPITAL_OCCUPANCY
											FROM work.MODEL_FINAL
											GROUP BY 1, 2
											HAVING HOSPITAL_OCCUPANCY=MAX(HOSPITAL_OCCUPANCY)
											) 
										GROUP BY MODELTYPE, SCENARIONAMEUNIQUE
										HAVING DATE=MIN(DATE)
									) HOSP
									ON MF.MODELTYPE = HOSP.MODELTYPE
										AND MF.SCENARIONAMEUNIQUE = HOSP.SCENARIONAMEUNIQUE
										AND MF.DATE = HOSP.DATE
								LEFT JOIN
									(SELECT *
										FROM (SELECT MODELTYPE, SCENARIONAMEUNIQUE, DATE, ICU_OCCUPANCY, 1 AS PEAK_ICU_OCCUPANCY
											FROM work.MODEL_FINAL
											GROUP BY 1, 2
											HAVING ICU_OCCUPANCY=MAX(ICU_OCCUPANCY)
											) 
										GROUP BY MODELTYPE, SCENARIONAMEUNIQUE
										HAVING DATE=MIN(DATE)
									) ICU
									ON MF.MODELTYPE = ICU.MODELTYPE
										AND MF.SCENARIONAMEUNIQUE = ICU.SCENARIONAMEUNIQUE
										AND MF.DATE = ICU.DATE
								LEFT JOIN
									(SELECT *
										FROM (SELECT MODELTYPE, SCENARIONAMEUNIQUE, DATE, VENT_OCCUPANCY, 1 AS PEAK_VENT_OCCUPANCY
											FROM work.MODEL_FINAL
											GROUP BY 1, 2
											HAVING VENT_OCCUPANCY=MAX(VENT_OCCUPANCY)
										) 
										GROUP BY MODELTYPE, SCENARIONAMEUNIQUE
										HAVING DATE=MIN(DATE)
									) VENT
									ON MF.MODELTYPE = VENT.MODELTYPE
										AND MF.SCENARIONAMEUNIQUE = VENT.SCENARIONAMEUNIQUE
										AND MF.DATE = VENT.DATE
								LEFT JOIN
									(SELECT *
										FROM (SELECT MODELTYPE, SCENARIONAMEUNIQUE, DATE, ECMO_OCCUPANCY, 1 AS PEAK_ECMO_OCCUPANCY
											FROM work.MODEL_FINAL
											GROUP BY 1, 2
											HAVING ECMO_OCCUPANCY=MAX(ECMO_OCCUPANCY)
										) 
										GROUP BY MODELTYPE, SCENARIONAMEUNIQUE
										HAVING DATE=MIN(DATE)
									) ECMO
									ON MF.MODELTYPE = ECMO.MODELTYPE
										AND MF.SCENARIONAMEUNIQUE = ECMO.SCENARIONAMEUNIQUE
										AND MF.DATE = ECMO.DATE
								LEFT JOIN
									(SELECT * FROM
										(SELECT MODELTYPE, SCENARIONAMEUNIQUE, DATE, DIAL_OCCUPANCY, 1 AS PEAK_DIAL_OCCUPANCY
											FROM work.MODEL_FINAL
											GROUP BY 1, 2
											HAVING DIAL_OCCUPANCY=MAX(DIAL_OCCUPANCY)
										) 
										GROUP BY MODELTYPE, SCENARIONAMEUNIQUE
										HAVING DATE=MIN(DATE)
									) DIAL
									ON MF.MODELTYPE = DIAL.MODELTYPE
										AND MF.SCENARIONAMEUNIQUE = DIAL.SCENARIONAMEUNIQUE
										AND MF.DATE = DIAL.DATE
								LEFT JOIN
									(SELECT *
										FROM (SELECT MODELTYPE, SCENARIONAMEUNIQUE, DATE, I_N, 1 AS PEAK_I_N
											FROM work.MODEL_FINAL
											GROUP BY 1, 2
											HAVING I_N=MAX(I_N)
										) 
										GROUP BY MODELTYPE, SCENARIONAMEUNIQUE
										HAVING DATE=MIN(DATE)
									) I
									ON MF.MODELTYPE = I.MODELTYPE
										AND MF.SCENARIONAMEUNIQUE = I.SCENARIONAMEUNIQUE
										AND MF.DATE = I.DATE
								LEFT JOIN
									(SELECT *
										FROM (SELECT MODELTYPE, SCENARIONAMEUNIQUE, DATE, FATALITY, 1 AS PEAK_FATALITY
											FROM work.MODEL_FINAL
											GROUP BY 1, 2
											HAVING FATALITY=MAX(FATALITY)
										) 
										GROUP BY MODELTYPE, SCENARIONAMEUNIQUE
										HAVING DATE=MIN(DATE)
									) FATAL
									ON MF.MODELTYPE = FATAL.MODELTYPE
										AND MF.SCENARIONAMEUNIQUE = FATAL.SCENARIONAMEUNIQUE
										AND MF.DATE = FATAL.DATE
							ORDER BY SCENARIONAMEUNIQUE, MODELTYPE, DATE;
					QUIT;
            /* CCF specific post-processing of MODEL_FINAL */
            /*pull real COVID admits and ICU*/
                proc sql; 
                    create table work.MODEL_FINAL as select t1.*,t2.TrueDailyAdmits, t2.SumICUNum
                        from work.MODEL_FINAL t1 left join CovData.PullRealAdmitCovid t2 on (t1.Date=t2.AdmitDate);
                    create table work.MODEL_FINAL as select t1.*,t2.TrueDailyDischarges, t2.SumICUDISCHARGE as SumICUNum_Discharge
                        from work.MODEL_FINAL t1 left join CovData.RealCovid_DischargeDt t2 on (t1.Date=t2.DischargDate);
                quit;

                data work.MODEL_FINAL;
                    set work.MODEL_FINAL;
                    *format Scenarioname $550.;
                    format INPUT_Social_DistancingCombo $90.;
                    *ScenarioName="&Scenario";
                    CumSumTrueAdmits + TrueDailyAdmits;
                    CumSumTrueDischarges + TrueDailyDischarges;
                    CumSumICU + SumICUNum;
                    CumSumICUDischarge + SumICUNum_Discharge;


                    True_CCF_Occupancy=CumSumTrueAdmits-CumSumTrueDischarges;

                    TrueCCF_ICU_Occupancy=CumSumICU-CumSumICUDischarge;
                    /*day logic for tableau views*/
                    if date>(today()-3) then Hospital_Occupancy_PP=Hospital_Occupancy; else Hospital_Occupancy_PP=.;
                    if date>(today()-3) then ICU_Occupancy_PP=ICU_Occupancy; else ICU_Occupancy_PP=.;
                    if date>(today()-3) then Vent_Occupancy_PP=Vent_Occupancy; else Vent_Occupancy_PP=.;
                    if date>(today()-3) then ECMO_Occupancy_PP=ECMO_Occupancy; else ECMO_Occupancy_PP=.;
                    if date>(today()-3) then DIAL_Occupancy_PP=DIAL_Occupancy; else DIAL_Occupancy_PP=.;

                    if date>today() then True_CCF_Occupancy=.;
                    if date>today() then TrueCCF_ICU_Occupancy=.;

                    /*
                        INPUT_Geography="&GeographyInput";

                        INPUT_Recovery_Time				=&RecoveryDays;
                        INPUT_Doubling_Time				=&doublingtime;
                        INPUT_Starting_Admits			=&KnownAdmits;

                        INPUT_Population				=&Population;
                        INPUT_Social_DistancingCombo	="&SocialDistancing"||"/"||"&SocialDistancingChange"||"/"||"&SocialDistancingChangeTwo"||"/"||"&SocialDistancingChange3"||"/"||"&SocialDistancingChange4";
                        INPUT_Social_Distancing_Date	=Put(&dayZero,date9.) ||" - "|| put(&iso_change_date,date9.) ||" - "|| put(&iso_change_date_two,date9.) ||" - "|| put(&iso_change_date_3,date9.) ||" - "|| put(&iso_change_date_4,date9.);
                        INPUT_Market_Share				=&MarketSharePercent;
                        INPUT_Admit_Percent_of_Infected	=&Admission_Rate;
                        INPUT_ICU_Percent_of_Admits		=&ICUPercent;
                        INPUT_Vent_Percent_of_Admits	=&VentPErcent;
                    */
                    /*paste overarching scenario variables*/
                    /*
                        INPUT_Mortality_RateInput		=&DeathRt;

                        INPUT_Length_of_Stay			=&LOS; 
                        INPUT_ICU_LOS					=&ICULOS; 
                        INPUT_Vent_LOS					=&VENTLOS; 
                        INPUT_Ecmo_Percent_of_Admits	=&ecmoPercent; 
                        INPUT_Ecmo_LOS_Input			=&ecmolos;
                        INPUT_Dialysis_PErcent			=&DialysisPercent; 
                        INPUT_Dialysis_LOS				=&DialysisLOS;
                        INPUT_Time_Zero					=&day_Zero;
                    */
                run;

                %IF &ScenarioSource = BATCH %THEN %DO;
                
                    PROC APPEND base=store.MODEL_FINAL data=work.MODEL_FINAL NOWARN FORCE; run;
                    PROC APPEND base=store.SCENARIOS data=work.SCENARIOS; run;
                    PROC APPEND base=store.INPUTS data=work.INPUTS; run;
                    PROC APPEND base=store.FIT_PRED data=work.FIT_PRED; run;
                    PROC APPEND base=store.FIT_PARMS data=work.FIT_PARMS; run;

                    PROC SQL;
                        drop table work.MODEL_FINAL;
                        drop table work.SCENARIOS;
                        drop table work.INPUTS;
                        drop table work.FIT_PRED;
                        drop table work.FIT_PARMS;
                    QUIT;

                %END;

        %END;
        /*%ELSE %IF &PLOTS. = YES %THEN %DO;*/
        %ELSE %DO;
            %IF &ScenarioSource = BATCH %THEN %DO;
                PROC SQL; 
                    drop table work.MODEL_FINAL;
                    drop table work.SCENARIOS;
                    drop table work.INPUTS; 
                    drop table work.FIT_PRED;
                    drop table work.FIT_PARMS;
                QUIT;
            %END;
        %END;
%mend;



/* Scenarios can be run in batch by specifying them in a sas dataset.
    In the example below, this dataset is created by reading scenarios from an csv file: run_scenarios.csv
    An example run_scenarios.csv file is provided with this code.

	IMPORTANT NOTES: 
		The example run_scenarios.csv file has columns for all the positional macro variables.  
		There are even more keyword parameters available.
			These need to be set for your population.
			They can be reviewed within the %EasyRun macro at the very top.
		THEN:
			you can set fixed values for the keyword parameters in the %EasyRun definition call
			OR
			you can add columns for the keyword parameters to this input file

	You could also use other files as input sources.  For example, with an excel file you could use libname XLSX.
*/
%macro run_scenarios(ds);
	/* import file */
	PROC IMPORT DATAFILE="&homedir./&ds."
		DBMS=CSV
		OUT=run_scenarios
		REPLACE;
		GETNAMES=YES;
	RUN;
	/* extract column names into space delimited string stored in macro variable &names */
	PROC SQL noprint;
		select name into :names separated by ' '
	  		from dictionary.columns
	  		where memname = 'RUN_SCENARIOS';
		select name into :dnames separated by ' '
	  		from dictionary.columns
	  		where memname = 'RUN_SCENARIOS' and substr(format,1,4)='DATE';
	QUIT;
	/* change date variables to character and of the form 'ddmmmyyyy'd */
	%DO i = 1 %TO %sysfunc(countw(&dnames.));
		%LET dname = %scan(&dnames,&i);
		data run_scenarios(drop=x);
			set run_scenarios(rename=(&dname.=x));
			&dname.="'"||put(x,date9.)||"'d";
		run;
	%END;
	/* build a call to %EasyRun for each row in run_scenarios */
	%GLOBAL cexecute;
	%DO i=1 %TO %sysfunc(countw(&names.));
		%LET next_name = %scan(&names, &i);
		%IF &i = 1 %THEN %DO;
			%LET cexecute = "&next_name.=",&next_name.; 
		%END;
		%ELSE %DO;
			%LET cexecute = &cexecute ,", &next_name.=",&next_name;
		%END;
	%END;
%mend;

%run_scenarios(run_scenarios.csv);
	/* use the &cexecute variable and the run_scenario dataset to run all the scenarios with call execute */
	data _null_;
		set run_scenarios;
		call execute(cats('%nrstr(%EasyRun(',&cexecute.,'));'));
	run;