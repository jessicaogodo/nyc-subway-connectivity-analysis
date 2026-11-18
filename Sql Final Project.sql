USE nyc_subway;

SELECT sc.complex_id, sc.complex_name, b.borough_name, sc.land_use_type, sc.hub_score, sc.is_accessible
FROM station_complexes sc
JOIN boroughs b on sc.borough_id = b.borough_id
WHERE sc.land_use_type = 'Institutional'
ORDER BY b.borough_name;


-- Query 1: How many stations Per borough and what types
SELECT
    b.borough_name,
    COUNT(sc.complex_id) AS total_stations,
    SUM(CASE WHEN sc.land_use_type = 'Institutional' THEN 1 ELSE 0 END) AS institutional_count,
    ROUND(AVG(sc.hub_score), 2) AS avg_hub_score
FROM boroughs b
JOIN station_complexes sc ON b.borough_id = sc.borough_id
GROUP BY b.borough_name
ORDER BY total_stations DESC;


-- Query 2: The Total Passenger Count by Borough
SELECT
    b.borough_name,
    SUM(hr.entries_count + hr.exits_count) AS total_ridership,
    COUNT(DISTINCT sc.complex_id) AS station_count
FROM boroughs b
JOIN station_complexes sc ON b.borough_id = sc.borough_id
JOIN hourly_ridership hr ON sc.complex_id = hr.complex_id
GROUP BY b.borough_name
ORDER BY total_ridership DESC; 


-- Query 3: How many train Lines Per Borough
SELECT
    b.borough_name,
    COUNT(DISTINCT s.route_id) AS route_count,
    COUNT(DISTINCT s.stop_id) AS total_stops
FROM boroughs b
JOIN station_complexes sc ON b.borough_id = sc.borough_id
JOIN stops s ON sc.complex_id = s.complex_id
GROUP BY b.borough_name
ORDER BY route_count DESC;


-- Query 4: How easy is it to switch trains per borough
SELECT
    b.borough_name,
    COUNT(t.transfer_id) AS total_transfers
FROM boroughs b
JOIN station_complexes sc ON b.borough_id = sc.borough_id
JOIN stops s ON sc.complex_id = s.complex_id
JOIN transfers t ON s.stop_id = t.from_stop_id
GROUP BY b.borough_name
ORDER BY total_transfers DESC;

-- Query 5: Connectivity Score (custom metrics) 
SELECT b.borough_name,
    COUNT(DISTINCT s.route_id) AS route_count,
    COUNT(DISTINCT s.stop_id) AS total_stops,
    COUNT(DISTINCT t.transfer_id) AS total_transfers,
    ROUND(AVG(sc.hub_score), 2) AS avg_hub_score,
    ROUND((COUNT(DISTINCT s.route_id) * 3) +
		(COUNT(DISTINCT s.stop_id) * 0.5) +
        (COUNT(DISTINCT t.transfer_id) * 0.2) +
        (AVG(sc.hub_score) * 5) 
        , 2) AS connectivity_score
FROM boroughs b
JOIN station_complexes sc ON b.borough_id = sc.borough_id
JOIN stops s ON sc.complex_id = s.complex_id
LEFT JOIN transfers t ON s.stop_id = t.from_stop_id
GROUP BY b.borough_name
ORDER BY connectivity_score DESC;


-- Query 6: Ridership Vs Connectivity
SELECT r.borough_name, r.total_ridership, c.connectivity_score,
    ROUND(r.total_ridership / c.connectivity_score, 2) AS demand_supply_ratio,
    CASE
        WHEN r.total_ridership / c.connectivity_score > 50000 THEN 'High Mismatch'
        WHEN r.total_ridership / c.connectivity_score > 20000 THEN 'Moderate Mismatch'
        ELSE 'Aligned'
    END AS mismatch_level
FROM (SELECT b.borough_name,
	SUM(hr.entries_count + hr.exits_count) AS total_ridership
    FROM boroughs b
    JOIN station_complexes sc ON b.borough_id = sc.borough_id
    JOIN hourly_ridership hr ON sc.complex_id = hr.complex_id
    GROUP BY b.borough_name
) AS r
JOIN (
    SELECT b.borough_name,
           ROUND((COUNT(DISTINCT s.route_id) * 3) +
                 (COUNT(DISTINCT s.stop_id) * 0.5) +
                 (COUNT(DISTINCT t.transfer_id) * 0.2) +
                 (AVG(sc.hub_score) * 5), 2) AS connectivity_score
    FROM boroughs b
    JOIN station_complexes sc ON b.borough_id = sc.borough_id
    JOIN stops s ON sc.complex_id = s.complex_id
    LEFT JOIN transfers t ON s.stop_id = t.from_stop_id
    GROUP BY b.borough_name
) AS c ON r.borough_name = c.borough_name
ORDER BY demand_supply_ratio DESC;

-- Query 7: Healthcare Stations vs. Everything else 
SELECT sc.land_use_type,
    COUNT(DISTINCT sc.complex_id) AS station_count,
    SUM(hr.entries_count + hr.exits_count) AS total_ridership,
    ROUND(SUM(hr.entries_count + hr.exits_count) / COUNT(DISTINCT sc.complex_id), 2) AS avg_ridership_per_station,
    ROUND(AVG(sc.hub_score), 2) AS avg_hub_score,
    CASE
        WHEN sc.land_use_type = 'Institutional' THEN 'Healthcare Focus'
        ELSE 'Other'
    END AS category
