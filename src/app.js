import feathers from '@feathersjs/feathers';
import express from '@feathersjs/express';
import socketio from '@feathersjs/socketio';
import { MemoryService } from '@feathersjs/memory';
import cors from 'cors';

// Create Express app with Feathers
const app = express(feathers());

// Enable CORS for all origins (adjust for production)
app.use(cors({
  origin: true,
  credentials: true
}));

// Parse JSON and URL-encoded data
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Configure REST API
app.configure(express.rest());

// Configure Socket.IO for real-time communication
app.configure(socketio({
  cors: {
    origin: '*',
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE']
  }
}, (io) => {
  // Socket.IO connection handlers
  io.on('connection', (socket) => {
    console.log('🔌 Client connected:', socket.id);
    console.log('🔌 Transport:', socket.conn.transport.name);

    // Handle ping/pong for connection testing
    socket.on('ping', (data) => {
      console.log('🏓 Received ping from client:', data);
      socket.emit('pong', data);
    });

    socket.on('disconnect', (reason) => {
      console.log('🔌 Client disconnected:', socket.id, 'Reason:', reason);
    });

    socket.on('error', (error) => {
      console.error('🔌 Socket error:', error);
    });
  });

  console.log('✅ Socket.IO server configured successfully');
}));

// Register services
app.use('/messages', new MemoryService({
  id: 'id',
  startId: 1,
  paginate: {
    default: 10,
    max: 50
  }
}));

// Add Users service for testing
app.use('/api/users', new MemoryService({
  id: 'id',
  startId: 1,
  paginate: {
    default: 10,
    max: 50
  }
}));

// Add Posts service for testing
app.use('/api/posts', new MemoryService({
  id: 'id',
  startId: 1,
  paginate: {
    default: 10,
    max: 50
  }
}));

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    version: '1.0.0',
    environment: process.env.NODE_ENV || 'development'
  });
});

// API info endpoint
app.get('/api/info', (req, res) => {
  res.json({
    name: 'Feathers Test API',
    version: '1.0.0',
    description: 'API for testing CI/CD pipelines',
    endpoints: [
      'GET /health',
      'GET /api/info',
      'GET /api/users',
      'POST /api/users',
      'GET /api/users/:id',
      'PUT /api/users/:id',
      'DELETE /api/users/:id',
      'GET /api/posts',
      'POST /api/posts',
      'GET /api/posts/:id',
      'PUT /api/posts/:id',
      'DELETE /api/posts/:id',
      'POST /api/auth/login',
      'POST /api/auth/register',
      'GET /api/stats',
      'GET /api/test/error',
      'GET /api/test/slow'
    ]
  });
});

// Authentication endpoints (mock)
app.post('/api/auth/login', (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({
      error: 'Email and password are required'
    });
  }

  // Mock authentication
  if (email === 'test@example.com' && password === 'password123') {
    res.json({
      success: true,
      token: 'mock-jwt-token-' + Date.now(),
      user: {
        id: 1,
        email,
        name: 'Test User'
      }
    });
  } else {
    res.status(401).json({
      error: 'Invalid credentials'
    });
  }
});

app.post('/api/auth/register', (req, res) => {
  const { email, password, name } = req.body;

  if (!email || !password || !name) {
    return res.status(400).json({
      error: 'Email, password, and name are required'
    });
  }

  // Mock registration
  res.status(201).json({
    success: true,
    message: 'User registered successfully',
    user: {
      id: Date.now(),
      email,
      name
    }
  });
});

// Stats endpoint
app.get('/api/stats', async (req, res) => {
  try {
    const messagesService = app.service('messages');
    const usersService = app.service('api/users');
    const postsService = app.service('api/posts');

    const [messages, users, posts] = await Promise.all([
      messagesService.find({ paginate: false }),
      usersService.find({ paginate: false }),
      postsService.find({ paginate: false })
    ]);

    res.json({
      stats: {
        messages: messages.length,
        users: users.length,
        posts: posts.length,
        uptime: process.uptime(),
        memory: process.memoryUsage(),
        timestamp: new Date().toISOString()
      }
    });
  } catch (error) {
    res.status(500).json({
      error: 'Failed to fetch stats',
      message: error.message
    });
  }
});

