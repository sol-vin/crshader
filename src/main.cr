require "./crshader/addon"
{% unless flag?(:libgodot_addon) || flag?(:release) %}
  require "./crshader"
  require "./docs"
{% end %}
