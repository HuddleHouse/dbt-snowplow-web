{{
  config(
    materialized='table',
    enabled=var("snowplow__enable_cwv", false) and target.type in ('databricks', 'spark') | as_bool(),
    sql_header=snowplow_utils.set_query_tag(var('snowplow__query_tag', 'snowplow_dbt'))
  )
}}

with measurements as (

  select
    page_url,
    device_class,
    geo_country,
    cast( {{ dbt.date_trunc('day', 'derived_tstamp') }} as {{ dbt.type_string() }}) as time_period,
    count(*) as page_view_count,
    grouping_id() as grouping_ids,
    percentile_cont(0.{{ var('snowplow__cwv_percentile') }}) within group (order by lcp) as lcp_{{ var('snowplow__cwv_percentile') }}p,
    percentile_cont(0.{{ var('snowplow__cwv_percentile') }}) within group (order by fid) as fid_{{ var('snowplow__cwv_percentile') }}p,
    percentile_cont(0.{{ var('snowplow__cwv_percentile') }}) within group (order by cls) as cls_{{ var('snowplow__cwv_percentile') }}p,
    percentile_cont(0.{{ var('snowplow__cwv_percentile') }}) within group (order by ttfb) as ttfb_{{ var('snowplow__cwv_percentile') }}p,
    percentile_cont(0.{{ var('snowplow__cwv_percentile') }}) within group (order by inp) as inp_{{ var('snowplow__cwv_percentile') }}p
  from {{ ref('snowplow_web_vitals') }}

  where cast(derived_tstamp as date) >= {{ dateadd('day', '-'+var('snowplow__cwv_days_to_measure')|string, date_trunc('day', snowplow_utils.current_timestamp_in_utc())) }}

  group by cube(page_url, device_class,cast( {{ dbt.date_trunc('day', 'derived_tstamp') }} as {{ dbt.type_string() }}), geo_country)

)

, measurement_type as (

  select
    *,
    case when grouping_ids = 15 then 'overall'
       when grouping_ids = 3 then 'by_url_and_device'
       when grouping_ids = 9 then 'by_day_and_device'
       when grouping_ids = 10 then 'by_country_and_device'
       when grouping_ids = 14 then 'by_country'
       when grouping_ids = 11 then 'by_device'
       when grouping_ids = 13 then 'by_day'
       end as measurement_type,
   {{ snowplow_web.core_web_vital_results_query('_' + var('snowplow__cwv_percentile') | string + 'p') }}

  from measurements
)

select
  m.measurement_type,
  coalesce(m.page_url, 'all') as page_url,
  coalesce(m.device_class, 'all') as device_class,
  coalesce(m.geo_country, 'all') as geo_country,
  coalesce(g.name, 'all') as country,
  coalesce(m.time_period, 'last {{var("snowplow__cwv_days_to_measure")|string }} days') as time_period,
  m.page_view_count,
  ceil(m.lcp_{{ var('snowplow__cwv_percentile') }}p, 3) as lcp_{{ var('snowplow__cwv_percentile') }}p,
  ceil(m.fid_{{ var('snowplow__cwv_percentile') }}p, 3) as fid_{{ var('snowplow__cwv_percentile') }}p,
  ceil(m.cls_{{ var('snowplow__cwv_percentile') }}p, 3) as cls_{{ var('snowplow__cwv_percentile') }}p,
  ceil(m.ttfb_{{ var('snowplow__cwv_percentile') }}p, 3) as ttfb_{{ var('snowplow__cwv_percentile') }}p,
  ceil(m.inp_{{ var('snowplow__cwv_percentile') }}p, 3) as inp_{{ var('snowplow__cwv_percentile') }}p,
  m.lcp_result,
  m.fid_result,
  m.cls_result,
  m.ttfb_result,
  m.inp_result,
  {{ snowplow_web.core_web_vital_pass_query() }} as passed

from measurement_type m

left join {{ ref('dim_geo_country_mapping') }} g on lower(m.geo_country) = lower(g.alpha_2)

where measurement_type is not null

order by 1