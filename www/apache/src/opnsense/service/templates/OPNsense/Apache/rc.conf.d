{% if not helpers.empty('OPNsense.Apache.general.enabled') %}
apache24_enable="YES"
{% else %}
apache24_enable="NO"
{% endif %}
