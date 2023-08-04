#-------------------------------------------------------------------------------
# Author: Keith Brings
# Copyright (C) 2023 Noizu Labs, Inc. All rights reserved.
#-------------------------------------------------------------------------------

defmodule Noizu.Intellect.Account.Channel do
  use Noizu.Entities
  use Noizu.Core
  alias Noizu.Intellect.Entity.Repo
  alias Noizu.Entity.TimeStamp

  require Noizu.Intellect.LiveEventModule
  import Noizu.Intellect.LiveEventModule
  @vsn 1.0
  @sref "account-channel"
  @persistence ecto_store(Noizu.Intellect.Schema.Account.Channel, Noizu.Intellect.Repo)
  def_entity do
    identifier :integer
    field :slug
    field :account, nil, Noizu.Entity.Reference
    field :details, nil, Noizu.Entity.VersionedString
    field :time_stamp, nil, Noizu.Entity.TimeStamp
  end

  def summarize_message?(channel, message, prompt_context, context, options) do
    {:ok, message.token_size > 1024}
  end
  def summarize_message(channel, message, prompt_context, context, options) do
    with {:ok, prompt_context} <- Noizu.Intellect.Prompt.DynamicContext.prepare_meta_prompt_context(channel, [message], Noizu.Intellect.Prompt.ContextWrapper.summarize_message_prompt(), context, put_in(options || [], [:nlp], :disabled)),
         {:ok, request} <- Noizu.Intellect.Prompt.DynamicContext.for_openai(prompt_context, context, options),
         {:ok, request_settings} <- Noizu.Intellect.Prompt.RequestWrapper.settings(request, context, options),
         {:ok, request_messages} <- Noizu.Intellect.Prompt.RequestWrapper.messages(request, context, options),
         {:ok, response} <- Noizu.OpenAI.Api.Chat.chat(request_messages, request_settings) |> IO.inspect(label: "Summarize Response"),
         %{choices: [%{message: %{content: reply}}|_]} <- response
      do
      Logger.warn("----------------------------\n\n\n[SUMMARY]\n #{reply}")
      {:ok, put_in(message, [Access.key(:contents), Access.key(:body)], reply)}
      else
      error -> error
    end

  end


  def agent_slugs(prompt_context, context, options \\ nil) do
    slugs = Enum.map(prompt_context.channel_members || [], fn(member) ->
      case member do
        %{slug: slug} -> {member.identifier, Regex.compile!("(@#{slug} |@#{slug}$)", "i")}
        %{user: %{slug: slug}} -> {member.identifier, Regex.compile!("(@#{slug} |@#{slug}$)", "i")}
      end
    end) |> Map.new()
    {:ok, slugs}
  end

  def broadcast(message, prompt_context, context, options) do
    with {:ok, agent_slugs} <- agent_slugs(prompt_context, context, options) do
      v = String.contains?(String.downcase(message.contents.body || ""), "@everyone") || String.contains?(String.downcase(message.contents.body || ""), "@channel")
      {:ok, v}
    end
  end

  def extract_message_delivery(response) do
    with %{choices: [%{message: %{content: reply}}|_]} <- response do
      extract = Noizu.Intellect.HtmlModule.extract_message_delivery_details(reply)
      {:ok, extract}
    else
      _ -> {:invalid_response, response}
    end
  end


  def deliver(this, message, context, options \\ nil) do
    # Retrieve related message history for this message (this will eventually be based on who is sending and previous weightings for now we simply pull recent history)

    IO.inspect(message, label: "CURRENT_MESSAGE")

    with {:ok, messages} <- Noizu.Intellect.Account.Channel.Repo.recent(this, context, put_in(options || [], [:limit], 30)),
         messages <- Enum.reverse(messages),
         {:ok, prompt_context} <- Noizu.Intellect.Prompt.DynamicContext.prepare_meta_prompt_context(this, messages, Noizu.Intellect.Prompt.ContextWrapper.relevancy_prompt(message), context, options),
         {:ok, request} <- Noizu.Intellect.Prompt.DynamicContext.for_openai(prompt_context, context, options),
         {:ok, request_settings} <- Noizu.Intellect.Prompt.RequestWrapper.settings(request, context, options),
         {:ok, request_messages} <- Noizu.Intellect.Prompt.RequestWrapper.messages(request, context, options),
         {:ok, broadcast} <- broadcast(message, prompt_context, context, options),
         {:ok, summarized_message?} <- summarize_message?(this, message, prompt_context, context, options),
         {:ok, summarized_message} <- summarized_message? && summarize_message(this, message, prompt_context, context, options) || {:ok, message},
         {:ok, prompt} <- Noizu.Intellect.Prompt.DynamicContext.Protocol.prompt(summarized_message, prompt_context, context, options),
         :ok <- Logger.info(request_messages |> Enum.at(0) |> Map.get(:content), limit: :infinity),
         {:ok, response} <- Noizu.OpenAI.Api.Chat.chat(request_messages ++ [%{role: :user, content: prompt}], request_settings) |> IO.inspect,
         {:ok, extracted_details} <- extract_message_delivery(response) |> IO.inspect
      do

        details = Enum.group_by(extracted_details, &(elem(&1, 0)))
        if responding_to = details[:responding_to] do
          Enum.map(responding_to,
            fn(entry) -> Noizu.Intellect.Schema.Account.Message.RespondingTo.record(entry, message, context, options) end
          )
        end
        if audience = details[:audience] do
          Enum.map(audience,
            fn(entry) -> Noizu.Intellect.Schema.Account.Message.Audience.record(entry, message, context, options) end
          )
        end
        if summary = details[:summary] do
          Enum.map(summary,
            fn(entry) -> Noizu.Intellect.Account.Message.add_summary(entry, message, context, options) end
          )
        end

        with {:ok, prompt} <- Noizu.Intellect.Prompt.DynamicContext.Protocol.prompt(summarized_message, prompt_context, context, options),
             {:ok, response} <- Noizu.OpenAI.Api.Chat.chat(request_messages ++ [%{role: :user, content: prompt}], request_settings) do

          # response could be a function call or a response or a mix, need to handle all.
          with %{choices: [%{message: %{content: reply}}|_]} <- response,
               :ok <- Logger.warning("[DELIVER REPLY] #{reply}"),
               {:ok, prepped} <- Noizu.Intellect.HtmlModule.extract_message_delivery_details(reply)
            do

              IO.inspect(prepped)

              # Pending Update

