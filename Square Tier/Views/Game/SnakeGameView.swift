import SwiftUI
import Combine

struct SnakeGameView: View {
    @EnvironmentObject var session: AppSession
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private let engineTimer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    private let rows = 20
    private let cols = 20
    private let minimumSwipeDistance: CGFloat = 14

    @AppStorage("snake.highScore") private var highScore = 0

    @State private var snake: [CGPoint] = []
    @State private var food: CGPoint = .zero
    @State private var bonusFood: CGPoint? = nil
    @State private var direction: Direction = .right
    @State private var queuedDirection: Direction? = nil
    @State private var isPaused = false
    @State private var isGameOver = false
    @State private var score = 0

    @State private var bonusStepsRemaining = 0
    @State private var stepCounter = 0
    @State private var lastTickAt: Date?
    @State private var stepAccumulator: TimeInterval = 0
    @State private var leaderboardEntries: [SnakeLeaderboardEntry] = []
    @State private var leaderboardError: String? = nil
    @State private var isLoadingLeaderboard = false
    @State private var isSubmittingLeaderboardScore = false
    @State private var lastSubmittedHighScore = 0
    @State private var isLeaderboardExpanded = false
    @GestureState private var isInteractingWithBoard = false

    private let leaderboardAPI = SnakeLeaderboardAPI()

    private enum Direction {
        case up, down, left, right

        var opposite: Direction {
            switch self {
            case .up: return .down
            case .down: return .up
            case .left: return .right
            case .right: return .left
            }
        }
    }

    private var level: Int {
        min(12, (score / 40) + 1)
    }

    private var stepInterval: TimeInterval {
        max(0.07, 0.17 - Double(level - 1) * 0.008)
    }

    private var bestScore: Int {
        max(highScore, score)
    }

