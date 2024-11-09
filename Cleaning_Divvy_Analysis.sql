-- 1. Creation of combined table for 1 year (March 2023 to February 2024) ------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------------------------------

USE Case_study_velo;

CREATE TABLE Case_study_velo.velo_combined AS
SELECT * FROM Case_study_velo.velo_202303
UNION ALL
SELECT * FROM Case_study_velo.velo_202304
UNION ALL
SELECT * FROM Case_study_velo.velo_202305
UNION ALL
SELECT * FROM Case_study_velo.velo_202306
UNION ALL
SELECT * FROM Case_study_velo.velo_202307
UNION ALL
SELECT * FROM Case_study_velo.velo_202308
UNION ALL
SELECT * FROM Case_study_velo.velo_202309
UNION ALL
SELECT * FROM Case_study_velo.velo_202310
UNION ALL
SELECT * FROM Case_study_velo.velo_202311
UNION ALL
SELECT * FROM Case_study_velo.velo_202312
UNION ALL
SELECT * FROM Case_study_velo.velo_202401
UNION ALL
SELECT * FROM Case_study_velo.velo_202402;

SELECT * FROM velo_combined;


-- -----------------------------------------------------------------------------------------------------------------------------
-- 2. Cleaning datas -----------------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------------------------------

-- Ride_ID ---------------------------------------------------------------------------------------------------------------------

-- Trimming the values 
UPDATE velo_combined SET ride_id = TRIM(ride_id);
UPDATE velo_combined SET rideable_type = TRIM(rideable_type);
UPDATE velo_combined SET start_station_name = TRIM(start_station_name);
UPDATE velo_combined SET start_station_id = TRIM(start_station_id);
UPDATE velo_combined SET end_station_name = TRIM(end_station_name);
UPDATE velo_combined SET end_station_id = TRIM(end_station_id);
UPDATE velo_combined SET member_casual = TRIM(member_casual);

-- Checking for duplicates : Count total number of rows and distinct ride IDs 
SELECT COUNT(*), COUNT(DISTINCT ride_id) 
FROM velo_combined;


-- Rideable_type ---------------------------------------------------------------------------------------------------------------

-- Check rideable_type 
SELECT rideable_type, COUNT(*) AS count
FROM velo_combined
GROUP BY rideable_type;
-- 3 rideable types : electrique_bike, classic_bike, docked_bike
-- docked_bike is the old name for classic_bike (seen in the archives)

-- we replace docked by classic 
UPDATE velo_combined
SET rideable_type = 'classic_bike'
WHERE rideable_type = 'docked_bike';


-- Time coherence ---------------------------------------------------------------------------------------------------------------

-- Checking missing values
SELECT *
FROM velo_combined
WHERE started_at IS NULL OR ended_at IS NULL;

-- Checking if the time is coherent : started_at should occur before ended_at
SELECT count(*) AS incoherent_time
FROM velo_combined
WHERE started_at >= ended_at OR started_at IS NULL OR ended_at IS NULL;
-- There are 1377 instances where the start time occurs after the end time, not signicant, can be removed
DELETE FROM velo_combined
WHERE started_at >= ended_at OR started_at IS NULL OR ended_at IS NULL;

-- Creation column ride_length_minute : time of the ride in minute
ALTER TABLE velo_combined
ADD ride_length_minute INT;
select * from velo_combined;

-- Calculate the duration of each ride
UPDATE velo_combined
SET ride_length_minute = TIMESTAMPDIFF(MINUTE,started_at, ended_at);

-- Checking the duration of rides
SELECT 
    MAX(ride_length_minute) AS max_ride_length_minute,
    MIN(ride_length_minute) AS min_ride_length_minute
FROM velo_combined;

-- Checking how many rides times are more that 6 hours 
SELECT COUNT(*)
FROM velo_combined
WHERE ride_length_minute > 6*60 ; 
-- We have 13 158 rides over 6 hours

