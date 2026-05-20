# Insert after ActionDispatch::RequestId so request.request_id is set.
class SemanticLoggerNamedTags
  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)
    SemanticLogger.named_tagged(
      request_id: request.request_id,
      ip:         request.remote_ip
    ) do
      @app.call(env)
    end
  end
end
