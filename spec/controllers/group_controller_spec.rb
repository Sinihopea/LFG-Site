require 'rails_helper'

RSpec.describe GroupController, type: :controller do
  let(:bobby) { FactoryGirl.create(:user) }
  let(:admin_bobby) { FactoryGirl.create(:administrator_user)}
  let(:group) { FactoryGirl.create(:group) }
  let(:membership) { FactoryGirl.create(:group_membership, user: bobby, group: group) }
  let(:admin_membership) { FactoryGirl.create(:group_membership, user: admin_bobby, group: group)}

  describe 'Test the unban system' do
    context 'when banned' do
      before do
        session[:user] = bobby.id
      end
      it 'should unban the user when their ban period is up' do
        membership.ban("dick", 2.weeks.from_now, admin_bobby)
        expect(GroupMembership.find(membership.id).role).to eq("banned")
        get :show, id: group.slug
        expect(GroupMembership.find(membership.id).role).to eq("banned")
        membership.ban("dick", 2.weeks.ago, admin_bobby)
        get :show, id: group.slug
        expect(GroupMembership.find(membership.id).role).to_not eq("banned")
      end
    end
  end

  describe "GET /group" do
    context 'when not logged in' do
      it 'should return all groups and no user group variable' do
        get :index
        expect(response).to render_template("index")
        expect(assigns(:groups)).to_not be_nil
        expect(assigns(:user_groups)).to be_nil
      end
      it 'should not return private groups' do
        group.privacy = :private_group
        group.save
        get :index
        expect(response).to render_template("index")
        expect(assigns(:groups)).to_not include(Group.find(group.id))
      end
    end
    context 'when logged in' do
      before do
        session[:user] = bobby.id
      end
      it 'should return all groups and user groups' do
        get :index
        expect(response).to render_template("index")
        expect(assigns(:groups)).to_not be_nil
        expect(assigns(:user_groups)).to_not be_nil
      end
    end
  end

  describe "POST /group" do
    context 'when not logged in' do
      it 'should return groups when requesting source all' do
        get :index_ajax, {source: "all", page: 0}
        expect(assigns(:groups)).to include(group)
      end
      it 'should not return private groups' do
        group.privacy = :private_group
        group.save
        get :index_ajax, {source: "all", page: 0}
        expect(assigns(:groups)).to_not include(Group.find(group.id))
      end
      it 'should fail gracefully when missing a page parameter' do
        get :index_ajax, {source: "all"}
        expect(response.status).to eq(403)
        expect(assigns(:groups)).to be_nil
      end
      it 'should fail gracefully when requesting source user' do
        get :index_ajax, {source: "user", page: 0}
        expect(response.status).to eq(403)
        expect(assigns(:groups)).to be_nil
      end
    end
    context 'when logged in' do
      before do
        session[:user] = bobby.id
      end
      it 'should fail gracefully when passed an invalid source parameter' do
        get :index_ajax, {source: "invalid", page: 0}
        expect(response.status).to eq(403)
        expect(assigns(:groups)).to be_nil
      end
      it 'should return groups when requesting source all' do
        get :index_ajax, {source: "all", page: 0}
        expect(assigns(:groups)).to include(group)
      end
      it 'should return groups the user is a member of when requesting source user' do
        membership.valid? # It fails if this isn't called. What in the fuck, factory girl?
        get :index_ajax, {source: "user", page: 0}
        expect(assigns(:groups)).to include(group)
      end
    end
  end

  describe "GET /group/new" do
    context 'when not logged in' do
      it 'should gracefully fail' do
        get :new
        expect(response).to_not render_template(:new)
        expect(response).to redirect_to('/signup')
      end
    end
    context 'when logged in' do
      before do
        session[:user] = bobby.id
      end
      context 'and banned' do
        it 'should gracefully fail' do
          bobby.ban("dick", 2.weeks.from_now, admin_bobby)
          get :new
          expect(response).to_not render_template(:new)
          expect(response).to redirect_to(root_url)
          expect(flash[:warning]).to be_present
        end
      end
      it 'should render the new template' do
        get :new
        expect(response).to render_template(:new)
      end
    end
  end

  describe "POST /group/new" do
    context 'when not logged in' do
      it 'should gracefully fail' do
        post :create, group: {title: "newgroup", description: "", membership: "public_membership", privacy: "public_group" }
        expect(assigns(:group)).to_not be_present
        expect(response).to_not redirect_to('/group/newgroup')
        expect(response).to redirect_to('/signup')
      end
    end
    context 'when logged in' do
      before do
        session[:user] = bobby.id
      end
      context 'and banned' do
        it 'should gracefully fail' do
          bobby.ban("dick", 2.weeks.from_now, admin_bobby)
          post :create, group: {title: "newgroup", description: "", membership: "public_membership", privacy: "public_group" }
          expect(assigns(:group)).to_not be_present
          expect(response).to_not redirect_to('/group/newgroup')
          expect(flash[:warning]).to be_present
        end
      end
      it 'should create the group and assign the user as owner' do
        post :create, group: {title: "newgroup", description: "", membership: "public_membership", privacy: "public_group" }
        expect(response).to redirect_to('/group/newgroup')
        expect(Group.last.title).to eq("newgroup")
        expect(Group.last.group_memberships.first.user).to eq(bobby)
        expect(Group.last.group_memberships.first.role).to eq("owner")
      end
      it 'should fail when parameters are missing' do
        post :create, group: {description: ""}
        expect(response).to_not redirect_to('/group/newgroup')
        expect(assigns(:group).valid?).to eq(false)
      end
    end
  end

  describe "POST /group/:id/delete" do
    context 'when not logged in' do
      it 'should fail gracefully' do
        post :delete, id: group.slug, confirmation: group.title
        expect(response).to redirect_to('/signup')
      end
    end
    context 'when logged in' do
      before do
        session[:user] = bobby.id
      end
      context 'but not the owner of the group' do
        it 'should fail gracefully' do
          post :delete, id: group.slug, confirmation: group.title
          expect(response).to redirect_to(root_url)
          expect(flash[:warning]).to be_present
          expect(Group.find(group.id)).to_not be_blank
        end
      end
      context 'and is the owner of the group' do
        before do
          membership.role = :owner
          membership.save
        end
        context 'and the group has other users in it' do
          before do
            # Ensure they're recognised.
            membership.valid?
            admin_membership.valid?
          end
          it 'should fail gracefully' do
            post :delete, id: group.slug, confirmation: group.title
            expect(response).to redirect_to(root_url)
            expect(flash[:warning]).to be_present
            expect(Group.find(group.id)).to_not be_blank
          end
        end
        context 'and the group has no other users in it' do
          before do
            admin_bobby.destroy
            group.save
          end
          context 'and the confirmation does not match the title' do
            it 'should fail gracefully' do
              post :delete, id: group.slug, confirmation: group.title + "blah"
              expect(response).to redirect_to(root_url)
              expect(flash[:warning]).to be_present
              expect(Group.find(group.id)).to_not be_blank
            end
          end
          it 'should delete the group' do
            post :delete, id: group.slug, confirmation: group.title
            expect(Group.where(slug: group.slug)).to be_blank
            expect(response).to_not redirect_to(root_url)
            expect(response).to redirect_to("/group")
            expect(flash[:warning]).to_not be_present
          end
        end
      end
    end
  end

  describe "GET /group/:id" do
    it 'should set the group and show the group template' do
      get :show, id: group.slug
      expect(response).to render_template(:show)
      expect(assigns(:group)).to eq(group)
      expect(response.status).to eq(200)
    end
    context 'when passed an invalid group' do
      it 'should create a 404 error' do
        get :show, id: "doesnt_exist"
        expect(response.status).to eq(404)
      end
    end
  end

  describe "PATCH /group/:id" do
    context 'when not logged in' do
      it 'should fail gracefully' do
        patch :update, id: group.slug, group: { description: "Dicks" }
        expect(response).to redirect_to('/signup')
      end
    end
    context 'when logged in' do
      before do
        session[:user] = bobby.id
      end
      context 'and banned' do
        it 'should fail gracefully' do
          membership.ban("dick", 2.weeks.from_now, admin_bobby)
          post :update, id: group.slug, group: { description: "dicks", membership: "owner_verified", privacy: "public_group", post_control: "management_only_post" }
          expect(response).to_not redirect_to("/group/#{group.slug}")
          expect(flash[:warning]).to be_present
          expect(Group.find(group.id).description).to_not eq("dicks")
        end
      end
      context 'and the user is the owner' do
        before do
          membership.role = "owner"
          membership.save
        end

        it 'should update the group when passed new parameters' do
          old_desc = group.description
          post :update, id: group.slug, group: { description: "dicks"}
          expect(response).to redirect_to("/group/#{group.slug}")
          expect(Group.find(group.id).description).to_not eq(old_desc)
          expect(Group.find(group.id).description).to eq("dicks")
        end

        it 'should fail gracefully when invalid parameters are passed' do
          new_desc = SecureRandom.hex(2000)
          post :update, id: group.slug, group: { description: new_desc}
          expect(response).to redirect_to("/group/#{group.slug}")
          expect(Group.find(group.id).description).to_not eq(new_desc)
        end
      end
      it 'should fail gracefully as the user lacks the permission' do
        old_desc = group.description
        post :update, id: group.slug, group: { description: "dicks"}
        expect(response).to redirect_to(root_url)
        expect(response).to_not redirect_to("/group/#{group.slug}")
        expect(flash[:warning]).to be_present
        expect(Group.find(group.id).description).to eq(old_desc)
        expect(Group.find(group.id).description).to_not eq("dicks")
      end
    end
    context 'and the user is a global admin' do
      before do
        session[:user] = admin_bobby.id
      end
      it 'should let the user change otherwise unchangable parameters' do
        newtitle = SecureRandom.hex(5)
        post :update, id: group.slug, group: { title: newtitle, official: true}
        slug = newtitle.parameterize('_')
        expect(response).to redirect_to("/group/#{slug}")
        expect(Group.find(group.id).title).to eq(newtitle)
        expect(Group.find(group.id).official).to eq(true)
      end
    end
  end

  describe "GET /group/:id/members" do
    before do 
      session[:user] = bobby.id
    end
    context 'when the group is public' do
      before do
        group.privacy = :public_group
        group.save
        membership.role = :owner
        membership.save
        admin_membership.valid?
      end
      it 'should return a hash with members sorted into roles' do
        get :members, id: group.slug
        expect(assigns(:members)).to be_present
        expect(response).to render_template("members")
        expect(assigns(:members)["owner"]).to include(bobby)
      end
    end
    context 'when the group is private' do
      before do
        group.privacy = :private_group
        group.save
        membership.role = :owner
        membership.save
        admin_membership.valid?
      end
      it 'should return a hash with members sorted into roles' do
        get :members, id: group.slug
        expect(assigns(:members)).to be_present
        expect(response).to render_template("members")
        expect(assigns(:members)["owner"]).to include(bobby)
      end
    end
  end

  describe "POST /group/:id/members" do
    before do 
      session[:user] = bobby.id
    end
    context 'when the group is public' do
      before do
        membership.role = :owner
        membership.save
        admin_membership.valid?
      end
      it 'should return a hash with members in the role chosen by the source' do
        get :members_ajax, id: group.slug, source: "owner", page: 0
        expect(assigns(:members)).to be_present
        expect(response).to render_template("raw_user_cards")
        expect(assigns(:members).map(&:user)).to include(bobby)
      end
    end
    context 'when the group is private' do
      before do
        group.privacy = :private_group
        group.save
        membership.role = :owner
        membership.save
        admin_membership.valid?
      end
      context 'and the user is logged in' do
        before do 
          session[:user] = bobby.id
        end
        it 'should return a hash with members in the role chosen by the source' do
          get :members_ajax, id: group.slug, source: "owner", page: 0
          expect(assigns(:members)).to be_present
          expect(response).to render_template("raw_user_cards")
          expect(assigns(:members).map(&:user)).to include(bobby)
        end
      end
    end
  end

  describe "GET /group/:id/members/:user_id" do
    context 'when not logged in' do
      it 'should fail gracefully' do
        get :membership, id: group.slug, user_id: bobby.username
        expect(response).to redirect_to('/signup')
      end
    end
    context 'when logged in' do
      before do
        session[:user] = bobby.id
      end

      context 'but not a member of the group' do
        before do
          membership.delete
        end
        it 'should fail gracefully' do
          get :membership, id: group.slug, user_id: bobby.username
          expect(response).to redirect_to(root_url)
          expect(flash[:warning]).to be_present
        end
      end
      context 'when the user is not an administrator of the group' do
        it 'should fail gracefully' do
          get :membership, id: group.slug, user_id: bobby.username
          expect(response).to redirect_to(root_url)
          expect(flash[:warning]).to be_present
        end
      end
      context 'when the user is an administrator of the group' do
        before do
          membership.role = :owner
          membership.save
          admin_membership.valid?
        end
        it 'should render a 404 when the user id is invalid' do
          get :membership, id: group.slug, user_id: "invaid"
          expect(response.status).to eq(404)
          expect(response).to render_template("shared/not_found")
        end
        it 'return variables containing the user and their group membership' do
          admin_membership.ban("dick", 1.week.from_now, bobby)
          get :membership, id: group.slug, user_id: admin_bobby.username
          expect(assigns(:user)).to be_present
          expect(assigns(:user_membership)).to be_present
          expect(assigns(:user_bans)).to_not be_empty
          expect(response).to render_template("membership")
        end
      end
    end
  end

  describe "PATCH /group/:id/members/:user_id" do
    context 'when not logged in' do
      it 'should fail gracefully' do
        patch :update_membership, id: group.slug, user_id: bobby.username
        expect(response).to redirect_to('/signup')
      end
    end
    context 'when logged in' do
      before do
        session[:user] = bobby.id
      end

      context 'but not a member of the group' do
        before do
          membership.delete
        end
        it 'should fail gracefully' do
          patch :update_membership, id: group.slug, user_id: bobby.username
          expect(response).to redirect_to(root_url)
          expect(flash[:warning]).to be_present
        end
      end
      context 'when the user is not an administrator of the group' do
        it 'should fail gracefully' do
          patch :update_membership, id: group.slug, user_id: bobby.username
          expect(response).to redirect_to(root_url)
          expect(flash[:warning]).to be_present
        end
      end

      context 'when the user is an administrator of the group' do
        before do
          membership.role = :owner
          membership.save
          admin_membership.valid?
        end
        it 'should render a 404 when the user id is invalid' do
          patch :update_membership, id: group.slug, user_id: "invaid"
          expect(response.status).to eq(404)
          expect(response).to render_template("shared/not_found")
        end
        it 'should render an error when missing a goal parameter' do
          patch :update_membership, id: group.slug, user_id: admin_bobby.username
          expect(response).to redirect_to(root_url)
          expect(flash[:warning]).to be_present
        end
        it 'should render an error when given an invalid goal parameter' do
          patch :update_membership, id: group.slug, user_id: admin_bobby.username, goal: "nonexistant"
          expect(response).to redirect_to(root_url)
          expect(flash[:warning]).to be_present
        end 
        context 'when updating the role' do
          it 'should update the users role to the newly specified role' do
            patch :update_membership, id: group.slug, user_id: admin_bobby.username, goal: "role", group_membership: { role: :moderator }
            expect(response).to redirect_to(root_url)
            expect(flash[:warning]).to_not be_present
            expect(assigns[:user_membership].role).to eq("moderator")
            expect(assigns[:user_membership]).to be_valid
          end
        end
        context 'when approving user' do
          before do
            group.membership = :owner_verified
            group.save
            admin_membership.role = :unverified
            admin_membership.save
          end
          it 'should update the users role to the newly specified role' do
            patch :update_membership, id: group.slug, user_id: admin_bobby.username, goal: "approve"
            expect(response).to redirect_to(root_url)
            expect(flash[:warning]).to_not be_present
            expect(assigns[:user_membership].role).to eq("member")
            expect(assigns[:user_membership]).to be_valid
            expect(Notification.last.user).to eq(admin_bobby)
          end
        end
        context 'when promoting a user to owner' do
          it 'should gracefully fail the user is already owner' do
            patch :update_membership, id: group.slug, user_id: bobby.username, goal: "promote"
            expect(response).to redirect_to(root_url)
            expect(flash[:warning]).to be_present
          end
          it 'should update the users role to owner, and make the existing owner an admin' do
            patch :update_membership, id: group.slug, user_id: admin_bobby.username, goal: "promote"
            expect(response).to redirect_to(root_url)
            expect(flash[:warning]).to_not be_present
            expect(assigns[:user_membership].role).to eq("owner")
            expect(assigns[:user_membership]).to be_valid
          end
        end
      end
    end
  end

  describe "POST /group/:id/members/:user_id/ban" do
    context 'when not logged in' do
      it 'should fail gracefully' do
        post :ban, id: group.slug, user_id: bobby.username
        expect(response).to redirect_to('/signup')
      end
    end
    context 'when logged in' do
      before do
        session[:user] = bobby.id
      end

      context 'but not a member of the group' do
        before do
          membership.delete
        end
        it 'should fail gracefully' do
          post :ban, id: group.slug, user_id: bobby.username
          expect(response.status).to eq(403)
        end
      end
      context 'when the user is not an administrator of the group' do
        it 'should fail gracefully' do
          post :ban, id: group.slug, user_id: bobby.username
          expect(response.status).to eq(403)
        end
      end
      context 'when the user is an administrator of the group' do
        before do
          membership.role = :owner
          membership.save
          admin_membership.valid?
        end
        it 'should render a 404 when the user id is invalid' do
          post :ban, id: group.slug, user_id: "invaid"
          expect(response.status).to eq(404)
          expect(response).to render_template("shared/not_found")
        end
        it 'should duration parameter is invalid it should gracefully fail' do
          post :ban, id: group.slug, user_id: admin_bobby.username, duration: "invalid"
          expect(response).to redirect_to root_url
          expect(flash[:warning]).to be_present
        end
        it 'should ban a user with the specified duration' do
          post :ban, id: group.slug, user_id: admin_bobby.username, duration: "one_day"
          last = Ban.last
          expect(last.end_date).to eq(1.day.from_now.to_date)
          expect(last.user).to eq(admin_bobby)

          post :ban, id: group.slug, user_id: admin_bobby.username, duration: "three_days"
          last = Ban.last
          expect(last.end_date).to eq(3.days.from_now.to_date)
          expect(last.user).to eq(admin_bobby)

          post :ban, id: group.slug, user_id: admin_bobby.username, duration: "one_week"
          last = Ban.last
          expect(last.end_date).to eq(1.week.from_now.to_date)
          expect(last.user).to eq(admin_bobby)

          post :ban, id: group.slug, user_id: admin_bobby.username, duration: "one_month"
          last = Ban.last
          expect(last.end_date).to eq(1.month.from_now.to_date)
          expect(last.user).to eq(admin_bobby)

          post :ban, id: group.slug, user_id: admin_bobby.username, duration: "perm"
          last = Ban.last
          expect(last.end_date).to eq(nil)
          expect(last.user).to eq(admin_bobby)
        end
        it 'should unban the user' do
          admin_membership.ban("dick", nil, bobby)
          expect(GroupMembership.find(admin_membership.id).role).to eq("banned")
          post :ban, id: group.slug, user_id: admin_bobby.username, duration: "unban"
          expect(assigns[:user_membership].role).to_not eq("banned")
          expect(assigns[:user_membership]).to be_valid
          expect(response).to redirect_to(root_url)
          expect(flash[:info]).to be_present
        end 
      end
    end
  end

  describe "POST /group/:id/new_post" do
    context 'when not logged in' do
      it 'should fail gracefully' do
        post :create_post, id: group.slug
        expect(response).to redirect_to('/signup')
      end
    end
    context 'when logged in' do
      before do
        session[:user] = bobby.id
      end
      it 'should create a new post when passed valid parameters' do
        body = "Test post body"
        post :create_post, {id: group.slug, body: body}
        expect(group.posts.last.body).to eq(body)
      end
      context "while being an administrator and passing the official flag" do
        let(:admin_bobby) { FactoryGirl.create(:administrator_user) }
        before do
          FactoryGirl.create(:group_membership, user: admin_bobby, group: group, role: :owner)
          session[:user] = admin_bobby.id
        end
        it 'should create an official group post' do
          body = "Test post body"
          post :create_post, {id: group.slug, body: body, official: true}
          post = group.posts.where(official: true).last
          expect(post.body).to eq(body)
          expect(post.official).to be(true)
        end
      end
    end
  end

  describe "GET /group/:id/join" do
    context 'when not logged in' do
      it 'should fail gracefully' do
        get :join, id: group.slug
        expect(response).to redirect_to('/signup')
      end
    end
    context 'when logged in' do
      before do
        session[:user] = bobby.id
        membership.delete
      end
      context 'and globally banned' do
        it 'should reject the user from joining' do
          bobby.ban("dick", 2.weeks.from_now, admin_bobby)
          get :join, id: group.slug
          expect(group.group_memberships.map(&:user)).to_not include(bobby)
        end
      end
      context 'and the group is invite only' do
        before do
          group.membership = :invite_only
          group.save
        end
        it 'should reject the user from joining' do
          get :join, id: group.slug
          expect(group.group_memberships.map(&:user)).to_not include(bobby)
        end
      end
      context 'and the user is already part of the group' do
        before do
          session[:user] = admin_bobby.id
        end
        it 'should reject the user from joining' do
          get :join, id: group.slug
          expect(group.group_memberships.map(&:user)).to_not include(bobby)
        end
      end
      context 'and the group is owner verified' do
        before do
          group.membership = :owner_verified
          group.save
        end
        it 'should join the group but be marked as an unverified user' do
          get :join, id: group.slug
          expect(group.group_memberships.map(&:user)).to include(bobby)
          expect(group.group_memberships.last.role).to eq("unverified")
        end
      end
      context 'when the membership conditions are invalid' do
        it 'should generate an error' do
          get :join, id: group.slug, invalid: true
          expect(group.group_memberships.map(&:user)).to_not include(bobby)
          expect(flash[:info]).to include("error")
        end
      end
      it 'should join the group' do
        get :join, id: group.slug
        expect(group.group_memberships.map(&:user)).to include(bobby)
        expect(group.group_memberships.last.role).to eq("member")
      end
    end
  end

  describe "GET /group/:id/leave" do
    context 'when not logged in' do
      it 'should fail gracefully' do
        get :leave, id: group.slug
        expect(response).to redirect_to('/signup')
      end
    end
    context 'when logged in' do
      before do
        session[:user] = bobby.id
      end
      context 'when not member of group' do
        before do
          membership.delete
        end
        it 'should gracefully fail' do
          get :leave, id: group.slug
          expect(response).to redirect_to(root_url)
          expect(flash[:warning]).to be_present
        end
      end
      context 'when banned from group' do
        it 'should fail gracefully' do
          membership.ban("dick", 2.weeks.from_now, admin_bobby)
          get :leave, id: group.slug
          expect(response).to redirect_to(root_url)
          expect(flash[:warning]).to be_present
          expect(GroupMembership.find(membership.id)).to be_present
        end
      end
      context 'when owner of the group' do
        before do
          membership.role = :owner
          membership.save
        end
        it 'should fail gracefully' do
          get :leave, id: group.slug
          expect(response).to redirect_to(root_url)
          expect(flash[:warning]).to be_present
          expect(flash[:warning]).to include("owner")
          expect(GroupMembership.find(membership.id)).to be_present
        end        
      end
      it 'should destroy the membership of the user' do
        expect(GroupMembership.find(membership.id)).to be_present
        get :leave, id: group.slug
        expect(response).to redirect_to(root_url)
        expect { GroupMembership.find(membership.id) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe "GET /group/search" do
    it 'should return groups when searched for' do
      get :search, query: group.title
      expect(response).to_not redirect_to('/signup')
      expect(assigns(:groups)).to_not be_nil
      expect(assigns(:groups).map(&:title)).to include(group.title)
      expect(response).to render_template('search')
    end

    it 'should return groups using the raw cards template when the raw parameter is passed' do
      get :search, query: group.title, raw: true
      expect(response).to_not redirect_to('/signup')
      expect(assigns(:groups)).to_not be_nil
      expect(assigns(:groups).map(&:title)).to include(group.title)
      expect(response).to render_template('raw_cards')
    end
  end

  describe "GET /group/:id/posts/:post_id" do
    context 'when logged in' do
      before do
        session[:user] = bobby.id
      end
      let(:new_post) { FactoryGirl.create(:post, user: bobby, group: group) }
      it "sets @post" do
        get :show_post, id: group.slug, post_id: new_post.id
        expect(assigns(:post)).to eq(new_post)
      end
      it "renders an error for an invalid id" do
        get :show_post, id: group.slug, post_id: 9953259
        expect(response).to render_template('shared/not_found')
        expect(response.status).to eq(404)
      end
      it 'enforces alignment of group_id and post ownership' do
        get :show_post, id: "non-existant-group", post_id: new_post.id
        expect(response).to render_template('shared/not_found')
        expect(response.status).to eq(404)
      end
    end
  end

  describe "POST /group/:id/posts/:post_id/comment" do
    let(:new_post) { FactoryGirl.create(:post, user: bobby, group: group) }
    context "while not logged in" do
      it "should redirect to /signup" do
        post :create_reply, { id: group.slug, post_id: new_post.id }
        expect(response).to redirect_to('/signup')
      end
    end
    context "while logged in" do
      before do
        session[:user] = bobby.id
      end
      context "while passing arguments" do
        let(:mismatched_group) { FactoryGirl.create(:group, title: "Wrong Group") }
        it 'creates a new comment' do
          body = "testing"
          post :create_reply, { id: group.slug, post_id: new_post.id, body: body }
          expect(new_post.children.first.body).to eq(body)
          expect(response).to redirect_to(root_url)
        end
        it 'creates a new comment and returns in json format' do
          body = "testing json"
          post :create_reply, { id: group.slug, post_id: new_post.id, body: body, format: :json }
          parsed = JSON.parse(response.body)
          expect(parsed["body"]).to_not be_nil
        end
        it 'creates an error message in json format when an error is present' do
          body = ""
          500.times { body << "testing json " } # create a body too large.
          post :create_reply, { id: group.slug, post_id: new_post.id, body: body, format: :json }
          expect(response.status).to eq(400)
        end
        it 'should generate a 404 when a posts group does not match the one in the URL' do
          post :create_reply, { id: mismatched_group.slug, post_id: new_post.id, body: 'testing' }
          expect(response).to render_template('shared/not_found')
          expect(response.status).to eq(404)
        end
      end
    end
  end

  describe '#set_locale' do
    context 'when the group language is set to japanese' do
      let(:group) { FactoryGirl.create(:group, language: :japanese) }
      it 'should set certain variables for encoding' do
        get :show, id: group.slug
        expect(assigns(:lang)).to eq('ja')
        expect(assigns(:charset)).to eq('shift-jis')
        expect(assigns(:encoding)).to eq(Encoding::Shift_JIS)
      end
    end
  end

  describe '#universal_permission_check' do
    context 'when a user has a global permission' do
      it 'should return true' do
        expect(controller.send(:universal_permission_check, "can_create_post", {user: bobby})).to eq(true)
      end
    end
    context 'when a user has a group permission' do
      before do
        membership.role = :owner
        membership.save
      end

      it 'should return true' do
        permissions = GroupMembership.get_permission(membership, group)
        expect(controller.send(:universal_permission_check, "can_edit_group_member_roles", {permissions: permissions, user: bobby})).to eq(true)
      end
    end
  end
end
