-- raw data to be able look at it in any time.

SELECT *
FROM players;

SELECT *
FROM school_details;

SELECT *
FROM schools;

SELECT *
FROM salaries;

-- Task 1. In each decade, how many schools were there that produced MLB players?

    SELECT FLOOR(yearID/10)*10 AS the_decade, COUNT(DISTINCT schoolID) AS num_of_schools
	FROM schools
    GROUP BY FLOOR(yearID/10)*10;

-- Task 2. What are the names of the top 5 schools that produced the most players?
WITH r AS (SELECT schoolID, COUNT(DISTINCT playerID) as number_of_players,
			ROW_NUMBER() OVER(ORDER BY COUNT(DISTINCT playerID) DESC) AS ranking 
			FROM schools
			GROUP BY schoolID)
SELECT name_full, number_of_players
FROM r 
LEFT JOIN school_details sd
ON r.schoolID = sd.schoolID
WHERE ranking <6;

-- Task 3. For each decade, what were the names of the top 3 schools that produced the most players?
WITH num AS (SELECT FLOOR(yearID/10)*10 AS the_decade, schoolID, COUNT(DISTINCT playerID) AS num_of_pl,
			 ROW_NUMBER() OVER (partition by FLOOR(yearID/10)*10 ORDER BY COUNT(DISTINCT playerID) DESC) AS ranking
		FROM schools
		GROUP BY FLOOR(yearID/10)*10,schoolID
        ORDER BY COUNT(DISTINCT playerID) DESC)
        
SELECT name_full, the_decade, num_of_pl
FROM num
INNER JOIN school_details sd
ON sd.schoolID = num.schoolID
WHERE ranking <4
ORDER BY the_decade DESC;

-- Task 4. Return the top 20% of teams in terms of average annual spending


WITH n AS (SELECT teamID, ROUND(AVG(s)/1000000,1) AS avg_mil_spending, NTILE(5) OVER(ORDER BY AVG(s) DESC) AS ranking
			FROM( SELECT yearID, teamID, SUM(salary) AS s
			FROM salaries
			GROUP BY yearID, teamID) AS t
			GROUP BY teamID)
SELECT teamID, avg_mil_spending
FROM n
WHERE ranking = 1;

-- Task 5. For each team, show the cumulative sum of spending over the years

WITH S AS (SELECT yearID, teamID, SUM(salary) AS salary
			FROM salaries
			GROUP BY  yearID, teamID)
SELECT yearID, teamID,
ROUND(SUM(salary) OVER (partition by teamID ORDER BY yearID)/1000000,1) AS sum_mil_sal
FROM S;

-- Task 6. Return the first year that each team’s cumulative spending surpassed 1 billion

WITH S AS (SELECT yearID, teamID, SUM(salary) AS salary
			FROM salaries
			GROUP BY  yearID, teamID),
	M AS (SELECT yearID, teamID,
			ROUND(SUM(salary) OVER (partition by teamID ORDER BY yearID)/1000000000,2) AS sum_bil_sal
			FROM S),
	R AS (SELECT yearID, teamID, sum_bil_sal,
			ROW_NUMBER() OVER(partition by teamID ORDER BY yearID) AS ranking 
			FROM M 
			WHERE sum_bil_sal > 1)
SELECT yearID, teamID, sum_bil_sal
FROM R 
WHERE ranking = 1;

-- Task 7. For each player, calculate their age at their first (debut) game, their last game, and their career length (all in years). Sort from longest career to shortest career.
WITH ad AS (SELECT nameGiven,
			STR_TO_DATE(CONCAT(birthYear, "-", birthMonth, "-", birthDay), '%Y-%m-%d') AS date_of_birth,
			debut AS debut,
			finalGame AS finalGame
			FROM players)
