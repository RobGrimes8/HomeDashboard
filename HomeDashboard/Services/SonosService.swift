import Foundation

/// Sonos local HTTP API (port 1400).
/// Uses UPnP SOAP and device description — no cloud account required.
final class SonosService {

    private let client: LocalHTTPClient
    private var config: AppConfig

    init(client: LocalHTTPClient, config: AppConfig) {
        self.client = client
        self.config = config
    }

    func updateConfig(_ config: AppConfig) {
        self.config = config
    }

    func fetchSpeakers(completion: @escaping (Result<[SmartDevice], LocalHTTPError>) -> Void) {
        let group = DispatchGroup()
        var speakers: [SmartDevice] = []
        var firstError: LocalHTTPError?
        let lock = NSLock()

        for ip in config.sonosSpeakerIPs {
            group.enter()
            fetchSpeaker(at: ip) { result in
                lock.lock()
                defer { lock.unlock() }

                switch result {
                case .success(let device):
                    speakers.append(device)
                case .failure(let error):
                    if firstError == nil { firstError = error }
                    speakers.append(SmartDevice(
                        id: ip,
                        name: "Sonos (\(ip))",
                        kind: .speaker,
                        room: nil,
                        isOn: false,
                        brightness: nil,
                        volume: nil,
                        nowPlaying: nil,
                        isReachable: false
                    ))
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if speakers.isEmpty, let error = firstError {
                completion(.failure(error))
            } else {
                speakers.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                completion(.success(speakers))
            }
        }
    }

    func setVolume(_ speakerIP: String, volume: Int, completion: @escaping (Result<Void, LocalHTTPError>) -> Void) {
        let clamped = max(0, min(100, volume))
        let body = """
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
          <s:Body>
            <u:SetVolume xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1">
              <InstanceID>0</InstanceID>
              <Channel>Master</Channel>
              <DesiredVolume>\(clamped)</DesiredVolume>
            </u:SetVolume>
          </s:Body>
        </s:Envelope>
        """

        performSOAP(
            ip: speakerIP,
            controlPath: "/MediaRenderer/RenderingControl/Control",
            action: "urn:schemas-upnp-org:service:RenderingControl:1#SetVolume",
            body: body
        ) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func adjustVolume(_ speakerIP: String, by delta: Int, completion: @escaping (Result<Int, LocalHTTPError>) -> Void) {
        let body = """
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
          <s:Body>
            <u:SetRelativeVolume xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1">
              <InstanceID>0</InstanceID>
              <Channel>Master</Channel>
              <Adjustment>\(delta)</Adjustment>
            </u:SetRelativeVolume>
          </s:Body>
        </s:Envelope>
        """

        performSOAP(
            ip: speakerIP,
            controlPath: "/MediaRenderer/RenderingControl/Control",
            action: "urn:schemas-upnp-org:service:RenderingControl:1#SetRelativeVolume",
            body: body
        ) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let xml):
                if let volumeString = self.extractXMLValue(named: "NewVolume", from: xml),
                   let volume = Int(volumeString) {
                    completion(.success(volume))
                } else {
                    completion(.failure(.decodingFailed))
                }
            }
        }
    }

    func play(_ speakerIP: String, completion: @escaping (Result<Void, LocalHTTPError>) -> Void) {
        performPlay(on: speakerIP, completion: completion)
    }

    private func performPlay(on ip: String, completion: @escaping (Result<Void, LocalHTTPError>) -> Void) {
        avTransportAction(
            ip: ip,
            action: "urn:schemas-upnp-org:service:AVTransport:1#Play",
            body: """
            <?xml version="1.0" encoding="utf-8"?>
            <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
              <s:Body>
                <u:Play xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
                  <InstanceID>0</InstanceID>
                  <Speed>1</Speed>
                </u:Play>
              </s:Body>
            </s:Envelope>
            """,
            completion: completion
        )
    }

    func pause(_ speakerIP: String, completion: @escaping (Result<Void, LocalHTTPError>) -> Void) {
        withCoordinatorIP(for: speakerIP) { [weak self] coordinatorIP in
            self?.avTransportAction(
                ip: coordinatorIP,
                action: "urn:schemas-upnp-org:service:AVTransport:1#Pause",
                body: """
                <?xml version="1.0" encoding="utf-8"?>
                <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
                  <s:Body>
                    <u:Pause xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
                      <InstanceID>0</InstanceID>
                    </u:Pause>
                  </s:Body>
                </s:Envelope>
                """,
                completion: completion,
                skipCoordinatorResolution: true
            )
        }
    }

    func nextTrack(_ speakerIP: String, completion: @escaping (Result<Void, LocalHTTPError>) -> Void) {
        withCoordinatorIP(for: speakerIP) { [weak self] coordinatorIP in
            self?.avTransportAction(
                ip: coordinatorIP,
                action: "urn:schemas-upnp-org:service:AVTransport:1#Next",
                body: """
                <?xml version="1.0" encoding="utf-8"?>
                <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
                  <s:Body>
                    <u:Next xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
                      <InstanceID>0</InstanceID>
                    </u:Next>
                  </s:Body>
                </s:Envelope>
                """,
                completion: completion,
                skipCoordinatorResolution: true
            )
        }
    }

    func previousTrack(_ speakerIP: String, completion: @escaping (Result<Void, LocalHTTPError>) -> Void) {
        withCoordinatorIP(for: speakerIP) { [weak self] coordinatorIP in
            self?.avTransportAction(
                ip: coordinatorIP,
                action: "urn:schemas-upnp-org:service:AVTransport:1#Previous",
                body: """
                <?xml version="1.0" encoding="utf-8"?>
                <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
                  <s:Body>
                    <u:Previous xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
                      <InstanceID>0</InstanceID>
                    </u:Previous>
                  </s:Body>
                </s:Envelope>
                """,
                completion: completion,
                skipCoordinatorResolution: true
            )
        }
    }

