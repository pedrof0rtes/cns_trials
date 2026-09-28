-- Databricks notebook source
-- MAGIC %md
-- MAGIC ## 1. Mapping of MeSH terms to 31 diagnostic categories.
-- MAGIC

-- COMMAND ----------

-- Manual mapping

CREATE OR REPLACE TABLE cns_trials.`2_silver`.ref_mesh_disorder AS
SELECT 'Stroke and cerebrovascular disease' AS disorder, explode(array('Stroke','Ischemic Stroke','Hemorrhagic Stroke','Cerebrovascular Disorders','Brain Ischemia','Cerebral Infarction','Brain Infarction','Cerebral Hemorrhage','Intracranial Hemorrhages','Subarachnoid Hemorrhage','Ischemic Attack, Transient','Embolic Stroke','Stroke, Lacunar','Thrombotic Stroke','Infarction, Middle Cerebral Artery')) AS mesh_term
UNION ALL SELECT 'Depression', explode(array('Depression','Depressive Disorder, Major','Depressive Disorder','Depression, Postpartum','Depressive Disorder, Treatment-Resistant','Dysthymic Disorder','Seasonal Affective Disorder','Major Depressive Disorder 1'))
UNION ALL SELECT 'Anxiety', explode(array('Anxiety Disorders','Generalized Anxiety Disorder','Phobia, Social','Panic Disorder','Phobic Disorders','Agoraphobia','Phobia, Specific','Anxiety, Separation'))
UNION ALL SELECT 'Alzheimer disease and dementias', explode(array('Alzheimer Disease','Dementia','Neurocognitive Disorders','Lewy Body Disease','Frontotemporal Dementia','Dementia, Vascular','Pick Disease of the Brain','Aphasia, Primary Progressive','Mixed Dementias','Frontotemporal Lobar Degeneration','AIDS Dementia Complex','Primary Progressive Nonfluent Aphasia','Dementia, Multi-Infarct'))
UNION ALL SELECT 'Schizophrenia and psychoses', explode(array('Schizophrenia','Psychotic Disorders','Schizophrenia Spectrum and Other Psychotic Disorders','Schizophrenia, Treatment-Resistant','Schizophrenia, Paranoid','Affective Disorders, Psychotic','Schizophrenia, Childhood','Schizophrenia, Disorganized','Schizophrenia, Catatonic'))
UNION ALL SELECT 'Sleep disorders (excluding apnea)', explode(array('Sleep Initiation and Maintenance Disorders','Sleep Wake Disorders','Parasomnias','Restless Legs Syndrome','Disorders of Excessive Somnolence','Narcolepsy','Sleep Disorders, Circadian Rhythm','Chronobiology Disorders','REM Sleep Behavior Disorder','Idiopathic Hypersomnia','Dyssomnias','Cataplexy','Sleep Disorders, Intrinsic','Sleep Arousal Disorders'))
UNION ALL SELECT 'Cognitive impairment (generic)', explode(array('Cognitive Dysfunction','Cognition Disorders','Memory Disorders','Postoperative Cognitive Complications','Chemotherapy-Related Cognitive Impairment'))
UNION ALL SELECT 'Parkinson disease', explode(array('Parkinson Disease','Parkinsonian Disorders','Parkinson Disease, Secondary'))
UNION ALL SELECT 'Multiple sclerosis and demyelinating diseases', explode(array('Multiple Sclerosis','Multiple Sclerosis, Relapsing-Remitting','Multiple Sclerosis, Chronic Progressive','Neuromyelitis Optica','Demyelinating Diseases','Demyelinating Autoimmune Diseases, CNS','Myelin Oligodendrocyte Glycoprotein Antibody-Associated Disease'))
UNION ALL SELECT 'Other substance use and addiction (general)', explode(array('Substance-Related Disorders','Behavior, Addictive','Marijuana Abuse','Cocaine-Related Disorders','Gambling','Drug Overdose','Substance Withdrawal Syndrome','Amphetamine-Related Disorders','Substance Abuse, Intravenous','Marijuana Use','Drug Misuse','Internet Addiction Disorder','Marijuana Smoking','Prescription Drug Overuse','Prescription Drug Misuse','Cannabinoid Hyperemesis Syndrome'))
UNION ALL SELECT 'Traumatic brain injury', explode(array('Brain Injuries, Traumatic','Brain Injuries','Brain Concussion','Craniocerebral Trauma','Post-Concussion Syndrome','Head Injuries, Closed','Chronic Traumatic Encephalopathy','Brain Injury, Chronic','Brain Contusion','Head Injuries, Penetrating','Diffuse Axonal Injury','Brain Injuries, Diffuse'))
UNION ALL SELECT 'PTSD and trauma', explode(array('Stress Disorders, Post-Traumatic','Combat Disorders','Psychological Trauma','Stress Disorders, Traumatic','Stress Disorders, Traumatic, Acute','Trauma and Stressor Related Disorders'))
UNION ALL SELECT 'Headache and migraine', explode(array('Migraine Disorders','Headache','Post-Traumatic Headache','Headache Disorders','Tension-Type Headache','Cluster Headache','Migraine with Aura','Migraine without Aura','Headache Disorders, Secondary','Headache Disorders, Primary','Trigeminal Autonomic Cephalalgias','Vascular Headaches','Paroxysmal Hemicrania'))
UNION ALL SELECT 'Autism', explode(array('Autism Spectrum Disorder','Autistic Disorder','Child Development Disorders, Pervasive','Asperger Syndrome'))
UNION ALL SELECT 'Epilepsy', explode(array('Epilepsy','Drug Resistant Epilepsy','Epilepsies, Partial','Status Epilepticus','Epilepsies, Myoclonic','Lennox Gastaut Syndrome','Epilepsy, Temporal Lobe','Spasms, Infantile','Epilepsy, Generalized','Epilepsy, Absence','Epilepsy, Tonic-Clonic','Epilepsy, Rolandic','Sudden Unexpected Death in Epilepsy','Epilepsy, Idiopathic Generalized','Epilepsy, Complex Partial','Epilepsy, Post-Traumatic','Epilepsy, Reflex','Epileptic Syndromes'))
UNION ALL SELECT 'Spinal cord injury', explode(array('Spinal Cord Injuries','Quadriplegia','Paraplegia','Spinal Cord Diseases','Spinal Cord Compression','Autonomic Dysreflexia','Spinal Injuries','Central Cord Syndrome','Spinal Cord Ischemia'))
UNION ALL SELECT 'Alcohol', explode(array('Alcoholism','Alcohol Drinking','Alcohol-Related Disorders','Alcoholic Intoxication','Binge Drinking','Alcohol Abstinence','Alcohol Withdrawal Delirium','Underage Drinking','Alcohol Drinking in College','Alcohol-Induced Disorders','Alcohol-Induced Disorders, Nervous System'))
UNION ALL SELECT 'Tobacco', explode(array('Tobacco Use Disorder','Smoking Cessation','Smoking','Cigarette Smoking','Tobacco Use','Vaping','Tobacco Use Cessation','Tobacco Smoking','Smoking Reduction','Cigar Smoking','Water Pipe Smoking','Pipe Smoking'))
UNION ALL SELECT 'Movement disorders and tics', explode(array('Movement Disorders','Huntington Disease','Essential Tremor','Dystonia','Dyskinesias','Tremor','Dystonic Disorders','Tardive Dyskinesia','Chorea','Tourette Syndrome','Tic Disorders','Tics'))
UNION ALL SELECT 'ADHD', explode(array('Attention Deficit Disorder with Hyperactivity','Attention Deficit and Disruptive Behavior Disorders'))
UNION ALL SELECT 'Cerebral palsy', explode(array('Cerebral Palsy','Cerebral palsy, spastic, diplegic','Cerebral Palsy, Ataxic, Autosomal Recessive'))
UNION ALL SELECT 'Bipolar disorder', explode(array('Bipolar Disorder','Mania','Bipolar and Related Disorders','Cyclothymic Disorder'))
UNION ALL SELECT 'Eating disorders', explode(array('Feeding and Eating Disorders','Anorexia Nervosa','Binge-Eating Disorder','Bulimia Nervosa','Bulimia','Avoidant Restrictive Food Intake Disorder','Feeding and Eating Disorders of Childhood','Disordered Eating Behavior','Night Eating Syndrome','Pica'))
UNION ALL SELECT 'Opioids', explode(array('Opioid-Related Disorders','Heroin Dependence','Opiate Overdose','Narcotic-Related Disorders','Morphine Dependence','Opium Dependence'))
UNION ALL SELECT 'Delirium', explode(array('Delirium','Emergence Delirium'))
UNION ALL SELECT 'Neurodevelopmental disorders and intellectual disability', explode(array('Neurodevelopmental Disorders','Intellectual Disability','Developmental Disabilities','Learning Disabilities','Language Development Disorders','Dyslexia'))
UNION ALL SELECT 'ALS and motor neuron disease', explode(array('Amyotrophic Lateral Sclerosis','Motor Neuron Disease','Amyotrophic lateral sclerosis 1','Bulbar Palsy, Progressive','Amyotrophic Lateral Sclerosis 7'))
UNION ALL SELECT 'OCD and related disorders', explode(array('Obsessive-Compulsive Disorder','Body Dysmorphic Disorders','Trichotillomania','Hoarding Disorder','Compulsive Behavior','Excoriation Disorder','Hoarding','Obsessive Behavior'))
UNION ALL SELECT 'Suicidality and self-harm', explode(array('Suicidal Ideation','Suicide','Self-Injurious Behavior','Suicide, Attempted','Suicide Prevention','Self Mutilation'))
UNION ALL SELECT 'Personality disorders', explode(array('Borderline Personality Disorder','Personality Disorders','Antisocial Personality Disorder','Schizotypal Personality Disorder','Compulsive Personality Disorder','Passive-Aggressive Personality Disorder','Dependent Personality Disorder','Narcissistic Personality Disorder'))
UNION ALL SELECT 'Pain (excluding postoperative)', explode(array('Pain','Chronic Pain','Acute Pain','Fibromyalgia','Neuralgia','Neuralgia, Postherpetic','Trigeminal Neuralgia','Facial Neuralgia','Pudendal Neuralgia','Low Back Pain','Back Pain','Neck Pain','Shoulder Pain','Musculoskeletal Pain','Sciatica','Failed Back Surgery Syndrome','Complex Regional Pain Syndromes','Reflex Sympathetic Dystrophy','Causalgia','Hyperalgesia','Phantom Limb','Myofascial Pain Syndromes','Facial Pain','Nociceptive Pain','Nociplastic Pain','Visceral Pain','Pain, Intractable','Pain, Referred','Breakthrough Pain','Cancer Pain','Neuropathy, Painful','Pelvic Pain','Pain, Procedural','Labor Pain'))

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 2. Creating a study-disorder bridge table (final project scope).

