{{
  config(
    tags=["this_run"]
  )
}}

with prep as (
  select
    ev.page_view_id,
    ev.event_id,

    ev.app_id,
    ev.platform,

    -- user fields
    ev.user_id,
    ev.domain_userid,
    ev.network_userid,

    -- session fields
    ev.domain_sessionid,
    ev.domain_sessionidx,

    -- timestamp fields
    ev.dvce_created_tstamp,
    ev.collector_tstamp,
    ev.derived_tstamp,
    ev.derived_tstamp as start_tstamp,

    ev.doc_width,
    ev.doc_height,

    ev.page_title,
    {{ content_group_query() }} as content_group,
    ev.page_url,
    ev.page_urlscheme,
    ev.page_urlhost,
    ev.page_urlpath,
    ev.page_urlquery,
    ev.page_urlfragment,

    -- marketing fields
    ev.mkt_medium,
    ev.mkt_source,
    ev.mkt_term,
    ev.mkt_content,
    ev.mkt_campaign,
    ev.mkt_clickid,
    ev.mkt_network,
    {{ channel_group_query() }} as default_channel_group,

    -- referrer fields
    ev.page_referrer,
    ev.refr_urlscheme ,
    ev.refr_urlhost,
    ev.refr_urlpath,
    ev.refr_urlquery,
    ev.refr_urlfragment,
    ev.refr_medium,
    ev.refr_source,
    ev.refr_term,

    -- geo fields
    ev.geo_country,
    ev.geo_region,
    ev.geo_region_name,
    ev.geo_city,
    ev.geo_zipcode,
    ev.geo_latitude,
    ev.geo_longitude,
    ev.geo_timezone ,

    ev.user_ipaddress,

    ev.useragent,

    ev.dvce_screenwidth || 'x' || ev.dvce_screenheight as screen_resolution,

    ev.br_lang,
    ev.br_viewwidth,
    ev.br_viewheight,
    ev.br_colordepth,
    ev.br_renderengine,
    ev.os_timezone,

    -- optional fields, only populated if enabled.

    -- iab enrichment fields: set iab variable to true to enable
    {{snowplow_web.get_iab_context_fields('ev')}},

    -- ua parser enrichment fields
    {{snowplow_web.get_ua_context_fields('ev')}},

    -- yauaa enrichment fields
    {{snowplow_web.get_yauaa_context_fields('ev')}},

    row_number() over (partition by ev.page_view_id order by ev.derived_tstamp, ev.dvce_created_tstamp) as page_view_id_dedupe_index

  from {{ ref('snowplow_web_base_events_this_run') }} as ev
  left join {{ ref('dim_ga4_source_categories') }} c on lower(trim(ev.mkt_source)) = lower(c.source)

  where ev.event_name = 'page_view'
    and ev.page_view_id is not null

  {% if var("snowplow__ua_bot_filter", true) %}
    {{ filter_bots('ev') }}
  {% endif %}
)

, page_view_events as (
  select
    p.page_view_id,
    p.event_id,

    p.app_id,
    p.platform,

    -- user fields
    p.user_id,
    p.domain_userid,
    p.network_userid,

    -- session fields
    p.domain_sessionid,
    p.domain_sessionidx,

    row_number() over (partition by p.domain_sessionid order by p.derived_tstamp, p.dvce_created_tstamp, p.event_id) AS page_view_in_session_index,

    -- timestamp fields
    p.dvce_created_tstamp,
    p.collector_tstamp,
    p.derived_tstamp,
    p.start_tstamp,
    coalesce(t.end_tstamp, p.derived_tstamp) as end_tstamp, -- only page views with pings will have a row in table t
    {{ snowplow_utils.current_timestamp_in_utc() }} as model_tstamp,

    coalesce(t.engaged_time_in_s, 0) as engaged_time_in_s, -- where there are no pings, engaged time is 0.
    {{ datediff('p.derived_tstamp', 'coalesce(t.end_tstamp, p.derived_tstamp)', 'second') }} as absolute_time_in_s,

    sd.hmax as horizontal_pixels_scrolled,
    sd.vmax as vertical_pixels_scrolled,

    sd.relative_hmax as horizontal_percentage_scrolled,
    sd.relative_vmax as vertical_percentage_scrolled,

    p.doc_width,
    p.doc_height,

    p.content_group,

    p.page_title,
    p.page_url,
    p.page_urlscheme,
    p.page_urlhost,
    p.page_urlpath,
    p.page_urlquery,
    p.page_urlfragment,

    p.mkt_medium,
    p.mkt_source,
    p.mkt_term,
    p.mkt_content,
    p.mkt_campaign,
    p.mkt_clickid,
    p.mkt_network,
    p.default_channel_group,

    p.page_referrer,
    p.refr_urlscheme ,
    p.refr_urlhost,
    p.refr_urlpath,
    p.refr_urlquery,
    p.refr_urlfragment,
    p.refr_medium,
    p.refr_source,
    p.refr_term,

    p.geo_country,
    p.geo_region,
    p.geo_region_name,
    p.geo_city,
    p.geo_zipcode,
    p.geo_latitude,
    p.geo_longitude,
    p.geo_timezone ,

    p.user_ipaddress,

    p.useragent,

    p.screen_resolution,

    p.br_lang,
    p.br_viewwidth,
    p.br_viewheight,
    p.br_colordepth,
    p.br_renderengine,
    p.os_timezone,


    p.iab_category as category,
    p.iab_primary_impact as primary_impact,
    p.iab_reason as reason,
    p.iab_spider_or_robot as spider_or_robot,

    p.ua_useragent_family as useragent_family,
    p.ua_useragent_major as useragent_major,
    p.ua_useragent_minor as useragent_minor,
    p.ua_useragent_patch as useragent_patch,
    p.ua_useragent_version as useragent_version,
    p.ua_os_family as os_family,
    p.ua_os_major as os_major,
    p.ua_os_minor as os_minor,
    p.ua_os_patch as os_patch,
    p.ua_os_patch_minor as os_patch_minor,
    p.ua_os_version as os_version,
    p.ua_device_family as device_family,

    p.yauaa_device_class as device_class,
    p.yauaa_agent_class as agent_class,
    p.yauaa_agent_name as agent_name,
    p.yauaa_agent_name_version as agent_name_version,
    p.yauaa_agent_name_version_major as agent_name_version_major,
    p.yauaa_agent_version as agent_version,
    p.yauaa_agent_version_major as agent_version_major,
    p.yauaa_device_brand as device_brand,
    p.yauaa_device_name as device_name,
    p.yauaa_device_version as device_version,
    p.yauaa_layout_engine_class as layout_engine_class,
    p.yauaa_layout_engine_name as layout_engine_name,
    p.yauaa_layout_engine_name_version as layout_engine_name_version,
    p.yauaa_layout_engine_name_version_major as layout_engine_name_version_major,
    p.yauaa_layout_engine_version as layout_engine_version,
    p.yauaa_layout_engine_version_major as layout_engine_version_major,
    p.yauaa_operating_system_class as operating_system_class,
    p.yauaa_operating_system_name as operating_system_name,
    p.yauaa_operating_system_name_version as operating_system_name_version,
    p.yauaa_operating_system_version as operating_system_version
  from prep as p
    left join {{ ref('snowplow_web_pv_engaged_time') }} t
    on p.page_view_id = t.page_view_id {% if var('snowplow__limit_page_views_to_session', true) %} and p.domain_sessionid = t.domain_sessionid {% endif %}

    left join {{ ref('snowplow_web_pv_scroll_depth') }} sd
    on p.page_view_id = sd.page_view_id {% if var('snowplow__limit_page_views_to_session', true) %} and p.domain_sessionid = sd.domain_sessionid {% endif %}

  where page_view_id_dedupe_index = 1

)


