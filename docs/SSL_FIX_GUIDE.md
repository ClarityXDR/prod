# ClarityXDR SSL Configuration Fix

## Problem Description

The ClarityXDR backend is failing to connect to PostgreSQL with the error:
```
Failed to connect to database: failed to ping database: pq: SSL is not enabled on the server
```

This happens because the backend expects SSL to be enabled on PostgreSQL, but the default PostgreSQL container doesn't have SSL configured.

## Quick Fix (Immediate Solution)

### Option 1: Run the Quick Fix Script

```bash
cd /opt/clarityxdr
sudo bash /path/to/clarityxdr/docker/scripts/quick-fix-ssl.sh
```

### Option 2: Manual Fix

1. **Update the .env file:**
   ```bash
   cd /opt/clarityxdr
   echo "DB_SSL_MODE=disable" >> .env
   ```

2. **Restart the services:**
   ```bash
   docker-compose down
   docker-compose up -d
   ```

3. **Check if the backend is now healthy:**
   ```bash
   docker-compose ps
   docker logs clarityxdr-backend
   ```

## Permanent SSL Solution

If you want to enable proper SSL support for PostgreSQL:

### Step 1: Enable SSL on PostgreSQL

```bash
cd /opt/clarityxdr
sudo bash /path/to/clarityxdr/docker/scripts/enable-ssl.sh
```

### Step 2: Update Environment Configuration

```bash
# Edit .env file
nano .env

# Change this line:
DB_SSL_MODE=disable

# To this:
DB_SSL_MODE=require
```

### Step 3: Restart Backend Service

```bash
docker-compose restart backend
```

## Understanding SSL Modes

| SSL Mode | Description |
|----------|-------------|
| `disable` | No SSL connection (fastest, least secure) |
| `allow` | Try SSL first, fall back to non-SSL |
| `prefer` | Try SSL first, but allow non-SSL (default) |
| `require` | Require SSL, fail if not available |
| `verify-ca` | Require SSL and verify certificate authority |
| `verify-full` | Require SSL and verify hostname |

## Production Recommendations

For production environments, follow these steps in order:

1. **Start with SSL disabled** (immediate fix)
2. **Set up proper SSL certificates** (use the enable-ssl.sh script)
3. **Update to SSL required mode** (change DB_SSL_MODE=require)
4. **Test thoroughly** before going live

## Troubleshooting

### Check Backend Logs
```bash
docker logs clarityxdr-backend --tail 50
```

### Check PostgreSQL SSL Status
```bash
docker exec clarityxdr-postgres psql -U postgres -d postgres -c "SHOW ssl;"
```

### Test Database Connection
```bash
docker exec clarityxdr-backend sh -c 'ping postgres'
```

### Check Environment Variables
```bash
docker exec clarityxdr-backend env | grep DB_
```

## Files Modified

1. `/docker/docker-compose.yml` - Changed default SSL mode to `disable`
2. `/docker/.env.example` - Updated example configuration
3. `/install.sh` - Added SSL mode configuration to generated files
4. `/docker/scripts/quick-fix-ssl.sh` - New quick fix script
5. `/docker/scripts/enable-ssl.sh` - New SSL enablement script
6. `/docker/init-scripts/01-configure-ssl.sh` - PostgreSQL SSL initialization

## Next Steps

1. Apply the quick fix to get your system running
2. Monitor logs to ensure everything is working
3. Plan SSL enablement for production security
4. Consider using proper SSL certificates for production

## Support

If you continue to experience issues:

1. Check Docker logs: `docker-compose logs`
2. Verify network connectivity between containers
3. Ensure all environment variables are properly set
4. Review PostgreSQL and backend configurations
