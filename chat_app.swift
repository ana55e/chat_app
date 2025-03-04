import SwiftUI
import SwiftData
import Foundation

// MARK: - Modèle de données
@Model
class ChatMessage {
    var text: String         // Changé de 'let' à 'var' pour permettre la modification
    let isFromUser: Bool
    let timestamp: Date
    
    init(text: String, isFromUser: Bool, timestamp: Date) {
        self.text = text
        self.isFromUser = isFromUser
        self.timestamp = timestamp
    }
}

// MARK: - Modèle Ollama
struct OllamaRequest: Codable {
    let model: String
    let prompt: String
    let stream: Bool
}

struct OllamaResponse: Codable {
    let response: String
    let done: Bool
}

// MARK: - ViewModel
@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText = ""
    @Published var isLoading = false
    @Published var error: Error?
    
    private let ollamaURL = URL(string: "http://localhost:11434/api/generate")!
    private let modelName = "mistral" // Ajuster selon le modèle installé
    
    // Initialisation simple, le modelContext est passé aux méthodes
    init() {
        // Pas besoin de charger l'historique ici, cela sera fait dans onAppear de la vue
    }
    
    func sendMessage(modelContext: ModelContext) async {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return // Protection contre les messages vides
        }
        
        let userText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        inputText = "" // Réinitialisation immédiate pour une meilleure UX
        
        let userMessage = ChatMessage(
            text: userText,
            isFromUser: true,
            timestamp: Date()
        )
        modelContext.insert(userMessage)
        
        do {
            try modelContext.save()
            loadHistory(modelContext: modelContext)
            
            // Créer un message assistant vide (placeholder)
            let assistantMessage = ChatMessage(
                text: "Réflexion en cours...",
                isFromUser: false,
                timestamp: Date()
            )
            modelContext.insert(assistantMessage)
            try modelContext.save()
            loadHistory(modelContext: modelContext)
            
            isLoading = true
            
            // Récupérer la réponse d'Ollama
            let response = try await fetchOllamaResponse(prompt: userText)
            
            // Mettre à jour le message assistant avec la réponse
            assistantMessage.text = response
            try modelContext.save()
            loadHistory(modelContext: modelContext)
        } catch {
            self.error = error
            // Supprimer le dernier message assistant en cas d'erreur
            if let lastMessage = messages.last, !lastMessage.isFromUser {
                modelContext.delete(lastMessage)
                try? modelContext.save()
                loadHistory(modelContext: modelContext)
            }
        }
        
        isLoading = false
    }
    
    private func fetchOllamaResponse(prompt: String) async throws -> String {
        let requestData = OllamaRequest(
            model: modelName,
            prompt: prompt,
            stream: false
        )
        
        var request = URLRequest(url: ollamaURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60 // Augmenter le délai d'attente à 60 secondes
        request.httpBody = try JSONEncoder().encode(requestData)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "ChatApp", code: 0, userInfo: [NSLocalizedDescriptionKey: "Réponse réseau invalide"])
        }
        
        guard httpResponse.statusCode == 200 else {
            // Amélioration: meilleure gestion des erreurs HTTP
            let errorMessage = "Erreur serveur: \(httpResponse.statusCode)"
            throw NSError(domain: "ChatApp", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
        
        let ollamaResponse = try JSONDecoder().decode(OllamaResponse.self, from: data)
        return ollamaResponse.response
    }
    
    func loadHistory(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<ChatMessage>(
            sortBy: [SortDescriptor(\.timestamp)]
        )
        messages = (try? modelContext.fetch(descriptor)) ?? []
    }
    
    func clearChat(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<ChatMessage>()
        do {
            let allMessages = try modelContext.fetch(descriptor)
            for message in allMessages {
                modelContext.delete(message)
            }
            try modelContext.save()
            messages = []
        } catch {
            self.error = error
        }
    }
}

// MARK: - Vue principale
struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @Environment(\.modelContext) private var modelContext
    @State private var showClearConfirmation = false
    
    var body: some View {
        VStack {
            // En-tête
            HStack {
                Text("Chat avec Ollama")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    showClearConfirmation = true
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .disabled(viewModel.messages.isEmpty || viewModel.isLoading)
            }
            .padding(.horizontal)
            
            // Zone de chat
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(
                                text: message.text,
                                isFromUser: message.isFromUser
                            )
                            .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Zone de saisie
            HStack {
                TextField("Message...", text: $viewModel.inputText)
                    .textFieldStyle(.roundedBorder)
                    .disabled(viewModel.isLoading)
                    .onSubmit {
                        submitMessage()
                    }
                
                Button {
                    submitMessage()
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                }
                .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
                .padding(.leading, 8)
            }
            .padding()
        }
        .onAppear {
            viewModel.loadHistory(modelContext: modelContext)
        }
        .alert("Erreur", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") { viewModel.error = nil }
        } message: {
            if let error = viewModel.error {
                Text(error.localizedDescription)
            }
        }
        .confirmationDialog(
            "Êtes-vous sûr de vouloir effacer toute la conversation ?",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Effacer", role: .destructive) {
                viewModel.clearChat(modelContext: modelContext)
            }
            Button("Annuler", role: .cancel) {}
        }
    }
    
    private func submitMessage() {
        Task {
            await viewModel.sendMessage(modelContext: modelContext)
        }
    }
}

// MARK: - Composant bulle de message
struct MessageBubble: View {
    let text: String
    let isFromUser: Bool
    
    var body: some View {
        HStack {
            if isFromUser {
                Spacer()
            }
            
            Text(text)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isFromUser ? Color.blue : Color(.systemGray5))
                .foregroundColor(isFromUser ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .textSelection(.enabled)  // Permet de sélectionner le texte
            
            if !isFromUser {
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Configuration SwiftData et App
@main
struct ChatApp: App {
    var body: some Scene {
        WindowGroup {
            ChatView()
        }
        .modelContainer(for: ChatMessage.self)
    }
}
