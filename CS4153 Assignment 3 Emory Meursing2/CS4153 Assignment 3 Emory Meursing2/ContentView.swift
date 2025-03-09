//
//  ContentView.swift
//  CS4153 Assignment 3 Emory Meursing2
//
//  Created by Emory Meursing on 3/9/25.
//

import SwiftUI
import UIKit

struct Card: Identifiable {
    var id = UUID()  // Unique identifier
    var emoji: String  // The content of the card (emoji)
    var isFaceUp = false  // Whether the card is face up or down
    var isMatched = false  // Whether the card has been matched
    var position: CGPoint = .zero  // The card's position on the screen
}
struct CardFront: View {
    let emoji: String
    
    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.white)
            .overlay(
                Text(emoji)
                    .font(.system(size: 48))
                    .foregroundColor(.black)
            )
            .shadow(radius: 5)
    }
}
struct CardBack: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.blue)
            .overlay(
                Image(systemName: "app.fill") // Placeholder for a pattern
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .foregroundColor(.white)
            )
            .shadow(radius: 5)
    }
}
struct CardView: View {
    @Binding var card: Card
    @GestureState private var dragAmount = CGSize.zero
    @State private var flipped = false
    
    var body: some View {
        ZStack {
            // Card back or front based on state
            if card.isFaceUp {
                CardFront(emoji: card.emoji)
                    .rotation3DEffect(
                        .degrees(flipped ? 0 : 180),
                        axis: (x: 0, y: 1, z: 0)
                    )
            } else {
                CardBack()
                    .rotation3DEffect(
                        .degrees(flipped ? 0 : -180),
                        axis: (x: 0, y: 1, z: 0)
                    )
            }
        }
        .frame(width: 100, height: 150)
        .offset(dragAmount) // Dragging offset
        .onTapGesture(count: 2) {  // Double tap to flip card
            withAnimation(.easeInOut(duration: 0.6)) {
                card.isFaceUp.toggle()
            }
        }
        .gesture(DragGesture().updating($dragAmount) { value, state, _ in
            state = value.translation
        })
        .animation(.spring(), value: dragAmount)
    }
}
class CardGameViewModel: ObservableObject {
    @Published var cards: [Card] = []
    @Published var score = 0
    @Published var moves = 0
    @Published var gameOver = false
    @Published var firstSelectedCard: Card? = nil

    init() {
        startNewGame()
    }

    // Start a new game
    func startNewGame() {
        var emojis = ["🍎", "🍌", "🍒", "🍍", "🍇", "🍉", "🍓", "🍑"]
        emojis += emojis  // Duplicate for pairs

        cards = emojis.shuffled().map { Card(emoji: $0) }
        score = 0
        moves = 0
        gameOver = false
        firstSelectedCard = nil
    }

    // Shuffle cards
    func shuffleCards() {
        cards.shuffle()
    }

    // Handle card selection
        func selectCard(_ selectedCard: Card) {
            guard let selectedIndex = cards.firstIndex(where: { $0.id == selectedCard.id }),
                  !cards[selectedIndex].isMatched else {
                return // Do nothing if card is already matched
            }
            
            if let firstCard = firstSelectedCard {
                // Second card selected
                moves += 1
                
                if firstCard.emoji == selectedCard.emoji {
                    // Match found
                    score += 2

                    // Check if all cards are matched
                    if cards.allSatisfy({ $0.isMatched }) {
                        gameOver = true
                    }
                } else {
                    // Cards don't match
                    if score > 0 { score -= 1 }

                    // Flip the cards back after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.flipCardsBack(firstCard, secondCard: selectedCard)
                    }
                }
                
                firstSelectedCard = nil
            } else {
                // First card selected
                firstSelectedCard = selectedCard
            }

            // Flip selected card face up
            cards[selectedIndex].isFaceUp = true
        }

        private func flipCardsBack(_ firstCard: Card, secondCard: Card) {
            // Find indices of the cards in the deck
            guard let firstIndex = cards.firstIndex(where: { $0.id == firstCard.id }),
                  let secondIndex = cards.firstIndex(where: { $0.id == secondCard.id }) else {
                return
            }

            // Flip both cards face down
            cards[firstIndex].isFaceUp = false
            cards[secondIndex].isFaceUp = false
        }
    }
struct ControlPanel: View {
    @ObservedObject var gameViewModel: CardGameViewModel
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Score: \(gameViewModel.score)")
                    .font(.headline)
                Spacer()
                Text("Moves: \(gameViewModel.moves)")
                    .font(.headline)
            }

            HStack {
                Button("New Game") {
                    withAnimation {
                        gameViewModel.startNewGame()
                    }
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                
                Button("Shuffle") {
                    withAnimation {
                        gameViewModel.shuffleCards()
                    }
                }
                .padding()
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(10)
            }

            if gameViewModel.gameOver {
                Text("Game Over!")
                    .font(.largeTitle)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 5)
    }
}
struct MainGameView: View {
    @StateObject private var gameViewModel = CardGameViewModel()
    @State private var deviceOrientation: UIDeviceOrientation = .portrait

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.blue.opacity(0.1).edgesIgnoringSafeArea(.all)
                
                VStack {
                    if deviceOrientation.isPortrait {
                        createCardGrid(geometry.size)
                        ControlPanel(gameViewModel: gameViewModel)
                    } else {
                        HStack {
                            createCardGrid(geometry.size)
                            ControlPanel(gameViewModel: gameViewModel)
                        }
                    }
                }
                .onChange(of: UIDevice.current.orientation) { newOrientation in
                    withAnimation {
                        deviceOrientation = newOrientation
                    }
                }
            }
        }
    }

    private func createCardGrid(_ size: CGSize) -> some View {
        let columns = deviceOrientation.isPortrait ? 4 : 6
        let rows = (gameViewModel.cards.count + columns - 1) / columns

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: columns), spacing: 10) {
            ForEach(gameViewModel.cards) { card in
                CardView(card: $gameViewModel.cards[gameViewModel.cards.firstIndex(where: { $0.id == card.id })!])
                    .onTapGesture {
                        gameViewModel.selectCard(card)
                    }
            }
        }
        .frame(width: size.width - 40, height: size.height / 2)
    }
}
