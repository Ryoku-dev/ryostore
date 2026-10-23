import "../../../../port/services"
import "../../../../components"
import "../../../../services"
PerfStat {
    icon: "memory"
    accent: Colours.palette.m3primary
    value: Cpu.percentage
    valueText: isNaN(Cpu.percentage) ? "..." : Math.round(Cpu.percentage * 100) 

    ServiceRef {
        service: Cpu
    }
}
