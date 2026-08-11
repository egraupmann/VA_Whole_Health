SELECT
    SCHEMA_NAME(t.schema_id) AS schema_name,
    t.name AS table_name,
    c.name AS column_name
FROM CDWWork2.sys.views AS t
JOIN CDWWork2.sys.columns AS c
    ON c.object_id = t.object_id
WHERE t.name LIKE '%CDS%'
ORDER BY
    schema_name,
    table_name;