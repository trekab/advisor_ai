# Advisor AI - Financial Advisor Assistant

A comprehensive Rails 8 application that integrates Gmail, Google Calendar, and HubSpot CRM with AI-powered features to help financial advisors manage their client relationships more effectively.

## 🚀 Features

### Core Integrations
- **Gmail Integration**: Sync emails, search through conversations, and analyze client communications
- **Google Calendar**: Manage appointments and schedule meetings with clients
- **HubSpot CRM**: Track leads, manage contacts, and maintain client relationships
- **AI-Powered Chat**: Intelligent assistant using Ollama for context-aware responses

### AI & Intelligence
- **RAG (Retrieval-Augmented Generation)**: Semantic search through emails and documents
- **Tool Calling**: AI can execute actions like sending emails, creating calendar events, and updating CRM records
- **Task Management**: Create, track, and manage client-related tasks
- **Smart Context Retrieval**: AI automatically finds relevant information from your integrated data sources

### User Experience
- **Modern UI**: Clean, responsive design with smooth animations
- **Real-time Updates**: Live sync status and notifications
- **Progressive Web App**: Installable on mobile and desktop devices
- **Enhanced Loading States**: Engaging animations for AI responses

## 🏗️ Architecture

### Technology Stack
- **Backend**: Ruby on Rails 8
- **Database**: PostgreSQL with pgvector extension for vector search
- **AI**: Ollama (local LLM) with custom embeddings
- **Authentication**: OAuth 2.0 (Google, HubSpot)
- **Background Jobs**: Good Job for email synchronization
- **Vector Search**: pgvector for semantic similarity

### Key Components
- **Models**: User, Email, Message, Instruction, Task
- **Services**: GmailClient, EmbeddingService, EmailSearchService, ToolRegistry
- **Controllers**: Sessions, Messages, Instructions, Dashboard
- **Jobs**: GmailSyncJob for background email processing

## 📋 Prerequisites

Before running this application, ensure you have:

- Ruby 3.3+ installed
- PostgreSQL 12+ with pgvector extension
- Node.js 18+ (for asset compilation)
- Ollama installed and running locally
- Google Cloud Platform account with OAuth credentials
- HubSpot developer account

## 🛠️ Installation & Setup

### 1. Clone the Repository
```bash
git clone <repository-url>
cd advisor_ai
```

### 2. Install Dependencies
```bash
# Install Ruby gems
bundle install

# Install Node.js dependencies (if any)
npm install
```

### 3. Database Setup
```bash
# Create and setup database
bin/rails db:create
bin/rails db:migrate
bin/rails db:seed
```

### 4. Environment Configuration
Create a `.env` file in the root directory with the following variables:

```env
# Google OAuth
GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_client_secret

# HubSpot OAuth
HUBSPOT_CLIENT_ID=your_hubspot_client_id
HUBSPOT_CLIENT_SECRET=your_hubspot_client_secret

# Database
DATABASE_URL=postgresql://username:password@localhost:5432/advisor_ai_development

# Rails
RAILS_MASTER_KEY=your_rails_master_key
SECRET_KEY_BASE=your_secret_key_base

# Ollama
OLLAMA_BASE_URL=http://localhost:11434
```

### 5. Google Cloud Platform Setup
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable Gmail API and Google Calendar API
4. Create OAuth 2.0 credentials
5. Add authorized redirect URIs:
   - `http://localhost:3000/auth/google_oauth2/callback` (development)
   - `https://your-domain.com/auth/google_oauth2/callback` (production)

