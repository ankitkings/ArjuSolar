module Admin
  # Admin > Subsidy: the government subsidy rates used in quotes and on the website
  class SubsidySchemesController < BaseController
    def show
      @scheme = SubsidyScheme.current
    end

    def update
      @scheme = SubsidyScheme.current
      if @scheme.update(params.require(:subsidy_scheme).permit(:first_slab_kw, :first_rate, :cap_kw, :second_rate, :active))
        redirect_to admin_subsidy_path, notice: "Subsidy rates saved"
      else
        render :show, status: :unprocessable_entity
      end
    end
  end
end