    func fetchFavorites(on speakerIP: String, completion: @escaping (Result<[SonosFavorite], LocalHTTPError>) -> Void) {
        withCoordinatorIP(for: speakerIP) { [weak self] coordinatorIP in
            self?.fetchSonosFavorites(at: coordinatorIP) { items in
                DebugLog.shared.log("Sonos favorites: \(items.count) on \(coordinatorIP)")
                completion(.success(items))
            }
        }
    }

    func playFavorite(on speakerIP: String, favorite: SonosFavorite, completion: @escaping (Result<Void, LocalHTTPError>) -> Void) {
        DebugLog.shared.log("Play Sonos favorite: \(favorite.title)")

        let startPlayback = { [weak self] (uri: String, metadata: String) in
            guard let self = self else { return }
            self.playFavoriteURI(
                on: speakerIP,
                uri: uri,
                metadata: metadata,
                title: favorite.title,
                completion: completion
            )
        }

        if !favorite.uri.isEmpty {
            startPlayback(favorite.uri, favorite.metadata)
            return
        }

        guard let objectID = favorite.objectID else {
            completion(.failure(.decodingFailed))
            return
        }

        withCoordinatorIP(for: speakerIP) { [weak self] coordinatorIP in
            self?.resolveFavoritePlayback(at: coordinatorIP, objectID: objectID) { result in
                switch result {
                case .failure(let error):
                    completion(.failure(error))
                case .success(let resolved):
                    startPlayback(resolved.uri, resolved.metadata)
                }
            }
        }
    }

    func playSpotifyPlaylist(
        on speakerIP: String,
        title: String,
        uri: String,
        completion: @escaping (Result<Void, LocalHTTPError>) -> Void
    ) {
        guard let parsed = parseSpotifyURI(uri), parsed.kind == "playlist" else {
            DebugLog.shared.error("Spotify playlist URI not recognized: \(uri)")
            completion(.failure(.decodingFailed))
            return
        }

        self.playSpotifyFromFavorites(on: speakerIP, playlistID: parsed.id) { [weak self] favoriteResult in
            guard let self = self else { return }
            switch favoriteResult {
            case .success:
                completion(.success(()))
            case .failure(let favoriteError):
                DebugLog.shared.log("Sonos favorites miss for \(parsed.id): \(favoriteError.localizedDescription)")
                self.attemptSpotifyPlaylistPlayback(
                    on: speakerIP,
                    title: title,
                    parsed: parsed,
                    regions: ["2311", "3079"],
                    regionIndex: 0,
                    variantIndex: 0,
                    completion: completion
                )
            }
        }
    }

    private func playSpotifyFromFavorites(
        on speakerIP: String,
        playlistID: String,
        completion: @escaping (Result<Void, LocalHTTPError>) -> Void
    ) {
        withCoordinatorIP(for: speakerIP) { [weak self] coordinatorIP in
            self?.fetchSonosFavorites(at: coordinatorIP) { items in
                guard let self = self else { return }
            let normalizedID = playlistID.lowercased()
            guard
                let favorite = items.first(where: { item in
                    item.uri.lowercased().contains(normalizedID)
                        || item.metadata.lowercased().contains(normalizedID)
                })
            else {
                completion(.failure(.decodingFailed))
                return
            }

            DebugLog.shared.log("Spotify favorite match: \(favorite.title) → \(favorite.uri.isEmpty ? (favorite.objectID ?? "unresolved") : favorite.uri)")
            let startPlayback = { (uri: String, metadata: String) in
                self.playFavoriteURI(
                    on: speakerIP,
                    uri: uri,
                    metadata: metadata,
                    title: favorite.title,
                    completion: completion
                )
            }

            if !favorite.uri.isEmpty {
                startPlayback(favorite.uri, favorite.metadata)
                return
            }

            guard let objectID = favorite.objectID else {
                completion(.failure(.decodingFailed))
                return
            }

            self.resolveFavoritePlayback(at: coordinatorIP, objectID: objectID) { result in
                switch result {
                case .failure(let error):
                    completion(.failure(error))
                case .success(let resolved):
                    startPlayback(resolved.uri, resolved.metadata)
                }
            }
            }
        }
    }

    private func fetchSonosFavorites(at ip: String, completion: @escaping ([SonosFavorite]) -> Void) {
        let body = """
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
          <s:Body>
            <u:Browse xmlns:u="urn:schemas-upnp-org:service:ContentDirectory:1">
              <ObjectID>FV:2</ObjectID>
              <BrowseFlag>BrowseDirectChildren</BrowseFlag>
              <Filter>*</Filter>
              <StartingIndex>0</StartingIndex>
              <RequestedCount>100</RequestedCount>
              <SortCriteria></SortCriteria>
            </u:Browse>
          </s:Body>
        </s:Envelope>
        """

        performSOAP(
            ip: ip,
            controlPath: "/MediaServer/ContentDirectory/Control",
            action: "urn:schemas-upnp-org:service:ContentDirectory:1#Browse",
            body: body
        ) { result in
            switch result {
            case .failure:
                completion([])
            case .success(let xml):
                guard let resultXML = self.extractXMLValue(named: "Result", from: xml) else {
                    completion([])
                    return
                }
                completion(self.parseSonosFavoriteItems(from: resultXML))
            }
        }
    }

