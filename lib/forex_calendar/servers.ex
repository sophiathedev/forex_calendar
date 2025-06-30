defmodule ForexCalendar.Servers do
  @moduledoc """
  The Servers context.
  """

  import Ecto.Query, warn: false
  alias ForexCalendar.Repo

  alias ForexCalendar.Servers.{Server, ServerSetting}

  @doc """
  Returns the list of servers for a user.

  ## Examples

      iex> list_servers(user_id)
      [%Server{}, ...]

  """
  def list_servers(user_id) do
    Repo.all(from s in Server, where: s.user_id == ^user_id)
  end

  @doc """
  Gets a single server.

  Raises `Ecto.NoResultsError` if the Server does not exist.

  ## Examples

      iex> get_server!(123)
      %Server{}

      iex> get_server!(456)
      ** (Ecto.NoResultsError)

  """
  def get_server!(id), do: Repo.get!(Server, id)

  @doc """
  Creates a server.

  ## Examples

      iex> create_server(%{field: value})
      {:ok, %Server{}}

      iex> create_server(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_server(attrs \\ %{}) do
    %Server{}
    |> Server.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a server.

  ## Examples

      iex> update_server(server, %{field: new_value})
      {:ok, %Server{}}

      iex> update_server(server, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_server(%Server{} = server, attrs) do
    server
    |> Server.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a server.

  ## Examples

      iex> delete_server(server)
      {:ok, %Server{}}

      iex> delete_server(server)
      {:error, %Ecto.Changeset{}}

  """
  def delete_server(%Server{} = server) do
    Repo.delete(server)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking server changes.

  ## Examples

      iex> change_server(server)
      %Ecto.Changeset{data: %Server{}}

  """
  def change_server(%Server{} = server, attrs \\ %{}) do
    Server.changeset(server, attrs)
  end

  @doc """
  Gets server settings for a server.

  ## Examples

      iex> get_server_settings(server_id)
      %ServerSetting{}

      iex> get_server_settings(456)
      nil

  """
  def get_server_settings(server_id) do
    Repo.get_by(ServerSetting, server_id: server_id)
  end

  @doc """
  Creates server settings.

  ## Examples

      iex> create_server_settings(%{field: value})
      {:ok, %ServerSetting{}}

      iex> create_server_settings(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_server_settings(attrs \\ %{}) do
    %ServerSetting{}
    |> ServerSetting.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates server settings.

  ## Examples

      iex> update_server_settings(server_setting, %{field: new_value})
      {:ok, %ServerSetting{}}

      iex> update_server_settings(server_setting, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_server_settings(%ServerSetting{} = server_setting, attrs) do
    server_setting
    |> ServerSetting.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking server settings changes.

  ## Examples

      iex> change_server_settings(server_setting)
      %Ecto.Changeset{data: %ServerSetting{}}

  """
  def change_server_settings(%ServerSetting{} = server_setting, attrs \\ %{}) do
    ServerSetting.changeset(server_setting, attrs)
  end
end
