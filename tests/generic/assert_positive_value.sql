{# =============================================================================
   assert_positive_value
   =============================================================================
   Custom generic test: asserts that values in a column are strictly positive
   (> 0). Optionally allows null values via the `allow_null` arg.

   Usage in _models.yml:

       columns:
         - name: net_revenue
           data_tests:
             - assert_positive_value
         - name: account_balance
           data_tests:
             - assert_positive_value:
                 allow_null: true

   Returns failing rows. Test passes when zero rows are returned.
============================================================================= #}

{% test assert_positive_value(model, column_name, allow_null=false) %}

    select *
    from {{ model }}
    where
        {% if allow_null %}
            {{ column_name }} is not null
            and
        {% endif %}
        {{ column_name }} <= 0

{% endtest %}
