-- Marketing analytics demo schema and seed data (1 year)
-- Run: psql -h <host> -U <user> -d <db> -f sql/marketing_demo_seed.sql

CREATE SCHEMA IF NOT EXISTS marketing;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Dimensions
CREATE TABLE IF NOT EXISTS marketing.platform (
  platform_id SERIAL PRIMARY KEY,
  platform_name TEXT UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS marketing.channel (
  channel_id SERIAL PRIMARY KEY,
  channel_name TEXT UNIQUE NOT NULL,
  category TEXT NOT NULL CHECK (category IN ('organic','paid','email','text')),
  platform_id INT NULL REFERENCES marketing.platform(platform_id)
);

-- Facts (daily aggregates per channel)
CREATE TABLE IF NOT EXISTS marketing.daily_channel_metrics (
  metric_date DATE NOT NULL,
  channel_id INT NOT NULL REFERENCES marketing.channel(channel_id),
  impressions INT NOT NULL DEFAULT 0,
  reach INT NOT NULL DEFAULT 0,
  video_views INT NOT NULL DEFAULT 0,
  link_clicks INT NOT NULL DEFAULT 0,
  likes INT NOT NULL DEFAULT 0,
  comments INT NOT NULL DEFAULT 0,
  shares INT NOT NULL DEFAULT 0,
  saves INT NOT NULL DEFAULT 0,
  clicks INT NOT NULL DEFAULT 0,
  CONSTRAINT daily_channel_metrics_uniq UNIQUE (metric_date, channel_id)
);

CREATE INDEX IF NOT EXISTS idx_daily_metrics_date ON marketing.daily_channel_metrics(metric_date);
CREATE INDEX IF NOT EXISTS idx_daily_metrics_channel ON marketing.daily_channel_metrics(channel_id);

CREATE TABLE IF NOT EXISTS marketing.follower_counts (
  metric_date DATE NOT NULL,
  platform_id INT NOT NULL REFERENCES marketing.platform(platform_id),
  followers INT NOT NULL,
  PRIMARY KEY (metric_date, platform_id)
);

-- Posts and per-post metrics
CREATE TABLE IF NOT EXISTS marketing.post (
  post_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  platform_id INT NOT NULL REFERENCES marketing.platform(platform_id),
  posted_at TIMESTAMP NOT NULL,
  title TEXT,
  content_type TEXT CHECK (content_type IN ('image','video','carousel','text'))
);

CREATE INDEX IF NOT EXISTS idx_post_platform_time ON marketing.post(platform_id, posted_at);

CREATE TABLE IF NOT EXISTS marketing.post_metrics (
  post_id UUID PRIMARY KEY REFERENCES marketing.post(post_id) ON DELETE CASCADE,
  reach INT NOT NULL DEFAULT 0,
  impressions INT NOT NULL DEFAULT 0,
  video_views INT NOT NULL DEFAULT 0,
  avg_watch_time_seconds NUMERIC(6,2) NOT NULL DEFAULT 0,
  likes INT NOT NULL DEFAULT 0,
  comments INT NOT NULL DEFAULT 0,
  shares INT NOT NULL DEFAULT 0,
  saves INT NOT NULL DEFAULT 0,
  clicks INT NOT NULL DEFAULT 0
);

-- Seed platforms
INSERT INTO marketing.platform (platform_name) VALUES
  ('facebook'), ('instagram'), ('tiktok')
ON CONFLICT (platform_name) DO NOTHING;

-- Seed channels (organic/paid link to platforms; email/text with NULL platform)
INSERT INTO marketing.channel (channel_name, category, platform_id)
SELECT x.channel_name, x.category, p.platform_id
FROM (
  VALUES
    ('organic_facebook','organic','facebook'),
    ('organic_instagram','organic','instagram'),
    ('organic_tiktok','organic','tiktok'),
    ('paid_facebook','paid','facebook'),
    ('paid_instagram','paid','instagram'),
    ('email','email',NULL),
    ('text','text',NULL)
) AS x(channel_name, category, platform_name)
LEFT JOIN marketing.platform p ON x.platform_name = p.platform_name
ON CONFLICT (channel_name) DO NOTHING;

-- 1 year of daily metrics per channel
WITH dates AS (
  SELECT generate_series((current_date - INTERVAL '365 days')::date, current_date, INTERVAL '1 day')::date AS d
),
ch AS (
  SELECT c.channel_id, c.channel_name, c.category, p.platform_name, c.platform_id
  FROM marketing.channel c
  LEFT JOIN marketing.platform p ON p.platform_id = c.platform_id
),
base AS (
  SELECT
    ch.*,
    CASE ch.category
      WHEN 'organic' THEN 6000
      WHEN 'paid'    THEN 16000
      WHEN 'email'   THEN 2500
      WHEN 'text'    THEN 1800
    END AS base_impressions,
    CASE ch.platform_name
      WHEN 'facebook'  THEN 1.00
      WHEN 'instagram' THEN 0.90
      WHEN 'tiktok'    THEN 1.30
      ELSE 1.00
    END AS platform_mult
  FROM ch
),
daily AS (
  SELECT
    d.d AS metric_date,
    b.channel_id,
    GREATEST( (b.base_impressions * b.platform_mult
      * (1 + 0.25 * SIN(2 * PI() * EXTRACT(doy FROM d.d)::float / 365))
      * (0.70 + (random() * 0.60)) )::int, 0) AS impressions
  FROM dates d
  CROSS JOIN base b
)
INSERT INTO marketing.daily_channel_metrics (
  metric_date, channel_id, impressions, reach, video_views, link_clicks,
  likes, comments, shares, saves, clicks
)
SELECT
  d.metric_date,
  d.channel_id,
  d.impressions,
  (d.impressions * (0.60 + (random() * 0.30)))::int AS reach,
  CASE WHEN c.category IN ('organic','paid') AND c.platform_id IS NOT NULL
       THEN (d.impressions * (0.35 + random() * 0.30))::int ELSE 0 END AS video_views,
  CASE WHEN c.category IN ('organic','paid') THEN (d.impressions * (0.01 + random() * 0.02))::int
       WHEN c.category IN ('email','text')    THEN (d.impressions * (0.02 + random() * 0.03))::int
       ELSE 0 END AS link_clicks,
  (d.impressions * (0.015 + random() * 0.015))::int AS likes,
  (d.impressions * (0.002 + random() * 0.005))::int AS comments,
  (d.impressions * (0.001 + random() * 0.004))::int AS shares,
  CASE WHEN c.category IN ('organic','paid') THEN (d.impressions * (0.002 + random() * 0.004))::int ELSE 0 END AS saves,
  CASE WHEN c.category IN ('organic','paid') THEN (d.impressions * (0.01 + random() * 0.02))::int
       WHEN c.category IN ('email','text')    THEN (d.impressions * (0.02 + random() * 0.03))::int
       ELSE 0 END AS clicks
FROM daily d
JOIN marketing.channel c ON c.channel_id = d.channel_id
ON CONFLICT (metric_date, channel_id) DO NOTHING;

-- Follower counts per platform (growth with noise)
WITH dates AS (
  SELECT generate_series((current_date - INTERVAL '365 days')::date, current_date, INTERVAL '1 day')::date AS d
),
p AS (
  SELECT platform_id,
         (50000 + (random() * 150000))::int AS start_followers,
         (80 + (random() * 200))::int AS daily_growth
  FROM marketing.platform
),
series AS (
  SELECT
    d.d AS metric_date,
    p.platform_id,
    p.start_followers,
    p.daily_growth,
    ROW_NUMBER() OVER (PARTITION BY p.platform_id ORDER BY d.d) - 1 AS rn
  FROM dates d CROSS JOIN p
)
INSERT INTO marketing.follower_counts (metric_date, platform_id, followers)
SELECT
  metric_date,
  platform_id,
  (start_followers + rn * daily_growth + (random() * 500)::int)::int AS followers
FROM series
ON CONFLICT (metric_date, platform_id) DO NOTHING;

-- Generate posts across last year
WITH params AS (
  SELECT 1000 AS num_posts
),
platforms AS (
  SELECT platform_id FROM marketing.platform
),
posts AS (
  SELECT
    uuid_generate_v4() AS post_id,
    (SELECT platform_id FROM platforms ORDER BY random() LIMIT 1) AS platform_id,
    (current_date - (random() * 365)::int)::timestamp
      + ((random() * 24)::int || ' hours')::interval
      + ((random() * 60)::int || ' minutes')::interval AS posted_at,
    'Post ' || LPAD((row_number() OVER ())::text, 4, '0') AS title,
    (ARRAY['image','video','carousel','text'])[(floor(random()*4)::int + 1)] AS content_type
  FROM generate_series(1, (SELECT num_posts FROM params))
)
INSERT INTO marketing.post (post_id, platform_id, posted_at, title, content_type)
SELECT post_id, platform_id, posted_at, title, content_type
FROM posts
ON CONFLICT (post_id) DO NOTHING;

-- Per-post metrics
WITH pm AS (
  SELECT
    p.post_id,
    p.platform_id,
    p.posted_at,
    p.content_type,
    GREATEST( (CASE p.content_type
                 WHEN 'video'    THEN 18000
                 WHEN 'carousel' THEN 14000
                 WHEN 'image'    THEN 10000
                 ELSE 6000
               END * (0.70 + random()*0.80))::int, 0) AS impressions
  FROM marketing.post p
)
INSERT INTO marketing.post_metrics (
  post_id, reach, impressions, video_views, avg_watch_time_seconds,
  likes, comments, shares, saves, clicks
)
SELECT
  post_id,
  (impressions * (0.55 + random()*0.35))::int AS reach,
  impressions,
  CASE WHEN content_type = 'video'
       THEN (impressions * (0.40 + random()*0.35))::int ELSE 0 END AS video_views,
  CASE WHEN content_type = 'video'
       THEN ROUND((5 + random()*35)::numeric, 2) ELSE 0 END AS avg_watch_time_seconds,
  (impressions * (0.02 + random()*0.02))::int AS likes,
  (impressions * (0.003 + random()*0.004))::int AS comments,
  (impressions * (0.002 + random()*0.003))::int AS shares,
  (impressions * (0.002 + random()*0.003))::int AS saves,
  (impressions * (0.01 + random()*0.02))::int AS clicks
FROM pm
ON CONFLICT (post_id) DO NOTHING;

-- Views for Metabase
CREATE OR REPLACE VIEW marketing.v_daily_metrics_enriched AS
SELECT
  d.metric_date,
  pl.platform_name,
  ch.category,
  ch.channel_name,
  d.impressions,
  d.reach,
  d.video_views,
  d.link_clicks,
  d.likes,
  d.comments,
  d.shares,
  d.saves,
  d.clicks,
  CASE WHEN d.impressions = 0 THEN 0
       ELSE (d.likes + d.comments + d.shares + d.saves + d.clicks)::numeric / d.impressions END AS engagement_rate
FROM marketing.daily_channel_metrics d
JOIN marketing.channel ch ON ch.channel_id = d.channel_id
LEFT JOIN marketing.platform pl ON pl.platform_id = ch.platform_id;

CREATE OR REPLACE VIEW marketing.v_post_metrics_enriched AS
SELECT
  p.post_id,
  pl.platform_name,
  p.posted_at,
  p.title,
  p.content_type,
  m.reach,
  m.impressions,
  m.video_views,
  m.avg_watch_time_seconds,
  m.likes,
  m.comments,
  m.shares,
  m.saves,
  m.clicks,
  CASE WHEN m.impressions = 0 THEN 0
       ELSE (m.likes + m.comments + m.shares + m.saves + m.clicks)::numeric / m.impressions END AS engagement_rate
FROM marketing.post p
JOIN marketing.post_metrics m ON m.post_id = p.post_id
LEFT JOIN marketing.platform pl ON pl.platform_id = p.platform_id;



