{% macro materialize_table_citus(this, old_relation, sql) %}
  {%- set tmp_relation = make_temp_relation(this) -%}
  {%- set distribution_column = config.get('distribution_column', default='id') -%}  -- 'id' is the default distribution column
  
  -- Create an empty table
  create table {{ this }} (like {{ old_relation.include() }} including all);
  
  -- Insert data into empty table
  insert into {{ this }} ({{ sql }});
  
  -- Make it a Citus distributed table
  select create_distributed_table('{{ this }}', '{{ distribution_column }}');
{% endmacro %}