-- COMMAND ----------

-- Bridge table study x disorder (defines the project scope)

CREATE OR REPLACE TABLE cns_trials.`2_silver`.study_disorder AS
WITH postop AS (
  SELECT DISTINCT nct_id
  FROM cns_trials.`1_bronze`.browse_conditions
  WHERE mesh_type = 'mesh-list' AND mesh_term = 'Pain, Postoperative'
)
SELECT DISTINCT b.nct_id, r.disorder
FROM cns_trials.`1_bronze`.browse_conditions b
JOIN cns_trials.`2_silver`.ref_mesh_disorder r ON b.mesh_term = r.mesh_term
JOIN cns_trials.`1_bronze`.studies s ON b.nct_id = s.nct_id
LEFT JOIN postop p ON b.nct_id = p.nct_id
WHERE b.mesh_type = 'mesh-list'
  AND s.study_type = 'INTERVENTIONAL'
  AND NOT (r.disorder = 'Pain (excluding postoperative)' AND p.nct_id IS NOT NULL)

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 3) Create refined 'studies' table.

-- COMMAND ----------

CREATE OR REPLACE TABLE cns_trials.`2_silver`.studies AS
WITH base AS (
  SELECT
    s.nct_id,
    upper(trim(s.overall_status))                     AS overall_status,
    NULLIF(trim(s.why_stopped), '')                   AS why_stopped,
    upper(trim(s.phase))                              AS phase,
    try_cast(s.start_date AS DATE)                    AS start_date,
    try_cast(s.completion_date AS DATE)               AS completion_date,
    upper(trim(s.completion_date_type))               AS completion_date_type,
    try_cast(s.primary_completion_date AS DATE)       AS primary_completion_date,
    try_cast(s.enrollment AS BIGINT)                  AS enrollment,
    upper(trim(s.enrollment_type))                    AS enrollment_type,
    CASE WHEN lower(trim(s.has_dmc)) IN ('true', 't', 'yes', 'y', '1') THEN true
         WHEN lower(trim(s.has_dmc)) IN ('false', 'f', 'no', 'n', '0') THEN false
         ELSE NULL END                                AS has_dmc,
    CASE WHEN lower(trim(s.is_fda_regulated_drug)) IN ('true', 't', 'yes', 'y', '1') THEN true
         WHEN lower(trim(s.is_fda_regulated_drug)) IN ('false', 'f', 'no', 'n', '0') THEN false
         ELSE NULL END                                AS is_fda_regulated_drug
  FROM cns_trials.`1_bronze`.studies s
  WHERE s.nct_id IN (SELECT nct_id FROM cns_trials.`2_silver`.study_disorder)
)
SELECT
  nct_id,
  overall_status,
 
  -- outcome of the study (analysis denominator = Completed, Terminated, Withdrawn)
  CASE overall_status
    WHEN 'COMPLETED'  THEN 'Completed'
    WHEN 'TERMINATED' THEN 'Terminated'
    WHEN 'WITHDRAWN'  THEN 'Withdrawn'
    ELSE 'Not final'
  END AS outcome_group,
 
  -- target variable: true = terminated or withdrawn, false = completed, null = not final (excluded)
  CASE WHEN overall_status IN ('TERMINATED', 'WITHDRAWN') THEN true
       WHEN overall_status = 'COMPLETED' THEN false
       ELSE NULL
  END AS early_termination,
 
  why_stopped,
 
  -- keyword classification of the free-text reason (first match wins, in this order)
    CASE
    WHEN overall_status NOT IN ('TERMINATED', 'WITHDRAWN', 'SUSPENDED') THEN NULL
    WHEN why_stopped IS NULL THEN 'Not reported'

    WHEN lower(why_stopped) RLIKE 'safety|adverse|toxic|death|harm|side.?effect|serious|mortality|hemorrhage|bleeding|respiratory (depression|insufficiency)|imbalance of .*events|increased incidence of|dsmb.*(safety|adverse|toxicity|increased incidence)|health risk|liver function|abnormalit(y|ies).*(higher than expected|test)|cardiac concern|progressive stroke|stroke in one arm|infection rate|wound infection' THEN 'Safety'

    WHEN lower(why_stopped) RLIKE 'efficac|futil|no benefit|lack of effect|ineffective|not effective|(interim|iterim)|did not meet|failed|no (visual |significant )?difference|insufficient data|incomplete data|benefit.?risk|risk.?benefit|preliminary results|parent study results|sufficient (data|patients?|subjects?|sample) to (evaluate|assess|determine|meet)|is sufficient to (evaluate|assess|determine)|sample size (achieved|reached|met|sufficient)|full sample size|(no|not|didn.?t show).*benefit|clearly identifiable benefit|demonstrated (clear |sufficient )?benefit|stopped (early )?for (efficacy|benefit)|too significant|results were too (significant|positive)|treatment.?failure|primary endpoint (was )?not (achieved|met|reached)|missed (its |the )?primary endpoint|endpoint not met|endpoint.*not met|not meeting (the )?(intended )?(primary|secondary) endpoint(s)?|stopping rule (was )?met|met the (pre-specified |predefined )?criteria for stopping|pre-specified criteria for stopping|follow.?up of the last patient|data.*not sufficient|dataset .*not strong enough|data .*not strong enough|main goals? achieved|goals? (were |was )?(achieved|met)|objectives? (were |was )?achieved|aim and objectives.*achieved|did not achieve (statistical )?significance|not achieve (statistical )?significance|low likelihood of.*significant|unlikely to (show|detect|achieve).*significan|difficulty controlling for confounding|confounding factors|showed significant improvement|significant improvement in (pain|symptoms?|outcome)|number of (analyzable |evaluable )?(patients?|subjects?).*(was |were )?reached|call(ed)? into question the viability|viability of the (substance|compound|drug) class|results? (would|will) not be conclusive|not (be )?conclusive|did not induce sufficient|failed to (induce|produce|elicit) sufficient|publication of (recent |other )?trials showing no effect|other trials (showed|showing) no effect|preliminary data showed.*not (a )?useful|not (a )?useful tool|not (be )?strong enough (for|to)|not efficient enough|no (apparent )?therapeutic effects?|(not )?superior to placebo|impacting the scientific rationale|compelling insights|halted to analyze data|halt(ed)? .*to analyze|not compliant (to|with).*(exercise|protocol)|non-compliance.*protocol|not clinically significant|null (results|findings)|low probability of meeting (its |the )?primary endpoint|not (yet )?covered sufficiently|not sufficiently covered|unexpected outcomes?|unexpected results?|effect (was )?(judged to be )?insufficient|not show sufficient improvement|insufficient improvement|will not have (statistical )?power|underpowered|not (have|has) (sufficient |adequate )?power|halted by (the )?(dsmb|dmc)|dsmb halted|dmc halted|dmc recommend(ation|ed) to discontinue|dsmb recommended (an )?end|did not show (a )?reason to continue|no reason to continue|did not (support|justify) conducting|results from cohort.*did not support|did not evidence as marker|not evidence as marker|would not (substantially )?add to|existing contributions in the literature|data (was |were )?higher (than|for)|higher for our standardized|not meeting primary objective' THEN 'Efficacy / futility'

    WHEN lower(why_stopped) RLIKE 'covid|pandemic|coronavirus|sars|corona(?!ry)|lockdown' THEN 'COVID-19'

    WHEN lower(why_stopped) RLIKE 'recruit|enrol|accru|participa|slow|inclusion|not enough (patients?|participants?|subjects?|sample)|too few (patients?|participants?|subjects?)|no patients?|no subjects?|lack of (additional )?patients?|lack of (additional )?subjects?|insufficient (patients?|subjects?|participants?|volunteers?)|insufficient recuirment|not enough viable (subjects?|patients?|participants?|candidates?)|limited (number|numbers) of (patients?|participants?|subjects?)|no eligible (subjects?|patients?|participants?)|no suitable (patients?|participants?|subjects?|candidates?)|no sufficient patients|inadequate (flow|number|numbers) of patients|unable to find (patients?|participants?|subjects?|volunteers?)|unable to identify (eligible|appropriate) (patients?|subjects?|participants?)|declined (to )?(participat|consent|enroll)|not enough sample|low number (met|meeting) (criteria|eligibility)|met criteria to randomize|low eligibility (rate)?|decrease (of|in) viable candidates|decrease in eligible (subjects?|patients?|candidates?)|decrease in refugee arrivals|difficult(y|ies) (to |in )?find(ing)?|difficult to (find|identify) (eligible|suitable)|only \d+ were eligible|could not be reached|lost to follow-?up|unable to (reach|contact) patients|impossible.*inclu|premier patient|target (number|enrollment|sample).{0,20}not (reached|met|achieved)|failure to (include|enroll|recruit) patients?|recruti?ng|recrutment|miss(ed)? contact|lost contact|not obtained (additional )?(subjects?|patients?)|did not obtain (additional )?(subjects|patients)|limited qualifying (patient )?population|small (eligible|qualifying) population|required number of (subjects?|patients?).{0,20}could not be (accomplished|achieved|reached)|impossible to reach.*(sample size|enrollment)|reduced access to.*(patients?|population)|drop-?out rate (was )?too high|high drop-?out|drop-?out patients are more than|low .*compliance|lack of compl[ai]ance|lower than anticipated|prevalence.*lower than|few .*(identified|met).*(criteria|eligib)|already (been |on )?prescribed|already receiving (the )?(treatment|medication)|inability to obtain (patients?|subjects?|participants?)|many patients missed|unable to keep patients (attending|coming)|low 5.year completer|low completer number' THEN 'Recruitment'

    -- placed before Funding so 'PI decision' / 'investigator decision' don't get
    -- caught by the generic 'decid' keyword below
    WHEN lower(why_stopped) RLIKE '(^|[^a-z])(pi|investigator|principal investigator|principle investigator)(.?s)? (decision|choice|discretion|request)|pi cited personal reasons|cited personal reasons' THEN 'Operational / logistics'

    WHEN lower(why_stopped) RLIKE 'fund|financ|finacial|budget|sponsor|spons?er|busi?ness|strateg|commercial|portfolio|priorit|cost|resource|ressources?|grant|money|corporate|company|industry|decid|administrative|stop development|program discontinued|discontinued (the )?development|discontinuation of (the )?.*(clinical )?development|termination of (the )?(clinical )?(program|programme)|halt(ed)? development|termination of development|product (terminated|discontinued|withdrawn)|program (objectives|goals)|overall program|study re-?design(ed)?|redesign(ed)? as a new (trial|study)|protoc[ao]l update|protoc[ao]l amendment|project name change|new (modified |revised |updated |dedicated )?protoc[ao]l|updated protoc[ao]l|rewritten|re-written|chapter 11|bankrupt|withdrawal of (support|funding|sponsorship|celgene)|withdrew (its |their )?support|withdrawn support|lack of support|overlapping stud(y|ies)|another (trial|study|rct) (on the same|started)|superc?s?eded? by (another|similar|nct)|replaced by (another|other) (study|trial|protocol|ntrp)|sub-?study of (nct)?\d|competing (study|trial)|outcome of (another |a )?(phase \d )?(trial|study)|stopped after the outcome of|research question answered by another|became lapsed|study lapsed|after results of other studies|shift in (research )?focus|focus.*has shifted|changes? in pipeline|revised development program|development plan (has been |was )?(updated|changed|amended|readjust\w*)|change in development plan|study design (was |is |has been )?(obsolete|changed)|design (was |is )?obsolete|made (this |the )?study obsolete|study (is |was |became )?obsolete|no longer align with (the )?(original )?protoc[ao]l|changes? in (its |the )?scope|will no longer be conducted|started a different project|no (more |longer )?interest (to|in) (follow|continue|pursu)|standard of care.*(now includes|changed)|change (on|in|to) (the )?standard of care|reassess(ed|ment) (the )?(phase \d )?(study )?indication|need (for )?a new version of the study|submitted as a (new |different )?protoc[ao]l|design changed significantly|significant changes.*(to|in) the protoc[ao]l|rollover study following|guideline.*changed.*dsmb recommended.*end|changes? in state policy|updated the evaluation plan|changed the direction (and aims )?of the study|aims of the study (were |was )?changed|a new trial should be designed|new (trial|study) (should|will|in planning|in place)|persuing larger|pursuing larger|multi-site (study|trial)|unafford(able|ability)|not valid anymore|no longer valid|no longer relevant|no longer consistent with|modified to a .*design|study modified to|collaborating with a new (community )?partner|new community partner|change (for|to) (a )?phase (i|ii|iii|iv|1|2|3|4) design|change in (the )?active comparator|phase (change|amendment)|modifications in methodology|methodology.*(had to be made|changed)|no need for a pilot study|new study will be opened|inform the start of a multi-site trial|written up as a pilot|data.*not critical to (the )?(continued )?evaluation|market dynamics|not viable\b|no longer viable\b|milestone(s)? (was |were )?not met|first milestone|internal desicions?|pivot(ed)?|re-?evaluation|required re-?evaluation|reconsideration of (the )?(study )?design|not moving forward( with)?|qi project|quality improvement project|non-randomized (qi|quality)|no longer randomized|drug being offered to all patients|plan to change the trial design|trial design.*plan to change|approvable decision|agency decision|medicines agency decision|rolled into (study )?(nct)?\d|is no longer required\b|delayed project onset|pilot data.*(collected at a later date|later date)' THEN 'Funding / business'

    WHEN lower(why_stopped) RLIKE 'feasib|faisab|logistic|operational|infrastructure|technical|staff|personnel|personel|manpower|supply|supplies|manufactur|unavailab|non-availab|not available|availab.*(drug|medication|device|solution|product|study)|delaying.*availab|drug availability|backorder|equipment|contract|trial agreement not executed|agreement not executed|clinical trial agreement|could not (come to|reach) an agreement|site closure|site closed|sites closed|clinics? (was |were )?closed|clos(e|ing) at (current |this )?site|site performance|poor performance|principal investigator|primary investigator|principle investigator|investigator (left|leaving|departure|départure|departed|transferred|moved|resigned|died|deceased|passed away|withdrawn)|d[ée]parture|pi (has )?(left|leaving|moved|withdrawn|died|deceased|passed away|resigned)|pi (is )?retir|pi,.*left|investigator,.*left|(pi|investigator) no longer at|pi no longer has an appointment|pi move\b|pi (changed|change) (hospital|institution|center)|pi terminated employment|pi unexpectedly passed away|study pi resigned|seperated from|separated from|researcher left|research(er)? (fellow )?(has )?graduated|left (the )?(institution|university|nih|hospital|va)|leav(e|ing) (the )?(institution|university|nih|hospital)|left for (an )?internship|quitt[ée]|investigateur.*quitt|retire|departure|relocat(ion|ing|e)|clos(e|ing|ed) (his |her |their )?lab|moved (abroad|to (another|a different) institution)|moved institutions|study moved to|material issues?|material problem|no intention to (initiate|start|continue)|did not want to (pursue|continue|proceed)|(did not|no longer) want(ed)? to (pursue|continue|proceed)|transferred to (another|a different) (university|institution|hospital|site)|transitioning to another institution|internal organi[sz]ation|organi[sz]ational issues|reorgani[sz]ation|no (research )?team (to conduct|available)|no practitioner|no (clinician|physician|nurse) available|no investigator (to|available)|no pi (to continue|available)|investigators? .*(limited availability)|no longer (being )?(made|manufactured|available|supported|produced)|(no|not) longer available|change of career|career change|changed institutions|no longer able to continue|no longer in the institution|research.*no longer (based |located )?(in|at) (the )?institution|foreign training|data (was |were )?not correctly collected|incorrectly collected|data collection (error|issue|problem)|discrepanc(y|ies) in .*(orders?|records?)|documents.*pending|no response despite|coordinator.*(pending|no response|moved|relocat)|moving of coordinator|not successful in securing|unable to secure|unable to obtain|could not obtain|difficulty (in )?obtaining|unable to acquire|not possible to acquire|securing the .*product|drug expired|expired (drug|medication|product|supply)|product expir|arrived (at |near )?expir|unable to perform .*(imaging|scan|procedure|assessment|test)|device (design )?modification|design modification|device evolves|device (has )?evolved|device not found to be adequate|devices? (were )?not suitable|issues? with device development|issue with (the )?software development|problems? (of|with) the .*(software|device)|software (intervention )?(problem|issue)|incompatible with .*(hardware|software|mri|ct|scanner|equipment)|mechanical issue with (the )?device|machine.*(damaged|broken|could not (fix|repair))|program closed|clinic closed|department closed|device implementation delayed|took longer than anticipated|implementation (was )?delayed|need(ed)? more time|did not have time|optimi[sz]e the (sensor|device|equipment|protoc[ao]l|software)|office delays|thesis|(phd |doctoral )?student (stopped working|left|stopped)|student study|end of (their |his |her )?course|too many constraints|time limitation|protoc[ao]l.*(too (long|complex|complicated|restrictive))|inadequate support|insufficient (study )?materials?|insufficient supplies|issues? with insurance|insurance (of|for) the (robot|device|equipment)|clinically impracticable|difficulties (about|with) the method|conflicts? at the (study )?site|time constraints|study did not start due to|unable to start up|unable to start the study|collaborator (got sick|is sick|fell ill)|loss of (team|staff) members|no longer have.*(coverage|access)|dietician|billing issues?|practice (moved|move) to another building|move(d)? to another building|war (in|the)|active war|military conflict|army reserve service|manpower (issue|shortage)|inactivity|not able to run research|unable to run (the )?(research|study) in|schedule issue|scheduling (issue|problem|conflict)|given permission.*to discontinue|withdrawn by (the )?pi\b|discontinued by (the )?(pi|investigator)|terminated by (the )?pis?\b|lapsed (institutional )?training|training lapsed|intraoperative recording could not be maintained|recording could not be maintained|workload.*(different institutions|difficult to gather)|different institutions.*(difficult|workload)|lack of bandwidth|accidental duplicate entry|duplicate entry into|collaborating investigator has moved' THEN 'Operational / logistics'

    WHEN lower(why_stopped) RLIKE 'regulatory|ethic|irb|approval|clinical hold|removed from.*market|market withdrawal|ce-certif|ce mark|did not require (a )?(clinical )?trial|institutional (research )?pause|research pause|agreed by (the )?fda|fda were satisfied|fda did not approve|not approved by (the )?(fda|cms|bfarm|ema|mhra|anvisa|health canada)|no further data (was |is )?required|per ct\.gov guidance|registry guidance|did not authori[sz]e|local authorit(y|ies) (did not|denied)|fwa restriction|no longer required for (the )?prea|prea (requirement|exemption)|did not obtain (an )?ind\b|failed to obtain ind|no ind\b|executive order|no response to (ec|irb|ethics committee) questions|ec questions|reb review|research ethics board|human subjects protection board|denied by (the )?(irb|ethics|human subjects)|registration of (the )?(medicine|drug|product) .*(no longer|not) (being )?pursued|drug registration|due to new guidelines|nih.*(guidelines|policy)|government restrictions|government polic|recall(ed)? by (the )?fda|fda recall|\brecall(ed)?\b' THEN 'Regulatory / ethics'

    -- text present but uninformative (pointer to description, status repeated, never started);
    -- placed last so texts that also give a real reason are classified by that reason
    WHEN lower(why_stopped) RLIKE 'detailed description|never (started|initiated|began|opened|commenced|sterted)|not (started|initiated)|prior to initiation|before initiation|^(terminated|withdrawn|termin.e)[.]?$|terminated/withdrawn|undefined|close-?out|cancell?ed|cancellation|abandon|discontinuation of the (trial|study)|early termination|created by mistake|entered? in error|data entry error|erroneously created|record error|duplicate record|placeholder|not going forward|halted prematurely|not considered a clinical trial|not really a clinical trial|doesn.?t meet.*criteria.*(clinicaltrials\.gov|ct\.gov)|new entry in clinicaltrials\.gov was created|modified and a new entry|apply for withdrawing|registed in .*apply for withdraw|decision to stop the study|compassionate use( program)?|no reason given|without (giving |providing )?(a )?reason|whole project was terminated|could not (get|start).*started|could not initiate|no site was initiated|site(s)? (was |were )?(never )?initiated|will not be (initiated|intiated)|no longer proceeding with this study|will not be pursued (as a viable opportunity)?|see nct\d+|current version of this study|please see nct|under review|not able to be completed|project has finished|concluded prematur(e)?ly|study was completed|study has been completed|^insufficient[.]?$|^not active[.]?$|^reason[.]?$|^investigator[.]?$|^(completed|study (has been )?completed)[.]?$' THEN 'Not reported'

    ELSE 'Other'
  END AS why_stopped_category,
 
  phase,
  CASE phase
    WHEN 'EARLY_PHASE1'   THEN 'Early Phase 1'
    WHEN 'PHASE1'         THEN 'Phase 1'
    WHEN 'PHASE1/PHASE2'  THEN 'Phase 1/2'
    WHEN 'PHASE2'         THEN 'Phase 2'
    WHEN 'PHASE2/PHASE3'  THEN 'Phase 2/3'
    WHEN 'PHASE3'         THEN 'Phase 3'
    WHEN 'PHASE4'         THEN 'Phase 4'
    WHEN 'NA'             THEN 'Not applicable'
    ELSE 'Unknown'
  END AS phase_group,
 
  start_date,
  YEAR(start_date) AS start_year,
  completion_date,
  completion_date_type,
  primary_completion_date,
 
  -- quality flag: completion before start (duration is not computed for these)
  COALESCE(completion_date < start_date, false) AS invalid_dates,
 
  -- duration in months (for Terminated studies = time until the study stopped, not planned duration)
  CASE WHEN completion_date >= start_date
       THEN ROUND(months_between(completion_date, start_date), 1) END AS duration_months,
 
  enrollment,
  enrollment_type,
  has_dmc,
  is_fda_regulated_drug