// Test endpoints for CI/CD testing
app.get('/api/test/error', (_req, res) => {
  // Intentional error for testing error handling
  res.status(500).json({
    error: 'This is a test error endpoint',
    code: 'TEST_ERROR',
    timestamp: new Date().toISOString()
  });
});

app.get('/api/test/slow', (_req, res) => {
  // Slow endpoint for testing timeouts
  setTimeout(() => {
    res.json({
      message: 'This endpoint took 3 seconds to respond',
      timestamp: new Date().toISOString()
    });
  }, 3000);
});

// Validation endpoint
app.post('/api/validate', (req, res) => {
  const { data } = req.body;

  if (!data) {
    return res.status(400).json({
      error: 'Data field is required'
    });
  }

  // Mock validation
  const isValid = typeof data === 'string' && data.length > 0;

  res.json({
    valid: isValid,
    data,
    length: data.length,
    timestamp: new Date().toISOString()
  });
});

// Configure channels for real-time events
app.on('connection', (connection) => {
  console.log('📡 New real-time connection established');
  // Join all clients to a general channel
  app.channel('everybody').join(connection);
});

// Publish all service events to everybody
app.publish((_data, hook) => {
  console.log(`📡 Publishing ${hook.service}:${hook.method} event to all clients`);
  return app.channel('everybody');
});

// Add service hooks for logging
app.service('messages').hooks({
  before: {
    all: [
      (context) => {
        console.log(`📝 ${context.method.toUpperCase()} /messages`, context.data || context.id || '');
        return context;
      }
    ]
  },
  after: {
    all: [
      (context) => {
        console.log(`✅ ${context.method.toUpperCase()} /messages completed`, context.result);
        console.log(`📡 Feathers real-time event should be emitted for: ${context.method}`);
        return context;
      }
    ]
  }
});

// Error handler
app.use(express.errorHandler({
  logger: console
}));

// Start server
const PORT = process.env.PORT || 3031;
const server = app.listen(PORT, () => {
  console.log('🚀 Feathers backend running on http://localhost:' + PORT);
  console.log('📡 Socket.IO enabled for real-time communication');
  console.log('🔗 Available endpoints:');
  console.log('');
  console.log('📨 Messages Service:');
  console.log('   GET    /messages     - Get all messages');
  console.log('   POST   /messages     - Create new message');
  console.log('   GET    /messages/:id - Get message by ID');
  console.log('   PUT    /messages/:id - Update message');
  console.log('   PATCH  /messages/:id - Patch message');
  console.log('   DELETE /messages/:id - Delete message');
  console.log('');
  console.log('👥 Users Service:');
  console.log('   GET    /api/users     - Get all users');
  console.log('   POST   /api/users     - Create new user');
  console.log('   GET    /api/users/:id - Get user by ID');
  console.log('   PUT    /api/users/:id - Update user');
  console.log('   PATCH  /api/users/:id - Patch user');
  console.log('   DELETE /api/users/:id - Delete user');
  console.log('');
  console.log('📝 Posts Service:');
  console.log('   GET    /api/posts     - Get all posts');
  console.log('   POST   /api/posts     - Create new post');
  console.log('   GET    /api/posts/:id - Get post by ID');
  console.log('   PUT    /api/posts/:id - Update post');
  console.log('   PATCH  /api/posts/:id - Patch post');
  console.log('   DELETE /api/posts/:id - Delete post');
  console.log('');
  console.log('🔐 Authentication:');
  console.log('   POST   /api/auth/login    - Login user');
  console.log('   POST   /api/auth/register - Register user');
  console.log('');
  console.log('📊 Utility Endpoints:');
  console.log('   GET    /health           - Health check');
  console.log('   GET    /api/info         - API information');
  console.log('   GET    /api/stats        - Service statistics');
  console.log('   POST   /api/validate     - Validate data');
  console.log('');
  console.log('🧪 Test Endpoints:');
  console.log('   GET    /api/test/error   - Test error handling');
  console.log('   GET    /api/test/slow    - Test slow response (3s)');
  console.log('');
  console.log('🎯 Perfect for CI/CD testing, code scanning, and API testing!');
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('🛑 SIGTERM received, shutting down gracefully');
  server.close(() => {
    console.log('✅ Server closed');
    process.exit(0);
  });
});

export default app;
