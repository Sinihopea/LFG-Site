require 'rails_helper'

RSpec.describe Group, type: :model do
  let(:group) { FactoryGirl.create(:group) }
  let(:bobby) { FactoryGirl.create(:user) }
  before do
    FactoryGirl.create(:group_membership, user: bobby, group: group)
  end
  it "has a valid factory" do
    expect(group).to be_valid
    expect(group.slug).to_not be_empty
    expect(bobby).to be_valid
    expect(bobby.groups).to include(group)
  end
end
