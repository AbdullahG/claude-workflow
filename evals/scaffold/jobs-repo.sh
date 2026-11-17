#!/usr/bin/env bash
# Fixture for inbtw evals: a small TS service with TypeORM installed but
# raw SQL for job listing (with a recorded reason), plus one real injection.
set -euo pipefail

mkdir -p src/jobs src/db
cat >package.json <<'EOF'
{
  "name": "jobs-service",
  "private": true,
  "dependencies": { "pg": "^8.11.0", "typeorm": "^0.3.20", "express": "^4.19.0" }
}
EOF

cat >src/db/data-source.ts <<'EOF'
import { DataSource } from 'typeorm';
import { User } from './user.entity';

// TypeORM is used for entities and simple CRUD (users, settings).
export const AppDataSource = new DataSource({
  type: 'postgres',
  url: process.env.DATABASE_URL,
  entities: [User],
});
EOF

cat >src/db/user.entity.ts <<'EOF'
import { Column, Entity, PrimaryGeneratedColumn } from 'typeorm';

@Entity('users')
export class User {
  @PrimaryGeneratedColumn('uuid') id!: string;
  @Column() email!: string;
}
EOF

cat >src/jobs/sql.ts <<'EOF'
const COLUMNS = 'id, type, status, result, error_code, created_at, completed_at';

export const LIST_SQL = `SELECT ${COLUMNS} FROM jobs
  WHERE user_id = $1 AND (created_at, id) < ($2, $3)
  ORDER BY created_at DESC, id DESC
  LIMIT $4`;

export const LIST_BY_STATUS_SQL = `SELECT ${COLUMNS} FROM jobs
  WHERE user_id = $1 AND status = $5 AND (created_at, id) < ($2, $3)
  ORDER BY created_at DESC, id DESC
  LIMIT $4`;

export const EXPORT_SQL = `SELECT id, type, status, error_code, created_at, completed_at FROM jobs
  WHERE user_id = $1
  ORDER BY created_at DESC, id DESC`;
EOF

cat >src/jobs/repository.ts <<'EOF'
import { AppDataSource } from '../db/data-source';
import { EXPORT_SQL, LIST_BY_STATUS_SQL, LIST_SQL } from './sql';

export async function listJobs(userId: string, cursor: { createdAt: Date; id: string }, limit: number, status?: string) {
  const params: unknown[] = [userId, cursor.createdAt, cursor.id, Math.min(limit, 100)];
  if (status) return AppDataSource.query(LIST_BY_STATUS_SQL, [...params, status]);
  return AppDataSource.query(LIST_SQL, params);
}

export async function exportJobs(userId: string) {
  return AppDataSource.query(EXPORT_SQL, [userId]);
}
EOF

cat >src/jobs/filter.ts <<'EOF'
import type { Request, Response } from 'express';
import { AppDataSource } from '../db/data-source';

// Admin search across all users' jobs.
export async function searchJobs(req: Request, res: Response) {
  const type = String(req.query.type ?? '');
  const rows = await AppDataSource.query(
    `SELECT id, type, status FROM jobs WHERE type = '${type}' ORDER BY created_at DESC LIMIT 50`,
  );
  res.json(rows);
}
EOF

git init -q
git config user.email eval@example.com
git config user.name eval
git add package.json src/db
git commit -qm "Add TypeORM data source and User entity"
git add src/jobs/sql.ts src/jobs/repository.ts
git commit -qm "jobs: keyset pagination with raw SQL

TypeORM's QueryBuilder cannot express a row-value comparison
(created_at, id) < (\$2, \$3), which the composite index
jobs(user_id, created_at DESC, id DESC) needs to stay index-only.
OFFSET pagination was timing out past page ~200, so listing uses
parameterized raw SQL."
git add src/jobs/filter.ts
git commit -qm "jobs: admin search by type"