-- Which type of bike have more rides over 6 hours
SELECT rideable_type, COUNT(*)
FROM velo_combined
WHERE ride_length_minute > 6*60
GROUP BY rideable_type;
-- 12 360 classic_bike VS 798 electric_bike rides over 6 hours

-- For the classic_bike, they should have an end_station_name
SELECT rideable_type, count(*)
FROM velo_combined
WHERE ride_length_minute > 6*60 
	AND (end_station_name IS NULL OR end_station_name='') 
	AND (end_station_id IS NULL OR end_station_id='') 
GROUP BY rideable_type ;
-- 7 111 classic_bike  (624 electric_bike) rides over 6 hours without end_station_name

-- If they have the same start and end station, with over 6 hours rides, it could be a problem of ride
SELECT COUNT(*) 
FROM velo_combined
WHERE ride_length_minute > 6*60 AND (start_station_id = end_station_id OR start_station_name  = end_station_name) ;
-- 1 594 have the same start and end station 

-- I choose to delete these 12 360 rides over 6 hours
DELETE FROM velo_combined
WHERE ride_length_minute > 6*60

-- Checking how many rides times are under 1 min
SELECT COUNT(*)
FROM velo_combined
WHERE ride_length_minute <= 0 ; 
-- There are 144366 rides under 1 min 

-- Checking how many rides times are under 1 min with the same start and end or without the data
SELECT COUNT(*)
FROM velo_combined
WHERE ride_length_minute <= 0
	AND ( start_station_name = end_station_name  
			OR start_station_id = end_station_id 
			OR (start_lat = end_lat AND start_lng = end_lng ) 
			OR start_station_name = '' OR start_station_name IS NULL
			OR end_station_name = '' OR end_station_name IS NULL );
-- There are 140 853 rides 

-- These rides should be errors or malfunctioning bikes, I decide to delete this data
DELETE FROM velo_combined
WHERE ride_length_minute <= 0;


-- Checking the stations names and id --------------------------------------------------------------------------------------------


-- Create a table to check the stations names and ids -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --- -- -- -- -- -- -- -- -- --
USE Case_study_velo;

CREATE TABLE Case_study_velo.test_combined AS
SELECT * FROM Case_study_velo.velo_202303
UNION ALL
SELECT * FROM Case_study_velo.velo_202304
UNION ALL
SELECT * FROM Case_study_velo.velo_202305
UNION ALL
SELECT * FROM Case_study_velo.velo_202306
UNION ALL
SELECT * FROM Case_study_velo.velo_202307
UNION ALL
SELECT * FROM Case_study_velo.velo_202308
UNION ALL
SELECT * FROM Case_study_velo.velo_202309
UNION ALL
SELECT * FROM Case_study_velo.velo_202310
UNION ALL
SELECT * FROM Case_study_velo.velo_202311
UNION ALL
SELECT * FROM Case_study_velo.velo_202312
UNION ALL
SELECT * FROM Case_study_velo.velo_202401
UNION ALL
SELECT * FROM Case_study_velo.velo_202402;

SELECT * FROM test_combined;

-- Combined all stations names and ids

CREATE TABLE test_station AS
SELECT start_station_name AS station_name, start_station_id AS station_id
FROM test_combined
UNION
SELECT end_station_name AS station_name, end_station_id AS station_id
FROM test_combined;

-- Create a table without duplicate of lines
CREATE TABLE table_station_name_id AS
SELECT DISTINCT *
FROM test_station;

SELECT *
FROM table_station_name_id
ORDER BY station_id;

-- We associate the same station_id to the station with or without "- public rack"
UPDATE table_station_name_id AS t1
JOIN table_station_name_id AS t2 
    ON t1.station_name = CONCAT('Public Rack - ', t2.station_name)
SET t1.station_id = t2.station_id;

SELECT COUNT(*), 
       COUNT(DISTINCT station_name), 
       COUNT(DISTINCT station_id)
FROM table_station_name_id;

-- for each idd see how many names
SELECT station_id, GROUP_CONCAT(station_name) AS names
FROM table_station_name_id
GROUP BY station_id
HAVING COUNT(station_name) > 1;

