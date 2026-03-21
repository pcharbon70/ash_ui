defmodule AshUI.Test.RuntimeDomain do
  @moduledoc false

  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource AshUI.Test.Profile
    resource AshUI.Test.User
    resource AshUI.Test.Post
    resource AshUI.Test.Comment
  end
end

defmodule AshUI.Test.Profile do
  @moduledoc false

  @resource_topic_prefix "ash_ui:resource:AshUI:Test:Profile"

  use Ash.Resource,
    domain: AshUI.Test.RuntimeDomain,
    notifiers: [Ash.Notifier.PubSub],
    data_layer: Ash.DataLayer.Ets

  ets do
    private? true
  end

  pub_sub do
    module AshUI.Notifications
    prefix @resource_topic_prefix

    publish :create, "changes"
    publish :update, "changes"
    publish :destroy, "changes"
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:name]
    end

    update :update do
      primary? true
      accept [:name]
    end
  end
end

defmodule AshUI.Test.User do
  @moduledoc false

  @resource_topic_prefix "ash_ui:resource:AshUI:Test:User"

  use Ash.Resource,
    domain: AshUI.Test.RuntimeDomain,
    notifiers: [Ash.Notifier.PubSub],
    data_layer: Ash.DataLayer.Ets

  ets do
    private? true
  end

  pub_sub do
    module AshUI.Notifications
    prefix @resource_topic_prefix

    publish :create, "changes"
    publish :update, "changes"
    publish :destroy, "changes"
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
    attribute :email, :string, allow_nil?: false, public?: true
    attribute :nickname, :string, public?: true
    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :profile, AshUI.Test.Profile do
      attribute_type :uuid
      allow_nil? true
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:name, :email, :nickname, :profile_id]
    end

    update :update do
      primary? true
      accept [:name, :email, :nickname, :profile_id]
    end
  end
end

defmodule AshUI.Test.Post do
  @moduledoc false

  @resource_topic_prefix "ash_ui:resource:AshUI:Test:Post"

  use Ash.Resource,
    domain: AshUI.Test.RuntimeDomain,
    notifiers: [Ash.Notifier.PubSub],
    data_layer: Ash.DataLayer.Ets

  ets do
    private? true
  end

  pub_sub do
    module AshUI.Notifications
    prefix @resource_topic_prefix

    publish :create, "changes"
    publish :update, "changes"
    publish :destroy, "changes"
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false, public?: true
  end

  relationships do
    has_many :comments, AshUI.Test.Comment do
      destination_attribute :post_id
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:title]
    end

    update :update do
      primary? true
      accept [:title]
    end
  end
end

defmodule AshUI.Test.Comment do
  @moduledoc false

  @resource_topic_prefix "ash_ui:resource:AshUI:Test:Comment"

  use Ash.Resource,
    domain: AshUI.Test.RuntimeDomain,
    notifiers: [Ash.Notifier.PubSub],
    data_layer: Ash.DataLayer.Ets

  ets do
    private? true
  end

  pub_sub do
    module AshUI.Notifications
    prefix @resource_topic_prefix

    publish :create, "changes"
    publish :update, "changes"
    publish :destroy, "changes"
  end

  attributes do
    uuid_primary_key :id
    attribute :content, :string, allow_nil?: false, public?: true
  end

  relationships do
    belongs_to :post, AshUI.Test.Post do
      attribute_type :uuid
      allow_nil? false
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:content, :post_id]
    end

    update :update do
      primary? true
      accept [:content]
    end
  end
end

defmodule AshUI.Test.RuntimeFixtures do
  @moduledoc false

  alias AshUI.Test.Comment
  alias AshUI.Test.Post
  alias AshUI.Test.Profile
  alias AshUI.Test.RuntimeDomain
  alias AshUI.Test.User

  def seed! do
    {:ok, profile} =
      Ash.create(Profile, %{name: "Primary Profile"}, domain: RuntimeDomain)

    {:ok, user} =
      Ash.create(
        User,
        %{
          name: "Pascal",
          email: "pascal@example.com",
          nickname: nil,
          profile_id: profile.id
        },
        domain: RuntimeDomain
      )

    {:ok, other_user} =
      Ash.create(
        User,
        %{
          name: "Secondary",
          email: "secondary@example.com",
          nickname: "Second",
          profile_id: profile.id
        },
        domain: RuntimeDomain
      )

    {:ok, post} =
      Ash.create(Post, %{title: "Release Notes"}, domain: RuntimeDomain)

    {:ok, first_comment} =
      Ash.create(
        Comment,
        %{content: "First comment", post_id: post.id},
        domain: RuntimeDomain
      )

    {:ok, second_comment} =
      Ash.create(
        Comment,
        %{content: "Second comment", post_id: post.id},
        domain: RuntimeDomain
      )

    %{
      actor: %{id: "actor-1", role: :admin},
      profile: profile,
      user: user,
      other_user: other_user,
      post: post,
      comments: [first_comment, second_comment]
    }
  end

  def context(fixtures, extra \\ %{}) do
    Map.merge(
      %{
        user_id: fixtures.actor.id,
        actor: fixtures.actor,
        params: %{},
        assigns: %{},
        ash_domains: [RuntimeDomain]
      },
      extra
    )
  end

  def socket(assigns \\ %{}) do
    assigns =
      case assigns do
        assigns when is_list(assigns) -> Enum.into(assigns, %{})
        assigns -> assigns
      end

    %Phoenix.LiveView.Socket{
      assigns:
        assigns
        |> Map.put_new(:ash_ui, %{})
        |> Map.put_new(:ash_ui_domains, [RuntimeDomain])
        |> Map.put_new(:__changed__, %{})
    }
  end
end
