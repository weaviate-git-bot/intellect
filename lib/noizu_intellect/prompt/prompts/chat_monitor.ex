defmodule Noizu.Intellect.Prompts.ChatMonitor do
  @behaviour Noizu.Intellect.Prompt.ContextWrapper
  require Logger
  @impl true

  def prompt(version, options \\ nil)
  def prompt(:v2, options) do
    current_message = options[:current_message]

    %Noizu.Intellect.Prompt.ContextWrapper{
      assigns: fn(prompt_context, context, options) ->
                 graph = with {:ok, graph} <- Noizu.Intellect.Account.Message.Graph.to_graph(prompt_context.message_history, context, options) do
                   graph
                 else
                   _ -> false
                 end

                 assigns = Map.merge(prompt_context.assigns, %{message_graph: true, nlp: false, members: Map.merge(prompt_context.assigns[:members] || %{}, %{verbose: :detailed})})
                           |> put_in([:message_graph], graph)
                           |> put_in([:current_message], current_message)
                  {:ok, assigns}
               end,
      prompt: [user:
        """
        <%= if @message_graph do %>
        # Instructions
        As a chat thread and content analysis engine, given the following channel, channel members and graph encoded chat conversation
        Analyze the conversation graph and identify the relationships between messages, including reply-to and target audience connections.
        Then as new messages are provided based on the ongoing message threads and the content of new messages determine the likely audience and
        messages if any the new message was in response to or a continuation of and why.

        <%= case Noizu.Intellect.Prompt.DynamicContext.Protocol.prompt(@prompt_context.channel, @prompt_context, @context, @options) do %>
        <% {:ok, prompt} when is_bitstring(prompt) -> %><%= prompt %>
        <% _ -> %><%= "" %>
        <% end %>

        # Conversation Graph
        <%= case Noizu.Intellect.Prompt.DynamicContext.Protocol.prompt(@message_graph, @prompt_context, @context, @options) do %>
        <% {:ok, prompt} when is_bitstring(prompt) -> %><%= prompt %>
        <% _ -> %><%= "" %>
        <% end %>

        <% else %>

        # Instructions

        ## Review
        Review the following channel description, members and message to determine the most likely audience based on their background, message contents and direct channel member mentions.

        <%= case Noizu.Intellect.Prompt.DynamicContext.Protocol.prompt(@prompt_context.channel, @prompt_context, @context, @options) do %>
        <% {:ok, prompt} when is_bitstring(prompt) -> %><%= prompt || "" %>
        <% _ -> %><%= "" %>
        <% end %>
        <% end %>

        ### Note
        - Messages that include @[member.slug| case insensitive] should list that user as a high confidence (90) recipients.
        - Messages including @everyone (case insensitive) or @channel (case insensitive) should be list all members as med-high confidence (70) recipients.
        - Messages that mention (with out a slug) someone by name in passing with out directly querying them should have a med-low confidence level (50)
        - Messages addressed to someone by name should have a high-med-high confidence (80) if sent by a human operator or (50) if sent by a virtual agent.

        # New Message
        Determine which messages the new message is most likely responding to, and identify the most appropriate audience members for the message.

        <%= case Noizu.Intellect.Prompt.DynamicContext.Protocol.prompt(@current_message, @prompt_context, @context, @options) do %>
        <% {:ok, prompt} when is_bitstring(prompt) -> %><%= prompt || "" %>
        <% _ -> %><%= "" %>
        <% end %>

        # Output Format
        Provide your final response in the following XML structure:

        <message-analysis>
        [...|
        under the heading Chat History list each previous message by id, the messages it is in response to, its recipients and a note on if and if so how it relates to the new messages.
        Include an entry for <%= "#\{inspect @prompt_context.message_history |> Enum.map(& &1.identifier) \}" %>
        Use markdown not xml/html as in the below example
        # Chat History
        - msg {id}, sender {sender slug}, responding_to: [{messages in response to}], recipients: [{member slugs of recipients}], relates?: {"no" if message contents has nothing in common with new message or a comment on how this message relates to the new message. Two messages about the same subject even if different are related.}
        [...]
        ]
        </message-analysis>

        <message-details>
        <replying-to>
          <message id="<numeric id of message new message is likely responding to>" confidence="<numeric confidence that this is the chain/message the new message is responding to>">[...|comment on reasoning behind association]</message>
          [...|additional entries]
        </replying-to>
        <audience>
          <member id="numeric id of recipient" confidence="confidence interval message is targeted towards specific recipient">[...|note to recipient on why message may be relevant to them]</member>
          [...|additional entries]
        </audience>
        <summary>Brief Concise summary of message, Place ellipses/omissions in long code blocks, Summarization should be at most 1/3rd the length of message being summarized<features><feature>Tag/Feature relating to message for use in VDB future search/lookup</feature>[...|additional entries]</features></summary>
        </message-details>
        """,
      ],
      minder: [system: ""],
    }
  end


  def prompt(:v1, _) do
    %Noizu.Intellect.Prompt.ContextWrapper{
      prompt: [system:
        """


            <%= case Noizu.Intellect.Prompt.DynamicContext.Protocol.prompt(@prompt_context.channel, @prompt_context, @context, @options) do %>
              <% {:ok, prompt} when is_bitstring(prompt) -> %><%= prompt || "" %>
              <% _ -> %><%= "" %>
            <% end %>

            ## Channel-Members
            <%= for member <- (@prompt_context.channel_members || []) do %>
            <%= case Noizu.Intellect.Prompt.DynamicContext.Protocol.prompt(member, @prompt_context, @context, @options) do %>
            <% {:ok, prompt} when is_bitstring(prompt) -> %>
            <%= String.trim_trailing(prompt) %>
            <% _ -> %><%= "" %>
            <% end %>
            <% end %>

            <%= if @prompt_context.message_history do %>
            ## Channel Message History
            ```yaml
            current_time: #{DateTime.utc_now()}
            messages:
            <%= for message <- @prompt_context.message_history do %>
            <%= case Noizu.Intellect.Prompt.DynamicContext.Protocol.prompt(message, @prompt_context, @context, @options) do %>
            <% {:ok, prompt} when is_bitstring(prompt)  -> %>
            <%= String.trim_trailing(prompt) %><% _ -> %><%= "" %>
            <% end  # end case %>
            <% end  # end for %>
            ```
            <% end  # end if %>
        """,
        system: """



        # Instruction Prompt
        For each new incoming message based on the message history previously listed prepare the following xml output format:

        ````format
        <nlp-intent>
        [...|
          Provide a 10 row markdown table including a header row containing:
          (message.id, message.sent-on, message.sender.slug, the most likely recipient(s) slugs, recipient weight(s), the message.id this is likely responding to, reason for designation)
          include one entry for each of the following messages: <%= Enum.slice(@prompt_context.message_history,-10..-1) |> Enum.reject(&is_nil/1) |> Enum.map(& &1.identifier) |> Enum.join(", ") %>
        ]
        </nlp-intent>

        <relevance>
        {for all channel members (simulated and real regardless of recipient weight) (
          Consider each channel member. `@channel` and `@everyone` are special directives; if found in a message, treat it as if it had included the channel member's slug.
          For each member, provide a relevancy score between 0.0 (not relevant) and 1.0 (direct message) and explain your reasoning.)
         }
          <relevancy for-user="{member.id - The channel members id not their slug}" for-message="{message.id - id of message most likely to be in response or empty if unknown.}" for-slug="{member.slug}" value="{value in [0.0,1.0] where 0.0 indicates message has nothing to do with channel member and 1.0 indicates this is a direct message to channel member.}">
          [...|Reasoning]
          </relevancy>
        {/for}
        </relevance>

        <summary>
        [...|
        1-2 paragraph summary of the contents and purpose of the message, (the contents of the message not the nature (direct reply, continued chat, etc.))
        for short messages like hello, how can I help you etc. a single word or sentence
        "greeting", "introduction", etc. is appropriate. Summary should be shorter than the actual message. If message is an ongoing chat, reply etc. that can be mentioned in the <type> section.
        if message is more than a few lines or includes large code snippets brief should be at least 2 paragraphs of 4-5 5-9 word sentences.
        ]
        ```type
        [...| note if this is a new thread/context, continued chat, response, question, introduction,request, etc. Include details about purpose/ongoing conversation etc. here not in above.]
        ```
        </summary>
        ````

        # Steps
        1. Identify different types of conversation threads commonly found in messaging systems (e.g., direct messages, group discussions, announcements).
        2. Provide high-level examples for each type of thread, detailing how the messages would be weighted based on their contents and history.
        3. Consider these high level reasoning examples, ensuring they align with the structure previously defined.

        <reasoning-examples>
          {Direct Message|
            - Type: Direct communication between two members.
            - Weight: 1.0 (as this is a direct message to a specific member).
          }
          {Group Discussion|
            - Type: Conversation involving multiple members within a specific group.
            - Weight: Varies (e.g., 0.5 if the message is relevant to half the members, 0.2 if only relevant to a smaller subset,0.7 or higher if ongoing conversation and relevant to interests or background).
          }
          {Announcement `@everyone`|
            - Type: Broadcast message to all channel members.
            - Weight: 1.0 for all members, as it includes everyone in the channel.
          }
          {Reply to a Specific Message|
            - Type: A reply to a specific message within a conversation thread.
            - Weight: Based on the relevance to the recipient(s) of the original message, may vary (e.g., 0.7 if it's a continuation of a specific conversation).
          }
        </reasoning-examples>


        """],

      minder: [system: ""],

    }
  end

  def prompt(:v0, _) do
    %Noizu.Intellect.Prompt.ContextWrapper{
      prompt: [system: """
      🎯 Prompt Attention Rule
      When parsing input, please pay particular attention to the section of text
      that immediately follows the 🎯 (Direct Hit) emoji.
      This emoji is being used as a marker to highlight areas of heightened
      importance or relevance. The text following the 🎯 emoji should be considered
      with particular care and prioritized in the formation of your response.
      Please interpret and execute on any instructions or requests in the section
      following this emoji with increased focus and attention to detail.


      <%= case Noizu.Intellect.Prompt.DynamicContext.Protocol.prompt(@prompt_context.channel, @prompt_context, @context, @options) do %>
        <% {:ok, prompt} when is_bitstring(prompt) -> %><%= prompt || "" %>
        <% _ -> %><%= "" %>
      <% end %>

      ## Channel-Members
      <%= for member <- (@prompt_context.channel_members || []) do %>
      <%= case Noizu.Intellect.Prompt.DynamicContext.Protocol.prompt(member, @prompt_context, @context, @options) do %>
      <% {:ok, prompt} when is_bitstring(prompt) -> %>
      <%= String.trim_trailing(prompt) %>
      <% _ -> %><%= "" %>
      <% end %>
      <% end %>

      <%= if @prompt_context.message_history do %>
      ## Channel Message History
      ```yaml
      current_time: #{DateTime.utc_now()}
      messages:
      <%= for message <- @prompt_context.message_history do %>
      <%= case Noizu.Intellect.Prompt.DynamicContext.Protocol.prompt(message, @prompt_context, @context, @options) do %>
      <% {:ok, prompt} when is_bitstring(prompt)  -> %>
      <%= String.trim_trailing(prompt) %><% _ -> %><%= "" %>
      <% end  # end case %>
      <% end  # end for %>
      ```
      <% end  # end if %>

      # System Prompt

      ## 🎯 Goal

      Determine relevance scores for new message inputs, ranging from 0.0 (no relevance) to 1.0 (direct message). These scores indicate the intended recipient among channel members, based on the content of the message and the sender's previous interactions.

      ## 🎯 Considerations

      1. If the sender previously addressed a specific member and the new message doesn't change the addressee (no "@" symbols or tonal shifts), consider it likely intended for the same recipient(s).
      2. If the sender's message aligns with a member's background, yet the intended recipient is unclear, assign a relevance score of 0.6.
      3. If the sender was previously chatting with an agent or group of agents assume they are still conversing with those recipients unless they've
         @at'd someone else with a change of topic. A message is still relavent to a recipient even if not mentioned by name if they had previously been chatting back and forth.

      ## Reminder

      Unless a message explicitly addresses someone else, assume the sender's dialogues are continuous. Check the `Message History` in reverse chronological order, considering timings, senders, and users' interactions to determine the intended recipient.

      ## Output Structure

      Structure your output in the XML-like format provided:

      ```xml
      <relevance>
      <relevancy
      for-user="{member.id}"
      for-message="{message.id | the message this is most likely responding to.}"
      for-slug="{member.slug}"
      value="{value in [0.0,1.0]}">

      {Explanation of the Relevancy Score}

      </relevancy>
      </relevance>
      ```


      """
      ],
     minder: """
      # Reminder: Conversation Flow

      🎯 Always assume that any new message from a sender is a continuation of their previous message, unless the content clearly indicates a response to a different prior message. Review the message history, considering messages sent by the sender, other users, and the time lapse between messages, until the most likely recipient of the sender's new message is identified.

      Note: The use of `@` followed by an agent's slug (case insensitive) implies the message is targeted at that agent and likely now longer directed to the previous sender messages' recipients. For example, `@stEvE` suggests the agent with the slug `steve` is a high priority recipient.

      # Direction: Message Relevance

      🎯 For subsequent messages, compare their content with the `Message History` in reverse chronological order. This will help determine the relevance of the new message based on its content and the channel's message history.
      and provide a message summary (taking into account past context) for use with vectorization and future recall.

      For instance, if a sender's new message continues their previous one and doesn't clearly suggest a new recipient or response to a preceding message, the relevance of the sender's previous message should apply.


      ```format
      <nlp-intent>
      {Provide a markdown table listing: message.id, message.sent-on, message.sender.slug, the most likely recipient(s) slugs, recipient weight(s), the message.id this is likely responding to, and reason for designation for the 10 most recent messages chronologically (not per conversation), sorted by message.sent-on. Only list 10 items no more no less (unless there are fewer than 10 items to include)}
      </nlp-intent>

      <relevance>
        {for each channel member|
          Consider each channel member. `@channel` and `@everyone` are special directives; if found in a message, treat it as if it had included the channel member's slug.
          For each member, provide a relevancy score between 0.0 (not relevant) and 1.0 (direct message) and explain your reasoning.}
        <relevancy for-user="{member.id}" for-message="{message.id | id of message most likely to be in response to given this weight.}" for-slug="{member.slug}" value="{value in [0.0,1.0] where 0.0 indicate message has nothing to do with channel member and 1.0 indicates this is a direct message to channel member.}">
        {Reasoning}
        </relevancy>
        {/for}
      </relevance>

      <summary>
      [...|
      1-2 paragraph summary describing the contents and purpose of the message, (the contents of the message not the nature (direct reply, continued chat, etc.))
      for short messages like hello, how can I help you etc. a single word or sentence
      "greeting", "introduction", etc. is appropriate. brief should be shorter than the actual message. If message is a ongoing chat, reply etc. that can be mentioned in the <type> section.
      if message is more than a few lines or includes large code snippets brief should be at least 2 paragraphs of 4-5 5-9 word sentences.
      ]
      ```type
      [...| note if this is a new thread/context, continued chat, response, question, introduction,request, etc. Include details about purpose/ongoing conversation etc. here not in above.]
      ```
      </summary>
      ```
      """
    }
  end


end
