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

file = File.open("#{outputname}.csv", "w")
file.print [0xEF, 0xBB, 0xBF].pack("C*")
csv = CSV.new(file)
csv << ["identifier", "name", "label", "value", "start_date", "end_date", "instant", "explicit_member"]

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

			contexts = {}
			xbrl.get_elements("//xbrli:context").each do |context|
				unless contexts.has_key?(context.attribute("id").value)
					id = context.attribute("id").value
					contexts[id] = {}
					period = REXML::XPath.first(context, "#{context.xpath}/xbrli:period")
					start_date = REXML::XPath.first(period, "#{period.xpath}/xbrli:startDate")
					contexts[id][:start_date] = start_date ? start_date.text : ""
					end_date = REXML::XPath.first(period, "#{period.xpath}/xbrli:endDate")
					contexts[id][:end_date] = end_date ? end_date.text : ""
					instant = REXML::XPath.first(period, "#{period.xpath}/xbrli:instant")
					contexts[id][:instant] = instant ? instant.text : ""
					identifier = REXML::XPath.first(context, "#{context.xpath}/xbrli:entity/xbrli:identifier")
					contexts[id][:identifier] = identifier ? identifier.text : ""
					contexts[id][:explicit_members] = REXML::XPath.match(context, "#{context.xpath}/xbrli:scenario/xbrldi:explicitMember").collect { |member|
						[member.attribute("dimension").value, member.text]
					}
				end
			end
			namespaces.each do |namespace, uri|
				elements = xbrl.get_elements("//#{namespace}:*")
				elements.each do |element|
					unit = element.attribute("unitRef")
					next if !unit or unit.value != "JPY"
					decimals = element.attribute("decimals")
					decimals = decimals ? Integer(decimals.value) : 0
					context = contexts[element.attribute("contextRef").value]
					context = {} unless context
					csv << [
						context[:identifier],
						"#{element.prefix}:#{element.name}",
						label_store[uri][element.name].first,
						element.text ? Integer(element.text) / (10 ** decimals) : nil,
						context[:start_date],
						context[:end_date],
						context[:instant],
						context[:explicit_members]
				].flatten
				end
			end
		end
	end
end
file.close
Marshal.dump(label_store, open("label_store.dat", "w"))