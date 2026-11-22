#pragma once

#include <QObject>
#include <QtQmlIntegration>

class QAudioSink;
class ToneSource;

// Tiny audio engine for the Visualizer: a continuously-running QAudioSink fed by a
// sine oscillator with a fast-decaying envelope. ping(v) retriggers a short blip
// whose pitch maps to the element value v (0..1), so playing a sort "sounds out" the
// data as it moves — the signature sorting-visualizer effect. Safe no-op when there
// is no audio output device (e.g. headless/CI), so it never blocks the app.
class SortAudio : public QObject {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)

public:
    explicit SortAudio(QObject* parent = nullptr);
    ~SortAudio() override;

    bool active() const { return m_active; }
    void setActive(bool on);

    // Trigger a blip; v01 is the element value normalised to [0,1] (pitch).
    Q_INVOKABLE void ping(double v01);

signals:
    void activeChanged();

private:
    bool m_active = false;
    QAudioSink* m_sink = nullptr;
    ToneSource* m_tone = nullptr;
};
