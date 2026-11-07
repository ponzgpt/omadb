# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_07_000001) do
  create_table "components", force: :cascade do |t|
    t.string "kind", null: false
    t.string "key", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_components_on_key", unique: true
    t.index ["kind"], name: "index_components_on_kind"
  end

  create_table "dmi_aliases", force: :cascade do |t|
    t.integer "sku_id", null: false
    t.string "raw", null: false
    t.string "normalized", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["normalized"], name: "index_dmi_aliases_on_normalized", unique: true
    t.index ["sku_id"], name: "index_dmi_aliases_on_sku_id"
  end

  create_table "feature_results", force: :cascade do |t|
    t.integer "report_id", null: false
    t.string "feature", null: false
    t.string "status", null: false
    t.integer "fix_id"
    t.index ["fix_id"], name: "index_feature_results_on_fix_id"
    t.index ["report_id", "feature"], name: "index_feature_results_on_report_id_and_feature", unique: true
    t.index ["report_id"], name: "index_feature_results_on_report_id"
  end

  create_table "fixes", force: :cascade do |t|
    t.string "slug", null: false
    t.string "title", null: false
    t.string "feature", null: false
    t.text "symptom"
    t.text "steps"
    t.boolean "out_of_tree", default: false, null: false
    t.string "quirk_script"
    t.integer "component_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["component_id"], name: "index_fixes_on_component_id"
    t.index ["slug"], name: "index_fixes_on_slug", unique: true
  end

  create_table "machines", force: :cascade do |t|
    t.integer "model_line_id", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.string "form_factor"
    t.integer "release_year"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["model_line_id"], name: "index_machines_on_model_line_id"
    t.index ["slug"], name: "index_machines_on_slug", unique: true
  end

  create_table "model_lines", force: :cascade do |t|
    t.integer "vendor_id", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["vendor_id", "slug"], name: "index_model_lines_on_vendor_id_and_slug", unique: true
    t.index ["vendor_id"], name: "index_model_lines_on_vendor_id"
  end

  create_table "report_components", force: :cascade do |t|
    t.integer "report_id", null: false
    t.integer "component_id", null: false
    t.index ["component_id"], name: "index_report_components_on_component_id"
    t.index ["report_id", "component_id"], name: "index_report_components_on_report_id_and_component_id", unique: true
    t.index ["report_id"], name: "index_report_components_on_report_id"
  end

  create_table "reports", force: :cascade do |t|
    t.integer "sku_id", null: false
    t.string "machine_hash", null: false
    t.string "omarchy_version", null: false
    t.string "channel"
    t.string "kernel"
    t.string "source", default: "installed", null: false
    t.json "payload", default: {}, null: false
    t.text "notes"
    t.string "notes_status", default: "none", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["machine_hash"], name: "index_reports_on_machine_hash"
    t.index ["sku_id"], name: "index_reports_on_sku_id"
  end

  create_table "sku_components", force: :cascade do |t|
    t.integer "sku_id", null: false
    t.integer "component_id", null: false
    t.string "source", null: false
    t.float "mapping_confidence", default: 1.0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["component_id"], name: "index_sku_components_on_component_id"
    t.index ["sku_id", "component_id"], name: "index_sku_components_on_sku_id_and_component_id", unique: true
    t.index ["sku_id"], name: "index_sku_components_on_sku_id"
  end

  create_table "skus", force: :cascade do |t|
    t.integer "machine_id", null: false
    t.string "code", null: false
    t.string "spec_source", default: "report", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["machine_id", "code"], name: "index_skus_on_machine_id_and_code", unique: true
    t.index ["machine_id"], name: "index_skus_on_machine_id"
  end

  create_table "vendors", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_vendors_on_slug", unique: true
  end

  add_foreign_key "dmi_aliases", "skus"
  add_foreign_key "feature_results", "fixes"
  add_foreign_key "feature_results", "reports"
  add_foreign_key "fixes", "components"
  add_foreign_key "machines", "model_lines"
  add_foreign_key "model_lines", "vendors"
  add_foreign_key "report_components", "components"
  add_foreign_key "report_components", "reports"
  add_foreign_key "reports", "skus"
  add_foreign_key "sku_components", "components"
  add_foreign_key "sku_components", "skus"
  add_foreign_key "skus", "machines"
end
