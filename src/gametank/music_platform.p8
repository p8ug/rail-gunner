; Rail Gunner music for the GameTank: the SDK's tracker player and its song.
%import gametank
%import songdata

music {
    %option overlay_data

    ; target.boot() started the player
    sub init() {
    }

    sub start() {
        gametank.play_song(&songdata.song, banks.ASSETS, gametank.REPEAT_LOOP)
    }

    sub stop() {
        gametank.stop_music()
    }

    ; Once every frame, always: the sound effects need it as well.
    sub tick() {
        gametank.tick_music()
    }
}
