require 'csv'
require 'sqlite3'
require 'zip'
require 'stringio'

def create_companies_table(db)
    sql = <<-SQL
        CREATE TABLE IF NOT EXISTS companies (
            edinet_id TEXT,
            closing_date TEXT,
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
            edinet_id TEXT,
            closing_date TEXT,
            item TEXT,
            context TEXT,
            value_id TEXT,
            UNIQUE(edinet_id, closing_date, item, context)
        );
    SQL
    db.execute(sql)

    sql = <<-SQL
    CREATE INDEX IF NOT EXISTS idx_date_item_context ON entries
        (closing_date, edinet_id, context)
    SQL
    db.execute(sql)
end

def create_items_table(db)
    sql = <<-SQL
        CREATE TABLE IF NOT EXISTS items (
            item TEXT,
            label TEXT,
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

def create_item_table(db, table_name)
    sql = <<-SQL
        CREATE TABLE IF NOT EXISTS item_#{table_name} (
            id INTEGER PRIMARY KEY,
            timing TEXT,
            value_kind TEXT,
            timing_kind TEXT,
            unit_id TEXT,
            unit TEXT,
            value TEXT
        );
    SQL
    db.execute(sql)
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

def check_entry_exists?(db, edinet_id, closing_date, item, context)
    sql = <<-SQL
        SELECT * FROM entries
            WHERE edinet_id = ? AND
                  closing_date = ? AND
                  item = ? AND
                  context = ?
    SQL
    rows = db.execute(sql, [edinet_id, closing_date, item, context])
    not rows.empty?
end

def insert_value(db, table_name, row)
    sql = <<-SQL
        INSERT INTO item_#{table_name} (
            timing,
            value_kind,
            timing_kind,
            unit_id,
            unit,
            value
        ) VALUES (?, ?, ?, ?, ?, ?)
    SQL
    db.execute(sql, row[3..8])
    db.last_insert_row_id
end

def insert_entry(db, edinet_id, closing_date, item, context, value_id)
    sql = <<-SQL
        INSERT INTO entries (
            edinet_id,
            closing_date,
            item,
            context,
            value_id
        ) VALUES (?, ?, ?, ?, ?)
    SQL
    db.execute(sql, [edinet_id, closing_date, item, context, value_id])
end

def process_csv(db, csv, edinet_id, closing_date)
    csv.each do |row|
        item = row[0].gsub(/[\-:]/, '_')
        insert_item(db, item, row[1])
        create_item_table(db, item)
        next if check_entry_exists?(db, edinet_id, closing_date, item, row[2])
        value_id = insert_value(db, item, row)
        insert_entry(db, edinet_id, closing_date, item, row[2], value_id)
    end
end

dirname = ARGV.shift

db = SQLite3::Database.new('edinet.db')

db.transaction do
    create_companies_table(db)
    create_entries_table(db)
    create_items_table(db)
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
                        unless insert_company(db, edinet_id, closing_date)
                            puts "Already exists #{edinet_id} #{closing_date}"
                            next
                        end
                        process_csv(db, csv, edinet_id, closing_date)
                    rescue SQLite3::Exception => e
                        db.rollback
                        puts "Exception occurred #{e.message}"
                    end                
                end
            end
        end
    end
end
