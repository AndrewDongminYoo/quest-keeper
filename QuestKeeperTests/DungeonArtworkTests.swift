import Testing
import UIKit
@testable import QuestKeeper

struct DungeonArtworkTests {
    @Test("mob levels map to the three visual tiers")
    func monsterTierMapping() {
        #expect(DungeonArtwork.monster(level: 0) == .slime)
        #expect(DungeonArtwork.monster(level: 1) == .slime)
        #expect(DungeonArtwork.monster(level: 2) == .skeleton)
        #expect(DungeonArtwork.monster(level: 3) == .skeleton)
        #expect(DungeonArtwork.monster(level: 4) == .dragon)
        #expect(DungeonArtwork.monster(level: 5) == .dragon)
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
            .add,
            .notificationsDisabled,
            .retry,
            .complete,
            .delete,
        ]

        #expect(icons.allSatisfy { $0.contentScale == 1.5 })
        #expect(DungeonArtwork.heroIdle.contentScale == 1)
    }

    @Test("second-row icons have clear top margins")
    func secondRowIconsHaveClearTopMargins() throws {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let assetNames = ["icon-victory-trophy", "icon-add", "icon-notifications-disabled", "icon-retry"]

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
            "sprite-hero-idle",
            "sprite-hero-breathe-in",
            "sprite-hero-breathe-out",
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
            .heroIdle,
            .heroBreatheIn,
            .heroBreatheOut,
            .heroBreatheIn,
        ])
        #expect(Set(HeroAnimation.breathingFrames).count == 3)
    }

    @Test("mourning and Reduce Motion select stable artwork")
    func staticHeroArtwork() {
        #expect(HeroAnimation.artwork(isMourning: true, reduceMotion: false, frameIndex: 2) == .heroMourning)
        #expect(HeroAnimation.artwork(isMourning: false, reduceMotion: true, frameIndex: 2) == .heroIdle)
        #expect(HeroAnimation.artwork(isMourning: false, reduceMotion: false, frameIndex: 2) == .heroBreatheOut)
    }
}
