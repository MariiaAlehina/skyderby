class Event < ApplicationRecord
  class Result < ApplicationRecord
    class Submission
      include ActiveModel::Model
      extend ActiveModel::Naming

      attr_reader :result, :errors

      attr_accessor :event_id,
                    :competitor_id,
                    :competitor_name,
                    :round_id,
                    :round_name,
                    :penalized,
                    :penalty_size,
                    :penalty_reason,
                    :track_attributes,
                    :jump_range,
                    :reference_point_name,
                    :reference_point_coordinates

      validates :competitor, :round, presence: true
      validates :penalty_size, presence: true, if: :penalized

      def initialize(args)
        super

        @errors = ActiveModel::Errors.new(self)
      end

      def save
        return false unless valid?

        Event::Result.transaction do
          create_result
          set_jump_range
          assign_reference_point
        end

        result
      end

      private

      def create_result
        @result = event.results.new result_params
        @result.save!
      end

      def set_jump_range
        return if exit_time.blank? || deploy_time.blank?

        points = PointsQuery.execute(result.track, only: %i[gps_time fl_time])

        relative_exit_time   = points.bsearch { |p| p['gps_time'] >= exit_time }[:fl_time]
        relative_deploy_time = points.bsearch { |p| p['gps_time'] >= deploy_time }[:fl_time]

        @result.track.update! ff_start: relative_exit_time, ff_end: relative_deploy_time
      end

      def assign_reference_point
        return unless reference_point

        round.reference_point_assignments.create \
          competitor: competitor,
          reference_point: reference_point
      end

      def result_params
        {
          competitor: competitor,
          round: round,
          penalized: penalized,
          penalty_size: penalty_size,
          penalty_reason: penalty_reason,
          track_attributes: track_attributes,
          track_from: 'from_file'
        }
      end

      def competitor
        @competitor ||= event.competitors.find_by(id: competitor_id) || competitor_by_name
      end

      def round
        @round ||= event.rounds.find_by(id: round_id) ||
                   event.rounds.find_by(discipline: round_task, number: round_number)
      end

      def event
        @event ||= Event.find(event_id)
      end

      def competitor_by_name
        event.competitors.joins(:profile).where('LOWER(profiles.name) = ?', competitor_name).first
      end

      def competitor_name
        @competitor_name.to_s.strip.downcase
      end

      def round_task
        Event::Round.disciplines[round_name.split('-')[0].downcase]
      end

      def round_number
        round_name.split('-')[1]
      end

      def reference_point
        @reference_point ||= find_or_create_reference_point
      end

      def find_or_create_reference_point
        if reference_point_name.present? && reference_point_coordinates.blank?
          event.reference_points.find_by(name: reference_point_name)
        elsif reference_point_name.present? && reference_point_coordinates.present?
          latitude, longitude = reference_point_coordinates.split(',')

          event.reference_points.find_or_create_by \
            name: reference_point_name,
            latitude: latitude.to_s.strip,
            longitude: longitude.to_s.strip
        end
      end

      def exit_time
        return unless jump_range[:exit_time]

        Time.strptime(jump_range[:exit_time], '%Y-%m-%dT%H:%M:%S.%L %Z')
      end

      def deploy_time
        return unless jump_range[:deploy_time]

        Time.strptime(jump_range[:deploy_time], '%Y-%m-%dT%H:%M:%S.%L %Z')
      end

      def jump_range
        @jump_range || {}
      end

      def penalized
        @penalized.to_s.downcase == 'true'
      end
    end
  end
end
