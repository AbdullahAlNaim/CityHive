class ApplicationController < ActionController::API
  rescue_from ActionController::BadRequest,       with: :bad_request
  rescue_from ActionController::ParameterMissing, with: :bad_request
  rescue_from Mongoid::Errors::DocumentNotFound,  with: :not_found
  rescue_from Mongoid::Errors::Validations,       with: :unprocessable

  private

  def bad_request(exception)
    render_error(:bad_request, "bad_request", exception.message)
  end

  def not_found(_exception)
    render_error(:not_found, "not_found", "Resource not found")
  end

  def unprocessable(exception)
    messages = exception.document.errors.full_messages.to_sentence
    render_error(:unprocessable_entity, "validation_failed", messages)
  end

  def render_error(status, code, message)
    render json: { error: { code: code, message: message } }, status: status
  end
end
