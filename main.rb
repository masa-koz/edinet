require 'rubygems'
require 'zip'
require 'rexml/document'
require 'rexml/xpath'
require 'uri'
require 'csv'

labels = {}

def get_path_and_name(zip)
	zip.each do |entry|
		if entry.name =~ /(.*PublicDoc)\/([^\.]+)\.xbrl$/
			return $1, $2
		end
	end
end

def get_labels(xsd_doc, xsd_path, label_doc)
	store = {}
	elements = xsd_doc.get_elements("//element")
	if elements.empty?
		elements = xsd_doc.get_elements("//xsd:element")
	end

	locators_hash = {}
	label_doc.get_elements("//link:loc").each do |locator|
		locators_hash[locator.attribute("href").value] = locator.attribute("label").value
	end

	arcs_hash = {}
	label_doc.get_elements("//link:labelArc").each do |arc|
		unless arcs_hash.has_key?(arc.attribute("from").value)
			arcs_hash[arc.attribute("from").value] = [arc.attribute("to").value]
		else
			arcs_hash[arc.attribute("from").value].push(arc.attribute("to").value)
		end
	end

	labels_hash = {}
	label_doc.get_elements("//link:label").each do |label|
		labels_hash[label.attribute("label").value] = label.text
	end

	elements.each do |element|
		id = element.attribute("id").value
		name = element.attribute("name").value
		store[name] = []
		xlink_label = locators_hash["#{xsd_path}\##{id}"]
		arcs_hash[xlink_label].each do |label_id|
			store[name].push(labels_hash[label_id])
		end
	end
	store
end

if ARGV.length < 2
	exit(1)
end

datas = {}
xbrls = []
label_store = nil
if File.exist?("label_store.dat")
	label_store = Marshal.load(open("label_store.dat"))
else
	label_store = {}
end

dirname = ARGV.shift
outputname = ARGV.shift

topdir = Dir.pwd
Dir.mkdir(outputname) unless Dir.exist?(outputname)
outputdir = File.absolute_path(outputname)

Dir.chdir(dirname) do
	Dir.glob("*.zip") do |zipname|
		Zip::File.open(zipname) do |zipFile|
			path, doc_name = get_path_and_name(zipFile)
			xbrl = REXML::Document.new(zipFile.get_entry("#{path}/#{doc_name}.xbrl").get_input_stream.read)
			elements = xbrl.get_elements("//xbrli:xbrl")
			next if elements.empty?
			namespaces = elements[0].namespaces
			namespaces.delete_if {|key, val| URI.parse(val).host != "disclosure.edinet-fsa.go.jp" }
			namespaces.each do |namespace, uri|
				uri = URI.parse(uri)
				if uri.host == "disclosure.edinet-fsa.go.jp"
					params = uri.path.split("/")[1..]
					if params.first == "taxonomy"
						unless label_store.has_key?(uri.to_s)
							xsd_path = sprintf("%s_%s.xsd", params.join("/"), params[-2])
							label_path = sprintf("%s/label/%s_%s_lab.xml", params[0..-2].join("/"), params[1], params[-2])
							xsd_doc = REXML::Document.new(open("#{topdir}/#{xsd_path}"))
							xsd_relative_path = "../#{File.basename(xsd_path)}"
							label_doc = REXML::Document.new(open("#{topdir}/#{label_path}"))
							label_store[uri.to_s] = get_labels(xsd_doc, xsd_relative_path, label_doc)
						end
					elsif params.length == 7 && doc_name == "#{params[0]}-#{params[1]}-#{params[2]}_#{params[3]}_#{params[4]}_#{params[5]}_#{params[6]}"
						unless label_store.has_key?(uri.to_s)
							xsd_doc = REXML::Document.new(zipFile.get_entry("#{path}/#{doc_name}.xsd").get_input_stream.read)
							xsd_path = "#{doc_name}.xsd"
							label_doc = REXML::Document.new(zipFile.get_entry("#{path}/#{doc_name}_lab.xml").get_input_stream.read)
							label_store[uri.to_s] = get_labels(xsd_doc, xsd_path, label_doc)
						end
					end
				end
			end
			p label_store
			namespaces.each do |namespace, uri|
				elements = xbrl.get_elements("//#{namespace}:*")
				elements.each do |element|
					#p element
				end
			end
		end
	end
