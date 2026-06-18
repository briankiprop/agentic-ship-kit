# Security Rules

Apply to all code changes.

## Required checks

- Validate external input.
- Enforce server-side authorization.
- Do not expose secrets in logs, errors, tests, snapshots, or docs.
- Use safe database query patterns.
- Check permissions on every user-owned resource.
- Avoid leaking whether a user/email/account exists unless product requirements allow it.
- Add regression tests for security fixes.
- Check dependency risk when adding new packages.

## Blockers

Block the change if it:

- Stores plaintext passwords or tokens.
- Logs credentials, session cookies, reset tokens, API keys, or private data.
- Bypasses authentication or authorization.
- Disables CSRF, CORS, rate limiting, or validation without explicit approval.
- Adds a dependency with known critical vulnerabilities without justification.

## Language-specific patterns

### Node / TypeScript

```ts
// Parameterized query (pg)
const result = await pool.query('SELECT * FROM users WHERE id = $1', [userId]);

// Never interpolate user input
// BAD:  `SELECT * FROM users WHERE id = ${userId}`

// Secrets from environment only
const secret = process.env.JWT_SECRET;
if (!secret) throw new Error('JWT_SECRET not set');

// Input validation (zod)
const schema = z.object({ email: z.string().email(), age: z.number().int().min(0) });
const parsed = schema.parse(req.body); // throws on invalid input
```

### Python / FastAPI / SQLAlchemy

```python
# Parameterized query (psycopg2)
cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))

# SQLAlchemy ORM (safe by default)
user = db.query(User).filter(User.id == user_id).first()

# Never use f-strings in raw SQL
# BAD:  cursor.execute(f"SELECT * FROM users WHERE id = {user_id}")

# Secrets from environment only
import os
secret = os.environ["JWT_SECRET"]  # KeyError if missing — fail fast

# Input validation (pydantic)
class UserIn(BaseModel):
    email: EmailStr
    age: int = Field(ge=0)
```

### Ruby on Rails

```ruby
# Parameterized query (ActiveRecord)
User.where("email = ?", params[:email])
User.find_by(id: params[:id])   # safe

# Never interpolate into where strings
# BAD:  User.where("email = '#{params[:email]}'")

# Secrets from credentials or ENV
secret = Rails.application.credentials.jwt_secret || ENV.fetch("JWT_SECRET")

# Strong parameters (always whitelist)
def user_params
  params.require(:user).permit(:name, :email)
end
```

### General secret handling

- Load secrets from environment variables or a secrets manager — never hardcode.
- Never log request bodies that may contain passwords, tokens, or card numbers.
- Rotate any secret accidentally committed to git immediately.
- Use `npm audit` / `pip-audit` / `bundle audit` before every release.
