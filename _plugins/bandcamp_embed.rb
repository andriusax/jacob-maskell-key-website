# Looks up the Bandcamp album/track number for every Discography and Remixes
# entry at build time, so the cards can show an inline Bandcamp player.
# Nothing to fill in by hand: paste the normal Bandcamp link in Pages CMS and
# the player appears on the next build. If a lookup fails (or the link isn't
# Bandcamp), the card simply falls back to linking out, as before.
# To force a specific player, add `bandcamp_id` (and optionally
# `bandcamp_type: track`) to an entry in the data file.
require "net/http"
require "uri"
require "json"
require "cgi"

module BandcampEmbed
  CACHE = {}
  LINK = %r{\Ahttps?://[^/\s]*bandcamp\.com/(album|track)/}i

  def self.lookup(url)
    return nil unless url.is_a?(String) && url.strip =~ LINK
    url = url.strip
    return CACHE[url] if CACHE.key?(url)
    CACHE[url] = fetch(url)
  end

  def self.parse(html)
    if (m = html.match(%r{EmbeddedPlayer/(?:v=2/)?(album|track)=(\d+)}))
      return { "type" => m[1], "id" => m[2] }
    end
    if (m = html.match(/bc-page-properties"\s+content="([^"]+)"/i))
      props = JSON.parse(CGI.unescapeHTML(m[1]))
      return { "type" => (props["item_type"] == "t" ? "track" : "album"), "id" => props["item_id"].to_s }
    end
    nil
  end

  def self.fetch(url, redirects = 3)
    uri = URI.parse(url)
    res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                          open_timeout: 10, read_timeout: 20) do |http|
      http.request(Net::HTTP::Get.new(uri.request_uri, "User-Agent" => "Mozilla/5.0 (jacobmkey.work site build)"))
    end
    if res.is_a?(Net::HTTPRedirection) && redirects > 0
      return fetch(URI.join(url, res["location"]).to_s, redirects - 1)
    end
    unless res.is_a?(Net::HTTPSuccess)
      Jekyll.logger.warn "Bandcamp:", "#{url} returned #{res.code}, card will link out instead"
      return nil
    end
    info = parse(res.body.to_s)
    Jekyll.logger.warn "Bandcamp:", "no player id found on #{url}" unless info
    info
  rescue StandardError => e
    Jekyll.logger.warn "Bandcamp:", "couldn't look up #{url} (#{e.class}: #{e.message})"
    nil
  end
end

module Jekyll
  class BandcampEmbedGenerator < Generator
    safe true
    priority :high

    def generate(site)
      %w[discography remixes].each do |key|
        list = site.data[key]
        next unless list.is_a?(Array)
        list.each do |item|
          next unless item.is_a?(Hash)
          if item["bandcamp_id"].to_s.strip != ""
            item["bandcamp_type"] = "album" if item["bandcamp_type"].to_s.strip == ""
            next
          end
          info = BandcampEmbed.lookup(item["link"])
          next unless info
          item["bandcamp_type"] = info["type"]
          item["bandcamp_id"] = info["id"]
        end
      end
    end
  end
end