end

Marshal.dump(label_store, open("label_store.dat", "w"))

=begin
xbrls.each do |filename|
	doc = REXML::Document.new(open(filename))

	elements_jpdei_cor= doc.get_elements("//jpdei_cor:*")
	edi = REXML::XPath.first(elements_jpdei_cor, "//jpdei_cor:EDINETCodeDEI")
	unless edi
		$stderr.puts " Skip"
		next
	end

	docType = REXML::XPath.first(elements_jpdei_cor, "//jpdei_cor:DocumentTypeDEI")
	unless (docType and docType.text =~ /第三号様式/u)
		$stderr.puts " Skip: #{edi.text},#{docType.text}"
		next
	end
	$stderr.puts " Process: #{edi.text},#{docType.text}"

	name = REXML::XPath.first(elements_jpdei_cor, "//jpdei_cor:FilerNameInJapaneseDEI")
	start_date = REXML::XPath.first(elements_jpdei_cor, "//jpdei_cor:CurrentFiscalYearStartDateDEI")
	end_date = REXML::XPath.first(elements_jpdei_cor, "//jpdei_cor:CurrentFiscalYearEndDateDEI")
	industrialCode = REXML::XPath.first(elements_jpdei_cor, "//jpdei_cor:IndustryCodeWhenConsolidatedFinancialStatementsArePreparedInAccordanceWithIndustrySpecificRegulationsDEI")
	nonConsolidated_industrialCode = REXML::XPath.first(elements_jpdei_cor, "//jpdei_cor:IndustryCodeWhenFinancialStatementsArePreparedInAccordanceWithIndustrySpecificRegulationsDEI")

	elements_jpcrp_cor= doc.get_elements("//jpcrp_cor:*")

	balanceSheet = REXML::XPath.first(elements_jpcrp_cor, "//jpcrp_cor:ConsolidatedBalanceSheetTextBlock")
	nonConsolidated_balanceSheet = REXML::XPath.first(elements_jpcrp_cor, "//jpcrp_cor:BalanceSheetTextBlock")

	statementOfIncome = REXML::XPath.first(elements_jpcrp_cor, "//jpcrp_cor:ConsolidatedStatementOfIncomeTextBlock")
	nonConsolidated_statementOfIncome = REXML::XPath.first(elements_jpcrp_cor, "//jpcrp_cor:StatementOfIncomeTextBlock")

	businessCombination = REXML::XPath.first(elements_jpcrp_cor, "//jpcrp_cor:NotesBusinessCombinationsConsolidatedFinancialStatementsTextBlock")
	nonConsolidated_businessCombination = REXML::XPath.first(elements_jpcrp_cor, "//jpcrp_cor:NotesBusinessCombinationsFinancialStatementsTextBlock")

	taxEffect = REXML::XPath.first(elements_jpcrp_cor, "//jpcrp_cor:NotesTaxEffectAccountingConsolidatedFinancialStatementsTextBlock")
	nonConsolidated_taxEffect = REXML::XPath.first(elements_jpcrp_cor, "//jpcrp_cor:NotesTaxEffectAccountingFinancialStatementsTextBlock")

	elements_jppfs_cor= doc.get_elements("//jppfs_cor:*")

	# 繰延税金資産
	deferredTaxAssetsCA = REXML::XPath.first(elements_jppfs_cor, "//jppfs_cor:DeferredTaxAssetsCA[@contextRef='CurrentYearInstant']")
	deferredTaxAssetsIOA = REXML::XPath.first(elements_jppfs_cor, "//jppfs_cor:DeferredTaxAssetsIOA[@contextRef='CurrentYearInstant']")

	# 繰延税金負債
	deferredTaxLiabilitiesCL = REXML::XPath.first(elements_jppfs_cor, "//jppfs_cor:DeferredTaxLiabilitiesCL[@contextRef='CurrentYearInstant']")
	deferredTaxLiabilitiesNCL = REXML::XPath.first(elements_jppfs_cor, "//jppfs_cor:DeferredTaxLiabilitiesNCL[@contextRef='CurrentYearInstant']")
	deferredTaxLiabilitiesForLandRevaluation = REXML::XPath.first(elements_jppfs_cor, "//jppfs_cor:DeferredTaxLiabilitiesForLandRevaluation[@contextRef='CurrentYearInstant']")

	# 資産・負債
	netAssets = REXML::XPath.first(elements_jppfs_cor, "//jppfs_cor:NetAssets[@contextRef='CurrentYearInstant']")
	assets = REXML::XPath.first(elements_jppfs_cor, "//jppfs_cor:Assets[@contextRef='CurrentYearInstant']")
	liabilities = REXML::XPath.first(elements_jppfs_cor, "//jppfs_cor:Liabilities[@contextRef='CurrentYearInstant']")

	# 繰延税金資産（単体）
	nonConsolidated_deferredTaxAssetsCA = REXML::XPath.first(elements_jppfs_cor, "//jppfs_cor:DeferredTaxAssetsCA[@contextRef='CurrentYearInstant_NonConsolidatedMember']")
	nonConsolidated_deferredTaxAssetsIOA = REXML::XPath.first(elements_jppfs_cor, "//jppfs_cor:DeferredTaxAssetsIOA[@contextRef='CurrentYearInstant_NonConsolidatedMember']")

	# 繰延税金負債（単体）
	nonConsolidated_deferredTaxLiabilitiesCL = REXML::XPath.first(elements_jppfs_cor, "//jppfs_cor:DeferredTaxLiabilitiesCL[@contextRef='CurrentYearInstant_NonConsolidatedMember']")
	nonConsolidated_deferredTaxLiabilitiesNCL = REXML::XPath.first(elements_jppfs_cor, "//jppfs_cor:DeferredTaxLiabilitiesNCL[@contextRef='CurrentYearInstant_NonConsolidatedMember']")
	nonConsolidated_deferredTaxLiabilitiesForLandRevaluation = REXML::XPath.first(elements_jppfs_cor, "//jppfs_cor:DeferredTaxLiabilitiesForLandRevaluation[@contextRef='CurrentYearInstant_NonConsolidatedMember']")

	# 資産・負債（単体）
	nonConsolidated_netAssets = REXML::XPath.first(elements_jppfs_cor, "//jppfs_cor:NetAssets[@contextRef='CurrentYearInstant_NonConsolidatedMember']")
	nonConsolidated_assets = REXML::XPath.first(elements_jppfs_cor, "//jppfs_cor:Assets[@contextRef='CurrentYearInstant_NonConsolidatedMember']")
	nonConsolidated_liabilities = REXML::XPath.first(elements_jppfs_cor, "//jppfs_cor:Liabilities[@contextRef='CurrentYearInstant_NonConsolidatedMember']")

	incomeBeforeIncomeTaxes = REXML::XPath.first(elements_jppfs_cor, "//jppfs_cor:IncomeBeforeIncomeTaxes[@contextRef='CurrentYearDuration']")
	incomeTaxes = REXML::XPath.first(elements_jppfs_cor, "//jppfs_cor:IncomeTaxes[@contextRef='CurrentYearDuration']")
	incomeTaxesDeferred = REXML::XPath.first(elements_jppfs_cor, "//jppfs_cor:IncomeTaxesDeferred[@contextRef='CurrentYearDuration']")
	incomeTaxesCurrent = REXML::XPath.first(elements_jppfs_cor, "//jppfs_cor:IncomeTaxesCurrent[@contextRef='CurrentYearDuration']")
	
	nonConsolidated_incomeBeforeIncomeTaxes = REXML::XPath.first(elements_jppfs_cor, "//jppfs_cor:IncomeBeforeIncomeTaxes[@contextRef='CurrentYearDuration_NonConsolidatedMember']")
	nonConsolidated_incomeTaxes = REXML::XPath.first(elements_jppfs_cor, "//jppfs_cor:IncomeTaxes[@contextRef='CurrentYearDuration_NonConsolidatedMember']")
	nonConsolidated_incomeTaxesDeferred = REXML::XPath.first(elements_jppfs_cor, "//jppfs_cor:IncomeTaxesDeferred[@contextRef='CurrentYearDuration_NonConsolidatedMember']")
	nonConsolidated_incomeTaxesCurrent = REXML::XPath.first(elements_jppfs_cor, "//jppfs_cor:IncomeTaxesCurrent[@contextRef='CurrentYearDuration_NonConsolidatedMember']")

	datas[edi.text] = {}
	datas[edi.text][:name] = name ? name.text : ""

	datas[edi.text][:start_date] = start_date ? start_date.text : ""
	datas[edi.text][:end_date] = end_date ? end_date.text : ""

	datas[edi.text][:industrialCode] = industrialCode ? industrialCode.text : ""
	datas[edi.text][:nonConsolidated_industrialCode] = nonConsolidated_industrialCode ? nonConsolidated_industrialCode.text : ""

	datas[edi.text][:deferredTaxAssetsCA] = (deferredTaxAssetsCA and deferredTaxAssetsCA.has_text?) ? Integer(deferredTaxAssetsCA.text) : 0
	datas[edi.text][:deferredTaxAssetsIOA] = (deferredTaxAssetsIOA and deferredTaxAssetsIOA.has_text?) ? Integer(deferredTaxAssetsIOA.text) : 0

	datas[edi.text][:deferredTaxLiabilitiesCL] = (deferredTaxLiabilitiesCL and deferredTaxLiabilitiesCL.has_text?) ? Integer(deferredTaxLiabilitiesCL.text) : 0
	datas[edi.text][:deferredTaxLiabilitiesNCL] = (deferredTaxLiabilitiesNCL and deferredTaxLiabilitiesNCL.has_text?) ? Integer(deferredTaxLiabilitiesNCL.text) : 0
	datas[edi.text][:deferredTaxLiabilitiesForLandRevaluation] = (deferredTaxLiabilitiesForLandRevaluation and deferredTaxLiabilitiesForLandRevaluation.has_text?) ? Integer(deferredTaxLiabilitiesForLandRevaluation.text) : 0

	datas[edi.text][:netAssets] = (netAssets and netAssets.has_text?) ? Integer(netAssets.text) : 0
	datas[edi.text][:assets] = (assets and assets.has_text?) ? Integer(assets.text) : 0
	datas[edi.text][:liabilities] = (liabilities and liabilities.has_text?) ? Integer(liabilities.text) : 0

	datas[edi.text][:nonConsolidated_deferredTaxAssetsCA] = (nonConsolidated_deferredTaxAssetsCA and nonConsolidated_deferredTaxAssetsCA.has_text?) ? Integer(nonConsolidated_deferredTaxAssetsCA.text) : 0
	datas[edi.text][:nonConsolidated_deferredTaxAssetsIOA] = (nonConsolidated_deferredTaxAssetsIOA and nonConsolidated_deferredTaxAssetsIOA.has_text?) ? Integer(nonConsolidated_deferredTaxAssetsIOA.text) : 0

	datas[edi.text][:nonConsolidated_deferredTaxLiabilitiesCL] = (nonConsolidated_deferredTaxLiabilitiesCL and nonConsolidated_deferredTaxLiabilitiesCL.has_text?) ? Integer(nonConsolidated_deferredTaxLiabilitiesCL.text) : 0
	datas[edi.text][:nonConsolidated_deferredTaxLiabilitiesNCL] = (nonConsolidated_deferredTaxLiabilitiesNCL and nonConsolidated_deferredTaxLiabilitiesNCL.has_text?) ? Integer(nonConsolidated_deferredTaxLiabilitiesNCL.text) : 0
	datas[edi.text][:nonConsolidated_deferredTaxLiabilitiesForLandRevaluation] = (nonConsolidated_deferredTaxLiabilitiesForLandRevaluation and nonConsolidated_deferredTaxLiabilitiesForLandRevaluation.has_text?) ? Integer(nonConsolidated_deferredTaxLiabilitiesForLandRevaluation.text) : 0

	datas[edi.text][:nonConsolidated_netAssets] = (nonConsolidated_netAssets and nonConsolidated_netAssets.has_text?) ? Integer(nonConsolidated_netAssets.text) : 0
	datas[edi.text][:nonConsolidated_assets] = (nonConsolidated_assets and nonConsolidated_assets.has_text?) ? Integer(nonConsolidated_assets.text) : 0
	datas[edi.text][:nonConsolidated_liabilities] = (nonConsolidated_liabilities and nonConsolidated_liabilities.has_text?) ? Integer(nonConsolidated_liabilities.text) : 0

	datas[edi.text][:incomeBeforeIncomeTaxes] = (incomeBeforeIncomeTaxes and incomeBeforeIncomeTaxes.has_text?) ? Integer(incomeBeforeIncomeTaxes.text) : 0
	datas[edi.text][:incomeTaxes] = (incomeTaxes and incomeTaxes.has_text?) ? Integer(incomeTaxes.text) : 0
	datas[edi.text][:incomeTaxesCurrent] = (incomeTaxesCurrent and incomeTaxesCurrent.has_text?) ? Integer(incomeTaxesCurrent.text) : 0
	datas[edi.text][:incomeTaxesDeferred] = (incomeTaxesDeferred and incomeTaxesDeferred.has_text?) ? Integer(incomeTaxesDeferred.text) : 0

	datas[edi.text][:nonConsolidated_incomeBeforeIncomeTaxes] = (nonConsolidated_incomeBeforeIncomeTaxes and nonConsolidated_incomeBeforeIncomeTaxes.has_text?) ? Integer(nonConsolidated_incomeBeforeIncomeTaxes.text) : 0
	datas[edi.text][:nonConsolidated_incomeTaxes] = (nonConsolidated_incomeTaxes and nonConsolidated_incomeTaxes.has_text?) ? Integer(nonConsolidated_incomeTaxes.text) : 0
	datas[edi.text][:nonConsolidated_incomeTaxesCurrent] = (nonConsolidated_incomeTaxesCurrent and nonConsolidated_incomeTaxesCurrent.has_text?) ? Integer(nonConsolidated_incomeTaxesCurrent.text) : 0
	datas[edi.text][:nonConsolidated_incomeTaxesDeferred] = (nonConsolidated_incomeTaxesDeferred and nonConsolidated_incomeTaxesDeferred.has_text?) ? Integer(nonConsolidated_incomeTaxesDeferred.text) : 0

	puts <<"HTML"
