import Virtualization

#if arch(arm64)
struct VMConfiguration {

    enum NetworkingType {
        case nat
        case bridged(interface: String)
    }

    let bootloader = VZMacOSBootLoader()

    let cpuCount: Int = VZVirtualMachineConfiguration.maximumAllowedCPUCount
    let memorySize: UInt64 = VZVirtualMachineConfiguration.maximumAllowedMemorySize
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
#endif
