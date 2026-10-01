#ifndef BW_SHA1_COMPAT_H
#define BW_SHA1_COMPAT_H

// SHA-1 for the disc ID and executable checks. Apple has CommonCrypto; other
// platforms use the small public-domain implementation below so the extractor
// stays dependency-free.

#ifdef __APPLE__
#include <CommonCrypto/CommonDigest.h>
#else
#include <stdint.h>
#include <stddef.h>
#include <string.h>

#define CC_SHA1_DIGEST_LENGTH 20

static uint32_t bw_sha1_rotl(uint32_t x, int n) {
    return (x << n) | (x >> (32 - n));
}

static void bw_sha1_block(uint32_t h[5], const uint8_t block[64]) {
    uint32_t w[80];
    for (int i = 0; i < 16; ++i)
        w[i] = ((uint32_t)block[i * 4] << 24) | ((uint32_t)block[i * 4 + 1] << 16) |
               ((uint32_t)block[i * 4 + 2] << 8) | block[i * 4 + 3];
    for (int i = 16; i < 80; ++i)
        w[i] = bw_sha1_rotl(w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16], 1);

    uint32_t a = h[0], b = h[1], c = h[2], d = h[3], e = h[4];
    for (int i = 0; i < 80; ++i) {
        uint32_t f, k;
        if (i < 20) {
            f = (b & c) | ((~b) & d);
            k = 0x5A827999;
        } else if (i < 40) {
            f = b ^ c ^ d;
            k = 0x6ED9EBA1;
        } else if (i < 60) {
            f = (b & c) | (b & d) | (c & d);
            k = 0x8F1BBCDC;
        } else {
            f = b ^ c ^ d;
            k = 0xCA62C1D6;
        }
        uint32_t t = bw_sha1_rotl(a, 5) + f + e + k + w[i];
        e = d;
        d = c;
        c = bw_sha1_rotl(b, 30);
        b = a;
        a = t;
    }
    h[0] += a;
    h[1] += b;
    h[2] += c;
    h[3] += d;
    h[4] += e;
}

static void bw_sha1(const uint8_t* data, size_t size, uint8_t digest[20]) {
    uint32_t h[5] = {0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0};
    const size_t full = size & ~(size_t)63;
    for (size_t i = 0; i < full; i += 64)
        bw_sha1_block(h, data + i);

    uint8_t tail[128];
    size_t rest = size - full;
    memcpy(tail, data + full, rest);
    tail[rest++] = 0x80;
    const size_t blocks = (rest <= 56) ? 1 : 2;
    memset(tail + rest, 0, blocks * 64 - rest);
    const uint64_t bits = (uint64_t)size * 8;
    for (int i = 0; i < 8; ++i)
        tail[blocks * 64 - 1 - i] = (uint8_t)(bits >> (8 * i));
    bw_sha1_block(h, tail);
    if (blocks == 2)
        bw_sha1_block(h, tail + 64);

    for (int i = 0; i < 5; ++i) {
        digest[i * 4] = (uint8_t)(h[i] >> 24);
        digest[i * 4 + 1] = (uint8_t)(h[i] >> 16);
        digest[i * 4 + 2] = (uint8_t)(h[i] >> 8);
        digest[i * 4 + 3] = (uint8_t)h[i];
    }
}

// The extractor's only CommonCrypto call, kept at the same call site.
#define CC_SHA1(data, len, md) bw_sha1((const uint8_t*)(data), (size_t)(len), (md))
#endif

#endif