-- in a lot of case one of the station is the same just with the mention 'Temp'
SELECT station_id, GROUP_CONCAT(station_name) AS names
FROM table_station_name_id
WHERE station_name NOT LIKE '%(Temp)'
  	AND station_name NOT IN (
    	SELECT CONCAT('Public Rack - ', t.station_name)
    	FROM table_station_name_id t
  )
GROUP BY station_id
HAVING COUNT(station_name) > 1;

-- The public rack are new stations we could decide to delete the mention public rack

-- Replace id of Buckingham fountain 
UPDATE table_station_name_id
SET station_id = REPLACE(station_id, '15541.1.1', '15541');

-- Checking other cases
SELECT station_id, GROUP_CONCAT(station_name) AS names
FROM table_station_name_id
WHERE station_name NOT LIKE '%(Temp)'
  	AND station_name  NOT LIKE 'Public Rack - %'
GROUP BY station_id
HAVING COUNT(station_name) > 1;

-- Things to change in the main table -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
-- Case 1, the name change and have the mention 'Public rack - ' in front
-- Case 2, same name with the mention '(Temp)'
-- Case 3, slighly different spelling and id for "Buckingham Fountain" and the id is 15541 or 15541.1.1
-- Case 4, for id 20133 the name of the station is completed "Woodlawn & 103rd - Olive Harvey Vaccination Site" instead of "Woodlawn & 103rd"
-- Case 5, for id 410, 410 is in the end_station_name colomn instead of "Campbell Ave & Augusta Blvd"

-- Checking Case 1, the name change and have the mention 'Public rack - ' in front

-- Checking the chronology : 
SELECT *
FROM velo_combined
WHERE start_station_name LIKE '%Public Rack%' OR end_station_name LIKE '%Public Rack%'
ORDER BY started_at ASC;
-- Appear since 1 april 2023
-- Checking the type of bike for 'Public Rack' :
SELECT rideable_type, count(*)
FROM velo_combined
WHERE start_station_name LIKE '%Public Rack%' OR end_station_name LIKE '%Public Rack%'
GROUP BY rideable_type ;
-- Only electric type
-- These are new racks for the electric bikes, we delete the mention public rack and trim :
UPDATE velo_combined
SET start_station_name = REPLACE(start_station_name, 'Public Rack -', ''),
    end_station_name = REPLACE(end_station_name, 'Public Rack -', '')
WHERE start_station_name LIKE '%Public Rack -%' OR end_station_name LIKE '%Public Rack -%';
UPDATE velo_combined SET start_station_name = TRIM(start_station_name);
UPDATE velo_combined SET end_station_name = TRIM(end_station_name);

-- Case 2, same name with the mention '(Temp)'

-- Checking the chronology : 
SELECT *
FROM velo_combined
WHERE start_station_name LIKE '%(Temp)%' OR end_station_name LIKE '%(Temp)%'
ORDER BY started_at ASC;
-- nothing special, appear since 1 april 2023
-- we delete the mention (Temp) and trim the values
UPDATE velo_combined
SET start_station_name = REPLACE(start_station_name, '(Temp)', ''),
    end_station_name = REPLACE(end_station_name, '(Temp)', '')
WHERE start_station_name LIKE '%(Temp)%' OR end_station_name LIKE '%(Temp)%';
UPDATE velo_combined SET start_station_name = TRIM(start_station_name);
UPDATE velo_combined SET end_station_name = TRIM(end_station_name);


-- Checking other cases :

-- for start stations
SELECT start_station_id, COUNT(DISTINCT start_station_name) AS start_station_count,
       GROUP_CONCAT(DISTINCT start_station_name) AS station_names
FROM velo_combined
GROUP BY start_station_id
HAVING COUNT(DISTINCT start_station_name) > 1;

-- for end stations
SELECT end_station_id, COUNT(DISTINCT end_station_name) AS end_station_count,
       GROUP_CONCAT(DISTINCT end_station_name) AS station_names
