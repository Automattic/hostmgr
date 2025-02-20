import Virtualization
import libhostmgr

struct ManagedVirtualMachine {
    let machine: VZVirtualMachine
    let config: LaunchConfiguration
}
