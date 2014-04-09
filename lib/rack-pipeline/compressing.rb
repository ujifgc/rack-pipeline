module RackPipeline
  module Compressing
    def self.process(source, target)
      ext = File.extname source
      if compressor = compressors[ext]
        require compressor[1]
        Compressing.const_get(compressor[0]).process(source, target)
      else
        warn "no compressor found for #{source}"
        source
      end
    end

    def self.register(ext, klass, feature)
      compressors[ext] = [klass, feature]
    end

    def self.compressors
      @compressors ||= {}
    end
  end
end

RackPipeline::Compressing.register '.js', 'Uglifier', 'rack-pipeline/compressing/uglifier'
