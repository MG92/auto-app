#!/bin/bash
set -e

##############################################
#         BACKEND (DJANGO) CONFIGURATION     #
##############################################

echo "Changing to backend directory..."
cd django-react-app/backend || { echo "Directory not found: django-react-app/backend"; exit 1; }

# --- Create the accounts app if it doesn't exist ---
if [ ! -d "accounts" ]; then
  echo "Creating accounts app..."
  python3 manage.py startapp accounts
else
  echo "Accounts app already exists."
fi

echo "Setting up Django user authentication functionality..."

# --- Create templates directory for authentication ---
mkdir -p accounts/templates/registration

# --- Create authentication templates ---

# Login template
cat > accounts/templates/registration/login.html << 'EOF'
{% extends "base.html" %}
{% block content %}
<h2>Login</h2>
<form method="post">
  {% csrf_token %}
  {{ form.as_p }}
  <button type="submit">Login</button>
</form>
{% endblock %}
EOF

# Signup (registration) template
cat > accounts/templates/registration/signup.html << 'EOF'
{% extends "base.html" %}
{% block content %}
<h2>Register</h2>
<form method="post">
  {% csrf_token %}
  {{ form.as_p }}
  <button type="submit">Sign Up</button>
</form>
{% endblock %}
EOF

# Password reset templates
cat > accounts/templates/registration/password_reset_form.html << 'EOF'
{% extends "base.html" %}
{% block content %}
<h2>Password Reset</h2>
<form method="post">
  {% csrf_token %}
  {{ form.as_p }}
  <button type="submit">Reset Password</button>
</form>
{% endblock %}
EOF

cat > accounts/templates/registration/password_reset_done.html << 'EOF'
{% extends "base.html" %}
{% block content %}
<h2>Password Reset Sent</h2>
<p>We've emailed you instructions for resetting your password. Check your spam folder if necessary.</p>
{% endblock %}
EOF

cat > accounts/templates/registration/password_reset_confirm.html << 'EOF'
{% extends "base.html" %}
{% block content %}
<h2>Enter New Password</h2>
<form method="post">
  {% csrf_token %}
  {{ form.as_p }}
  <button type="submit">Change Password</button>
</form>
{% endblock %}
EOF

cat > accounts/templates/registration/password_reset_complete.html << 'EOF'
{% extends "base.html" %}
{% block content %}
<h2>Password Reset Complete</h2>
<p>Your password has been successfully reset. You may now <a href="{% url 'login' %}">log in</a>.</p>
{% endblock %}
EOF

# --- Create accounts/urls.py with all authentication routes ---
cat > accounts/urls.py << 'EOF'
from django.urls import path
from django.contrib.auth import views as auth_views
from .views import UserRegisterView

urlpatterns = [
    path('login/', auth_views.LoginView.as_view(template_name='registration/login.html'), name='login'),
    path('logout/', auth_views.LogoutView.as_view(next_page='/'), name='logout'),
    path('register/', UserRegisterView.as_view(), name='register'),
    path('password-reset/', auth_views.PasswordResetView.as_view(template_name='registration/password_reset_form.html'), name='password_reset'),
    path('password-reset/done/', auth_views.PasswordResetDoneView.as_view(template_name='registration/password_reset_done.html'), name='password_reset_done'),
    path('password-reset-confirm/<uidb64>/<token>/', auth_views.PasswordResetConfirmView.as_view(template_name='registration/password_reset_confirm.html'), name='password_reset_confirm'),
    path('password-reset-complete/', auth_views.PasswordResetCompleteView.as_view(template_name='registration/password_reset_complete.html'), name='password_reset_complete'),
]
EOF

# --- Create a simple registration view in accounts/views.py ---
cat > accounts/views.py << 'EOF'
from django.urls import reverse_lazy
from django.views.generic.edit import CreateView
from django.contrib.auth.forms import UserCreationForm

class UserRegisterView(CreateView):
    form_class = UserCreationForm
    template_name = 'registration/signup.html'
    success_url = reverse_lazy('login')
EOF

# --- Update settings.py with redirect URLs ---
if [ -f backend/settings.py ]; then
  sed -i '' '/LOGIN_REDIRECT_URL/d' backend/settings.py
  sed -i '' '/LOGOUT_REDIRECT_URL/d' backend/settings.py
  echo "LOGIN_REDIRECT_URL = '/'" >> backend/settings.py
  echo "LOGOUT_REDIRECT_URL = '/'" >> backend/settings.py
  echo "Updated backend/settings.pywith redirect URLs."
