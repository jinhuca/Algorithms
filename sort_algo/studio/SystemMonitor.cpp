#include "SystemMonitor.h"

#if defined(_WIN32)
#  ifndef NOMINMAX
#    define NOMINMAX
#  endif
#  ifndef WIN32_LEAN_AND_MEAN
#    define WIN32_LEAN_AND_MEAN
#  endif
#  include <windows.h>
#  include <psapi.h>
#  include <pdh.h>
#  include <pdhmsg.h>
#  include <QHash>
#  include <QString>
#  include <algorithm>
#endif

namespace sa::studio {

namespace {
#if defined(_WIN32)
    inline quint64 toU64(const FILETIME& f) {
        return (static_cast<quint64>(f.dwHighDateTime) << 32) | f.dwLowDateTime;
    }
    inline quint64 nowFiletime() {
        FILETIME ft;
        GetSystemTimeAsFileTime(&ft);   // 100-ns ticks since 1601 — only deltas matter
        return toU64(ft);
    }
#endif
}

SystemMonitor::SystemMonitor(QObject* parent) : QObject(parent) {
    m_timer.setInterval(1000);
    m_timer.setSingleShot(false);
    connect(&m_timer, &QTimer::timeout, this, &SystemMonitor::tick);
#if defined(_WIN32)
    SYSTEM_INFO si;
    GetSystemInfo(&si);
    m_cores = si.dwNumberOfProcessors > 0 ? static_cast<int>(si.dwNumberOfProcessors) : 1;

    // Whole-GPU utilisation via PDH's GPU-engine counters (Windows 10+). Best-effort:
    // if the query or counter can't be created (no GPU, headless, older OS), m_gpu
    // stays -1 and the UI hides the GPU row.
    PDH_HQUERY q = nullptr;
    if (PdhOpenQueryW(nullptr, 0, &q) == ERROR_SUCCESS) {
        PDH_HCOUNTER c = nullptr;
        if (PdhAddEnglishCounterW(q, L"\\GPU Engine(*)\\Utilization Percentage", 0, &c) == ERROR_SUCCESS) {
            PdhCollectQueryData(q);     // prime
            m_pdhQuery = q;
            m_pdhGpu = c;
        } else {
            PdhCloseQuery(q);
        }
    }
#endif
}

SystemMonitor::~SystemMonitor() {
#if defined(_WIN32)
    if (m_pdhQuery) PdhCloseQuery(static_cast<PDH_HQUERY>(m_pdhQuery));
#endif
}

void SystemMonitor::setActive(bool on) {
    if (on == m_active) return;
    m_active = on;
    if (on) { prime(); m_timer.start(); tick(); }   // immediate first reading
    else m_timer.stop();
    emit activeChanged();
}

void SystemMonitor::prime() {
#if defined(_WIN32)
    FILETIME idle, kernel, user;
    if (GetSystemTimes(&idle, &kernel, &user)) {
        m_prevIdle = toU64(idle); m_prevKernel = toU64(kernel); m_prevUser = toU64(user);
    }
    FILETIME c, e, pk, pu;
    if (GetProcessTimes(GetCurrentProcess(), &c, &e, &pk, &pu))
        m_prevProcCpu = toU64(pk) + toU64(pu);
    m_prevWall = nowFiletime();
#endif
}

void SystemMonitor::tick() {
#if defined(_WIN32)
    // ---- system CPU: busy fraction of total over the interval ----
    FILETIME idle, kernel, user;
    if (GetSystemTimes(&idle, &kernel, &user)) {
        const quint64 i = toU64(idle), k = toU64(kernel), u = toU64(user);
        const quint64 dIdle = i - m_prevIdle;
        const quint64 dKernel = k - m_prevKernel;   // kernel includes idle
        const quint64 dUser = u - m_prevUser;
        const quint64 total = dKernel + dUser;
        if (total > 0)
            m_cpu = 100.0 * static_cast<double>(total - dIdle) / static_cast<double>(total);
        m_prevIdle = i; m_prevKernel = k; m_prevUser = u;
    }

    // ---- system RAM ----
    MEMORYSTATUSEX ms; ms.dwLength = sizeof(ms);
    if (GlobalMemoryStatusEx(&ms)) {
        m_mem = static_cast<double>(ms.dwMemoryLoad);
        const double gb = 1024.0 * 1024.0 * 1024.0;
        m_memTotalGb = static_cast<double>(ms.ullTotalPhys) / gb;
        m_memUsedGb = static_cast<double>(ms.ullTotalPhys - ms.ullAvailPhys) / gb;
    }

    // ---- process CPU (normalised to whole-machine capacity) + working set ----
    const quint64 wall = nowFiletime();
    const quint64 dWall = wall - m_prevWall;
    FILETIME c, e, pk, pu;
    if (GetProcessTimes(GetCurrentProcess(), &c, &e, &pk, &pu)) {
        const quint64 procCpu = toU64(pk) + toU64(pu);
        const quint64 dProc = procCpu - m_prevProcCpu;
        if (dWall > 0 && m_cores > 0) {
            double pct = 100.0 * static_cast<double>(dProc)
                         / (static_cast<double>(dWall) * m_cores);
            if (pct < 0.0) pct = 0.0;
            if (pct > 100.0) pct = 100.0;   // clamp quantisation overshoot
            m_procCpu = pct;
        }
        m_prevProcCpu = procCpu;
    }
    m_prevWall = wall;

    PROCESS_MEMORY_COUNTERS pmc;
    if (GetProcessMemoryInfo(GetCurrentProcess(), &pmc, sizeof(pmc)))
        m_procMemMb = static_cast<double>(pmc.WorkingSetSize) / (1024.0 * 1024.0);

    // ---- whole-GPU utilisation: sum engine instances per engine type, take the max
    //      type (≤100, matches Task Manager's headline GPU %) ----
    if (m_pdhQuery && m_pdhGpu) {
        auto query = static_cast<PDH_HQUERY>(m_pdhQuery);
        auto counter = static_cast<PDH_HCOUNTER>(m_pdhGpu);
        if (PdhCollectQueryData(query) == ERROR_SUCCESS) {
            DWORD size = 0, count = 0;
            if (PdhGetFormattedCounterArrayW(counter, PDH_FMT_DOUBLE, &size, &count, nullptr)
                    == PDH_MORE_DATA && size > 0) {
                QByteArray buf(static_cast<int>(size), Qt::Uninitialized);
                auto* items = reinterpret_cast<PDH_FMT_COUNTERVALUE_ITEM_W*>(buf.data());
                if (PdhGetFormattedCounterArrayW(counter, PDH_FMT_DOUBLE, &size, &count, items)
                        == ERROR_SUCCESS) {
                    QHash<QString, double> byType;
                    for (DWORD i = 0; i < count; ++i) {
                        if (items[i].FmtValue.CStatus != PDH_CSTATUS_VALID_DATA
                            && items[i].FmtValue.CStatus != PDH_CSTATUS_NEW_DATA) continue;
                        const QString name = QString::fromWCharArray(items[i].szName);
                        const int p = name.indexOf(QStringLiteral("engtype_"));
                        const QString type = p >= 0 ? name.mid(p + 8) : QStringLiteral("other");
                        byType[type] += items[i].FmtValue.doubleValue;
                    }
                    double best = 0.0;
                    for (auto it = byType.constBegin(); it != byType.constEnd(); ++it)
                        best = std::max(best, it.value());
                    m_gpu = std::max(0.0, std::min(100.0, best));
                }
            }
        }
    }
#endif
    emit sampled();
}

}  // namespace sa::studio
