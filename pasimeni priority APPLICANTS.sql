
--Selecting only the patents that have been granted.

drop table tls201_appln_1;

SELECT
	granted,
	earliest_filing_year,
	appln_id INTO tls201_appln_1
FROM
	tls201_appln
WHERE
	granted = 'Y';

CREATE INDEX tls_201_1_granted ON tls201_appln_1 (granted); 
CREATE INDEX tls_201_1_earliest_filing_year ON tls201_appln_1 (earliest_filing_year);

--Query 2 OK: SELECT 55562661, 55562661 rows affected

/*Selecting the inventor person_id (doesn't have to be a person, can be an organisation as well) of the patents granted and filtering with tls204 to leave the appln_ids of Paris Convention priority patents. Excerpt from the codebook: "Consequently, adding the condition "APPLT_SEQ_NR > 0" to the WHERE clause in a query retrieves only those persons from TLS207_PERS_APPLN or TLS227_PERS_PUBLN which are applicants."*/

drop table tls207_pers_appln_join_2;


SELECT DISTINCT --SELECT DISTINCT because SELECT produces duplicate rows 
	person_id,
	tls201_appln_1.appln_id INTO tls207_pers_appln_JOIN_2
FROM
	tls207_pers_appln
	INNER JOIN tls201_appln_1 ON tls207_pers_appln.appln_id = tls201_appln_1.appln_id
	INNER JOIN tls204_appln_prior ON tls207_pers_appln.appln_id = tls204_appln_prior.appln_id --INNER JOIN to select the appln_ids that are in both tables
WHERE
	APPLT_SEQ_NR > 0;

--Query 1 OK: SELECT 22 821 983, 22821983 rows affected

SELECT COUNT ( DISTINCT appln_id ) AS "patents" 
FROM tls207_pers_appln_join_2;

--There are 18 091 082 unique granted Paris Conventions priority patents.

SELECT
	appln_id,
	COUNT(appln_id)
FROM
	tls207_pers_appln_join_2
GROUP BY
	appln_id
HAVING
	COUNT(appln_id) > 1
order by COUNT(appln_id) DESC;

select *
from tls207_pers_appln_join_2
where appln_id = '1936502';

/*There are 2,213,498 appln_ids which have more than 1 applicant connected to it. It's worth noting that appln_id 1936502 for example has 71 person_ids connected to it.*/

CREATE INDEX tls207_person_id_JOIN_2 ON tls207_pers_appln_JOIN_2 (person_id);

--Selecting the person_ctry_vode ja doc_std_name_id, replacing some known values for a missing person_ctry_code.

drop table tls206_person_1;

SELECT
	person_id,
	doc_std_name_id,
	doc_std_name,
	(CASE 
		WHEN person_ctry_code = '--' then ''
		WHEN person_ctry_code = '. ' then ''
		when person_ctry_code = '..' then ''
		when person_ctry_code = '75' then ''
		when person_ctry_code = '@@' then ''
		WHEN person_ctry_code = ':W' then ''
		WHEN person_ctry_code = '0B' then ''
		WHEN person_ctry_code = '0T' then ''
		WHEN person_ctry_code = 'VT' then ''
		WHEN person_ctry_code = '0V' then ''
		else person_ctry_code
		end)
	 INTO tls206_person_1
FROM
	tls206_person;

--Query 1 OK: SELECT 74 388 833, 74388833 rows affected

CREATE INDEX tls206_person_id_1 ON tls206_person_1 (person_id);
CREATE INDEX tls206_person_ctry_code_1 ON tls206_person_1 (person_ctry_code);

SELECT
	count(person_ctry_code)
FROM
	tls206_person_1
WHERE
	person_ctry_code = '';

--Count of missing person_ctry_codes: 31 594 523

--Procedure proposed by Pasimeni (2019)

