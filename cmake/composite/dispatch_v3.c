/* BlueWake composite module export glue: the x86-64-v3 dispatch twin.
 *
 * The generated dispatcher (dolrecomp_call and everything it calls) is static
 * in generated_composite.h, so this translation unit includes it a second time
 * with the entry point renamed and the file compiled for x86-64-v3 (AVX2, FMA,
 * BMI, MOVBE, LZCNT; set in CMakeLists.txt). module_export.c probes the host
 * CPU at runtime and picks this copy when it is safe; the base build serves
 * every other x86-64 CPU. The Windows build wires the same twin through its
 * own build files.
 *
 * Everything the generated header holds is static, so this TU runs on its own
 * copies of the chunk tables, the pc cache and the mod state. Mods have to
 * reach them exactly as they reach the base TU's copies: the twin hooks below
 * (bluewake_composite_apply_mods_v3, called by module_export.c under
 * BLUEWAKE_COMPOSITE_DISPATCH_V3) apply the same mask once, at boot, before
 * any dispatch fills a pc cache. The mod logic mirrors module_export.c:
 * keep the two in sync.
 */
#define dolrecomp_call bluewake_dispatch_v3
#include "generated_composite.h"
#include "StaticRecompABI.h"
#include "dispatch_loop.h"

/* The mod tables (generated at mods time into mod_tables.inc) give this TU
 * its own static copies of the variant tables. Without mods the file does not
 * exist and MODULE_MOD_COUNT reads as 0 in the guards below. */
#if defined(__has_include)
#if __has_include("mod_tables.inc")
#include "mod_tables.inc"
#endif
#endif
static u32 s_mod_enabled_mask;

static DolRecompFunction bluewake_mod_extra_find(u32 address)
{
#if defined(MODULE_MOD_COUNT) && MODULE_MOD_COUNT > 0
    for (u32 i = 0; i < MODULE_MOD_EXTRA_CHUNK_COUNT; ++i) {
        const BlueWakeModExtraChunk* c = &s_mod_extra_chunks[i];
        if ((s_mod_enabled_mask & (1u << c->mod)) != 0u && c->start <= address &&
            address < c->end && ((address - c->start) & 3u) == 0u)
            return c->fn;
    }
#else
    (void)address;
#endif
    return NULL;
}

u32 bluewake_composite_apply_mods_v3(u32 mask)
{
    u32 replaced = 0;
    s_mod_enabled_mask = mask;
#if defined(MODULE_MOD_COUNT) && MODULE_MOD_COUNT > 0
    for (u32 i = 0; i < MODULE_MOD_CHUNK_COUNT; ++i) {
        const BlueWakeModChunk* c = &s_mod_chunks[i];
        if ((mask & c->mask) != c->mask)
            continue;
        for (u32 k = 0; k < DOLRECOMP_CHUNK_COUNT; ++k) {
            if (s_dolrecomp_chunk_starts[k] == c->start) {
                s_dolrecomp_chunk_fns[k] = c->fn;
                replaced++;
                break;
            }
        }
    }
#else
    (void)mask;
#endif
    return replaced;
}

int dolrecomp_call__x86_64_v3(CPUState* ctx, u32 address) {
    return bluewake_dispatch_v3(ctx, address);
}
