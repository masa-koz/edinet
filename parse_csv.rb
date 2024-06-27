require 'csv'
require 'sqlite3'
require 'zip'
require 'stringio'

def create_ids_table(db)
    sql = <<-SQL
        CREATE TABLE IF NOT EXISTS ids (
            edinet_id TEXT NOT NULL,
            UNIQUE(edinet_id)
        );
    SQL
    db.execute(sql)

    sql = <<-SQL
    CREATE INDEX IF NOT EXISTS idx_edinet_id ON ids
        (edinet_id)
    SQL
    db.execute(sql)
end

def create_companies_table(db)
    sql = <<-SQL
        CREATE TABLE IF NOT EXISTS companies (
            edinet_id TEXT NOT NULL,
            closing_date TEXT NOT NULL,
            UNIQUE(edinet_id, closing_date)
        );
    SQL
    db.execute(sql)

    sql = <<-SQL
    CREATE INDEX IF NOT EXISTS idx_edinet_id_date ON companies
        (edinet_id, closing_date)
    SQL
    db.execute(sql)
end

def create_entries_table(db)
    sql = <<-SQL
        CREATE TABLE IF NOT EXISTS entries (
            edinet_id TEXT NOT NULL,
            closing_date TEXT NOT NULL,
            item TEXT NOT NULL,
            context TEXT NOT NULL,
            value TEXT NOT NULL,
            UNIQUE(edinet_id, closing_date, item, context)
        );
    SQL
    db.execute(sql)

    sql = <<-SQL
    CREATE INDEX IF NOT EXISTS idx_edinet_id_date_item_context ON entries
        (edinet_id, closing_date, item, context)
    SQL
    db.execute(sql)
end

def create_items_table(db)
    sql = <<-SQL
        CREATE TABLE IF NOT EXISTS items (
            item TEXT NOT NULL,
            label TEXT NOT NULL,
            UNIQUE(item, label)
        );
    SQL
    db.execute(sql)

    sql = <<-SQL
    CREATE INDEX IF NOT EXISTS idx_item_label ON items
        (item, label)
    SQL
    db.execute(sql)
end

def create_pairs_table(db)
    sql = <<-SQL
        CREATE TABLE IF NOT EXISTS pairs (
            item TEXT NOT NULL,
            context TEXT NOT NULL,
            timing TEXT NOT NULL,
            value_kind TEXT NOT NULL,
            timing_kind TEXT NOT NULL,
            unit_id TEXT NOT NULL,
            unit TEXT NOT NULL,
            UNIQUE(item, context)
        );
    SQL
    db.execute(sql)

    sql = <<-SQL
    CREATE INDEX IF NOT EXISTS idx_item_context ON pairs
        (item, context)
    SQL
    db.execute(sql)
end

def insert_id(db, edinet_id)
    sql = <<-SQL
        SELECT * FROM ids
            WHERE edinet_id = ?
    SQL
    rows = db.execute(sql, [edinet_id])
    return false unless rows.empty?

    sql = <<-SQL
        INSERT INTO ids (
            edinet_id
        ) VALUES (?)
    SQL
    db.execute(sql, [edinet_id])
    true
end

def insert_company(db, edinet_id, closing_date)
    sql = <<-SQL
        SELECT * FROM companies
            WHERE edinet_id = ? AND closing_date = ?
    SQL
    rows = db.execute(sql, [edinet_id, closing_date])
    return false unless rows.empty?

    sql = <<-SQL
        INSERT INTO companies (
            edinet_id,
            closing_date
        ) VALUES (?, ?)
    SQL
    db.execute(sql, [edinet_id, closing_date])
    true
end

def insert_item(db, item, label)
    sql = <<-SQL
        SELECT * FROM items
            WHERE item = ? AND label = ?
    SQL
    rows = db.execute(sql, [item, label])
    return unless rows.empty?

    sql = <<-SQL
        INSERT INTO items (
            item,
            label
        ) VALUES (?, ?)
    SQL
    db.execute(sql, [item, label])
end

def insert_pairs(db, item, context, timing, value_kind, timing_kind, unit_id, unit)
    sql = <<-SQL
        SELECT * FROM pairs
            WHERE item = ? AND context = ?
    SQL
    rows = db.execute(sql, [item, context])
    return unless rows.empty?

    sql = <<-SQL
        INSERT INTO pairs (
            item,
            context,
            timing,
            value_kind,
            timing_kind,
            unit_id,
            unit
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
    SQL
    db.execute(sql, [item, context, timing, value_kind, timing_kind, unit_id, unit])
end

def insert_entry(db, edinet_id, closing_date, item, context, value)
    sql = <<-SQL
        SELECT * FROM entries
            WHERE edinet_id = ? AND
                  closing_date = ? AND
                  item = ? AND
                  context = ?
    SQL
    rows = db.execute(sql, [edinet_id, closing_date, item, context])
    return unless rows.empty?

    sql = <<-SQL
        INSERT INTO entries (
            edinet_id,
            closing_date,
            item,
            context,
            value
        ) VALUES (?, ?, ?, ?, ?)
    SQL
    db.execute(sql, [edinet_id, closing_date, item, context, value])
end

def process_csv(db, csv, edinet_id, closing_date)
    csv.each do |row|
        item = row[0].gsub(/[\-:]/, '_')
        insert_item(db, item, row[1])
        insert_pairs(db, item, row[2], row[3], row[4], row[5], row[6], row[7])
        insert_entry(db, edinet_id, closing_date, item, row[2], row[8])
    end
end

dirname = ARGV.shift

db = SQLite3::Database.new('edinet.db')

db.transaction do
    create_ids_table(db)
    create_companies_table(db)
    create_entries_table(db)
    create_items_table(db)
    create_pairs_table(db)
rescue SQLite3::Exception => e
    db.rollback
    puts "Exception occurred #{e.message}"
end

Dir.chdir(dirname) do
    Dir.glob("*.zip") do |zipname|
        Zip::File.open(zipname) do |zipFile|
            zipFile.each do |entry|
                if entry.name =~ /\/jpcrp030000\-asr\-001_([^\-]+)\-000_(\d{4}\-\d{2}\-\d{2})_01_(\d{4}\-\d{2}\-\d{2})\.csv/
                    edinet_id = $1
                    closing_date = $2
                    filing_date = $3
                    io = StringIO.new(entry.get_input_stream.read, "r")
                    io.set_encoding_by_bom
                    csv_data = io.read.encode("UTF-8")
                    csv = CSV.new(csv_data,
                        headers: true, col_sep: "\t", row_sep: "\r\n", encoding: "UTF-8")
                    db.transaction do
                        puts "Processing #{edinet_id} #{closing_date}..."
                        insert_id(db, edinet_id)
                        unless insert_company(db, edinet_id, closing_date)
                            puts "Already exists #{edinet_id} #{closing_date}"
                            next
                        end
                        process_csv(db, csv, edinet_id, closing_date)
                    rescue SQLite3::Exception => e
                        db.rollback
                        puts "Exception occurred #{e}"
                    end                
                end
            end
        end
    end
end