/*In order to show an example of these inconsistencies, Table 1 summarises the result of the query run in PATSTAT Online (2018 spring version) that searches and retrieves all person_id, and the related person_ctry_code, that have doc_std_name = 1. This identifier represents the Finnish Nokia Corporation and groups together 174 different entries. 130 of them are associated correctly with the country code ’FI’, 20 of them with the United States, 10 do not have any code and the remaining are associated with several other countries. Despite this lack of accuracy, it is worth noting that a country code occurs more frequently than the others. In this example, about 75% of person_id are assigned correctly to Finland. Therefore, it is reasonable to assume that also the remaining person_id, grouped under the doc_std_name_id=1, can be assigned to the same country.
The allocation procedure proposed in this paper is based on this rationale. It is assumed that the person_ctry_code associated more fre- quently to one doc_std_name_id is the correct one, and that can be automatically assigned to all person_id grouped under the doc_std_name_id itself./*

drop TABLE person_ctry_code_ALL;

SELECT
	doc_std_name_id,
	doc_std_name,
	person_ctry_code,
	count(person_ctry_code) AS N_all,
	rank() OVER (PARTITION BY doc_std_name_id ORDER BY count(person_ctry_code) --This orders the country codes per doc_std_name_id starting from the most frequent.
		DESC,
		person_ctry_code ASC) AS rnk INTO person_ctry_code_ALL
FROM
	tls206_person_1
WHERE
	NOT person_ctry_code = '' --To avoid missing country codes ending up the most frequent for some doc_std_name_ids
GROUP BY
	doc_std_name_id,
	doc_std_name,
	person_ctry_code
order by doc_std_name_id;

select COUNT(*)
from person_ctry_code_all;

--17 542 372

CREATE INDEX person_ctry_code_all_person_ctry_code ON person_ctry_code_ALL (person_ctry_code);

--Filtering out the country codes that were most frequent for each doc_std_name_id

drop table doc_ctry_code;

SELECT
	person_ctry_code AS doc_ctry_code,
	person_ctry_code_all.doc_std_name_id INTO doc_ctry_code
FROM
	person_ctry_code_all
WHERE
	rnk = '1';

--Query 6 OK: SELECT 16 435 975, 16435975 rows affected

CREATE INDEX doc_ctry_code_index ON doc_ctry_code (doc_ctry_code);

--Join together the table that has the country codes produced with the Pasimeni procedure and the table with the person country code and person_id.

drop table pasimeni_ctry_code;

SELECT
	tls206_person_1.doc_std_name_id,
	tls206_person_1.doc_std_name,
	tls206_person_1.person_id,
	tls206_person_1.person_ctry_code,
	doc_ctry_code.doc_ctry_code INTO PASIMENI_CTRY_CODE
FROM
	tls206_person_1 
	LEFT JOIN doc_ctry_code ON tls206_person_1.doc_std_name_id = doc_ctry_code.doc_std_name_id --LEFT JOIN so all the doc_std_name_ids from tls206_person_1 would be selected even if they don't get a ctry_code from the Pasimeni prodedure.
ORDER BY
	doc_std_name_id;

--Query 1 OK: SELECT 74388833, 74388833 rows affected
	
SELECT
	COUNT(doc_std_name_id)
FROM
	pasimeni_ctry_code
WHERE
	doc_ctry_code IS NULL;

--doc_std_name_ids still without a ctry_code: 19685501

--Filter with tls207 to leave only the applicants and appln_ids of Paris Convention priority patents.

drop table APPLICANT_ctry_code;

SELECT
	PASIMENI_CTRY_CODE.doc_std_name_id,
	PASIMENI_CTRY_CODE.doc_std_name,
	PASIMENI_CTRY_CODE.person_id,
	PASIMENI_CTRY_CODE.person_ctry_code,
	PASIMENI_CTRY_CODE.doc_ctry_code,
	tls207_pers_appln_join_2.appln_id INTO APPLICANT_CTRY_CODE
FROM
	PASIMENI_CTRY_CODE
	INNER JOIN tls207_pers_appln_join_2 ON tls207_pers_appln_join_2.person_id = PASIMENI_CTRY_CODE.person_id  --INNER JOIN with tls207 so only the applicants person_ids and corresponding appln_ids would remain.
order by tls207_pers_appln_join_2.appln_id;	

--Query 1 OK: SELECT 22821983, 22821983 rows affected

SELECT *
from applicant_ctry_code 
where appln_id = '1936502';

	
SELECT
	*
FROM
	applicant_ctry_code
WHERE
	doc_ctry_code IS NULL;


--There are 1,216,456 doc_std_name_ids that don't have doc_ctry_code, that's 5.3%. 


--This is just to check what those without a ctry_code look like.

SELECT
	doc_std_name_id,
	doc_std_name,
	count(doc_std_name_id) AS doc_count,
	count(doc_ctry_code) AS ctry_count
FROM
	applicant_ctry_code
GROUP BY
	doc_std_name_id,
	doc_std_name,
	doc_ctry_code
HAVING
	NOT count(doc_std_name_id) = count(doc_ctry_code);


--Doing the Pasimeni (2019) procedure again, this time using the psn_id.

/* Table tls206_person provides two additional sets of harmonised information. The first one is the result of a method developed by K.U.Leuven and Eurostat which harmonises patentees’ names and assigns a sector classification to them. This method generates another identification number, psn_id, which is added to PATSTAT, and concerns about 98% of the total person_id in table tls206_person. Therefore, also this additional identifier groups several person_id under the same entity. However, as for the case of doc_std_name_id, these additional sets of harmonised information present the same type of inconsistencies. Consequently, the allocation procedure can be replicated by using this additional identifier as main standardised reference, hence by replacing doc_std_name_id with psn_id.*/


