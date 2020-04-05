require 'openssl'

class User < ApplicationRecord
  ITERATIONS = 20_000
  DIGEST = OpenSSL::Digest::SHA256.new

  attr_accessor :password

  has_many :questions, dependent: :destroy

  validates :email, :username, presence: true, uniqueness: true
  validates :username, length: {maximum: 40}, format: {with: /\A[A-Za-z\d_]+\z/i}
  validates :email, 'valid_email2/email': true
  validates :password, presence: true, on: :create
  validates :color, format: /\A#([A-Fa-f0-9]{6})\z/i, allow_blank: true

  validates_confirmation_of :password
  before_validation :normalize_user, on: [ :create, :update ]
  before_save :encrypt_password

  def encrypt_password
    if password.present?
      self.password_salt = User.hash_to_string(OpenSSL::Random.random_bytes(16))
      self.password_hash = User.hash_to_string(
          OpenSSL::PKCS5.pbkdf2_hmac(
              password, password_salt, ITERATIONS, DIGEST.length, DIGEST
          )
      )
    end
  end

  def self.hash_to_string(password_hash)
    password_hash.unpack('H*')[0]
  end

  def self.authenticate(email, password)
    user = find_by(email: email)
    return nil unless user.present?
    hashed_password = User.hash_to_string(
        OpenSSL::PKCS5.pbkdf2_hmac(
            password, user.password_salt, ITERATIONS, DIGEST.length, DIGEST
        )
    )
    return user if user.password_hash == hashed_password
    nil
  end

  private

  def normalize_user
    self.username&.downcase!
    self.email&.downcase!
  end
end
