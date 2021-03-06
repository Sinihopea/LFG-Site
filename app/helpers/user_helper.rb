module UserHelper
  def expand_social_link(social)
    case social[0]
    when "link_twitter"
      "https://twitter.com/#{social[1]}"
    when "link_facebook"
      "https://www.facebook.com/#{social[1]}"
    when "link_googleplus"
      "https://plus.google.com/#{social[1]}"
    when "link_linkedin"
      "https://www.linkedin.com/profile/view?id=#{social[1]}"
    when "link_youtube"
      "https://www.youtube.com/channel/#{social[1]}"
    when "link_instagram"
      "https://instagram.com/#{social[1]}"
    else
      social[1]
    end
  end

  def to_b(b)
    b == "true"
  end
end
