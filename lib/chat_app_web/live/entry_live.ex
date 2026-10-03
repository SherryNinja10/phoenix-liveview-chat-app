defmodule ChatAppWeb.EntryLive do
  use ChatAppWeb, :live_view

  alias ChatApp.Accounts

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, pending_sender: nil, validate_receiver: nil, show_register_form: false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-md mx-auto mt-20 p-6 bg-white rounded-lg shadow-md">
      <%= if msg = @flash["info"] do %>
        <div
          class="p-4 mb-4 text-sm text-green-800 rounded-lg bg-green-50 border border-green-200"
          role="alert"
        >
          <span class="font-bold">Success:</span> {msg}
        </div>
      <% end %>

      <%= if msg = @flash["error"] do %>
        <div
          class="p-4 mb-4 text-sm text-red-800 rounded-lg bg-red-50 border border-red-200"
          role="alert"
        >
          <span class="font-bold">Error:</span> {msg}
        </div>
      <% end %>

      <h1 class="text-2xl font-bold mb-6 text-center text-zinc-800">
        {if @show_register_form, do: "Register User", else: "Start a Chat"}
      </h1>

      <%= if @pending_sender do %>
        <div class="text-center space-y-6">
          <p class="text-zinc-700">
            The username <span class="font-bold text-black">{@pending_sender}</span> does not exist.
            Would you like to create a new account and join the chat?
          </p>

          <div class="flex gap-4">
            <button
              type="button"
              phx-click="cancel_create"
              class="w-full py-2 px-4 border border-zinc-300 rounded-md shadow-sm text-sm font-medium text-zinc-700 bg-white hover:bg-zinc-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-zinc-900"
            >
              Cancel
            </button>
            <button
              type="button"
              phx-click="create_user"
              class="w-full py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-brand bg-zinc-900 hover:bg-zinc-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-zinc-900"
            >
              Yes, create user
            </button>
          </div>
        </div>
      <% else %>
        <%= if @show_register_form do %>
          <form phx-submit="register_standalone" class="space-y-4">
            <div>
              <label for="new_username" class="block text-sm font-medium text-zinc-700">
                New Username
              </label>
              <input
                type="text"
                name="new_username"
                id="new_username"
                required
                class="mt-1 block w-full rounded-md bg-black text-white border-zinc-700 placeholder-zinc-500 shadow-sm focus:border-brand focus:ring-brand sm:text-sm"
                placeholder="e.g. charlie"
              />
            </div>

            <button
              type="submit"
              class="w-full flex justify-center py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-zinc-900 hover:bg-zinc-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-zinc-900 mt-6"
            >
              Create Account
            </button>
          </form>

          <div class="mt-4 text-center">
            <button
              type="button"
              phx-click="toggle_register"
              class="text-sm text-zinc-500 hover:text-zinc-800 underline"
            >
              Back to Chat
            </button>
          </div>
        <% else %>
          <form phx-submit="join_chat" class="space-y-4">
            <div>
              <label for="sender_username" class="block text-sm font-medium text-zinc-700">
                Your Username
              </label>
              <input
                type="text"
                name="sender_username"
                id="sender_username"
                required
                class="mt-1 block w-full rounded-md bg-black text-white border-zinc-700 placeholder-zinc-500 shadow-sm focus:border-brand focus:ring-brand sm:text-sm"
                placeholder="e.g. alice"
              />
            </div>

            <div>
              <label for="receiver_username" class="block text-sm font-medium text-zinc-700">
                Who do you want to chat with?
              </label>
              <input
                type="text"
                name="receiver_username"
                id="receiver_username"
                required
                class="mt-1 block w-full rounded-md bg-black text-white border-zinc-700 placeholder-zinc-500 shadow-sm focus:border-brand focus:ring-brand sm:text-sm"
                placeholder="e.g. bob"
              />
            </div>

            <button
              type="submit"
              class="w-full flex justify-center py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-zinc-900 hover:bg-zinc-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-zinc-900 mt-6"
            >
              Enter Chat Room
            </button>
          </form>

          <div class="mt-4 text-center">
            <button
              type="button"
              phx-click="toggle_register"
              class="text-sm text-zinc-500 hover:text-zinc-800 underline"
            >
              Need to register a user?
            </button>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  # When the user submit's the form to join a chat
  @impl true
  def handle_event(
        "join_chat",
        %{"sender_username" => sender_name, "receiver_username" => receiver_name},
        socket
      ) do
    case Accounts.get_user_by_username(receiver_name) do
      nil ->
        {:noreply, put_flash(socket, :error, "This user doesn't exist")}

      receiver ->
        case Accounts.get_user_by_username(sender_name) do
          nil ->
            {:noreply, assign(socket, pending_sender: sender_name, valid_receiver: receiver)}

          sender ->
            {:noreply, push_navigate(socket, to: "/chat/#{sender.id}/#{receiver.id}")}
        end
    end
  end

  # When the user wanted to create a user
  @impl true
  def handle_event("create_user", _params, socket) do
    case Accounts.create_user(%{username: socket.assigns.pending_sender}) do
      {:ok, new_sender} ->
        {:noreply,
         push_navigate(socket, to: ~p"/chat/#{new_sender.id}/#{socket.assigns.valid_receiver.id}")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create user.")}
    end
  end

  @impl true
  def handle_event("cancel_create", _params, socket) do
    {:noreply, assign(socket, pending_sender: nil, valid_receiver: nil)}
  end

  @impl true
  def handle_event("toggle_register", _, socket) do
    {:noreply, assign(socket, show_register_form: !socket.assigns.show_register_form)}
  end

  @impl true
  def handle_event("register_standalone", %{"new_username" => new_username}, socket) do
    case Accounts.create_user(%{username: new_username}) do
      {:ok, _new_sender} ->
        socket =
          socket
          |> put_flash(:info, "User created! You can now start a chat.")
          |> assign(show_register_form: false)

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply,
         put_flash(socket, :error, "Failed to create user. User likely already exists.")}
    end
  end
end
