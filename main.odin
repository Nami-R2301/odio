package odio;

import "core:fmt";
import ma "vendor:miniaudio";
import libc "core:c/libc";

my_device: ma.device = {};

main :: proc() {
    defer {
        defer_audio();
    }

    result : ma.result = init_audio();
    assert(result == ma.result.SUCCESS, "[App]\t\t[main:12]:\tCannot initialize audio device");
}

init_audio :: proc() -> ma.result {
    if (my_device.pUserData != nil) {
        return ma.result.ALREADY_EXISTS;
    }
    fmt.printf("[Miniaudio]\t[%s]:\tInitializing audio device... ", #location());
    device_config := ma.device_config_init(ma.device_type.playback);
    device_config.playback.format = ma.format.unknown;
    device_config.sampleRate = 48000;
    device_config.performanceProfile = ma.performance_profile.low_latency;
    device_config.dataCallback = proc "c" (pDevice: ^ma.device, pOutput, pInput: rawptr, frameCount: u32) {
        libc.printf("[Miniaudio]\t[%s]:\tData Callback: Device [%p], Input: %p, Framecount: %d\n",
        pDevice, pInput, frameCount);
        libc.fflush(libc.stdout);
    }

    result : ma.result = ma.device_init(nil, &device_config, &my_device);
    if (result != ma.result.SUCCESS) {
        fmt.printfln("\n[Miniaudio]\t[%s]:\tError when initializing audio device: [%d]", #location(), result);
        return result;
    }
    fmt.println("done");


    return ma.result.SUCCESS;
}

defer_audio :: proc() {
    if (my_device.pUserData == nil) {
        return;
    }
    ma.device_stop(&my_device);
    fmt.printf("[Miniaudio]\t[%4s]:\tDestroying audio device... ", #location());
    fmt.println("done");
}