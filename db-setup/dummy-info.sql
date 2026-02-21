BEGIN;

-- =========================
-- 1) RESOURCE TYPES
-- =========================
INSERT INTO
    resource_type (name, description)
VALUES (
        'Radio',
        'Radio de comunicación portátil (UHF/VHF)'
    ),
    (
        'Chaqueta',
        'Chaqueta reflectiva / seguridad'
    ),
    (
        'Cono',
        'Cono de tráfico 70cm'
    ),
    (
        'Valla',
        'Valla metálica de control (barrera)'
    ),
    (
        'Linterna',
        'Linterna recargable USB'
    ),
    (
        'Extintor',
        'Extintor ABC 10lb'
    ),
    (
        'Botiquín',
        'Botiquín de primeros auxilios'
    ),
    (
        'Cinta',
        'Cinta de demarcación'
    ),
    (
        'Batería',
        'Power pack para radios'
    ),
    (
        'Megáfono',
        'Megáfono recargable'
    );

-- =========================
-- 2) RESOURCE ITEMS
-- (adjusted to create many items to test dispatch history)
-- =========================

INSERT INTO resource_item (resource_type_id, code, current_state, notes)
SELECT rt.id, v.code, v.state::resource_state, v.notes
FROM resource_type rt
JOIN (VALUES
  ('Radio','RAD-001','IN_WAREHOUSE','Motorola canal 1'),
  ('Radio','RAD-002','IN_WAREHOUSE','Motorola canal 2'),
  ('Radio','RAD-003','IN_WAREHOUSE','Motorola canal 3'),
  ('Radio','RAD-004','IN_WAREHOUSE','Motorola canal 4'),
  ('Radio','RAD-005','IN_WAREHOUSE','Motorola canal 5'),
  ('Radio','RAD-006','IN_WAREHOUSE','Motorola canal 6'),
  ('Radio','RAD-007','IN_WAREHOUSE','Kenwood canal 7'),
  ('Radio','RAD-008','IN_WAREHOUSE','Kenwood canal 8'),

  ('Chaqueta','CHA-001','IN_WAREHOUSE','Reflectiva talla S'),
  ('Chaqueta','CHA-002','IN_WAREHOUSE','Reflectiva talla M'),
  ('Chaqueta','CHA-003','IN_WAREHOUSE','Reflectiva talla L'),
  ('Chaqueta','CHA-004','IN_WAREHOUSE','Reflectiva talla XL'),
  ('Chaqueta','CHA-005','IN_WAREHOUSE','Reflectiva talla M (rep)'),
  ('Chaqueta','CHA-006','IN_WAREHOUSE','Reflectiva talla L (rep)'),

  ('Cono','CON-001','IN_WAREHOUSE','70cm reflectivo'),
  ('Cono','CON-002','IN_WAREHOUSE','70cm reflectivo'),
  ('Cono','CON-003','IN_WAREHOUSE','70cm reflectivo'),
  ('Cono','CON-004','IN_WAREHOUSE','70cm reflectivo'),
  ('Cono','CON-005','IN_WAREHOUSE','70cm reflectivo'),
  ('Cono','CON-006','IN_WAREHOUSE','70cm reflectivo'),
  ('Cono','CON-007','IN_WAREHOUSE','70cm reflectivo'),
  ('Cono','CON-008','IN_WAREHOUSE','70cm reflectivo'),
  ('Cono','CON-009','IN_WAREHOUSE','70cm reflectivo'),
  ('Cono','CON-010','IN_WAREHOUSE','70cm reflectivo'),

  ('Valla','VAL-001','IN_WAREHOUSE','Valla 2m'),
  ('Valla','VAL-002','IN_WAREHOUSE','Valla 2m'),
  ('Valla','VAL-003','IN_WAREHOUSE','Valla 2m'),
  ('Valla','VAL-004','IN_WAREHOUSE','Valla 2m'),
  ('Valla','VAL-005','IN_WAREHOUSE','Valla 2m'),

  ('Linterna','LIN-001','IN_WAREHOUSE','USB-C'),
  ('Linterna','LIN-002','IN_WAREHOUSE','USB-C'),
  ('Linterna','LIN-003','IN_WAREHOUSE','USB-C'),
  ('Linterna','LIN-004','IN_WAREHOUSE','USB-C'),

  ('Extintor','EXT-001','IN_WAREHOUSE','ABC 10lb'),
  ('Extintor','EXT-002','IN_WAREHOUSE','ABC 10lb'),
  ('Extintor','EXT-003','IN_WAREHOUSE','ABC 10lb'),

  ('Botiquín','BOT-001','IN_WAREHOUSE','Kit completo'),
  ('Botiquín','BOT-002','IN_WAREHOUSE','Kit completo'),

  ('Cinta','CIN-001','IN_WAREHOUSE','Peligro 100m'),
  ('Cinta','CIN-002','IN_WAREHOUSE','Acceso restringido 100m'),
  ('Cinta','CIN-003','IN_WAREHOUSE','Demarcación 100m'),

  ('Batería','BAT-001','IN_WAREHOUSE','Power pack 1'),
  ('Batería','BAT-002','IN_WAREHOUSE','Power pack 2'),
  ('Batería','BAT-003','IN_WAREHOUSE','Power pack 3'),

  ('Megáfono','MEG-001','IN_WAREHOUSE','25W'),
  ('Megáfono','MEG-002','IN_WAREHOUSE','25W')
) AS v(type_name, code, state, notes)
ON rt.name = v.type_name;