drop table tls206_person_psn_id;

SELECT
	person_id,
	psn_id,
	psn_name,
	(CASE 
		WHEN person_ctry_code = '--' then ''
		WHEN person_ctry_code = '. ' then ''
		when person_ctry_code = '..' then ''
		when person_ctry_code = '75' then ''
		when person_ctry_code = '@@' then ''
		WHEN person_ctry_code = ':W' then ''
		WHEN person_ctry_code = '0B' then ''
		WHEN person_ctry_code = '0T' then ''
		WHEN person_ctry_code = 'VT' then ''
		WHEN person_ctry_code = '0V' then ''
		else person_ctry_code
		end)
	 INTO tls206_person_psn_id
FROM
	tls206_person;

--Query 2 OK: SELECT 74388833, 74388833 rows affected

CREATE INDEX tls206_person_psn_id_person ON tls206_person_psn_id (person_id);
CREATE INDEX tls206_person_ctry_code_psn_id ON tls206_person_psn_id (person_ctry_code);

SELECT
	count(person_ctry_code)
FROM
	tls206_person_psn_id
WHERE
	person_ctry_code = '';

--Count of missing person_ctry_codes: 31594618

--Procedure proposed by Pasimeni (2019)

drop TABLE person_ctry_code_psn;

SELECT
	psn_id,
	psn_name,
	person_ctry_code,
	count(person_ctry_code) AS N_all,
	rank() OVER (PARTITION BY psn_id ORDER BY count(person_ctry_code) --This orders the country codes per doc_std_name_id starting from the most frequent.
		DESC,
		person_ctry_code ASC) AS rnk INTO person_ctry_code_psn
FROM
	tls206_person_psn_id
WHERE
	NOT person_ctry_code = '' --To avoid missing country codes ending up the most frequent for some doc_std_name_ids
GROUP BY
	psn_id,
	psn_name,
	person_ctry_code
order by psn_id;

--Query 1 OK: SELECT 23615688, 23615688 rows affected

CREATE INDEX person_ctry_code_psn_person_ctry_code ON person_ctry_code_psn (person_ctry_code);

--Filtering out the country codes that were most frequent for each psn_id

drop table psn_ctry_code;

SELECT
	person_ctry_code AS psn_ctry_code,
	person_ctry_code_psn.psn_id INTO psn_ctry_code
FROM
	person_ctry_code_psn
WHERE
	rnk = '1';

--Query 2 OK: SELECT 22549218, 22549218 rows affected

CREATE INDEX psn_ctry_code_index ON psn_ctry_code (psn_ctry_code);

/*Join together the table that has the country codes produced with the Pasimeni procedure and the table with the person country code and person_id.*/

drop table pasimeni_ctry_code_psn;

SELECT
	tls206_person_psn_id.psn_id,
	tls206_person_psn_id.psn_name,
	tls206_person_psn_id.person_id,
	tls206_person_psn_id.person_ctry_code,
	psn_ctry_code.psn_ctry_code INTO PASIMENI_CTRY_CODE_psn
FROM
	tls206_person_psn_id
	LEFT JOIN psn_ctry_code ON tls206_person_psn_id.psn_id = psn_ctry_code.psn_id --LEFT JOIN so all the doc_std_name_ids from tls206_person_psn would be selected even if they don't get a ctry_code from the Pasimeni prodedure.
ORDER BY
	psn_id;

--Query 1 OK: SELECT 74389077, 74389077 rows affected

drop table psn_doc;

--Join with the table that has the country codes produced using doc_ctry_code

SELECT
	applicant_ctry_code.person_id,
	applicant_ctry_code.doc_ctry_code,
	applicant_ctry_code.appln_id,
	pasimeni_ctry_code_psn.psn_ctry_code into psn_doc
FROM
	applicant_ctry_code
	INNER JOIN pasimeni_ctry_code_psn ON applicant_ctry_code.person_id = pasimeni_ctry_code_psn.person_id
ORDER BY
	pasimeni_ctry_code_psn.psn_ctry_code;

--Query 1 OK: SELECT 22822003, 22822003 rows affected

SELECT
	*
FROM
	psn_doc
WHERE
	doc_ctry_code IS NULL
	AND psn_ctry_code IS NULL;

--There are 838,663 rows appln_ids that don't have doc_ctry_code or a ctry_code, that's 3.7%.

