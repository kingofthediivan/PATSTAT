/*Selecting the inventor country codes. Excerpt from the codebook: "An entry with the value 0 does not represent an applicant, but another person (e.g. an inventor)."*/

drop table tls207_inventors;

SELECT DISTINCT  
	person_id,
	appln_id INTO tls207_inventors
FROM
	tls207_pers_appln
WHERE
	APPLT_SEQ_NR = 0; --Selecting the inventors

SELECT
	COUNT(DISTINCT appln_id)
FROM
	tls207_inventors;

--There are 64 882 663 unique applications 
 
CREATE INDEX tls207_inventors_person_id ON tls207_inventors(person_id);

/* Using the table with inventor country codes and appln_ids of priority patents provided by de Rassenfosse and Seliger (2019). This covers 52 patents offices between 1980-2016, so not all countries and years available in Patstat. */

CREATE TABLE geoc_inv (LIKE geoc_app INCLUDING ALL);

drop table geoc_inventors;

SELECT DISTINCT
	tls207_inventors.appln_id,
	tls207_inventors.person_id,
	geoc_inv.ctry_code INTO geoc_inventors
FROM
	tls207_inventors
	LEFT JOIN geoc_inv ON tls207_inventors.appln_id = geoc_inv.appln_id;

SELECT
	count(DISTINCT appln_id)
FROM
	geoc_inventors
WHERE
	NOT ctry_code IS NULL;

--Doing so gives us 16 511 347 applications with a country code.

SELECT count(*)
from geoc_inventors;

--Replacing some known values for a missing person_ctry_code in tls206_person.

update tls206_person
set person_ctry_code = CASE 
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
		end
WHERE
	person_ctry_code in ('--', '. ', '..', '75', '@@', ':W', '0B', '0T', 'VT', '0V');

--Query 1 OK: UPDATE 98, 98 rows affected

SELECT
	count(person_ctry_code)
FROM
	tls206_person
WHERE
	person_ctry_code = '';

--Count of missing person_ctry_codes: 31 594 618

--Procedure proposed by Pasimeni (2019): doc_std_name_id

drop TABLE person_ctry_code_doc;

SELECT
	doc_std_name_id,
	doc_std_name,
	person_ctry_code,
	count(person_ctry_code) AS N_all,
	rank() OVER (PARTITION BY doc_std_name_id ORDER BY count(person_ctry_code) --This orders the country codes per doc_std_name_id starting from the most frequent.
		DESC,
		person_ctry_code ASC) AS rnk INTO person_ctry_code_doc
FROM
	tls206_person
WHERE
	NOT person_ctry_code = '' --To avoid missing country codes ending up the most frequent for some doc_std_name_ids
GROUP BY
	doc_std_name_id,
	doc_std_name,
	person_ctry_code
order by doc_std_name_id;

--Query 1 OK: SELECT 17 542 372, 17542372 rows affected

CREATE INDEX person_ctry_code_all_person_ctry_code ON person_ctry_code_doc (person_ctry_code);

--Filtering out the country codes that were most frequent for each doc_std_name_id

drop table doc_ctry_code;

SELECT
	person_ctry_code AS doc_ctry_code,
	person_ctry_code_doc.doc_std_name_id INTO doc_ctry_code
FROM
	person_ctry_code_doc
WHERE
	rnk = '1';

--Query 1 OK: SELECT 16435975, 16435975 rows affected

CREATE INDEX doc_ctry_code_index ON doc_ctry_code (doc_ctry_code);

--Doing the Pasimeni (2019) procedure again, this time using the psn_id.

/* Table tls206_person provides two additional sets of harmonised information. The first one is the result of a method developed by K.U.Leuven and Eurostat which harmonises patentees’ names and assigns a sector classification to them. This method generates another identification number, psn_id, which is added to PATSTAT, and concerns about 98% of the total person_id in table tls206_person. Therefore, also this additional identifier groups several person_id under the same entity. However, as for the case of doc_std_name_id, these additional sets of harmonised information present the same type of inconsistencies. Consequently, the allocation procedure can be replicated by using this additional identifier as main standardised reference, hence by replacing doc_std_name_id with psn_id.*/

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
	tls206_person
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

--Query 2 OK: SELECT 22 549 218, 22 549 218 rows affected

CREATE INDEX psn_ctry_code_index ON psn_ctry_code (psn_ctry_code);

/*Join together the table that has the country codes produced with the Pasimeni procedure and the table with the granted application ids, person ids, and country codes from de Rassenfosse (2019) repo.*/

drop table geoc_doc_psn;

SELECT DISTINCT
	tls206_person.person_id,
	geoc_inventors.appln_id,
	geoc_inventors.ctry_code,
	doc_ctry_code.doc_ctry_code,
	psn_ctry_code.psn_ctry_code into geoc_doc_psn
FROM
	geoc_inventors
	LEFT JOIN tls206_person ON geoc_inventors.person_id = tls206_person.person_id
	LEFT JOIN doc_ctry_code ON tls206_person.doc_std_name_id = doc_ctry_code.doc_std_name_id
	LEFT JOIN psn_ctry_code ON tls206_person.psn_id = psn_ctry_code.psn_id;

--Query 1 OK: SELECT 164 194 102, 164 194 102 rows affected

CREATE INDEX geoc_doc_psn_appln_id ON geoc_doc_psn (appln_id);
CREATE INDEX geoc_doc_psn_person_id ON geoc_doc_psn (person_id);

SELECT
	count(*)
FROM
	geoc_doc_psn
WHERE
	doc_ctry_code IS NULL
	AND psn_ctry_code IS NOT NULL;

--Using the Pasimeni procedure with psn_id gives us 3 792 461 additional country codes.

--Delete the applications without a country code

DELETE FROM geoc_doc_psn
WHERE ctry_code IS NULL
	AND doc_ctry_code IS NULL
	AND psn_ctry_code IS NULL;

SELECT
	count(DISTINCT appln_id)
FROM
	geoc_doc_psn;

--We have 59 418 090 applications with an inventor country code!

--Coalescing country code columns

SELECT
	appln_id,
	person_id,
	ctry_code AS ctry_code into ctry_co
FROM
	geoc_doc_psn
WHERE
	ctry_code IS NOT NULL
UNION
SELECT
	appln_id,
	person_id,
	doc_ctry_code AS ctry_code
FROM
	geoc_doc_psn
WHERE
	ctry_code IS NULL;

SELECT 
count(DISTINCT appln_id)
FROM
	ctry_co
WHERE
	ctry_code IS NOT NULL;

--58 664 822

SELECT
	appln_id,
	person_id,
	ctry_code AS ctry_code INTO ctry_psn
FROM
	ctry_co
UNION
SELECT
	appln_id,
	person_id,
	psn_ctry_code AS ctry_code
FROM
	geoc_doc_psn
WHERE
	doc_ctry_code IS NULL
	AND ctry_code IS NOT NULL;

SELECT
	count(DISTINCT appln_id)
FROM
	ctry_psn;

--Still 59 418 090 unique applications with an inventor country code after coalescing. 

--Make a table with applications ids, country codes, simple family ids, and earliest filing year.

drop table counting_fams;

SELECT DISTINCT
	ctry_psn.appln_id,
	ctry_psn.ctry_code,
	tls201_appln.docdb_family_id,
	tls201_appln.earliest_filing_year into counting_fams
FROM
	ctry_psn
	LEFT JOIN tls201_appln ON ctry_psn.appln_id = tls201_appln.appln_id;

--Query 1 OK: SELECT 71103414, 71103414 rows affected

SELECT
	count(DISTINCT docdb_family_id)
FROM
	counting_fams;

--41 092 283

--Combine data for Germany and Russia

UPDATE
	counting_fams
SET
	ctry_code = 'DE'
WHERE
	ctry_code = 'DD'; --East Germany

--Query 3 OK: UPDATE 105753, 105753 rows affected

UPDATE
	counting_fams
SET
	ctry_code = 'RU'
WHERE
	ctry_code = 'SU'; --USSR

--Query 4 OK: UPDATE 853301, 853301 rows affected
	
--Add IPC class sysmbols to the applications

drop table counting_fams_ipc;

SELECT 
	counting_fams.docdb_family_id,
	ctry_code,
	earliest_filing_year,
	tls209_appln_ipc.ipc_class_symbol INTO counting_fams_ipc
FROM
	counting_fams
	LEFT JOIN tls209_appln_ipc ON counting_fams.appln_id = tls209_appln_ipc.appln_id;

--Query 2 OK: SELECT 223 774 990, 223774990 rows affected
    
--Add CPC class symbols to the applications

drop table counting_fams_cpc;

SELECT 
	counting_fams.docdb_family_id,
	ctry_code,
	earliest_filing_year,
	tls225_docdb_fam_cpc.cpc_class_symbol INTO counting_fams_cpc
FROM
	counting_fams
	LEFT JOIN tls225_docdb_fam_cpc ON counting_fams.docdb_family_id = tls225_docdb_fam_cpc.docdb_family_id;  
	
--Query 2 OK: SELECT 223 774 990, 223774990 rows affected 

--Use the OECD method (fractional counts per unique country code allocated to the family) to calculate fractional counts for CPC Y02&04

drop table frac_oecd_cpc;

SELECT
	docdb_family_id,
	cpc_class_symbol,
	earliest_filing_year,
	ctry_code,
	f.ctry::DECIMAL / f.count AS frac into frac_oecd_cpc
FROM (
	SELECT DISTINCT
		docdb_family_id,
		ctry_code,
		earliest_filing_year,
		cpc_class_symbol,
		count(DISTINCT ctry_code) AS ctry,
		Count(*) OVER (PARTITION BY docdb_family_id) AS count
	FROM
		counting_fams_cpc
GROUP BY
	docdb_family_id,
	cpc_class_symbol,
	earliest_filing_year,
	ctry_code) f;

--Query 4 OK: SELECT 313 697 299, 313697299 rows affected

--IPC Green Inventory

DROP table frac_oecd_ipc;

SELECT
	docdb_family_id,
	ipc_class_symbol,
	earliest_filing_year,
	ctry_code,
	f.ctry::DECIMAL / f.count AS frac into frac_oecd_ipc
FROM (
	SELECT DISTINCT
		docdb_family_id,
		ctry_code,
		earliest_filing_year,
		ipc_class_symbol,
		count(DISTINCT ctry_code) AS ctry,
		Count(*) OVER (PARTITION BY docdb_family_id) AS count
	FROM
		counting_fams_ipc
GROUP BY
	docdb_family_id,
	ipc_class_symbol,
	earliest_filing_year,
	ctry_code) f;

--Query 8 OK: SELECT 143002504, 143002504 rows affected

--Checking if the sum per family is 1 (it is!)

drop table test2;
 
SELECT 
	docdb_family_id,
	frac into test2
FROM
	frac_oecd_cpc
WHERE
	docdb_family_id in('58745329', '58995202', '98675', '116971', '47996977');

SELECT
	docdb_family_id,
	sum(frac) AS total
FROM
	test2
GROUP BY
 docdb_family_id;

--Tag the Y02 and Y04 classes and subclasses


ALTER TABLE frac_oecd_cpc ADD COLUMN cpc_green TEXT;

UPDATE
	frac_oecd_cpc
SET
	cpc_green = (
			CASE WHEN cpc_class_symbol LIKE 'Y02A%' THEN
				'Adaptation to CC'
			WHEN cpc_class_symbol LIKE 'Y02B%' THEN
				'Buildings'
			WHEN cpc_class_symbol LIKE 'Y02C%' THEN
				'Capture and storage of GHG'
			WHEN cpc_class_symbol LIKE 'Y02D%' THEN
				'ICT'
			WHEN cpc_class_symbol LIKE 'Y02E%' THEN
				'Production of energy'
			WHEN cpc_class_symbol LIKE 'Y02P%' THEN
				'Industry and agriculture'
			WHEN cpc_class_symbol LIKE 'Y02T%' THEN
				'Transportation'
			WHEN cpc_class_symbol LIKE 'Y02W%' THEN
				'Waste'
			WHEN cpc_class_symbol LIKE 'Y04S%' THEN
				'Smart grids'
			ELSE
				'Other'
			END);


--Query 2 OK: UPDATE 121020483, 121020483 rows affected

ALTER TABLE frac_oecd_cpc ADD COLUMN is_green INTEGER;

UPDATE
	frac_oecd_cpc
SET is_green = CASE WHEN cpc_class_symbol LIKE 'Y02%' OR cpc_class_symbol LIKE 'Y04S%' THEN
	1
ELSE
	0
END;

--UPDATE 121020483, 121020483 rows affected

--Query 2 OK: UPDATE 67766654, 67766654 rows affected

--Find the innovations tagged with IPC codes in the Green Inventory

ALTER TABLE frac_oecd_ipc ADD COLUMN IPC_green TEXT;

UPDATE
	frac_oecd_ipc