-- =========================
-- 3) EVENTS
-- multiple categories + multi-day festivals to test many-to-many
-- =========================
INSERT INTO
    event (
        name,
        event_date,
        location,
        notes
    )
VALUES (
        'Partido: Seattle Sounders vs LA Galaxy',
        '2026-03-07',
        'Lumen Field, Seattle',
        'Partido de liga'
    ),
    (
        'Partido: Seattle Mariners vs NY Yankees',
        '2026-03-10',
        'T-Mobile Park, Seattle',
        'Juego nocturno'
    ),
    (
        'Partido: Seahawks vs 49ers (Exhibición)',
        '2026-04-04',
        'Lumen Field, Seattle',
        'Exhibición'
    ),
    (
        'Concierto: Coldplay - Music of the Spheres',
        '2026-03-14',
        'Climate Pledge Arena, Seattle',
        'Indoor'
    ),
    (
        'Concierto: Bad Bunny (Tour)',
        '2026-04-18',
        'T-Mobile Park, Seattle',
        'Masivo'
    ),
    (
        'Festival: Seattle Spring Fest (Día 1)',
        '2026-03-21',
        'Seattle Center, Seattle',
        'Outdoor'
    ),
    (
        'Festival: Seattle Spring Fest (Día 2)',
        '2026-03-22',
        'Seattle Center, Seattle',
        'Outdoor'
    ),
    (
        'Festival: Waterfront Food & Music (Día 1)',
        '2026-05-02',
        'Pier 62, Seattle',
        'Gastro+Música'
    ),
    (
        'Festival: Waterfront Food & Music (Día 2)',
        '2026-05-03',
        'Pier 62, Seattle',
        'Gastro+Música'
    );

-- =========================
-- 4) DISPATCHES
-- Creates:
-- - Many dispatches
-- - Some items reused in later dispatches (history)
-- - Some OPEN (returned_at NULL) to test "CHECKED_OUT" state
-- =========================

