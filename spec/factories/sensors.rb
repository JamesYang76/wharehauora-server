FactoryGirl.define do
  factory :sensor do
    node_id { rand 100..999 }
    room
    home
  end
end
