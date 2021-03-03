# frozen_string_literal: true

# Consumer concerns related to message validation
module Validation
  extend ActiveSupport::Concern

  included do
    def validated_reports(report_contents, metadata)
      report_contents.map do |raw_report|
        begin
          parsed = XccdfReportParser.new(raw_report, metadata)
          test_result = parsed.test_result_file.test_result
        rescue StandardError
          raise InventoryEventsConsumer::ReportValidationError
        end

        [test_result.profile_id, raw_report]
      end
    end

    def validation_payload(request_id, valid:)
      {
        'request_id': request_id,
        'service': 'compliance',
        'validation': valid ? 'success' : 'failure'
      }.to_json
    end

    def notify_payload_tracker(status, status_msg = '')
      PayloadTracker.deliver(
        account: @msg_value['account'], system_id: @msg_value['id'],
        request_id: @msg_value['request_id'], status: status,
        status_msg: status_msg
      )
    end
  end
end
