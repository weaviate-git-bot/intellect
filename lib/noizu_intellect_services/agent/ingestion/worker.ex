defmodule Noizu.Intellect.Service.Agent.Ingestion.Worker do
  use Noizu.Entities
  require Noizu.Service.Types

  require Noizu.Intellect.LiveEventModule
  import Noizu.Intellect.LiveEventModule

  require Noizu.Service.Types
  alias Noizu.Service.Types, as: M

  @vsn 1.0
  @sref "worker-ingest-agent"
  @persistence redis_store(Noizu.Intellect.Service.Agent.Ingestion.Worker, Noizu.Intellect.Redis)
  def_entity do
    identifier :dual_ref
    field :agent, nil, Noizu.Entity.Reference
    field :account, nil, Noizu.Entity.Reference
    field :channel, nil, Noizu.Entity.Reference
    field :objectives, []
    field :book_keeping, %{}
    field :time_stamp, nil, Noizu.Entity.TimeStamp
  end
  use Noizu.Service.Worker.Behaviour

  #-------------------
  #
  #-------------------
  def init(R.ref(module: __MODULE__, identifier: identifier), _args, context) do
    Logger.error("WORKER INIT| #{inspect identifier}")
    self = self()
    spawn(fn ->
      Process.sleep(100)
      Noizu.Intellect.Service.Agent.Ingestion.fetch(identifier, :state, context, nil)
    end)
    %__MODULE__{
      identifier: identifier,
    }
  end

  #-------------------
  #
  #-------------------

  #-------------------
  #
  #-------------------

  #-------------------
  #
  #-------------------
  def load(state, context), do: load(state, context, nil)
  def load(state, context, options) do
    Logger.error("WORKER LOAD| #{inspect state.identifier}")
    with {:ok, worker} <- entity(state.identifier, context) do
      {:ok, worker}
    else
      _ ->
        # TODO we need to handle ref identifiers so we can use the actual ref as our id.
        with {:ok, {agent, channel}} <- id(state.identifier),
             {:ok, agent_entity} <- Noizu.Intellect.Account.Agent.entity(agent, context),
             {:ok, channel_entity} <- Noizu.Intellect.Account.Channel.entity(channel, context),
             {:ok, account} <- ERP.ref(agent_entity.account) do
          worker = %__MODULE__{
                     identifier: state.identifier,
                     agent: agent_entity,
                     channel: channel_entity,
                     account: account
                   } |> shallow_persist(context, options)
          {:ok, worker}
        end
    end
    |> case do
         {:ok, worker} ->
           state = %{state| status: :loaded, worker: worker}
                   |> queue_heart_beat(context, options)
           {:ok, state}
         _ -> {:error, state}
       end
  end

  #---------------------
  #
  #---------------------
  def queue_heart_beat(state, context, options \\ nil, fuse \\ 10_000) do
    # Start HeartBeat
    _identifier = {self(), :os.system_time(:millisecond)}
    _settings = apply(__pool__(), :__cast_settings__, [])
    _timeout = 15_000
    fuse = div(fuse, 2)
    fuse = fuse + :rand.uniform(fuse) + :rand.uniform(fuse)

    msg = M.s(call: M.call(handler: :heart_beat), context: context, options: options)
    timer = Process.send_after(self(), msg, fuse)
    put_in(state, [Access.key(:worker), Access.key(:book_keeping, %{}), :heart_beat], timer)
  end

  def unread_messages?(state,context,options) do
    cond do
      state.worker.channel.type == :session -> session_unread_messages?(state, context, options)
      state.worker.channel.type == :chat -> session_unread_messages?(state, context, options)
      :else -> channel_unread_messages?(state,context,options)
    end
  end

  def session_unread_messages?(state, context, options) do
    # TODO - logic depends on channel type
    # Noizu.Intellect.Account.Message.Repo.has_unread?(state.worker.agent, state.worker.channel, context, options)
    now = DateTime.utc_now()
    with {:ok, o} <- message_history(state, context, options)  do
      unless unread = Enum.find_value(o, &(is_nil(&1.read_on) && &1.priority && &1.priority >= 50 && DateTime.compare(&1.time_stamp.created_on, now) == :lt  || nil)) do
        false
      else
        true
      end
    else
      _ -> false
    end
  end

  def channel_unread_messages?(state,context,options) do
    # TODO - logic depends on channel type
    # Noizu.Intellect.Account.Message.Repo.has_unread?(state.worker.agent, state.worker.channel, context, options)
    with {:ok, o} <- message_history(state, context, options)  do
      unless unread = Enum.find_value(o, &(is_nil(&1.read_on) && &1.priority && &1.priority >= 50 && &1.event not in [:system_minder, :system_message] && true || nil)) do
