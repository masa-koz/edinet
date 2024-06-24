require 'sqlite3'

def get_entries(db, item, context)
    sql = <<-SQL
        SELECT item_#{item}.value FROM companies
            LEFT JOIN entries
                ON companies.edinet_id = entries.edinet_id AND
                   companies.closing_date = entries.closing_date AND
                   item = ? AND
                   context = ?
            LEFT JOIN item_#{item}
                ON entries.value_id = item_#{item}.id
    SQL

    db.execute(sql, [item, context])
end

db = SQLite3::Database.new('edinet.db')

capital_stocks = get_entries(db, "jppfs_cor_CapitalStock", "CurrentYearInstant_NonConsolidatedMember")
netassets = get_entries(db, "jppfs_cor_NetAssets", "CurrentYearInstant_NonConsolidatedMember")
capital_stocks.flatten.zip(netassets.flatten).each do |row|
    puts Float(row[0]) / Integer(row[1])
end