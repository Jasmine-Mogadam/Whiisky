//
//  SteamInstaller.swift
//  WhiskyKit
//
//  This file is part of Whisky.
//
//  Whisky is free software: you can redistribute it and/or modify it under the terms
//  of the GNU General Public License as published by the Free Software Foundation,
//  either version 3 of the License, or (at your option) any later version.
//
//  Whisky is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
//  without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
//  See the GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License along with Whisky.
//  If not, see https://www.gnu.org/licenses/.
//

import Foundation
import os.log

public class SteamInstaller {
    public static let downloadURL = "https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe"
    public static let defaultArguments = "-no-cef-sandbox -no-browser"

    public static func steamExeURL(for bottle: Bottle) -> URL {
        let primaryPath = bottle.url
            .appending(path: "drive_c")
            .appending(path: "Program Files (x86)")
            .appending(path: "Steam")
            .appending(path: "steam.exe")

        if FileManager.default.fileExists(atPath: primaryPath.path(percentEncoded: false)) {
            return primaryPath
        }

        // Fallback to Program Files (non-x86)
        let fallbackPath = bottle.url
            .appending(path: "drive_c")
            .appending(path: "Program Files")
            .appending(path: "Steam")
            .appending(path: "steam.exe")

        if FileManager.default.fileExists(atPath: fallbackPath.path(percentEncoded: false)) {
            return fallbackPath
        }

        // Default to primary path even if not found yet
        return primaryPath
    }

    /// Downloads SteamSetup.exe to a temporary location
    public static func download() async throws -> URL {
        guard let url = URL(string: downloadURL) else {
            throw SteamInstallerError.invalidURL
        }

        let (tempURL, _) = try await URLSession.shared.download(from: url)

        // Move to a location with the .exe extension so Wine recognizes it
        let destURL = FileManager.default.temporaryDirectory.appending(path: "SteamSetup.exe")
        try? FileManager.default.removeItem(at: destURL)
        try FileManager.default.moveItem(at: tempURL, to: destURL)

        return destURL
    }

    /// Runs the Steam installer silently in the given bottle
    public static func install(setupExe: URL, bottle: Bottle) async throws {
        try await Wine.runProgram(at: setupExe, args: ["/S"], bottle: bottle)
        // Clean up the installer
        try? FileManager.default.removeItem(at: setupExe)
    }

    /// Pins Steam in the bottle with the correct launch arguments
    public static func pinSteam(bottle: Bottle) throws {
        let steamURL = steamExeURL(for: bottle)

        guard FileManager.default.fileExists(atPath: steamURL.path(percentEncoded: false)) else {
            throw SteamInstallerError.steamNotFound
        }

        // Write ProgramSettings with the required args
        let settingsFolder = bottle.url.appending(path: "Program Settings")
        if !FileManager.default.fileExists(atPath: settingsFolder.path(percentEncoded: false)) {
            try FileManager.default.createDirectory(at: settingsFolder, withIntermediateDirectories: true)
        }

        var settings = ProgramSettings()
        settings.arguments = defaultArguments
        let settingsURL = settingsFolder.appending(path: "steam.exe").appendingPathExtension("plist")
        try settings.encode(to: settingsURL)

        // Add pin if not already pinned
        if !bottle.settings.pins.contains(where: { $0.url == steamURL }) {
            bottle.settings.pins.append(PinnedProgram(name: "Steam", url: steamURL))
        }
    }
}

public enum SteamInstallerError: LocalizedError {
    case invalidURL
    case steamNotFound

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Steam download URL"
        case .steamNotFound:
            return "Steam executable not found after installation"
        }
    }
}
