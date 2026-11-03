local M = {}

local ls = require("luasnip")
local s = ls.snippet
local sn = ls.snippet_node
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node
local c = ls.choice_node
local d = ls.dynamic_node

local js_snippets = {}

table.insert(js_snippets, s({
  trig = "ooextend",
  name = "Extend Widget/Component",
  dscr = "Extend an Odoo Widget or Component",
}, {
  t("var "), i(1, "Name"), t(" = "), i(2, "Parent"), t({ ".extend({", 
      "\tstart: function () {", 
      "\t\tvar self = this;",
      "\t\treturn this._super.apply(this, arguments).then(function () {",
      "\t\t\t" }), i(0), t({ "", 
      "\t\t});",
      "\t},",
      "});" }),
}))

table.insert(js_snippets, s({
  trig = "ooowl",
  name = "OWL Component",
  dscr = "Define a new OWL Component",
}, {
  t({ "const { Component, useState } = owl;", "", 
      "class " }), i(1, "MyComponent"), t({ " extends Component {", 
      "\tsetup() {",
      "\t\tthis.state = useState({ " }), i(2, "value: 0"), t({ " });",
      "\t}",
      "}", "",
      }), f(function(args) return args[1][1] end, { 1 }), t({ ".template = '" }), i(3, "template_name"), t("';"),
}))

table.insert(js_snippets, s({
  trig = "ooowlpatch",
  name = "Patch OWL Component",
  dscr = "Patch an existing OWL Component",
}, {
  t({ "import { patch } = require(\"@web/core/utils/patch\");",
      "import { " }), i(1, "TargetComponent"), t({ " } from \"@point_of_sale/app/store/models\";", -- Example path
      "",
      "patch(" }), f(function(args) return args[1][1] end, { 1 }), t({ ".prototype, {",
      "\tsetup() {",
      "\t\tsuper.setup(...arguments);",
      "\t\t" }), i(0), t({ "",
      "\t},",
      "});" }),
}))

table.insert(js_snippets, s({
  trig = "oodef",
  name = "Odoo Define",
  dscr = "odoo.define module",
}, {
  t("odoo.define('"), i(1, "module.name"), t({ "', function (require) {", 
      "\t\"use strict\";", "", 
      "\tvar " }), i(2, "Variable"), t(" = require('"), i(3, "dependency"), t({ "');", "", 
      "\t" }), i(0), t({ "", 
      "});" }),
}))

function M.setup()
  ls.add_snippets("javascript", js_snippets, { key = "odoo-ide-js" })
  ls.add_snippets("javascriptreact", js_snippets, { key = "odoo-ide-jsx" }) -- Support for JSX/OWL if recognized as such
end

return M
