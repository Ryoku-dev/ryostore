import QtQuick

Item {
  id: spring

  property real target: 0

  property real response: 0.4

  property real dampingFraction: 1.0

  property real epsilon: 0.0005

  property bool tracking: false

  property bool reduceMotion: false

  property real value: 0
  property real velocity: 0
  readonly property bool animating: ticker.running

  signal settled()

  function snapTo(v) {
    ticker.stop()
    spring.velocity = 0
    spring.value = v
  }

  function retarget(v, v0) {
    spring.velocity = v0 || 0
    spring.target = v
    if (!spring.tracking) spring.start()
  }

  function start() {
    if (spring.tracking) return
    if (ticker.running) return
    ticker.start()
  }

  function stop() {
    ticker.stop()
  }

  property bool ready: false

  readonly property real effResponse: spring.reduceMotion
    ? Math.min(Math.max(spring.response, 0.05), 0.25)
    : Math.max(spring.response, 0.05)
  readonly property real effZeta: spring.reduceMotion
    ? 1.0
    : Math.max(spring.dampingFraction, 0.05)
  readonly property real omega: 2 * Math.PI / spring.effResponse

  Component.onCompleted: {
    spring.value = spring.target
    spring.velocity = 0
    spring.ready = true
  }

  onTargetChanged: {
    if (!spring.ready) return
    if (spring.tracking) {

      spring.velocity = 0
      spring.value = spring.target
      return
    }
    spring.start()
  }

  onTrackingChanged: {
    if (spring.ready) {
      if (spring.tracking) {
        ticker.stop()
        spring.velocity = 0
        spring.value = spring.target
      } else {

        spring.velocity = 0
        spring.start()
      }
    }
  }

  onResponseChanged: if (spring.ready && !spring.tracking) spring.start()
  onDampingFractionChanged: if (spring.ready && !spring.tracking) spring.start()

  FrameAnimation {
    id: ticker
    running: false
    onTriggered: {
      const dt = Math.max(0.001, Math.min(frameTime > 0 ? frameTime : 0.007, 0.033))
      spring.advance(dt)
    }
  }

  function advance(dt) {
    const w0 = spring.omega
    const zeta = spring.effZeta
    const x = spring.value - spring.target
    const v = spring.velocity
    let nextValue
    let nextVelocity

    if (zeta < 0.999) {
      let wd = w0 * Math.sqrt(1 - zeta * zeta)
      let decay = Math.exp(-zeta * w0 * dt)
      let cosw = Math.cos(wd * dt)
      let sinw = Math.sin(wd * dt)
      let amp = (v + zeta * w0 * x) / wd
      nextValue = spring.target + decay * (x * cosw + amp * sinw)
      nextVelocity = decay * ((amp * wd - zeta * w0 * x) * cosw
                              - (x * wd + zeta * w0 * amp) * sinw)
    } else {
      let decayC = Math.exp(-w0 * dt)
      let slope = v + w0 * x
      nextValue = spring.target + decayC * (x + slope * dt)
      nextVelocity = decayC * (slope - w0 * (x + slope * dt))
    }

    if (!isFinite(nextValue) || !isFinite(nextVelocity)) {
      spring.settle()
      return
    }

    const restX = Math.abs(nextValue - spring.target)
    const restV = Math.abs(nextVelocity)

    spring.value = nextValue
    spring.velocity = nextVelocity

    if (restX <= spring.epsilon && restV <= spring.epsilon * w0 * 2) spring.settle()
  }

  function settle() {
    ticker.stop()
    spring.velocity = 0
    spring.value = spring.target
    spring.settled()
  }
}
