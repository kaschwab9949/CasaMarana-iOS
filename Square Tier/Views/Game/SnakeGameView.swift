import SwiftUI
import Combine

struct SnakeGameView: View {
    private let timer = Timer.publish(every: 0.15, on: .main, in: .common).autoconnect()
    
    // Grid settings
    private let rows = 20
    private let cols = 20
    
    // Game State
    @State private var snake: [CGPoint] = [CGPoint(x: 10, y: 10)]
    @State private var food: CGPoint = CGPoint(x: 5, y: 5)
    @State private var direction: Direction = .right
    @State private var isGameOver = false
    @State private var score = 0
    
    private enum Direction {
        case up, down, left, right
    }
    
    var body: some View {
        VStack {
            // Header: Score
            HStack {
                Text("Score: \(score)")
                    .font(.title2)
                    .bold()
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 10)
            
            Spacer()
            
            // Game Board
            GeometryReader { proxy in
                let size = min(proxy.size.width, proxy.size.height) - 32
                let cellSize = size / CGFloat(cols)
                
                ZStack {
                    // Background board
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(uiColor: .systemGray6))
                        .frame(width: size, height: size)
                    
                    // Food
                    Circle()
                        .fill(Color.red)
                        .frame(width: cellSize * 0.8, height: cellSize * 0.8)
                        .position(
                            x: food.x * cellSize + (cellSize / 2),
                            y: food.y * cellSize + (cellSize / 2)
                        )
                    
                    // Snake
                    ForEach(0..<snake.count, id: \.self) { index in
                        Rectangle()
                            .fill(index == 0 ? Color.green : Color.green.opacity(0.8))
                            .frame(width: cellSize, height: cellSize)
                            .position(
                                x: snake[index].x * cellSize + (cellSize / 2),
                                y: snake[index].y * cellSize + (cellSize / 2)
                            )
                    }
                    
                    // Game Over Overlay
                    if isGameOver {
                        VStack(spacing: 20) {
                            Text("Game Over")
                                .font(.largeTitle)
                                .bold()
                            
                            Text("Final Score: \(score)")
                                .font(.title3)
                            
                            Button {
                                resetGame()
                            } label: {
                                Text("Play Again")
                                    .padding(.horizontal, 30)
                                    .padding(.vertical, 12)
                                    .background(Color.mint)
                                    .foregroundColor(.white)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(30)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .shadow(radius: 10)
                    }
                }
                .frame(width: size, height: size)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Swipe gestures for controls
                .gesture(
                    DragGesture()
                        .onEnded { value in
                            guard !isGameOver else { return }
                            let xDiff = value.translation.width
                            let yDiff = value.translation.height
                            
                            if abs(xDiff) > abs(yDiff) {
                                // Horizontal swipe
                                if xDiff > 0 && direction != .left {
                                    direction = .right
                                } else if xDiff < 0 && direction != .right {
                                    direction = .left
                                }
                            } else {
                                // Vertical swipe (note: -y is up in view coords)
                                if yDiff > 0 && direction != .up {
                                    direction = .down
                                } else if yDiff < 0 && direction != .down {
                                    direction = .up
                                }
                            }
                        }
                )
            }
            .aspectRatio(1, contentMode: .fit)
            
            // D-Pad / Buttons for tapping (Accessibility / alternative control)
            VStack(spacing: 12) {
                Button { if direction != .down { direction = .up } } label: { Image(systemName: "arrowtriangle.up.fill").font(.largeTitle) }
                HStack(spacing: 40) {
                    Button { if direction != .right { direction = .left } } label: { Image(systemName: "arrowtriangle.left.fill").font(.largeTitle) }
                    Button { if direction != .left { direction = .right } } label: { Image(systemName: "arrowtriangle.right.fill").font(.largeTitle) }
                }
                Button { if direction != .up { direction = .down } } label: { Image(systemName: "arrowtriangle.down.fill").font(.largeTitle) }
            }
            .padding(.bottom, 30)
            .tint(.primary)
            
            Spacer()
        }
        .onReceive(timer) { _ in
            if !isGameOver {
                moveSnake()
            }
        }
    }
    
    // MARK: - Game Logic
    
    private func moveSnake() {
        guard let head = snake.first else { return }
        
        var newHead = head
        switch direction {
        case .up:    newHead.y -= 1
        case .down:  newHead.y += 1
        case .left:  newHead.x -= 1
        case .right: newHead.x += 1
        }
        
        // Wall collision
        if newHead.x < 0 || newHead.x >= CGFloat(cols) ||
           newHead.y < 0 || newHead.y >= CGFloat(rows) {
            isGameOver = true
            return
        }
        
        // Self collision - ONLY check against body, if body exists.
        // We drop the very last segment from the check because it moves forward.
        if snake.count > 1 && snake.dropLast().contains(newHead) {
            isGameOver = true
            return
        }
        
        snake.insert(newHead, at: 0)
        
        // Food collision
        if newHead == food {
            score += 10
            spawnFood()
             // Don't array map remove tail
        } else {
             snake.removeLast()
        }
    }
    
    private func spawnFood() {
        var newFood: CGPoint
        repeat {
            let rx = Int.random(in: 0..<cols)
            let ry = Int.random(in: 0..<rows)
            newFood = CGPoint(x: rx, y: ry)
        } while snake.contains(newFood)
        food = newFood
    }
    
    private func resetGame() {
        snake = [CGPoint(x: cols/2, y: rows/2)]
        direction = .right
        score = 0
        isGameOver = false
        spawnFood()
    }
}
