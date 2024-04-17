import Foundation

enum PartSizeCalculator {
    // https://docs.aws.amazon.com/AmazonS3/latest/userguide/qfacts.html
    static let minPartSize = 5*1024*1024 // 5MB
    static let maxPartSize = 5*1024*1024*1024 // 5GB
    static let typicalNumberOfParts = 500

    static func calculate(basedOn fileSize: Int) -> Int {
        max(min(fileSize, minPartSize), min(fileSize / typicalNumberOfParts, maxPartSize))
    }
}

/*
     ^
     |       N = typicalNumberOfParts
     |
 5GB |                                    _______________________
     |                               ____/
     |                          ____/     '
     |                     ____/          '
     |                ____/               '
 5MB |   ------------'                    '
     |  /            '                    '
     | /             '                    '
     |/ '            '                    '
     +--+------------+--------------------+----------------------------->
       5MB         5MB*N                5GB*N
 */
