/* S.T.U.N. Runner HD60 launcher: sets the overclock, HD redraw + data folder, then starts bin\stun60.exe.
   HD backgrounds: built from the ROM on first launch by stun60.exe in the background with bin\realesrgan\ (Vulkan),
   kept in data\hdpack. STUN60_HD= (empty) starts without the HD screen.
   Layout: STUNRunner60.exe, bin\stun60.exe, bin\stunrun-interp60.lua, bin\bgfx\ (shaders), bin\artwork\bgfx\ (CRT textures),
   roms\stunrun.zip (or stunrun.zip next to the exe), data\ (created: log, overlay setting, cfg, nvram = high scores, snapshots).
   Screen effect: C cycles CRT deluxe / CRT sharp / off in-game (saved in data\cfg\stunrun.cfg); the first launch uses CRT
   deluxe. STUN60_CRT=deluxe|geom|off forces one. */
#include <windows.h>
#include <stdio.h>
#include <wchar.h>
#include <string.h>
static int exists(const wchar_t *p) { return GetFileAttributesW(p) != INVALID_FILE_ATTRIBUTES; }
static int file_has(const wchar_t *path, const char *needle)
{
    FILE *f = _wfopen(path, L"rb"); if (!f) return 0;
    static char buf[65536]; size_t n = fread(buf, 1, sizeof buf - 1, f); fclose(f); buf[n] = 0;
    return strstr(buf, needle) != NULL;
}
int WINAPI wWinMain(HINSTANCE h, HINSTANCE p, LPWSTR args, int show)
{
    wchar_t dir[MAX_PATH], tmp[MAX_PATH], data[MAX_PATH], exe[MAX_PATH], cmd[8192];
    GetModuleFileNameW(NULL, dir, MAX_PATH);
    wchar_t *s = wcsrchr(dir, L'\\'); if (s) *s = 0;
    swprintf(data, MAX_PATH, L"%ls\\data", dir);
    CreateDirectoryW(data, NULL);
    const wchar_t *sub[] = { L"cfg", L"nvram", L"snap" };
    for (int i = 0; i < 3; i++) { swprintf(tmp, MAX_PATH, L"%ls\\%ls", data, sub[i]); CreateDirectoryW(tmp, NULL); }
    int found = 0;
    const wchar_t *rp[] = { L"%ls\\stunrun.zip", L"%ls\\roms\\stunrun.zip", L"%ls\\stunrun", L"%ls\\roms\\stunrun" };
    for (int i = 0; i < 4; i++) { swprintf(tmp, MAX_PATH, rp[i], dir); if (exists(tmp)) found = 1; }
    if (!found) {
        MessageBoxW(NULL, L"stunrun.zip not found.\n\nPut it next to STUNRunnerHD60.exe or in the roms folder.",
                    L"S.T.U.N. Runner HD60", MB_ICONERROR);
        return 1;
    }
    if (!GetEnvironmentVariableW(L"STUN60_CLOCK", tmp, MAX_PATH))
        SetEnvironmentVariableW(L"STUN60_CLOCK", L"maincpu=3,gsp=4,adsp=8");
    SetEnvironmentVariableW(L"STUN60_DATA", data);
    /* defaults only when not set (an empty STUN60_HD means: no HD screen) */
    if (!GetEnvironmentVariableW(L"STUN60_HD", tmp, MAX_PATH) && GetLastError() == ERROR_ENVVAR_NOT_FOUND)
        SetEnvironmentVariableW(L"STUN60_HD", L"3x5");
    if (!GetEnvironmentVariableW(L"STUN60_HDPACK", tmp, MAX_PATH)) {
        swprintf(tmp, MAX_PATH, L"%ls\\hdpack", data); SetEnvironmentVariableW(L"STUN60_HDPACK", tmp);
    }
    if (!GetEnvironmentVariableW(L"STUN60_ESRGAN", tmp, MAX_PATH)) {
        swprintf(tmp, MAX_PATH, L"%ls\\bin\\realesrgan\\realesrgan-ncnn-vulkan.exe", dir); SetEnvironmentVariableW(L"STUN60_ESRGAN", tmp);
    }
    swprintf(exe, MAX_PATH, L"%ls\\bin\\stun60.exe", dir);
    const wchar_t *chain = L"";
    wchar_t crt[32] = L"";
    GetEnvironmentVariableW(L"STUN60_CRT", crt, 32);
    swprintf(tmp, MAX_PATH, L"%ls\\cfg\\stunrun.cfg", data);
    if (!wcscmp(crt, L"deluxe")) chain = L"-bgfx_screen_chains crt-geom-deluxe ";
    else if (!wcscmp(crt, L"geom")) chain = L"-bgfx_screen_chains crt-geom ";
    else if (!wcscmp(crt, L"off")) chain = L"-bgfx_screen_chains default ";
    else if (!file_has(tmp, "chain=")) chain = L"-bgfx_screen_chains crt-geom-deluxe ";
    swprintf(cmd, 8192,
        L"\"%ls\" stunrun -inipath \"%ls\" -rompath \"%ls;%ls\\roms\" -cfg_directory \"%ls\\cfg\" "
        L"-nvram_directory \"%ls\\nvram\" -snapshot_directory \"%ls\\snap\" -skip_gameinfo "
        L"-video bgfx -bgfx_path \"%ls\\bin\\bgfx\" -artpath \"%ls\\artwork;%ls\\bin\\artwork\" %ls"
        L"-sound portaudio -audio_latency 3 -autoboot_script \"%ls\\bin\\stunrun-interp60.lua\" %ls",
        exe, data, dir, dir, data, data, data, dir, data, dir, chain, dir, args ? args : L"");
    STARTUPINFOW si = { sizeof si }; PROCESS_INFORMATION pi;
    if (!CreateProcessW(exe, cmd, NULL, NULL, FALSE, 0, NULL, data, &si, &pi)) {
        MessageBoxW(NULL, L"Could not start bin\\stun60.exe.", L"S.T.U.N. Runner HD60", MB_ICONERROR);
        return 1;
    }
    CloseHandle(pi.hThread); CloseHandle(pi.hProcess);
    return 0;
}
