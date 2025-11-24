class User < ApplicationRecord
  has_many :jobs, dependent: :destroy
end