WITH i AS (SELECT id, code FROM resource_item),
seed_dispatch AS (
  SELECT * FROM (VALUES
    ('RAD-001','2026-03-06T17:00:00Z','Sounders - seguridad','2026-03-08T18:00:00Z','OK'),
    ('RAD-002','2026-03-06T17:00:00Z','Sounders - accesos','2026-03-08T18:00:00Z','OK'),
    ('RAD-003','2026-03-06T17:05:00Z','Sounders - logística','2026-03-08T18:30:00Z','OK'),
    ('CHA-001','2026-03-06T17:10:00Z','Sounders - perímetro','2026-03-09T16:00:00Z','Mancha leve'),
    ('CON-001','2026-03-06T17:20:00Z','Sounders - filas','2026-03-09T16:10:00Z','OK'),
    ('VAL-001','2026-03-06T17:25:00Z','Sounders - barreras','2026-03-09T17:00:00Z','OK'),
    ('BOT-001','2026-03-06T17:30:00Z','Sounders - primeros auxilios','2026-03-09T17:05:00Z','Reponer gasas'),
    ('BAT-001','2026-03-06T17:00:00Z','Sounders - pack baterías','2026-03-09T16:30:00Z','OK'),

    ('RAD-004','2026-03-09T18:00:00Z','Mariners - seguridad','2026-03-11T18:00:00Z','OK'),
    ('RAD-005','2026-03-09T18:00:00Z','Mariners - accesos','2026-03-11T18:00:00Z','OK'),
    ('CHA-003','2026-03-09T18:10:00Z','Mariners - staff','2026-03-12T16:00:00Z','OK'),
    ('CON-003','2026-03-09T18:20:00Z','Mariners - filas','2026-03-12T16:10:00Z','OK'),
    ('VAL-002','2026-03-09T18:25:00Z','Mariners - barreras','2026-03-12T17:00:00Z','OK'),

    ('RAD-006','2026-03-13T20:00:00Z','Coldplay - backstage','2026-03-15T19:00:00Z','OK'),
    ('LIN-001','2026-03-13T20:10:00Z','Coldplay - apoyo nocturno','2026-03-16T18:00:00Z','Batería 40%'),
    ('EXT-001','2026-03-13T20:15:00Z','Coldplay - safety','2026-03-16T18:10:00Z','OK'),
    ('MEG-001','2026-03-13T20:20:00Z','Coldplay - comunicaciones','2026-03-16T18:15:00Z','OK'),
    ('BAT-002','2026-03-13T20:00:00Z','Coldplay - pack baterías','2026-03-16T18:30:00Z','OK'),

    ('CON-004','2026-03-20T16:00:00Z','Spring Fest - accesos','2026-03-24T18:00:00Z','OK'),
    ('CIN-001','2026-03-20T16:05:00Z','Spring Fest - cinta peligro','2026-03-25T17:00:00Z','OK'),
    ('VAL-003','2026-03-20T16:10:00Z','Spring Fest - barreras','2026-03-25T17:10:00Z','OK'),
    ('MEG-002','2026-03-20T16:20:00Z','Spring Fest - llamadas','2026-03-25T17:20:00Z','OK'),
    ('BOT-002','2026-03-20T16:15:00Z','Spring Fest - auxilios','2026-03-25T17:15:00Z','Reponer alcohol'),

-- Re-use items later to test item history
(
    'RAD-001',
    '2026-04-03T18:00:00Z',
    'Seahawks - seguridad',
    '2026-04-05T18:00:00Z',
    'OK'
),
(
    'CHA-001',
    '2026-04-03T18:05:00Z',
    'Seahawks - staff',
    '2026-04-06T17:00:00Z',
    'OK'
),
(
    'LIN-002',
    '2026-04-03T18:10:00Z',
    'Seahawks - apoyo',
    '2026-04-06T17:10:00Z',
    'OK'
),

-- Open dispatches (not returned yet)
(
    'RAD-008',
    '2026-04-17T18:00:00Z',
    'Bad Bunny - seguridad',
    NULL,
    NULL
),
(
    'CHA-004',
    '2026-04-17T18:05:00Z',
    'Bad Bunny - staff',
    NULL,
    NULL
),
(
    'CON-007',
    '2026-04-17T18:10:00Z',
    'Bad Bunny - filas',
    NULL,
    NULL
),
(
    'LIN-003',
    '2026-04-17T18:15:00Z',
    'Bad Bunny - apoyo nocturno',
    NULL,
    NULL
),
(
    'EXT-002',
    '2026-04-17T18:20:00Z',
    'Bad Bunny - safety',
    NULL,
    NULL
),
(
    'BAT-003',
    '2026-04-17T18:00:00Z',
    'Bad Bunny - pack baterías',
    NULL,
    NULL
),

-- Waterfront (closed)
('VAL-004','2026-05-01T18:00:00Z','Waterfront - barreras','2026-05-04T18:00:00Z','OK'),
    ('CIN-003','2026-05-01T18:05:00Z','Waterfront - demarcación','2026-05-04T18:10:00Z','OK'),
    ('LIN-004','2026-05-01T18:10:00Z','Waterfront - apoyo','2026-05-04T18:15:00Z','OK'),
    ('EXT-003','2026-05-01T18:15:00Z','Waterfront - safety','2026-05-04T18:20:00Z','OK')
  ) AS t(code, dispatched_at, dispatch_note, returned_at, return_note)
)
INSERT INTO dispatch (resource_item_id, dispatched_at, dispatch_note, returned_at, return_note)
SELECT i.id,
       sd.dispatched_at::timestamptz,
       sd.dispatch_note,
       sd.returned_at::timestamptz,
       sd.return_note