select
  pve.page_view_id,
  pve.event_id,

  pve.app_id,
  pve.platform,

  -- user fields
  pve.user_id,
  pve.domain_userid,
  pve.network_userid,

  -- session fields
  pve.domain_sessionid,
  pve.domain_sessionidx,

  pve.page_view_in_session_index,
  max(pve.page_view_in_session_index) over (partition by pve.domain_sessionid) as page_views_in_session,

  -- timestamp fields
  pve.dvce_created_tstamp,
  pve.collector_tstamp,
  pve.derived_tstamp,
  pve.start_tstamp,
  pve.end_tstamp,
  pve.model_tstamp,

  pve.engaged_time_in_s,
  pve.absolute_time_in_s,

  pve.horizontal_pixels_scrolled,
  pve.vertical_pixels_scrolled,

  pve.horizontal_percentage_scrolled,
  pve.vertical_percentage_scrolled,

  pve.doc_width,
  pve.doc_height,
  pve.content_group,

  pve.page_title,
  pve.page_url,
  pve.page_urlscheme,
  pve.page_urlhost,
  pve.page_urlpath,
  pve.page_urlquery,
  pve.page_urlfragment,

  pve.mkt_medium,
  pve.mkt_source,
  pve.mkt_term,
  pve.mkt_content,
  pve.mkt_campaign,
  pve.mkt_clickid,
  pve.mkt_network,
  pve.default_channel_group,

  pve.page_referrer,
  pve.refr_urlscheme,
  pve.refr_urlhost,
  pve.refr_urlpath,
  pve.refr_urlquery,
  pve.refr_urlfragment,
  pve.refr_medium,
  pve.refr_source,
  pve.refr_term,

  pve.geo_country,
  pve.geo_region,
  pve.geo_region_name,
  pve.geo_city,
  pve.geo_zipcode,
  pve.geo_latitude,
  pve.geo_longitude,
  pve.geo_timezone,

  pve.user_ipaddress,

  pve.useragent,

  pve.br_lang,
  pve.br_viewwidth,
  pve.br_viewheight,
  pve.br_colordepth,
  pve.br_renderengine,

  pve.os_timezone,

  pve.category,
  pve.primary_impact,
  pve.reason,
  pve.spider_or_robot,

  pve.useragent_family,
  pve.useragent_major,
  pve.useragent_minor,
  pve.useragent_patch,
  pve.useragent_version,
  pve.os_family,
  pve.os_major,
  pve.os_minor,
  pve.os_patch,
  pve.os_patch_minor,
  pve.os_version,
  pve.device_family,

  pve.device_class,
  case when pve.device_class = 'Desktop' then 'Desktop'
    when pve.device_class = 'Phone' then 'Mobile'
    when pve.device_class = 'Tablet' then 'Tablet'
    else 'Other' end as device_category,
  pve.screen_resolution,
  pve.agent_class,
  pve.agent_name,
  pve.agent_name_version,
  pve.agent_name_version_major,
  pve.agent_version,
  pve.agent_version_major,
  pve.device_brand,
  pve.device_name,
  pve.device_version,
  pve.layout_engine_class,
  pve.layout_engine_name,
  pve.layout_engine_name_version,
  pve.layout_engine_name_version_major,
  pve.layout_engine_version,
  pve.layout_engine_version_major,
  pve.operating_system_class,
  pve.operating_system_name,
  pve.operating_system_name_version,
  pve.operating_system_version

from page_view_events pve