    private func parseSonosFavoriteItems(from resultXML: String) -> [SonosFavorite] {
        let decoded = decodeHTMLEntities(resultXML)
        var favorites = parseDIDLFavorites(from: decoded, tagName: "item")
        favorites.append(contentsOf: parseDIDLFavorites(from: decoded, tagName: "container"))

        var seen = Set<String>()
        return favorites.filter { favorite in
            let key = favorite.objectID ?? favorite.uri
            guard !key.isEmpty else { return false }
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }

    private func parseDIDLFavorites(from decoded: String, tagName: String) -> [SonosFavorite] {
        let pattern = "<\(tagName)[^>]*id=\"([^\"]+)\"[^>]*>(.*?)</\(tagName)>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return []
        }

        let range = NSRange(decoded.startIndex..., in: decoded)
        return regex.matches(in: decoded, options: [], range: range).compactMap { match in
            guard
                let itemIDRange = Range(match.range(at: 1), in: decoded),
                let bodyRange = Range(match.range(at: 2), in: decoded)
            else {
                return nil
            }

            let itemID = String(decoded[itemIDRange])
            let body = String(decoded[bodyRange])
            let openingTag = extractOpeningTag(for: tagName, itemID: itemID, in: decoded) ?? ""
            let title = extractDIDLTitle(from: body)
                ?? extractTitleAttribute(from: openingTag)
                ?? humanizedFavoriteTitle(itemID: itemID, body: body)
            let uri = extractPlaybackURI(from: body, itemID: itemID) ?? ""
            let objectID = itemID.hasPrefix("FV:2/") ? itemID : nil

            guard !uri.isEmpty || objectID != nil else { return nil }

            let metadataDIDL = """
            <DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" xmlns:r="urn:schemas-rinconnetworks-com:metadata-1-0/" xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/"><\(tagName) id="\(itemID)" parentID="-1" restricted="true">\(body)</\(tagName)></DIDL-Lite>
            """
            return SonosFavorite(
                title: decodeHTMLEntities(title),
                uri: uri,
                metadata: xmlEscape(metadataDIDL),
                objectID: uri.isEmpty ? objectID : nil
            )
        }
    }

