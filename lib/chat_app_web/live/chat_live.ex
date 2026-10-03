defmodule ChatAppWeb.ChatLive do
  use ChatAppWeb, :live_view

  alias ChatApp.Accounts
  alias ChatApp.Messages
  alias ChatAppWeb.Presence

  @impl true
  def mount(%{"sender_id" => sender_id, "receiver_id" => receiver_id}, _session, socket) do
    hashed_topic = "chat:#{min(sender_id, receiver_id)}:#{max(sender_id, receiver_id)}"

    # Fetch once
    sender = Accounts.get_user!(sender_id)
    receiver = Accounts.get_user!(receiver_id)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(ChatApp.PubSub, hashed_topic)
      Presence.track(self(), hashed_topic, to_string(sender.id), %{username: sender.username})
    end

    # Convert the map into a true/false boolean
    presences = Presence.list(hashed_topic)
    receiver_online? = Map.has_key?(presences, to_string(receiver.id))

    socket =
      socket
      |> assign(:sender, sender)
      |> assign(:receiver, receiver)
      |> assign(:receiver_online, receiver_online?)
      |> stream(:messages, Messages.get_all_messages_between_users(sender_id, receiver_id))
      |> assign(:chat_topic, hashed_topic)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto mt-10 p-4 sm:p-6 bg-zinc-50 rounded-lg shadow-md text-black h-[80vh] flex flex-col">
      <!-- Header -->
      <div class="border-b border-zinc-200 pb-4 mb-4 flex justify-between items-center">
        <div>
          <h1 class="text-2xl font-bold text-zinc-800">Chat Room</h1>
          <p class="text-sm text-zinc-500 flex items-center gap-2 mt-1">
            You (<span class="font-bold"><%= @sender.username %></span>) are talking to
            <span class="font-bold text-zinc-800">{@receiver.username}</span>

            <%= if @receiver_online do %>
              <span
                class="inline-block w-2.5 h-2.5 bg-green-500 rounded-full shadow-sm"
                title="Online"
              >
              </span>
            <% else %>
              <span
                class="inline-block w-2.5 h-2.5 bg-zinc-300 rounded-full shadow-sm"
                title="Offline"
              >
              </span>
            <% end %>
          </p>
        </div>
        <!-- Link to go back to the entry form -->
        <.link navigate="/" class="text-sm text-brand hover:underline font-medium">Leave Chat</.link>
      </div>
      
    <!-- Message History (Phoenix Stream) -->
      <div id="chat-messages" phx-update="stream" class="flex-1 overflow-y-auto space-y-4 mb-4 p-2">
        <div :for={{dom_id, message} <- @streams.messages} id={dom_id} class="flex flex-col">
          <%= if message.sender_id == @sender.id do %>
            <!-- Sender's Message (Aligned Right) -->
            <div class="self-end max-w-[75%]">
              <div class="bg-zinc-800 text-white px-4 py-2 rounded-2xl rounded-tr-sm inline-block shadow-sm">
                {message.content}
              </div>
            </div>
          <% else %>
            <!-- Receiver's Message (Aligned Left) -->
            <div class="self-start max-w-[75%]">
              <span class="text-xs text-zinc-500 ml-1 mb-1 block">{@receiver.username}</span>
              <div class="bg-white text-zinc-800 border border-zinc-200 px-4 py-2 rounded-2xl rounded-tl-sm inline-block shadow-sm">
                {message.content}
              </div>
            </div>
          <% end %>
        </div>
      </div>
      
    <!-- Message Input Form -->
      <form phx-submit="send_message" class="mt-auto border-t border-zinc-200 pt-4">
        <div class="flex gap-2">
          <input
            type="text"
            name="new_message"
            id="new_message"
            placeholder="Type your message..."
            required
            autocomplete="off"
            class="flex-1 rounded-full border-zinc-300 shadow-sm focus:border-zinc-800 focus:ring-zinc-800"
          />
          <button
            type="submit"
            class="px-6 py-2 bg-zinc-900 text-white font-medium rounded-full hover:bg-zinc-700 focus:outline-none focus:ring-2 focus:ring-zinc-900 focus:ring-offset-2 transition-colors"
          >
            Send
          </button>
        </div>
      </form>
    </div>
    """
  end

  @impl true
  def handle_event("send_message", %{"new_message" => new_message}, socket) do
    case Messages.create_message(%{
           content: new_message,
           sender_id: socket.assigns.sender.id,
           receiver_id: socket.assigns.receiver.id
         }) do
      {:ok, message} ->
        Phoenix.PubSub.broadcast(
          ChatApp.PubSub,
          socket.assigns.chat_topic,
          {:message_created, message}
        )
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:message_created, new_message}, socket) do
    {:noreply, stream_insert(socket, :messages, new_message)}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    # Re-check the boolean when someone joins or leaves
    presences = Presence.list(socket.assigns.chat_topic)
    receiver_online? = Map.has_key?(presences, to_string(socket.assigns.receiver.id))

    {:noreply, assign(socket, :receiver_online, receiver_online?)}
  end
end
