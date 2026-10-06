# Checks that uploaded files are normal photos (JPG / PNG / WebP, max 8 MB each)
module ImageAttachment
  extend ActiveSupport::Concern

  ALLOWED_TYPES = %w[image/jpeg image/png image/webp].freeze
  MAX_SIZE = 8.megabytes

  class_methods do
    # works for has_one_attached and has_many_attached
    def validates_image(name)
      validate do
        attachment = public_send(name)
        next unless attachment.attached?
        blobs = attachment.respond_to?(:blobs) ? attachment.blobs : [attachment.blob]
        errors.add(name, "must be JPG, PNG or WebP photos") if blobs.any? { |b| !ALLOWED_TYPES.include?(b.content_type) }
        errors.add(name, "must each be smaller than 8 MB") if blobs.any? { |b| b.byte_size > MAX_SIZE }
      end
    end
  end
end
