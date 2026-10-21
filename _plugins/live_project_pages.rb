# Builds one page per Live Project at /live-projects/<name>/, straight from
# _data/live_projects.yml, so adding a project in Pages CMS is enough to get
# its page. Nothing to fill in by hand beyond the CMS fields.
#
# Each page gets:
#   - the project's description and YouTube video (the "video" field; if that
#     is empty and the old "link" field is a YouTube link, that one is used)
#   - every gig from _data/gigs.yml whose project matches. A gig matches when
#     its project equals the project name, or starts with it followed by a
#     space, so "Spooky-J (DJ)" lands on Spooky-J and "Toni Geitani + Marmoucha
#     Orchestra" lands on Toni Geitani. Matching ignores upper/lower case.
#     To match other names, list them in "gig_names" (e.g. the "Dis Fig x
#     Spooky-J" project lists "Dis Fig").
module LiveProjectPages
  YOUTUBE = %r{(?:youtu\.be/|youtube\.com/(?:watch\?(?:[^#\s]*&)?v=|embed/|shorts/|live/))([A-Za-z0-9_-]{11})}i

  def self.youtube_id(value)
    return nil unless value.is_a?(String)
    value = value.strip
    return value if value =~ /\A[A-Za-z0-9_-]{11}\z/
    (m = value.match(YOUTUBE)) ? m[1] : nil
  end

  def self.match_names(project)
    names = Array(project["gig_names"]).map(&:to_s).reject { |n| n.strip.empty? }
    names = [project["name"].to_s] if names.empty?
    names.map { |n| n.strip.downcase }
  end

  def self.matches?(gig_project, names)
    p = gig_project.to_s.strip.downcase
    return false if p.empty?
    names.any? { |n| p == n || p.start_with?("#{n} ") }
  end

  class Generator < Jekyll::Generator
    safe true
    priority :low

    def generate(site)
      projects = site.data["live_projects"]
      return unless projects.is_a?(Array)
      gigs = site.data["gigs"].is_a?(Array) ? site.data["gigs"] : []
      used = {}

      projects.each do |project|
        next unless project.is_a?(Hash) && !project["name"].to_s.strip.empty?

        slug = Jekyll::Utils.slugify(project["name"].to_s)
        slug = "project" if slug.empty?
        slug = "#{slug}-#{used[slug] + 1}" if used[slug]
        used[slug] = (used[slug] || 0) + 1

        video_id = LiveProjectPages.youtube_id(project["video"]) ||
                   LiveProjectPages.youtube_id(project["link"])
        external = project["link"].to_s.strip
        external = "" if LiveProjectPages.youtube_id(external)

        names = LiveProjectPages.match_names(project)
        matched = gigs.select { |g| g.is_a?(Hash) && LiveProjectPages.matches?(g["project"], names) }
                      .sort_by { |g| g["date"].to_s }

        url = "/live-projects/#{slug}/"
        project["url"] = url

        page = Jekyll::PageWithoutAFile.new(site, site.source, "live-projects/#{slug}", "index.html")
        page.content = ""
        page.data.merge!(
          "layout" => "live-project",
          "title" => project["name"].to_s,
          "permalink" => url,
          "project" => project,
          "video_id" => video_id,
          "external_link" => external,
          "gigs" => matched
        )
        page.data["image"] = project["image"] if project["image"].to_s != ""
        site.pages << page
      end
    end
  end
end
