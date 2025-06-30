defmodule Mix.Tasks.CreateAdmin do
  @moduledoc """
  Mix task to create an admin user.

  ## Usage

      mix create_admin --email admin@example.com --password secretpassword

  ## Options

    * `--email` - The email address for the admin user (required)
    * `--password` - The password for the admin user (required)

  ## Examples

      mix create_admin --email admin@forex.com --password admin123456
      mix create_admin -e admin@test.com -p mypassword
  """

  use Mix.Task

  alias ForexCalendar.Accounts
  alias ForexCalendar.Repo

  @shortdoc "Creates an admin user"

  @switches [
    email: :string,
    password: :string
  ]

  @aliases [
    e: :email,
    p: :password
  ]

  def run(args) do
    Mix.Task.run("app.start")

    {opts, _} = OptionParser.parse!(args, switches: @switches, aliases: @aliases)

    email = opts[:email]
    password = opts[:password]

    cond do
      is_nil(email) ->
        Mix.shell().error("Email is required. Use --email or -e flag.")
        System.halt(1)

      is_nil(password) ->
        Mix.shell().error("Password is required. Use --password or -p flag.")
        System.halt(1)

      true ->
        create_admin_user(email, password)
    end
  end

  defp create_admin_user(email, password) do
    attrs = %{
      email: email,
      password: password
    }

    case Accounts.register_admin_user(attrs) do
      {:ok, user} ->
        # Automatically confirm the admin user
        confirmed_user = confirm_user(user)

        Mix.shell().info("✅ Admin user created successfully!")
        Mix.shell().info("📧 Email: #{confirmed_user.email}")
        Mix.shell().info("👑 Role: #{confirmed_user.role}")

        Mix.shell().info(
          "✅ Account confirmed: #{if confirmed_user.confirmed_at, do: "Yes", else: "No"}"
        )

      {:error, changeset} ->
        Mix.shell().error("❌ Failed to create admin user:")

        Enum.each(changeset.errors, fn {field, {message, _}} ->
          Mix.shell().error("  • #{field}: #{message}")
        end)

        System.halt(1)
    end
  end

  defp confirm_user(user) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    user
    |> Ecto.Changeset.change(confirmed_at: now)
    |> Repo.update!()
  end
end
