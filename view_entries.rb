require 'sqlite3'

def get_entries(db, item, context)
    sql = <<-SQL
        SELECT * FROM companies
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

rows = get_entries(db, "jppfs_cor_CapitalStock", "CurrentYearInstant_NonConsolidatedMember")
p rows.length
rows = get_entries(db, "jppfs_cor_NetAssets", "CurrentYearInstant_NonConsolidatedMember")
p rows.length