    private var verifiedPhoneE164: String? {
        guard let raw = session.verifiedPhoneE164 else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var leaderboardDisplayName: String {
        let fullName = session.profile.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !fullName.isEmpty {
            return fullName
        }

        guard let phone = verifiedPhoneE164 else { return "Member" }
        let digits = phone.filter(\.isNumber)
        let suffix = String(digits.suffix(4))
        return suffix.isEmpty ? "Member" : "Member \(suffix)"
    }

    static func resolvedBoardMetrics(containerSize: CGSize, cols: Int) -> (boardSide: CGFloat, cellSize: CGFloat) {
        let safeWidth = (containerSize.width.isFinite && containerSize.width > 0) ? containerSize.width : 0
        let safeHeight = (containerSize.height.isFinite && containerSize.height > 0) ? containerSize.height : 0
        let widthDriven = max(1, safeWidth - 24)
        let minSide: CGFloat = safeWidth >= 700 ? 340 : 290
        let maxSide: CGFloat = safeWidth >= 700 ? 620 : 540

        var boardSide = min(maxSide, max(minSide, widthDriven))
        if safeHeight > 0 {
            boardSide = min(boardSide, max(1, safeHeight - 8))
        }
        boardSide = max(1, boardSide)

        let safeCols = max(cols, 1)
        let cellSize = min(48, max(1, boardSide / CGFloat(safeCols)))
        return (boardSide, cellSize)
    }

    private var boardSwipeGesture: some Gesture {
        DragGesture(minimumDistance: minimumSwipeDistance, coordinateSpace: .local)
            .updating($isInteractingWithBoard) { _, state, _ in
                state = true
            }
            .onEnded { value in
                handleSwipe(value.translation)
            }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Score \(score)")
                            .font(.title2)
                            .bold()
                        Text("Best \(bestScore)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Level \(level)")
                            .font(.headline)
                            .bold()
                        Text(String(format: "%.2fs", stepInterval))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)

                GeometryReader { proxy in
                    let metrics = Self.resolvedBoardMetrics(containerSize: proxy.size, cols: cols)
                    let boardSide = metrics.boardSide
                    let cellSize = metrics.cellSize

                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(uiColor: .systemGray6))
                            .frame(width: boardSide, height: boardSide)

                        Path { path in
                            for row in 0...rows {
                                let y = CGFloat(row) * cellSize
                                path.move(to: CGPoint(x: 0, y: y))
                                path.addLine(to: CGPoint(x: boardSide, y: y))
                            }
                            for col in 0...cols {
                                let x = CGFloat(col) * cellSize
                                path.move(to: CGPoint(x: x, y: 0))
                                path.addLine(to: CGPoint(x: x, y: boardSide))
                            }
                        }
                        .stroke(Color.black.opacity(0.08), lineWidth: 0.5)

                        Circle()
                            .fill(.red.gradient)
                            .frame(width: cellSize * 0.75, height: cellSize * 0.75)
                            .shadow(color: .red.opacity(0.35), radius: 3)
                            .position(
                                x: food.x * cellSize + (cellSize / 2),
                                y: food.y * cellSize + (cellSize / 2)
                            )

                        if let bonus = bonusFood {
                            Image(systemName: "star.fill")
                                .font(.system(size: cellSize * 0.65, weight: .black))
                                .foregroundStyle(.yellow)
                                .shadow(color: .yellow.opacity(0.45), radius: 4)
                                .position(
                                    x: bonus.x * cellSize + (cellSize / 2),
                                    y: bonus.y * cellSize + (cellSize / 2)
                                )
                        }

                        ForEach(Array(snake.enumerated()), id: \.offset) { index, segment in
                            RoundedRectangle(cornerRadius: max(3, cellSize * 0.22))
                                .fill(index == 0 ? Color.green : Color.green.opacity(0.82))
                                .frame(width: cellSize * 0.95, height: cellSize * 0.95)
                                .position(
                                    x: segment.x * cellSize + (cellSize / 2),
                                    y: segment.y * cellSize + (cellSize / 2)
                                )
                        }

                        if isGameOver || isPaused {
                            VStack(spacing: 20) {
                                Text(isGameOver ? "Game Over" : "Paused")
                                    .font(.largeTitle)
                                    .bold()

                                Text("Score: \(score)")
                                    .font(.title2)

                                if isGameOver {
                                    Text("Best: \(bestScore)")
                                        .font(.headline)
                                }

                                Button {
                                    isGameOver ? resetGame() : resumeGame()
                                } label: {
                                    Text(isGameOver ? "Play Again" : "Resume")
                                        .padding(.horizontal, 30)
                                        .padding(.vertical, 12)
                                        .background(Color.mint)
                                        .foregroundColor(.white)
                                        .clipShape(Capsule())
                                }
                                .accessibilityIdentifier("snake.overlay.primaryActionButton")
                            }
                            .padding(30)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                            .shadow(radius: 10)
                        }
                    }
                    .frame(width: boardSide, height: boardSide)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("snake.board")
                    .highPriorityGesture(
                        boardSwipeGesture,
                        including: (isGameOver || isPaused) ? .none : .all
                    )
                }
                .frame(height: verticalSizeClass == .compact ? 320 : 470)

                Text("Swipe on the board with one finger to move the snake.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .accessibilityIdentifier("snake.instructions")

                HStack(spacing: 12) {
                    Button(isPaused ? "Resume" : "Pause") {
                        if isPaused {
                            resumeGame()
                        } else {
                            pauseGame()
                        }
                    }
                    .buttonStyle(.bordered)

                    Button("New Game") {
                        resetGame()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Global Leaderboard")
                            .font(.headline)
                        Spacer()
                        if isLoadingLeaderboard || isSubmittingLeaderboardScore {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Button {
                            Task { await refreshLeaderboard() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("snake.leaderboard.refreshButton")

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isLeaderboardExpanded.toggle()
                            }
                        } label: {
                            Image(systemName: isLeaderboardExpanded ? "chevron.up.circle" : "chevron.down.circle")
                        }
                        .buttonStyle(.plain)
                    }

                    if isLeaderboardExpanded {
                        if let leaderboardError {
                            Text(leaderboardError)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .accessibilityIdentifier("snake.leaderboard.errorText")
                        }

                        if leaderboardEntries.isEmpty {
                            Text("No leaderboard scores yet.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 8) {
                                    ForEach(leaderboardEntries) { entry in
                                        HStack(spacing: 10) {
                                            Text("#\(entry.rank)")
                                                .font(.subheadline.monospacedDigit())
                                                .frame(width: 34, alignment: .leading)
                                            Text(entry.displayName)
                                                .lineLimit(1)
                                            Spacer()
                                            Text("\(entry.score)")
                                                .font(.subheadline.monospacedDigit())
                                                .bold()
                                        }
                                        .foregroundStyle(entry.isCurrentUser ? .mint : .primary)
                                    }
                                }
                            }
                            .frame(maxHeight: 220)
                        }

                        if verifiedPhoneE164 == nil {
                            Text("Sign in with a verified phone to publish your high score.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal)
                .accessibilityIdentifier("snake.leaderboard.section")

                HStack(spacing: 10) {
                    Circle()
                        .fill(.red.gradient)
                        .frame(width: 10, height: 10)
                    Text("+10 Food")
                        .font(.caption)
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                    Text("+25 Bonus")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .scrollDisabled(isInteractingWithBoard)
        .onAppear {
            if snake.isEmpty {
                resetGame()
            }
            if !isLeaderboardExpanded {
                isLeaderboardExpanded = verticalSizeClass != .compact
            }
            Task {
                await refreshLeaderboard()
            }
            submitBestScoreIfNeeded(force: true)
        }
        .onReceive(engineTimer) { now in
            if lastTickAt == nil {
                lastTickAt = now
                return
            }

            let delta = now.timeIntervalSince(lastTickAt ?? now)
            lastTickAt = now

            guard !isGameOver && !isPaused else {
                stepAccumulator = 0
                return
            }

            stepAccumulator += min(delta, 0.2)
            while stepAccumulator >= stepInterval {
                stepAccumulator -= stepInterval
                moveSnake()
                if isGameOver {
                    break
                }
            }
        }
    }

    private func handleSwipe(_ translation: CGSize) {
        guard !isGameOver else { return }

        let xDiff = translation.width
        let yDiff = translation.height
        guard max(abs(xDiff), abs(yDiff)) >= minimumSwipeDistance else { return }

        if abs(xDiff) > abs(yDiff) {
            requestDirection(xDiff > 0 ? .right : .left)
        } else {
            requestDirection(yDiff > 0 ? .down : .up)
        }
    }

    private func requestDirection(_ newDirection: Direction) {
        guard !isGameOver else { return }

        let currentReference = queuedDirection ?? direction
        guard newDirection != currentReference, newDirection != currentReference.opposite else {
            return
        }

        queuedDirection = newDirection
        if isPaused {
            resumeGame()
        }
    }

    private func moveSnake() {
        guard let head = snake.first else { return }

        if let queued = queuedDirection, queued != direction.opposite {
            direction = queued
        }
        queuedDirection = nil

        var newHead = head
        switch direction {
        case .up: newHead.y -= 1
        case .down: newHead.y += 1
        case .left: newHead.x -= 1
        case .right: newHead.x += 1
        }

        if newHead.x < 0 || newHead.x >= CGFloat(cols) ||
            newHead.y < 0 || newHead.y >= CGFloat(rows) {
            isGameOver = true
            updateHighScoreIfNeeded()
            submitBestScoreIfNeeded(force: true)
            return
        }

        if snake.count > 1 && snake.dropLast().contains(newHead) {
            isGameOver = true
            updateHighScoreIfNeeded()
            submitBestScoreIfNeeded(force: true)
            return
        }

        snake.insert(newHead, at: 0)

        var didGrow = false
        if newHead == food {
            score += 10
            didGrow = true
            spawnFood()
            if bonusFood == nil, score >= 40, Int.random(in: 0..<100) < 30 {
                spawnBonusFood()
            }
        }

        if let bonus = bonusFood, newHead == bonus {
            score += 25
            didGrow = true
            bonusFood = nil
            bonusStepsRemaining = 0
        }

        if !didGrow {
            snake.removeLast()
        }

        stepCounter += 1
        if bonusFood != nil {
            bonusStepsRemaining -= 1
            if bonusStepsRemaining <= 0 {
                bonusFood = nil
            }
        } else if score >= 40, stepCounter % 18 == 0, Int.random(in: 0..<100) < 45 {
            spawnBonusFood()
        }

        updateHighScoreIfNeeded()
    }

    private func randomFreeCell(excluding extras: [CGPoint] = []) -> CGPoint? {
        let occupied = Set((snake + extras).map(occupancyKey(for:)))
        guard occupied.count < rows * cols else { return nil }

        var candidate: CGPoint
        repeat {
            candidate = CGPoint(x: Int.random(in: 0..<cols), y: Int.random(in: 0..<rows))
        } while occupied.contains(occupancyKey(for: candidate))

        return candidate
    }

    private func occupancyKey(for point: CGPoint) -> String {
        "\(Int(point.x)):\(Int(point.y))"
    }

    private func spawnFood() {
        guard let newFood = randomFreeCell(excluding: bonusFood.map { [$0] } ?? []) else {
            isGameOver = true
            updateHighScoreIfNeeded()
            return
        }
        food = newFood
    }

    private func spawnBonusFood() {
        guard let newBonus = randomFreeCell(excluding: [food]) else { return }
        bonusFood = newBonus
        bonusStepsRemaining = 32
    }

    private func pauseGame() {
        guard !isGameOver else { return }
        isPaused = true
        stepAccumulator = 0
    }

    private func resumeGame() {
        isPaused = false
        stepAccumulator = 0
        lastTickAt = nil
    }

    private func updateHighScoreIfNeeded() {
        if score > highScore {
            highScore = score
        }
    }

    private func submitBestScoreIfNeeded(force: Bool) {
        let best = max(highScore, score)
        guard best > 0 else { return }
        guard force || best > lastSubmittedHighScore else { return }
        guard !isSubmittingLeaderboardScore else { return }
        guard let phone = verifiedPhoneE164 else { return }

        isSubmittingLeaderboardScore = true
        let displayName = leaderboardDisplayName

        Task {
            do {
                let saved = try await leaderboardAPI.submitScore(
                    phoneE164: phone,
                    displayName: displayName,
                    score: best
                )
                let entries = try await leaderboardAPI.fetchLeaderboard(limit: 100, phoneE164: phone)

                await MainActor.run {
                    self.lastSubmittedHighScore = max(self.lastSubmittedHighScore, saved)
                    self.leaderboardEntries = entries
                    self.leaderboardError = nil
                    self.isSubmittingLeaderboardScore = false
                }
            } catch {
                await MainActor.run {
                    self.leaderboardError = friendlyLeaderboardError(error, operation: .sync)
                    self.isSubmittingLeaderboardScore = false
                }
            }
        }
    }

    private func refreshLeaderboard() async {
        await MainActor.run {
            isLoadingLeaderboard = true
            leaderboardError = nil
        }

        do {
            let entries = try await leaderboardAPI.fetchLeaderboard(limit: 100, phoneE164: verifiedPhoneE164)
            await MainActor.run {
                leaderboardEntries = entries
                isLoadingLeaderboard = false
            }
        } catch {
            await MainActor.run {
                leaderboardError = friendlyLeaderboardError(error, operation: .load)
                isLoadingLeaderboard = false
            }
        }
    }

    private enum LeaderboardOperation {
        case load
        case sync
    }

    private func friendlyLeaderboardError(_ error: Error, operation: LeaderboardOperation) -> String {
        if let apiError = error as? APIError {
            switch apiError {
            case .rateLimited(let retryAfter):
                if let retryAfter, retryAfter > 0 {
                    return "Leaderboard is busy. Please wait \(Int(ceil(retryAfter))) seconds and try again."
                }
                return "Leaderboard is busy. Please try again in a moment."
            case .message(let message):
                let normalized = message.trimmingCharacters(in: .whitespacesAndNewlines)
                if normalized.isEmpty {
                    break
                }
                let lowered = normalized.lowercased()
                if lowered.contains("not configured") {
                    return "Leaderboard is not configured yet."
                }
                if lowered.contains("rate limit") || lowered.contains("rate_limited") {
                    return "Leaderboard is busy. Please try again in a moment."
                }
                if normalized.first == "{" || normalized.first == "[" {
                    return "Leaderboard is unavailable right now."
                }
                if lowered.contains("http 4")
                    || lowered.contains("http 5")
                    || lowered.contains("status 4")
                    || lowered.contains("status 5")
                    || lowered.contains("error code") {
                    return "Leaderboard is unavailable right now."
                }
                let safeMessage = UserFacingError.message(
                    for: APIError.message(normalized),
                    context: .generic,
                    fallback: ""
                )
                if !safeMessage.isEmpty {
                    return safeMessage
                }
                return "Leaderboard is unavailable right now."
            case .badStatus(let code):
                if code == 401 || code == 403 {
                    return "Leaderboard access is unavailable right now."
                }
                if code >= 500 {
                    return "Leaderboard service is temporarily unavailable."
                }
            case .invalidURL, .decoding:
                break
            }
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return "No internet connection. Please reconnect and try again."
            case .timedOut:
                return "Leaderboard request timed out. Please try again."
            default:
                break
            }
        }

        switch operation {
        case .load:
            return "Could not load leaderboard right now."
        case .sync:
            return "Could not sync your score right now."
        }
    }

    private func resetGame() {
        let centerX = cols / 2
        let centerY = rows / 2

        snake = [
            CGPoint(x: centerX, y: centerY),
            CGPoint(x: centerX - 1, y: centerY),
            CGPoint(x: centerX - 2, y: centerY)
        ]
        food = .zero
        bonusFood = nil
        bonusStepsRemaining = 0
        stepCounter = 0
        direction = .right
        queuedDirection = nil
        score = 0
        isGameOver = false
        isPaused = false
        stepAccumulator = 0
        lastTickAt = nil
        spawnFood()
    }
}