SELECT nameGiven,
timestampdiff(YEAR, date_of_birth, debut) AS starting_age,
timestampdiff(YEAR, date_of_birth, finalGame) AS ending_age,
timestampdiff(YEAR, debut, finalGame) AS career_length
FROM ad
ORDER BY timestampdiff(YEAR, debut, finalGame) DESC;

-- Task 8. What team did each player play on for their starting and ending years?

SELECT nameGiven, YEAR(debut) AS starting_year, s1.teamID AS start_team, YEAR(finalGame) AS ending_year, s2.teamID AS final_team
FROM players p
INNER JOIN salaries s1
ON p.playerID = s1.playerID AND s1.yearID = YEAR(debut)
INNER JOIN salaries s2
ON p.playerID = s2.playerID AND s2.yearID = YEAR(finalGame)
ORDER BY s1.teamID, YEAR(debut);

-- Task 9. How many players started and ended on the same team and also played for over a decade?

WITH mm AS (SELECT MIN(yearID) AS start_year, MAX(yearID) AS final_year, playerID
			FROM salaries
			GROUP BY playerID),
almost_final AS (SELECT mm.playerID, start_year, s1.teamID AS start_team, final_year, s2.teamID AS final_team
					FROM mm 
					INNER JOIN salaries s1
					ON s1.yearID = start_year AND s1.playerID = mm.playerID
					INNER JOIN salaries s2
					ON s2.yearID = final_year AND s2.playerID = mm.playerID)
SELECT COUNT(DISTINCT playerID) AS number_of_players
FROM almost_final
WHERE start_team IS NOT NULL
  AND final_team IS NOT NULL
  AND start_team = final_team
  AND final_year - start_year > 9;

-- Task 10. Which players have the same birthday?

WITH t1 AS (SELECT 
			DATE(CONCAT(birthYear, "-", birthMonth, "-", birthDay)) AS date_of_birth, nameGiven
			FROM players
            WHERE birthYear IS NOT NULL
    AND birthMonth IS NOT NULL
    AND birthDay IS NOT NULL
)
SELECT
  date_of_birth,
  GROUP_CONCAT(nameGiven SEPARATOR ', ') AS players
FROM t1
GROUP BY date_of_birth
ORDER BY date_of_birth;

-- Task 11. Create a summary table that shows for each team, what percent of players bat right, left and both.

WITH base AS (SELECT teamID,
				SUM(CASE WHEN bats = "R" THEN 1 ELSE 0 END) AS right_hand,
				SUM(CASE WHEN bats = "L" THEN 1 ELSE 0 END) AS left_hand,
				SUM(CASE WHEN bats = "B" THEN 1 ELSE 0 END) AS both_hand,
				SUM(CASE WHEN bats = "R" or bats = "L" or bats = "B" THEN 1 ELSE 0 END) AS sum_for_any
				FROM players p
				INNER JOIN salaries s
				ON p.playerId = s.playerID
				GROUP BY teamID)
SELECT teamID, 
ROUND(right_hand/sum_for_any*100,1) AS right_hand_percent,
ROUND(left_hand/sum_for_any*100,1) AS left_hand_percent,
ROUND(both_hand/sum_for_any*100,1) AS both_hand_percent
FROM base
ORDER BY teamID;

-- Task 12. How have average height and weight at debut game changed over the years, and what’s the decade-over-decade difference?

WITH base AS (SELECT FLOOR(YEAR(debut)/10)*10 AS decades, AVG(weight) AS avg_weight, AVG(height) AS avg_height
				FROM players
				WHERE FLOOR(YEAR(debut)/10)*10 IS NOT NULL
				GROUP BY FLOOR(YEAR(debut)/10)*10
				ORDER BY FLOOR(YEAR(debut)/10)*10)

SELECT *
FROM (SELECT decades, avg_weight - LAG(avg_weight) OVER(ORDER BY decades) AS weight_diff, avg_height - LAG(avg_height) OVER(ORDER BY decades) AS leight_diff
FROM base) AS base2
WHERE weight_diff is not null;