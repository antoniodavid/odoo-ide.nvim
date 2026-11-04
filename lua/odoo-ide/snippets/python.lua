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

local function get_model_class()
  local info = context.get_model_info()
  if info.name then
    local parts = {}
    for part in info.name:gmatch("[^%.]+") do
      table.insert(parts, part:gsub("^%l", string.upper))
    end
    return table.concat(parts, "")
  end
  return "ClassName"
end

local python_snippets = {}

table.insert(python_snippets, s({
  trig = "oocreate",
  name = "Create Method",
  dscr = "Override create() - auto-detects @api.model vs @api.model_create_multi based on Odoo version",
}, {
  d(1, function()
    local version = get_version()
    if version and version >= 14 then
      return sn(nil, {
        t({ "@api.model_create_multi", "" }),
        t("def create(self, vals_list):"),
        t({ "", "    " }),
        i(1),
        t({ "", "    return super().create(vals_list)" }),
      })
    else
      return sn(nil, {
        t({ "@api.model", "" }),
        t("def create(self, vals):"),
        t({ "", "    " }),
        i(1),
        t({ "", "    return super(" }),
        f(function() return get_model_class() end, {}),
        t(", self).create(vals)"),
      })
    end
  end, {}),
}))

table.insert(python_snippets, s({
  trig = "oowrite",
  name = "Write Method",
  dscr = "Override write()",
}, {
  t({ "def write(self, vals):", "    " }),
  i(1),
  t({ "", "    return super().write(vals)" }),
}))

table.insert(python_snippets, s({
  trig = "oounlink",
  name = "Unlink Method",
  dscr = "Override unlink()",
}, {
  t({ "def unlink(self):", "    " }),
  i(1),
  t({ "", "    return super().unlink()" }),
}))

table.insert(python_snippets, s({
  trig = "ooimo",
  name = "Import Odoo",
  dscr = "Import models, fields, api, _",
}, {
  t("from odoo import models, fields, api, _"),
}))

table.insert(python_snippets, s({
  trig = "ooiml",
  name = "Import Logging",
  dscr = "Setup Python logging",
}, {
  t({ "import logging", "", "", "_logger = logging.getLogger(__name__)", "" }),
}))

table.insert(python_snippets, s({
  trig = "ooime",
  name = "Import Exceptions",
  dscr = "Import Odoo exceptions",
}, {
  t("from odoo.exceptions import "),
  c(1, {
    t("ValidationError"),
    t("UserError"),
    t("AccessError"),
    t("MissingError"),
    t("RedirectWarning"),
  }),
}))

table.insert(python_snippets, s({
  trig = "oomodel",
  name = "Odoo Model",
  dscr = "Create new Odoo model class",
}, {
  t({ "from odoo import models, fields, api, _", "", "", "class " }),
  d(2, function(args)
    local name = args[1][1] or "model.name"
    local parts = {}
    for part in name:gmatch("[^%.]+") do
      table.insert(parts, part:gsub("^%l", string.upper))
    end
    return sn(nil, { t(table.concat(parts, "")) })
  end, { 1 }),
  t("(models."),
  c(3, {
    t("Model"),
    t("TransientModel"),
    t("AbstractModel"),
  }),
  t({ "):", "    _name = '" }),
  i(1, "model.name"),
  t({ "'", "    _description = _(" }),
  d(4, function(args)
    local name = args[1][1] or "Model"
    local desc = name:gsub("%.", " "):gsub("^%l", string.upper)
    return sn(nil, { t("'" .. desc .. "'") })
  end, { 1 }),
  t({ ")", "", "    " }),
  i(0),
}))

table.insert(python_snippets, s({
  trig = "oofchar",
  name = "Char Field",
  dscr = "fields.Char",
}, {
  i(1, "field_name"),
  t(" = fields.Char()"),
}))

table.insert(python_snippets, s({
  trig = "oofinteger",
  name = "Integer Field",
  dscr = "fields.Integer",
}, {
  i(1, "field_name"),
  t(" = fields.Integer()"),
}))

table.insert(python_snippets, s({
  trig = "ooffloat",
  name = "Float Field",
  dscr = "fields.Float",
}, {
  i(1, "field_name"),
  t(" = fields.Float()"),
}))

table.insert(python_snippets, s({
  trig = "oofboolean",
  name = "Boolean Field",
  dscr = "fields.Boolean",
}, {
  i(1, "field_name"),
  t(" = fields.Boolean(default="),
  c(2, { t("False"), t("True") }),
  t(")"),
}))

