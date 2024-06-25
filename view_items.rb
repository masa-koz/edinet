require 'sqlite3'

db_path = ARGV.shift
db = SQLite3::Database.new(db_path)

label = '役員%'

sql = <<-SQL
    SELECT * FROM items
        WHERE label LIKE ?
SQL

rows = db.execute(sql, [label])
rows.each do |row|
    puts row
end