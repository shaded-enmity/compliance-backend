# frozen_string_literal: true

module V2
  # Model for SCAP policies
  class Policy < ApplicationRecord
    # FIXME: clean up after the remodel
    self.table_name = :v2_policies
    self.primary_key = :id

    belongs_to :profile, class_name: 'V2::Profile'
    has_one :security_guide, through: :profile, class_name: 'V2::SecurityGuide'
    has_many :tailorings, class_name: 'V2::Tailoring', dependent: :destroy
    has_many :tailoring_rules, through: :tailorings, class_name: 'V2::TailoringRule', dependent: :destroy
    has_many :rules, through: :tailoring_rules, class_name: 'V2::Rule'
    has_many :policy_systems, class_name: 'V2::PolicySystem', dependent: :destroy
    has_many :systems, through: :policy_systems, class_name: 'V2::System'
    belongs_to :account, class_name: 'Account'

    validates :account, presence: true
    validates :profile, presence: true
    validates :title, presence: true
    validates :compliance_threshold, numericality: {
      greater_than_or_equal_to: 0, less_than_or_equal_to: 100
    }

    sortable_by :title
    sortable_by :os_major_version, 'security_guide.os_major_version'
    sortable_by :total_system_count
    sortable_by :business_objective
    sortable_by :compliance_threshold

    searchable_by :title, %i[like unlike eq ne in notin]
    searchable_by :os_major_version, %i[eq ne in notin] do |_key, op, val|
      bind = ['IN', 'NOT IN'].include?(op) ? '(?)' : '?'

      {
        conditions: "security_guide.os_major_version #{op} #{bind}",
        parameter: [val.split.map(&:to_i)]
      }
    end
    searchable_by :os_minor_version, %i[eq] do |_key, _op, val|
      # Rails doesn't support composed foreign keys yet, so we have to manually join with `SupportedProfile` using
      # `Profile#ref_id` and `SecurityGuide#os_major_version`.
      supported_profiles = arel_join_fragment(
        arel_table.join(V2::SupportedProfile.arel_table).on(
          V2::SupportedProfile.arel_table[:ref_id].eq(V2::Profile.arel_table.alias(:profile)[:ref_id]).and(
            V2::SupportedProfile.arel_table[:os_major_version].eq(
              V2::SecurityGuide.arel_table.alias(:security_guide)[:os_major_version]
            )
          )
        )
      )

      match_os_minors = Arel::Nodes::NamedFunction.new('ANY', [V2::SupportedProfile.arel_table[:os_minor_versions]])
      ids = V2::Policy.joins(profile: :security_guide).joins(supported_profiles)
                      .where(Arel::Nodes.build_quoted(val).eq(match_os_minors))
                      .reselect(arel_table[:id])

      { conditions: "v2_policies.id IN (#{ids.to_sql})" }
    end

    before_validation :ensure_default_values

    def os_major_version
      attributes['security_guide__os_major_version'] || security_guide.os_major_version
    end

    def profile_title
      attributes['profile__title'] || profile.title
    end

    def ref_id
      attributes['profile__ref_id'] || profile.ref_id
    end

    def os_minor_versions
      V2::SupportedProfile.find_by!(ref_id: ref_id, os_major_version: os_major_version).os_minor_versions
    end

    private

    def ensure_default_values
      self.title ||= profile.title
      self.description ||= profile.description
      self.compliance_threshold ||= 100.0
    end
  end
end
