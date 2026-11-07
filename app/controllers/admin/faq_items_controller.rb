module Admin
  # add, change and remove the questions and answers on the home page
  class FaqItemsController < BaseController
    def create
      item = FaqItem.new(item_params.merge(position: (FaqItem.maximum(:position) || -1) + 1))
      if item.save
        redirect_to admin_website_path(anchor: "faq"), notice: "Question added."
      else
        redirect_to admin_website_path(anchor: "faq"), alert: item.errors.full_messages.to_sentence
      end
    end

    def update
      item = FaqItem.find(params[:id])
      if item.update(item_params)
        redirect_to admin_website_path(anchor: "faq"), notice: "Saved."
      else
        redirect_to admin_website_path(anchor: "faq"), alert: item.errors.full_messages.to_sentence
      end
    end

    def destroy
      FaqItem.find(params[:id]).destroy
      redirect_to admin_website_path(anchor: "faq"), notice: "Removed."
    end

    private

    def item_params = params.require(:faq_item).permit(:question, :answer, :position, :active)
  end
end