#            # before setting relevancy do book keeping.
#            Enum.map(prepped, fn
#              ({:summary, summary}) ->
#                %{message|
#                  brief: %{title: "Message Summary", body: summary}
#                }
#                |> IO.inspect(label: "SET BRIEF")
#                |> Noizu.Intellect.Entity.Repo.update(context)
#
#                with {:ok, sref} <- Noizu.EntityReference.Protocol.sref(message.channel) do
#                  temp = %Noizu.IntellectWeb.Message{
#                    type: :system_message,
#                    timestamp: DateTime.utc_now(),
#                    user_name: "[System:Summary]",
#                    profile_image: nil,
#                    mood: :nothing,
#                    body: "#{message.identifier} <> #{summary}"
#                  }
#                  Noizu.Intellect.LiveEventModule.publish(event(subject: "chat", instance: sref, event: "sent", payload: temp, options: [scroll: true]))
#                end
#
#              ({:intent, response}) ->
#                prepped_entries = Enum.group_by(prepped, (&(elem(&1, 0))))
#                header = Enum.map(prepped_entries[:relevancy] || [], fn({_, settings}) -> " - #{settings[:member]}@#{settings[:weight]} - #{settings[:contents] || ""}</li>"  end) |> Enum.join("\n")
#                header = "#Relevancy\n\n#{header}\n\n#Tabular\n\n"
#                with {:ok, sref} <- Noizu.EntityReference.Protocol.sref(message.channel) do
#                  temp = %Noizu.IntellectWeb.Message{
#                    type: :system_message,
#                    timestamp: DateTime.utc_now(),
#                    user_name: "[System:Relevancy]",
#                    profile_image: nil,
#                    mood: :nothing,
#                    body: header <> response
#                  }
#
#                  Noizu.Intellect.LiveEventModule.publish(event(subject: "chat", instance: sref, event: "sent", payload: temp, options: [scroll: true]))
#                end
#
#              (_) -> nil
#            end)
#
#            Enum.map(prepped, fn
#              ({:relevancy, settings}) ->
#                recipient_id = settings[:member]
#                weight = settings[:weight]
#                weight = if (weight < 0.7) do
#                  slug = agent_slugs[recipient_id]
#                  if broadcast || (slug && String.match?(prompt, slug)) do
#                    Logger.error("[Deliver] Agent set incorrect weight #{weight} for #{recipient_id}")
#                    0.7
#                  else
#                    weight
#                  end
#                else
#                  weight
#                end
#                # Scan message, if it contains @recipient then min bar weight to 0.7
#                weight = weight && trunc(Float.round(weight, 2) * 100)
#                comment = settings[:contents]
#                now = DateTime.utc_now()
#                %Noizu.Intellect.Schema.Account.Message.Relevancy{
#                  message: message.identifier,
#                  recipient: recipient_id,
#                  relevance: weight,
#                  responding_to: settings[:message],
#                  comment: comment,
#                  created_on: now,
#                  modified_on: now,
#                } |> Noizu.Intellect.Repo.insert(on_conflict: :replace_all, conflict_target: [:message, :recipient])
#              (_) -> nil
#            end)

            {:ok, message}
          end

      end



    end


    #    %Noizu.Intellect.Account.Message{
    #      sender: socket.assigns[:user],
    #      channel: socket.assigns[:channel],
    #      depth: 0,
    #      user_mood: nil,
    #      event: :message,
    #      contents: form["comment"],
    #      time_stamp: Noizu.Entity.TimeStamp.now()
    #    }
    #

  end

  defimpl Noizu.Entity.Protocol do
    def layer_identifier(entity, _layer) do
      {:ok, entity.identifier}
    end
  end

  defmodule Repo do
    use Noizu.Repo
    alias Noizu.Intellect.User.Credential
    alias Noizu.Intellect.User.Credential.LoginPass
    alias Noizu.Intellect.Entity.Repo, as: EntityRepo
    alias Noizu.EntityReference.Protocol, as: ERP
    def_repo()
    import Ecto.Query

    def members(channel, context, options \\ nil) do
      {:ok, id} = Noizu.EntityReference.Protocol.id(channel)
      q = from cm in Noizu.Intellect.Schema.Account.Channel.Member,
               where: cm.channel == ^id,
               select: cm
      members = Noizu.Intellect.Repo.all(q)
                |> Enum.map(&(&1.member))
      {:ok, members}
    end

    def relevant_or_recent(recipient, channel, context, options \\ nil) do
      with {:ok, channel_id} <- Noizu.EntityReference.Protocol.id(channel),
           {:ok, recipient_id} <- Noizu.EntityReference.Protocol.id(recipient) do
        limit = options[:limit] || 20
        relevancy = options[:relevancy] || 50
        recent_cut_off = DateTime.utc_now() |> Timex.shift(minutes: -45)

        responding_to = from p in Noizu.Intellect.Schema.Account.Message.RespondingTo,
                             group_by: p.message,
                             select: {p.message, fragment("array_agg(row(?,?,?))", p.responding_to, p.confidence, p.comment)}
        audience = from p in Noizu.Intellect.Schema.Account.Message.Audience,
                        group_by: p.message,
                        select: {p.message, fragment("array_agg(row(?,?,?))", p.recipient, p.confidence, p.comment)}


        q = from msg in Noizu.Intellect.Schema.Account.Message,
                 join: aud in Noizu.Intellect.Schema.Account.Message.Audience,
                 on: aud.message == msg.identifier,
                 left_join: contents in Noizu.Intellect.Schema.VersionedString,
                 on: contents.identifier == msg.contents,
                 left_join: brief in Noizu.Intellect.Schema.VersionedString,
                 on: brief.identifier == msg.brief,
                 left_join: meta in Noizu.Intellect.Schema.VersionedString,
                 on: meta.identifier == msg.meta,
                 left_join: read_status in Noizu.Intellect.Schema.Account.Message.Read,
                 on: read_status.message == msg.identifier and read_status.recipient == aud.recipient,
                 left_join: resp_list in subquery(responding_to),
                 on: msg.identifier == resp_list.message,
                 left_join: aud_list in subquery(audience),
                 on: msg.identifier == aud_list.message,
                 where: msg.channel == ^channel_id,
                 where: aud.recipient == ^recipient_id,
                 where: (is_nil(read_status) or (aud.confidence >= ^relevancy or aud.created_on >= ^recent_cut_off)),
                 order_by: [desc: msg.created_on],
                 limit: ^limit,
                 select: %{msg|
                   __loader__: %{
                     contents: contents,
                     brief: brief,
                     meta: meta,
                     audience_list: aud_list,
                     responding_to_list: resp_list,
                     audience: aud,
                     read_status: read_status
                   }
                 }
        messages = Enum.map(
                     Noizu.Intellect.Repo.all(q) |> IO.inspect("NEW MESSAGE LOADER"),
                     & Noizu.Intellect.Account.Message.entity(&1, context)
                   ) |> Enum.map(
                          fn
                            ({:ok, v}) -> v
                            (_) -> nil
                          end)
                   |> Enum.reject(&is_nil/1)
        {:ok, messages}
      end
    end

    def recent(channel, context, options \\ nil) do
      {:ok, id} = Noizu.EntityReference.Protocol.id(channel)
      limit = options[:limit] || 100
      q = from m in Noizu.Intellect.Schema.Account.Message,
               where: m.channel == ^id,
               order_by: [desc: m.created_on],
               limit: ^limit,
               select: m
      messages = Enum.map(
                   Noizu.Intellect.Repo.all(q) ,
                   fn(msg) ->
                     # Temp - load from ecto needed.
                     Noizu.Intellect.Account.Message.entity(msg.identifier, context)
                   end
                 ) |> Enum.map(
                        fn
                          ({:ok, v}) -> v
                          (_) -> nil
                        end)
                 |> Enum.filter(&(&1))
      {:ok, messages}
    end

  end
end


defimpl Noizu.Intellect.Prompt.DynamicContext.Protocol, for: [Noizu.Intellect.Account.Channel] do
  def prompt(subject, %{format: :markdown} = prompt_context, context, options) do
    p = if prompt_context.channel_members do
      prompt_context = put_in(prompt_context, [Access.key(:format)], :raw)
      members = Enum.map(prompt_context.channel_members, fn(member) ->
        with {:ok, member} <- Noizu.Intellect.Prompt.DynamicContext.Protocol.prompt(member, prompt_context, context, options) do
          member
        else
          _ -> nil
        end
      end) |> Enum.reject(&is_nil/1)
      %{identifier: subject.identifier,
        name: subject.slug,
        description: subject.details && subject.details.body || "[None]",
        channel_members: members
      }
    else
      %{identifier: subject.identifier,
        name: subject.slug,
        description: subject.details && subject.details.body || "[None]"}
    end

    prompt = """
    # Channel
    You are currently in the following channel
    #{Poison.encode!(p, pretty: true)}

    """
    {:ok, prompt}

  end
  def minder(subject, prompt_context, context, options) do
    {:ok, nil}
  end
end