FROM velo_combined
GROUP BY end_station_id
HAVING COUNT(DISTINCT end_station_name) > 1;

-- Case 3, slighly different name for "Buckingham Fountain" where the id is 15541 : update with same names
UPDATE velo_combined
SET start_station_name = 'Buckingham Fountain'
WHERE start_station_id = '15541' OR  start_station_id = '15541.1.1';
UPDATE velo_combined
SET end_station_name = 'Buckingham Fountain'
WHERE end_station_id = '15541' OR end_station_id = '15541.1.1';

-- Case 4, for id 20133 the name of the station is completed "Woodlawn & 103rd - Olive Harvey Vaccination Site" instead of "Woodlawn & 103rd"
UPDATE velo_combined
SET start_station_name = 'Woodlawn & 103rd - Olive Harvey Vaccination Site'
WHERE start_station_id = '20133';
UPDATE velo_combined
SET end_station_name = 'Woodlawn & 103rd - Olive Harvey Vaccination Site'
WHERE end_station_id = '20133';

-- Case 5, for id 410, 410 is in the end_station_name colomn instead of "Campbell Ave & Augusta Blvd"
UPDATE velo_combined
SET start_station_name = 'Campbell Ave & Augusta Blvd'
WHERE start_station_id = '410';
UPDATE velo_combined
SET end_station_name = 'Campbell Ave & Augusta Blvd'
WHERE end_station_id = '410';

-- Some stations have the same id, must do the analyse by names and not ids of stations 


-- Checking if we have missing datas for latitudes and longitudes and times

SELECT 
  COUNT(CASE WHEN Start_lat IS NULL THEN 1 END) AS missing_Start_lat,
  COUNT(CASE WHEN Start_lng IS NULL THEN 1 END) AS missing_Start_lng,
  COUNT(CASE WHEN End_lat IS NULL THEN 1 END) AS missing_End_lat,
  COUNT(CASE WHEN End_lng IS NULL THEN 1 END) AS missing_End_lng,
  COUNT(CASE WHEN Ride_length_minute IS NULL THEN 1 END) AS missing_Ride_length_minute,
  COUNT(CASE WHEN Started_at IS NULL THEN 1 END) AS missing_Started_at,
  COUNT(CASE WHEN Ended_at IS NULL THEN 1 END) AS missing_Ended_at
FROM velo_combined;

-- We have 386 missing datas for end_lat and 386 missing datas for end_lng, we check if it is the same lines :

SELECT COUNT(*)
FROM velo_combined
WHERE 
  end_lat IS NULL OR 
  end_lng IS NULL;

-- Yes, only 386 lines, so we decide to delete these lines
 
DELETE FROM velo_combined
WHERE 
  end_lat IS NULL OR 
  end_lng IS NULL;


-- Now the data are clean, I add a new column named started_day to the table velo_combined

ALTER TABLE velo_combined
ADD COLUMN started_day VARCHAR(20);

UPDATE velo_combined
SET started_day = CASE DAYOFWEEK(started_at)
    WHEN 1 THEN 'Sunday'
    WHEN 2 THEN 'Monday'
    WHEN 3 THEN 'Tuesday'
    WHEN 4 THEN 'Wednesday'
    WHEN 5 THEN 'Thursday'
    WHEN 6 THEN 'Friday'
    WHEN 7 THEN 'Saturday'
END;

-- -----------------------------------------------------------------------------------------------------------------------------
-- 3. ANALYZE THE DATA ---------------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------------------------------

-- Summary statistics for trip duration
SELECT
    member_casual,
    AVG(ride_length_minute) AS average_duration,
    STDDEV(ride_length_minute) AS stddev_duration
FROM velo_combined
GROUP BY member_casual;


-- Summary statistics for trip count by user type
SELECT 
    member_casual,
    COUNT(*) AS trip_count
FROM velo_combined
GROUP BY member_casual;

-- -----------------------------------------------------------------------------------------------------------------------------
-- Exploring Interesting Trends

-- temporal -------------------------------------------------------------------------------------------------