<h2 id=\"#{edi.text}\">#{name.text if name}（#{edi.text}）</h2>
<h3 id=\"#{edi.text}_cbs\">Consolidated balanceSheet</h3>
#{balanceSheet.text if balanceSheet}
<h3>balanceSheet</h3>
#{nonConsolidated_balanceSheet.text if nonConsolidated_balanceSheet}

<h3 id=\"#{edi.text}_cin\">Consolidated statementOfIncome</h3>
#{statementOfIncome.text if statementOfIncome}
<h3>statementOfIncome</h3>
#{nonConsolidated_statementOfIncome.text if nonConsolidated_statementOfIncome}

<h3 id=\"#{edi.text}_cc\">businessCombination</h3>
#{businessCombination.text if businessCombination}
<h3>combination</h3>
#{nonConsolidated_businessCombination.text if nonConsolidated_businessCombination}

<h3 id=\"#{edi.text}_cte\">taxEffect</h3>
#{taxEffect.text if taxEffect}
<h3>nonConsolidated_taxEffect</h3>
#{nonConsolidated_taxEffect.text if nonConsolidated_taxEffect}
HTML
end

puts <<"HTML"
<table border="1">
  <tr>
    <th>コード</th>
    <th>名称</th>
    <th></th>
    <th></th>
    <th></th>
    <th></th>
 </tr>