SET
	IPC_green = (
		CASE WHEN ipc_class_symbol IN('A62D   3/02', 'B01D  53/02', 'B01D  53/04', 'B01D  53/047', 'B01D  53/14', 'B01D  53/22', 'B01D  53/24', 'B09B   3/00', 'B09B   3/00', 'B60K  16/00', 'B60K  16/00', 'B60L   8/00', 'B60L   8/00', 'B63B  35/00', 'B63H  13/00', 'B63H  19/02', 'B63H  19/04', 'C01B  33/02', 'C02F   1/14', 'C02F   1/16', 'C02F   3/28', 'C02F  11/04', 'C02F  11/04', 'C02F  11/14', 'C07C  67/00', 'C07C  69/00', 'C10B  53/00', 'C10B  53/02', 'C10J   3/02', 'C10J   3/46', 'C10J   3/86', 'C10L   1/00', 'C10L   1/02', 'C10L   1/02', 'C10L   1/02', 'C10L   1/02', 'C10L   1/14', 'C10L   1/182', 'C10L   1/19', 'C10L   1/19', 'C10L   3/00', 'C10L   3/00', 'C10L   5/00', 'C10L   5/00', 'C10L   5/40', 'C10L   5/42', 'C10L   5/44', 'C10L   5/46', 'C10L   5/48', 'C10L   9/00', 'C11C   3/10', 'C12M   1/107', 'C12N   1/13', 'C12N   1/15', 'C12N   1/21', 'C12N   5/10', 'C12N   9/24', 'C12N  15/00', 'C12P   5/02', 'C12P   7/64', 'C21B   5/06', 'C23C  14/14', 'C23C  16/24', 'C30B  29/06', 'D21C  11/00', 'D21F   5/20', 'E04D  13/00', 'E04D  13/18', 'E04H  12/00', 'F01K  17/00', 'F01K  23/04', 'F01K  23/06', 'F01K  23/08', 'F01K  23/10', 'F01K  27/00', 'F01N   5/00', 'F02C   1/05', 'F02C   3/28', 'F02C   6/18', 'F02G   5/00', 'F02G   5/02', 'F02G   5/04', 'F03B  13/12', 'F03B  13/14', 'F03B  13/16', 'F03B  13/18', 'F03B  13/20', 'F03B  13/22', 'F03B  13/24', 'F03B  13/26', 'F03D   1/04', 'F03D   9/00', 'F03D  13/00', 'F03D  13/20', 'F03G   4/00', 'F03G   4/02', 'F03G   4/04', 'F03G   4/06', 'F03G   5/00', 'F03G   5/02', 'F03G   5/04', 'F03G   5/06', 'F03G   5/08', 'F03G   6/00', 'F03G   6/00', 'F03G   6/02', 'F03G   6/04', 'F03G   6/06', 'F03G   7/04', 'F03G   7/05', 'F21L   4/00', 'F21S   9/03', 'F22B   1/00', 'F22B   1/02', 'F23B  90/00', 'F23G   5/00', 'F23G   5/00', 'F23G   5/00', 'F23G   5/027', 'F23G   5/46', 'F23G   7/00', 'F23G   7/00', 'F23G   7/00', 'F23G   7/00', 'F23G   7/10', 'F23G   7/10', 'F24D   3/00', 'F24D   5/00', 'F24D  11/00', 'F24D  11/02', 'F24D  15/04', 'F24D  17/00', 'F24D  17/02', 'F24D  19/00', 'F24F   5/00', 'F24F  12/00', 'F24H   4/00', 'F24S  10/10', 'F24S  23/00', 'F24S  90/00', 'F24T  10/00', 'F24T  10/10', 'F24T  10/13', 'F24T  10/15', 'F24T  10/17', 'F24T  10/20', 'F24T  10/30', 'F24T  10/40', 'F24T  50/00', 'F24V  30/00', 'F24V  30/00', 'F24V  40/00', 'F24V  40/10', 'F24V  50/00', 'F25B  27/00', 'F25B  27/02', 'F25B  27/02', 'F25B  30/00', 'F25B  30/06', 'F26B   3/00', 'F26B   3/28', 'F27D  17/00', 'F28D  17/00', 'F28D  17/02', 'F28D  17/04', 'F28D  19/00', 'F28D  19/02', 'F28D  19/04', 'F28D  20/00', 'F28D  20/02', 'G02B   7/183', 'G05F   1/67', 'H01G   9/20', 'H01G   9/20', 'H01L  25/00', 'H01L  25/03', 'H01L  25/16', 'H01L  25/18', 'H01L  27/142', 'H01L  27/30', 'H01L  31/00', 'H01L  31/02', 'H01L  31/0203', 'H01L  31/0216', 'H01L  31/0224', 'H01L  31/0232', 'H01L  31/0236', 'H01L  31/024', 'H01L  31/0248', 'H01L  31/0256', 'H01L  31/0264', 'H01L  31/0272', 'H01L  31/028', 'H01L  31/0288', 'H01L  31/0296', 'H01L  31/0304', 'H01L  31/0312', 'H01L  31/032', 'H01L  31/0328', 'H01L  31/0336', 'H01L  31/0352', 'H01L  31/036', 'H01L  31/0368', 'H01L  31/0376', 'H01L  31/0384', 'H01L  31/0392', 'H01L  31/04', 'H01L  31/041', 'H01L  31/042', 'H01L  31/042', 'H01L  31/043', 'H01L  31/044', 'H01L  31/0443', 'H01L  31/0445', 'H01L  31/046', 'H01L  31/0463', 'H01L  31/0465', 'H01L  31/0468', 'H01L  31/047', 'H01L  31/0475', 'H01L  31/048', 'H01L  31/049', 'H01L  31/05', 'H01L  31/052', 'H01L  31/0525', 'H01L  31/053', 'H01L  31/054', 'H01L  31/055', 'H01L  31/056', 'H01L  31/058', 'H01L  31/06', 'H01L  31/061', 'H01L  31/062', 'H01L  31/065', 'H01L  31/068', 'H01L  31/0687', 'H01L  31/0693', 'H01L  31/07', 'H01L  31/072', 'H01L  31/0725', 'H01L  31/073', 'H01L  31/0735', 'H01L  31/074', 'H01L  31/0745', 'H01L  31/0747', 'H01L  31/0749', 'H01L  31/075', 'H01L  31/076', 'H01L  31/077', 'H01L  31/078', 'H01L  51/42', 'H01L  51/44', 'H01L  51/46', 'H01L  51/48', 'H01M   2/00', 'H01M   2/02', 'H01M   2/04', 'H01M   4/86', 'H01M   4/88', 'H01M   4/90', 'H01M   4/92', 'H01M   4/94', 'H01M   4/96', 'H01M   4/98', 'H01M  12/00', 'H01M  12/02', 'H01M  12/04', 'H01M  12/06', 'H01M  12/08', 'H01M  14/00', 'H02J   7/35', 'H02K   7/18', 'H02N  10/00', 'H02S  10/00', 'H02S  40/44', 'A01H', 'B09B', 'B09B   1/00', 'B09B   3/00', 'B09B   5/00', 'C10G', 'C10J', 'C10J   1/00', 'C10J   1/02', 'C10J   1/04', 'C10J   1/06', 'C10J   1/08', 'C10J   1/10', 'C10J   1/12', 'C10J   1/14', 'C10J   1/16', 'C10J   1/18', 'C10J   1/20', 'C10J   1/207', 'C10J   1/213', 'C10J   1/22', 'C10J   1/24', 'C10J   1/26', 'C10J   1/28', 'C10J   3/00', 'C10J   3/02', 'C10J   3/04', 'C10J   3/06', 'C10J   3/08', 'C10J   3/10', 'C10J   3/12', 'C10J   3/14', 'C10J   3/16', 'C10J   3/18', 'C10J   3/20', 'C10J   3/22', 'C10J   3/24', 'C10J   3/26', 'C10J   3/28', 'C10J   3/30', 'C10J   3/32', 'C10J   3/34', 'C10J   3/36', 'C10J   3/38', 'C10J   3/40', 'C10J   3/42', 'C10J   3/44', 'C10J   3/46', 'C10J   3/48', 'C10J   3/50', 'C10J   3/52', 'C10J   3/54', 'C10J   3/56', 'C10J   3/57', 'C10J   3/58', 'C10J   3/60', 'C10J   3/62', 'C10J   3/64', 'C10J   3/66', 'C10J   3/72', 'C10J   3/74', 'C10J   3/76', 'C10J   3/78', 'C10J   3/80', 'C10J   3/82', 'C10J   3/84', 'C10J   3/86', 'F01K', 'F03B', 'F03C', 'F03D', 'F03D   1/00', 'F03D   1/02', 'F03D   1/04', 'F03D   1/06', 'F03D   3/00', 'F03D   3/02', 'F03D   3/04', 'F03D   3/06', 'F03D   5/00', 'F03D   5/02', 'F03D   5/04', 'F03D   5/06', 'F03D   7/00', 'F03D   7/02', 'F03D   7/04', 'F03D   7/06', 'F03D   9/00', 'F03D   9/10', 'F03D   9/11', 'F03D   9/12', 'F03D   9/13', 'F03D   9/14', 'F03D   9/16', 'F03D   9/17', 'F03D   9/18', 'F03D   9/19', 'F03D   9/20', 'F03D   9/22', 'F03D   9/25', 'F03D   9/28', 'F03D   9/30', 'F03D   9/32', 'F03D   9/34', 'F03D   9/35', 'F03D   9/37', 'F03D   9/39', 'F03D   9/41', 'F03D   9/43', 'F03D   9/45', 'F03D   9/46', 'F03D   9/48', 'F03D  13/00', 'F03D  13/10', 'F03D  13/20', 'F03D  13/25', 'F03D  13/30', 'F03D  13/35', 'F03D  13/40', 'F03D  15/00', 'F03D  15/10', 'F03D  15/20', 'F03D  17/00', 'F03D  80/00', 'F03D  80/10', 'F03D  80/20', 'F03D  80/30', 'F03D  80/40', 'F03D  80/50', 'F03D  80/55', 'F03D  80/60', 'F03D  80/70', 'F03D  80/80', 'F24S', 'F24S  10/00', 'F24S  10/10', 'F24S  10/13', 'F24S  10/17', 'F24S  10/20', 'F24S  10/25', 'F24S  10/30', 'F24S  10/40', 'F24S  10/50', 'F24S  10/55', 'F24S  10/60', 'F24S  10/70', 'F24S  10/75', 'F24S  10/80', 'F24S  10/90', 'F24S  10/95', 'F24S  20/00', 'F24S  20/20', 'F24S  20/25', 'F24S  20/30', 'F24S  20/40', 'F24S  20/50', 'F24S  20/55', 'F24S  20/60', 'F24S  20/61', 'F24S  20/62', 'F24S  20/63', 'F24S  20/64', 'F24S  20/66', 'F24S  20/67', 'F24S  20/69', 'F24S  20/70', 'F24S  20/80', 'F24S  21/00', 'F24S  23/00', 'F24S  23/30', 'F24S  23/70', 'F24S  23/71', 'F24S  23/72', 'F24S  23/74', 'F24S  23/75', 'F24S  23/77', 'F24S  23/79', 'F24S  25/00', 'F24S  25/10', 'F24S  25/11', 'F24S  25/12', 'F24S  25/13', 'F24S  25/15', 'F24S  25/16', 'F24S  25/20', 'F24S  25/30', 'F24S  25/33', 'F24S  25/35', 'F24S  25/37', 'F24S  25/40', 'F24S  25/50', 'F24S  25/60', 'F24S  25/61', 'F24S  25/613', 'F24S  25/615', 'F24S  25/617', 'F24S  25/63', 'F24S  25/632', 'F24S  25/634', 'F24S  25/636', 'F24S  25/65', 'F24S  25/67', 'F24S  25/70', 'F24S  30/00', 'F24S  30/20', 'F24S  30/40', 'F24S  30/42', 'F24S  30/422', 'F24S  30/425', 'F24S  30/428', 'F24S  30/45', 'F24S  30/452', 'F24S  30/455', 'F24S  30/458', 'F24S  30/48', 'F24S  40/00', 'F24S  40/10', 'F24S  40/20', 'F24S  40/40', 'F24S  40/42', 'F24S  40/44', 'F24S  40/46', 'F24S  40/48', 'F24S  40/50', 'F24S  40/52', 'F24S  40/53', 'F24S  40/55', 'F24S  40/57', 'F24S  40/58', 'F24S  40/60', 'F24S  40/70', 'F24S  40/80', 'F24S  40/90', 'F24S  50/00', 'F24S  50/20', 'F24S  50/40', 'F24S  50/60', 'F24S  50/80', 'F24S  60/00', 'F24S  60/10', 'F24S  60/20', 'F24S  60/30', 'F24S  70/00', 'F24S  70/10', 'F24S  70/12', 'F24S  70/14', 'F24S  70/16', 'F24S  70/20', 'F24S  70/225', 'F24S  70/25', 'F24S  70/275', 'F24S  70/30', 'F24S  70/60', 'F24S  70/65', 'F24S  80/00', 'F24S  80/10', 'F24S  80/20', 'F24S  80/30', 'F24S  80/40', 'F24S  80/45', 'F24S  80/453', 'F24S  80/457', 'F24S  80/50', 'F24S  80/52', 'F24S  80/525', 'F24S  80/54', 'F24S  80/56', 'F24S  80/58', 'F24S  80/60', 'F24S  80/65', 'F24S  80/70', 'F24S  90/00', 'F24S  90/10', 'F24T', 'F24T  10/00', 'F24T  10/10', 'F24T  10/13', 'F24T  10/15', 'F24T  10/17', 'F24T  10/20', 'F24T  10/30', 'F24T  10/40', 'F24T  50/00', 'H02S', 'H02S  10/00', 'H02S  10/10', 'H02S  10/12', 'H02S  10/20', 'H02S  10/30', 'H02S  10/40', 'H02S  20/00', 'H02S  20/10', 'H02S  20/20', 'H02S  20/21', 'H02S  20/22', 'H02S  20/23', 'H02S  20/24', 'H02S  20/25', 'H02S  20/26', 'H02S  20/30', 'H02S  20/32', 'H02S  30/00', 'H02S  30/10', 'H02S  30/20', 'H02S  40/00', 'H02S  40/10', 'H02S  40/12', 'H02S  40/20', 'H02S  40/22', 'H02S  40/30', 'H02S  40/32', 'H02S  40/34', 'H02S  40/36', 'H02S  40/38', 'H02S  40/40', 'H02S  40/42', 'H02S  40/44', 'H02S  50/00', 'H02S  50/10', 'H02S  50/15', 'H02S  99/00', 'C10L   5/00', 'C10L   5/02', 'C10L   5/04', 'C10L   5/06', 'C10L   5/08', 'C10L   5/10', 'C10L   5/12', 'C10L   5/14', 'C10L   5/16', 'C10L   5/18', 'C10L   5/20', 'C10L   5/22', 'C10L   5/24', 'C10L   5/26', 'C10L   5/28', 'C10L   5/30', 'C10L   5/32', 'C10L   5/34', 'C10L   5/36', 'C10L   5/38', 'C10L   5/40', 'C10L   5/42', 'C10L   5/44', 'C10L   5/46', 'C10L   5/48', 'C12P   7/00', 'C12P   7/02', 'C12P   7/04', 'C12P   7/06', 'C12P   7/08', 'C12P   7/10', 'C12P   7/12', 'C12P   7/14', 'C12P   7/16', 'C12P   7/18', 'C12P   7/20', 'C12P   7/22', 'C12P   7/24', 'C12P   7/26', 'C12P   7/28', 'C12P   7/30', 'C12P   7/32', 'C12P   7/34', 'C12P   7/36', 'C12P   7/38', 'C12P   7/40', 'C12P   7/42', 'C12P   7/44', 'C12P   7/46', 'C12P   7/48', 'C12P   7/50', 'C12P   7/52', 'C12P   7/54', 'C12P   7/56', 'C12P   7/58', 'C12P   7/60', 'C12P   7/62', 'C12P   7/64', 'C12P   7/66', 'E02B   9/00', 'E02B   9/02', 'E02B   9/04', 'E02B   9/06', 'E02B   9/08', 'F03B  15/00', 'F03B  15/02', 'F03B  15/04', 'F03B  15/06', 'F03B  15/08', 'F03B  15/10', 'F03B  15/12', 'F03B  15/14', 'F03B  15/16', 'F03B  15/18', 'F03B  15/20', 'F03B  15/22', 'H01M   8/00', 'H01M   8/008', 'H01M   8/02', 'H01M   8/0202', 'H01M   8/0204', 'H01M   8/0206', 'H01M   8/0208', 'H01M   8/021', 'H01M   8/0213', 'H01M   8/0215', 'H01M   8/0217', 'H01M   8/0221', 'H01M   8/0223', 'H01M   8/0226', 'H01M   8/0228', 'H01M   8/023', 'H01M   8/0232', 'H01M   8/0234', 'H01M   8/0236', 'H01M   8/0239', 'H01M   8/0241', 'H01M   8/0243', 'H01M   8/0245', 'H01M   8/0247', 'H01M   8/025', 'H01M   8/0252', 'H01M   8/0254', 'H01M   8/0256', 'H01M   8/0258', 'H01M   8/026', 'H01M   8/0263', 'H01M   8/0265', 'H01M   8/0267', 'H01M   8/0271', 'H01M   8/0273', 'H01M   8/0276', 'H01M   8/028', 'H01M   8/0282', 'H01M   8/0284', 'H01M   8/0286', 'H01M   8/0289', 'H01M   8/0293', 'H01M   8/0295', 'H01M   8/0297', 'H01M   8/04', 'H01M   8/04007', 'H01M   8/04014', 'H01M   8/04029', 'H01M   8/04044', 'H01M   8/04082', 'H01M   8/04089', 'H01M   8/04111', 'H01M   8/04119', 'H01M   8/04186', 'H01M   8/04223', 'H01M   8/04225', 'H01M   8/04228', 'H01M   8/04276', 'H01M   8/04291', 'H01M   8/04298', 'H01M   8/043', 'H01M   8/04302', 'H01M   8/04303', 'H01M   8/04313', 'H01M   8/0432', 'H01M   8/0438', 'H01M   8/0444', 'H01M   8/04492', 'H01M   8/04537', 'H01M   8/04664', 'H01M   8/04694', 'H01M   8/04701', 'H01M   8/04746', 'H01M   8/04791', 'H01M   8/04828', 'H01M   8/04858', 'H01M   8/04955', 'H01M   8/04992', 'H01M   8/06', 'H01M   8/0606', 'H01M   8/0612', 'H01M   8/0637', 'H01M   8/065', 'H01M   8/0656', 'H01M   8/0662', 'H01M   8/0668', 'H01M   8/08', 'H01M   8/083', 'H01M   8/086', 'H01M   8/10', 'H01M   8/1004', 'H01M   8/1006', 'H01M   8/1007', 'H01M   8/1009', 'H01M   8/1011', 'H01M   8/1016', 'H01M   8/1018', 'H01M   8/102', 'H01M   8/1023', 'H01M   8/1025', 'H01M   8/1027', 'H01M   8/103', 'H01M   8/1032', 'H01M   8/1034', 'H01M   8/1037', 'H01M   8/1039', 'H01M   8/1041', 'H01M   8/1044', 'H01M   8/1046', 'H01M   8/1048', 'H01M   8/1051', 'H01M   8/1053', 'H01M   8/1058', 'H01M   8/106', 'H01M   8/1062', 'H01M   8/1065', 'H01M   8/1067', 'H01M   8/1069', 'H01M   8/1072', 'H01M   8/1081', 'H01M   8/1086', 'H01M   8/1088', 'H01M   8/1097', 'H01M   8/12', 'H01M   8/1213', 'H01M   8/122', 'H01M   8/1226', 'H01M   8/1231', 'H01M   8/1233', 'H01M   8/124', 'H01M   8/1246', 'H01M   8/1253', 'H01M   8/126', 'H01M   8/1286', 'H01M   8/14', 'H01M   8/16', 'H01M   8/18', 'H01M   8/20', 'H01M   8/22', 'H01M   8/24', 'H01M   8/2404', 'H01M   8/241', 'H01M   8/2418', 'H01M   8/242', 'H01M   8/2425', 'H01M   8/2428', 'H01M   8/243', 'H01M   8/2432', 'H01M   8/2435', 'H01M   8/244', 'H01M   8/2455', 'H01M   8/2457', 'H01M   8/2465', 'H01M   8/247', 'H01M   8/2475', 'H01M   8/248', 'H01M   8/2483', 'H01M   8/2484', 'H01M   8/2485', 'H01M   8/249', 'H01M   8/2495', 'F01K', 'F01K   1/00', 'F01K   1/02', 'F01K   1/04', 'F01K   1/06', 'F01K   1/08', 'F01K   1/10', 'F01K   1/12', 'F01K   1/14', 'F01K   1/16', 'F01K   1/18', 'F01K   1/20', 'F01K   3/00', 'F01K   3/02', 'F01K   3/04', 'F01K   3/06', 'F01K   3/08', 'F01K   3/10', 'F01K   3/12', 'F01K   3/14', 'F01K   3/16', 'F01K   3/18', 'F01K   3/20', 'F01K   3/22', 'F01K   3/24', 'F01K   3/26', 'F01K   5/00', 'F01K   5/02', 'F01K   7/00', 'F01K   7/02', 'F01K   7/04', 'F01K   7/06', 'F01K   7/08', 'F01K   7/10', 'F01K   7/12', 'F01K   7/14', 'F01K   7/16', 'F01K   7/18', 'F01K   7/20', 'F01K   7/22', 'F01K   7/24', 'F01K   7/26', 'F01K   7/28', 'F01K   7/30', 'F01K   7/32', 'F01K   7/34', 'F01K   7/36', 'F01K   7/38', 'F01K   7/40', 'F01K   7/42', 'F01K   7/44', 'F01K   9/00', 'F01K   9/02', 'F01K   9/04', 'F01K  11/00', 'F01K  11/02', 'F01K  11/04', 'F01K  13/00', 'F01K  13/02', 'F01K  15/00', 'F01K  15/02', 'F01K  15/04', 'F01K  17/00', 'F01K  17/02', 'F01K  17/04', 'F01K  17/06', 'F01K  19/00', 'F01K  19/02', 'F01K  19/04', 'F01K  19/06', 'F01K  19/08', 'F01K  19/10', 'F01K  21/00', 'F01K  21/02', 'F01K  21/04', 'F01K  21/06', 'F01K  23/00', 'F01K  23/02', 'F01K  23/04', 'F01K  23/06', 'F01K  23/08', 'F01K  23/10', 'F01K  23/12', 'F01K  23/14', 'F01K  23/16', 'F01K  23/18', 'F01K  25/00', 'F01K  25/02', 'F01K  25/04', 'F01K  25/06', 'F01K  25/08', 'F01K  25/10', 'F01K  25/12', 'F01K  25/14', 'F01K  27/00', 'F01K  27/02', 'C10G   3/00)', 'F03B', 'F03B   1/00', 'F03B   1/02', 'F03B   1/04', 'F03B   3/00', 'F03B   3/02', 'F03B   3/04', 'F03B   3/06', 'F03B   3/08', 'F03B   3/10', 'F03B   3/12', 'F03B   3/14', 'F03B   3/16', 'F03B   3/18', 'F03B   5/00', 'F03B   7/00', 'F03B   9/00', 'F03B  11/00', 'F03B  11/02', 'F03B  11/04', 'F03B  11/06', 'F03B  11/08', 'F03B  13/00', 'F03B  13/02', 'F03B  13/04', 'F03B  13/06', 'F03B  13/08', 'F03B  13/10', 'F03B  13/12', 'F03B  13/14', 'F03B  13/16', 'F03B  13/18', 'F03B  13/20', 'F03B  13/22', 'F03B  13/24', 'F03B  13/26', 'F03B  15/00', 'F03B  15/02', 'F03B  15/04', 'F03B  15/06', 'F03B  15/08', 'F03B  15/10', 'F03B  15/12', 'F03B  15/14', 'F03B  15/16', 'F03B  15/18', 'F03B  15/20', 'F03B  15/22', 'F03B  17/00', 'F03B  17/02', 'F03B  17/04', 'F03B  17/06') THEN
			'Alternative energy'
		WHEN ipc_class_symbol IN('B60K   6/00', 'B60K   6/20', 'B60K  16/00', 'B60L   7/10', 'B60L   7/12', 'B60L   7/14', 'B60L   7/16', 'B60L   7/18', 'B60L   7/20', 'B60L   7/22', 'B60L   8/00', 'B60L   9/00', 'B61D  17/02', 'B62D  35/00', 'B62D  35/02', 'B62M   1/00', 'B62M   3/00', 'B62M   5/00', 'B62M   6/00', 'B63B   1/34', 'B63B   1/36', 'B63B   1/38', 'B63B   1/40', 'B63H   9/00', 'B63H  13/00', 'B63H  16/00', 'B63H  19/02', 'B63H  19/04', 'B63H  21/18', 'B64G   1/44', 'F02B  43/00', 'F02M  21/02', 'F02M  27/02', 'H02J   7/00', 'H02K  29/08', 'H02K  49/10', 'B61B', 'B61B   1/00', 'B61B   1/02', 'B61B   3/00', 'B61B   3/02', 'B61B   5/00', 'B61B   5/02', 'B61B   7/00', 'B61B   7/02', 'B61B   7/04', 'B61B   7/06', 'B61B   9/00', 'B61B  10/00', 'B61B  10/02', 'B61B  10/04', 'B61B  11/00', 'B61B  12/00', 'B61B  12/02', 'B61B  12/04', 'B61B  12/06', 'B61B  12/08', 'B61B  12/10', 'B61B  12/12', 'B61B  13/00', 'B61B  13/02', 'B61B  13/04', 'B61B  13/06', 'B61B  13/08', 'B61B  13/10', 'B61B  13/12', 'B61B  15/00', 'B62K', 'B62K   1/00', 'B62K   3/00', 'B62K   3/02', 'B62K   3/04', 'B62K   3/06', 'B62K   3/08', 'B62K   3/10', 'B62K   3/12', 'B62K   3/14', 'B62K   3/16', 'B62K   5/00', 'B62K   5/003', 'B62K   5/007', 'B62K   5/01', 'B62K   5/02', 'B62K   5/023', 'B62K   5/025', 'B62K   5/027', 'B62K   5/05', 'B62K   5/06', 'B62K   5/08', 'B62K   5/10', 'B62K   7/00', 'B62K   7/02', 'B62K   7/04', 'B62K   9/00', 'B62K   9/02', 'B62K  11/00', 'B62K  11/02', 'B62K  11/04', 'B62K  11/06', 'B62K  11/08', 'B62K  11/10', 'B62K  11/12', 'B62K  11/14', 'B62K  13/00', 'B62K  13/02', 'B62K  13/04', 'B62K  13/06', 'B62K  13/08', 'B62K  15/00', 'B62K  17/00', 'B62K  19/00', 'B62K  19/02', 'B62K  19/04', 'B62K  19/06', 'B62K  19/08', 'B62K  19/10', 'B62K  19/12', 'B62K  19/14', 'B62K  19/16', 'B62K  19/18', 'B62K  19/20', 'B62K  19/22', 'B62K  19/24', 'B62K  19/26', 'B62K  19/28', 'B62K  19/30', 'B62K  19/32', 'B62K  19/34', 'B62K  19/36', 'B62K  19/38', 'B62K  19/40', 'B62K  19/42', 'B62K  19/44', 'B62K  19/46', 'B62K  19/48', 'B62K  21/00', 'B62K  21/02', 'B62K  21/04', 'B62K  21/06', 'B62K  21/08', 'B62K  21/10', 'B62K  21/12', 'B62K  21/14', 'B62K  21/16', 'B62K  21/18', 'B62K  21/20', 'B62K  21/22', 'B62K  21/24', 'B62K  21/26', 'B62K  23/00', 'B62K  23/02', 'B62K  23/04', 'B62K  23/06', 'B62K  23/08', 'B62K  25/00', 'B62K  25/02', 'B62K  25/04', 'B62K  25/06', 'B62K  25/08', 'B62K  25/10', 'B62K  25/12', 'B62K  25/14', 'B62K  25/16', 'B62K  25/18', 'B62K  25/20', 'B62K  25/22', 'B62K  25/24', 'B62K  25/26', 'B62K  25/28', 'B62K  25/30', 'B62K  25/32', 'B62K  27/00', 'B62K  27/02', 'B62K  27/04', 'B62K  27/06', 'B62K  27/08', 'B62K  27/10', 'B62K  27/12', 'B62K  27/14', 'B62K  27/16', 'B60L  50/00', 'B60L  50/10', 'B60L  50/11', 'B60L  50/12', 'B60L  50/13', 'B60L  50/14', 'B60L  50/15', 'B60L  50/16', 'B60L  50/20', 'B60L  50/30', 'B60L  50/40', 'B60L  50/50', 'B60L  50/51', 'B60L  50/52', 'B60L  50/53', 'B60L  50/60', 'B60L  50/61', 'B60L  50/62', 'B60L  50/64', 'B60L  50/70', 'B60L  50/71', 'B60L  50/72', 'B60L  50/75', 'B60L  50/90', 'B60L  53/00', 'B60L  53/10', 'B60L  53/12', 'B60L  53/122', 'B60L  53/124', 'B60L  53/126', 'B60L  53/14', 'B60L  53/16', 'B60L  53/18', 'B60L  53/20', 'B60L  53/22', 'B60L  53/24', 'B60L  53/30', 'B60L  53/302', 'B60L  53/31', 'B60L  53/34', 'B60L  53/35', 'B60L  53/36', 'B60L  53/37', 'B60L  53/38', 'B60L  53/39', 'B60L  53/50', 'B60L  53/51', 'B60L  53/52', 'B60L  53/53', 'B60L  53/54', 'B60L  53/55', 'B60L  53/56', 'B60L  53/57', 'B60L  53/60', 'B60L  53/62', 'B60L  53/63', 'B60L  53/64', 'B60L  53/65', 'B60L  53/66', 'B60L  53/67', 'B60L  53/68', 'B60L  53/80', 'B60L  55/00', 'B60L  58/00', 'B60L  58/10', 'B60L  58/12', 'B60L  58/13', 'B60L  58/14', 'B60L  58/15', 'B60L  58/16', 'B60L  58/18', 'B60L  58/19', 'B60L  58/20', 'B60L  58/21', 'B60L  58/22', 'B60L  58/24', 'B60L  58/25', 'B60L  58/26', 'B60L  58/27', 'B60L  58/30', 'B60L  58/31', 'B60L  58/32', 'B60L  58/33', 'B60L  58/34', 'B60L  58/40') THEN
			'Transportation'
		WHEN ipc_class_symbol IN('B60K   6/10', 'B60K   6/28', 'B60K   6/30', 'B60L   3/00', 'B60L  50/30', 'B60W  10/26', 'C09K   5/00', 'E04B   1/62', 'E04B   1/74', 'E04B   1/76', 'E04B   1/78', 'E04B   1/80', 'E04B   1/88', 'E04B   1/90', 'E04B   2/00', 'E04B   5/00', 'E04B   7/00', 'E04B   9/00', 'E04C   1/40', 'E04C   1/41', 'E04C   2/284', 'E04C   2/288', 'E04C   2/292', 'E04C   2/296', 'E04D   1/28', 'E04D   3/35', 'E04D  13/16', 'E04F  13/08', 'E04F  13/08', 'E04F  15/18', 'E06B   3/263', 'F03G   7/08', 'F21K  99/00', 'F21L   4/02', 'F24H   7/00', 'F28D  20/00', 'F28D  20/02', 'H01G  11/00', 'H01L  51/50', 'H01M  10/44', 'H01M  10/46', 'H02J   3/28', 'H02J   7/00', 'H02J   9/00', 'H02J  15/00', 'H05B  33/00', 'G01R', 'H02J', 'H02J   1/00', 'H02J   1/02', 'H02J   1/04', 'H02J   1/06', 'H02J   1/08', 'H02J   1/10', 'H02J   1/12', 'H02J   1/14', 'H02J   1/16', 'H02J   3/00', 'H02J   3/01', 'H02J   3/02', 'H02J   3/04', 'H02J   3/06', 'H02J   3/08', 'H02J   3/10', 'H02J   3/12', 'H02J   3/14', 'H02J   3/16', 'H02J   3/18', 'H02J   3/20', 'H02J   3/22', 'H02J   3/24', 'H02J   3/26', 'H02J   3/28', 'H02J   3/30', 'H02J   3/32', 'H02J   3/34', 'H02J   3/36', 'H02J   3/38', 'H02J   3/40', 'H02J   3/42', 'H02J   3/44', 'H02J   3/46', 'H02J   3/48', 'H02J   3/50', 'H02J   4/00', 'H02J   5/00', 'H02J   7/00', 'H02J   7/02', 'H02J   7/04', 'H02J   7/06', 'H02J   7/08', 'H02J   7/10', 'H02J   7/12', 'H02J   7/14', 'H02J   7/16', 'H02J   7/18', 'H02J   7/20', 'H02J   7/22', 'H02J   7/24', 'H02J   7/26', 'H02J   7/28', 'H02J   7/30', 'H02J   7/32', 'H02J   7/34', 'H02J   7/35', 'H02J   7/36', 'H02J   9/00', 'H02J   9/02', 'H02J   9/04', 'H02J   9/06', 'H02J   9/08', 'H02J  11/00', 'H02J  13/00', 'H02J  15/00', 'H02J  50/00', 'H02J  50/05', 'H02J  50/10', 'H02J  50/12', 'H02J  50/15', 'H02J  50/20', 'H02J  50/23', 'H02J  50/27', 'H02J  50/30', 'H02J  50/40', 'H02J  50/50', 'H02J  50/60', 'H02J  50/70', 'H02J  50/80', 'H02J  50/90', 'H02J  50/90', 'H01L  33/00', 'H01L  33/02', 'H01L  33/04', 'H01L  33/06', 'H01L  33/08', 'H01L  33/10', 'H01L  33/12', 'H01L  33/14', 'H01L  33/16', 'H01L  33/18', 'H01L  33/20', 'H01L  33/22', 'H01L  33/24', 'H01L  33/26', 'H01L  33/28', 'H01L  33/30', 'H01L  33/32', 'H01L  33/34', 'H01L  33/36', 'H01L  33/38', 'H01L  33/40', 'H01L  33/42', 'H01L  33/44', 'H01L  33/46', 'H01L  33/48', 'H01L  33/50', 'H01L  33/52', 'H01L  33/54', 'H01L  33/56', 'H01L  33/58', 'H01L  33/60', 'H01L  33/62', 'H01L  33/64') THEN
			'Energy conservation'
		WHEN ipc_class_symbol IN('B63B  35/32', 'B63B  35/32', 'B63J   4/00', 'B63J   4/00', 'C02F   1/00', 'C02F   1/00', 'C02F   3/00', 'C02F   3/00', 'C02F   9/00', 'C02F   9/00', 'C05F   7/00', 'C05F   7/00', 'C09K   3/32', 'C09K   3/32', 'E02B  15/04', 'E02B  15/04', 'E03C   1/12', 'E03C   1/12', 'A43B   1/12', 'A43B  21/14', 'A61L  11/00', 'A62D   3/00', 'A62D 101/00', 'B01D  53/14', 'B01D  53/22', 'B01D  53/62', 'B03B   9/06', 'B22F   8/00', 'B65G   5/00', 'C01B  32/50', 'C04B   7/24', 'C04B   7/26', 'C04B   7/28', 'C04B   7/30', 'C04B  18/04', 'C04B  18/06', 'C04B  18/08', 'C04B  18/10', 'C09K  11/01', 'C11B  11/00', 'C14C   3/32', 'C21B   3/04', 'C25C   1/00', 'D21B   1/08', 'D21B   1/32', 'E21B  41/00', 'E21B  43/16', 'E21F  17/16', 'F25J   3/02', 'G21C  13/10', 'G21F   9/00', 'B09B', 'B09B   1/00', 'B09B   3/00', 'B09B   5/00', 'B09C', 'B09C   1/00', 'B09C   1/02', 'B09C   1/04', 'B09C   1/06', 'B09C   1/08', 'B09C   1/10', 'B65F', 'B65F   1/00', 'B65F   1/02', 'B65F   1/04', 'B65F   1/06', 'B65F   1/08', 'B65F   1/10', 'B65F   1/12', 'B65F   1/14', 'B65F   1/16', 'B65F   3/00', 'B65F   3/02', 'B65F   3/04', 'B65F   3/06', 'B65F   3/08', 'B65F   3/10', 'B65F   3/12', 'B65F   3/14', 'B65F   3/16', 'B65F   3/18', 'B65F   3/20', 'B65F   3/22', 'B65F   3/24', 'B65F   3/26', 'B65F   3/28', 'B65F   5/00', 'B65F   7/00', 'B65F   9/00', 'C05F', 'C05F   1/00', 'C05F   1/02', 'C05F   3/00', 'C05F   3/02', 'C05F   3/04', 'C05F   3/06', 'C05F   5/00', 'C05F   7/00', 'C05F   7/02', 'C05F   7/04', 'C05F   9/00', 'C05F   9/02', 'C05F   9/04', 'C05F  11/00', 'C05F  11/02', 'C05F  11/04', 'C05F  11/06', 'C05F  11/08', 'C05F  11/10', 'C05F  15/00', 'C05F  17/00', 'C05F  17/05', 'C05F  17/10', 'C05F  17/20', 'C05F  17/30', 'C05F  17/40', 'C05F  17/50', 'C05F  17/60', 'C05F  17/70', 'C05F  17/80', 'C05F  17/90', 'C05F  17/907', 'C05F  17/914', 'C05F  17/921', 'C05F  17/929', 'C05F  17/936', 'C05F  17/943', 'C05F  17/95', 'C05F  17/957', 'C05F  17/964', 'C05F  17/971', 'C05F  17/979', 'C05F  17/986', 'C05F  17/993', 'F23G', 'F23G   1/00', 'F23G   5/00', 'F23G   5/02', 'F23G   5/027', 'F23G   5/033', 'F23G   5/04', 'F23G   5/05', 'F23G   5/08', 'F23G   5/10', 'F23G   5/12', 'F23G   5/14', 'F23G   5/16', 'F23G   5/18', 'F23G   5/20', 'F23G   5/22', 'F23G   5/24', 'F23G   5/26', 'F23G   5/28', 'F23G   5/30', 'F23G   5/32', 'F23G   5/34', 'F23G   5/36', 'F23G   5/38', 'F23G   5/40', 'F23G   5/42', 'F23G   5/44', 'F23G   5/46', 'F23G   5/48', 'F23G   5/50', 'F23G   7/00', 'F23G   7/02', 'F23G   7/04', 'F23G   7/05', 'F23G   7/06', 'F23G   7/07', 'F23G   7/08', 'F23G   7/10', 'F23G   7/12', 'F23G   7/14', 'C08J  11/00', 'C08J  11/02', 'C08J  11/04', 'C08J  11/06', 'C08J  11/08', 'C08J  11/10', 'C08J  11/12', 'C08J  11/14', 'C08J  11/16', 'C08J  11/18', 'C08J  11/20', 'C08J  11/22', 'C08J  11/24', 'C08J  11/26', 'C08J  11/28', 'C11B  13/00', 'C11B  13/02', 'C11B  13/04', 'D01F  13/00', 'D01F  13/02', 'D01F  13/04', 'C02F', 'C02F   1/00', 'C02F   1/02', 'C02F   1/04', 'C02F   1/06', 'C02F   1/08', 'C02F   1/10', 'C02F   1/12', 'C02F   1/14', 'C02F   1/16', 'C02F   1/18', 'C02F   1/20', 'C02F   1/22', 'C02F   1/24', 'C02F   1/26', 'C02F   1/28', 'C02F   1/30', 'C02F   1/32', 'C02F   1/34', 'C02F   1/36', 'C02F   1/38', 'C02F   1/40', 'C02F   1/42', 'C02F   1/44', 'C02F   1/46', 'C02F   1/461', 'C02F   1/463', 'C02F   1/465', 'C02F   1/467', 'C02F   1/469', 'C02F   1/48', 'C02F   1/50', 'C02F   1/52', 'C02F   1/54', 'C02F   1/56', 'C02F   1/58', 'C02F   1/60', 'C02F   1/62', 'C02F   1/64', 'C02F   1/66', 'C02F   1/68', 'C02F   1/70', 'C02F   1/72', 'C02F   1/74', 'C02F   1/76', 'C02F   1/78', 'C02F   3/00', 'C02F   3/02', 'C02F   3/04', 'C02F   3/06', 'C02F   3/08', 'C02F   3/10', 'C02F   3/12', 'C02F   3/14', 'C02F   3/16', 'C02F   3/18', 'C02F   3/20', 'C02F   3/22', 'C02F   3/24', 'C02F   3/26', 'C02F   3/28', 'C02F   3/30', 'C02F   3/32', 'C02F   3/34', 'C02F   5/00', 'C02F   5/02', 'C02F   5/04', 'C02F   5/06', 'C02F   5/08', 'C02F   5/10', 'C02F   5/12', 'C02F   5/14', 'C02F   7/00', 'C02F   9/00', 'C02F   9/02', 'C02F   9/04', 'C02F   9/06', 'C02F   9/08', 'C02F   9/10', 'C02F   9/12', 'C02F   9/14', 'C02F  11/00', 'C02F  11/02', 'C02F  11/04', 'C02F  11/06', 'C02F  11/08', 'C02F  11/10', 'C02F  11/12', 'C02F  11/121', 'C02F  11/122', 'C02F  11/123', 'C02F  11/125', 'C02F  11/126', 'C02F  11/127', 'C02F  11/128', 'C02F  11/13', 'C02F  11/131', 'C02F  11/14', 'C02F  11/143', 'C02F  11/145', 'C02F  11/147', 'C02F  11/148', 'C02F  11/15', 'C02F  11/16', 'C02F  11/18', 'C02F  11/20', 'C02F 101/00', 'C02F 101/10', 'C02F 101/12', 'C02F 101/14', 'C02F 101/16', 'C02F 101/18', 'C02F 101/20', 'C02F 101/22', 'C02F 101/30', 'C02F 101/32', 'C02F 101/34', 'C02F 101/36', 'C02F 101/38', 'C02F 103/00', 'C02F 103/02', 'C02F 103/04', 'C02F 103/06', 'C02F 103/08', 'C02F 103/10', 'C02F 103/12', 'C02F 103/14', 'C02F 103/16', 'C02F 103/18', 'C02F 103/20', 'C02F 103/22', 'C02F 103/24', 'C02F 103/26', 'C02F 103/28', 'C02F 103/30', 'C02F 103/32', 'C02F 103/34', 'C02F 103/36', 'C02F 103/38', 'C02F 103/40', 'C02F 103/42', 'C02F 103/44', 'E03F', 'E03F   1/00', 'E03F   3/00', 'E03F   3/02', 'E03F   3/04', 'E03F   3/06', 'E03F   5/00', 'E03F   5/02', 'E03F   5/04', 'E03F   5/042', 'E03F   5/046', 'E03F   5/06', 'E03F   5/08', 'E03F   5/10', 'E03F   5/12', 'E03F   5/14', 'E03F   5/16', 'E03F   5/18', 'E03F   5/20', 'E03F   5/22', 'E03F   5/24', 'E03F   5/26', 'E03F   7/00', 'E03F   7/02', 'E03F   7/04', 'E03F   7/06', 'E03F   7/08', 'E03F   7/10', 'E03F   7/12', 'E03F   9/00', 'E03F 11/00') THEN
			'Waste management'
		WHEN ipc_class_symbol IN('A01G  23/00', 'A01G  25/00', 'C09K  17/00', 'E02D   3/00', 'C05F', 'C05F   1/00', 'C05F   1/02', 'C05F   3/00', 'C05F   3/02', 'C05F   3/04', 'C05F   3/06', 'C05F   5/00', 'C05F   7/00', 'C05F   7/02', 'C05F   7/04', 'C05F   9/00', 'C05F   9/02', 'C05F   9/04', 'C05F  11/00', 'C05F  11/02', 'C05F  11/04', 'C05F  11/06', 'C05F  11/08', 'C05F  11/10', 'C05F  15/00', 'C05F  17/00', 'C05F  17/05', 'C05F  17/10', 'C05F  17/20', 'C05F  17/30', 'C05F  17/40', 'C05F  17/50', 'C05F  17/60', 'C05F  17/70', 'C05F  17/80', 'C05F  17/90', 'C05F  17/907', 'C05F  17/914', 'C05F  17/921', 'C05F  17/929', 'C05F  17/936', 'C05F  17/943', 'C05F  17/95', 'C05F  17/957', 'C05F  17/964', 'C05F  17/971', 'C05F  17/979', 'C05F  17/986', 'C05F  17/993', 'A01N  25/00', 'A01N  25/02', 'A01N  25/04', 'A01N  25/06', 'A01N  25/08', 'A01N  25/10', 'A01N  25/12', 'A01N  25/14', 'A01N  25/16', 'A01N  25/18', 'A01N  25/20', 'A01N  25/22', 'A01N  25/24', 'A01N  25/26', 'A01N  25/28', 'A01N  25/30', 'A01N  25/32', 'A01N  25/34', 'A01N  27/00', 'A01N  29/00', 'A01N  29/02', 'A01N  29/04', 'A01N  29/06', 'A01N  29/08', 'A01N  29/10', 'A01N  29/12', 'A01N  31/00', 'A01N  31/02', 'A01N  31/04', 'A01N  31/06', 'A01N  31/08', 'A01N  31/10', 'A01N  31/12', 'A01N  31/14', 'A01N  31/16', 'A01N  33/00', 'A01N  33/02', 'A01N  33/04', 'A01N  33/06', 'A01N  33/08', 'A01N  33/10', 'A01N  33/12', 'A01N  33/14', 'A01N  33/16', 'A01N  33/18', 'A01N  33/20', 'A01N  33/22', 'A01N  33/24', 'A01N  33/26', 'A01N  35/00', 'A01N  35/02', 'A01N  35/04', 'A01N  35/06', 'A01N  35/08', 'A01N  35/10', 'A01N  37/00', 'A01N  37/02', 'A01N  37/04', 'A01N  37/06', 'A01N  37/08', 'A01N  37/10', 'A01N  37/12', 'A01N  37/14', 'A01N  37/16', 'A01N  37/18', 'A01N  37/20', 'A01N  37/22', 'A01N  37/24', 'A01N  37/26', 'A01N  37/28', 'A01N  37/30', 'A01N  37/32', 'A01N  37/34', 'A01N  37/36', 'A01N  37/38', 'A01N  37/40', 'A01N  37/42', 'A01N  37/44', 'A01N  37/46', 'A01N  37/48', 'A01N  37/50', 'A01N  37/52', 'A01N  39/00', 'A01N  39/02', 'A01N  39/04', 'A01N  41/00', 'A01N  41/02', 'A01N  41/04', 'A01N  41/06', 'A01N  41/08', 'A01N  41/10', 'A01N  41/12', 'A01N  43/00', 'A01N  43/02', 'A01N  43/04', 'A01N  43/06', 'A01N  43/08', 'A01N  43/10', 'A01N  43/12', 'A01N  43/14', 'A01N  43/16', 'A01N  43/18', 'A01N  43/20', 'A01N  43/22', 'A01N  43/24', 'A01N  43/26', 'A01N  43/28', 'A01N  43/30', 'A01N  43/32', 'A01N  43/34', 'A01N  43/36', 'A01N  43/38', 'A01N  43/40', 'A01N  43/42', 'A01N  43/44', 'A01N  43/46', 'A01N  43/48', 'A01N  43/50', 'A01N  43/52', 'A01N  43/54', 'A01N  43/56', 'A01N  43/58', 'A01N  43/60', 'A01N  43/62', 'A01N  43/64', 'A01N  43/647', 'A01N  43/653', 'A01N  43/66', 'A01N  43/68', 'A01N  43/70', 'A01N  43/707', 'A01N  43/713', 'A01N  43/72', 'A01N  43/74', 'A01N  43/76', 'A01N  43/78', 'A01N  43/80', 'A01N  43/82', 'A01N  43/824', 'A01N  43/828', 'A01N  43/832', 'A01N  43/836', 'A01N  43/84', 'A01N  43/86', 'A01N  43/88', 'A01N  43/90', 'A01N  43/92', 'A01N  45/00', 'A01N  45/02', 'A01N  47/00', 'A01N  47/02', 'A01N  47/04', 'A01N  47/06', 'A01N  47/08', 'A01N  47/10', 'A01N  47/12', 'A01N  47/14', 'A01N  47/16', 'A01N  47/18', 'A01N  47/20', 'A01N  47/22', 'A01N  47/24', 'A01N  47/26', 'A01N  47/28', 'A01N  47/30', 'A01N  47/32', 'A01N  47/34', 'A01N  47/36', 'A01N  47/38', 'A01N  47/40', 'A01N  47/42', 'A01N  47/44', 'A01N  47/46', 'A01N  47/48', 'A01N  49/00', 'A01N  51/00', 'A01N  53/00', 'A01N  53/02', 'A01N  53/04', 'A01N  53/06', 'A01N  53/08', 'A01N  53/10', 'A01N  53/12', 'A01N  53/14', 'A01N  55/00', 'A01N  55/02', 'A01N  55/04', 'A01N  55/06', 'A01N  55/08', 'A01N  55/10', 'A01N  57/00', 'A01N  57/02', 'A01N  57/04', 'A01N  57/06', 'A01N  57/08', 'A01N  57/10', 'A01N  57/12', 'A01N  57/14', 'A01N  57/16', 'A01N  57/18', 'A01N  57/20', 'A01N  57/22', 'A01N  57/24', 'A01N  57/26', 'A01N  57/28', 'A01N  57/30', 'A01N  57/32', 'A01N  57/34', 'A01N  57/36', 'A01N  59/00', 'A01N  59/02', 'A01N  59/04', 'A01N  59/06', 'A01N  59/08', 'A01N  59/10', 'A01N  59/12', 'A01N  59/14', 'A01N  59/16', 'A01N  59/18', 'A01N  59/20', 'A01N  59/22', 'A01N  59/24', 'A01N  59/26', 'A01N  61/00', 'A01N  61/02', 'A01N  63/00', 'A01N  63/10', 'A01N  63/12', 'A01N  63/14', 'A01N  63/16', 'A01N  63/20', 'A01N  63/22', 'A01N  63/23', 'A01N  63/25', 'A01N  63/27', 'A01N  63/28', 'A01N  63/30', 'A01N  63/32', 'A01N  63/34', 'A01N  63/36', 'A01N  63/38', 'A01N  63/40', 'A01N  63/50', 'A01N  63/60', 'A01N  65/00', 'A01N  65/03', 'A01N  65/04', 'A01N  65/06', 'A01N  65/08', 'A01N  65/10', 'A01N  65/12', 'A01N  65/14', 'A01N  65/16', 'A01N  65/18', 'A01N  65/20', 'A01N  65/22', 'A01N  65/24', 'A01N  65/26', 'A01N  65/28', 'A01N  65/30', 'A01N  65/32', 'A01N  65/34', 'A01N  65/36', 'A01N  65/38', 'A01N  65/40', 'A01N  65/42', 'A01N  65/44', 'A01N  65/46', 'A01N  65/48') THEN 'Agriculture and Forestry'
		WHEN ipc_class_symbol IN('E04H   1/00', 'G06Q') THEN 'Administrative and regulatory'
		WHEN ipc_class_symbol IN('F02C   1/05', 'G21B', 'G21B   1/00', 'G21B   1/01', 'G21B   1/03', 'G21B   1/05', 'G21B   1/11', 'G21B   1/13', 'G21B   1/15', 'G21B   1/17', 'G21B   1/19', 'G21B   1/21', 'G21B   1/23', 'G21B   1/25', 'G21B   3/00', 'G21C', 'G21C   1/00', 'G21C   1/02', 'G21C   1/03', 'G21C   1/04', 'G21C   1/06', 'G21C   1/07', 'G21C   1/08', 'G21C   1/09', 'G21C   1/10', 'G21C   1/12', 'G21C   1/14', 'G21C   1/16', 'G21C   1/18', 'G21C   1/20', 'G21C   1/22', 'G21C   1/24', 'G21C   1/26', 'G21C   1/28', 'G21C   1/30', 'G21C   1/32', 'G21C   3/00', 'G21C   3/02', 'G21C   3/04', 'G21C   3/06', 'G21C   3/07', 'G21C   3/08', 'G21C   3/10', 'G21C   3/12', 'G21C   3/14', 'G21C   3/16', 'G21C   3/17', 'G21C   3/18', 'G21C   3/20', 'G21C   3/22', 'G21C   3/24', 'G21C   3/26', 'G21C   3/28', 'G21C   3/30', 'G21C   3/32', 'G21C   3/322', 'G21C   3/324', 'G21C   3/326', 'G21C   3/328', 'G21C   3/33', 'G21C   3/332', 'G21C   3/334', 'G21C   3/335', 'G21C   3/336', 'G21C   3/338', 'G21C   3/34', 'G21C   3/344', 'G21C   3/348', 'G21C   3/352', 'G21C   3/356', 'G21C   3/36', 'G21C   3/38', 'G21C   3/40', 'G21C   3/42', 'G21C   3/44', 'G21C   3/46', 'G21C   3/48', 'G21C   3/50', 'G21C   3/52', 'G21C   3/54', 'G21C   3/56', 'G21C   3/58', 'G21C   3/60', 'G21C   3/62', 'G21C   3/64', 'G21C   5/00', 'G21C   5/02', 'G21C   5/04', 'G21C   5/06', 'G21C   5/08', 'G21C   5/10', 'G21C   5/12', 'G21C   5/14', 'G21C   5/16', 'G21C   5/18', 'G21C   5/20', 'G21C   5/22', 'G21C   7/00', 'G21C   7/02', 'G21C   7/04', 'G21C   7/06', 'G21C   7/08', 'G21C   7/10', 'G21C   7/103', 'G21C   7/107', 'G21C   7/11', 'G21C   7/113', 'G21C   7/117', 'G21C   7/12', 'G21C   7/14', 'G21C   7/16', 'G21C   7/18', 'G21C   7/20', 'G21C   7/22', 'G21C   7/24', 'G21C   7/26', 'G21C   7/27', 'G21C   7/28', 'G21C   7/30', 'G21C   7/32', 'G21C   7/34', 'G21C   7/36', 'G21C   9/00', 'G21C   9/004', 'G21C   9/008', 'G21C   9/012', 'G21C   9/016', 'G21C   9/02', 'G21C   9/027', 'G21C   9/033', 'G21C   9/04', 'G21C   9/06', 'G21C  11/00', 'G21C  11/02', 'G21C  11/04', 'G21C  11/06', 'G21C  11/08', 'G21C  13/00', 'G21C  13/02', 'G21C  13/024', 'G21C  13/028', 'G21C  13/032', 'G21C  13/036', 'G21C  13/04', 'G21C  13/06', 'G21C  13/067', 'G21C  13/073', 'G21C  13/08', 'G21C  13/087', 'G21C  13/093', 'G21C  13/10', 'G21C  15/00', 'G21C  15/02', 'G21C  15/04', 'G21C  15/06', 'G21C  15/08', 'G21C  15/10', 'G21C  15/12', 'G21C  15/14', 'G21C  15/16', 'G21C  15/18', 'G21C  15/20', 'G21C  15/22', 'G21C  15/24', 'G21C  15/243', 'G21C  15/247', 'G21C  15/25', 'G21C  15/253', 'G21C  15/257', 'G21C  15/26', 'G21C  15/28', 'G21C  17/00', 'G21C  17/003', 'G21C  17/007', 'G21C  17/01', 'G21C  17/013', 'G21C  17/017', 'G21C  17/02', 'G21C  17/022', 'G21C  17/025', 'G21C  17/028', 'G21C  17/032', 'G21C  17/035', 'G21C  17/038', 'G21C  17/04', 'G21C  17/06', 'G21C  17/07', 'G21C  17/08', 'G21C  17/10', 'G21C  17/104', 'G21C  17/108', 'G21C  17/112', 'G21C  17/116', 'G21C  17/12', 'G21C  17/14', 'G21C  19/00', 'G21C  19/02', 'G21C  19/04', 'G21C  19/06', 'G21C  19/07', 'G21C  19/08', 'G21C  19/10', 'G21C  19/105', 'G21C  19/11', 'G21C  19/115', 'G21C  19/12', 'G21C  19/14', 'G21C  19/16', 'G21C  19/18', 'G21C  19/19', 'G21C  19/20', 'G21C  19/22', 'G21C  19/24', 'G21C  19/26', 'G21C  19/28', 'G21C  19/30', 'G21C  19/303', 'G21C  19/307', 'G21C  19/31', 'G21C  19/313', 'G21C  19/317', 'G21C  19/32', 'G21C  19/33', 'G21C  19/34', 'G21C  19/36', 'G21C  19/365', 'G21C  19/37', 'G21C  19/375', 'G21C  19/38', 'G21C  19/40', 'G21C  19/42', 'G21C  19/44', 'G21C  19/46', 'G21C  19/48', 'G21C  19/50', 'G21C  21/00', 'G21C  21/02', 'G21C  21/04', 'G21C  21/06', 'G21C  21/08', 'G21C  21/10', 'G21C  21/12', 'G21C  21/14', 'G21C  21/16', 'G21C  21/18', 'G21C  23/00', 'G21D', 'G21D   1/00', 'G21D   1/02', 'G21D   1/04', 'G21D   3/00', 'G21D   3/02', 'G21D   3/04', 'G21D   3/06', 'G21D   3/08', 'G21D   3/10', 'G21D   3/12', 'G21D   3/14', 'G21D   3/16', 'G21D   3/18', 'G21D   5/00', 'G21D   5/02', 'G21D   5/04', 'G21D   5/06', 'G21D   5/08', 'G21D   5/10', 'G21D   5/12', 'G21D   5/14', 'G21D   5/16', 'G21D   7/00', 'G21D   7/02', 'G21D   7/04', 'G21D   9/00', 'G21F', 'G21F   1/00', 'G21F   1/02', 'G21F   1/04', 'G21F   1/06', 'G21F   1/08', 'G21F   1/10', 'G21F   1/12', 'G21F   3/00', 'G21F   3/02', 'G21F   3/025', 'G21F   3/03', 'G21F   3/035', 'G21F   3/04', 'G21F   5/00', 'G21F   5/002', 'G21F   5/005', 'G21F   5/008', 'G21F   5/012', 'G21F   5/015', 'G21F   5/018', 'G21F   5/02', 'G21F   5/04', 'G21F   5/06', 'G21F   5/08', 'G21F   5/10', 'G21F   5/12', 'G21F   5/14', 'G21F   7/00', 'G21F   7/005', 'G21F   7/01', 'G21F   7/015', 'G21F   7/02', 'G21F   7/03', 'G21F   7/04', 'G21F   7/047', 'G21F   7/053', 'G21F   7/06', 'G21F   9/00', 'G21F   9/02', 'G21F   9/04', 'G21F   9/06', 'G21F   9/08', 'G21F   9/10', 'G21F   9/12', 'G21F   9/14', 'G21F   9/16', 'G21F   9/18', 'G21F   9/20', 'G21F   9/22', 'G21F   9/24', 'G21F   9/26', 'G21F   9/28', 'G21F   9/30', 'G21F   9/32', 'G21F   9/34', 'G21F   9/36', 'G21G', 'G21G   1/00', 'G21G   1/02', 'G21G   1/04', 'G21G   1/06', 'G21G   1/08', 'G21G   1/10', 'G21G   1/12', 'G21G   4/00', 'G21G   4/02', 'G21G   4/04', 'G21G   4/06', 'G21G   4/08', 'G21G   4/10', 'G21G   5/00', 'G21G   7/00', 'G21H', 'G21H   1/00', 'G21H   1/02', 'G21H   1/04', 'G21H   1/06', 'G21H   1/08', 'G21H   1/10', 'G21H   1/12', 'G21H   3/00', 'G21H   3/02', 'G21H   5/00', 'G21H   5/02', 'G21H   7/00', 'G21J', 'G21J   1/00', 'G21J   3/00', 'G21J   3/02', 'G21J   5/00', 'G21K', 'G21K   1/00', 'G21K   1/02', 'G21K   1/04', 'G21K   1/06', 'G21K   1/08', 'G21K   1/087', 'G21K   1/093', 'G21K   1/10', 'G21K   1/12', 'G21K   1/14', 'G21K   1/16', 'G21K   3/00', 'G21K   4/00', 'G21K   5/00', 'G21K   5/02', 'G21K   5/04', 'G21K   5/08', 'G21K   5/10', 'G21K   7/00') THEN
			'Nuclear Power Generation'
		ELSE
			'Other'
		END); 
		