SELECT
	*
FROM
	psn_doc
WHERE
	doc_ctry_code IS NULL
	AND NOT psn_ctry_code IS NULL;

--Joining with pasimeni_ctry_code_psn gives us 377,793 country codes that we didn't have before. 

--Move the ctry_code from psn_ctry_code to doc_ctry_code where the doc_ctry_code was empty

UPDATE
	psn_doc
SET
	doc_ctry_code = COALESCE(psn_ctry_code, doc_ctry_code)
WHERE
	doc_ctry_code IS NULL
	AND NOT psn_ctry_code IS NULL;

/* Using the table with applicant country codes and appln_ids of priority patents provided by de Rassenfosse and Seliger (2019). This covers 52 patents offices between 1980-2016, so not all countries and years available in Patstat. */

DROP TABLE geoc_psn_doc;

SELECT DISTINCT
	psn_doc.person_id,
	psn_doc.doc_ctry_code,
	psn_doc.appln_id,
	G.ctry_code,
	G.type INTO geoc_psn_doc
/*FROM (
	SELECT
		*
	FROM
		geoc_app
	WHERE
		geoc_app.type = 'priority') AS G --To select only the Paris Convention priority patents from this table. I didn't end up doing this because the difference is small (ca 20 000 appln_ids) and a number of the patents that are in tls204 and thus should be PC priority are not marked as such in geoc_app. */
FROM geoc_app AS G 
	RIGHT JOIN psn_doc ON G.appln_id = psn_doc.appln_id
order by appln_id;

--Query 1 OK: SELECT 23060860, 23060860 rows affected

CREATE INDEX ctry_code_geoc_psn_doc ON geoc_psn_doc (ctry_code);
CREATE INDEX doc_ctry_code_geoc_psn_doc ON geoc_psn_doc (doc_ctry_code);
CREATE INDEX appln_id_geoc_psn_doc ON geoc_psn_doc (appln_id);

SELECT
	*
FROM
	geoc_psn_doc
WHERE
	doc_ctry_code IS NULL
	AND ctry_code IS NULL;

--There are 820,187 appln_ids that still don't have doc_ctry_code or a ctry_code, that's 3,6%.

SELECT
	*
FROM
	geoc_psn_doc
WHERE
	doc_ctry_code IS NULL
	AND NOT ctry_code IS NULL;

--Joining with geoc_app gives us 18,551 country codes that we didn't have before. 

--Move the ctry_code from geoc_app to doc_ctry_code where the doc_ctry_code was empty.

UPDATE geoc_psn_doc
SET doc_ctry_code = COALESCE(ctry_code, doc_ctry_code)
WHERE doc_ctry_code IS NULL
AND NOT ctry_code IS NULL;

--Query 1 OK: UPDATE 18551, 18551 rows affected

--Selecting distinct country code and appln_id combos and leaving out those still missing.

drop table applicants_distinct;

SELECT DISTINCT
	doc_ctry_code,
	appln_id into applicants_distinct
FROM
	geoc_psn_doc
WHERE
	doc_ctry_code IS NOT NULL;

--Query 1 OK: SELECT 17 908 113, 17 908 113 rows affected

select count (DISTINCT appln_id) 
from applicants_distinct;

--There are 17 394 918 unique patents that have at least 1 applicant country code, that's 96.2% of the original list of appln_ids (N = 18 091 082). 


/* Next, I'm checking if the appln_ids that still don't have a country code assigned to it, have an inventor or multiple inventors connected to it who have a country code assigned to them. If there are multiple inventors conneted to the patent, I'm only going to select one from each country. I'm again using both doc_std_name_id and psn_id to do this.*/

--Selecting appln_ids without at least one country code attached to it. 

DROP table doc_ctry_code_missing;

SELECT DISTINCT
	doc_ctry_code,
	count(doc_ctry_code),
	appln_id INTO doc_ctry_code_missing
FROM
	geoc_psn_doc
GROUP BY
	doc_ctry_code,
	appln_id
HAVING count(doc_ctry_code) = 0;

--Query 1 OK: SELECT 755 851, 755 851 rows affected

drop TABLE tls207_pers_appln_inventors;

SELECT DISTINCT --SELECT DISTINCT because SELECT produces duplicate rows 
	person_id,
	tls201_appln_1.appln_id INTO tls207_pers_appln_inventors
FROM
	tls207_pers_appln
	INNER JOIN tls201_appln_1 ON tls207_pers_appln.appln_id = tls201_appln_1.appln_id
	INNER JOIN tls204_appln_prior ON tls207_pers_appln.appln_id = tls204_appln_prior.appln_id --INNER JOIN to select the appln_ids that are in both tables