FROM base

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 4. Create, clean and filter child tables
-- MAGIC

-- COMMAND ----------

-- Child tables, cleaned and filtered to the project scope

CREATE OR REPLACE TABLE cns_trials.`2_silver`.design_groups
COMMENT 'Study arms (design groups) for studies in scope. group_type standardized to uppercase; null kept as null (unknown).'
AS
SELECT
  try_cast(id AS BIGINT)        AS id,
  nct_id,
  upper(NULLIF(trim(group_type), '')) AS group_type,
  NULLIF(trim(title), '')       AS title
FROM cns_trials.`1_bronze`.design_groups
WHERE nct_id IN (SELECT nct_id FROM cns_trials.`2_silver`.studies)

-- COMMAND ----------

CREATE OR REPLACE TABLE cns_trials.`2_silver`.design_outcomes
COMMENT 'Outcome measures for studies in scope. outcome_type uppercase (PRIMARY, SECONDARY, OTHER). time_frame kept as raw text. time_frame_months = longest time mentioned in time_frame, in months, capped at 120; null when no time can be extracted (no imputation).'
AS
WITH base AS (
  SELECT
    try_cast(id AS BIGINT)        AS id,
    nct_id,
    upper(NULLIF(trim(outcome_type), '')) AS outcome_type,
    NULLIF(trim(measure), '')     AS measure,
    NULLIF(trim(time_frame), '')  AS time_frame,
    -- text prepared for parsing: lowercase, age mentions removed ('aged 6-12 years', '25 years of age')
    regexp_replace(
      lower(NULLIF(trim(time_frame), '')),
      '(?<![a-z])aged? [0-9]+(?:-[0-9]+)? years?|(?<![a-z])ages? [0-9]+(?:-[0-9]+)?|[0-9]+(?:-[0-9]+)? years? (?:of age|old)',
      ' ') AS tf
  FROM cns_trials.`1_bronze`.design_outcomes
  WHERE nct_id IN (SELECT nct_id FROM cns_trials.`2_silver`.studies)
),
parsed AS (
  SELECT id, nct_id, outcome_type, measure, time_frame,
    array_max(concat(
      -- pattern A: '12 weeks', '6-month', '0.5 hour' (number before the unit;
      -- the number is not preceded by letters/digits, e.g. study codes, nor by another unit, e.g. 'week 25 year 1')
      zip_with(
        regexp_extract_all(tf, '(?<![a-z0-9.])(?<!week |weeks |day |days |month |months |year |years )([0-9]+(?:[.][0-9]+)?) *-? *(minute|hour|day|week|month|year)', 1),
        regexp_extract_all(tf, '(?<![a-z0-9.])(?<!week |weeks |day |days |month |months |year |years )([0-9]+(?:[.][0-9]+)?) *-? *(minute|hour|day|week|month|year)', 2),
        (n, u) -> CAST(n AS DOUBLE) * CASE u WHEN 'minute' THEN 1/43830.0 WHEN 'hour' THEN 1/730.5 WHEN 'day' THEN 1/30.4375 WHEN 'week' THEN 7/30.4375 WHEN 'month' THEN 1.0 WHEN 'year' THEN 12.0 END),
      -- pattern B: 'week 12', 'day 1' (unit before the number, up to 3 digits)
      zip_with(
        regexp_extract_all(tf, '(?<![a-z])(day|week|month|year)s? *([0-9]{1,3})(?![0-9])', 2),
        regexp_extract_all(tf, '(?<![a-z])(day|week|month|year)s? *([0-9]{1,3})(?![0-9])', 1),
        (n, u) -> CAST(n AS DOUBLE) * CASE u WHEN 'day' THEN 1/30.4375 WHEN 'week' THEN 7/30.4375 WHEN 'month' THEN 1.0 WHEN 'year' THEN 12.0 END)
    )) AS months_raw
  FROM base
)
SELECT id, nct_id, outcome_type, measure, time_frame,
       -- cap at 120 months (10 years); guard against LEAST() ignoring nulls
       CASE WHEN months_raw IS NULL THEN NULL ELSE LEAST(months_raw, 120.0) END AS time_frame_months
