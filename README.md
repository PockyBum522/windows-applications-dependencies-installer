# windows-applications-dependencies-installer
Script that installs chocolatey and then installs the .NET Desktop Runtime(s) that the applications in my github must have to run

Your user will need to approve a UAC prompt, but do not run the script as admin. It will handle that itself, and needs to run as user first so that it can run some things *as* the user.