HTML

file = File.open("#{outputname}.csv", "w")
file.print [0xEF, 0xBB, 0xBF].pack("C*")
csv = CSV.new(file)
csv << ["コード", "名称",
	"産業コード（連結）", "産業コード（単体）",
	"開始", "終了",
	#G, H, I, J, K
	"税引前利益（連結）", "法人税等合計（連結）", "法人税等（連結）", "法人税等支払額（連結）", "法人税等調整額（連結）",
	#L
	"繰延税金資産負債（連結）",
	#M, N, O
	"繰延税金資産合計（連結）", "繰延税金資産（流動）（連結）", "繰延税金資産（固定）（連結）", 
	#P, Q, R, S 
	"繰延税金負債合計（連結）", "繰延税金負債（流動）（連結）", "繰延税金負債（固定）（連結）", "繰延税金負債（再評価）（連結）", 
	#T, U, V
	"総資産（連結）", "負債（連結）", "純資産（連結）", 
	#W, X, Y, Z, AA
	"税引前利益（単体）", "法人税等合計（単体）", "法人税等（単体）", "法人税支払額（単体）", "法人税等調整額（単体）",
	#AB
	"繰延税金資産負債（単体）",
	#AC, AD, AE
	"繰延税金資産合計（単体）", "繰延税金資産（流動）（単体）", "繰延税金資産（固定）（単体）", 
	#AF, AG, AH, AI
	"繰延税金負債合計（単体）", "繰延税金負債（流動）（単体）", "繰延税金負債（固定）（単体）", "繰延税金負債（再評価）（単体）", 
	#AJ, AK, AL
	"総資産（単体）", "負債（単体）", "純資産（単体）"]
