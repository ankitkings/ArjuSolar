module Staff
  # Site visitor: record the PM Surya Ghar documents taken from the client after the quote was accepted
  class SubsidyDocumentsController < BaseController
    def update
      task = current_staff.service_requests.find(params[:task_id])
      unless task.status == "quote_sent"
        return redirect_to(staff_task_path(task), alert: "Documents are collected once the quote has been sent.")
      end

      application = task.subsidy_application || SubsidyApplication.start_for!(task)
      before = application.collected_documents
      application.assign_attributes(document_params)
      if application.save
        newly = application.collected_documents - before
        if newly.any?
          note = "PM Surya Ghar documents collected: #{newly.to_sentence}"
          note += ". All 4 documents are now complete" if application.documents_complete?
          task.updates.create!(status: task.status, progress: task.progress, team_member: current_staff, note: note)
        end
        redirect_to staff_task_path(task), notice: "Documents saved – #{application.collected_documents.size} of #{SubsidyApplication::DOCUMENTS.size} collected."
      else
        redirect_to staff_task_path(task), alert: application.errors.full_messages.to_sentence
      end
    end

    private

    def document_params
      params.require(:subsidy_application).permit(*SubsidyApplication::DOCUMENTS.keys, *SubsidyApplication::DOCUMENTS.values.map { |d| d[:file] })
    end
  end
end