    private func playFavoriteURI(
        on speakerIP: String,
        uri: String,
        metadata: String,
        title: String,
        completion: @escaping (Result<Void, LocalHTTPError>) -> Void
    ) {
        if uri.contains("cpcontainer") || metadata.contains("playlistContainer") {
            let escapedURI = uri.replacingOccurrences(of: "&", with: "&amp;")
            let body = """
            <?xml version="1.0" encoding="utf-8"?>
            <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
              <s:Body>
                <u:AddURIToQueue xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
                  <InstanceID>0</InstanceID>
                  <EnqueuedURI>\(escapedURI)</EnqueuedURI>
                  <EnqueuedURIMetaData>\(metadata)</EnqueuedURIMetaData>
                  <DesiredFirstTrackNumberEnqueued>0</DesiredFirstTrackNumberEnqueued>
                  <EnqueueAsNext>false</EnqueueAsNext>
                </u:AddURIToQueue>
              </s:Body>
            </s:Envelope>
            """

            DebugLog.shared.log("Sonos favorite playlist queue: \(title) → \(uri)")
            performAVTransportSOAP(
                on: speakerIP,
                action: "urn:schemas-upnp-org:service:AVTransport:1#AddURIToQueue",
                body: body
            ) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .failure(let error):
                    completion(.failure(error))
                case .success(let xml):
                    let trackNumber = Int(self.extractXMLValue(named: "FirstTrackNumberEnqueued", from: xml) ?? "1") ?? 1
                    self.playFromQueueTrack(on: speakerIP, trackNumber: max(trackNumber, 1), completion: completion)
                }
            }
            return
        }

        withCoordinatorIP(for: speakerIP) { [weak self] coordinatorIP in
            self?.setSpotifyTransport(
                on: coordinatorIP,
                uri: uri,
                metadata: metadata,
                label: "favorite"
            ) { result in
                switch result {
                case .failure(let error):
                    completion(.failure(error))
                case .success:
                    self?.performPlay(on: speakerIP, completion: completion)
                }
            }
        }
    }

    private func resolveFavoritePlayback(
        at ip: String,
        objectID: String,
        completion: @escaping (Result<(uri: String, metadata: String), LocalHTTPError>) -> Void
    ) {
        let body = """
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
          <s:Body>
            <u:Browse xmlns:u="urn:schemas-upnp-org:service:ContentDirectory:1">
              <ObjectID>\(objectID)</ObjectID>
              <BrowseFlag>BrowseMetadata</BrowseFlag>
              <Filter>*</Filter>
              <StartingIndex>0</StartingIndex>
              <RequestedCount>1</RequestedCount>
              <SortCriteria></SortCriteria>
            </u:Browse>
          </s:Body>
        </s:Envelope>
        """

        performSOAP(
            ip: ip,
            controlPath: "/MediaServer/ContentDirectory/Control",
            action: "urn:schemas-upnp-org:service:ContentDirectory:1#Browse",
            body: body
        ) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let xml):
                guard
                    let resultXML = self.extractXMLValue(named: "Result", from: xml),
                    let favorite = self.parseSonosFavoriteItems(from: resultXML).first(where: { !$0.uri.isEmpty })
                else {
                    completion(.failure(.decodingFailed))
                    return
                }
                completion(.success((favorite.uri, favorite.metadata)))
            }
        }
    }

    private func extractDIDLTitle(from xml: String) -> String? {
        let tags = ["dc:title", "title", "r:shortTitle"]
        for tag in tags {
            if let title = extractXMLTagContent(tag: tag, from: xml), !title.isEmpty {
                return decodeHTMLEntities(title)
            }
        }
        return nil
    }

    private func extractXMLTagContent(tag: String, from xml: String) -> String? {
        let escapedTag = NSRegularExpression.escapedPattern(for: tag)
        let pattern = "<\(escapedTag)[^>]*>(.*?)</\(escapedTag)>"
        guard
            let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
            let match = regex.firstMatch(in: xml, options: [], range: NSRange(xml.startIndex..., in: xml)),
            let range = Range(match.range(at: 1), in: xml)
        else {
            return nil
        }

        let value = String(xml[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func extractTitleAttribute(from openingTag: String) -> String? {
        let pattern = "title=\"([^\"]+)\""
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(in: openingTag, options: [], range: NSRange(openingTag.startIndex..., in: openingTag)),
            let range = Range(match.range(at: 1), in: openingTag)
        else {
            return nil
        }

        let value = String(openingTag[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : decodeHTMLEntities(value)
    }

    private func extractOpeningTag(for tagName: String, itemID: String, in decoded: String) -> String? {
        let escapedID = NSRegularExpression.escapedPattern(for: itemID)
        let pattern = "<\(tagName)[^>]*id=\"\(escapedID)\"[^>]*>"
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(in: decoded, options: [], range: NSRange(decoded.startIndex..., in: decoded)),
            let range = Range(match.range, in: decoded)
        else {
            return nil
        }
        return String(decoded[range])
    }

    private func humanizedFavoriteTitle(itemID: String, body: String) -> String {
        if body.contains("playlistContainer") { return "Spotify Playlist" }
        if body.contains("musicTrack") { return "Spotify Track" }
        if body.contains("audioBroadcast") { return "Radio Station" }
        return itemID
    }

    private func extractPlaybackURI(from body: String, itemID: String) -> String? {
        if let res = extractResURI(from: body) {
            return decodeHTMLEntities(res)
        }
        if let rUri = extractXMLTagContent(tag: "r:uri", from: body), !rUri.isEmpty {
            return decodeHTMLEntities(rUri)
        }
        if let rUri = extractXMLValue(named: "uri", from: body), !rUri.isEmpty {
            return decodeHTMLEntities(rUri)
        }

        let patterns = [
            "x-rincon-cpcontainer:[^<\\s\"]+",
            "x-sonos-spotify:[^<\\s\"]+",
            "x-sonosapi-stream:[^<\\s\"]+",
            "x-sonosapi-radio:[^<\\s\"]+",
            "x-sonos-http:[^<\\s\"]+"
        ]
        for pattern in patterns {
            if let uri = firstRegexMatch(pattern, in: body) {
                return decodeHTMLEntities(uri)
            }
        }

        if !itemID.hasPrefix("FV:2/") {
            if itemID.contains("playlist") || itemID.contains("spotify") || itemID.hasPrefix("1006206c") || itemID.hasPrefix("0006206c") {
                return "x-rincon-cpcontainer:\(itemID)"
            }
        }

        return nil
    }

    private func firstRegexMatch(_ pattern: String, in text: String) -> String? {
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
            let range = Range(match.range, in: text)
        else {
            return nil
        }
        return String(text[range])
    }

    private func extractResURI(from xml: String) -> String? {
        let pattern = "<res[^>]*>(.*?)</res>"
        guard
            let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
            let match = regex.firstMatch(in: xml, options: [], range: NSRange(xml.startIndex..., in: xml)),
            let range = Range(match.range(at: 1), in: xml)
        else {
            return nil
        }

        let value = String(xml[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private struct ParsedSpotifyURI {
        let kind: String
        let id: String

        var spotifyURI: String { "spotify:\(kind):\(id)" }
        var encodedURI: String { spotifyURI.replacingOccurrences(of: ":", with: "%3a") }
    }

    private func attemptSpotifyPlaylistPlayback(
        on speakerIP: String,
        title: String,
        parsed: ParsedSpotifyURI,
        regions: [String],
        regionIndex: Int,
        variantIndex: Int,
        completion: @escaping (Result<Void, LocalHTTPError>) -> Void
    ) {
        guard regionIndex < regions.count else {
            completion(.failure(.invalidResponse))
            return
        }

        let region = regions[regionIndex]
        let variants = spotifyPlaylistVariants(title: title, parsed: parsed, region: region)
        guard variantIndex < variants.count else {
            completion(.failure(.invalidResponse))
            return
        }

        let request = variants[variantIndex]

        addSpotifyPlaylistToQueue(on: speakerIP, request: request) { [weak self] result in
            switch result {
            case .success(let trackNumber):
                self?.playFromQueueTrack(on: speakerIP, trackNumber: trackNumber) { queueResult in
                    switch queueResult {
                    case .success:
                        completion(.success(()))
                    case .failure:
                        DebugLog.shared.log("Spotify queue bind failed, trying direct Play")
                        self?.performPlay(on: speakerIP, completion: completion)
                    }
                }
            case .failure(let queueError):
                self?.advanceSpotifyPlaylistAttempt(
                    on: speakerIP,
                    title: title,
                    parsed: parsed,
                    regions: regions,
                    regionIndex: regionIndex,
                    variantIndex: variantIndex,
                    lastError: queueError,
                    completion: completion
                )
            }
        }
    }

    private func advanceSpotifyPlaylistAttempt(
        on speakerIP: String,
        title: String,
        parsed: ParsedSpotifyURI,
        regions: [String],
        regionIndex: Int,
        variantIndex: Int,
        lastError: LocalHTTPError,
        completion: @escaping (Result<Void, LocalHTTPError>) -> Void
    ) {
        let region = regions[regionIndex]
        let variants = spotifyPlaylistVariants(title: title, parsed: parsed, region: region)

        let nextVariant = variantIndex + 1
        if nextVariant < variants.count {
            DebugLog.shared.log("Spotify playlist retry variant \(variants[nextVariant].label)")
            attemptSpotifyPlaylistPlayback(
                on: speakerIP,
                title: title,
                parsed: parsed,
                regions: regions,
                regionIndex: regionIndex,
                variantIndex: nextVariant,
                completion: completion
            )
            return
        }

        let nextRegion = regionIndex + 1
        if nextRegion < regions.count {
            DebugLog.shared.log("Spotify playlist retry region \(regions[nextRegion])")
            attemptSpotifyPlaylistPlayback(
                on: speakerIP,
                title: title,
                parsed: parsed,
                regions: regions,
                regionIndex: nextRegion,
                variantIndex: 0,
                completion: completion
            )
            return
        }

        DebugLog.shared.error("Spotify playlist failed: \(lastError.localizedDescription)")
        completion(.failure(lastError))
    }

    private struct SpotifyPlaylistRequest {
        let queueURI: String
        let itemId: String
        let title: String
        let cdUdn: String
        let useMetadata: Bool
        let label: String
    }

    private func spotifyPlaylistVariants(
        title: String,
        parsed: ParsedSpotifyURI,
        region: String
    ) -> [SpotifyPlaylistRequest] {
        let encodedPlaylist = parsed.encodedURI
        let encodedUserPlaylist = "spotify%3auser%3aspotify%3aplaylist%3a\(parsed.id)"
        let cdUdn = "SA_RINCON\(region)_X_#Svc\(region)-0-Token"

        return [
            SpotifyPlaylistRequest(
                queueURI: "x-rincon-cpcontainer:1006206c\(encodedPlaylist)",
                itemId: "1006206c\(encodedPlaylist)",
                title: title,
                cdUdn: cdUdn,
                useMetadata: true,
                label: "standard"
            ),
            SpotifyPlaylistRequest(
                queueURI: "x-rincon-cpcontainer:0006206c\(encodedUserPlaylist)",
                itemId: "0006206c\(encodedUserPlaylist)",
                title: title,
                cdUdn: cdUdn,
                useMetadata: true,
                label: "user-style"
            ),
            SpotifyPlaylistRequest(
                queueURI: "x-rincon-cpcontainer:1006206c\(encodedPlaylist)?sid=9&flags=8300&sn=0",
                itemId: "1006206c\(encodedPlaylist)",
                title: title,
                cdUdn: cdUdn,
                useMetadata: true,
                label: "with-sid"
            ),
            SpotifyPlaylistRequest(
                queueURI: "x-rincon-cpcontainer:1006206c\(encodedPlaylist)",
                itemId: "1006206c\(encodedPlaylist)",
                title: title,
                cdUdn: cdUdn,
                useMetadata: false,
                label: "no-metadata"
            )
        ]
    }

    private func spotifyShareMetadata(for request: SpotifyPlaylistRequest) -> String {
        guard request.useMetadata else { return "" }

        let escapedTitle = xmlEscape(request.title)
        let didl = """
        <DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" xmlns:r="urn:schemas-rinconnetworks-com:metadata-1-0/" xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/"><item id="\(request.itemId)" parentID="-1" restricted="true"><dc:title>\(escapedTitle)</dc:title><upnp:class>object.container.playlistContainer</upnp:class><desc id="cdudn" nameSpace="urn:schemas-rinconnetworks-com:metadata-1-0/">\(request.cdUdn)</desc></item></DIDL-Lite>
        """
        return xmlEscape(didl)
    }

    private func setSpotifyTransport(
        on speakerIP: String,
        uri: String,
        metadata: String,
        label: String,
        completion: @escaping (Result<Void, LocalHTTPError>) -> Void
    ) {
        let escapedURI = uri.replacingOccurrences(of: "&", with: "&amp;")
        let body = """
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
          <s:Body>
            <u:SetAVTransportURI xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
              <InstanceID>0</InstanceID>
              <CurrentURI>\(escapedURI)</CurrentURI>
              <CurrentURIMetaData>\(metadata)</CurrentURIMetaData>
            </u:SetAVTransportURI>
          </s:Body>
        </s:Envelope>
        """

        DebugLog.shared.log("Spotify SetAVTransportURI [\(label)] \(uri)")
        avTransportAction(
            ip: speakerIP,
            action: "urn:schemas-upnp-org:service:AVTransport:1#SetAVTransportURI",
            body: body,
            completion: completion,
            skipCoordinatorResolution: true
        )
    }

    private func addSpotifyPlaylistToQueue(
        on speakerIP: String,
        request: SpotifyPlaylistRequest,
        completion: @escaping (Result<Int, LocalHTTPError>) -> Void
    ) {
        let metadata = spotifyShareMetadata(for: request)
        let body = """
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
          <s:Body>
            <u:AddURIToQueue xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
              <InstanceID>0</InstanceID>
              <EnqueuedURI>\(request.queueURI)</EnqueuedURI>
              <EnqueuedURIMetaData>\(metadata)</EnqueuedURIMetaData>
              <DesiredFirstTrackNumberEnqueued>0</DesiredFirstTrackNumberEnqueued>
              <EnqueueAsNext>false</EnqueueAsNext>
            </u:AddURIToQueue>
          </s:Body>
        </s:Envelope>
        """

        DebugLog.shared.log("Spotify AddURIToQueue [\(request.label)] \(request.queueURI) (\(request.cdUdn))")
        performAVTransportSOAP(
            on: speakerIP,
            action: "urn:schemas-upnp-org:service:AVTransport:1#AddURIToQueue",
            body: body
        ) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let xml):
                let trackNumber = Int(self.extractXMLValue(named: "FirstTrackNumberEnqueued", from: xml) ?? "1") ?? 1
                DebugLog.shared.log("Spotify queued at track \(trackNumber)")
                completion(.success(max(trackNumber, 1)))
            }
        }
    }

    private func playFromQueueTrack(
        on speakerIP: String,
        trackNumber: Int,
        completion: @escaping (Result<Void, LocalHTTPError>) -> Void
    ) {
        withCoordinatorIP(for: speakerIP) { [weak self] coordinatorIP in
            guard let self = self else { return }
            self.fetchDeviceUDN(at: coordinatorIP) { udn in
                guard let queueID = self.normalizedQueueUDN(from: udn) else {
                    completion(.failure(.decodingFailed))
                    return
                }

                let queueURI = "x-rincon-queue:\(queueID)#0"
                let body = """
                <?xml version="1.0" encoding="utf-8"?>
                <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
                  <s:Body>
                    <u:SetAVTransportURI xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
                      <InstanceID>0</InstanceID>
                      <CurrentURI>\(queueURI)</CurrentURI>
                      <CurrentURIMetaData></CurrentURIMetaData>
                    </u:SetAVTransportURI>
                  </s:Body>
                </s:Envelope>
                """

                DebugLog.shared.log("Spotify play queue \(queueURI) track \(trackNumber) via \(coordinatorIP)")
                self.performAVTransportSOAP(
                    on: speakerIP,
                    action: "urn:schemas-upnp-org:service:AVTransport:1#SetAVTransportURI",
                    body: body
                ) { result in
                    switch result {
                    case .failure(let error):
                        completion(.failure(error))
                    case .success:
                        self.seekQueueTrack(on: speakerIP, trackNumber: trackNumber) { seekResult in
                            switch seekResult {
                            case .failure(let error):
                                completion(.failure(error))
                            case .success:
                                self.performPlay(on: speakerIP, completion: completion)
                            }
                        }
                    }
                }
            }
        }
    }

    private func seekQueueTrack(
        on speakerIP: String,
        trackNumber: Int,
        completion: @escaping (Result<Void, LocalHTTPError>) -> Void
    ) {
        let body = """
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
          <s:Body>
            <u:Seek xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
              <InstanceID>0</InstanceID>
              <Unit>TRACK_NR</Unit>
              <Target>\(trackNumber)</Target>
            </u:Seek>
          </s:Body>
        </s:Envelope>
        """

        avTransportAction(
            ip: speakerIP,
            action: "urn:schemas-upnp-org:service:AVTransport:1#Seek",
            body: body,
            completion: completion
        )
    }

    private func fetchDeviceUDN(at ip: String, completion: @escaping (String?) -> Void) {
        let url = "http://\(ip):1400/xml/device_description.xml"
        client.get(urlString: url) { result in
            switch result {
            case .failure:
                completion(nil)
            case .success(let data):
                guard let xml = String(data: data, encoding: .utf8) else {
                    completion(nil)
                    return
                }
                completion(self.extractXMLValue(named: "UDN", from: xml))
            }
        }
    }

    private func fetchSpeaker(at ip: String, completion: @escaping (Result<SmartDevice, LocalHTTPError>) -> Void) {
        let group = DispatchGroup()
        var roomName: String?
        var volume: Int?
        var playback = PlaybackStatus(isPlaying: false, nowPlaying: nil)
        var firstError: LocalHTTPError?
        let lock = NSLock()

        group.enter()
        fetchRoomName(at: ip) { result in
            lock.lock()
            defer { lock.unlock() }
            switch result {
            case .success(let name):
                roomName = name
            case .failure(let error):
                if firstError == nil { firstError = error }
            }
            group.leave()
        }

        group.enter()
        fetchVolume(at: ip) { result in
            lock.lock()
            defer { lock.unlock() }
            switch result {
            case .success(let level):
                volume = level
            case .failure(let error):
                if firstError == nil { firstError = error }
            }
            group.leave()
        }

        group.enter()
        fetchPlaybackStatus(at: ip) { result in
            lock.lock()
            defer { lock.unlock() }
            switch result {
            case .success(let status):
                playback = status
            case .failure(let error):
                if firstError == nil { firstError = error }
            }
            group.leave()
        }

        group.notify(queue: .main) {
            guard roomName != nil || volume != nil || playback.nowPlaying != nil else {
                completion(.failure(firstError ?? .invalidResponse))
                return
            }

            let name = roomName ?? "Sonos \(ip)"
            completion(.success(SmartDevice(
                id: ip,
                name: name,
                kind: .speaker,
                room: roomName,
                isOn: playback.isPlaying,
                brightness: nil,
                volume: volume,
                nowPlaying: playback.nowPlaying,
                isReachable: true
            )))
        }
    }

    private struct PlaybackStatus {
        let isPlaying: Bool
        let nowPlaying: String?
    }

    private func fetchRoomName(at ip: String, completion: @escaping (Result<String, LocalHTTPError>) -> Void) {
        let url = "http://\(ip):1400/xml/device_description.xml"
        client.get(urlString: url) { result in
            switch result {
            case .failure(let error):
                self.fetchRoomNameFromInfo(at: ip, fallbackError: error, completion: completion)
            case .success(let data):
                guard let xml = String(data: data, encoding: .utf8) else {
                    self.fetchRoomNameFromInfo(at: ip, fallbackError: .decodingFailed, completion: completion)
                    return
                }

                if let room = self.extractXMLValue(named: "roomName", from: xml), !room.isEmpty {
                    completion(.success(room))
                    return
                }

                if let friendly = self.extractXMLValue(named: "friendlyName", from: xml), !friendly.isEmpty {
                    completion(.success(friendly))
                    return
                }

                self.fetchRoomNameFromInfo(at: ip, fallbackError: .decodingFailed, completion: completion)
            }
        }
    }

    private func fetchRoomNameFromInfo(
        at ip: String,
        fallbackError: LocalHTTPError,
        completion: @escaping (Result<String, LocalHTTPError>) -> Void
    ) {
        let url = "http://\(ip):1400/status/info"
        client.get(urlString: url) { result in
            switch result {
            case .failure:
                completion(.failure(fallbackError))
            case .success(let data):
                guard
                    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let roomName = json["roomName"] as? String,
                    !roomName.isEmpty
                else {
                    completion(.failure(fallbackError))
                    return
                }
                completion(.success(roomName))
            }
        }
    }

    private func fetchVolume(at ip: String, completion: @escaping (Result<Int, LocalHTTPError>) -> Void) {
        let body = """
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
          <s:Body>
            <u:GetVolume xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1">
              <InstanceID>0</InstanceID>
              <Channel>Master</Channel>
            </u:GetVolume>
          </s:Body>
        </s:Envelope>
        """

        performSOAP(
            ip: ip,
            controlPath: "/MediaRenderer/RenderingControl/Control",
            action: "urn:schemas-upnp-org:service:RenderingControl:1#GetVolume",
            body: body
        ) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let xml):
                if let volumeString = self.extractXMLValue(named: "CurrentVolume", from: xml),
                   let volume = Int(volumeString) {
                    completion(.success(volume))
                } else {
                    completion(.failure(.decodingFailed))
                }
            }
        }
    }

    private func fetchPlaybackStatus(at ip: String, completion: @escaping (Result<PlaybackStatus, LocalHTTPError>) -> Void) {
        let url = "http://\(ip):1400/status/player"
        client.get(urlString: url) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let data):
                guard let xml = String(data: data, encoding: .utf8) else {
                    completion(.failure(.decodingFailed))
                    return
                }

                let isPlaying = xml.contains("<state>PLAYING</state>")
                    || xml.contains("<transportState>PLAYING</transportState>")
                let title = self.extractXMLValue(named: "title", from: xml)
                let artist = self.extractXMLValue(named: "artist", from: xml)
                let nowPlaying = self.nowPlayingText(title: title, artist: artist, isPlaying: isPlaying)
                completion(.success(PlaybackStatus(isPlaying: isPlaying, nowPlaying: nowPlaying)))
            }
        }
    }

    private func nowPlayingText(title: String?, artist: String?, isPlaying: Bool) -> String? {
        if let title = title, !title.isEmpty {
            if let artist = artist, !artist.isEmpty {
                return "\(title) · \(artist)"
            }
            return title
        }
        return isPlaying ? "Playing" : "Nothing playing"
    }

    private func avTransportAction(
        ip: String,
        action: String,
        body: String,
        completion: @escaping (Result<Void, LocalHTTPError>) -> Void,
        skipCoordinatorResolution: Bool = false
    ) {
        let perform = { [weak self] (targetIP: String) in
            self?.performSOAP(
                ip: targetIP,
                controlPath: "/MediaRenderer/AVTransport/Control",
                action: action,
                body: body
            ) { result in
                switch result {
                case .success:
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }

        if skipCoordinatorResolution {
            perform(ip)
            return
        }

        withCoordinatorIP(for: ip) { coordinatorIP in
            if coordinatorIP != ip {
                DebugLog.shared.log("Sonos AVTransport via coordinator \(coordinatorIP) (speaker \(ip))")
            }
            perform(coordinatorIP)
        }
    }

    private func performAVTransportSOAP(
        on speakerIP: String,
        action: String,
        body: String,
        completion: @escaping (Result<String, LocalHTTPError>) -> Void
    ) {
        withCoordinatorIP(for: speakerIP) { coordinatorIP in
            self.performSOAP(
                ip: coordinatorIP,
                controlPath: "/MediaRenderer/AVTransport/Control",
                action: action,
                body: body,
                completion: completion
            )
        }
    }

    private func normalizedQueueUDN(from udn: String?) -> String? {
        guard var value = udn?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        if value.hasPrefix("uuid:") {
            value = String(value.dropFirst(5))
        }
        return value
    }

    private func withCoordinatorIP(for ip: String, completion: @escaping (String) -> Void) {
        fetchDeviceUUID(at: ip) { [weak self] uuid in
            guard let self = self else { return }
            guard let uuid = uuid else {
                completion(ip)
                return
            }

            self.fetchZoneGroupState(at: ip) { zoneGroupState in
                if let zoneGroupState = zoneGroupState,
                   let coordinatorIP = self.coordinatorIP(for: uuid, in: zoneGroupState) {
                    if coordinatorIP != ip {
                        DebugLog.shared.log("Sonos coordinator \(coordinatorIP) for speaker \(ip)")
                    }
                    completion(coordinatorIP)
                } else {
                    completion(ip)
                }
            }
        }
    }

    private func fetchDeviceUUID(at ip: String, completion: @escaping (String?) -> Void) {
        let url = "http://\(ip):1400/xml/device_description.xml"
        client.get(urlString: url) { result in
            switch result {
            case .failure:
                completion(nil)
            case .success(let data):
                guard let xml = String(data: data, encoding: .utf8) else {
                    completion(nil)
                    return
                }
                completion(self.normalizedSonosUUID(from: self.extractXMLValue(named: "UDN", from: xml)))
            }
        }
    }

    private func fetchZoneGroupState(at ip: String, completion: @escaping (String?) -> Void) {
        let body = """
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
          <s:Body>
            <u:GetZoneGroupState xmlns:u="urn:schemas-upnp-org:service:ZoneGroupTopology:1"/>
          </s:Body>
        </s:Envelope>
        """

        performSOAP(
            ip: ip,
            controlPath: "/ZoneGroupTopology/Control",
            action: "urn:schemas-upnp-org:service:ZoneGroupTopology:1#GetZoneGroupState",
            body: body
        ) { result in
            switch result {
            case .failure:
                completion(nil)
            case .success(let xml):
                completion(self.extractXMLValue(named: "ZoneGroupState", from: xml))
            }
        }
    }

    private func coordinatorIP(for deviceUUID: String, in zoneGroupState: String) -> String? {
        let decoded = decodeHTMLEntities(zoneGroupState)
        let groups = decoded.components(separatedBy: "<ZoneGroup ")
        guard groups.count > 1 else { return nil }

        for group in groups.dropFirst() {
            guard group.contains("UUID=\"\(deviceUUID)\"") else { continue }
            guard
                let coordinatorUUID = extractAttribute(named: "Coordinator", from: group),
                let memberBlock = group.range(of: "UUID=\"\(coordinatorUUID)\"")
            else {
                continue
            }

            let tail = String(group[memberBlock.lowerBound...])
            guard
                let location = extractAttribute(named: "Location", from: tail),
                let coordinatorIP = ipFromSonosLocation(location)
            else {
                continue
            }
            return coordinatorIP
        }

        return nil
    }

    private func fetchSpotifySerialNumber(at ip: String, completion: @escaping (Int?) -> Void) {
        let url = "http://\(ip):1400/status/player"
        client.get(urlString: url) { result in
            switch result {
            case .failure:
                completion(nil)
            case .success(let data):
                guard let xml = String(data: data, encoding: .utf8) else {
                    completion(nil)
                    return
                }
                completion(self.extractSpotifySerialNumber(from: xml))
            }
        }
    }

    private func extractSpotifySerialNumber(from xml: String) -> Int? {
        let pattern = "sn=(\\d+)"
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(in: xml, options: [], range: NSRange(xml.startIndex..., in: xml)),
            let range = Range(match.range(at: 1), in: xml),
            let value = Int(String(xml[range]))
        else {
            return nil
        }
        return value
    }

    private func normalizedSonosUUID(from udn: String?) -> String? {
        guard var udn = udn?.trimmingCharacters(in: .whitespacesAndNewlines), !udn.isEmpty else {
            return nil
        }
        if udn.hasPrefix("uuid:") {
            udn = String(udn.dropFirst(5))
        }
        return udn
    }

    private func extractAttribute(named name: String, from fragment: String) -> String? {
        let pattern = "\(name)=\"([^\"]+)\""
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(in: fragment, options: [], range: NSRange(fragment.startIndex..., in: fragment)),
            let range = Range(match.range(at: 1), in: fragment)
        else {
            return nil
        }
        return String(fragment[range])
    }

    private func ipFromSonosLocation(_ location: String) -> String? {
        guard let url = URL(string: location), let host = url.host, !host.isEmpty else {
            return nil
        }
        return host
    }

    private func decodeHTMLEntities(_ string: String) -> String {
        var result = string
        let namedEntities = [
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&quot;", "\""),
            ("&apos;", "'"),
            ("&#39;", "'"),
            ("&#x27;", "'"),
            ("&#x2019;", "'"),
            ("&rsquo;", "'")
        ]
        for (entity, character) in namedEntities {
            result = result.replacingOccurrences(of: entity, with: character)
        }

        if let decimalRegex = try? NSRegularExpression(pattern: "&#(\\d+);") {
            let range = NSRange(result.startIndex..., in: result)
            let matches = decimalRegex.matches(in: result, options: [], range: range).reversed()
            for match in matches {
                guard
                    let codeRange = Range(match.range(at: 1), in: result),
                    let codePoint = UInt32(result[codeRange]),
                    let scalar = UnicodeScalar(codePoint)
                else {
                    continue
                }
                if let fullRange = Range(match.range, in: result) {
                    result.replaceSubrange(fullRange, with: String(Character(scalar)))
                }
            }
        }

        return result.replacingOccurrences(of: "&amp;", with: "&")
    }

    private func soapFaultMessage(from xml: String) -> String? {
        guard xml.contains("Fault") || xml.contains("faultstring") else { return nil }

        let faultString = extractXMLValue(named: "faultstring", from: xml) ?? "UPnPError"
        guard let errorCode = extractXMLValue(named: "errorCode", from: xml) else {
            return faultString
        }

        let description = upnpErrorDescription(for: errorCode)
        if description.isEmpty {
            return "UPnP Error \(errorCode) (\(faultString))"
        }
        return "UPnP Error \(errorCode): \(description)"
    }

    private func upnpErrorDescription(for code: String) -> String {
        switch code {
        case "800":
            return "Command not supported or not a coordinator"
        case "714":
            return "Invalid metadata or URI — playlists must be queued, not played directly"
        case "701":
            return "Transition not available"
        case "402":
            return "Invalid arguments"
        default:
            return ""
        }
    }

    private func parseSpotifyURI(_ input: String) -> ParsedSpotifyURI? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("spotify:") {
            let withoutQuery = trimmed.split(separator: "?").first.map(String.init) ?? trimmed
            let parts = withoutQuery.split(separator: ":").map(String.init)
            guard parts.count == 3, parts[0] == "spotify", !parts[2].isEmpty else { return nil }
            return ParsedSpotifyURI(kind: parts[1], id: parts[2])
        }

        if let url = URL(string: trimmed), let host = url.host, host.contains("spotify") {
            let parts = url.pathComponents.filter { $0 != "/" }
            if parts.count >= 2 {
                return ParsedSpotifyURI(kind: parts[0], id: parts[1])
            }
        }

        return nil
    }

    private func xmlEscape(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private func performSOAP(
        ip: String,
        controlPath: String,
        action: String,
        body: String,
        completion: @escaping (Result<String, LocalHTTPError>) -> Void
    ) {
        guard let url = URL(string: "http://\(ip):1400\(controlPath)") else {
            completion(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("text/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue(action, forHTTPHeaderField: "SOAPACTION")
        request.setValue("Linux UPnP/1.0 Sonos/83.1-61210", forHTTPHeaderField: "User-Agent")
        request.httpBody = body.data(using: .utf8)

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.transport(error)))
                return
            }

            guard let data = data, let xml = String(data: data, encoding: .utf8) else {
                completion(.failure(.decodingFailed))
                return
            }

            if let fault = self.soapFaultMessage(from: xml) {
                DebugLog.shared.error("Sonos SOAP fault: \(fault)")
                completion(.failure(.transport(NSError(domain: "SonosSOAP", code: 1, userInfo: [NSLocalizedDescriptionKey: fault]))))
                return
            }

            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                DebugLog.shared.error("Sonos SOAP HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                completion(.failure(.invalidResponse))
                return
            }

            completion(.success(xml))
        }
        task.resume()
    }

    private func extractXMLValue(named tag: String, from xml: String) -> String? {
        let pattern = "<\(tag)>(.*?)</\(tag)>"
        guard
            let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
            let match = regex.firstMatch(in: xml, options: [], range: NSRange(xml.startIndex..., in: xml)),
            let range = Range(match.range(at: 1), in: xml)
        else {
            return nil
        }

        let value = String(xml[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