-- Temporal trends by day of the week
SELECT 
	started_day,
    COUNT(CASE WHEN member_casual = 'member' THEN 1 END) AS member_trips,
    COUNT(CASE WHEN member_casual = 'casual' THEN 1 END) AS casual_trips
FROM velo_combined
GROUP BY started_day
ORDER BY member_trips DESC ;
-- member use during week and casual during week-end 

-- Temporal trends by month
SELECT 
    EXTRACT(MONTH FROM started_at) AS month,
    COUNT(CASE WHEN member_casual = 'member' THEN 1 END) AS member_trips,
    COUNT(CASE WHEN member_casual = 'casual' THEN 1 END) AS casual_trips
FROM velo_combined
GROUP BY month
ORDER BY casual_trips DESC;
-- trendy in summer but even more for casual 


-- Analyzing peak hours for bike usage by member and casual users
SELECT 
    HOUR(started_at) AS hour_of_day,
    member_casual,
    COUNT(*) AS ride_count
FROM 
    velo_combined
GROUP BY 
    hour_of_day, member_casual
ORDER BY 
    ride_count DESC;
 -- members use it around 8am - 5pm and casual use it more afternoon 2pm - 7pm

-- Peak hours analysis for weekend rides (Saturday and Sunday)
SELECT 
    HOUR(started_at) AS hour_of_day,
    COUNT(*) AS ride_count,
    member_casual
FROM 
    velo_combined
WHERE 
    started_day IN ('Saturday', 'Sunday')  -- Filter for Saturday and Sunday
GROUP BY 
    hour_of_day, member_casual
ORDER BY 
    ride_count DESC;


-- duration ----------------------------------------------------------------------

-- Average trip duration by user type
SELECT 
    member_casual,
    AVG(ride_length_minute) AS avg_duration
FROM velo_combined
GROUP BY member_casual;
-- avg time of 12 min for members meanwhile 19min for casual

-- Average trip duration by user type during weekend
SELECT 
    member_casual,
    AVG(ride_length_minute) AS avg_duration
FROM velo_combined
WHERE started_day IN ('Friday','Saturday','Sunday')
GROUP BY member_casual;

-- Distribution of ride durations grouped by membership status (members vs casual) and duration range
SELECT 
    CASE 
        WHEN ride_length_minute < 5 THEN 'Less than 5 minutes'
        WHEN ride_length_minute >= 5 AND ride_length_minute < 10 THEN '5-10 minutes'
        WHEN ride_length_minute >= 10 AND ride_length_minute < 15 THEN '10-15 minutes'
        WHEN ride_length_minute >= 15 AND ride_length_minute < 20 THEN '15-20 minutes'
        WHEN ride_length_minute >= 20 AND ride_length_minute < 25 THEN '20-25 minutes'
        WHEN ride_length_minute >= 25 AND ride_length_minute < 30 THEN '25-30 minutes'
        WHEN ride_length_minute >= 30 THEN '30 minutes and above'
    END AS duration_category,
    member_casual,
    COUNT(*) AS count_trips
FROM 
    velo_combined
GROUP BY 
    duration_category, member_casual
ORDER BY 
    count_trips;

-- Comparing average ride duration by bike type for casual and member users
SELECT 
    rideable_type,
    member_casual,
    AVG(ride_length_minute) AS average_duration,
    COUNT(*) AS total_rides
FROM 
    velo_combined
GROUP BY 
    rideable_type, member_casual
ORDER BY 
    rideable_type, member_casual;
 -- long rides in classic bikes for casual (24 min) vs 12 min for members
 -- bit longer rides in electric bikes for casual (14 min) vs 11 min for members
  


-- trips geography  ----------------------------------------------------------------------

   
-- most popular start station
SELECT 
    member_casual,
    start_station_name,
    COUNT(*) AS trips
FROM velo_combined
GROUP BY member_casual, start_station_name 
ORDER BY trips DESC 
LIMIT 15;

-- most popular end station
SELECT 
    member_casual,
    end_station_name,
    COUNT(*) AS trips
