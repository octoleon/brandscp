require 'rails_helper'

describe BrandPortfolio, type: :model, search: true do
  it 'should search for brand portfolios' do
    # First populate the Database with some data
    brand = create(:brand)
    brand2 = create(:brand)
    brand_portfolio = create(:brand_portfolio, company_id: 1, brand_ids: [brand.id])
    brand_portfolio2 = create(:brand_portfolio, company_id: 1, brand_ids: [brand.id, brand2.id])

    # Create a Brand Portfolio on company 2
    company2_brand_portfolio = create(:brand_portfolio, company_id: 2)

    # Search for all Brand Portfolios on a given Company
    expect(search(company_id: 1))
    .to match_array([brand_portfolio, brand_portfolio2])
    expect(search(company_id: 2))
    .to match_array([company2_brand_portfolio])

    # Search for brands associated to the Brand Portfolios
    expect(search(company_id: 1, brand: brand.id))
    .to match_array([brand_portfolio, brand_portfolio2])
    expect(search(company_id: 1, brand: brand2.id))
    .to match_array([brand_portfolio2])
    expect(search(company_id: 1, brand: [brand.id, brand2.id]))
    .to match_array([brand_portfolio, brand_portfolio2])

    # Search for a given Brand Portfolio
    expect(search(company_id: 1, brand_portfolio: [brand_portfolio.id]))
    .to match_array([brand_portfolio])

    # Search for Brand Portfolios on a given status
    expect(search(company_id: 1, status: ['Active']))
    .to match_array([brand_portfolio, brand_portfolio2])
  end
end
