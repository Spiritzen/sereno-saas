# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Assets Factur-X vendorés" do
  it "le profil ICC sRGB est présent dans le repo" do
    expect(File.exist?(Rails.root.join("config", "facturx", "sRGB.icc"))).to be(true)
  end
end