else
  echo "Error: settings.py not found in backend directory." 
  exit 1
fi

# --- Include accounts URLs in main urls.py if not already present ---
if [ -f backend/urls.py ]; then
  if ! grep -q "include('accounts.urls')" backend/urls.py; then
    # Ensure 'include' is imported.
    if ! grep -q "from django.urls import" backend/urls.py; then
        # Add the import at the beginning
      sed -i'' '1s/^/from django.urls import include, path\n\n/' backend/urls.py
    fi
    sed -i '' "s/urlpatterns = \[/urlpatterns = \[\n    path('accounts\/', include('accounts.urls')),/" backend/urls.py

    echo "Included accounts URLs in backend/urls.py."
  else
    echo "Accounts URLs already included in backend/urls.py."
  fi
else
  echo "WARNING: backend/urls.py not found. Please manually include accounts.urls in your project's URL configuration."
fi

echo "Django user authentication setup completed."

##############################################
#         FRONTEND (REACT) COMPONENTS        #
##############################################

echo "Changing to frontend directory..."

# Assuming the project structure: django-react-app/frontend
cd ../.. || { echo "Error navigating to project root."; exit 1; }
cd django-react-app/frontend || { echo "Frontend directory not found: django-react-app/frontend"; exit 1; }

# Create the auth components directory in React if it doesn't exist
mkdir -p src/components/auth
cd src/components/auth

# --- Create Login.jsx component ---
cat > Login.jsx << 'EOF'
import React, { useState } from "react";

const Login = () => {
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      const response = await fetch("/api/login/", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ username, password })
      });
      if (response.ok) {
        console.log("Logged in successfully");
      } else {
        console.error("Login failed");
      }
    } catch (error) {
      console.error("Error during login:", error);
    }
  };

  return (
    <div>
      <h2>Login</h2>
      <form onSubmit={handleSubmit}>
        <label>Username:
          <input type="text" value={username} onChange={e => setUsername(e.target.value)} />
        </label>
        <br/>
        <label>Password:
          <input type="password" value={password} onChange={e => setPassword(e.target.value)} />
        </label>
        <br/>
        <button type="submit">Login</button>
      </form>
    </div>
  );
};

export default Login;
EOF

# --- Create Register.jsx component ---
cat > Register.jsx << 'EOF'
import React, { useState } from "react";

const Register = () => {
  const [username, setUsername] = useState("");
  const [password1, setPassword1] = useState("");
  const [password2, setPassword2] = useState("");

  const handleSubmit = async (e) => {
    e.preventDefault();
    if(password1 !== password2) {
      alert("Passwords do not match.");
      return;
    }
    try {
      const response = await fetch("/api/register/", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ username, password: password1 })
      });
      if (response.ok) {
        console.log("Registration successful");
      } else {
        console.error("Registration failed");
      }
    } catch (error) {
      console.error("Error during registration:", error);
    }
  };

  return (
    <div>
      <h2>Register</h2>
      <form onSubmit={handleSubmit}>
        <label>Username:
          <input type="text" value={username} onChange={e => setUsername(e.target.value)} />
        </label>
        <br/>
        <label>Password:
          <input type="password" value={password1} onChange={e => setPassword1(e.target.value)} />
        </label>
        <br/>
        <label>Confirm Password:
          <input type="password" value={password2} onChange={e => setPassword2(e.target.value)} />
        </label>
        <br/>
        <button type="submit">Register</button>
      </form>
    </div>
  );
};

export default Register;
EOF

# --- Create PasswordReset.jsx component ---
cat > PasswordReset.jsx << 'EOF'
import React, { useState } from "react";

const PasswordReset = () => {
  const [email, setEmail] = useState("");

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      const response = await fetch("/api/password-reset/", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email })
      });
      if (response.ok) {
        console.log("Password reset email sent");
      } else {
        console.error("Password reset failed");
      }
    } catch (error) {
      console.error("Error during password reset:", error);
    }
  };

  return (
    <div>
      <h2>Password Reset</h2>
      <form onSubmit={handleSubmit}>
        <label>Email:
          <input type="email" value={email} onChange={e => setEmail(e.target.value)} />
        </label>
        <br/>
        <button type="submit">Send Reset Email</button>
      </form>
    </div>
  );
};

