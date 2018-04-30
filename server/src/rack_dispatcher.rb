require_relative 'external'
require_relative 'runner'
require_relative 'well_formed_args'
require 'rack'

class RackDispatcher # stateless

  def initialize(cache)
    @cache = cache
  end

  def call(env, external = External.new, request = Rack::Request)
    name, args = name_args(request.new(env))
    runner = Runner.new(external, @cache)
    result = runner.public_send(name, *args)
    messages = external.log.messages
    body = {
      name => result,
      'log' => messages
    }
    if messages != []
      #external.writer.write(body)
    end
    triple(success, body)
  rescue => error
    body = {
      'exception' => error.message,
      'trace' => error.backtrace,
      'log' => external.log.messages
    }
    external.writer.write(body)
    triple(code(error), body)
  end

  private # = = = = = = = = = = = =

  include WellFormedArgs

  def name_args(request)
    name = request.path_info[1..-1] # lose leading /
    well_formed_args(request.body.read)
    args = case name
      when /^sha$/          then []
      when /^kata_new$/,
           /^kata_old$/     then [image_name, kata_id]
      when /^avatar_new$/   then [image_name, kata_id, avatar_name, starting_files]
      when /^avatar_old$/   then [image_name, kata_id, avatar_name]
      when /^run_cyber_dojo_sh$/
        [image_name, kata_id, avatar_name,
         new_files, deleted_files, unchanged_files, changed_files,
         max_seconds]
      else
        raise ClientError, 'json:malformed'
    end
    [name, args]
  end

  # - - - - - - - - - - - - - - - -

  def success
    200
  end

  def code(error)
    error.is_a?(ClientError) ? 400 : 500
  end

  def triple(code, body)
    [ code, { 'Content-Type' => 'application/json' }, [ body.to_json ] ]
  end

end
