import Testing
import UIKit
@testable import QuestKeeper

struct DungeonArtworkTests {
    @Test("mob levels and quest IDs map to stable artwork")
    func monsterTierMapping() {
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

        #expect(DungeonArtwork.monster(level: 0, questID: id) == .bat)
        #expect(DungeonArtwork.monster(level: 2, questID: id) == .orc)
        #expect(DungeonArtwork.monster(level: 4, questID: id) == .golem)
    }

    @Test("every artwork case has a unique asset name")
    func assetNamesAreUnique() {
        let names = DungeonArtwork.allCases.map(\.rawValue)
        #expect(Set(names).count == names.count)
    }

    @Test("compact icons enlarge content within fixed frames")
    func compactIconScales() {
        let icons: [DungeonArtwork] = [
            .battleFlag,
            .victoryTrophy,
            .notificationsDisabled,
            .retry,
            .complete,
            .delete,
        ]

        #expect(icons.allSatisfy { $0.contentScale == 1.5 })
        #expect(DungeonArtwork.slime.contentScale == 1)
    }

    @Test("second-row icons have clear top margins")
    func secondRowIconsHaveClearTopMargins() throws {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let assetNames = ["icon-victory-trophy", "icon-notifications-disabled", "icon-retry"]

        for assetName in assetNames {
            let imageURL = testsDirectory
                .deletingLastPathComponent()
                .appending(path: "QuestKeeper/Assets.xcassets/\(assetName).imageset/\(assetName).png")
            let image = try #require(UIImage(contentsOfFile: imageURL.path)?.cgImage)
            let topMargin = try #require(image.cropping(to: CGRect(x: 0, y: 0, width: image.width, height: 64)))
            var pixels = [UInt8](repeating: 0, count: topMargin.width * topMargin.height * 4)
            let context = try #require(CGContext(
                data: &pixels,
                width: topMargin.width,
                height: topMargin.height,
                bitsPerComponent: 8,
                bytesPerRow: topMargin.width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ))

            context.draw(topMargin, in: CGRect(x: 0, y: 0, width: topMargin.width, height: topMargin.height))

            #expect(!pixels.contains { $0 > 0 }, "\(assetName) contains artwork from the cell above.")
        }
    }

    @Test("hero and grave sprites have clear left margins")
    func heroAndGraveSpritesHaveClearLeftMargins() throws {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let assetNames = [
            "sprite-hero-male-blue-idle",
            "sprite-hero-male-blue-breathe-in",
            "sprite-hero-male-blue-breathe-out",
            "sprite-daily-grave",
        ]

        for assetName in assetNames {
            let imageURL = testsDirectory
                .deletingLastPathComponent()
                .appending(path: "QuestKeeper/Assets.xcassets/\(assetName).imageset/\(assetName).png")
            let image = try #require(UIImage(contentsOfFile: imageURL.path)?.cgImage)
            let leftMargin = try #require(image.cropping(to: CGRect(x: 0, y: 0, width: 32, height: image.height)))
            var pixels = [UInt8](repeating: 0, count: leftMargin.width * leftMargin.height * 4)
            let context = try #require(CGContext(
                data: &pixels,
                width: leftMargin.width,
                height: leftMargin.height,
                bitsPerComponent: 8,
                bytesPerRow: leftMargin.width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ))

            context.draw(leftMargin, in: CGRect(x: 0, y: 0, width: leftMargin.width, height: leftMargin.height))

            #expect(!pixels.contains { $0 > 0 }, "\(assetName) contains detached artwork along the left edge.")
        }
    }

    @Test("breathing uses three unique hero frames in a smooth loop")
    func breathingSequence() {
        #expect(HeroAnimation.breathingFrames == [
            .idle,
            .breatheIn,
            .breatheOut,
            .breatheIn,
        ])
        #expect(Set(HeroAnimation.breathingFrames).count == 3)
    }

    @Test("breathing frames keep the hero centered on one safe baseline")
    func breathingFramesUseAnchoredGeometry() throws {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let assetNames = [
            "sprite-hero-male-blue-idle",
            "sprite-hero-male-blue-breathe-in",
            "sprite-hero-male-blue-breathe-out",
        ]
        let images = try assetNames.map { assetName in
            let imageURL = testsDirectory
                .deletingLastPathComponent()
                .appending(path: "QuestKeeper/Assets.xcassets/\(assetName).imageset/\(assetName).png")
            return try #require(UIImage(contentsOfFile: imageURL.path)?.cgImage)
        }
        let bounds = try images.map(alphaBounds)

        #expect(Set(images.map { CGSize(width: $0.width, height: $0.height) }).count == 1)

        for (image, alphaBounds) in zip(images, bounds) {
            #expect(alphaBounds.minX >= 16)
            #expect(alphaBounds.minY >= 16)
            #expect(alphaBounds.maxX <= CGFloat(image.width - 16))
            #expect(alphaBounds.maxY <= CGFloat(image.height - 16))
        }

        #expect(Set(bounds.map(\.maxY)).count == 1)
    }

    @Test("battle flag keeps its pole base inside the canvas")
    func battleFlagHasSafeBottomMargin() throws {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let imageURL = testsDirectory
            .deletingLastPathComponent()
            .appending(path: "QuestKeeper/Assets.xcassets/icon-battle-flag.imageset/icon-battle-flag.png")
        let image = try #require(UIImage(contentsOfFile: imageURL.path)?.cgImage)
        let bounds = try alphaBounds(of: image)

        #expect(bounds.maxY <= CGFloat(image.height - 16))
    }

    @Test("mourning and Reduce Motion select stable artwork")
    func staticHeroArtwork() {
        #expect(HeroAnimation.frame(reduceMotion: true, frameIndex: 2) == .idle)
        #expect(HeroAnimation.frame(reduceMotion: false, frameIndex: 2) == .breatheOut)
    }

    private func alphaBounds(of image: CGImage) throws -> CGRect {
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let context = try #require(CGContext(
            data: &pixels,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: image.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))

        var minX = image.width
        var minY = image.height
        var maxX = -1
        var maxY = -1

        for y in 0 ..< image.height {
            for x in 0 ..< image.width where pixels[(y * image.width + x) * 4 + 3] > 0 {
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }

        #expect(maxX >= 0 && maxY >= 0, "The sprite must contain visible pixels.")
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }
}