export default PasswordReset;
EOF

# --- Create PasswordResetConfirm.jsx component ---
cat > PasswordResetConfirm.jsx << 'EOF'
import React, { useState } from "react";
import { useParams } from "react-router-dom";

const PasswordResetConfirm = () => {
  const { uid, token } = useParams();
  const [newPassword, setNewPassword] = useState("");

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      const response = await fetch(\`/api/password-reset-confirm/\${uid}/\${token}/\`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ new_password: newPassword })
      });
      if (response.ok) {
        console.log("Password reset successful");
      } else {
        console.error("Password reset failed");
      }
    } catch (error) {
      console.error("Error during password reset confirmation:", error);
    }
  };

  return (
    <div>
      <h2>Reset Your Password</h2>
      <form onSubmit={handleSubmit}>
        <label>New Password:
          <input type="password" value={newPassword} onChange={e => setNewPassword(e.target.value)} />
        </label>
        <br/>
        <button type="submit">Reset Password</button>
      </form>
    </div>
  );
};

export default PasswordResetConfirm;
EOF

# --- Create PasswordResetComplete.jsx component ---
cat > PasswordResetComplete.jsx << 'EOF'
import React from "react";

const PasswordResetComplete = () => {
  return (
    <div>
      <h2>Password Reset Complete</h2>
      <p>Your password has been successfully reset. Please log in with your new password.</p>
    </div>
  );
};

export default PasswordResetComplete;
EOF

# Return to the frontend directory
cd ../../../


cat > src/components/NavigationBar.jsx << 'EOF'
import React from 'react';
import { Navbar, Nav, Container, Button } from 'react-bootstrap';
import { Link } from 'react-router-dom';

const NavigationBar = ({ isAuthenticated, handleLogout }) => {
    return (
        <Navbar bg="light" expand="lg">
            <Container>
                <Navbar.Brand as={Link} to="/">MyApp</Navbar.Brand>
                <Navbar.Toggle aria-controls="basic-navbar-nav" />
                <Navbar.Collapse id="basic-navbar-nav">
                    <Nav className="me-auto">
                        <Nav.Link as={Link} to="/">Home</Nav.Link>
                        {isAuthenticated && <Nav.Link as={Link} to="/account">My Account</Nav.Link>}
                    </Nav>
                    <Nav>
                        {isAuthenticated ? (
                            <Button variant="outline-danger" onClick={handleLogout}>Logout</Button>
                        ) : (
                            <Button variant="outline-success" as={Link} to="/login">Login</Button>
                        )}
                    </Nav>
                </Navbar.Collapse>
            </Container>
        </Navbar>
    );
};

export default NavigationBar;

EOF

# Update app.jsx to include the new components
echo "Creating a correct App.jsx file..."


# Overwrite/create the file with the correct contents
cat > src/App.jsx << 'EOF'
import React, { useState } from "react";
import { BrowserRouter, Outlet, Route, Routes } from "react-router-dom";
import Login from "./components/auth/Login";
import Register from "./components/auth/Register";
import ItemList from "./components/ItemList";
import AddItem from "./components/AddItem";
import "./App.css";
import NavigationBar from './components/NavigationBar';

const PrivateRoute = () => {
  console.log('local storage: ', localStorage)
  const token = localStorage.getItem('token');
  return token ? <Outlet /> : <Navigate to="/login" />;
};

function App() {
  // Constant for user authentication status
  const [isAuthenticated, setIsAuthenticated] = useState(false);

  // Method for logging out
  const handleLogout = () => {
    localStorage.removeItem('token');
    setIsAuthenticated(false);
    console.log("User logged out");
  };

  return (
    <BrowserRouter>
        <NavigationBar isAuthenticated={isAuthenticated} handleLogout={handleLogout} />

        <Routes>
          <Route
            path="/login"
            element={<Login onLogin={() => setIsAuthenticated(true)} />}
          />
          <Route path="/register" element={<Register />} />
          <Route path="/" element={
            <div>
              <ItemList />
              <AddItem />
            </div>
          } />
        </Routes>
    </BrowserRouter>
  );
}

export default App;
EOF

echo "Updated App.jsx file successfully."

echo "Frontend authentication components created successfully in src/components/auth."
