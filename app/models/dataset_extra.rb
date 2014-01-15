class DatasetExtra < ActiveRecord::Base
  def self.load_thumbnails
    params = {page: 0, page_size: 20}
    processed_count = 0

    begin
      params[:page] += 1
      response = Echo::Client.get_datasets(params)
      datasets = response.body
      hits = response.headers['echo-hits'].to_i

      datasets.each do |dataset|
        extra = DatasetExtra.find_or_create_by(echo_id: dataset.id)

        # Skip datasets that we've seen before which have no browseable granules.  Saves tons of time
        if extra.has_browseable_granules.nil? || extra.has_browseable_granules
          granules = Echo::Client.get_granules(format: 'echo10', echo_collection_id: dataset.id, page_size: 1, browse_only: true).body

          granule = granules.first
          if granule
            extra.thumbnail_url = granule.browse_urls.first
            puts "First result for dataset has no browse: #{dataset.id}" if extra.thumbnail_url.nil?
          end

          extra.has_browseable_granules = !granule.nil?
          extra.save
        end

        processed_count += 1

        puts "#{processed_count} / #{hits}"
      end
    end while processed_count < hits && datasets.size > 0

    nil
  end

  def self.decorate_all(datasets)
    datasets = datasets.as_json
    ids = datasets.map {|r| r['id']}
    extras = DatasetExtra.where(echo_id: ids).index_by(&:echo_id)

    datasets.map do |result|
      extra = extras[result['id']] || DatasetExtra.new
      extra.decorate(result)
    end
  end

  def decorate(dataset)
    dataset = dataset.dup
    dataset[:thumbnail] = self.thumbnail_url
    dataset
  end
end