require 'sqlite3'

def get_entries(db, item, context)
    sql = <<-SQL
        SELECT entries.value FROM companies
            LEFT JOIN entries
                ON companies.edinet_id = entries.edinet_id AND
                   companies.closing_date = entries.closing_date AND
                   item = ? AND
                   context = ?
    SQL

    db.execute(sql, [item, context])
end

db = SQLite3::Database.new('edinet.db')

# capital_stocks = get_entries(db, "jppfs_cor_CapitalStock", "CurrentYearInstant_NonConsolidatedMember")
# netassets = get_entries(db, "jppfs_cor_NetAssets", "CurrentYearInstant_NonConsolidatedMember")
# capital_stocks.flatten.zip(netassets.flatten).each do |row|
#     puts Float(row[0]) / Integer(row[1])
# end

payrolls = get_entries(db, "jppfs_cor_PayrollAndAllowancesSGA", "CurrentYearDuration_NonConsolidatedMember")
puts "jppfs_cor_PayrollAndAllowancesSGA", payrolls.size, payrolls.count{ |x| not x[0].nil? }

wages = get_entries(db, "jppfs_cor_WagesSGA", "CurrentYearDuration_NonConsolidatedMember")
puts "jppfs_cor_WagesSGA", wages.size, wages.count{ |x| not x[0].nil? }

wages = get_entries(db, "jppfs_cor_SalariesSGA", "CurrentYearDuration_NonConsolidatedMember")
puts "jppfs_cor_SalariesSGA", wages.size, wages.count{ |x| not x[0].nil? }

wages = get_entries(db, "jppfs_cor_SalariesAndAllowancesSGA", "CurrentYearDuration_NonConsolidatedMember")
puts "jppfs_cor_SalariesAndAllowancesSGA", wages.size, wages.count{ |x| not x[0].nil? }

wages = get_entries(db, "jppfs_cor_SalariesAndAllowancesAndWelfareExpensesSGA", "CurrentYearDuration_NonConsolidatedMember")
puts "jppfs_cor_SalariesAndAllowancesAndWelfareExpensesSGA", wages.size, wages.count{ |x| not x[0].nil? }

wages = get_entries(db, "jppfs_cor_SalariesAndWagesSGA", "CurrentYearDuration_NonConsolidatedMember")
puts "jppfs_cor_SalariesAndWagesSGA", wages.size, wages.count{ |x| not x[0].nil? }

wages = get_entries(db, "jppfs_cor_SalariesAllowancesAndBonusesSGA", "CurrentYearDuration_NonConsolidatedMember")
puts "jppfs_cor_SalariesAllowancesAndBonusesSGA", wages.size, wages.count{ |x| not x[0].nil? }

wages = get_entries(db, "jpigp_cor_SalariesSGAIFRS", "CurrentYearDuration_NonConsolidatedMember")
puts "jpigp_cor_SalariesSGAIFRS", wages.size, wages.count{ |x| not x[0].nil? }

wages = get_entries(db, "jppfs_cor_SalariesAndAllowancesOECNA", "CurrentYearDuration_NonConsolidatedMember")
puts "jppfs_cor_SalariesAndAllowancesOECNA", wages.size, wages.count{ |x| not x[0].nil? }

wages = get_entries(db, "jppfs_cor_SalariesAndAllowancesSGAIVT", "CurrentYearDuration_NonConsolidatedMember")
puts "jppfs_cor_SalariesAndAllowancesSGAIVT", wages.size, wages.count{ |x| not x[0].nil? }

# wages = get_entries(db, "jpigp_cor_SalariesAndBonusesOperatingExpensesIFRS", "CurrentYearDuration_NonConsolidatedMember")
# puts "jpigp_cor_SalariesAndBonusesOperatingExpensesIFRS", wages.size, wages.count{ |x| not x[0].nil? }

wages = get_entries(db, "jppfs_cor_SalariesSGAIVT", "CurrentYearDuration_NonConsolidatedMember")
puts "jppfs_cor_SalariesSGAIVT", wages.size, wages.count{ |x| not x[0].nil? }

# wages = get_entries(db, "jpigp_cor_SalariesOperatingExpensesIFRS", "CurrentYearDuration_NonConsolidatedMember")
# puts "jpigp_cor_SalariesOperatingExpensesIFRS", wages.size, wages.count{ |x| not x[0].nil? }
