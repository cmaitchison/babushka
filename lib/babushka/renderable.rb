module Babushka
  class Renderable
    include ShellHelpers
    include RunHelpers

    SEAL_REGEXP = /# Generated by babushka-[\d\.]+ at [a-zA-Z\d\-\:\s+]+, from [0-9a-f]{40}+\. [0-9a-f]{40}/

    attr_reader :path
    def initialize path
      @path = path
    end

    def render source, opts = {}
      shell("cat > '#{path}'",
        :input => inkan_output_for(source, opts),
        :sudo => opts[:sudo]
      ).tap {|result|
        if result
          sudo "chmod #{opts[:perms]} '#{path}'" if opts[:perms]
        end
      }
    end

    def exists?
      path.p.exists?
    end

    def clean?
      Inkan.legitimate? path
    end

    def from? source
      exists? && source_sha == sha_of(source)
    end

    private

    def inkan_output_for source, opts = {}
      Inkan.render {|inkan|
        inkan.credit = "Generated #{_by_babushka}, from #{sha_of(source)}"
        inkan.comment = opts[:comment] if opts[:comment]
        inkan.comment_suffix = opts[:comment_suffix] if opts[:comment_suffix]
        inkan.print render_erb(source, opts[:context])
      }
    end

    def render_erb source, custom_context
      require 'erb'
      (custom_context || self).instance_eval {
        ERB.new(source.p.read).result(binding)
      }
    end

    def sha_of source
      require 'digest/sha1'
      raise "Source doesn't exist: #{source.p}" unless source.p.exists?
      Digest::SHA1.hexdigest(source.p.read)
    end

    def source_sha
      shell(
        'head', '-n2', path.p, :sudo => !path.p.readable?
      ).split("\n").detect {|l|
        l[/^#!/].nil? # The first non-hashbang line of the top two lines
      }.scan(/, from ([0-9a-f]{40})\./).flatten.first
    end
  end
end

