#include "SortAudio.h"

#include <QAudioDevice>
#include <QAudioFormat>
#include <QAudioSink>
#include <QIODevice>
#include <QMediaDevices>

#include <atomic>
#include <cmath>

#ifndef M_PI
#  define M_PI 3.14159265358979323846
#endif

namespace sa::studio {

// A pull-mode QIODevice that synthesises a mono 16-bit sine with a per-note decay
// envelope. The audio sink reads from it continuously; trigger() (called from the
// GUI thread) re-arms the envelope and sets the pitch via atomics.
class ToneSource : public QIODevice {
public:
    explicit ToneSource(int sampleRate) : m_sr(sampleRate) { open(QIODevice::ReadOnly); }

    void trigger(double freq) { m_freq.store(freq); m_retrig.store(true); }

    qint64 readData(char* data, qint64 maxlen) override {
        constexpr int bytesPerSample = 2;
        const qint64 frames = maxlen / bytesPerSample;
        auto* out = reinterpret_cast<qint16*>(data);
        for (qint64 i = 0; i < frames; ++i) {
            if (m_retrig.exchange(false)) { m_env = 1.0; m_curFreq = m_freq.load(); }
            const double s = std::sin(m_phase) * m_env * 0.25;
            m_phase += 2.0 * M_PI * m_curFreq / m_sr;
            if (m_phase > 2.0 * M_PI) m_phase -= 2.0 * M_PI;
            m_env *= m_decay;                       // ~75 ms blip
            out[i] = static_cast<qint16>(s * 32767.0);
        }
        return frames * bytesPerSample;
    }
    qint64 writeData(const char*, qint64) override { return 0; }
    qint64 bytesAvailable() const override { return 65536 + QIODevice::bytesAvailable(); }
    bool isSequential() const override { return true; }

private:
    int m_sr;
    std::atomic<double> m_freq{440.0};
    std::atomic<bool> m_retrig{false};
    double m_curFreq = 440.0, m_phase = 0.0, m_env = 0.0, m_decay = 0.9997;
};

SortAudio::SortAudio(QObject* parent) : QObject(parent) {}

SortAudio::~SortAudio() {
    if (m_sink) m_sink->stop();
    delete m_tone;
}

void SortAudio::setActive(bool on) {
    if (on == m_active) return;
    m_active = on;
    if (on) {
        const QAudioDevice dev = QMediaDevices::defaultAudioOutput();
        if (!dev.isNull()) {                        // no device (headless) -> stay silent
            QAudioFormat fmt;
            fmt.setSampleRate(44100);
            fmt.setChannelCount(1);
            fmt.setSampleFormat(QAudioFormat::Int16);
            if (!m_tone) m_tone = new ToneSource(44100);
            m_sink = new QAudioSink(dev, fmt, this);
            m_sink->setVolume(0.6);
            m_sink->start(m_tone);
        }
    } else if (m_sink) {
        m_sink->stop();
        m_sink->deleteLater();
        m_sink = nullptr;
    }
    emit activeChanged();
}

void SortAudio::ping(double v01) {
    if (!m_active || !m_tone) return;
    if (v01 < 0.0) v01 = 0.0;
    if (v01 > 1.0) v01 = 1.0;
    m_tone->trigger(220.0 + v01 * (1200.0 - 220.0));   // map value -> 220..1200 Hz
}

}  // namespace sa::studio
