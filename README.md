# StreakNotify
A jailbreak tweak that specifies to the user everything about Snapchat streaks and is an extension to tweaks that don’t take advantage of this feature of Snapchat. If you snap a lot of people, this is what you’ll want for sure.

A clock/timer emoji and time remaining will show up on your feed for any streak that you have currently going with another user

Notifications will be pushed based on intervals that you specify in settings

Custom Friends allows notifications to be enabled for those specified in Friendmojilist settings 

Auto Reply allows Snaps to be sent automatically to those when notifications are delivered

# Features coming soon
1. Auto send snaps which keep the streak for you after receiving the notification (or dynamically through the daemon)
2. Custom pictures and caption you can send to keep the streak
3. Disable auto-reply for x certain users if enabled
4. Integration with Phantom and Snap+
5. Ability to install on a non-jailbroken device
Note: you won’t be able to receive updates unless you check out the project I have frequently as updates are pushed. <br />
Check out http://github.com/yungraj/StreakNotify-jailed and http://github.com/BishopFox/theos-jailed <br />
6. BulletinBoard framework handling notifications instead of UIKit (UILocalNotification) to fix issues with notifications <br />
7. More support with the objective-c frontend to Snapchat’s servers <br />
8. More features that may not necessarily be related to Snapchat streaks… features such as those found in Phantom and Snap++

# Note:
beta-testing branch is for beta testing the tweak… now is default branch for SN

# Known issues
Auto Reply IS NOT WORKING, reverse engineering Snapchat’s API’s is hard <br />
Snapchat updates cause selectors used for models become deprecated (UPDATE TO UPDATE) <br />
No caption insertion for auto reply in Preferences Bundle (FIXED) <br />
Choose image is dead in the Preferences Bundle (FIXED) <br />
Daemon not loading because of permissions issues (FIXED) <br />
FriendmojiList custom friends crashing (FIXED) <br />
/var/root/Documents folder missing on some devices (FIXED) <br />
Crashes before saving preferences and launching the app (FIXED) <br />
Random but not frequent crashes on cellForRowAtIndexPath: (FIXED)