FROM parsed

-- COMMAND ----------

CREATE OR REPLACE TABLE cns_trials.`2_silver`.designs
COMMENT 'Study design attributes (one row per study): allocation, intervention model, primary purpose, masking. Uppercase.'
AS
SELECT
  try_cast(id AS BIGINT)        AS id,
  nct_id,
  upper(NULLIF(trim(allocation), ''))         AS allocation,
  upper(NULLIF(trim(intervention_model), '')) AS intervention_model,
  upper(NULLIF(trim(primary_purpose), ''))    AS primary_purpose,
  upper(NULLIF(trim(masking), ''))            AS masking
FROM cns_trials.`1_bronze`.designs
WHERE nct_id IN (SELECT nct_id FROM cns_trials.`2_silver`.studies)

-- COMMAND ----------

CREATE OR REPLACE TABLE cns_trials.`2_silver`.interventions
COMMENT 'Interventions for studies in scope. intervention_type uppercase (DRUG, DEVICE, BEHAVIORAL, ...). Used to derive drug-intervention flags.'
AS
SELECT
  try_cast(id AS BIGINT)        AS id,
  nct_id,
  upper(NULLIF(trim(intervention_type), '')) AS intervention_type,
  NULLIF(trim(name), '')        AS name
FROM cns_trials.`1_bronze`.interventions
WHERE nct_id IN (SELECT nct_id FROM cns_trials.`2_silver`.studies)

