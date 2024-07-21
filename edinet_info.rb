require "csv"
require 'sqlite3'

def create_kinds_table(db)
    sql = <<-SQL
        CREATE TABLE IF NOT EXISTS kinds (
            edinet_id TEXT NOT NULL,
            kind TEXT NOT NULL,
            UNIQUE(edinet_id)
        );
    SQL
    db.execute(sql)

    sql = <<-SQL
    CREATE INDEX IF NOT EXISTS idx_edinet_id2 ON kinds
        (edinet_id)
    SQL
    db.execute(sql)
end

def insert_kind(db, edinet_id, kind)
    sql = <<-SQL
        SELECT kind FROM kinds
            WHERE edinet_id = ?
    SQL
    rows = db.execute(sql, [edinet_id])
    unless rows.empty?
        # puts "#{edinet_id} has been registered. Skip"
        if rows[0][0] != kind
            puts "#{edinet_id} : Dup and different value: Old:#{rows[0][0]}, New:#{kind}"
        end
        return
    end

    sql = <<-SQL
        INSERT INTO kinds (
            edinet_id,
            kind
        ) VALUES (?, ?)
    SQL
    db.execute(sql, [edinet_id, kind])
end

filename = ARGV.shift
dbname = ARGV.shift

db = SQLite3::Database.new(dbname)

db.transaction do
    create_kinds_table(db)
rescue SQLite3::Exception => e
    db.rollback
    puts "Exception occurred #{e.message}"
end

csv_data = open(filename, "r:SJIS:UTF-8") do |file|
    file.readline()
    file.read
end
csv = CSV.new(csv_data, headers: true)
csv.each do |row|
    db.transaction do
        puts "Inserting #{row['ＥＤＩＮＥＴコード']} #{row['提出者業種']}"
        insert_kind(db, row['ＥＤＩＮＥＴコード'], row['提出者業種'])
    rescue SQLite3::Exception => e
        db.rollback
        puts "Exception occurred #{e}"
    end                
end