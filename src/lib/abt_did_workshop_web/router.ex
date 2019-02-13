defmodule AbtDidWorkshopWeb.Router do
  use AbtDidWorkshopWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", AbtDidWorkshopWeb do
    pipe_through(:browser)
    get("/", DidController, :index)
    post("/did", DidController, :create)
    get("/did/show", DidController, :show)
    get("/did/new", DidController, :new)
  end

  scope "/api", AbtDidWorkshopWeb do
    pipe_through(:api)
    get("/logon", LogonController, :request)
    post("/logon", LogonController, :auth)
  end

  # Other scopes may use custom stacks.
  # scope "/api", AbtDidWorkshopWeb do
  #   pipe_through :api
  # end
end
