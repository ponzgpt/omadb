class CreateCatalog < ActiveRecord::Migration[8.1]
  def change
    create_table :vendors do |t|
      t.string :name, null: false
      t.string :slug, null: false, index: { unique: true }
      t.timestamps
    end

    create_table :model_lines do |t|
      t.references :vendor, null: false, foreign_key: true
      t.string :name, null: false
      t.string :slug, null: false
      t.timestamps
      t.index [ :vendor_id, :slug ], unique: true
    end

    # A "model" in the catalog. Named Machine to stay clear of ActiveRecord's Model.
    create_table :machines do |t|
      t.references :model_line, null: false, foreign_key: true
      t.string :name, null: false
      t.string :slug, null: false, index: { unique: true }
      t.string :form_factor
      t.integer :release_year
      t.timestamps
    end

    create_table :skus do |t|
      t.references :machine, null: false, foreign_key: true
      t.string :code, null: false
      t.string :spec_source, null: false, default: "report" # report | probe | catalog | marketing
      t.timestamps
      t.index [ :machine_id, :code ], unique: true
    end

    # Messy DMI product strings, normalized, so many strings resolve to one SKU.
    create_table :dmi_aliases do |t|
      t.references :sku, null: false, foreign_key: true
      t.string :raw, null: false
      t.string :normalized, null: false, index: { unique: true }
      t.timestamps
    end

    # A part, identified by bus IDs (pci:8086:272b, usb:06cb:00fc, hda:10ec:0257, cpu:intel-lunarlake).
    create_table :components do |t|
      t.string :kind, null: false
      t.string :key, null: false, index: { unique: true }
      t.string :name, null: false
      t.timestamps
      t.index :kind
    end

    # What a SKU is known to ship with. Several rows of one kind = module lottery (vendor swaps parts).
    create_table :sku_components do |t|
      t.references :sku, null: false, foreign_key: true
      t.references :component, null: false, foreign_key: true
      t.string :source, null: false # report | probe | catalog
      t.float :mapping_confidence, null: false, default: 1.0 # catalog text → ID certainty
      t.timestamps
      t.index [ :sku_id, :component_id ], unique: true
    end

    create_table :fixes do |t|
      t.string :slug, null: false, index: { unique: true }
      t.string :title, null: false
      t.string :feature, null: false
      t.text :symptom
      t.text :steps
      t.boolean :out_of_tree, null: false, default: false # DKMS / patched kernel ⇒ Bronze, not Gold
      t.string :quirk_script # set when the Omarchy installer applies it automatically
      t.references :component, foreign_key: true
      t.timestamps
    end

    create_table :reports do |t|
      t.references :sku, null: false, foreign_key: true
      t.string :machine_hash, null: false, index: true
      t.string :omarchy_version, null: false
      t.string :channel
      t.string :kernel
      t.string :source, null: false, default: "installed" # installed | live_iso
      t.json :payload, null: false, default: {}
      t.text :notes
      t.string :notes_status, null: false, default: "none" # none | pending | approved | rejected
      t.timestamps
    end

    create_table :report_components do |t|
      t.references :report, null: false, foreign_key: true
      t.references :component, null: false, foreign_key: true
      t.index [ :report_id, :component_id ], unique: true
    end

    create_table :feature_results do |t|
      t.references :report, null: false, foreign_key: true
      t.string :feature, null: false
      t.string :status, null: false
      t.references :fix, foreign_key: true
      t.index [ :report_id, :feature ], unique: true
    end
  end
end
