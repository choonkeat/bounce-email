require 'tmail'
require File.join(File.dirname(__FILE__), 'bounce-email.rb')

class MailUtil
  attr_accessor :raw, :bounce, :original

  def initialize(tmail_mail)
    @raw_text      = tmail_mail
    @raw           = TMail::Mail.parse(@raw_text)
    @bounce        = BounceEmail::Mail.new(@raw)
    @original      = get_original_email
    @feedback_type = feedback_report["feedback-type"]
    @bounce.type   = (@feedback_type && "Feedback Loop") || @bounce.type
  end

  def brief_bounce_reason
    @bounce.code || @bounce.reason || @feedback_type.to_s
  end

  def feedback_report
    @feedback_report ||= (get_embedded_mail(/\/feedback-report/i) || {})
  end

  private
    def delivery_status_headers
      if @delivery_status_headers.nil? && @delivery_status_headers = get_embedded_mail(/\/delivery-status/i)
        @delivery_status_headers = TMail::Mail.parse(@delivery_status_headers.body).header
      end
      @delivery_status_headers ||= {}
    end

    def get_original_email
      original = get_embedded_mail(/rfc822/i)
      return original if original
      # some mail servers append original email inline
      case @raw_text
      when /------ This is a copy of the message's headers. ------\n\n(.+)$/m,
           /------ This is a copy of the message, including all the headers. ------\n\n(.+)$/m,
           /--- Below this line is a copy of the message.\n\n(.+)$/m
        TMail::Mail.parse($1)
      else
        nil
      end
    end

    def get_embedded_mail(content_type_regexp)
      parts = select_parts_by_content_type(content_type_regexp, @raw.parts)
      if parts.empty?
        nil
      else
        TMail::Mail.parse(parts.flatten.compact.join("\n").sub(/\A.*?\n\n+/m, '')) # strip off "mime: header\n\n"
      end
    end

    def select_parts_by_content_type(content_type_regexp, parts, multipart_regexp = /multipart/i)
      (parts.select  {|x| content_type_regexp.match x['content-type'].to_s }) +
      (parts.select  {|x| multipart_regexp.match    x['content-type'].to_s }.
             collect {|x| select_parts_by_content_type(content_type_regexp, TMail::Mail.parse(x.to_s).parts) })
    end
end
