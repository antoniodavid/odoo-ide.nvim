local M = {}

local ls = require("luasnip")
local s = ls.snippet
local sn = ls.snippet_node
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node
local c = ls.choice_node
local d = ls.dynamic_node

local context = require("odoo-ide.context")

local function get_version()
  return context.get_odoo_version() or 17
end

local function tree_or_list()
  local version = get_version()
  if version and version >= 18 then
    return "list"
  end
  return "tree"
end

local xml_snippets = {}

-- Helper to capitalize words
local function capitalize(str)
  return str:gsub("(%a)([%w_']*)", function(first, rest)
    return first:upper() .. rest
  end):gsub("_", " ")
end

table.insert(xml_snippets, s({
  trig = "oovfull",
  name = "Full View Structure",
  dscr = "Creates Form, Tree/List, Search, Action and Menu",
}, {
  t('<?xml version="1.0" encoding="utf-8"?>'),
  t({ "", "<odoo>", "    <data>", "", "" }),
  
  -- Form View
  t({ "        <record id=\"view_" }), i(1, "model_name"), t({ "_form\" model=\"ir.ui.view\">", 
      "            <field name=\"name\">" }), f(function(args) return args[1][1]:gsub("_", ".") .. ".form" end, { 1 }), t({ "</field>",
      "            <field name=\"model\">" }), f(function(args) return args[1][1]:gsub("_", ".") end, { 1 }), t({ "</field>",
      "            <field name=\"arch\" type=\"xml\">",
      "                <form string=\"" }), f(function(args) return capitalize(args[1][1]) end, { 1 }), t({ "\">",
      "                    <sheet>",
      "                        <group>",
      "                            <group>",
      "                                <field name=\"name\"/>",
      "                            </group>",
      "                            <group>",
      "                            </group>",
      "                        </group>",
      "                    </sheet>",
      "                </form>",
      "            </field>",
      "        </record>", "", "" }),

  -- Tree/List View (Dynamic)
  d(2, function(args)
    local model_name = args[1][1]
    local tag = tree_or_list()
    return sn(nil, {
      t({ "        <record id=\"view_" .. model_name .. "_" .. tag .. "\" model=\"ir.ui.view\">",
          "            <field name=\"name\">" .. model_name:gsub("_", ".") .. "." .. tag .. "</field>",
          "            <field name=\"model\">" .. model_name:gsub("_", ".") .. "</field>",
          "            <field name=\"arch\" type=\"xml\">",
          "                <" .. tag .. ">",
          "                    <field name=\"name\"/>",
          "                </" .. tag .. ">",
          "            </field>",
          "        </record>", "", "" })
    })
  end, { 1 }),

  -- Action
  t({ "        <record id=\"action_" }), f(function(args) return args[1][1] end, { 1 }), t({ "\" model=\"ir.actions.act_window\">",
      "            <field name=\"name\">" }), f(function(args) return capitalize(args[1][1]) end, { 1 }), t({ "</field>",
      "            <field name=\"res_model\">" }), f(function(args) return args[1][1]:gsub("_", ".") end, { 1 }), t({ "</field>",
      "            <field name=\"view_mode\">" }), d(3, function() return sn(nil, { t(tree_or_list() .. ",form") }) end, {}), t({ "</field>",
      "        </record>", "", "" }),

  -- Menu
  t({ "        <menuitem id=\"menu_" }), f(function(args) return args[1][1] end, { 1 }), t({ "\"",
      "            name=\"" }), f(function(args) return capitalize(args[1][1]) end, { 1 }), t({ "\"",
      "            parent=\"" }), i(4, "parent_menu_id"), t({ "\"",
      "            action=\"action_" }), f(function(args) return args[1][1] end, { 1 }), t({ "\"/>", "", "" }),

  t({ "    </data>", "</odoo>" }),
}))

