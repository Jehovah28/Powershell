Create new users in Office 365 from an comma seperated csv file and assign a license to them.
The function also adds the users to a predefined Distribution group in Exchange Online and set the default public folder and addressbookpolicy.
Note: You have to change them to fit your needs

The function creates a log which is send in case of failure to the currently logged in domain user (vailid email in AD required) on the machine running the function.
If it succeed the specified user in the parameter emailadresse (emailadresse have to be a valid email from your AD, i assume the upn is equal to the emailadresse) 
will receive an email with the nessary login values for the create users.
Note: The password have to be the same for all users to work correctly.

The script "Voraussetzung" validate that the Microsoft Online Services Sign-in Assistent is installed on your machine. 
Note: Currently only on german systems, but it is easy to change for other languages

And it tries to import the module MSOnline. If it fails your not able to run the function.

German help is include in the XML-file in the subfolder de-DE

TODO:
improve error handling
handle what happens when an user exist in Office 365