FROM seed_dispatch sd
JOIN i ON i.code = sd.code;

-- =========================
-- 5) DISPATCH_EVENT LINKS (MANY-TO-MANY)
-- - Some dispatches linked to MULTIPLE events (festival day 1 + day 2)
-- =========================
WITH d AS (
  SELECT d.id, ri.code, d.dispatched_at
  FROM dispatch d
  JOIN resource_item ri ON ri.id = d.resource_item_id
),
e AS (
  SELECT id, name FROM event
),
seed_links AS (
  SELECT * FROM (VALUES
    -- Sounders
    ('RAD-001','2026-03-06T17:00:00Z','Partido: Seattle Sounders vs LA Galaxy'),
    ('RAD-002','2026-03-06T17:00:00Z','Partido: Seattle Sounders vs LA Galaxy'),
    ('RAD-003','2026-03-06T17:05:00Z','Partido: Seattle Sounders vs LA Galaxy'),
    ('CHA-001','2026-03-06T17:10:00Z','Partido: Seattle Sounders vs LA Galaxy'),
    ('CON-001','2026-03-06T17:20:00Z','Partido: Seattle Sounders vs LA Galaxy'),
    ('VAL-001','2026-03-06T17:25:00Z','Partido: Seattle Sounders vs LA Galaxy'),
    ('BOT-001','2026-03-06T17:30:00Z','Partido: Seattle Sounders vs LA Galaxy'),
    ('BAT-001','2026-03-06T17:00:00Z','Partido: Seattle Sounders vs LA Galaxy'),

-- Mariners
(
    'RAD-004',
    '2026-03-09T18:00:00Z',
    'Partido: Seattle Mariners vs NY Yankees'
),
(
    'RAD-005',
    '2026-03-09T18:00:00Z',
    'Partido: Seattle Mariners vs NY Yankees'
),
(
    'CHA-003',
    '2026-03-09T18:10:00Z',
    'Partido: Seattle Mariners vs NY Yankees'
),
(
    'CON-003',
    '2026-03-09T18:20:00Z',
    'Partido: Seattle Mariners vs NY Yankees'
),
(
    'VAL-002',
    '2026-03-09T18:25:00Z',
    'Partido: Seattle Mariners vs NY Yankees'
),

-- Coldplay
(
    'RAD-006',
    '2026-03-13T20:00:00Z',
    'Concierto: Coldplay - Music of the Spheres'
),
(
    'LIN-001',
    '2026-03-13T20:10:00Z',
    'Concierto: Coldplay - Music of the Spheres'
),
(
    'EXT-001',
    '2026-03-13T20:15:00Z',
    'Concierto: Coldplay - Music of the Spheres'
),
(
    'MEG-001',
    '2026-03-13T20:20:00Z',
    'Concierto: Coldplay - Music of the Spheres'
),
(
    'BAT-002',
    '2026-03-13T20:00:00Z',
    'Concierto: Coldplay - Music of the Spheres'
),

-- Spring Fest: same dispatch linked to both Day 1 and Day 2
(
    'CON-004',
    '2026-03-20T16:00:00Z',
    'Festival: Seattle Spring Fest (Día 1)'
),
(
    'CON-004',
    '2026-03-20T16:00:00Z',
    'Festival: Seattle Spring Fest (Día 2)'
),
(
    'CIN-001',
    '2026-03-20T16:05:00Z',
    'Festival: Seattle Spring Fest (Día 1)'
),
(
    'CIN-001',
    '2026-03-20T16:05:00Z',
    'Festival: Seattle Spring Fest (Día 2)'
),
(
    'VAL-003',
    '2026-03-20T16:10:00Z',
    'Festival: Seattle Spring Fest (Día 1)'
),
(
    'VAL-003',
    '2026-03-20T16:10:00Z',
    'Festival: Seattle Spring Fest (Día 2)'
),
(
    'MEG-002',
    '2026-03-20T16:20:00Z',
    'Festival: Seattle Spring Fest (Día 1)'
),
(
    'MEG-002',
    '2026-03-20T16:20:00Z',
    'Festival: Seattle Spring Fest (Día 2)'
),
(
    'BOT-002',
    '2026-03-20T16:15:00Z',
    'Festival: Seattle Spring Fest (Día 1)'
),
(
    'BOT-002',
    '2026-03-20T16:15:00Z',
    'Festival: Seattle Spring Fest (Día 2)'
),

-- Seahawks
(
    'RAD-001',
    '2026-04-03T18:00:00Z',
    'Partido: Seahawks vs 49ers (Exhibición)'
),
(
    'CHA-001',
    '2026-04-03T18:05:00Z',
    'Partido: Seahawks vs 49ers (Exhibición)'
),
(
    'LIN-002',
    '2026-04-03T18:10:00Z',
    'Partido: Seahawks vs 49ers (Exhibición)'
),

-- Bad Bunny (open)
(
    'RAD-008',
    '2026-04-17T18:00:00Z',
    'Concierto: Bad Bunny (Tour)'
),
(
    'CHA-004',
    '2026-04-17T18:05:00Z',
    'Concierto: Bad Bunny (Tour)'
),
(
    'CON-007',
    '2026-04-17T18:10:00Z',
    'Concierto: Bad Bunny (Tour)'
),
(
    'LIN-003',
    '2026-04-17T18:15:00Z',
    'Concierto: Bad Bunny (Tour)'
),
(
    'EXT-002',
    '2026-04-17T18:20:00Z',
    'Concierto: Bad Bunny (Tour)'
),
(
    'BAT-003',
    '2026-04-17T18:00:00Z',
    'Concierto: Bad Bunny (Tour)'
),

-- Waterfront: link same dispatch to Day 1 and Day 2 (many-to-many)
('VAL-004','2026-05-01T18:00:00Z','Festival: Waterfront Food & Music (Día 1)'),
    ('VAL-004','2026-05-01T18:00:00Z','Festival: Waterfront Food & Music (Día 2)'),
    ('CIN-003','2026-05-01T18:05:00Z','Festival: Waterfront Food & Music (Día 1)'),
    ('CIN-003','2026-05-01T18:05:00Z','Festival: Waterfront Food & Music (Día 2)'),
    ('LIN-004','2026-05-01T18:10:00Z','Festival: Waterfront Food & Music (Día 1)'),
    ('LIN-004','2026-05-01T18:10:00Z','Festival: Waterfront Food & Music (Día 2)'),
    ('EXT-003','2026-05-01T18:15:00Z','Festival: Waterfront Food & Music (Día 1)'),
    ('EXT-003','2026-05-01T18:15:00Z','Festival: Waterfront Food & Music (Día 2)')
  ) AS t(code, dispatched_at, event_name)
)
INSERT INTO dispatch_event (dispatch_id, event_id)
SELECT d.id, e.id
FROM seed_links sl
JOIN d ON d.code = sl.code AND d.dispatched_at = sl.dispatched_at::timestamptz
JOIN e ON e.name = sl.event_name;

COMMIT;