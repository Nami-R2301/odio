package odio;

import libc "core:c/libc"
import "core:fmt"
import mem "core:mem"
import os "core:os"
import str "core:strings"
import ma "vendor:miniaudio"

engine : ma.engine = { };

main :: proc() {
    if len(os.args) < 2 {
        fmt.fprintln(os.stderr, "Error: No input file provided");
        return;
    }

    // Get the sound file to read from. Currently as of 2025, Miniaudio supports WAV, FLAC and MP3.
    sound_file := str.unsafe_string_to_cstring(os.args[1]);

    result : ma.result = init_audio();
    assert(result == ma.result.SUCCESS, "[App]\t\t[%s]:\tError: Cannot initialize audio device", #location());

    defer defer_audio();

    sound: ma.sound;
    sound_flags : ma.sound_flags = { ma.sound_flag.NO_SPATIALIZATION };

    fmt.printf("[App]\t\t[%s]:\tReading from input file...", #location());
    result = ma.sound_init_from_file(&engine, sound_file, sound_flags, nil, nil, &sound);
    if (result != ma.result.SUCCESS) {
        fmt.fprintfln(os.stderr, "[App]\t\t[%s]:\tError: Cannot read from input sound file: %s", #location(), result);
        return;
    }
    fmt.println("done");

    // Lower volume to 35% since it is quite loud usually.
    ma.sound_set_volume(&sound, 0.35);

    fmt.printf("[App]\t\t[%s]:\tPlaying %s...", #location(), sound_file);

    // Fade in over 1 second.
    ma.sound_set_fade_in_milliseconds(&sound, 0, 1, 1000);

    ma.sound_start(&sound);
    get_total_time : f32;
    get_current_time : u64;

    ma.sound_get_length_in_seconds(&sound, &get_total_time);
    if result != ma.result.SUCCESS {
        fmt.fprintfln(os.stderr, "[Miniaudio]\t[%s]:\tError: Cannot get total track time: %s", #location(), result);
        return;
    }

    for !sound.atEnd {
        get_current_time = ma.sound_get_time_in_milliseconds(&sound);
        current_time_f32: f32 = f32 (get_current_time);

        // If the current track time is around 2 seconds before the end, fade out.
        if current_time_f32 / 1000.0 >= get_total_time - 2 {
            // Fade out over 1 second.
            ma.sound_set_fade_in_milliseconds(&sound, -1, 0, 1000);
        }
    }

    fmt.println("done");
    fmt.printfln("[App]\t\t[%s]:\tReached end of file input, bye bye...", #location());
}

init_audio :: proc() -> ma.result {
    if engine.pDevice != nil {
        return ma.result.ALREADY_EXISTS;
    }

    ctx : ma.context_type = { };

    fmt.printf("[Miniaudio]\t[%s]:\tInitializing audio context... ", #location());
    result := ma.context_init(nil, 0, nil, &ctx);
    if result != ma.result.SUCCESS {
        fmt.fprintfln(os.stderr, "\n[Miniaudio]\t[%s]:\tError when initializing audio context: [%d]", #location(), result);
        return result;
    }
    fmt.println("done");

    fmt.printfln("[Miniaudio]\t[%s]:\tChecking available devices... ", #location());
    pPlaybackInfos: [^]ma.device_info;
    playbackCount: u32;
    pCaptureInfos: [^]ma.device_info;
    captureCount: u32;
    if ma.context_get_devices(&ctx, &pPlaybackInfos, &playbackCount, &pCaptureInfos, &captureCount) != ma.result.SUCCESS {
        fmt.fprintfln(os.stderr, "\n[Miniaudio]\t[%s]:\tError when initializing audio device: [%d]", #location(), result);
        return result;
    }

    fmt.printfln("[Miniaudio]\t[%s]:\tAvailable playback device count: %d", #location(), playbackCount);
    fmt.printfln("[Miniaudio]\t[%s]:\tAvailable capture device count: %d", #location(), captureCount);

    // Loop over each device info and do something with it. Here we just print the name with their index. You may want
    // to give the user the opportunity to choose which device they'd prefer.
    for iDevice : u32 = 0; iDevice < playbackCount; iDevice += 1 {
        res, error := str.clone_from_bytes(pPlaybackInfos[iDevice].name[:]);
        if error != mem.Allocator_Error.None {
            fmt.fprintfln(os.stderr, "[Miniaudio]\t[%s]:\tError when getting device name: [%d]", #location(), result);
            return result;
        }
        to_cstr := str.unsafe_string_to_cstring(res);
        fmt.printfln("[Miniaudio]\t[%s]:\tPlayback device: %d - %s", #location(), iDevice, to_cstr);
    }

    fmt.printf("[Miniaudio]\t[%s]:\tInitializing audio engine... ", #location());
    config := ma.engine_config_init();
    config.channels = 2;
    config.sampleRate = 48000;
    config.dataCallback = proc "c" (pDevice: ^ma.device, pOutput, pInput: rawptr, frameCount: u32) {
        libc.printf("[Miniaudio]\t[%s]:\t\t\tData Callback: Device [%p], Input: %p, Framecount: %d\n",
        #location(), pDevice, pInput, frameCount);
        libc.fflush(libc.stdout);
    }

    result = ma.engine_init(nil, &engine);
    if result != ma.result.SUCCESS {
        fmt.fprintfln(os.stderr, "\n[Miniaudio]\t[%s]:\tError when initializing audio engine: [%d]", #location(), result);
        return result;  // Failed to initialize the engine.
    }
    fmt.println("done");

    return ma.result.SUCCESS;
}

defer_audio :: proc() -> ma.result {
    if engine.pDevice == nil {
        return ma.result.DOES_NOT_EXIST;
    }

    fmt.printf("[Miniaudio]\t[%4s]:\tDestroying audio device... ", #location());
    ma.engine_uninit(&engine);
    fmt.println("done");


    return ma.result.SUCCESS;
}