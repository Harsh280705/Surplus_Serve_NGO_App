cp Runner/GoogleService-Info.plist Runner/GoogleService-Info.plist.bak
plutil -convert xml1 Runner/GoogleService-Info.plist
/usr/libexec/PlistBuddy -c "Set :API_KEY $(grep GOOGLE_MAPS_API_KEY ../.env | cut -d '=' -f2)" Runner/GoogleService-Info.plist
plutil -convert binary1 Runner/GoogleService-Info.plist