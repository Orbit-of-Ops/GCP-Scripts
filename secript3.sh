#!/bin/bash
clear

# ==============================================================================
# ORBIT OF OPS AUTOMATION: GSP787 BIGQUERY CHALLENGE LAB
# ==============================================================================
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
CYAN=$(tput setaf 6)
MAGENTA=$(tput setaf 5)
WHITE=$(tput setaf 7)
BOLD=$(tput bold)
RESET=$(tput sgr0)

echo "${CYAN}${BOLD}"
echo "   ____       _     _ _            __   ___             "
echo "  / __ \     | |   (_) |          / _| / _ \            "
echo " | |  | |_ __| |__  _| |_   ___  | |_ | | | |_ __  ___  "
echo " | |  | | '__| '_ \| | __| / _ \ |  _|| | | | '_ \/ __| "
echo " | |__| | |  | |_) | | |_ | (_) || |  | |_| | |_) \__ \ "
echo "  \____/|_|  |_.__/|_|\__| \___/ |_|   \___/| .__/|___/ "
echo "                                            | |         "
echo "                                            |_|         "
echo "${RESET}"
echo "${MAGENTA}${BOLD}>>> INITIATING ORBIT OF OPS BIGQUERY AUTOMATION <<<${RESET}"
echo ""
echo "${WHITE}${BOLD}Gather the randomized variables from your lab instructions!${RESET}"
echo "Use the strict format YYYY-MM-DD for dates (e.g., 2020-04-15)."
echo ""

# --- VARIABLE COLLECTION ---
echo "${YELLOW}${BOLD}--- TASK 1 & 2 ---${RESET}"
read -p "Task 1 & 2 Date (YYYY-MM-DD): " T1_DATE
read -p "Task 2 Death Count Threshold: " T2_DEATHS

echo -e "\n${YELLOW}${BOLD}--- TASK 3 ---${RESET}"
read -p "Task 3 Date (YYYY-MM-DD): " T3_DATE
read -p "Task 3 Confirmed Cases Threshold: " T3_CASES

echo -e "\n${YELLOW}${BOLD}--- TASK 4 ---${RESET}"
read -p "Task 4 Start Date (e.g., 1st of the month, YYYY-MM-DD): " T4_START
read -p "Task 4 End Date (e.g., 31st of the month, YYYY-MM-DD): " T4_END

echo -e "\n${YELLOW}${BOLD}--- TASK 5 ---${RESET}"
read -p "Task 5 Death Count Threshold: " T5_DEATHS

echo -e "\n${YELLOW}${BOLD}--- TASK 6 ---${RESET}"
read -p "Task 6 Start Date in India (YYYY-MM-DD): " T6_START
read -p "Task 6 Close Date in India (YYYY-MM-DD): " T6_END

echo -e "\n${YELLOW}${BOLD}--- TASK 7 & 8 ---${RESET}"
read -p "Task 7 Percentage Increase Limit (e.g., 10): " T7_LIMIT
read -p "Task 8 Top Country Limit (e.g., 10): " T8_LIMIT

echo -e "\n${YELLOW}${BOLD}--- TASK 9 ---${RESET}"
read -p "Task 9 Last Day Date (YYYY-MM-DD): " T9_DATE

echo -e "\n${YELLOW}${BOLD}--- TASK 10 ---${RESET}"
read -p "Task 10 Date Range START (YYYY-MM-DD): " T10_START
read -p "Task 10 Date Range END (YYYY-MM-DD): " T10_END

echo -e "\n${CYAN}${BOLD}[*] ALL VARIABLES SECURED. EXECUTING BIGQUERY JOBS...${RESET}\n"

# --- TASK EXECUTION ---
echo "${GREEN}[*] Task 1: Total confirmed cases...${RESET}"
bq query --use_legacy_sql=false "SELECT sum(cumulative_confirmed) as total_cases_worldwide FROM \`bigquery-public-data.covid19_open_data.covid19_open_data\` WHERE date='${T1_DATE}'"

echo "${GREEN}[*] Task 2: Worst affected areas...${RESET}"
bq query --use_legacy_sql=false "WITH deaths_by_states AS (SELECT subregion1_name as state, sum(cumulative_deceased) as death_count FROM \`bigquery-public-data.covid19_open_data.covid19_open_data\` WHERE country_name='United States of America' AND date='${T1_DATE}' AND subregion1_name IS NOT NULL GROUP BY subregion1_name) SELECT count(*) as count_of_states FROM deaths_by_states WHERE death_count > ${T2_DEATHS}"

echo "${GREEN}[*] Task 3: Identify hotspots...${RESET}"
bq query --use_legacy_sql=false "SELECT * FROM (SELECT subregion1_name as state, sum(cumulative_confirmed) as total_confirmed_cases FROM \`bigquery-public-data.covid19_open_data.covid19_open_data\` WHERE country_code='US' AND date='${T3_DATE}' AND subregion1_name IS NOT NULL GROUP BY subregion1_name ORDER BY total_confirmed_cases DESC) WHERE total_confirmed_cases > ${T3_CASES}"

