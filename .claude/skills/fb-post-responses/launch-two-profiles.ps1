# Opens two Chrome windows, one per Chrome profile, for /fb-responses.
# Close Chrome completely first, otherwise the occlusion flag is ignored.
# Find profile folder names at chrome://version ("Profile Path", last folder).
param(
  [string]$ProfileA = "Default",
  [string]$ProfileB = "Profile 1"
)

$chrome = "C:\Program Files\Google\Chrome\Application\chrome.exe"
$flag = "--disable-features=CalculateNativeWinOcclusion"

Start-Process $chrome -ArgumentList "--profile-directory=`"$ProfileA`"", $flag, "--new-window", "https://www.facebook.com/notifications"
Start-Sleep -Seconds 3
Start-Process $chrome -ArgumentList "--profile-directory=`"$ProfileB`"", $flag, "--new-window", "https://www.facebook.com/notifications"
