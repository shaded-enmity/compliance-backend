# frozen_string_literal: true

# The `parents` parameter is required when testing nested controllers, and it should contain
# an ordered list of reflection symbols similarly to how they are defined in the routes. It is
# also required to set the `extra_params` variable in a let block and pass all the parent IDs
# there as a hash. For example:
# ```
# it_behaves_like 'paginable', :security_guide, :profile do
#   let(:extra_params) { { security_guide_id: 123, profile_id: 456 } }
# end
# ```
#
# In a non-nested case this example can be simply included as:
# ```
# it_behaves_like 'paginable'
# ```
#
RSpec.shared_examples 'paginable' do |*parents|
  let(:item_count) { 20 } # We need more items to be created to test pagination properly

  [2, 5, 10, 15, 20].each do |per_page|
    it "returns with the requested #{per_page} records per page" do
      items # force creation
      get :index, params: extra_params.merge('limit' => per_page, parents: parents)

      expect(response_body_data.count).to eq(per_page)
    end

    20.times do |offset|
      it "returns #{per_page} records from the offset #{offset}" do
        nth_items = items[offset..(offset + per_page - 1)].map do |sg|
          hash_including(
            'id' => sg.id,
            'type' => subject.send(:resource).model_name.element,
            'attributes' => a_kind_of(Hash)
          )
        end

        get :index, params: extra_params.merge(
          'limit' => per_page,
          'offset' => offset,
          parents: parents
        )

        expect(response_body_data).to match_array(nth_items)
        expect(response.parsed_body['meta']['limit']).to eq(per_page)
        expect(response.parsed_body['meta']['offset']).to eq(offset)
      end
    end
  end
end
