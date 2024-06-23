require 'date'
require 'faraday'


def make_day_array(start_day, end_day)
    (Date.parse(start_day)..Date.parse(end_day)).to_a
end

def make_doc_id_array(conn, day_array)
    doc_id_array = []
    day_array.each do |day|
        response = conn.get do |req|
            req.params[:date] = day
            req.params[:type] = 2
        end
        response.body["results"].each do |result|
            if result["ordinanceCode"] == "010" && result["formCode"] == "030000"
                puts "#{result['filerName']}, #{result['submitDateTime']}, #{result['docID']}"
                doc_id_array.push(result["docID"])
            end
        end
    end
    doc_id_array
end

def download_xrbl(conn, output_dir, doc_id_array)
    doc_id_array.each do |doc_id|
        puts "Downloading #{doc_id}..."
        response = conn.get do |req|
            req.url "/api/v2/documents/#{doc_id}"
            req.params[:type] = 1
        end
        puts "Downloading #{doc_id}... done."
        File.open("#{output_dir}/#{doc_id}.zip", "wb") do |file|
            file.write(response.body)
        end
    end
end

def download_csv(conn, output_dir, doc_id_array)
    doc_id_array.each do |doc_id|
        puts "Downloading #{doc_id}..."
        response = conn.get do |req|
            req.url "/api/v2/documents/#{doc_id}"
            req.params[:type] = 5
        end
        puts "Downloading #{doc_id}... done."
        File.open("#{output_dir}/#{doc_id}.zip", "wb") do |file|
            file.write(response.body)
        end
    end
end

api_key = File.open("api_key.txt").read.gsub(/\n/, '') # read api_key from file
start_date = ARGV.shift
end_date = ARGV.shift
output_dir = ARGV.shift

if File.exist?(output_dir)
    unless File.directory?(output_dir)
        STDERR.puts "The specified output directory(#{output_dir}) is not a directory."
        exit(1)
    end
else
    Dir.mkdir(output_dir)
end

conn = Faraday.new(:url => 'https://api.edinet-fsa.go.jp/api/v2/documents.json') do |builder|
    #builder.use Faraday::Response::Logger
    builder.adapter Faraday::Adapter::NetHttp
    builder.params['Subscription-Key'] = api_key
    builder.response :json, :content_type => /\bjson$/
end

day_array = make_day_array(start_date, end_date)
doc_id_array = make_doc_id_array(conn, day_array)
#download_xrbl(conn, output_dir, doc_id_array)
download_csv(conn, output_dir, doc_id_array)