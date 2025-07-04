package models

import (
	"time"

	"golang.org/x/crypto/bcrypt"
)

// User roles
const (
	RoleUser          = "user"
	RoleAdmin         = "admin"
	RoleSalesAgent    = "sales_agent"
	RoleAccountingBot = "accounting_bot"
	RoleInvoicingBot  = "invoicing_bot"
)

// User represents a user in the system
type User struct {
	ID               int64     `json:"id"`
	Email            string    `json:"email"`
	PasswordHash     string    `json:"-"`
	FirstName        string    `json:"first_name"`
	LastName         string    `json:"last_name"`
	Company          string    `json:"company,omitempty"`
	Phone            string    `json:"phone,omitempty"`
	Role             string    `json:"role"`
	Active           bool      `json:"active"`
	VerifiedAt       time.Time `json:"verified_at,omitempty"`
	CreatedAt        time.Time `json:"created_at"`
	UpdatedAt        time.Time `json:"updated_at"`
	LastLoginAt      time.Time `json:"last_login_at,omitempty"`
	TwoFactorSecret  string    `json:"-"`
	TwoFactorEnabled bool      `json:"two_factor_enabled"`
	ApiToken         string    `json:"-"`
}

// UserService defines methods for user management
type UserService interface {
	Create(user *User, password string) error
	GetByEmail(email string) (*User, error)
	GetByID(id int64) (*User, error)
	Update(user *User) error
	Delete(id int64) error
	Authenticate(email, password string) (*User, error)
	ChangePassword(userID int64, currentPassword, newPassword string) error
	ResetPassword(userID int64, newPassword string) error
	GetUsersByRole(role string) ([]*User, error)
	VerifyEmail(token string) error
	GeneratePasswordResetToken(email string) (string, error)
	ValidatePasswordResetToken(token string) (int64, error)
	GetAllUsers() ([]*User, error)
}

// HashPassword creates a bcrypt hash from a plain text password
func HashPassword(password string) (string, error) {
	hashedBytes, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return "", err
	}
	return string(hashedBytes), nil
}

// CheckPassword compares a bcrypt hashed password with a plain text password
func CheckPassword(hashedPassword, password string) error {
	return bcrypt.CompareHashAndPassword([]byte(hashedPassword), []byte(password))
}