WHERE
	APPLT_SEQ_NR = 0;


CREATE INDEX tls207_person_id_inventors ON tls207_pers_appln_inventors (person_id);

drop TABLE INVENTOR_CTRY_CODE;

SELECT
	PASIMENI_CTRY_CODE.doc_std_name_id,
	PASIMENI_CTRY_CODE.doc_std_name,
	PASIMENI_CTRY_CODE.person_id,
	PASIMENI_CTRY_CODE.person_ctry_code,
	PASIMENI_CTRY_CODE.doc_ctry_code,
	tls207_pers_appln_inventors.appln_id INTO INVENTOR_CTRY_CODE
FROM
	pasimeni_ctry_code
	RIGHT JOIN tls207_pers_appln_inventors ON tls207_pers_appln_inventors.person_id = PASIMENI_CTRY_CODE.person_id --RIGHT JOIN with tls207 so only the inventors would remain.
	INNER JOIN doc_ctry_code_missing ON tls207_pers_appln_inventors.appln_id = doc_ctry_code_missing.appln_id--selecting only the patents we didn't find an applicant country code for.
ORDER BY
	tls207_pers_appln_inventors.appln_id;

--Query 1 OK: SELECT 945 599, 945 599 rows affected

drop table inventor_missing;

SELECT DISTINCT
	doc_ctry_code AS inventor_ctry_code,
	appln_id into inventor_missing
FROM
	inventor_ctry_code
ORDER BY
	appln_id;

--Query 1 OK: SELECT 464 269, 464 269 rows affected

SELECT
	appln_id,
	count(inventor_ctry_code)
FROM
	inventor_missing
GROUP BY
	appln_id
HAVING
	count(inventor_ctry_code) > 1;

--There are 8,316 appln_ids with more than one country code. 

select distinct count(appln_id)
from inventor_missing
where inventor_ctry_code IS NULL;

--Still 340 217 appln_ids without a country code. 

select distinct appln_id, count(appln_id)
from geoc_psn_doc
where doc_ctry_code IS NULL
GROUP BY appln_id;

--But still less than before: 755,851.

--Now doing the same using psn_id.

drop TABLE INVENTOR_CTRY_CODE_PSN;

SELECT DISTINCT
	pasimeni_ctry_code_psn.psn_id,
	PASIMENI_CTRY_CODE_psn.psn_name,
	PASIMENI_CTRY_CODE_psn.person_id,
	PASIMENI_CTRY_CODE_psn.psn_ctry_code,
	inventor_missing.appln_id,
	inventor_missing.inventor_ctry_code INTO INVENTOR_CTRY_CODE_PSN
FROM
	pasimeni_ctry_code_psn
	RIGHT JOIN tls207_pers_appln_inventors ON tls207_pers_appln_inventors.person_id = pasimeni_ctry_code_psn.person_id --RIGHT JOIN with tls207 so only the inventors would remain.
	RIGHT JOIN inventor_missing ON tls207_pers_appln_inventors.appln_id = inventor_missing.appln_id
ORDER BY
	inventor_missing.appln_id;

--Query 1 OK: SELECT 1107890, 1107890 rows affected

SELECT
	COUNT(DISTINCT appln_id)
FROM
	inventor_ctry_code_psn
WHERE
	inventor_ctry_code IS NULL
	AND psn_ctry_code IS NULL;

--That leaves us with 331 393 missing country codes.

UPDATE
	inventor_ctry_code_psn
SET
	inventor_ctry_code = COALESCE(inventor_ctry_code, psn_ctry_code)
WHERE
	inventor_ctry_code IS NULL
	AND NOT psn_ctry_code IS NULL;

--Query 1 OK: UPDATE 72 145, 72 145 rows affected

drop table inventor_missing_psn;

SELECT DISTINCT
	appln_id,
	inventor_ctry_code INTO inventor_missing_psn
FROM
	inventor_ctry_code_psn
WHERE
	NOT inventor_ctry_code IS NULL
ORDER BY
	appln_id;

--Query 1 OK: SELECT 141 455, 141 455 rows affected

DROP TABLE geoc_psn_doc_inventor_psn;

SELECT DISTINCT
	geoc_psn_doc.appln_id,
	doc_ctry_code,
	inventor_missing_psn.inventor_ctry_code into geoc_psn_doc_inventor_psn
FROM
	geoc_psn_doc
	LEFT JOIN inventor_missing_psn ON geoc_psn_doc.appln_id = inventor_missing_psn.appln_id;

--Query 1 OK: SELECT 18 680 186, 18680186 rows affected

UPDATE
	geoc_psn_doc_inventor_psn
