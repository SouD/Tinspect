#Tinspect
By SouD

Version: 1.0

Date: 06/06/2012

##Description
Tinspect is an addon for World of Warcraft version 1.12.x (Build 5875 and 6005),
commonly known as "Classic WoW" or "Vanilla WoW". It was made to mimic the functionality
implemented by Blizzard with patch 2.0.1 which allowed players to inspect another players
talent specialization.

##Downloading
To clone Tinspect use the following command: git clone git://github.com/SouD/Tinspect.git
or download repo as .zip

##Installing
If you downloaded the repo as a .zip archive, unzip the archive into your AddOn folder.
Otherwise just copy all the files to your addon directory.
The final result should look something like this:
Drive:\PATH_TO_WOW_INSTALLATION\Interface\AddOn\CLF

##Usage
Firstly, there are a few requirements for the addon to work. These are as follows:

###Requirements
1. You must have the addon loaded
2. a. The player you wish to inspect must be in your party or raid group or
2. b. The player who's talents you wish to inspect must be saved in your cache / db
3. The player you wish to inspect must also have Tinspect installed and loaded

So, why all these restrictions? Because the WoW 1.12 API does not expose any functionality
to retreive information regarding other players talents. To circumvent this, Tinspect
"speaks" with other versions of Tinspect, similar to how DBM works.

##Future
1. Finish talent text database
2. Add descriptive text to talents on mouseover
3. Clean up codebase and optimize
4. Come up with a better caching system
5. Come up with a better db system
6. Localization

###Disclaimer
This was the first addon I ever wrote and because of this, the code is pretty messy.
There are a lot of things wich could be improved and will be sometime in the future.
