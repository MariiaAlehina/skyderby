module Api
  class EventTracksController < ApplicationController
    before_action :set_event_track, only: [:update, :destroy]

    def create
      @event_track = EventTrack.new event_track_params
      @event_track.create_track!(event_track_params[:track_attributes]) unless @event_track.track_id

      if @event_track.save
        @event_track
      else
        render json: @event_track.errors, status: :unprocessible_entry
      end
    end

    def update
      @event_track.update round_track_params
      respond_with @event_track
    end

    def destroy
      @event_track.destroy
      head :no_content
    end

    private

    def set_event_track
      @event_track = EventTrack.find(params[:id])
    end

    def event_track_params
      params.require(:event_track).permit(
        :competitor_id, :round_id, :track_id,
        track_attributes: [:file, :user_profile_id, :place_id, :wingsuit_id])
    end
  end
end