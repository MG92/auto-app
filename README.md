# auto-app
Automatic Django and react app 

These scripts create a web app with a Django backend and React frontend and a PostgreSQL database. A Docker Compose config file is also created to run all components as containers.

A script named django-accounts.sh will be invoked to add a user registration and login function to the app.

Some additional frontend components and corresponding backend views are added, as an example, but these can easily be modified in the script. 

# Running the script
From the `auto-app` folder run
```bash
sh app-setup.sh
```

This will create a folder structure that looks like the following:
```
- django-react-app
|__ frontend
  |__ public/
  |__ src/
  |__package.json
  |__index.html
|__ backend
  |__ accounts/
  |__ api/
  |__ backend/
  |__ environment.yml
  |__ manage.py
|__ docker-compose.yml
```
Other files are ommitted here for brevity. 

# Points to note 
- This has been designed to run on macOS and hasn't been tested on other operating systems. 
- The app-setup.sh script uses Vite to create a react frontend app. More information can be found  here: https://vite.dev 