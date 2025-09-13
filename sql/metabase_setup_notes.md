Metabase setup notes for Marketing demo

1) Add database connection
- Database: Postgres
- Schema: marketing
- Sync & scan to pick up tables and views

2) Create questions (saved)
- Daily KPIs (Overall): from `marketing.v_daily_metrics_enriched`
  - Filter: metric_date between {{date}}
  - Summaries: Sum(Impressions), Sum(Reach), Sum(Video Views), Avg(Engagement Rate)
  - Breakout: by platform_name (optional)
- Follower Growth: from `marketing.follower_counts`
  - Filter: metric_date between {{date}}
  - Visualization: line by platform
- By Channel Performance:
  - From `v_daily_metrics_enriched`, summarize by channel_name; show impressions, link_clicks, likes, comments, shares, saves, clicks
- Post Performance:
  - From `marketing.v_post_metrics_enriched`, filter by date and platform; show engagement_rate, impressions, video_views, avg_watch_time_seconds
  - Add custom column: benchmark flag where engagement_rate > percentile(engagement_rate, 0.75)

3) Dashboard layout
- Overall Platform Performance
  - KPIs: Impressions, Reach, Video Views, Avg Engagement Rate
  - Card: Total Engagement = likes+comments+shares+saves+clicks
  - Line: Follower Growth by platform
- Marketing General
  - Table/Bar by channel_name and category with key metrics
- By Post
  - Table of posts with engagement metrics and benchmark indicator

4) Filters
- Global date filter mapped to metric_date and posted_at
- Platform filter mapped to platform_name
- Category filter mapped to category (organic, paid, email, text)

5) Permissions
- Restrict edit rights; allow view to stakeholders only



