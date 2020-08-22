# rubocop:disable Naming/AccessorMethodName
module LexisNexisFixtures
  def self.get_results_response_success
    load_response_fixture('get_results_response_success.json')
  end

  def self.get_results_response_failure
    load_response_fixture('get_results_response_failure.json')
  end

  def self.load_response_fixture(filename)
    path = File.join(
      File.dirname(__FILE__),
      '../fixtures/lexis_nexis_responses',
      filename,
    )
    File.read(path)
  end
end
# rubocop:enable Naming/AccessorMethodName