datas.each do |key, val|
	puts <<"HTML"
  <tr>
    <td><a href="##{key}">#{key}</a></td>
    <td>#{val[:name]}</td>
    <td><a href="##{key}_cbs">貸借対照表</a></td>
    <td><a href="##{key}_cin">損益計算書</a></td>
    <td><a href="##{key}_cc">企業結合関係</a></td>
    <td><a href="##{key}_cte">税効果会計</a></td>
  </tr>
HTML
	csv << [key, val[:name],
		val[:industrialCode], val[:nonConsolidated_industrialCode], 
		val[:start_date], val[:end_date], 
		val[:incomeBeforeIncomeTaxes], "=J#{csv.lineno+1}+K#{csv.lineno+1}", val[:incomeTaxes], val[:incomeTaxesCurrent], val[:incomeTaxesDeferred],
		"=M#{csv.lineno+1}-P#{csv.lineno+1}",
		"=N#{csv.lineno+1}+O#{csv.lineno+1}", val[:deferredTaxAssetsCA], val[:deferredTaxAssetsIOA], 
		"=Q#{csv.lineno+1}+R#{csv.lineno+1}", val[:deferredTaxLiabilitiesCL], val[:deferredTaxLiabilitiesNCL], val[:deferredTaxLiabilitiesForLandRevaluation], 
		val[:assets], val[:liabilities], val[:netAssets], 
		val[:nonConsolidated_incomeBeforeIncomeTaxes], "=Z#{csv.lineno+1}+AA#{csv.lineno+1}", val[:nonConsolidated_incomeTaxes], val[:nonConsolidated_incomeTaxesCurrent], val[:nonConsolidated_incomeTaxesDeferred],
		"=AC#{csv.lineno+1}-AF#{csv.lineno+1}",
		"=AD#{csv.lineno+1}+AE#{csv.lineno+1}", val[:nonConsolidated_deferredTaxAssetsCA], val[:nonConsolidated_deferredTaxAssetsIOA], 
		"=AG#{csv.lineno+1}+AH#{csv.lineno+1}", val[:nonConsolidated_deferredTaxLiabilitiesCL], val[:nonConsolidated_deferredTaxLiabilitiesNCL], val[:nonConsolidated_deferredTaxLiabilitiesForLandRevaluation], 
		val[:nonConsolidated_assets], val[:nonConsolidated_liabilities], val[:nonConsolidated_netAssets]]
end

puts <<"HTML"
</table>
HTML
file.close
=end