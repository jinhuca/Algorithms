#pragma once

#include <QObject>
#include <QTimer>
#include <QtQmlIntegration>

// Lightweight live system/process utilisation sampler for the Analyzer page. A
// ~1 s QTimer samples whole-machine CPU % and RAM % (GetSystemTimes /
// GlobalMemoryStatusEx) plus this process's own CPU % and working-set RAM
// (GetProcessTimes / GetProcessMemoryInfo). `sampled()` fires every tick so the
// QML sparklines can advance even when a value is unchanged. Intentionally tiny
// compared to the Crystal_Qt telemetry app (no PDH/WMI/COM) — all Win32, only the
// psapi link added. Set `active` (e.g. bound to page visibility) to start/stop.
class SystemMonitor : public QObject {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    Q_PROPERTY(double cpuPercent READ cpuPercent NOTIFY sampled)         // system, 0..100
    Q_PROPERTY(double memPercent READ memPercent NOTIFY sampled)         // system, 0..100
    Q_PROPERTY(double memUsedGb READ memUsedGb NOTIFY sampled)
    Q_PROPERTY(double memTotalGb READ memTotalGb NOTIFY sampled)
    Q_PROPERTY(double procCpuPercent READ procCpuPercent NOTIFY sampled) // this app, 0..100 of machine
    Q_PROPERTY(double procMemMb READ procMemMb NOTIFY sampled)
    Q_PROPERTY(double gpuPercent READ gpuPercent NOTIFY sampled)         // whole GPU, 0..100; -1 = N/A

public:
    explicit SystemMonitor(QObject* parent = nullptr);
    ~SystemMonitor() override;

    bool active() const { return m_active; }
    void setActive(bool on);

    double cpuPercent() const { return m_cpu; }
    double memPercent() const { return m_mem; }
    double memUsedGb() const { return m_memUsedGb; }
    double memTotalGb() const { return m_memTotalGb; }
    double procCpuPercent() const { return m_procCpu; }
    double procMemMb() const { return m_procMemMb; }
    double gpuPercent() const { return m_gpu; }

signals:
    void activeChanged();
    void sampled();            // emitted every tick (even if values are unchanged)

private:
    void prime();              // capture baseline counters so the first tick has a delta
    void tick();               // sample all metrics + emit sampled()

    QTimer m_timer;
    bool m_active = false;
    int m_cores = 1;

    // Previous raw counters (100-ns FILETIME ticks packed into 64 bits) for deltas.
    quint64 m_prevIdle = 0, m_prevKernel = 0, m_prevUser = 0;   // system
    quint64 m_prevProcCpu = 0, m_prevWall = 0;                  // process + wall clock

    // Current published values.
    double m_cpu = 0, m_mem = 0, m_memUsedGb = 0, m_memTotalGb = 0;
    double m_procCpu = 0, m_procMemMb = 0;
    double m_gpu = -1;                 // -1 until a valid GPU reading (hidden in UI if <0)

    // PDH query for whole-GPU utilisation (opaque void* so the header stays Win-free).
    void* m_pdhQuery = nullptr;        // PDH_HQUERY
    void* m_pdhGpu = nullptr;          // PDH_HCOUNTER ( \GPU Engine(*)\Utilization Percentage )
};
