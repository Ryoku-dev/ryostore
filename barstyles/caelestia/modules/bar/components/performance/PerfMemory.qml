import "../../../../port/services"
import "../../../../components"
import "../../../../services"
PerfStat {
    icon: "memory_alt"
    accent: Colours.palette.m3primary
    value: Memory.percentage
    valueText: isNaN(Memory.percentage) ? "..." : Math.round(Memory.percentage * 100)

    ServiceRef {
        service: Memory
    }
}
