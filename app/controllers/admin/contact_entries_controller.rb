module Admin
  # add, change and remove the phone numbers, e-mails and addresses shown on the website
  class ContactEntriesController < BaseController
    def create
      entry = ContactEntry.new(entry_params.merge(position: (ContactEntry.maximum(:position) || -1) + 1))
      if entry.save
        redirect_to admin_website_path(anchor: "contacts"), notice: "#{entry.kind_label} added."
      else
        redirect_to admin_website_path(anchor: "contacts"), alert: entry.errors.full_messages.to_sentence
      end
    end

    def update
      entry = ContactEntry.find(params[:id])
      if entry.update(entry_params)
        redirect_to admin_website_path(anchor: "contacts"), notice: "Saved."
      else
        redirect_to admin_website_path(anchor: "contacts"), alert: "#{entry.value}: #{entry.errors.full_messages.to_sentence}"
      end
    end

    def destroy
      ContactEntry.find(params[:id]).destroy
      redirect_to admin_website_path(anchor: "contacts"), notice: "Removed."
    end

    private

    def entry_params = params.require(:contact_entry).permit(:kind, :label, :value, :position, :active)
  end
end
