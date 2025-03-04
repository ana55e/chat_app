### chat_app
Cette application fournit une interface simple mais efficace pour interagir avec des modèles de langage via Ollama, avec une expérience utilisateur soignée et une bonne gestion des erreurs et c'est interessant car la majority d'interface LLM local sont en python.





### Structure du Code
- **ChatMessage**: Modèle de données SwiftData pour stocker les messages.
- **OllamaRequest/OllamaResponse**: Structures pour l'API Ollama.
- **ChatViewModel**: Gère la logique métier, y compris l'envoi et la réception de messages.
- **ChatView**: Interface utilisateur principale avec scrollview et zone de saisie.
- **MessageBubble**: Composant réutilisable pour afficher les messages.

## Explications du Code
1. **Interface utilisateur**:
   - Ajout d'un en-tête avec un titre
   - Bouton pour effacer l'historique
   - Sélection de texte possible dans les messages
   - Animation lors du défilement

2. **Expérience utilisateur**:
   - Message "Réflexion en cours..." pendant le chargement
   - Validation des entrées (pas de messages vides)
   - Possibilité d'envoyer avec la touche Entrée
   - Confirmation avant suppression de l'historique

3. **Robustesse**:
   - Délai d'attente augmenté pour les requêtes réseau
   - Messages d'erreur plus détaillés
   - Nettoyage des messages en cas d'erreur

## Comment Utiliser le Code

### Prérequis
1. **Installation d'Ollama**: 
   - Téléchargez et installez Ollama depuis [https://ollama.ai](https://ollama.ai)
   - Démarrez le serveur Ollama (par défaut sur localhost:11434)

2. **Modèles Ollama**:
   - Installez le modèle que vous voulez utiliser, par exemple: `ollama pull mistral`
   - Assurez-vous que le nom du modèle dans `ChatViewModel` correspond à celui que vous avez installé

### Configuration dans Xcode
1. Créez un nouveau projet SwiftUI
2. Ajoutez SwiftData à votre projet
3. Copiez le code complet
4. Assurez-vous d'activer SwiftData dans les capacités du projet

### Fonctionnalités
1. **Conversation**: Tapez un message et envoyez-le pour communiquer avec le modèle Ollama.
2. **Persistance**: Tous les messages sont automatiquement sauvegardés via SwiftData.
3. **Historique**: L'historique est chargé automatiquement au démarrage de l'application.
4. **Effacement**: Vous pouvez effacer l'historique complet avec le bouton corbeille.

### Personnalisation
- **Modèle de langage**: Modifiez `modelName` dans `ChatViewModel` selon le modèle Ollama installé.
- **Interface**: Personnalisez les couleurs et le style des bulles de message dans `MessageBubble`.
- **URL du serveur**: Si vous exécutez Ollama sur une autre machine, modifiez `ollamaURL`.


