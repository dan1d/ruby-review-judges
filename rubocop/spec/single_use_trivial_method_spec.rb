# frozen_string_literal: true

require "rubocop"
require "rubocop/rspec/support"
require_relative "../lib/rubocop/cop/review/single_use_trivial_method"

RSpec.describe RuboCop::Cop::Review::SingleUseTrivialMethod do
  include RuboCop::RSpec::ExpectOffense

  subject(:cop) { RuboCop::Cop::Review::SingleUseTrivialMethod.new }

  it "flags a private single-expression method called from exactly one site" do
    expect_offense(<<~RUBY)
      class ReportBuilder
        def call
          build_summary
        end

        private

        def build_summary
            ^^^^^^^^^^^^^ Review/SingleUseTrivialMethod: Avoid a needless wrapper method: `build_summary` has a trivial, single-expression body and is only called from one place — inline it at its call site instead. [auto-fixable]
          report.summary_text
        end
      end
    RUBY
  end

  it "does not flag a private method called from two sites" do
    expect_no_offenses(<<~RUBY)
      class ReportBuilder
        def call
          build_summary
        end

        def retry_call
          build_summary
        end

        private

        def build_summary
          report.summary_text
        end
      end
    RUBY
  end

  it "does not flag a private method whose body branches" do
    expect_no_offenses(<<~RUBY)
      class ReportBuilder
        def call
          build_summary
        end

        private

        def build_summary
          report.present? ? report.summary_text : "N/A"
        end
      end
    RUBY
  end

  it "does not flag a private method with a multi-statement body" do
    expect_no_offenses(<<~RUBY)
      class ReportBuilder
        def call
          build_summary
        end

        private

        def build_summary
          report.reload
          report.summary_text
        end
      end
    RUBY
  end

  it "counts an explicit self-call as a second call site" do
    expect_no_offenses(<<~RUBY)
      class ReportBuilder
        def call
          build_summary
        end

        def retry_call
          self.build_summary
        end

        private

        def build_summary
          report.summary_text
        end
      end
    RUBY
  end

  it "does not flag a public method, even if trivial and single-use" do
    expect_no_offenses(<<~RUBY)
      class ReportBuilder
        def call
          build_summary
        end

        def build_summary
          report.summary_text
        end
      end
    RUBY
  end

  it "does not flag a memoized ivar reader" do
    expect_no_offenses(<<~RUBY)
      class ReportBuilder
        def call
          patient
        end

        private

        def patient
          @patient ||= Patient.find(@patient_id)
        end
      end
    RUBY
  end

  it "does not flag a strong-parameters method" do
    expect_no_offenses(<<~RUBY)
      class ReportsController
        def call
          report_params
        end

        private

        def report_params
          params.require(:report).permit(:a, :b)
        end
      end
    RUBY
  end

  it "does not flag a strong-parameters method using permit!" do
    expect_no_offenses(<<~RUBY)
      class FormsController
        def call
          form_params
        end

        private

        def form_params
          params.require(:response).permit!
        end
      end
    RUBY
  end

  it "does not flag a single-caller method with a long chain body" do
    expect_no_offenses(<<~RUBY)
      class ReportBuilder
        def call
          reports_sql
        end

        private

        def reports_sql
          reports
            .joins("a")
            .joins("b")
            .joins("c")
            .joins("d")
            .select("e")
        end
      end
    RUBY
  end

  it "does not flag a body with an embedded block containing branching" do
    expect_no_offenses(<<~RUBY)
      class ReportBuilder
        def call
          scoped_reports
        end

        private

        def scoped_reports
          reports.where(active: true).then { |scope| filter? ? scope.filtered : scope }
        end
      end
    RUBY
  end

  it "does not treat indexed params plus a comparison as a complex chain" do
    expect_offense(<<~RUBY)
      class ReportBuilder
        def call
          include_form?
        end

        private

        def include_form?
            ^^^^^^^^^^^^^ Review/SingleUseTrivialMethod: Avoid a needless wrapper method: `include_form?` has a trivial, single-expression body and is only called from one place — inline it at its call site instead. [auto-fixable]
          params[:include_form] && params[:include_form] == "true"
        end
      end
    RUBY
  end

  it "does not treat an interpolation of indexed params as a complex chain" do
    expect_offense(<<~RUBY)
      class ReportBuilder
        def call
          code_id
        end

        private

        def code_id
            ^^^^^^^ Review/SingleUseTrivialMethod: Avoid a needless wrapper method: `code_id` has a trivial, single-expression body and is only called from one place — inline it at its call site instead. [auto-fixable]
          "\#{params['id']}.\#{params['format']}"
        end
      end
    RUBY
  end
end
