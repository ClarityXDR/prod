package middleware

import (
	"context"
	"net/http"
	"os"
	"strings"

	"github.com/golang-jwt/jwt/v4"
)

type contextKey string

const UserContextKey contextKey = "user"

type Claims struct {
	UserID   int    `json:"user_id"`
	Email    string `json:"email"`
	Role     string `json:"role"`
	ClientID string `json:"client_id,omitempty"`
	jwt.RegisteredClaims
}

func AuthMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Skip auth for certain endpoints
		if r.URL.Path == "/api/health" || r.URL.Path == "/api/auth/login" {
			next.ServeHTTP(w, r)
			return
		}

		// Get token from Authorization header
		authHeader := r.Header.Get("Authorization")
		if authHeader == "" {
			http.Error(w, "Missing authorization header", http.StatusUnauthorized)
			return
		}

		// Extract token
		tokenString := strings.Replace(authHeader, "Bearer ", "", 1)

		// Parse and validate token
		token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
			return []byte(os.Getenv("JWT_SECRET")), nil
		})

		if err != nil || !token.Valid {
			http.Error(w, "Invalid token", http.StatusUnauthorized)
			return
		}

		// Add claims to context
		if claims, ok := token.Claims.(*Claims); ok {
			ctx := context.WithValue(r.Context(), UserContextKey, claims)
			next.ServeHTTP(w, r.WithContext(ctx))
		} else {
			http.Error(w, "Invalid token claims", http.StatusUnauthorized)
			return
		}
	})
}

func RequireRole(role string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			claims, ok := r.Context().Value(UserContextKey).(*Claims)
			if !ok || claims.Role != role {
				http.Error(w, "Insufficient permissions", http.StatusForbidden)
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}
