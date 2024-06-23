require 'sqlite3'

db = SQLite3::Database.new('edinet.db')

label = '純資産%'

sql = <<-SQL
    SELECT * FROM items
        WHERE label LIKE ?
SQL

rows = db.execute(sql, [label])
rows.each do |row|
    puts row
end