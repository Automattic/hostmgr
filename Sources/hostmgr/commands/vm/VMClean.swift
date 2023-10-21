import Foundation
import ArgumentParser
import libhostmgr

struct VMCleanCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "clean",
        abstract: "Remove VMs that haven't been used recently"
    )

    let vmManager = VMManager()

    enum CodingKeys: CodingKey {}

    func run() async throws {
        let cutoff = Date(timeIntervalSinceNow: 90 * 24 * 60 * 60 * -1) // 90 days

        let unusedImages = try await vmManager.getVMImages(unusedSince: cutoff)

        if unusedImages.isEmpty {
            Console.exit("No VMs to clean", style: .success)
        }

        Console.info("Removing VMs not used since \(Format.date(cutoff, style: .short))")

        for image in unusedImages {
            try await vmManager.removeVM(name: image.vmName)
            Console.success("Removed \(image.vmName)")
        }

        Console.success("Finished cleaning VMs")
    }
}
