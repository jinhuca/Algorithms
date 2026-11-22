// Global operator new/delete override that feeds sa::bench::mem's thread-local
// peak-heap counters, so the Analyzer can report an algorithm's peak memory use
// alongside its timing. Linking this TU into the executable is what "turns on"
// sa::bench::mem (it's a no-op API otherwise).
//
// Tracking is gated on sa::bench::mem::tracking (thread-local), which the Analyzer
// sets true only around one untimed measuring run on its worker thread. When false
// (everywhere else, always), this adds just a malloc + a thread-local bool check.
// Block size comes from _msize (Windows) / malloc_usable_size (POSIX). Only the
// non-aligned operators are overridden; over-aligned allocations use the library
// defaults and simply aren't counted (the sorts don't use over-aligned types).

#include <cstddef>
#include <cstdlib>
#include <new>

#include <malloc.h>

#include <sa/bench/bench.hpp>

#if defined(_WIN32)
#  define SA_USABLE(p) _msize(p)
#else
#  define SA_USABLE(p) malloc_usable_size(p)
#endif

namespace {
    inline void* sa_alloc(std::size_t n) {
        void* p = std::malloc(n ? n : 1);
        if (p && sa::bench::mem::tracking) sa::bench::mem::on_alloc(SA_USABLE(p));
        return p;
    }
    inline void sa_free(void* p) noexcept {
        if (!p) return;
        if (sa::bench::mem::tracking) sa::bench::mem::on_free(SA_USABLE(p));
        std::free(p);
    }
}  // namespace

void* operator new(std::size_t n) { void* p = sa_alloc(n); if (!p) throw std::bad_alloc(); return p; }
void* operator new[](std::size_t n) { void* p = sa_alloc(n); if (!p) throw std::bad_alloc(); return p; }
void* operator new(std::size_t n, const std::nothrow_t&) noexcept { return sa_alloc(n); }
void* operator new[](std::size_t n, const std::nothrow_t&) noexcept { return sa_alloc(n); }

void operator delete(void* p) noexcept { sa_free(p); }
void operator delete[](void* p) noexcept { sa_free(p); }
void operator delete(void* p, std::size_t) noexcept { sa_free(p); }
void operator delete[](void* p, std::size_t) noexcept { sa_free(p); }
void operator delete(void* p, const std::nothrow_t&) noexcept { sa_free(p); }
void operator delete[](void* p, const std::nothrow_t&) noexcept { sa_free(p); }
