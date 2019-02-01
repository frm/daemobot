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

    GROUP_SUCCESS = 0
    GROUP_FAILED = 1
    GROUP_SWJ = 2

    def initialize
      @mutex = Mutex.new
    end

    def create_group(server, publ: false, name: "")
      @mutex.synchronize {
        status, group_url = make_group server, publ: publ, name: name
        if status == GROUP_SUCCESS
          MessageBuilder.group_created(group_url)
        elsif status == GROUP_SWJ
          MessageBuilder.swj_server(server)
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
      rescue SocketError, Errno::ECONNREFUSED, URI::InvalidURIError, Net::OpenTimeout
        # See group_request rescues
        nil
      end
    end

    def group_request(url, publ, name)
      begin
        res = HTTParty.post url, follow_redirects: false, :body => { public: publ ? "on" : "off", name: name }, :timeout => HTTP_TIMEOUT
        if res.code == 302
          [GROUP_SUCCESS, url.sub(/\/groups.*$/, res.response['location'])]
        elsif res.code == 301
          # SWJ servers are not supported
          [GROUP_SWJ, nil]
        else
          [GROUP_FAILED, nil]
        end
      rescue SocketError
        # Rescue from inexistent servers and locations
        # If it isn't valid, ignore it, nil will be returned
        # Otherwise the location will be sent
        [GROUP_FAILED, nil]
      rescue Errno::ECONNREFUSED, Net::OpenTimeout
        # Old, inactive servers still have active DNS rules
        # However, these don't give a socket error, but instead
        # a connection refused error. Handle those the same way
        [GROUP_FAILED, nil]
      rescue URI::InvalidURIError
        # Don't care about invalid URIs
        # Don't do anything
        [GROUP_FAILED, nil]
      end
    end

    def make_group(server, publ: false, name: "")
      status, group_url = [GROUP_FAILED, nil]
      build_group_urls(server).detect do |url|
        status, group_url = group_request(url, publ, name)
        status != GROUP_FAILED
      end
      [status, group_url]
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