#        inbox = Enum.filter(o, &(is_nil(&1.read_on)))
#                |> length()
#        inbox > 20
         false
      else
        true
      end
      #Enum.find_value(o, &(is_nil(&1.read_on) && true || nil))
    else
      _ -> false
    end
  end

  def message_history(state,context,options) do
    cond do
      state.worker.channel.type == :session -> session_message_history(state, context, options)
      state.worker.channel.type == :chat -> session_message_history(state, context, options)
      :else -> session_message_history(state,context,options)
    end
  end

  def session_message_history(state,context, options) do
    channel_message_history(state,context,options)
  end

  def channel_message_history(state,context,options) do
    # TODO - logic depends on channel type

    # We'll actually pull agent digest messages, etc. here.

    # 1. get unprocessed
    # 2. for each get responding_to
    # 3. for all get features
    # 4. for unprocessed get near text
    # 5. query messages with tags in channel

    Noizu.Intellect.Account.Channel.Repo.relevant_or_recent(state.worker.agent, state.worker.channel, context, options)
#    with {:ok, x} <- o do
#      # Enum.map(x, fn(msg) -> msg.identifier == 7027 && IO.inspect(msg) end)
#      Enum.map(x, &(IO.puts "#{state.worker.agent.slug} - #{&1.identifier} - priority: #{&1.priority || "NONE"}, read: #{&1.read_on || "NONE"} - #{&1.time_stamp.created_on}"))
#    end
#    o
  end

  #---------------------
  # process_message_queue
  #---------------------
  def clear_response_acks(response, messages, state, context, options) do
    if ack = response[:ack] do
      Enum.map(ack,
        fn
          ({:ack, [for: ids]}) ->
          Enum.map(ids, fn(id) ->
            message = Enum.find_value(messages, fn(message) -> message.identifier == id && message || nil end)
            IO.inspect(message && {message.identifier, message.read_on}, label: "ACK")
            message && is_nil(message.read_on) && Noizu.Intellect.Account.Message.mark_read(message, state.worker.agent, context, options)
          end)
          (_) -> :nop
        end
      )
    end
  end


  def process_response_memories(response, _messages, state, _context, _options) do
    # record responses
    if reply = response[:memories] do
      Enum.map(reply,
        fn({:memories, contents}) ->
          # Has valid response block

            with {:ok, sref} <- Noizu.EntityReference.Protocol.sref(state.worker.channel) do
              # need a from message method.
              push = %Noizu.IntellectWeb.Message{
                type: :system_message,
                timestamp: DateTime.utc_now(),
                user_name: state.worker.agent.slug,
                profile_image: state.worker.agent.profile_image,
                mood: :nothing,
                body: "[AGENT MEMORIES] #{contents}"
              }
              Noizu.Intellect.LiveEventModule.publish(event(subject: "chat", instance: sref, event: "sent", payload: push, options: [scroll: true]))
            end
        end
      )
    end
  end

  def process_response_replies(response, messages, meta_list, state, context, options) do
    # record responses
    if reply = response[:reply] do
      Enum.map(reply,
        fn({:reply, attr}) ->
          # Has valid response block
          if response = attr[:response] do
            Logger.error("[RESPONSE:#{state.worker.agent.slug}] #{ response} \n----------------- #{inspect reply}")
            message = %Noizu.Intellect.Account.Message{
              sender: state.worker.agent,
              channel: state.worker.channel,
              depth: 0,
              user_mood: attr[:mood] && String.trim(attr[:mood]),
              event: :message,
              contents: %{body: response},
              meta: Ymlr.document!(meta_list),
              time_stamp: Noizu.Entity.TimeStamp.now()
            }
            {:ok, message} = Noizu.Intellect.Entity.Repo.create(message, context)
            # Block so we don't reload and resend.
            Noizu.Intellect.Account.Message.mark_read(message, state.worker.agent, context, options)

            Enum.map(attr[:ids], fn(id) ->
              is_integer(id) && Noizu.Intellect.Schema.Account.Message.RespondingTo.record({:responding_to, {id, 100, {nil, nil}, "agent reply"}}, message, context, options)
            end)

            if read = attr[:ids] do
              read_messages = Enum.filter(messages, & &1.identifier in read && is_nil(&1.read_on))
              Enum.map(read_messages, & Noizu.Intellect.Account.Message.mark_read(&1, state.worker.agent, context, options))
            end

            with {:ok, sref} <- Noizu.EntityReference.Protocol.sref(state.worker.channel) do
              # need a from message method.
              push = %Noizu.IntellectWeb.Message{
                identifier: message.identifier,
                type: :message,
                timestamp: message.time_stamp.created_on,
                user_name: state.worker.agent.slug,
                profile_image: state.worker.agent.profile_image,
                mood: attr[:mood],
                meta: Ymlr.document!(meta_list),
                body: message.contents.body
              }
              Noizu.Intellect.LiveEventModule.publish(event(subject: "chat", instance: sref, event: "sent", payload: push, options: [scroll: true]))
            end

            at = (attr[:at] || "")
                 |> String.split(",")
                 |> Enum.map(&String.trim/1)
            options = put_in(options || [], [:at], at)
            Noizu.Intellect.Account.Channel.deliver(state.worker.channel, message, context, options)
#          else
#            # clear ids regardless to avoid continuous loop.
#            if ids = attr[:ids] do
#              Enum.map(ids, fn(id) ->
#                message = Enum.find_value(messages, fn(message) -> message.identifier == id && message || nil end)
#                message && is_nil(message.read_on) && Noizu.Intellect.Account.Message.mark_read(message, state.worker.agent, context, options)
#              end)
#            end
          end
        end
      )
    end
  end

  def process_message_queue(state, context, options) do
    cond do
      state.worker.channel.type == :session -> session_process_message_queue(state, context, options)
      state.worker.channel.type == :chat -> session_process_message_queue(state, context, options)
      :else -> session_process_message_queue(state,context,options)
    end
  end




  def monitor_agent_response(state, message, context, options) do
    # TODO pass response through monitor and revisor to strip back and forth agent chatter.
    body = get_in(message, [Access.key(:contents), Access.key(:body)])
    body = String.replace(body, "Let's continue brainstorming together!", "")
    reply = put_in(message, [Access.key(:contents), Access.key(:body)], body)
    {:ok, reply}
  end


  def session_process_message_queue(state, context, options) do
    # TODO - logic depends on channel type, if session we get all unread messages and filter others by nearby object
    # weaviate search. Prompt returns a list of messages not a composite message and expects a single return.

    with true <- unread_messages?(state, context, options),
         {:ok, messages} <- message_history(state, context, options),
         messages <- messages |> Enum.reverse(),
         true <- (length(messages) > 0) || {:error, :no_messages},
         {:ok, prompt_context} <- Noizu.Intellect.Prompt.DynamicContext.prepare_custom_prompt_context(
           state.worker.agent,
           state.worker.channel,
           messages,
           Noizu.Intellect.Prompt.ContextWrapper.session_plan_prompt(state.worker.objectives),
           context,
           options),
         {:ok, api_response} <- Noizu.Intellect.Prompt.DynamicContext.execute(prompt_context, context, options)
      do

      try do
        with raw1 =%{choices: [%{message: %{content: reply}}|_]} <- api_response[:reply],
             :ok <- IO.puts("\n\n**************** PLAN #{state.worker.agent.slug} *******************\n#{reply}\n**************** PLAN *******************\n\n"),
             options_b <- put_in(options || [], [:pending_message], reply),
             {:ok, prompt_context} <- Noizu.Intellect.Prompt.DynamicContext.prepare_custom_prompt_context(
               state.worker.agent,
               state.worker.channel,
               messages,
               Noizu.Intellect.Prompt.ContextWrapper.session_reply_prompt(state.worker.objectives),
               context,
               options_b),
             {:ok, api_response} <- Noizu.Intellect.Prompt.DynamicContext.execute(prompt_context, context, options_b),
             raw2 = %{choices: [%{message: %{content: reply2}}|_]} <- api_response[:reply],
             :ok <- IO.puts("\n\n**************** REPLY #{state.worker.agent.slug} *******************\n#{reply2}\n**************** REPLY *******************\n\n"),
             # TODO after sending messages perform reflect prompt
             options_c <- put_in(options || [], [:previous_message], reply <> "\n" <> reply2),
             {:ok, prompt_context} <- Noizu.Intellect.Prompt.DynamicContext.prepare_custom_prompt_context(
               state.worker.agent,
               state.worker.channel,
               messages,
               Noizu.Intellect.Prompt.ContextWrapper.session_reflect_prompt(state.worker.objectives),
               context,
               options_c),
             {:ok, api_response} <- Noizu.Intellect.Prompt.DynamicContext.execute(prompt_context, context, options_c),
             raw3 = %{choices: [%{message: %{content: reply3}}|_]} <- api_response[:reply],
             :ok <- IO.puts("\n\n**************** REFLECT #{state.worker.agent.slug} *******************\n#{reply3}\n**************** REFLECT *******************\n\n"),
             api_response <- put_in(api_response, [:reply], [raw1,raw2,raw3]),
             {:ok, response} <- Noizu.Intellect.HtmlModule.extract_session_response_details(:v2, reply <> "\n" <> reply2 <> "\n" <> reply3)
          do

          Logger.warn("[agent-reply:#{state.worker.agent.slug}] -------------------------------\n" <> reply <> "\n" <> reply2 <> "\n" <> reply3 <> "\n------------------------------------\n\n")
          format_response = Enum.map([:reply, :function_call, :ack, :follow_up, :memory, :intent, :objective, :error], fn(s) ->
            r = if response[s] do
              Enum.map(response[s] || [], fn
                ({^s, x}) -> x
                (_) -> nil
              end) |> Enum.reject(&is_nil/1)
            end
            {s, r}
          end) |> Map.new()
          meta_list = %{"settings" => api_response[:settings], "messages" => api_response[:messages], "raw_reply" => api_response[:reply],  "response" => format_response}

          Enum.map(response[:follow_up] || [],
            fn
              ({:follow_up, details}) ->
                # this should be delayed until after after field - temp hack
                time_stamp = Noizu.Entity.TimeStamp.now(details[:remind_after]) || Noizu.Entity.TimeStamp.now()
                message = %Noizu.Intellect.Account.Message{
                  sender: state.worker.agent,
                  channel: state.worker.channel,
                  depth: 0,
                  event: :follow_up,
                  # Temp hack for condition field - follow ups should be it's own table and injected into request
                  contents: %{title: details[:condition] || "NO CONDITIONS", body: details[:instructions]},
                  meta: Ymlr.document!(meta_list) |> String.trim(),
                  time_stamp: time_stamp
                }
                {:ok, message} = Noizu.Intellect.Entity.Repo.create(message, context)
                Noizu.Intellect.Schema.Account.Message.Audience.record({:audience, {state.worker.agent.identifier, 100, "self-instruct"}}, message, context, options)
              (_) -> nil
            end
          )

          Enum.map(response[:reply] || [],
            fn
              ({:reply, reply_response}) ->
                message = %Noizu.Intellect.Account.Message{
                  sender: state.worker.agent,
                  channel: state.worker.channel,
                  depth: 0,
                  user_mood: reply_response[:mood],
                  event: :message,
                  contents: %{title: "response", body: reply_response[:response]},
                  meta: Ymlr.document!(meta_list) |> String.trim(),
                  time_stamp: Noizu.Entity.TimeStamp.now()
                }

                {:ok, message} = monitor_agent_response(state, message, context, options)

                {:ok, message} = Noizu.Intellect.Entity.Repo.create(message, context)
                # Block so we don't reload and resend.
                Noizu.Intellect.Account.Message.mark_read(message, state.worker.agent, context, options)
                Noizu.Intellect.Schema.Account.Message.Audience.record({:audience, {state.worker.agent.identifier, 10, "sender"}}, message, context, options)


                # mark any unread as read.
                Enum.map(messages, fn(message) ->
                  if is_nil(message.read_on) do
                    Noizu.Intellect.Account.Message.mark_read(message, state.worker.agent, context, options)
                  end
                end)

                with {:ok, sref} <- Noizu.EntityReference.Protocol.sref(state.worker.channel) do
                  # need a from message method.
                  m = case Ymlr.document!(meta_list) |> String.trim() |> YamlElixir.read_from_string() do
                    {:ok, m} -> m
                    _ -> "[NONE]"
                  end
                  push = %Noizu.IntellectWeb.Message{
                    identifier: message.identifier,
                    type: :message,
                    timestamp: message.time_stamp.created_on,
                    user_name: state.worker.agent.slug,
                    profile_image: state.worker.agent.profile_image,
                    mood: reply_response[:mood] && String.trim(reply_response[:mood]),
                    meta: m,
                    body: message.contents.body
                  }
                  Noizu.Intellect.LiveEventModule.publish(event(subject: "chat", instance: sref, event: "sent", payload: push, options: [scroll: true]))
                end

                spawn fn ->
                  options = put_in(options || [], [:at], reply_response[:at])
                  Noizu.Intellect.Account.Channel.deliver(state.worker.channel, message, context, options)
                end
              (other) ->
                Logger.warn("Invalid response: #{inspect other}")
            end
          )

          # Temp extract objectives store, store locally for now.
          #IO.inspect(response[:objective], label: "RESPONSE OBJECTIVE")
          with [{:objective, obj}|_] <- response[:objective] do
            state = if index = Enum.find_index(state.worker.objectives, & &1[:name] == obj[:name]) do
                      put_in(state, [Access.key(:worker),Access.key(:objectives), Access.at(index)], obj)
                      |> tap(fn(_) -> obj[:name] |> IO.inspect(label: "[#{state.worker.agent.slug}: Update Objective: #{index}]") end)
                    else
                      update_in(state, [Access.key(:worker),Access.key(:objectives)], & [obj|&1])
                      |> tap(fn(_) -> obj[:name] |> IO.inspect(label: "[#{state.worker.agent.slug}: Add Objective]") end)
                    end
                    |> shallow_persist(context, options)

            clear_response_acks(response, messages, state, context, options)

            {:ok, state}
          else
            _ -> {:ok, state}
          end


        else
          _ -> {:ok, state}
        end


      rescue error ->
        Logger.error(Exception.format(:error, error, __STACKTRACE__))
        {:ok, state}
      catch error ->
        Logger.error(Exception.format(:error, error, __STACKTRACE__))
        {:ok, state}
      end
    else
      _ -> {:ok, state}
    end
  end

  #---------------------
  #
  #---------------------
  def heart_beat(state, context, options) do
    IO.puts "Heart Beat #{inspect state.identifier}"
    state = queue_heart_beat(state, context, options)
    with {:ok, state} <- process_message_queue(state, context, options) do
      {:noreply, state}
    else
      _ -> {:noreply, state}
    end
  end


  defimpl Noizu.Entity.Protocol do
    def layer_identifier(entity, _layer) do
      {:ok, entity.identifier}
    end
  end

  defmodule Repo do
    use Noizu.Repo
    def_repo()
  end
end
