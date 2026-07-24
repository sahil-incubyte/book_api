class Review < ApplicationRecord
  belongs_to :book

  validates :reviewer, presence: true
  validates :rating, presence: true, numericality: { in: 1..5 }
end
