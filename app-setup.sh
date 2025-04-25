#!/bin/bash

# Function to check if a command is available
check_command() {
  command -v "$1" >/dev/null 2>&1 || { echo >&2 "Error: $1 is not installed."; exit 1; }
}

# # Check for Homebrew (macOS package manager)
# if ! command -v brew >/dev/null 2>&1; then
#   echo "Homebrew not found. Installing..."
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
# fi

# # Install dependencies via Homebrew
# echo "Installing dependencies..."
# brew install postgresql

# Start PostgreSQL service
echo "Starting PostgreSQL service..."
brew services start postgresql

# Set up PostgreSQL database
echo "Creating PostgreSQL database..."
psql postgres -c "CREATE DATABASE app_db;"

# Create directories for the app
echo "Creating project directories..."
mkdir -p django-react-app/backend django-react-app/frontend
cd django-react-app


# Set up Django backend
echo "Setting up Django backend..."
cd backend
cat > environment.yml << EOF
name: django-react-app
channels:
  - defaults
dependencies:
  - python=3.10
  - pip
  - pytorch
  - pip:
    - django
    - djangorestframework
    - django-cors-headers
    - djangorestframework-simplejwt
    - jupter
    - numpy
    - pandas
    - psycopg2
    - python-dotenv 
    - pytorch-lightning
    - requests
    - tensorboard
    - torcheval
EOF

# Create Conda environment
conda init

if conda env list | grep -q "django-react-app"; then
  echo "Conda environment 'django-react-app' already exists. Activating..."
  conda activate django-react-app
else
  echo "Creating Conda environment..."
  conda env create -f environment.yml
  conda activate django-react-app
fi

# Create Django app and model
if [ -f manage.py ]; then
  echo "Django project already exists. Skipping creation..."
else
  django-admin startproject backend .
fi

if [ -d api ]; then
  echo "The 'api' app already exists. Skipping creation..."
else
  echo "Creating 'api' app..."
  python manage.py startapp api
fi

# Add the app to INSTALLED_APPS in settings.py
if [ -f backend/settings.py ]; then
  # Only append 'api' if it doesn't already exist in INSTALLED_APPS
  if ! grep -q "'api'" backend/settings.py && ! grep -q "\"api\"" backend/settings.py; then
    sed -i '' "/INSTALLED_APPS = \[/,/]/ s/]$/ 'api',\n]/" backend/settings.py
    echo "Added 'api' to INSTALLED_APPS."
  else
    echo "'api' is already in INSTALLED_APPS."
  fi
else
  echo "Error: settings.py not found."
  exit 1
fi

# Create the Item model
cat > api/models.py << EOF
from django.db import models

class Item(models.Model):
    name = models.CharField(max_length=100)
    description = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.name
EOF

# Create views for the model
cat > api/views.py << EOF
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.shortcuts import get_object_or_404
from .models import Item
import json

@csrf_exempt
def item_list(request):
    if request.method == 'GET':
        items = list(Item.objects.values())
        return JsonResponse(items, safe=False)
    elif request.method == 'POST':
        data = json.loads(request.body)
        item = Item.objects.create(name=data['name'], description=data['description'])
        return JsonResponse({'id': item.id, 'name': item.name, 'description': item.description})

@csrf_exempt
def item_detail(request, pk):
    item = get_object_or_404(Item, pk=pk)
    if request.method == 'GET':
        return JsonResponse({'id': item.id, 'name': item.name, 'description': item.description})
    elif request.method == 'PUT':
        data = json.loads(request.body)
        item.name = data['name']
        item.description = data['description']
        item.save()
        return JsonResponse({'id': item.id, 'name': item.name, 'description': item.description})
    elif request.method == 'DELETE':
        item.delete()
        return JsonResponse({'message': 'Item deleted'})
EOF

# Define URL patterns
cat > api/urls.py << EOF
from django.urls import path
from . import views

urlpatterns = [
    path('items/', views.item_list),
    path('items/<int:pk>/', views.item_detail),
]
EOF

echo "$(ls)"

# Include the app's URLs in the project
if [ -f backend/urls.py ]; then
  # Check if the import statement already exists in actual code (not comments)
  if grep -q "^from django.urls[[:space:]]*import[[:space:]]*include$" backend/urls.py; then
    echo "Import statement for include already exists."
  else
    # Insert the import statement at the top of the file
    sed -i '' '1i\
from django.urls import include\
' backend/urls.py
    echo "Added import statement for include."
  fi


  # Check if the api.urls path already exists
  if ! grep -q "path('api/', include('api.urls'))" backend/urls.py && ! grep -q "path(\"api/\", include(\"api.urls\"))" backend/urls.py; then
    # Using sed to add the path with a newline after it
    sed -i '' "/urlpatterns = \[/a\\
    path('api/', include('api.urls')),\\