### 6. HubSpot Setup
1. Go to [HubSpot Developer Portal](https://developers.hubspot.com/)
2. Create a new app
3. Configure OAuth settings
4. Add redirect URIs:
   - `http://localhost:3000/auth/hubspot/callback` (development)
   - `https://your-domain.com/auth/hubspot/callback` (production)

### 7. Ollama Setup
```bash
# Install Ollama (macOS)
curl -fsSL https://ollama.ai/install.sh | sh

# Start Ollama service
ollama serve

# Pull a model (in another terminal)
ollama pull llama3.2:3b
```

## 🚀 Running the Application

### Development Mode
```bash
# Start the development server
bin/dev
```

The application will be available at `http://localhost:3000`

### Production Mode
```bash
# Precompile assets
bin/rails assets:precompile

# Start production server
bin/rails server -e production
```

## 📱 Usage Guide

### 1. Initial Setup
1. Visit the application homepage
2. Click "Sign in with Google" to authenticate
3. Grant necessary permissions for Gmail and Calendar access
4. Connect HubSpot account for CRM integration

### 2. Email Management
- **Sync Emails**: Background job automatically syncs recent emails
- **Search**: Use semantic search to find relevant client communications
- **AI Analysis**: Ask AI to analyze email threads and extract insights

### 3. Calendar Integration
- **View Events**: See upcoming appointments and meetings
- **Create Events**: AI can help schedule new meetings
- **Sync**: Automatic sync with Google Calendar

### 4. HubSpot CRM
- **Contact Management**: View and update client information
- **Lead Tracking**: Monitor lead status and progression
- **Integration**: Seamless data flow between email/calendar and CRM

### 5. AI Assistant
- **Chat Interface**: Natural language interaction
- **Context Awareness**: AI has access to your emails, calendar, and CRM data
- **Task Creation**: AI can create and manage tasks for you
- **Tool Execution**: AI can perform actions like sending emails or updating records

### 6. Task Management
- **Create Tasks**: Manual or AI-generated tasks
- **Track Progress**: Monitor task completion status
- **Organize**: Categorize tasks by client or priority

## 🔧 Configuration

### Database Configuration
The application uses PostgreSQL with the pgvector extension for vector search capabilities. Ensure your database supports this extension.

### Background Jobs
Email synchronization runs as background jobs using Good Job. Monitor job status in the Rails console or admin interface.

### AI Model Configuration
The application is configured to use Ollama with the `llama3.2:3b` model by default. You can change this in the `EmbeddingService` and AI chat configuration.

## 🚀 Deployment

### Using ngrok (Development/Testing)
```bash
# Install ngrok
brew install ngrok

# Start your Rails server
bin/dev

# In another terminal, expose your local server
ngrok http 3000
```

Update your OAuth redirect URIs to include the ngrok URL.

### Production Deployment
The application includes Docker support for containerized deployment:

```bash
# Build Docker image
docker build -t advisor-ai .

# Run with Docker Compose
docker-compose up -d
```

### Environment Variables for Production
Ensure all environment variables are properly set in your production environment, including:
- Database credentials
- OAuth client secrets
- Rails master key
- Ollama service URL

## 🧪 Testing

```bash
# Run test suite
bin/rails test

# Run specific test files
bin/rails test test/models/user_test.rb

# Run with coverage
COVERAGE=true bin/rails test
```

## 📊 Monitoring & Logging

### Application Logs
- Development: `log/development.log`
- Production: `log/production.log`

### Background Job Monitoring
Monitor email sync jobs and their status through the Rails console or admin interface.

### Error Tracking
The application includes comprehensive error handling and logging for:
- OAuth authentication failures
- Email sync errors
- AI service errors
- Database connection issues

## 🔒 Security

### OAuth Security
- CSRF protection enabled for OAuth flows
- Secure token storage and rotation
- Proper redirect URI validation

### Data Protection
- Encrypted credentials storage
- Secure session management
- Input validation and sanitization

### API Security
- Rate limiting on API endpoints
- Proper authentication checks
- Secure parameter handling

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Troubleshooting

### Common Issues

#### Missing Gems Error
```bash
# If you see "Could not find gem" errors
bundle install
```

#### Database Connection Issues
```bash
# Reset database
bin/rails db:drop db:create db:migrate db:seed
```

#### OAuth Errors
- Verify redirect URIs in Google Cloud Console and HubSpot
- Check environment variables are correctly set
- Ensure OAuth scopes are properly configured

#### Ollama Connection Issues
```bash
# Check if Ollama is running
curl http://localhost:11434/api/tags

# Restart Ollama service
ollama serve
```

#### Email Sync Issues
- Check Gmail API quotas and limits
- Verify OAuth tokens are valid
- Monitor background job logs

### Getting Help
- Check the application logs for detailed error messages
- Review the Rails console for debugging information
- Ensure all services (PostgreSQL, Ollama) are running

## 🎯 Roadmap

### Planned Features
- [ ] Google Contacts integration
- [ ] Advanced analytics dashboard
- [ ] Email templates and automation
- [ ] Client portal
- [ ] Mobile app
- [ ] Advanced AI features (sentiment analysis, meeting summaries)

### Performance Improvements
- [ ] Caching layer for frequently accessed data
- [ ] Optimized vector search queries
- [ ] Background job optimization
- [ ] Database query optimization

---

**Advisor AI** - Empowering financial advisors with intelligent automation and AI-powered insights.