FROM velo_combined
GROUP BY member_casual, end_station_name 
ORDER BY trips DESC 
LIMIT 15;

-- most popular geographic zone 
SELECT 
    member_casual,
    FLOOR( start_lat * 100 )  / 100 AS start_lat_grid,
    FLOOR( start_lng * 100 ) / 100 AS start_lng_grid,
    COUNT(*) AS trips
FROM velo_combined
GROUP BY member_casual, start_lat_grid, start_lng_grid
ORDER BY trips DESC 
LIMIT 25;
-- for members more popular (41.89,-87.63)  and (41.89,-87.63)
						--	(41.88,-87.64)		(41.88,-87.63)
						--	(41.88,-87.65)		(41.89,-87.62)
						--	(41.88,-87.63)		(41.88,-87.62)
						--	(41.89,-87.64)		(41.88,-87.64)

USE case_study_velo;				

-- loop trips 
SELECT 
	member_casual,
	COUNT( CASE WHEN ( start_lat = end_lat AND start_lng = end_lng )  THEN 1 END) / COUNT(*) * 100 AS loop_trip_percentage
FROM velo_combined
GROUP BY member_casual;
-- 3% loop trips for members and 7% loop trip for casuals

-- Distribution of ride durations grouped by membership status (members vs casual) and duration range for loop trips

SELECT 
    CASE 
        WHEN ride_length_minute < 5 THEN 'Less than 5 minutes'
        WHEN ride_length_minute >= 5 AND ride_length_minute < 10 THEN '5-10 minutes'
        WHEN ride_length_minute >= 10 AND ride_length_minute < 15 THEN '10-15 minutes'
        WHEN ride_length_minute >= 15 AND ride_length_minute < 20 THEN '15-20 minutes'
        WHEN ride_length_minute >= 20 AND ride_length_minute < 25 THEN '20-25 minutes'
        WHEN ride_length_minute >= 25 AND ride_length_minute < 30 THEN '25-30 minutes'
        WHEN ride_length_minute >= 30 THEN '30 minutes and above'
    END AS duration_category,
    member_casual,
    COUNT(*) AS count_trips
FROM 
    velo_combined
WHERE (start_lat = end_lat AND start_lng = end_lng)
GROUP BY 
    duration_category, member_casual
ORDER BY 
    count_trips DESC;
   
   
-- Distribution of ride durations grouped by membership status (members vs casual) and duration range for loop trips the weekend

SELECT 
    CASE 
        WHEN ride_length_minute < 5 THEN 'Less than 5 minutes'
        WHEN ride_length_minute >= 5 AND ride_length_minute < 10 THEN '5-10 minutes'
        WHEN ride_length_minute >= 10 AND ride_length_minute < 15 THEN '10-15 minutes'
        WHEN ride_length_minute >= 15 AND ride_length_minute < 20 THEN '15-20 minutes'
        WHEN ride_length_minute >= 20 AND ride_length_minute < 25 THEN '20-25 minutes'
        WHEN ride_length_minute >= 25 AND ride_length_minute < 30 THEN '25-30 minutes'
        WHEN ride_length_minute >= 30 THEN '30 minutes and above'
    END AS duration_category,
    member_casual,
    COUNT(*) AS count_trips
FROM 
    velo_combined
WHERE (start_lat = end_lat AND start_lng = end_lng) AND  started_day IN ('Friday','Saturday','Sunday')
GROUP BY 
    duration_category, member_casual
ORDER BY 
    count_trips DESC;
   
-- lot of loop trips more than  30 min for casual - even more end of the week
   
   
-- Type preferences ------------------------------------------------------------------------

-- bike type used
SELECT 
	rideable_type,
	member_casual,
	COUNT(*) AS trips
FROM velo_combined
GROUP BY rideable_type, member_casual
ORDER BY trips DESC ;
-- little pref for electric for casuals
-- little pref for classic for members

-- we need to perform statistical test to verify if it is significative
-- we decide to switch to R to do the analysis 