FROM station_complexes sc
JOIN hourly_ridership hr ON sc.complex_id = hr.complex_id
GROUP BY sc.land_use_type
ORDER BY avg_ridership_per_station DESC;


-- Query 8: How Supported Are the Healthcare Stations?
SELECT sc.complex_name, b.borough_name,sc.hub_score, sc.is_accessible,
    COUNT(DISTINCT s.route_id) AS route_count,
    COUNT(DISTINCT s.stop_id) AS stop_count,
    COUNT(DISTINCT t.transfer_id) AS transfer_count
FROM station_complexes sc
JOIN boroughs b ON sc.borough_id = b.borough_id
JOIN stops s ON sc.complex_id = s.complex_id
LEFT JOIN transfers t ON s.stop_id = t.from_stop_id
WHERE sc.land_use_type = 'Institutional'
GROUP BY sc.complex_name, b.borough_name, sc.hub_score, sc.is_accessible
ORDER BY route_count DESC;


-- Query 9: Rush-Hour Vs. Off-Peak ridership
SELECT b.borough_name,
    SUM(CASE WHEN HOUR(hr.hour_ending) BETWEEN 7 AND 9
             OR HOUR(hr.hour_ending) BETWEEN 16 AND 19
             THEN hr.entries_count + hr.exits_count ELSE 0 END) AS peak_ridership,
    SUM(CASE WHEN HOUR(hr.hour_ending) NOT BETWEEN 7 AND 9
             AND HOUR(hr.hour_ending) NOT BETWEEN 16 AND 19
             THEN hr.entries_count + hr.exits_count ELSE 0 END) AS offpeak_ridership
FROM boroughs b
JOIN station_complexes sc ON b.borough_id = sc.borough_id
JOIN hourly_ridership hr ON sc.complex_id = hr.complex_id
GROUP BY b.borough_name
ORDER BY peak_ridership DESC;



-- Query 10: Weekday Vs. Weekend Ridership
SELECT b.borough_name,
    SUM(CASE WHEN DAYOFWEEK(hr.service_date) BETWEEN 2 AND 6
             THEN hr.entries_count + hr.exits_count ELSE 0 END) AS weekday_ridership,
    SUM(CASE WHEN DAYOFWEEK(hr.service_date) IN (1, 7)
             THEN hr.entries_count + hr.exits_count ELSE 0 END) AS weekend_ridership
FROM boroughs b
JOIN station_complexes sc ON b.borough_id = sc.borough_id
JOIN hourly_ridership hr ON sc.complex_id = hr.complex_id
GROUP BY b.borough_name
ORDER BY weekday_ridership DESC;


-- Query 11: Save my results as a view 
CREATE OR REPLACE VIEW vw_borough_summary AS
SELECT b.borough_name,
    COUNT(DISTINCT sc.complex_id) AS station_count,
    COUNT(DISTINCT s.route_id) AS route_count,
    COUNT(DISTINCT s.stop_id) AS total_stops,
    COUNT(DISTINCT t.transfer_id) AS total_transfers,
    ROUND(AVG(sc.hub_score), 2) AS avg_hub_score,
    SUM(hr.entries_count + hr.exits_count) AS total_ridership,
    ROUND(
        (COUNT(DISTINCT s.route_id) * 3) +
        (COUNT(DISTINCT s.stop_id) * 0.5) +
        (COUNT(DISTINCT t.transfer_id) * 0.2) +
        (AVG(sc.hub_score) * 5)
    , 2) AS connectivity_score
FROM boroughs b
JOIN station_complexes sc ON b.borough_id = sc.borough_id
JOIN stops s ON sc.complex_id = s.complex_id
LEFT JOIN transfers t ON s.stop_id = t.from_stop_id
JOIN hourly_ridership hr ON sc.complex_id = hr.complex_id
GROUP BY b.borough_name;

SELECT * FROM vw_borough_summary;


-- Query 12: Final Borough Ranking
SELECT r.borough_name, r.total_ridership, c.connectivity_score,
    ROUND(r.total_ridership / c.connectivity_score, 2) AS demand_supply_ratio,
    RANK() OVER (ORDER BY r.total_ridership / c.connectivity_score DESC) AS mismatch_rank,
    CASE
        WHEN r.total_ridership / c.connectivity_score > 50000 THEN 'Severely Under-Connected'
        WHEN r.total_ridership / c.connectivity_score > 20000 THEN 'Moderately Under-Connected'
        ELSE 'Well Connected'
    END AS verdict
FROM (
    SELECT b.borough_name,
           SUM(hr.entries_count + hr.exits_count) AS total_ridership
    FROM boroughs b
    JOIN station_complexes sc ON b.borough_id = sc.borough_id
    JOIN hourly_ridership hr ON sc.complex_id = hr.complex_id
    GROUP BY b.borough_name
) AS r
JOIN vw_borough_summary c ON r.borough_name = c.borough_name
ORDER BY mismatch_rank;