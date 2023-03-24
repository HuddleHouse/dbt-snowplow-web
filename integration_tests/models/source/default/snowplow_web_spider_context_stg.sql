select
  root_id,
  root_tstamp::timestamp,
  category,
  primaryImpact as primary_impact,
  reason,
  spiderOrRobot::boolean as spider_or_robot

from {{ ref('snowplow_web_spider_context') }}
