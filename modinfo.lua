name = "Fusion Stack"
description = "Combine the features of stacking armor and anything item in the inventory with stacking items such as rocks, wood, gold, all loot dropped. By default 100 stacks are enabled with a maximum of 999 stacks."
author = "Danieroner"
version = "1.1.0"
forumthread = "/"

api_version = 10
all_clients_require_mod = true
client_only_mod = false
server_only_mod = true
dst_compatible = true
dont_starve_compatible = false
reign_of_giants_compatible = false
shipwrecked_compatible = false

icon_atlas = "modicon.xml"
icon = "modicon.tex"

server_filter_tags = {}

configuration_options = {
  {
    name = "StackSizeItems",
    label = "Max stack size items",
    hover = "Select the max items size stack",
    options = {
      {description = "10", data = 10},
      {description = "50", data = 50},
      {description = "100", data = 100},
      {description = "200", data = 200},
      {description = "500", data = 500},
      {description = "999", data = 999},
    },
    default = 100,
  },
}
