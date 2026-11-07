module Admin
  # Admin > Website: what the public website says and shows
  class WebsiteController < BaseController
    def show
      @setting = SiteSetting.current
      load_lists
    end

    def update
      @setting = SiteSetting.current
      if @setting.update(setting_params)
        redirect_to admin_website_path, notice: "Saved. The changes are live on the website now."
      else
        load_lists
        render :show, status: :unprocessable_entity
      end
    end

    private

    def load_lists
      @contacts = ContactEntry.listed.to_a
      @faqs = FaqItem.listed.to_a
    end

    def setting_params
      params.require(:site_setting).permit(:company_name, :tagline, :hero_eyebrow, :hero_title, :hero_subtitle, :about_title, :about_text,
                                           :footer_text, :office_hours, :meta_description, :facebook_url, :instagram_url, :youtube_url,
                                           :linkedin_url, *SiteSetting::SECTIONS.keys)
    end
  end
end