echo "${GREEN}[*] Task 4: Fatality ratio...${RESET}"
bq query --use_legacy_sql=false "SELECT sum(cumulative_confirmed) as total_confirmed_cases, sum(cumulative_deceased) as total_deaths, (sum(cumulative_deceased)/sum(cumulative_confirmed))*100 as case_fatality_ratio FROM \`bigquery-public-data.covid19_open_data.covid19_open_data\` WHERE country_name='Italy' AND date BETWEEN '${T4_START}' AND '${T4_END}'"

echo "${GREEN}[*] Task 5: Identify a specific day...${RESET}"
bq query --use_legacy_sql=false "SELECT date FROM \`bigquery-public-data.covid19_open_data.covid19_open_data\` WHERE country_name='Italy' AND cumulative_deceased > ${T5_DEATHS} ORDER BY date ASC LIMIT 1"

echo "${GREEN}[*] Task 6: Find days with zero net new cases...${RESET}"
bq query --use_legacy_sql=false "WITH india_cases_by_date AS (SELECT date, SUM(cumulative_confirmed) AS cases FROM \`bigquery-public-data.covid19_open_data.covid19_open_data\` WHERE country_name ='India' AND date BETWEEN '${T6_START}' AND '${T6_END}' GROUP BY date ORDER BY date ASC), india_previous_day_comparison AS (SELECT date, cases, LAG(cases) OVER(ORDER BY date) AS previous_day, cases - LAG(cases) OVER(ORDER BY date) AS net_new_cases FROM india_cases_by_date) SELECT count(*) FROM india_previous_day_comparison WHERE net_new_cases = 0"

echo "${GREEN}[*] Task 7: Doubling rate...${RESET}"
bq query --use_legacy_sql=false "WITH us_cases_by_date AS (SELECT date, SUM(cumulative_confirmed) AS cases FROM \`bigquery-public-data.covid19_open_data.covid19_open_data\` WHERE country_name='United States of America' AND date BETWEEN '2020-03-22' AND '2020-04-20' GROUP BY date ORDER BY date ASC), us_previous_day_comparison AS (SELECT date, cases, LAG(cases) OVER(ORDER BY date) AS previous_day, cases - LAG(cases) OVER(ORDER BY date) AS net_new_cases, (cases - LAG(cases) OVER(ORDER BY date))*100/LAG(cases) OVER(ORDER BY date) AS percentage_increase FROM us_cases_by_date) SELECT Date, cases AS Confirmed_Cases_On_Day, previous_day AS Confirmed_Cases_Previous_Day, percentage_increase AS Percentage_Increase_In_Cases FROM us_previous_day_comparison WHERE percentage_increase > ${T7_LIMIT}"

echo "${GREEN}[*] Task 8: Recovery rate...${RESET}"
bq query --use_legacy_sql=false "WITH cases_by_country AS (SELECT country_name AS country, sum(cumulative_confirmed) AS cases, sum(cumulative_recovered) AS recovered_cases FROM \`bigquery-public-data.covid19_open_data.covid19_open_data\` WHERE date = '2020-05-10' GROUP BY country_name), recovered_rate AS (SELECT country, cases, recovered_cases, (recovered_cases * 100)/cases AS recovery_rate FROM cases_by_country) SELECT country, cases AS confirmed_cases, recovered_cases, recovery_rate FROM recovered_rate WHERE cases > 50000 ORDER BY recovery_rate DESC LIMIT ${T8_LIMIT}"

echo "${GREEN}[*] Task 9: CDGR...${RESET}"
bq query --use_legacy_sql=false "WITH france_cases AS (SELECT date, SUM(cumulative_confirmed) AS total_cases FROM \`bigquery-public-data.covid19_open_data.covid19_open_data\` WHERE country_name='France' AND date IN ('2020-01-24', '${T9_DATE}') GROUP BY date ORDER BY date), summary AS (SELECT total_cases AS first_day_cases, LEAD(total_cases) OVER(ORDER BY date) AS last_day_cases, DATE_DIFF(LEAD(date) OVER(ORDER BY date), date, day) AS days_diff FROM france_cases LIMIT 1) SELECT first_day_cases, last_day_cases, days_diff, POWER((last_day_cases/first_day_cases),(1/days_diff))-1 AS cdgr FROM summary"

echo "${GREEN}[*] Task 10: Generating Data Studio Query...${RESET}"
bq query --use_legacy_sql=false "SELECT date, SUM(cumulative_confirmed) AS country_cases, SUM(cumulative_deceased) AS country_deaths FROM \`bigquery-public-data.covid19_open_data.covid19_open_data\` WHERE date BETWEEN '${T10_START}' AND '${T10_END}' AND country_name ='United States of America' GROUP BY date ORDER BY date"

echo -e "\n${MAGENTA}${BOLD}====================================================================${RESET}"
echo "${MAGENTA}${BOLD}>>> ORBIT OF OPS PIPELINE COMPLETE! <<<${RESET}"
echo "${MAGENTA}${BOLD}====================================================================${RESET}"
echo "${WHITE}${BOLD}Click 'Check my progress' on ALL 10 tasks in your lab manual!${RESET}"
echo ""
echo "${YELLOW}NOTE FOR TASK 10:${RESET} Running the query via CLI is usually enough to pass."
echo "If Task 10 does not turn green, open Looker Studio, choose BigQuery connector,"
echo "Custom Query, and paste the Task 10 SQL manually."
echo "===================================================================="