--Query 1 OK: UPDATE 29652687, 29652687 rows affected
		
ALTER TABLE frac_oecd_ipc ADD COLUMN is_green INTEGER;

UPDATE
	frac_oecd_ipc
SET
	is_green = (
		CASE WHEN ipc_class_symbol IN('A62D   3/02', 'B01D  53/02', 'B01D  53/04', 'B01D  53/047', 'B01D  53/14', 'B01D  53/22', 'B01D  53/24', 'B09B   3/00', 'B09B   3/00', 'B60K  16/00', 'B60K  16/00', 'B60L   8/00', 'B60L   8/00', 'B63B  35/00', 'B63H  13/00', 'B63H  19/02', 'B63H  19/04', 'C01B  33/02', 'C02F   1/14', 'C02F   1/16', 'C02F   3/28', 'C02F  11/04', 'C02F  11/04', 'C02F  11/14', 'C07C  67/00', 'C07C  69/00', 'C10B  53/00', 'C10B  53/02', 'C10J   3/02', 'C10J   3/46', 'C10J   3/86', 'C10L   1/00', 'C10L   1/02', 'C10L   1/02', 'C10L   1/02', 'C10L   1/02', 'C10L   1/14', 'C10L   1/182', 'C10L   1/19', 'C10L   1/19', 'C10L   3/00', 'C10L   3/00', 'C10L   5/00', 'C10L   5/00', 'C10L   5/40', 'C10L   5/42', 'C10L   5/44', 'C10L   5/46', 'C10L   5/48', 'C10L   9/00', 'C11C   3/10', 'C12M   1/107', 'C12N   1/13', 'C12N   1/15', 'C12N   1/21', 'C12N   5/10', 'C12N   9/24', 'C12N  15/00', 'C12P   5/02', 'C12P   7/64', 'C21B   5/06', 'C23C  14/14', 'C23C  16/24', 'C30B  29/06', 'D21C  11/00', 'D21F   5/20', 'E04D  13/00', 'E04D  13/18', 'E04H  12/00', 'F01K  17/00', 'F01K  23/04', 'F01K  23/06', 'F01K  23/08', 'F01K  23/10', 'F01K  27/00', 'F01N   5/00', 'F02C   1/05', 'F02C   3/28', 'F02C   6/18', 'F02G   5/00', 'F02G   5/02', 'F02G   5/04', 'F03B  13/12', 'F03B  13/14', 'F03B  13/16', 'F03B  13/18', 'F03B  13/20', 'F03B  13/22', 'F03B  13/24', 'F03B  13/26', 'F03D   1/04', 'F03D   9/00', 'F03D  13/00', 'F03D  13/20', 'F03G   4/00', 'F03G   4/02', 'F03G   4/04', 'F03G   4/06', 'F03G   5/00', 'F03G   5/02', 'F03G   5/04', 'F03G   5/06', 'F03G   5/08', 'F03G   6/00', 'F03G   6/00', 'F03G   6/02', 'F03G   6/04', 'F03G   6/06', 'F03G   7/04', 'F03G   7/05', 'F21L   4/00', 'F21S   9/03', 'F22B   1/00', 'F22B   1/02', 'F23B  90/00', 'F23G   5/00', 'F23G   5/00', 'F23G   5/00', 'F23G   5/027', 'F23G   5/46', 'F23G   7/00', 'F23G   7/00', 'F23G   7/00', 'F23G   7/00', 'F23G   7/10', 'F23G   7/10', 'F24D   3/00', 'F24D   5/00', 'F24D  11/00', 'F24D  11/02', 'F24D  15/04', 'F24D  17/00', 'F24D  17/02', 'F24D  19/00', 'F24F   5/00', 'F24F  12/00', 'F24H   4/00', 'F24S  10/10', 'F24S  23/00', 'F24S  90/00', 'F24T  10/00', 'F24T  10/10', 'F24T  10/13', 'F24T  10/15', 'F24T  10/17', 'F24T  10/20', 'F24T  10/30', 'F24T  10/40', 'F24T  50/00', 'F24V  30/00', 'F24V  30/00', 'F24V  40/00', 'F24V  40/10', 'F24V  50/00', 'F25B  27/00', 'F25B  27/02', 'F25B  27/02', 'F25B  30/00', 'F25B  30/06', 'F26B   3/00', 'F26B   3/28', 'F27D  17/00', 'F28D  17/00', 'F28D  17/02', 'F28D  17/04', 'F28D  19/00', 'F28D  19/02', 'F28D  19/04', 'F28D  20/00', 'F28D  20/02', 'G02B   7/183', 'G05F   1/67', 'H01G   9/20', 'H01G   9/20', 'H01L  25/00', 'H01L  25/03', 'H01L  25/16', 'H01L  25/18', 'H01L  27/142', 'H01L  27/30', 'H01L  31/00', 'H01L  31/02', 'H01L  31/0203', 'H01L  31/0216', 'H01L  31/0224', 'H01L  31/0232', 'H01L  31/0236', 'H01L  31/024', 'H01L  31/0248', 'H01L  31/0256', 'H01L  31/0264', 'H01L  31/0272', 'H01L  31/028', 'H01L  31/0288', 'H01L  31/0296', 'H01L  31/0304', 'H01L  31/0312', 'H01L  31/032', 'H01L  31/0328', 'H01L  31/0336', 'H01L  31/0352', 'H01L  31/036', 'H01L  31/0368', 'H01L  31/0376', 'H01L  31/0384', 'H01L  31/0392', 'H01L  31/04', 'H01L  31/041', 'H01L  31/042', 'H01L  31/042', 'H01L  31/043', 'H01L  31/044', 'H01L  31/0443', 'H01L  31/0445', 'H01L  31/046', 'H01L  31/0463', 'H01L  31/0465', 'H01L  31/0468', 'H01L  31/047', 'H01L  31/0475', 'H01L  31/048', 'H01L  31/049', 'H01L  31/05', 'H01L  31/052', 'H01L  31/0525', 'H01L  31/053', 'H01L  31/054', 'H01L  31/055', 'H01L  31/056', 'H01L  31/058', 'H01L  31/06', 'H01L  31/061', 'H01L  31/062', 'H01L  31/065', 'H01L  31/068', 'H01L  31/0687', 'H01L  31/0693', 'H01L  31/07', 'H01L  31/072', 'H01L  31/0725', 'H01L  31/073', 'H01L  31/0735', 'H01L  31/074', 'H01L  31/0745', 'H01L  31/0747', 'H01L  31/0749', 'H01L  31/075', 'H01L  31/076', 'H01L  31/077', 'H01L  31/078', 'H01L  51/42', 'H01L  51/44', 'H01L  51/46', 'H01L  51/48', 'H01M   2/00', 'H01M   2/02', 'H01M   2/04', 'H01M   4/86', 'H01M   4/88', 'H01M   4/90', 'H01M   4/92', 'H01M   4/94', 'H01M   4/96', 'H01M   4/98', 'H01M  12/00', 'H01M  12/02', 'H01M  12/04', 'H01M  12/06', 'H01M  12/08', 'H01M  14/00', 'H02J   7/35', 'H02K   7/18', 'H02N  10/00', 'H02S  10/00', 'H02S  40/44', 'A01H', 'B09B', 'B09B   1/00', 'B09B   3/00', 'B09B   5/00', 'C10G', 'C10J', 'C10J   1/00', 'C10J   1/02', 'C10J   1/04', 'C10J   1/06', 'C10J   1/08', 'C10J   1/10', 'C10J   1/12', 'C10J   1/14', 'C10J   1/16', 'C10J   1/18', 'C10J   1/20', 'C10J   1/207', 'C10J   1/213', 'C10J   1/22', 'C10J   1/24', 'C10J   1/26', 'C10J   1/28', 'C10J   3/00', 'C10J   3/02', 'C10J   3/04', 'C10J   3/06', 'C10J   3/08', 'C10J   3/10', 'C10J   3/12', 'C10J   3/14', 'C10J   3/16', 'C10J   3/18', 'C10J   3/20', 'C10J   3/22', 'C10J   3/24', 'C10J   3/26', 'C10J   3/28', 'C10J   3/30', 'C10J   3/32', 'C10J   3/34', 'C10J   3/36', 'C10J   3/38', 'C10J   3/40', 'C10J   3/42', 'C10J   3/44', 'C10J   3/46', 'C10J   3/48', 'C10J   3/50', 'C10J   3/52', 'C10J   3/54', 'C10J   3/56', 'C10J   3/57', 'C10J   3/58', 'C10J   3/60', 'C10J   3/62', 'C10J   3/64', 'C10J   3/66', 'C10J   3/72', 'C10J   3/74', 'C10J   3/76', 'C10J   3/78', 'C10J   3/80', 'C10J   3/82', 'C10J   3/84', 'C10J   3/86', 'F01K', 'F03B', 'F03C', 'F03D', 'F03D   1/00', 'F03D   1/02', 'F03D   1/04', 'F03D   1/06', 'F03D   3/00', 'F03D   3/02', 'F03D   3/04', 'F03D   3/06', 'F03D   5/00', 'F03D   5/02', 'F03D   5/04', 'F03D   5/06', 'F03D   7/00', 'F03D   7/02', 'F03D   7/04', 'F03D   7/06', 'F03D   9/00', 'F03D   9/10', 'F03D   9/11', 'F03D   9/12', 'F03D   9/13', 'F03D   9/14', 'F03D   9/16', 'F03D   9/17', 'F03D   9/18', 'F03D   9/19', 'F03D   9/20', 'F03D   9/22', 'F03D   9/25', 'F03D   9/28', 'F03D   9/30', 'F03D   9/32', 'F03D   9/34', 'F03D   9/35', 'F03D   9/37', 'F03D   9/39', 'F03D   9/41', 'F03D   9/43', 'F03D   9/45', 'F03D   9/46', 'F03D   9/48', 'F03D  13/00', 'F03D  13/10', 'F03D  13/20', 'F03D  13/25', 'F03D  13/30', 'F03D  13/35', 'F03D  13/40', 'F03D  15/00', 'F03D  15/10', 'F03D  15/20', 'F03D  17/00', 'F03D  80/00', 'F03D  80/10', 'F03D  80/20', 'F03D  80/30', 'F03D  80/40', 'F03D  80/50', 'F03D  80/55', 'F03D  80/60', 'F03D  80/70', 'F03D  80/80', 'F24S', 'F24S  10/00', 'F24S  10/10', 'F24S  10/13', 'F24S  10/17', 'F24S  10/20', 'F24S  10/25', 'F24S  10/30', 'F24S  10/40', 'F24S  10/50', 'F24S  10/55', 'F24S  10/60', 'F24S  10/70', 'F24S  10/75', 'F24S  10/80', 'F24S  10/90', 'F24S  10/95', 'F24S  20/00', 'F24S  20/20', 'F24S  20/25', 'F24S  20/30', 'F24S  20/40', 'F24S  20/50', 'F24S  20/55', 'F24S  20/60', 'F24S  20/61', 'F24S  20/62', 'F24S  20/63', 'F24S  20/64', 'F24S  20/66', 'F24S  20/67', 'F24S  20/69', 'F24S  20/70', 'F24S  20/80', 'F24S  21/00', 'F24S  23/00', 'F24S  23/30', 'F24S  23/70', 'F24S  23/71', 'F24S  23/72', 'F24S  23/74', 'F24S  23/75', 'F24S  23/77', 'F24S  23/79', 'F24S  25/00', 'F24S  25/10', 'F24S  25/11', 'F24S  25/12', 'F24S  25/13', 'F24S  25/15', 'F24S  25/16', 'F24S  25/20', 'F24S  25/30', 'F24S  25/33', 'F24S  25/35', 'F24S  25/37', 'F24S  25/40', 'F24S  25/50', 'F24S  25/60', 'F24S  25/61', 'F24S  25/613', 'F24S  25/615', 'F24S  25/617', 'F24S  25/63', 'F24S  25/632', 'F24S  25/634', 'F24S  25/636', 'F24S  25/65', 'F24S  25/67', 'F24S  25/70', 'F24S  30/00', 'F24S  30/20', 'F24S  30/40', 'F24S  30/42', 'F24S  30/422', 'F24S  30/425', 'F24S  30/428', 'F24S  30/45', 'F24S  30/452', 'F24S  30/455', 'F24S  30/458', 'F24S  30/48', 'F24S  40/00', 'F24S  40/10', 'F24S  40/20', 'F24S  40/40', 'F24S  40/42', 'F24S  40/44', 'F24S  40/46', 'F24S  40/48', 'F24S  40/50', 'F24S  40/52', 'F24S  40/53', 'F24S  40/55', 'F24S  40/57', 'F24S  40/58', 'F24S  40/60', 'F24S  40/70', 'F24S  40/80', 'F24S  40/90', 'F24S  50/00', 'F24S  50/20', 'F24S  50/40', 'F24S  50/60', 'F24S  50/80', 'F24S  60/00', 'F24S  60/10', 'F24S  60/20', 'F24S  60/30', 'F24S  70/00', 'F24S  70/10', 'F24S  70/12', 'F24S  70/14', 'F24S  70/16', 'F24S  70/20', 'F24S  70/225', 'F24S  70/25', 'F24S  70/275', 'F24S  70/30', 'F24S  70/60', 'F24S  70/65', 'F24S  80/00', 'F24S  80/10', 'F24S  80/20', 'F24S  80/30', 'F24S  80/40', 'F24S  80/45', 'F24S  80/453', 'F24S  80/457', 'F24S  80/50', 'F24S  80/52', 'F24S  80/525', 'F24S  80/54', 'F24S  80/56', 'F24S  80/58', 'F24S  80/60', 'F24S  80/65', 'F24S  80/70', 'F24S  90/00', 'F24S  90/10', 'F24T', 'F24T  10/00', 'F24T  10/10', 'F24T  10/13', 'F24T  10/15', 'F24T  10/17', 'F24T  10/20', 'F24T  10/30', 'F24T  10/40', 'F24T  50/00', 'H02S', 'H02S  10/00', 'H02S  10/10', 'H02S  10/12', 'H02S  10/20', 'H02S  10/30', 'H02S  10/40', 'H02S  20/00', 'H02S  20/10', 'H02S  20/20', 'H02S  20/21', 'H02S  20/22', 'H02S  20/23', 'H02S  20/24', 'H02S  20/25', 'H02S  20/26', 'H02S  20/30', 'H02S  20/32', 'H02S  30/00', 'H02S  30/10', 'H02S  30/20', 'H02S  40/00', 'H02S  40/10', 'H02S  40/12', 'H02S  40/20', 'H02S  40/22', 'H02S  40/30', 'H02S  40/32', 'H02S  40/34', 'H02S  40/36', 'H02S  40/38', 'H02S  40/40', 'H02S  40/42', 'H02S  40/44', 'H02S  50/00', 'H02S  50/10', 'H02S  50/15', 'H02S  99/00', 'C10L   5/00', 'C10L   5/02', 'C10L   5/04', 'C10L   5/06', 'C10L   5/08', 'C10L   5/10', 'C10L   5/12', 'C10L   5/14', 'C10L   5/16', 'C10L   5/18', 'C10L   5/20', 'C10L   5/22', 'C10L   5/24', 'C10L   5/26', 'C10L   5/28', 'C10L   5/30', 'C10L   5/32', 'C10L   5/34', 'C10L   5/36', 'C10L   5/38', 'C10L   5/40', 'C10L   5/42', 'C10L   5/44', 'C10L   5/46', 'C10L   5/48', 'C12P   7/00', 'C12P   7/02', 'C12P   7/04', 'C12P   7/06', 'C12P   7/08', 'C12P   7/10', 'C12P   7/12', 'C12P   7/14', 'C12P   7/16', 'C12P   7/18', 'C12P   7/20', 'C12P   7/22', 'C12P   7/24', 'C12P   7/26', 'C12P   7/28', 'C12P   7/30', 'C12P   7/32', 'C12P   7/34', 'C12P   7/36', 'C12P   7/38', 'C12P   7/40', 'C12P   7/42', 'C12P   7/44', 'C12P   7/46', 'C12P   7/48', 'C12P   7/50', 'C12P   7/52', 'C12P   7/54', 'C12P   7/56', 'C12P   7/58', 'C12P   7/60', 'C12P   7/62', 'C12P   7/64', 'C12P   7/66', 'E02B   9/00', 'E02B   9/02', 'E02B   9/04', 'E02B   9/06', 'E02B   9/08', 'F03B  15/00', 'F03B  15/02', 'F03B  15/04', 'F03B  15/06', 'F03B  15/08', 'F03B  15/10', 'F03B  15/12', 'F03B  15/14', 'F03B  15/16', 'F03B  15/18', 'F03B  15/20', 'F03B  15/22', 'H01M   8/00', 'H01M   8/008', 'H01M   8/02', 'H01M   8/0202', 'H01M   8/0204', 'H01M   8/0206', 'H01M   8/0208', 'H01M   8/021', 'H01M   8/0213', 'H01M   8/0215', 'H01M   8/0217', 'H01M   8/0221', 'H01M   8/0223', 'H01M   8/0226', 'H01M   8/0228', 'H01M   8/023', 'H01M   8/0232', 'H01M   8/0234', 'H01M   8/0236', 'H01M   8/0239', 'H01M   8/0241', 'H01M   8/0243', 'H01M   8/0245', 'H01M   8/0247', 'H01M   8/025', 'H01M   8/0252', 'H01M   8/0254', 'H01M   8/0256', 'H01M   8/0258', 'H01M   8/026', 'H01M   8/0263', 'H01M   8/0265', 'H01M   8/0267', 'H01M   8/0271', 'H01M   8/0273', 'H01M   8/0276', 'H01M   8/028', 'H01M   8/0282', 'H01M   8/0284', 'H01M   8/0286', 'H01M   8/0289', 'H01M   8/0293', 'H01M   8/0295', 'H01M   8/0297', 'H01M   8/04', 'H01M   8/04007', 'H01M   8/04014', 'H01M   8/04029', 'H01M   8/04044', 'H01M   8/04082', 'H01M   8/04089', 'H01M   8/04111', 'H01M   8/04119', 'H01M   8/04186', 'H01M   8/04223', 'H01M   8/04225', 'H01M   8/04228', 'H01M   8/04276', 'H01M   8/04291', 'H01M   8/04298', 'H01M   8/043', 'H01M   8/04302', 'H01M   8/04303', 'H01M   8/04313', 'H01M   8/0432', 'H01M   8/0438', 'H01M   8/0444', 'H01M   8/04492', 'H01M   8/04537', 'H01M   8/04664', 'H01M   8/04694', 'H01M   8/04701', 'H01M   8/04746', 'H01M   8/04791', 'H01M   8/04828', 'H01M   8/04858', 'H01M   8/04955', 'H01M   8/04992', 'H01M   8/06', 'H01M   8/0606', 'H01M   8/0612', 'H01M   8/0637', 'H01M   8/065', 'H01M   8/0656', 'H01M   8/0662', 'H01M   8/0668', 'H01M   8/08', 'H01M   8/083', 'H01M   8/086', 'H01M   8/10', 'H01M   8/1004', 'H01M   8/1006', 'H01M   8/1007', 'H01M   8/1009', 'H01M   8/1011', 'H01M   8/1016', 'H01M   8/1018', 'H01M   8/102', 'H01M   8/1023', 'H01M   8/1025', 'H01M   8/1027', 'H01M   8/103', 'H01M   8/1032', 'H01M   8/1034', 'H01M   8/1037', 'H01M   8/1039', 'H01M   8/1041', 'H01M   8/1044', 'H01M   8/1046', 'H01M   8/1048', 'H01M   8/1051', 'H01M   8/1053', 'H01M   8/1058', 'H01M   8/106', 'H01M   8/1062', 'H01M   8/1065', 'H01M   8/1067', 'H01M   8/1069', 'H01M   8/1072', 'H01M   8/1081', 'H01M   8/1086', 'H01M   8/1088', 'H01M   8/1097', 'H01M   8/12', 'H01M   8/1213', 'H01M   8/122', 'H01M   8/1226', 'H01M   8/1231', 'H01M   8/1233', 'H01M   8/124', 'H01M   8/1246', 'H01M   8/1253', 'H01M   8/126', 'H01M   8/1286', 'H01M   8/14', 'H01M   8/16', 'H01M   8/18', 'H01M   8/20', 'H01M   8/22', 'H01M   8/24', 'H01M   8/2404', 'H01M   8/241', 'H01M   8/2418', 'H01M   8/242', 'H01M   8/2425', 'H01M   8/2428', 'H01M   8/243', 'H01M   8/2432', 'H01M   8/2435', 'H01M   8/244', 'H01M   8/2455', 'H01M   8/2457', 'H01M   8/2465', 'H01M   8/247', 'H01M   8/2475', 'H01M   8/248', 'H01M   8/2483', 'H01M   8/2484', 'H01M   8/2485', 'H01M   8/249', 'H01M   8/2495', 'B60K   6/00', 'B60K   6/20', 'B60K  16/00', 'B60L   7/10', 'B60L   7/12', 'B60L   7/14', 'B60L   7/16', 'B60L   7/18', 'B60L   7/20', 'B60L   7/22', 'B60L   8/00', 'B60L   9/00', 'B61D  17/02', 'B62D  35/00', 'B62D  35/02', 'B62M   1/00', 'B62M   3/00', 'B62M   5/00', 'B62M   6/00', 'B63B   1/34', 'B63B   1/36', 'B63B   1/38', 'B63B   1/40', 'B63H   9/00', 'B63H  13/00', 'B63H  16/00', 'B63H  19/02', 'B63H  19/04', 'B63H  21/18', 'B64G   1/44', 'F02B  43/00', 'F02M  21/02', 'F02M  27/02', 'H02J   7/00', 'H02K  29/08', 'H02K  49/10', 'B61B', 'B61B   1/00', 'B61B   1/02', 'B61B   3/00', 'B61B   3/02', 'B61B   5/00', 'B61B   5/02', 'B61B   7/00', 'B61B   7/02', 'B61B   7/04', 'B61B   7/06', 'B61B   9/00', 'B61B  10/00', 'B61B  10/02', 'B61B  10/04', 'B61B  11/00', 'B61B  12/00', 'B61B  12/02', 'B61B  12/04', 'B61B  12/06', 'B61B  12/08', 'B61B  12/10', 'B61B  12/12', 'B61B  13/00', 'B61B  13/02', 'B61B  13/04', 'B61B  13/06', 'B61B  13/08', 'B61B  13/10', 'B61B  13/12', 'B61B  15/00', 'B62K', 'B62K   1/00', 'B62K   3/00', 'B62K   3/02', 'B62K   3/04', 'B62K   3/06', 'B62K   3/08', 'B62K   3/10', 'B62K   3/12', 'B62K   3/14', 'B62K   3/16', 'B62K   5/00', 'B62K   5/003', 'B62K   5/007', 'B62K   5/01', 'B62K   5/02', 'B62K   5/023', 'B62K   5/025', 'B62K   5/027', 'B62K   5/05', 'B62K   5/06', 'B62K   5/08', 'B62K   5/10', 'B62K   7/00', 'B62K   7/02', 'B62K   7/04', 'B62K   9/00', 'B62K   9/02', 'B62K  11/00', 'B62K  11/02', 'B62K  11/04', 'B62K  11/06', 'B62K  11/08', 'B62K  11/10', 'B62K  11/12', 'B62K  11/14', 'B62K  13/00', 'B62K  13/02', 'B62K  13/04', 'B62K  13/06', 'B62K  13/08', 'B62K  15/00', 'B62K  17/00', 'B62K  19/00', 'B62K  19/02', 'B62K  19/04', 'B62K  19/06', 'B62K  19/08', 'B62K  19/10', 'B62K  19/12', 'B62K  19/14', 'B62K  19/16', 'B62K  19/18', 'B62K  19/20', 'B62K  19/22', 'B62K  19/24', 'B62K  19/26', 'B62K  19/28', 'B62K  19/30', 'B62K  19/32', 'B62K  19/34', 'B62K  19/36', 'B62K  19/38', 'B62K  19/40', 'B62K  19/42', 'B62K  19/44', 'B62K  19/46', 'B62K  19/48', 'B62K  21/00', 'B62K  21/02', 'B62K  21/04', 'B62K  21/06', 'B62K  21/08', 'B62K  21/10', 'B62K  21/12', 'B62K  21/14', 'B62K  21/16', 'B62K  21/18', 'B62K  21/20', 'B62K  21/22', 'B62K  21/24', 'B62K  21/26', 'B62K  23/00', 'B62K  23/02', 'B62K  23/04', 'B62K  23/06', 'B62K  23/08', 'B62K  25/00', 'B62K  25/02', 'B62K  25/04', 'B62K  25/06', 'B62K  25/08', 'B62K  25/10', 'B62K  25/12', 'B62K  25/14', 'B62K  25/16', 'B62K  25/18', 'B62K  25/20', 'B62K  25/22', 'B62K  25/24', 'B62K  25/26', 'B62K  25/28', 'B62K  25/30', 'B62K  25/32', 'B62K  27/00', 'B62K  27/02', 'B62K  27/04', 'B62K  27/06', 'B62K  27/08', 'B62K  27/10', 'B62K  27/12', 'B62K  27/14', 'B62K  27/16', 'B60L  50/00', 'B60L  50/10', 'B60L  50/11', 'B60L  50/12', 'B60L  50/13', 'B60L  50/14', 'B60L  50/15', 'B60L  50/16', 'B60L  50/20', 'B60L  50/30', 'B60L  50/40', 'B60L  50/50', 'B60L  50/51', 'B60L  50/52', 'B60L  50/53', 'B60L  50/60', 'B60L  50/61', 'B60L  50/62', 'B60L  50/64', 'B60L  50/70', 'B60L  50/71', 'B60L  50/72', 'B60L  50/75', 'B60L  50/90', 'B60L  53/00', 'B60L  53/10', 'B60L  53/12', 'B60L  53/122', 'B60L  53/124', 'B60L  53/126', 'B60L  53/14', 'B60L  53/16', 'B60L  53/18', 'B60L  53/20', 'B60L  53/22', 'B60L  53/24', 'B60L  53/30', 'B60L  53/302', 'B60L  53/31', 'B60L  53/34', 'B60L  53/35', 'B60L  53/36', 'B60L  53/37', 'B60L  53/38', 'B60L  53/39', 'B60L  53/50', 'B60L  53/51', 'B60L  53/52', 'B60L  53/53', 'B60L  53/54', 'B60L  53/55', 'B60L  53/56', 'B60L  53/57', 'B60L  53/60', 'B60L  53/62', 'B60L  53/63', 'B60L  53/64', 'B60L  53/65', 'B60L  53/66', 'B60L  53/67', 'B60L  53/68', 'B60L  53/80', 'B60L  55/00', 'B60L  58/00', 'B60L  58/10', 'B60L  58/12', 'B60L  58/13', 'B60L  58/14', 'B60L  58/15', 'B60L  58/16', 'B60L  58/18', 'B60L  58/19', 'B60L  58/20', 'B60L  58/21', 'B60L  58/22', 'B60L  58/24', 'B60L  58/25', 'B60L  58/26', 'B60L  58/27', 'B60L  58/30', 'B60L  58/31', 'B60L  58/32', 'B60L  58/33', 'B60L  58/34', 'B60L  58/40', 'B60K   6/10', 'B60K   6/28', 'B60K   6/30', 'B60L   3/00', 'B60L  50/30', 'B60W  10/26', 'C09K   5/00', 'E04B   1/62', 'E04B   1/74', 'E04B   1/76', 'E04B   1/78', 'E04B   1/80', 'E04B   1/88', 'E04B   1/90', 'E04B   2/00', 'E04B   5/00', 'E04B   7/00', 'E04B   9/00', 'E04C   1/40', 'E04C   1/41', 'E04C   2/284', 'E04C   2/288', 'E04C   2/292', 'E04C   2/296', 'E04D   1/28', 'E04D   3/35', 'E04D  13/16', 'E04F  13/08', 'E04F  13/08', 'E04F  15/18', 'E06B   3/263', 'F03G   7/08', 'F21K  99/00', 'F21L   4/02', 'F24H   7/00', 'F28D  20/00', 'F28D  20/02', 'H01G  11/00', 'H01L  51/50', 'H01M  10/44', 'H01M  10/46', 'H02J   3/28', 'H02J   7/00', 'H02J   9/00', 'H02J  15/00', 'H05B  33/00', 'G01R', 'H02J', 'H02J   1/00', 'H02J   1/02', 'H02J   1/04', 'H02J   1/06', 'H02J   1/08', 'H02J   1/10', 'H02J   1/12', 'H02J   1/14', 'H02J   1/16', 'H02J   3/00', 'H02J   3/01', 'H02J   3/02', 'H02J   3/04', 'H02J   3/06', 'H02J   3/08', 'H02J   3/10', 'H02J   3/12', 'H02J   3/14', 'H02J   3/16', 'H02J   3/18', 'H02J   3/20', 'H02J   3/22', 'H02J   3/24', 'H02J   3/26', 'H02J   3/28', 'H02J   3/30', 'H02J   3/32', 'H02J   3/34', 'H02J   3/36', 'H02J   3/38', 'H02J   3/40', 'H02J   3/42', 'H02J   3/44', 'H02J   3/46', 'H02J   3/48', 'H02J   3/50', 'H02J   4/00', 'H02J   5/00', 'H02J   7/00', 'H02J   7/02', 'H02J   7/04', 'H02J   7/06', 'H02J   7/08', 'H02J   7/10', 'H02J   7/12', 'H02J   7/14', 'H02J   7/16', 'H02J   7/18', 'H02J   7/20', 'H02J   7/22', 'H02J   7/24', 'H02J   7/26', 'H02J   7/28', 'H02J   7/30', 'H02J   7/32', 'H02J   7/34', 'H02J   7/35', 'H02J   7/36', 'H02J   9/00', 'H02J   9/02', 'H02J   9/04', 'H02J   9/06', 'H02J   9/08', 'H02J  11/00', 'H02J  13/00', 'H02J  15/00', 'H02J  50/00', 'H02J  50/05', 'H02J  50/10', 'H02J  50/12', 'H02J  50/15', 'H02J  50/20', 'H02J  50/23', 'H02J  50/27', 'H02J  50/30', 'H02J  50/40', 'H02J  50/50', 'H02J  50/60', 'H02J  50/70', 'H02J  50/80', 'H02J  50/90', 'H02J  50/90', 'H01L  33/00', 'H01L  33/02', 'H01L  33/04', 'H01L  33/06', 'H01L  33/08', 'H01L  33/10', 'H01L  33/12', 'H01L  33/14', 'H01L  33/16', 'H01L  33/18', 'H01L  33/20', 'H01L  33/22', 'H01L  33/24', 'H01L  33/26', 'H01L  33/28', 'H01L  33/30', 'H01L  33/32', 'H01L  33/34', 'H01L  33/36', 'H01L  33/38', 'H01L  33/40', 'H01L  33/42', 'H01L  33/44', 'H01L  33/46', 'H01L  33/48', 'H01L  33/50', 'H01L  33/52', 'H01L  33/54', 'H01L  33/56', 'H01L  33/58', 'H01L  33/60', 'H01L  33/62', 'H01L  33/64', 'B63B  35/32', 'B63B  35/32', 'B63J   4/00', 'B63J   4/00', 'C02F   1/00', 'C02F   1/00', 'C02F   3/00', 'C02F   3/00', 'C02F   9/00', 'C02F   9/00', 'C05F   7/00', 'C05F   7/00', 'C09K   3/32', 'C09K   3/32', 'E02B  15/04', 'E02B  15/04', 'E03C   1/12', 'E03C   1/12', 'A43B   1/12', 'A43B  21/14', 'A61L  11/00', 'A62D   3/00', 'A62D 101/00', 'B01D  53/14', 'B01D  53/22', 'B01D  53/62', 'B03B   9/06', 'B22F   8/00', 'B65G   5/00', 'C01B  32/50', 'C04B   7/24', 'C04B   7/26', 'C04B   7/28', 'C04B   7/30', 'C04B  18/04', 'C04B  18/06', 'C04B  18/08', 'C04B  18/10', 'C09K  11/01', 'C11B  11/00', 'C14C   3/32', 'C21B   3/04', 'C25C   1/00', 'D21B   1/08', 'D21B   1/32', 'E21B  41/00', 'E21B  43/16', 'E21F  17/16', 'F25J   3/02', 'G21C  13/10', 'G21F   9/00', 'B09B', 'B09B   1/00', 'B09B   3/00', 'B09B   5/00', 'B09C', 'B09C   1/00', 'B09C   1/02', 'B09C   1/04', 'B09C   1/06', 'B09C   1/08', 'B09C   1/10', 'B65F', 'B65F   1/00', 'B65F   1/02', 'B65F   1/04', 'B65F   1/06', 'B65F   1/08', 'B65F   1/10', 'B65F   1/12', 'B65F   1/14', 'B65F   1/16', 'B65F   3/00', 'B65F   3/02', 'B65F   3/04', 'B65F   3/06', 'B65F   3/08', 'B65F   3/10', 'B65F   3/12', 'B65F   3/14', 'B65F   3/16', 'B65F   3/18', 'B65F   3/20', 'B65F   3/22', 'B65F   3/24', 'B65F   3/26', 'B65F   3/28', 'B65F   5/00', 'B65F   7/00', 'B65F   9/00', 'C05F', 'C05F   1/00', 'C05F   1/02', 'C05F   3/00', 'C05F   3/02', 'C05F   3/04', 'C05F   3/06', 'C05F   5/00', 'C05F   7/00', 'C05F   7/02', 'C05F   7/04', 'C05F   9/00', 'C05F   9/02', 'C05F   9/04', 'C05F  11/00', 'C05F  11/02', 'C05F  11/04', 'C05F  11/06', 'C05F  11/08', 'C05F  11/10', 'C05F  15/00', 'C05F  17/00', 'C05F  17/05', 'C05F  17/10', 'C05F  17/20', 'C05F  17/30', 'C05F  17/40', 'C05F  17/50', 'C05F  17/60', 'C05F  17/70', 'C05F  17/80', 'C05F  17/90', 'C05F  17/907', 'C05F  17/914', 'C05F  17/921', 'C05F  17/929', 'C05F  17/936', 'C05F  17/943', 'C05F  17/95', 'C05F  17/957', 'C05F  17/964', 'C05F  17/971', 'C05F  17/979', 'C05F  17/986', 'C05F  17/993', 'F23G', 'F23G   1/00', 'F23G   5/00', 'F23G   5/02', 'F23G   5/027', 'F23G   5/033', 'F23G   5/04', 'F23G   5/05', 'F23G   5/08', 'F23G   5/10', 'F23G   5/12', 'F23G   5/14', 'F23G   5/16', 'F23G   5/18', 'F23G   5/20', 'F23G   5/22', 'F23G   5/24', 'F23G   5/26', 'F23G   5/28', 'F23G   5/30', 'F23G   5/32', 'F23G   5/34', 'F23G   5/36', 'F23G   5/38', 'F23G   5/40', 'F23G   5/42', 'F23G   5/44', 'F23G   5/46', 'F23G   5/48', 'F23G   5/50', 'F23G   7/00', 'F23G   7/02', 'F23G   7/04', 'F23G   7/05', 'F23G   7/06', 'F23G   7/07', 'F23G   7/08', 'F23G   7/10', 'F23G   7/12', 'F23G   7/14', 'C08J  11/00', 'C08J  11/02', 'C08J  11/04', 'C08J  11/06', 'C08J  11/08', 'C08J  11/10', 'C08J  11/12', 'C08J  11/14', 'C08J  11/16', 'C08J  11/18', 'C08J  11/20', 'C08J  11/22', 'C08J  11/24', 'C08J  11/26', 'C08J  11/28', 'C11B  13/00', 'C11B  13/02', 'C11B  13/04', 'D01F  13/00', 'D01F  13/02', 'D01F  13/04', 'C02F', 'C02F   1/00', 'C02F   1/02', 'C02F   1/04', 'C02F   1/06', 'C02F   1/08', 'C02F   1/10', 'C02F   1/12', 'C02F   1/14', 'C02F   1/16', 'C02F   1/18', 'C02F   1/20', 'C02F   1/22', 'C02F   1/24', 'C02F   1/26', 'C02F   1/28', 'C02F   1/30', 'C02F   1/32', 'C02F   1/34', 'C02F   1/36', 'C02F   1/38', 'C02F   1/40', 'C02F   1/42', 'C02F   1/44', 'C02F   1/46', 'C02F   1/461', 'C02F   1/463', 'C02F   1/465', 'C02F   1/467', 'C02F   1/469', 'C02F   1/48', 'C02F   1/50', 'C02F   1/52', 'C02F   1/54', 'C02F   1/56', 'C02F   1/58', 'C02F   1/60', 'C02F   1/62', 'C02F   1/64', 'C02F   1/66', 'C02F   1/68', 'C02F   1/70', 'C02F   1/72', 'C02F   1/74', 'C02F   1/76', 'C02F   1/78', 'C02F   3/00', 'C02F   3/02', 'C02F   3/04', 'C02F   3/06', 'C02F   3/08', 'C02F   3/10', 'C02F   3/12', 'C02F   3/14', 'C02F   3/16', 'C02F   3/18', 'C02F   3/20', 'C02F   3/22', 'C02F   3/24', 'C02F   3/26', 'C02F   3/28', 'C02F   3/30', 'C02F   3/32', 'C02F   3/34', 'C02F   5/00', 'C02F   5/02', 'C02F   5/04', 'C02F   5/06', 'C02F   5/08', 'C02F   5/10', 'C02F   5/12', 'C02F   5/14', 'C02F   7/00', 'C02F   9/00', 'C02F   9/02', 'C02F   9/04', 'C02F   9/06', 'C02F   9/08', 'C02F   9/10', 'C02F   9/12', 'C02F   9/14', 'C02F  11/00', 'C02F  11/02', 'C02F  11/04', 'C02F  11/06', 'C02F  11/08', 'C02F  11/10', 'C02F  11/12', 'C02F  11/121', 'C02F  11/122', 'C02F  11/123', 'C02F  11/125', 'C02F  11/126', 'C02F  11/127', 'C02F  11/128', 'C02F  11/13', 'C02F  11/131', 'C02F  11/14', 'C02F  11/143', 'C02F  11/145', 'C02F  11/147', 'C02F  11/148', 'C02F  11/15', 'C02F  11/16', 'C02F  11/18', 'C02F  11/20', 'C02F 101/00', 'C02F 101/10', 'C02F 101/12', 'C02F 101/14', 'C02F 101/16', 'C02F 101/18', 'C02F 101/20', 'C02F 101/22', 'C02F 101/30', 'C02F 101/32', 'C02F 101/34', 'C02F 101/36', 'C02F 101/38', 'C02F 103/00', 'C02F 103/02', 'C02F 103/04', 'C02F 103/06', 'C02F 103/08', 'C02F 103/10', 'C02F 103/12', 'C02F 103/14', 'C02F 103/16', 'C02F 103/18', 'C02F 103/20', 'C02F 103/22', 'C02F 103/24', 'C02F 103/26', 'C02F 103/28', 'C02F 103/30', 'C02F 103/32', 'C02F 103/34', 'C02F 103/36', 'C02F 103/38', 'C02F 103/40', 'C02F 103/42', 'C02F 103/44', 'E03F', 'E03F   1/00', 'E03F   3/00', 'E03F   3/02', 'E03F   3/04', 'E03F   3/06', 'E03F   5/00', 'E03F   5/02', 'E03F   5/04', 'E03F   5/042', 'E03F   5/046', 'E03F   5/06', 'E03F   5/08', 'E03F   5/10', 'E03F   5/12', 'E03F   5/14', 'E03F   5/16', 'E03F   5/18', 'E03F   5/20', 'E03F   5/22', 'E03F   5/24', 'E03F   5/26', 'E03F   7/00', 'E03F   7/02', 'E03F   7/04', 'E03F   7/06', 'E03F   7/08', 'E03F   7/10', 'E03F   7/12', 'E03F   9/00', 'E03F 11/00', 'A01G  23/00', 'A01G  25/00', 'C09K  17/00', 'E02D   3/00', 'C05F', 'C05F   1/00', 'C05F   1/02', 'C05F   3/00', 'C05F   3/02', 'C05F   3/04', 'C05F   3/06', 'C05F   5/00', 'C05F   7/00', 'C05F   7/02', 'C05F   7/04', 'C05F   9/00', 'C05F   9/02', 'C05F   9/04', 'C05F  11/00', 'C05F  11/02', 'C05F  11/04', 'C05F  11/06', 'C05F  11/08', 'C05F  11/10', 'C05F  15/00', 'C05F  17/00', 'C05F  17/05', 'C05F  17/10', 'C05F  17/20', 'C05F  17/30', 'C05F  17/40', 'C05F  17/50', 'C05F  17/60', 'C05F  17/70', 'C05F  17/80', 'C05F  17/90', 'C05F  17/907', 'C05F  17/914', 'C05F  17/921', 'C05F  17/929', 'C05F  17/936', 'C05F  17/943', 'C05F  17/95', 'C05F  17/957', 'C05F  17/964', 'C05F  17/971', 'C05F  17/979', 'C05F  17/986', 'C05F  17/993', 'A01N  25/00', 'A01N  25/02', 'A01N  25/04', 'A01N  25/06', 'A01N  25/08', 'A01N  25/10', 'A01N  25/12', 'A01N  25/14', 'A01N  25/16', 'A01N  25/18', 'A01N  25/20', 'A01N  25/22', 'A01N  25/24', 'A01N  25/26', 'A01N  25/28', 'A01N  25/30', 'A01N  25/32', 'A01N  25/34', 'A01N  27/00', 'A01N  29/00', 'A01N  29/02', 'A01N  29/04', 'A01N  29/06', 'A01N  29/08', 'A01N  29/10', 'A01N  29/12', 'A01N  31/00', 'A01N  31/02', 'A01N  31/04', 'A01N  31/06', 'A01N  31/08', 'A01N  31/10', 'A01N  31/12', 'A01N  31/14', 'A01N  31/16', 'A01N  33/00', 'A01N  33/02', 'A01N  33/04', 'A01N  33/06', 'A01N  33/08', 'A01N  33/10', 'A01N  33/12', 'A01N  33/14', 'A01N  33/16', 'A01N  33/18', 'A01N  33/20', 'A01N  33/22', 'A01N  33/24', 'A01N  33/26', 'A01N  35/00', 'A01N  35/02', 'A01N  35/04', 'A01N  35/06', 'A01N  35/08', 'A01N  35/10', 'A01N  37/00', 'A01N  37/02', 'A01N  37/04', 'A01N  37/06', 'A01N  37/08', 'A01N  37/10', 'A01N  37/12', 'A01N  37/14', 'A01N  37/16', 'A01N  37/18', 'A01N  37/20', 'A01N  37/22', 'A01N  37/24', 'A01N  37/26', 'A01N  37/28', 'A01N  37/30', 'A01N  37/32', 'A01N  37/34', 'A01N  37/36', 'A01N  37/38', 'A01N  37/40', 'A01N  37/42', 'A01N  37/44', 'A01N  37/46', 'A01N  37/48', 'A01N  37/50', 'A01N  37/52', 'A01N  39/00', 'A01N  39/02', 'A01N  39/04', 'A01N  41/00', 'A01N  41/02', 'A01N  41/04', 'A01N  41/06', 'A01N  41/08', 'A01N  41/10', 'A01N  41/12', 'A01N  43/00', 'A01N  43/02', 'A01N  43/04', 'A01N  43/06', 'A01N  43/08', 'A01N  43/10', 'A01N  43/12', 'A01N  43/14', 'A01N  43/16', 'A01N  43/18', 'A01N  43/20', 'A01N  43/22', 'A01N  43/24', 'A01N  43/26', 'A01N  43/28', 'A01N  43/30', 'A01N  43/32', 'A01N  43/34', 'A01N  43/36', 'A01N  43/38', 'A01N  43/40', 'A01N  43/42', 'A01N  43/44', 'A01N  43/46', 'A01N  43/48', 'A01N  43/50', 'A01N  43/52', 'A01N  43/54', 'A01N  43/56', 'A01N  43/58', 'A01N  43/60', 'A01N  43/62', 'A01N  43/64', 'A01N  43/647', 'A01N  43/653', 'A01N  43/66', 'A01N  43/68', 'A01N  43/70', 'A01N  43/707', 'A01N  43/713', 'A01N  43/72', 'A01N  43/74', 'A01N  43/76', 'A01N  43/78', 'A01N  43/80', 'A01N  43/82', 'A01N  43/824', 'A01N  43/828', 'A01N  43/832', 'A01N  43/836', 'A01N  43/84', 'A01N  43/86', 'A01N  43/88', 'A01N  43/90', 'A01N  43/92', 'A01N  45/00', 'A01N  45/02', 'A01N  47/00', 'A01N  47/02', 'A01N  47/04', 'A01N  47/06', 'A01N  47/08', 'A01N  47/10', 'A01N  47/12', 'A01N  47/14', 'A01N  47/16', 'A01N  47/18', 'A01N  47/20', 'A01N  47/22', 'A01N  47/24', 'A01N  47/26', 'A01N  47/28', 'A01N  47/30', 'A01N  47/32', 'A01N  47/34', 'A01N  47/36', 'A01N  47/38', 'A01N  47/40', 'A01N  47/42', 'A01N  47/44', 'A01N  47/46', 'A01N  47/48', 'A01N  49/00', 'A01N  51/00', 'A01N  53/00', 'A01N  53/02', 'A01N  53/04', 'A01N  53/06', 'A01N  53/08', 'A01N  53/10', 'A01N  53/12', 'A01N  53/14', 'A01N  55/00', 'A01N  55/02', 'A01N  55/04', 'A01N  55/06', 'A01N  55/08', 'A01N  55/10', 'A01N  57/00', 'A01N  57/02', 'A01N  57/04', 'A01N  57/06', 'A01N  57/08', 'A01N  57/10', 'A01N  57/12', 'A01N  57/14', 'A01N  57/16', 'A01N  57/18', 'A01N  57/20', 'A01N  57/22', 'A01N  57/24', 'A01N  57/26', 'A01N  57/28', 'A01N  57/30', 'A01N  57/32', 'A01N  57/34', 'A01N  57/36', 'A01N  59/00', 'A01N  59/02', 'A01N  59/04', 'A01N  59/06', 'A01N  59/08', 'A01N  59/10', 'A01N  59/12', 'A01N  59/14', 'A01N  59/16', 'A01N  59/18', 'A01N  59/20', 'A01N  59/22', 'A01N  59/24', 'A01N  59/26', 'A01N  61/00', 'A01N  61/02', 'A01N  63/00', 'A01N  63/10', 'A01N  63/12', 'A01N  63/14', 'A01N  63/16', 'A01N  63/20', 'A01N  63/22', 'A01N  63/23', 'A01N  63/25', 'A01N  63/27', 'A01N  63/28', 'A01N  63/30', 'A01N  63/32', 'A01N  63/34', 'A01N  63/36', 'A01N  63/38', 'A01N  63/40', 'A01N  63/50', 'A01N  63/60', 'A01N  65/00', 'A01N  65/03', 'A01N  65/04', 'A01N  65/06', 'A01N  65/08', 'A01N  65/10', 'A01N  65/12', 'A01N  65/14', 'A01N  65/16', 'A01N  65/18', 'A01N  65/20', 'A01N  65/22', 'A01N  65/24', 'A01N  65/26', 'A01N  65/28', 'A01N  65/30', 'A01N  65/32', 'A01N  65/34', 'A01N  65/36', 'A01N  65/38', 'A01N  65/40', 'A01N  65/42', 'A01N  65/44', 'A01N  65/46', 'A01N  65/48', 'E04H   1/00', 'G06Q', 'F02C   1/05', 'G21B', 'G21B   1/00', 'G21B   1/01', 'G21B   1/03', 'G21B   1/05', 'G21B   1/11', 'G21B   1/13', 'G21B   1/15', 'G21B   1/17', 'G21B   1/19', 'G21B   1/21', 'G21B   1/23', 'G21B   1/25', 'G21B   3/00', 'G21C', 'G21C   1/00', 'G21C   1/02', 'G21C   1/03', 'G21C   1/04', 'G21C   1/06', 'G21C   1/07', 'G21C   1/08', 'G21C   1/09', 'G21C   1/10', 'G21C   1/12', 'G21C   1/14', 'G21C   1/16', 'G21C   1/18', 'G21C   1/20', 'G21C   1/22', 'G21C   1/24', 'G21C   1/26', 'G21C   1/28', 'G21C   1/30', 'G21C   1/32', 'G21C   3/00', 'G21C   3/02', 'G21C   3/04', 'G21C   3/06', 'G21C   3/07', 'G21C   3/08', 'G21C   3/10', 'G21C   3/12', 'G21C   3/14', 'G21C   3/16', 'G21C   3/17', 'G21C   3/18', 'G21C   3/20', 'G21C   3/22', 'G21C   3/24', 'G21C   3/26', 'G21C   3/28', 'G21C   3/30', 'G21C   3/32', 'G21C   3/322', 'G21C   3/324', 'G21C   3/326', 'G21C   3/328', 'G21C   3/33', 'G21C   3/332', 'G21C   3/334', 'G21C   3/335', 'G21C   3/336', 'G21C   3/338', 'G21C   3/34', 'G21C   3/344', 'G21C   3/348', 'G21C   3/352', 'G21C   3/356', 'G21C   3/36', 'G21C   3/38', 'G21C   3/40', 'G21C   3/42', 'G21C   3/44', 'G21C   3/46', 'G21C   3/48', 'G21C   3/50', 'G21C   3/52', 'G21C   3/54', 'G21C   3/56', 'G21C   3/58', 'G21C   3/60', 'G21C   3/62', 'G21C   3/64', 'G21C   5/00', 'G21C   5/02', 'G21C   5/04', 'G21C   5/06', 'G21C   5/08', 'G21C   5/10', 'G21C   5/12', 'G21C   5/14', 'G21C   5/16', 'G21C   5/18', 'G21C   5/20', 'G21C   5/22', 'G21C   7/00', 'G21C   7/02', 'G21C   7/04', 'G21C   7/06', 'G21C   7/08', 'G21C   7/10', 'G21C   7/103', 'G21C   7/107', 'G21C   7/11', 'G21C   7/113', 'G21C   7/117', 'G21C   7/12', 'G21C   7/14', 'G21C   7/16', 'G21C   7/18', 'G21C   7/20', 'G21C   7/22', 'G21C   7/24', 'G21C   7/26', 'G21C   7/27', 'G21C   7/28', 'G21C   7/30', 'G21C   7/32', 'G21C   7/34', 'G21C   7/36', 'G21C   9/00', 'G21C   9/004', 'G21C   9/008', 'G21C   9/012', 'G21C   9/016', 'G21C   9/02', 'G21C   9/027', 'G21C   9/033', 'G21C   9/04', 'G21C   9/06', 'G21C  11/00', 'G21C  11/02', 'G21C  11/04', 'G21C  11/06', 'G21C  11/08', 'G21C  13/00', 'G21C  13/02', 'G21C  13/024', 'G21C  13/028', 'G21C  13/032', 'G21C  13/036', 'G21C  13/04', 'G21C  13/06', 'G21C  13/067', 'G21C  13/073', 'G21C  13/08', 'G21C  13/087', 'G21C  13/093', 'G21C  13/10', 'G21C  15/00', 'G21C  15/02', 'G21C  15/04', 'G21C  15/06', 'G21C  15/08', 'G21C  15/10', 'G21C  15/12', 'G21C  15/14', 'G21C  15/16', 'G21C  15/18', 'G21C  15/20', 'G21C  15/22', 'G21C  15/24', 'G21C  15/243', 'G21C  15/247', 'G21C  15/25', 'G21C  15/253', 'G21C  15/257', 'G21C  15/26', 'G21C  15/28', 'G21C  17/00', 'G21C  17/003', 'G21C  17/007', 'G21C  17/01', 'G21C  17/013', 'G21C  17/017', 'G21C  17/02', 'G21C  17/022', 'G21C  17/025', 'G21C  17/028', 'G21C  17/032', 'G21C  17/035', 'G21C  17/038', 'G21C  17/04', 'G21C  17/06', 'G21C  17/07', 'G21C  17/08', 'G21C  17/10', 'G21C  17/104', 'G21C  17/108', 'G21C  17/112', 'G21C  17/116', 'G21C  17/12', 'G21C  17/14', 'G21C  19/00', 'G21C  19/02', 'G21C  19/04', 'G21C  19/06', 'G21C  19/07', 'G21C  19/08', 'G21C  19/10', 'G21C  19/105', 'G21C  19/11', 'G21C  19/115', 'G21C  19/12', 'G21C  19/14', 'G21C  19/16', 'G21C  19/18', 'G21C  19/19', 'G21C  19/20', 'G21C  19/22', 'G21C  19/24', 'G21C  19/26', 'G21C  19/28', 'G21C  19/30', 'G21C  19/303', 'G21C  19/307', 'G21C  19/31', 'G21C  19/313', 'G21C  19/317', 'G21C  19/32', 'G21C  19/33', 'G21C  19/34', 'G21C  19/36', 'G21C  19/365', 'G21C  19/37', 'G21C  19/375', 'G21C  19/38', 'G21C  19/40', 'G21C  19/42', 'G21C  19/44', 'G21C  19/46', 'G21C  19/48', 'G21C  19/50', 'G21C  21/00', 'G21C  21/02', 'G21C  21/04', 'G21C  21/06', 'G21C  21/08', 'G21C  21/10', 'G21C  21/12', 'G21C  21/14', 'G21C  21/16', 'G21C  21/18', 'G21C  23/00', 'G21D', 'G21D   1/00', 'G21D   1/02', 'G21D   1/04', 'G21D   3/00', 'G21D   3/02', 'G21D   3/04', 'G21D   3/06', 'G21D   3/08', 'G21D   3/10', 'G21D   3/12', 'G21D   3/14', 'G21D   3/16', 'G21D   3/18', 'G21D   5/00', 'G21D   5/02', 'G21D   5/04', 'G21D   5/06', 'G21D   5/08', 'G21D   5/10', 'G21D   5/12', 'G21D   5/14', 'G21D   5/16', 'G21D   7/00', 'G21D   7/02', 'G21D   7/04', 'G21D   9/00', 'G21F', 'G21F   1/00', 'G21F   1/02', 'G21F   1/04', 'G21F   1/06', 'G21F   1/08', 'G21F   1/10', 'G21F   1/12', 'G21F   3/00', 'G21F   3/02', 'G21F   3/025', 'G21F   3/03', 'G21F   3/035', 'G21F   3/04', 'G21F   5/00', 'G21F   5/002', 'G21F   5/005', 'G21F   5/008', 'G21F   5/012', 'G21F   5/015', 'G21F   5/018', 'G21F   5/02', 'G21F   5/04', 'G21F   5/06', 'G21F   5/08', 'G21F   5/10', 'G21F   5/12', 'G21F   5/14', 'G21F   7/00', 'G21F   7/005', 'G21F   7/01', 'G21F   7/015', 'G21F   7/02', 'G21F   7/03', 'G21F   7/04', 'G21F   7/047', 'G21F   7/053', 'G21F   7/06', 'G21F   9/00', 'G21F   9/02', 'G21F   9/04', 'G21F   9/06', 'G21F   9/08', 'G21F   9/10', 'G21F   9/12', 'G21F   9/14', 'G21F   9/16', 'G21F   9/18', 'G21F   9/20', 'G21F   9/22', 'G21F   9/24', 'G21F   9/26', 'G21F   9/28', 'G21F   9/30', 'G21F   9/32', 'G21F   9/34', 'G21F   9/36', 'G21G', 'G21G   1/00', 'G21G   1/02', 'G21G   1/04', 'G21G   1/06', 'G21G   1/08', 'G21G   1/10', 'G21G   1/12', 'G21G   4/00', 'G21G   4/02', 'G21G   4/04', 'G21G   4/06', 'G21G   4/08', 'G21G   4/10', 'G21G   5/00', 'G21G   7/00', 'G21H', 'G21H   1/00', 'G21H   1/02', 'G21H   1/04', 'G21H   1/06', 'G21H   1/08', 'G21H   1/10', 'G21H   1/12', 'G21H   3/00', 'G21H   3/02', 'G21H   5/00', 'G21H   5/02', 'G21H   7/00', 'G21J', 'G21J   1/00', 'G21J   3/00', 'G21J   3/02', 'G21J   5/00', 'G21K', 'G21K   1/00', 'G21K   1/02', 'G21K   1/04', 'G21K   1/06', 'G21K   1/08', 'G21K   1/087', 'G21K   1/093', 'G21K   1/10', 'G21K   1/12', 'G21K   1/14', 'G21K   1/16', 'G21K   3/00', 'G21K   4/00', 'G21K   5/00', 'G21K   5/02', 'G21K   5/04', 'G21K   5/08', 'G21K   5/10', 'G21K   7/00', 'F01K', 'F01K   1/00', 'F01K   1/02', 'F01K   1/04', 'F01K   1/06', 'F01K   1/08', 'F01K   1/10', 'F01K   1/12', 'F01K   1/14', 'F01K   1/16', 'F01K   1/18', 'F01K   1/20', 'F01K   3/00', 'F01K   3/02', 'F01K   3/04', 'F01K   3/06', 'F01K   3/08', 'F01K   3/10', 'F01K   3/12', 'F01K   3/14', 'F01K   3/16', 'F01K   3/18', 'F01K   3/20', 'F01K   3/22', 'F01K   3/24', 'F01K   3/26', 'F01K   5/00', 'F01K   5/02', 'F01K   7/00', 'F01K   7/02', 'F01K   7/04', 'F01K   7/06', 'F01K   7/08', 'F01K   7/10', 'F01K   7/12', 'F01K   7/14', 'F01K   7/16', 'F01K   7/18', 'F01K   7/20', 'F01K   7/22', 'F01K   7/24', 'F01K   7/26', 'F01K   7/28', 'F01K   7/30', 'F01K   7/32', 'F01K   7/34', 'F01K   7/36', 'F01K   7/38', 'F01K   7/40', 'F01K   7/42', 'F01K   7/44', 'F01K   9/00', 'F01K   9/02', 'F01K   9/04', 'F01K  11/00', 'F01K  11/02', 'F01K  11/04', 'F01K  13/00', 'F01K  13/02', 'F01K  15/00', 'F01K  15/02', 'F01K  15/04', 'F01K  17/00', 'F01K  17/02', 'F01K  17/04', 'F01K  17/06', 'F01K  19/00', 'F01K  19/02', 'F01K  19/04', 'F01K  19/06', 'F01K  19/08', 'F01K  19/10', 'F01K  21/00', 'F01K  21/02', 'F01K  21/04', 'F01K  21/06', 'F01K  23/00', 'F01K  23/02', 'F01K  23/04', 'F01K  23/06', 'F01K  23/08', 'F01K  23/10', 'F01K  23/12', 'F01K  23/14', 'F01K  23/16', 'F01K  23/18', 'F01K  25/00', 'F01K  25/02', 'F01K  25/04', 'F01K  25/06', 'F01K  25/08', 'F01K  25/10', 'F01K  25/12', 'F01K  25/14', 'F01K  27/00', 'F01K  27/02', 'C10G   3/00', 'F03B', 'F03B   1/00', 'F03B   1/02', 'F03B   1/04', 'F03B   3/00', 'F03B   3/02', 'F03B   3/04', 'F03B   3/06', 'F03B   3/08', 'F03B   3/10', 'F03B   3/12', 'F03B   3/14', 'F03B   3/16', 'F03B   3/18', 'F03B   5/00', 'F03B   7/00', 'F03B   9/00', 'F03B  11/00', 'F03B  11/02', 'F03B  11/04', 'F03B  11/06', 'F03B  11/08', 'F03B  13/00', 'F03B  13/02', 'F03B  13/04', 'F03B  13/06', 'F03B  13/08', 'F03B  13/10', 'F03B  13/12', 'F03B  13/14', 'F03B  13/16', 'F03B  13/18', 'F03B  13/20', 'F03B  13/22', 'F03B  13/24', 'F03B  13/26', 'F03B  15/00', 'F03B  15/02', 'F03B  15/04', 'F03B  15/06', 'F03B  15/08', 'F03B  15/10', 'F03B  15/12', 'F03B  15/14', 'F03B  15/16', 'F03B  15/18', 'F03B  15/20', 'F03B  15/22', 'F03B  17/00', 'F03B  17/02', 'F03B  17/04', 'F03B  17/06') THEN
			1
		ELSE
			0
		END);
		
--Query 2 OK: UPDATE 143002504, 143002504 rows affected

--Counting the unique innovations: 25 667 791

SELECT
	count(DISTINCT docdb_family_id)
FROM
	frac_oecd_cpc;

--41092283

SELECT
	count(DISTINCT docdb_family_id)
FROM
	frac_oecd_ipc;

--41092283

--Global counts per category for both CPC and IPC

SELECT
	earliest_filing_year,
	cpc_green,
	sum(frac) AS count
FROM
	frac_oecd_cpc
GROUP BY
	cpc_green,
	earliest_filing_year;

SELECT
	earliest_filing_year,
	ipc_green,
	sum(frac) AS count
FROM
	frac_oecd_ipc
GROUP BY
	ipc_green,
	earliest_filing_year;


--Counts per country

SELECT
	earliest_filing_year,
	ctry_code,
	cpc_green,
	sum(frac) AS count
FROM
	frac_oecd_cpc
GROUP BY
	cpc_green,
	ctry_code,
	earliest_filing_year;

SELECT
	earliest_filing_year,
	ctry_code,
	ipc_green,
	sum(frac) AS count
FROM
	frac_oecd_ipc
GROUP BY
	ipc_green,
	ctry_code,
	earliest_filing_year;