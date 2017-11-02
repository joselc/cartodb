Backend developer Test 2
========================

# Installation
For the installation process I cloned the Vagrant and project and installed
everything into the VM following the installation guide. Almost all the commands
described in the guide worked fine, I had no major issues.

### Some remarks

Redis configuration values:
```
save 900 1
save 300 10
save 60 10000
appendonly yes
appendfsync always
```

For the Editor code I forked the project into my Github account, and I created
a branch for the development of the test: [BCKD-TEST-1 branch](https://github.com/joselc/cartodb/tree/BCKD-TEST-1). The only little
issue I had during the installation was running `bundle exec grunt --environment=development`.
First time was `(Aborted due to warnings)`, so I had to rerun with `--force` option.
This second time it hanged, and the third it worked fine.  

I was thinking about developing a Docker environment for all the installation
(shouldn't be really difficult), so each component could be in a separate
container coordinated by a simple Docker Compose, but in the end I didn't have
time to do it.

# Developing the issue
On a first read of the task I thought about the main components/features the solution will need:
+ an endpoint to generate user tokens with the desired permission on the target table
+ possibility to generate more than token per table-permission, so they can be revoked without affecting the user tokens pointing to the same table (later I had some doubts about this, but they were clarified on email conversations)
+ some entity/structure to store the user tokens, accesible by the owner
+ modify the authorization module to use the user tokens as authorization entity

### First step: investigating Carto code, identifying entities involved

My first step was clear, as I understood that the main challenge wasn't the issue
itself (easy and straightforward to implement on a greenfield project), but to
develop it inside Carto code. After playing around with the application and exploring the database structure and how it changes with the different actions, I began the investigation.  

So my first stop was the `RecordController` class. Following the `before_filters`
actions, I traced the entities involved in the authorization process:  
1.  `RecordController`: CRUD endpoint for records on user tables. Retrieves the `UserTable` following the `:table_id` parameter, and checks the permissions of the user on the table before performing any action.
1.  `TableLocator`: helper class to find the `UserTable`. Locates the table based on both the `table_id` and the `current_user`. It is interesting (and helpful for the issue) that it can locate the table just with the `table_id` if it is in the format `userdomain.table_id`. That way it can be used to locate other users tables.
1.  `UserTable`: entity to map tables in the user database with user information (in cartodb database). Contains metadata of the data table and a one to one relation with `Visualization`.
1.  `Visualization`: contains the information about the visualization of a given table or map. Has a one to one relation with `Permissions`, the class where it delegates part of the authorization checks, mostly when the `current_user` isn't the owner of the table.
1.  `Permission`: this class contains functionality for extra authorizations over a user table. Most interesting part of this entity is ACL it contains, to give access for other entities (`Users`, `Organizations` and `Groups`). This seems like a good place to manage access for user tokens, but as I will explain later, this is not straightforward to implement, and it's more complex than it seems.
1.  `User`: contains all the information related to the user. Not really involved in the authorization logic, as this functionality is encapsulated in the other entities described.

### Second step: designing and implementing the solution

Once I had a basic understanding of the code involved in the issue scope I began with the design. My very first approach was quite simple:
+ `UserToken`: entity to store the generated user tokens. With relations to `UserTable` and `User`, and the given permissions as an attribute.
+ `UserTokenController`: endpoint with POST action to generate tokens for a given table with given permissions. Default permissions set to `readonly`.
+ `UserTable` logic to check on permissions of a user token on the table.
+ `RecordController` extension to accept user tokens as parameter, and adding checks of the user token permissions apart from the usual user permissions. When the controller is accessed with user token, the `table_id` must be in format `tableowner.table_id` (if the `current_user` is different from the owner).

This was a simple solution, but I was thinking of making a better solution. I wasn't thinking of this issue as a test, but more like my first entry-level issue if I was hired at Carto. With that in mind, I looked into the way of avoiding the creation of extra unnecessary entities, but more important, avoiding new flows of authorization processes. So I thought what was the best way to use the current authorization process and how I could extend it to match the user story requirements:

+ Using `Permission` ACLs to store raw user tokens in the `entity.id`. Adding new type of entity `TYPE_USERTOKEN`. New method to retrieve ACL entries for user tokens.
+ Same `UserTokenController` to generate user tokens, but storing them directly on `Permission` ACL.
+ No `UserToken` entity needed
+ On `RecordController` adding checks for user token authorization but following the current process used for users.
+ No need for new methods on `Visualization` or `UserTable`, as the logic is already implemented.

This looked like a really nice solution in theory (as Javier prevented me on an email conversation) but I quickly found some problems:
+ The authorization process for users is expecting to deal with... well, users. In many parts of the process the logic is looking for the `id` attribute of `User`, and that is what it checks on the final step in `Permission`. The user token was simply a `String` so that was a problem, that I ended up solving with some ugly code: `OpenStruct.new(:id => user_token)`. I really don't like to introduce workarounds of this kind.
+ The `PermissionPresenter`isn't prepared to deal with user token, and that was broking the application when a table had some user token associated.
+ More important: the authorization process is designed for users, not other entities. It is conceptually wrong to take profit of the language particularities to introduce entities with a completely different structure. And it is dangerous.

I developed this solution and tested it with `curl`requests. It was working fine for read permissions, and even for readwrite (and it shouldn't, so maybe I got wrong at some place with curl). I still think this way is a better way to implement it, but requires of a large refactor to implement an abstract authorization entity, to use instead of user. But this is completely out of the scope of the test. **So finally, I went back to my first approach.**

#### Known issues
Everything is working fine except for the DELETE operation on records (with user token). GET, POST and PUT use `UserTable` to deal with the table, wich is fine and helpful for the issue. But in the DELETE action, it is different, as it uses the `current_user` (wich is usually different from the owner when using a token), and that is causing a `404`error, as it can't find the table. I tried to deal with that, but I wasn't able to identify clearly the logic. **Any help here would be appreciated.**

### Main challenges I faced
+ As I don't have previous experience with rails and ruby, it was difficult to follow the syntax and the logic of the application. I ended up understanding it, but I almost had to troubleshoot everything I wanted to code. Coming from a Java environment it's hard to get used to follow this kind of languages. But not impossible! :)
+ Following that, I began late with tests, because I've never worked with rspec and I didn't want to spend time troubleshooting as I had few time to explore the code and ask questions. In the end it was a bad decision as rspec is really easy and it wasn't that hard.
+ Life. And work.

### Note
I found that the authorization checks for other table-controllers are the same code, duplicated in several classes. I thought about refactoring this pieces, so the logic of the user tokens could be used across endpoints regarding tables. But as it is out of the scope of the test I didn't do it. And also, if I learned something from my professional experience is that there is always a good reason for things to be as they are (as you also told me on emails).
