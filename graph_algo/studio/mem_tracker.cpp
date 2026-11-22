// Global operator new/delete override that feeds ga::bench::mem's thread-local
// peak-heap counters, so the Analyzer can report an algorithm's peak memory use
// alongside its timing. Linking this TU into the executable is what "turns on"
// ga::bench::mem (it's a no-op API otherwise).
//
// Design notes:
//  * Tracking is gated on ga::bench::mem::tracking (thread-local), which the
//    Analyzer sets true only around one untimed measuring run on its worker
//    thread. When false (everywhere else, always), this adds just a malloc + a
//    thread-local bool check — negligible for the rest of the app.
//  * Block size comes from _msize (Windows) / malloc_usable_size (POSIX) — no
//    per-allocation header, so alignment is whatever malloc guarantees.
//  * Only the NON-aligned operators are overridden. Over-aligned types keep using
//    the library's default aligned new/delete (consistently with each other), so
//    there's no mismatch risk — those allocations simply aren't counted, which is
//    fine since the graph algorithms don't use over-aligned types.

#include <cstddef>
#include <cstdlib>
#include <new>

#include <malloc.h>

#include <ga/bench/bench.hpp>

#if defined(_WIN32)
#  define GA_USABLE(p) _msize(p)
#else
#  define GA_USABLE(p) malloc_usable_size(p)
#endif

namespace {
    inline void* ga_alloc(std::size_t n) {
        void* p = std::malloc(n ? n : 1);
        if (p && ga::bench::mem::tracking) ga::bench::mem::on_alloc(GA_USABLE(p));
        return p;
    }
    inline void ga_free(void* p) noexcept {
        if (!p) return;
        if (ga::bench::mem::tracking) ga::bench::mem::on_free(GA_USABLE(p));
        std::free(p);
    }
}  // namespace

void* operator new(std::size_t n) { void* p = ga_alloc(n); if (!p) throw std::bad_alloc(); return p; }
void* operator new[](std::size_t n) { void* p = ga_alloc(n); if (!p) throw std::bad_alloc(); return p; }
void* operator new(std::size_t n, const std::nothrow_t&) noexcept { return ga_alloc(n); }
void* operator new[](std::size_t n, const std::nothrow_t&) noexcept { return ga_alloc(n); }

void operator delete(void* p) noexcept { ga_free(p); }
void operator delete[](void* p) noexcept { ga_free(p); }
void operator delete(void* p, std::size_t) noexcept { ga_free(p); }
void operator delete[](void* p, std::size_t) noexcept { ga_free(p); }
void operator delete(void* p, const std::nothrow_t&) noexcept { ga_free(p); }
void operator delete[](void* p, const std::nothrow_t&) noexcept { ga_free(p); }
