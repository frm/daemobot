require 'httparty'

module Daemobot
  class TagPro
    HTTP_TIMEOUT = 5
    HTTP_BASE = 'http://'
    GROUP_URI = '/groups/create'
    STATS_URI = '/stats'
    KOALABEAST_URI = 'tagpro-%{server}.koalabeast.com'
    JUKEJUICE_URI = '%{server}.jukejuice.com'
    NEWCOMPTE_URI = '%{server}.newcompte.fr'
    SERVERS = [NEWCOMPTE_URI, JUKEJUICE_URI, KOALABEAST_URI]

    def initialize
      @mutex = Mutex.new
    end

    def create_group(server, publ: false, name: "")
      @mutex.synchronize {
        group_url = make_group server, publ: publ, name: name
        if group_url
          MessageBuilder.group_created(group_url)
        else
          MessageBuilder.unknown_server(server)
        end
      }
    end

    def server_stats(server)
      @mutex.synchronize {
        stats = get_server_stats(server)
        if stats
          MessageBuilder.stats_for(server, stats)
        else
          MessageBuilder.unknown_server(server)
        end
      }
    end

  private

    def build_group_urls(server)
      SERVERS.map do |url|
        HTTP_BASE + ( url % { server: server } ) + GROUP_URI
      end
    end

    def build_stats_urls(server)
      SERVERS.map do |url|
        HTTP_BASE + ( url % { server: server } ) + STATS_URI
      end
    end

    def stats_request(url)
      begin
        res = HTTParty.get url, follow_redirects: false, timeout: HTTP_TIMEOUT
        res.code == 404 ? nil : Utils.symbolize_hash(res.parsed_response)
      rescue SocketError, Errno::ECONNREFUSED, URI::InvalidURIError
        # See group_request rescues
        nil
      end
    end

    def group_request(url, publ, name)
      begin
        res = HTTParty.post url, follow_redirects: false, :body => { public: publ ? "on" : "off", name: name }, :timeout => HTTP_TIMEOUT
        url.sub(/\/groups.*$/, res.response['location']) if res.code == 302
      rescue SocketError
        # Rescue from inexistent servers and locations
        # If it isn't valid, ignore it, nil will be returned
        # Otherwise the location will be sent
        nil
      rescue Errno::ECONNREFUSED, Net::OpenTimeout
        # Old, inactive servers still have active DNS rules
        # However, these don't give a socket error, but instead
        # a connection refused error. Handle those the same way
        nil
      rescue URI::InvalidURIError
        # Don't care about invalid URIs
        # Don't do anything
        nil
      end
    end

    def make_group(server, publ: false, name: "")
      res = ""
      build_group_urls(server).detect do |url|
        res = group_request(url, publ, name)
      end
      res
    end

    def get_server_stats(server)
      res = {}
      build_stats_urls(server).detect do |url|
        res = stats_request(url)
      end
      res
    end
  end
end