-- COMMAND ----------

CREATE OR REPLACE TABLE cns_trials.`2_silver`.sponsors
COMMENT 'Sponsors and collaborators for studies in scope. agency_class and lead_or_collaborator uppercase.'
AS
SELECT
  try_cast(id AS BIGINT)        AS id,
  nct_id,
  NULLIF(trim(name), '')        AS name,
  upper(NULLIF(trim(agency_class), ''))         AS agency_class,
  upper(NULLIF(trim(lead_or_collaborator), '')) AS lead_or_collaborator
FROM cns_trials.`1_bronze`.sponsors
WHERE nct_id IN (SELECT nct_id FROM cns_trials.`2_silver`.studies)

-- COMMAND ----------

CREATE OR REPLACE TABLE cns_trials.`2_silver`.facilities
COMMENT 'Study sites for studies in scope. Rows kept even when country is null; Studies without any row have no site information.'
AS
SELECT
  try_cast(id AS BIGINT)        AS id,
  nct_id,
  NULLIF(trim(name), '')        AS name,
  NULLIF(trim(city), '')        AS city,
  NULLIF(trim(country), '')     AS country
FROM cns_trials.`1_bronze`.facilities
WHERE nct_id IN (SELECT nct_id FROM cns_trials.`2_silver`.studies)

-- COMMAND ----------

CREATE OR REPLACE TABLE cns_trials.`2_silver`.countries
COMMENT 'Countries of studies in scope. Rows flagged as removed and rows with null name are excluded.'
AS
SELECT
  try_cast(id AS BIGINT)        AS id,
  nct_id,
  trim(name)                    AS name
FROM cns_trials.`1_bronze`.countries
WHERE nct_id IN (SELECT nct_id FROM cns_trials.`2_silver`.studies)
  AND NULLIF(trim(name), '') IS NOT NULL
  AND NOT COALESCE(lower(trim(removed)) IN ('true', 't', 'yes', 'y', '1'), false)