defmodule AbtDidWorkshopWeb.Router do
  use AbtDidWorkshopWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    # plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", AbtDidWorkshopWeb do
    pipe_through(:browser)

    # get("/", PageController, :index)
    # get("/pages", PageController, :new)
    # post("/post", PageController, :create)
    # post("/did", DidController, :new)
    # get("/did/new", DidController, :create)
    # get "/did/new" DidController, :new
    # resources("/", DidController)
    get("/", DidController, :index)
    post("/did", DidController, :create)
    post("/logon", LogonController, :logon)
  end

  # Other scopes may use custom stacks.
  # scope "/api", AbtDidWorkshopWeb do
  #   pipe_through :api
  # end
end