" backend/urls.py
    echo "Added api urls path to urlpatterns."
  else
    echo "api urls path already exists in urlpatterns."
  fi
else
  echo "Error: urls.py not found."
  exit 1
fi

# Configure Django for PostgreSQL
echo "Configuring Django backend for PostgreSQL..."
sed -i '' "s/'ENGINE': 'django.db.backends.sqlite3',/'ENGINE': 'django.db.backends.postgresql',/" backend/settings.py
sed -i '' "s/'NAME': BASE_DIR \/ 'db.sqlite3'/'NAME': 'app_db'/g" backend/settings.py
sed -i '' "s/# 'USER': 'your_username'/'USER': 'your_postgres_username'/g" backend/settings.py
sed -i '' "s/# 'PASSWORD': 'your_password'/'PASSWORD': 'your_postgres_password'/g" backend/settings.py

# Migrate the database
echo "Migrating database..."
python manage.py makemigrations api
python manage.py migrate


# Return to project root
cd ../
echo "$(ls)"

# Set up React frontend
check_command node
check_command npm

echo "Setting up React frontend..."


npm create vite@latest frontend --template react
cd frontend
npm install
npm install react-router-dom
npm install react-bootstrap

# Create React components
echo "Creating React components..."
mkdir -p src/components

cat > src/components/ItemList.jsx << EOF
import React, { useState, useEffect } from 'react';

function ItemList() {
    const [items, setItems] = useState([]);

    useEffect(() => {
        fetch('/api/items/')
            .then(response => response.json())
            .then(data => setItems(data));
    }, []);

    return (
        <div>
            <h1>Item List</h1>
            <ul>
                {items.map(item => (
                    <li key={item.id}>
                        <strong>{item.name}</strong>: {item.description}
                    </li>
                ))}
            </ul>
        </div>
    );
}

export default ItemList;
EOF

cat > src/components/AddItem.jsx << EOF
import React, { useState } from 'react';

function AddItem() {
    const [name, setName] = useState('');
    const [description, setDescription] = useState('');

    const handleSubmit = (e) => {
        e.preventDefault();
        fetch('/api/items/', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ name, description })
        })
        .then(response => response.json())
        .then(() => {
            setName('');
            setDescription('');
        });
    };

    return (
        <form onSubmit={handleSubmit}>
            <h1>Add Item</h1>
            <input
                type="text"
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="Name"
            />
            <textarea
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                placeholder="Description"
            ></textarea>
            <button type="submit">Add</button>
        </form>
    );
}

export default AddItem;
EOF

# Update React App to use the components

# # Check if App.jsx exists
# if [ -f src/App.jsx ]; then
#   echo "Updating App.jsx file..."

# # Ensure the src directory exists
# if [ ! -d "src" ]; then
#   echo "Error: src directory not found. Please run this script from the project's root directory."
#   exit 1
# fi

# echo "Creating a correct App.jsx file..."

# # Overwrite/create the file with the correct contents
# cat > src/App.jsx << 'EOF'
# import React from "react";
# import ItemList from "./components/ItemList";
# import AddItem from "./components/AddItem";
# import "./App.css";

# function App() {
#   return (
#     <div>
#       <ItemList />
#       <AddItem />
#     </div>
#   );
# }

# export default App;
# EOF

# else
#   echo "Error: App.jsx file not found in src directory."
#   exit 1
# fi

# Overwrite index.html
cat > index.html << EOL
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="theme-color" content="#000000" />
    <meta name="description" content="Django React PostgreSQL App" />
    <title>Django React App</title>
  </head>
  <body>
    <noscript>You need to enable JavaScript to run this app.</noscript>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
EOL

# Return to project root
cd ../

# Generate Docker Compose file
echo "Creating Docker Compose configuration..."
cat > docker-compose.yml << EOF
version: '3.8'

services:
  backend:
    build: ./backend
    command: python3 manage.py runserver 0.0.0.0:8000
    ports:
      - "8000:8000"
    environment:
      - DATABASE_URL=postgresql://your_postgres_username:your_postgres_password@localhost/app_db

  frontend:
    build: ./frontend
    command: npm run dev
    ports:
      - "5173:5173"

  postgres:
    image: postgres
    environment:
      POSTGRES_DB: app_db
      POSTGRES_USER: your_postgres_username
      POSTGRES_PASSWORD: your_postgres_password
    ports:
      - "5432:5432"
EOF

# Return to root dir
cd ../
/bin/bash ./django-accounts.sh

echo "Setup complete! 🎉 Your Django-React-PostgreSQL application is ready."