table.insert(xml_snippets, s({
  trig = "oovform",
  name = "Form View",
  dscr = "Odoo Form View Record",
}, {
  t({ "<record id=\"view_" }), i(1, "model_name"), t({ "_form\" model=\"ir.ui.view\">",
      "    <field name=\"name\">" }), f(function(args) return args[1][1]:gsub("_", ".") .. ".form" end, { 1 }), t({ "</field>",
      "    <field name=\"model\">" }), f(function(args) return args[1][1]:gsub("_", ".") end, { 1 }), t({ "</field>",
      "    <field name=\"arch\" type=\"xml\">",
      "        <form string=\"" }), f(function(args) return capitalize(args[1][1]) end, { 1 }), t({ "\">",
      "            <sheet>",
      "                <group>",
      "                    <group>",
      "                        <field name=\"" }), i(2, "name"), t({ "\"/>",
      "                    </group>",
      "                    <group>",
      "                    </group>",
      "                </group>",
      "            </sheet>",
      "        </form>",
      "    </field>",
      "</record>" }),
}))

table.insert(xml_snippets, s({
  trig = "oovtree",
  name = "Tree/List View",
  dscr = "Odoo Tree/List View Record (Version Aware)",
}, {
  t({ "<record id=\"view_" }), i(1, "model_name"), d(2, function(args) return sn(nil, { t("_" .. tree_or_list()) }) end, {}), t({ "\" model=\"ir.ui.view\">",
      "    <field name=\"name\">" }), f(function(args) return args[1][1]:gsub("_", ".") .. "." .. tree_or_list() end, { 1 }), t({ "</field>",
      "    <field name=\"model\">" }), f(function(args) return args[1][1]:gsub("_", ".") end, { 1 }), t({ "</field>",
      "    <field name=\"arch\" type=\"xml\">",
      "        <" }), d(3, function() return sn(nil, { t(tree_or_list()) }) end, {}), t({ ">",
      "            <field name=\"" }), i(4, "name"), t({ "\"/>",
      "        </" }), d(5, function() return sn(nil, { t(tree_or_list()) }) end, {}), t({ ">",
      "    </field>",
      "</record>" }),
}))

table.insert(xml_snippets, s({
  trig = "ooawindow",
  name = "Action Window",
  dscr = "ir.actions.act_window record",
}, {
  t({ "<record id=\"action_" }), i(1, "model_name"), t({ "\" model=\"ir.actions.act_window\">",
      "    <field name=\"name\">" }), f(function(args) return capitalize(args[1][1]) end, { 1 }), t({ "</field>",
      "    <field name=\"res_model\">" }), f(function(args) return args[1][1]:gsub("_", ".") end, { 1 }), t({ "</field>",
      "    <field name=\"view_mode\">" }), d(2, function() return sn(nil, { t(tree_or_list() .. ",form") }) end, {}), t({ "</field>",
      "</record>" }),
}))

table.insert(xml_snippets, s({
  trig = "oofield",
  name = "Field",
  dscr = "Simple field tag",
}, {
  t("<field name=\""), i(1, "name"), t("\"/>"),
}))

table.insert(xml_snippets, s({
  trig = "oogroup",
  name = "Group",
  dscr = "Group tag",
}, {
  t("<group>"),
  t({ "", "    " }), i(0),
  t({ "", "</group>" }),
}))

table.insert(xml_snippets, s({
  trig = "oomenu",
  name = "Menu Item",
  dscr = "Menuitem record",
}, {
  t("<menuitem id=\"menu_"), i(1, "id"), t("\""),
  t({ "", "    name=\"" }), i(2, "Name"), t("\""),
  t({ "", "    parent=\"" }), i(3, "parent_id"), t("\""),
  t({ "", "    action=\"" }), i(4, "action_id"), t("\"/>"),
}))

table.insert(xml_snippets, s({
  trig = "ooxpath",
  name = "XPath",
  dscr = "XPath expression",
}, {
  t("<xpath expr=\""), i(1, "//field[@name='name']"), t("\" position=\""), 
  c(2, { t("after"), t("before"), t("inside"), t("replace"), t("attributes") }),
  t({ "\">", "    " }), i(0),
  t({ "", "</xpath>" }),
}))

function M.setup()
  ls.add_snippets("xml", xml_snippets, {
    key = "odoo-ide-xml",
  })
end

return M
