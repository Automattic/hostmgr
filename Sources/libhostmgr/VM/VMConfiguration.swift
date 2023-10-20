import Virtualization

struct VMConfiguration {

    let bootloader = VZMacOSBootLoader()

    let diskImage: VZDiskImageStorageDeviceAttachment
    let macAddress: VZMACAddress

    let displays: [VZMacGraphicsDisplayConfiguration] = [
        VZMacGraphicsDisplayConfiguration(widthInPixels: 1920, heightInPixels: 1200, pixelsPerInch: 220)
    ]

    let pointingDevice = VZUSBScreenCoordinatePointingDeviceConfiguration()
    let keyboard = VZUSBKeyboardConfiguration()

    init(diskImagePath: URL, macAddress: VZMACAddress) throws {
        self.diskImage = try VZDiskImageStorageDeviceAttachment(url: diskImagePath, readOnly: false)
        self.macAddress = macAddress
    }

    var asVirtualMachineConfiguration: VZVirtualMachineConfiguration {
        let virtualMachineConfiguration = VZVirtualMachineConfiguration()
        virtualMachineConfiguration.bootLoader = self.bootloader

        virtualMachineConfiguration.cpuCount = self.cpuCount
        virtualMachineConfiguration.memorySize = self.memorySize

        virtualMachineConfiguration.networkDevices = self.networkConfiguration
        virtualMachineConfiguration.storageDevices = [self.blockDeviceConfiguration]

        virtualMachineConfiguration.graphicsDevices = self.graphicsConfiguration
        virtualMachineConfiguration.pointingDevices = [self.pointingDevice]
        virtualMachineConfiguration.keyboards = [self.keyboard]

        return virtualMachineConfiguration
    }

    func calculateCPUCount(shared: Bool) -> Int {
        if shared {
            return (ProcessInfo.processInfo.physicalProcessorCount - 1).quotientAndRemainder(dividingBy: 2).quotient
        }

        return ProcessInfo.processInfo.physicalProcessorCount
    }

    var cpuCount: Int {
        calculateCPUCount(shared: Configuration.shared.isSharedNode)
    }

    func calculateMemorySize(
        min minimum: UInt64 = VZVirtualMachineConfiguration.minimumAllowedMemorySize,
        max maximum: UInt64 = VZVirtualMachineConfiguration.maximumAllowedMemorySize,
        hostReserved: UInt64 = Configuration.shared.hostReservedRAM,
        shared: Bool
    ) -> UInt64 {
        let vmReservedSize = maximum - hostReserved

        if shared {
            return min(max(minimum, vmReservedSize.quotientAndRemainder(dividingBy: 2).quotient), maximum)
        }

        return max(vmReservedSize, minimum)
    }

    var memorySize: UInt64 {
        calculateMemorySize(shared: Configuration.shared.isSharedNode)
    }

    var graphicsConfiguration: [VZMacGraphicsDeviceConfiguration] {
        let graphicsConfiguration = VZMacGraphicsDeviceConfiguration()
        graphicsConfiguration.displays = self.displays
        return [graphicsConfiguration]
    }

    var networkConfiguration: [VZVirtioNetworkDeviceConfiguration] {
        let networkDevice = VZVirtioNetworkDeviceConfiguration()

        let networkAttachment = VZNATNetworkDeviceAttachment()
        networkDevice.attachment = networkAttachment
        networkDevice.macAddress = macAddress

        return [networkDevice]
    }

    var blockDeviceConfiguration: VZVirtioBlockDeviceConfiguration {
        VZVirtioBlockDeviceConfiguration(attachment: diskImage)
    }
}