table.insert(python_snippets, s({
  trig = "oofm2o",
  name = "Many2one Field",
  dscr = "fields.Many2one",
}, {
  i(1, "field_id"),
  t(" = fields.Many2one("),
  t({ "    comodel_name='" }),
  i(2, "model.name"),
  t({ "',", ")" }),
}))

table.insert(python_snippets, s({
  trig = "oofo2m",
  name = "One2many Field",
  dscr = "fields.One2many",
}, {
  i(1, "line_ids"),
  t({ " = fields.One2many(", "    comodel_name='" }),
  i(2, "model.line"),
  t({ "',", "    inverse_name='" }),
  i(3, "parent_id"),
  t({ "',", ")" }),
}))

table.insert(python_snippets, s({
  trig = "oofm2m",
  name = "Many2many Field",
  dscr = "fields.Many2many",
}, {
  i(1, "tag_ids"),
  t({ " = fields.Many2many(", "    comodel_name='" }),
  i(2, "model.name"),
  t({ "',", ")" }),
}))

table.insert(python_snippets, s({
  trig = "oofcompute",
  name = "Computed Field",
  dscr = "Field with compute method",
}, {
  i(1, "field_name"),
  t(" = fields."),
  c(2, {
    t("Char"),
    t("Integer"),
    t("Float"),
    t("Boolean"),
    t("Date"),
    t("Datetime"),
    t("Monetary"),
    t("Text"),
  }),
  t({ "(", "    compute='_compute_" }),
  f(function(args) return args[1][1] or "field_name" end, { 1 }),
  t({ "',", ")", "", "", "@api.depends('" }),
  i(3, "depends_field"),
  t({ "')", "def _compute_" }),
  f(function(args) return args[1][1] or "field_name" end, { 1 }),
  t({ "(self):", "    for record in self:", "        record." }),
  f(function(args) return args[1][1] or "field_name" end, { 1 }),
  t(" = "),
  i(0),
}))

table.insert(python_snippets, s({
  trig = "oomconstrains",
  name = "Constrains Method",
  dscr = "@api.constrains decorator",
}, {
  t("@api.constrains('"),
  i(1, "field_name"),
  t({ "')", "def _check_" }),
  f(function(args) return args[1][1] or "field" end, { 1 }),
  t({ "(self):", "    for rec in self:", "        if " }),
  i(2, "condition"),
  t({ ":", "            raise ValidationError(_('Error message'))" }),
}))

table.insert(python_snippets, s({
  trig = "ooonchange",
  name = "Onchange Method",
  dscr = "@api.onchange decorator",
}, {
  t("@api.onchange('"),
  i(1, "field_name"),
  t({ "')", "def _onchange_" }),
  f(function(args) return args[1][1] or "field" end, { 1 }),
  t({ "(self):", "    " }),
  i(0),
}))

table.insert(python_snippets, s({
  trig = "oosqlconstrains",
  name = "SQL Constraints",
  dscr = "_sql_constraints list",
}, {
  t({ "_sql_constraints = [", "    ('" }),
  i(1, "constraint_name"),
  t("', '"),
  c(2, { t("unique"), t("check") }),
  t("("),
  i(3, "field"),
  t(")', '"),
  i(4, "Error message"),
  t({ "'),", "]" }),
}))

table.insert(python_snippets, s({
  trig = "oomanifest",
  name = "Manifest File",
  dscr = "Standard OCA __manifest__.py",
}, {
  t({ "{", "    'name': '" }),
  i(1, "Module Name"),
  t({ "',", "    'summary': '" }),
  i(2, "Module Summary"),
  t({ "',", "    'version': '" }),
  f(function() return get_version() .. ".0.1.0.0" end, {}),
  t({ "',", "    'category': '" }),
  i(3, "Uncategorized"),
  t({ "',", "    'website': 'https://github.com/OCA/", }),
  i(4, "repo-name"),
  t({ "',", "    'author': 'Your Name, Odoo Community Association (OCA)',", "    'license': 'AGPL-3',", "    'application': False,", "    'installable': True,", "    'depends': [", "        '" }),
  i(5, "base"),
  t({ "',", "    ],", "    'data': [", "        " }),
  i(0),
  t({ "", "    ],", "}" }),
}))

function M.setup()
  ls.add_snippets("python", python_snippets, {
    key = "odoo-ide-python",
  })
end

return M