SET
	doc_ctry_code = COALESCE(inventor_ctry_code, doc_ctry_code)
WHERE
	doc_ctry_code IS NULL
	AND NOT inventor_ctry_code IS NULL;

--Query 1 OK: UPDATE 141455, 141455 rows affected

--We are using 141 455 inventor country codes. 

SELECT
	COUNT(appln_id)
FROM
	geoc_psn_doc_inventor_psn
WHERE
	NOT doc_ctry_code IS NULL;

--We have 18 052 546 appln_ids with a country code, that's 96.6%.

drop TABLE counting_greens;

SELECT DISTINCT doc_ctry_code, appln_id into counting_greens 
FROM geoc_psn_doc_inventor_psn
WHERE not doc_ctry_code IS NULL;

--Query 1 OK: SELECT 18037120, 18037120 rows affected

--Update East Germany country code (DD) to Germany country code (DE).

UPDATE
	counting_greens
SET
	doc_ctry_code = 'DE'
WHERE
	doc_ctry_code = 'DD';

--Query 1 OK: UPDATE 21338, 21338 rows affected

--Count the green patents. 

drop table greens_ipc;

SELECT
	counting_greens.doc_ctry_code,
	tls201_appln_1.earliest_filing_year,
	tls209_appln_ipc.ipc_class_symbol,
	counting_greens.appln_id,
	CASE WHEN tls209_appln_ipc.ipc_class_symbol IN('C10L   5/00', 'C10L   5', 'C10B  53/02', 'C10L   5/40', 'C10L   9/00', 'C10L   1/00', 'C10L   1/02', 'C10L   1/14', 'C10L   1/02', 'C10L   1/19', 'C07C  67/00', 'C07C  69/00', 'C10G', 'C10L   1/02', 'C10L   1/19', 'C11C   3/10', 'C12P   7/64', 'C10L   1/02', 'C10L  1/182', 'C12N   9/24', 'C12P   7', 'C02F   3/28', 'C02F  11/04', 'C10L   3/00', 'C12M  1/107', 'C12P   5/02', 'C12N   1/13', 'C12N   1/15', 'C12N   1/21', 'C12N   5/10', 'C12N  15/00', 'A01H', 'C10L   3/00', 'F02C   3/28', 'H01M   2/00', 'H01M   2/02', 'H01M   2/04', 'H01M   4/86', 'H01M   4/88', 'H01M   4/90', 'H01M   4/92', 'H01M   4/94', 'H01M   4/96', 'H01M   4/98', 'H01M   8', 'H01M  12/00', 'H01M  12/02', 'H01M  12/04', 'H01M  12/06', 'H01M  12/08', 'C10B  53/00', 'C10J', 'C10L   5/00', 'C10L   5/42', 'C10L   5/44', 'F23G   7/00', 'F23G   7/10', 'C10J   3/02', 'C10J   3/46', 'F23B  90/00', 'F23G  5/027', 'B09B   3/00', 'F23G   7/00', 'C10L   5/48', 'F23G   5/00', 'F23G   7/00', 'C21B   5/06', 'D21C  11/00', 'A62D   3/02', 'C02F  11/04', 'C02F  11/14', 'F23G   7/00', 'F23G   7/10', 'B09B   3/00', 'F23G   5/00', 'B09B', 'B01D  53/02', 'B01D  53/04', 'B01D 53/047', 'B01D  53/14', 'B01D  53/22', 'B01D  53/24', 'C10L   5/46', 'F23G   5/00', 'E02B   9', 'F03B', 'F03C', 'F03B  13/12', 'F03B  13/14', 'F03B  13/16', 'F03B  13/18', 'F03B  13/20', 'F03B  13/22', 'F03B  13/24', 'F03B  13/26', 'F03B  15', 'B63H  19/02', 'B63H  19/04', 'F03G   7/05', 'F03D', 'H02K   7/18', 'B63B  35/00', 'E04H  12/00', 'F03D  13/00', 'B60K  16/00', 'B60L   8/00', 'B63H  13/00', 'F24S', 'H02S', 'H01L  27/142', 'H01L  31/00', 'H01L  31/02', 'H01L  31/0203', 'H01L  31/0216', 'H01L  31/0224', 'H01L  31/0232', 'H01L  31/0236', 'H01L  31/024', 'H01L  31/0248', 'H01L  31/0256', 'H01L  31/0264', 'H01L  31/0272', 'H01L  31/028', 'H01L  31/0288', 'H01L  31/0296', 'H01L  31/0304', 'H01L  31/0312', 'H01L  31/032', 'H01L  31/0328', 'H01L  31/0336', 'H01L  31/0352', 'H01L  31/036', 'H01L  31/0368', 'H01L  31/0376', 'H01L  31/0384', 'H01L  31/0392', 'H01L  31/04', 'H01L  31/041', 'H01L  31/042', 'H01L  31/043', 'H01L  31/044', 'H01L  31/0443', 'H01L  31/0445', 'H01L  31/046', 'H01L  31/0463', 'H01L  31/0465', 'H01L  31/0468', 'H01L  31/047', 'H01L  31/0475', 'H01L  31/048', 'H01L  31/049', 'H01L  31/05', 'H01L  31/052', 'H01L  31/0525', 'H01L  31/053', 'H01L  31/054', 'H01L  31/055', 'H01L  31/056', 'H01L  31/058', 'H01L  31/06', 'H01L  31/061', 'H01L  31/062', 'H01L  31/065', 'H01L  31/068', 'H01L  31/0687', 'H01L  31/0693', 'H01L  31/07', 'H01L  31/072', 'H01L  31/0725', 'H01L  31/073', 'H01L  31/0735', 'H01L  31/074', 'H01L  31/0745', 'H01L  31/0747', 'H01L  31/0749', 'H01L  31/075', 'H01L  31/076', 'H01L  31/077', 'H01L  31/078', 'H01G   9/20', 'H02S  10/00', 'H01L  27/30', 'H01L  51/42', 'H01L  51/44', 'H01L  51/46', 'H01L  51/48', 'H01L  25/00', 'H01L  25/03', 'H01L  25/16', 'H01L  25/18', 'H01L  31/042', 'C01B  33/02', 'C23C  14/14', 'C23C  16/24', 'C30B  29/06', 'G05F   1/67', 'F21L   4/00', 'F21S   9/03', 'H02J   7/35', 'H01G   9/20', 'H01M  14/00', 'F24S', 'F24D  17/00', 'F24D   3/00', 'F24D   5/00', 'F24D  11/00', 'F24D  19/00', 'F24S  90/00', 'F03D   1/04', 'F03D   9/00', 'F03D  13/20', 'F03G   6/00', 'C02F   1/14', 'F02C   1/05', 'H02S  40/44', 'B60K  16/00', 'B60L   8/00', 'F03G   6/00', 'F03G   6/02', 'F03G   6/04', 'F03G   6/06', 'E04D  13/00', 'E04D  13/18', 'F22B   1/00', 'F24V  30/00', 'F25B  27/00', 'F26B   3/00', 'F26B   3/28', 'F24S  23/00', 'G02B  7/183', 'F24S  10/10', 'F24T', 'F01K', 'F24F   5/00', 'F24T  10/00', 'F24T  10/10', 'F24T  10/13', 'F24T  10/15', 'F24T  10/17', 'F24T  10/20', 'F24T  10/30', 'F24T  10/40', 'F24T  50/00', 'F24V  30/00', 'F24V  40/00', 'F24V  40/10', 'F24V  50/00', 'H02N  10/00', 'F25B  30/06', 'F03G   4/00', 'F03G   4/02', 'F03G   4/04', 'F03G   4/06', 'F03G   7/04', 'F24D  11/02', 'F24D  15/04', 'F24D  17/02', 'F24H   4/00', 'F25B  30/00', 'F01K  27/00', 'F01K  23/06', 'F01K  23/08', 'F01K  23/10', 'F01N   5/00', 'F02G   5/00', 'F02G   5/02', 'F02G   5/04', 'F25B  27/02', 'F01K  17/00', 'F01K  23/04', 'F02C   6/18', 'F25B  27/02', 'C02F   1/16', 'D21F   5/20', 'F22B   1/02', 'F23G   5/46', 'F24F  12/00', 'F27D  17/00', 'F28D  17/00', 'F28D  17/02', 'F28D  17/04', 'F28D  19/00', 'F28D  19/02', 'F28D  19/04', 'F28D  20/00', 'F28D  20/02', 'C10J   3/86', 'F03G   5/00', 'F03G   5/02', 'F03G   5/04', 'F03G   5/06', 'F03G   5/08', 'B60K   6/00', 'B60K   6/20', 'H02K  29/08', 'H02K  49/10', 'B60L   7/10', 'B60L   7/12', 'B60L   7/14', 'B60L   7/16', 'B60L   7/18', 'B60L   7/20', 'B60L   7/22', 'B60L   8/00', 'B60L   9/00', 'B60L  50', 'B60L  53', 'B60L  55', 'B60L  58', 'F02B  43/00', 'F02M  21/02', 'F02M  27/02', 'B60K  16/00', 'H02J   7/00', 'B62D  35/00', 'B62D  35/02', 'B63B   1/34', 'B63B   1/36', 'B63B   1/38', 'B63B   1/40', 'B62K', 'B62M   1/00', 'B62M   3/00', 'B62M   5/00', 'B62M   6/00', 'B61', 'B61D  17/02', 'B63H   9/00', 'B63H  13/00', 'B63H  19/02', 'B63H  19/04', 'B63H  16/00', 'B63H  21/18', 'B64G   1/44', 'B60K   6/28', 'B60W  10/26', 'H01M  10/44', 'H01M  10/46', 'H01G  11/00', 'H02J   3/28', 'H02J   7/00', 'H02J  15/00', 'H02J', 'H02J   9/00', 'B60L   3/00', 'G01R', 'C09K   5/00', 'F24H   7/00', 'F28D  20/00', 'F28D  20/02', 'F21K  99/00', 'F21L   4/02', 'H01L  33', 'H01L  51/50', 'H05B  33/00', 'E04B   1/62', 'E04B   1/74', 'E04B   1/76', 'E04B   1/78', 'E04B   1/80', 'E04B   1/88', 'E04B   1/90', 'E04C   1/40', 'E04C   1/41', 'E04C   2/284', 'E04C   2/288', 'E04C   2/292', 'E04C   2/296', 'E06B   3/263', 'E04B   2/00', 'E04F  13/08', 'E04B   5/00', 'E04F  15/18', 'E04B   7/00', 'E04D   1/28', 'E04D   3/35', 'E04D  13/16', 'E04B   9/00', 'E04F  13/08', 'F03G   7/08', 'B60K   6/10', 'B60K   6/30', 'B60L  50/30', 'B09B', 'B65F', 'A61L  11/00', 'A62D   3/00', 'A62D 101/00', 'G21F   9/00', 'B03B   9/06', 'B09C', 'D21B   1/08', 'D21B   1/32', 'F23G', 'A43B   1/12', 'A43B  21/14', 'B22F   8/00', 'C04B   7/24', 'C04B   7/26', 'C04B   7/28', 'C04B   7/30', 'C04B  18/04', 'C04B  18/06', 'C04B  18/08', 'C04B  18/10', 'C05F', 'C08J  11', 'C09K  11/01', 'C11B  11/00', 'C11B  13', 'C14C   3/32', 'C21B   3/04', 'C25C   1/00', 'D01F  13', 'B01D  53/14', 'B01D  53/22', 'B01D  53/62', 'B65G   5/00', 'C01B  32/50', 'E21B  41/00', 'E21B  43/16', 'E21F  17/16', 'F25J   3/02', 'G21C  13/10', 'A01G  23/00', 'A01G  25/00', 'A01N  25', 'A01N  27', 'A01N  29', 'A01N  31', 'A01N  33', 'A01N  35', 'A01N  37', 'A01N  39', 'A01N  41', 'A01N  43', 'A01N  45', 'A01N  47', 'A01N  49', 'A01N  51', 'A01N  53', 'A01N  55', 'A01N  57', 'A01N  59', 'A01N  61', 'A01N  63', 'A01N  65', 'C09K  17/00', 'E02D   3/00', 'C05F', 'G06Q', 'G08G', 'G06Q', 'E04H   1/00', 'G21', 'F02C   1/05') THEN
			1
		ELSE
			0
		END AS is_green into greens_ipc
FROM
	counting_greens
	LEFT JOIN tls209_appln_ipc ON counting_greens.appln_id = tls209_appln_ipc.appln_id
	LEFT JOIN tls201_appln_1 ON counting_greens.appln_id = tls201_appln_1.appln_id
WHERE
	counting_greens.doc_ctry_code in('DE', 'AU', 'RU', 'IN', 'US');

--Query 1 OK: SELECT 33329590, 33329590 rows affected

--Counting the patents with a WIPO green code

SELECT
	p.doc_ctry_code,
	p.earliest_filing_year,
	COUNT(p.appln_id) AS is_green
FROM ( SELECT DISTINCT
		doc_ctry_code,
		earliest_filing_year,
		appln_id
	FROM
		greens_ipc) AS p
GROUP BY
	p.doc_ctry_code,
	p.earliest_filing_year;

--Counting all the patents

SELECT
	p.doc_ctry_code,
	p.earliest_filing_year,
	COUNT(p.appln_id) AS is_green
FROM ( SELECT DISTINCT
		doc_ctry_code,
		earliest_filing_year,
		appln_id
	FROM
		greens_ipc
	WHERE
		is_green = '1') AS p
GROUP BY
	p.doc_ctry_code,
	p.earliest_filing_year;

