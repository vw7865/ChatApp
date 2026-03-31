// src/plugins/rateLimit.ts
// Temporarily disabled to avoid Fastify version conflict

import type { FastifyInstance } from 'fastify';

const rateLimitPlugin = async (fastify: FastifyInstance) => {
  console.log('⚠️  Rate limit plugin disabled for development');
};

export default rateLimitPlugin;