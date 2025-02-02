--Removing model_tstamp

select
  -- user fields
  user_id
  ,domain_userid
  ,network_userid

  ,start_tstamp
  ,end_tstamp

  -- engagement fields
  ,page_views
  ,sessions
  ,engaged_time_in_s

  -- first page fields
  ,first_page_title
  ,first_page_url
  ,first_page_urlscheme
  ,first_page_urlhost
  ,first_page_urlpath
  ,first_page_urlquery
  ,first_page_urlfragment
  ,first_geo_country
  ,first_geo_country_name
  ,first_geo_continent
  ,first_geo_city
  ,first_geo_region_name
  ,first_br_lang
  ,first_br_lang_name

  ,last_geo_country
  ,last_geo_country_name
  ,last_geo_continent
  ,last_geo_city
  ,last_geo_region_name
  ,last_br_lang
  ,last_br_lang_name
  ,last_page_title
  ,last_page_url
  ,last_page_urlscheme
  ,last_page_urlhost
  ,last_page_urlpath
  ,last_page_urlquery
  ,last_page_urlfragment

  -- referrer fields
  ,referrer

  ,refr_urlscheme
  ,refr_urlhost
  ,refr_urlpath
  ,refr_urlquery
  ,refr_urlfragment

  ,refr_medium
  ,refr_source
  ,refr_term

  -- marketing fields
  ,mkt_medium
  ,mkt_source
  ,mkt_term
  ,mkt_content
  ,mkt_campaign
  ,mkt_clickid
  ,mkt_network
  ,mkt_source_platform
  ,default_channel_group

from {{ ref('snowplow_web_users') }}
