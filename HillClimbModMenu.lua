gg.alert('⚠️  NOTICE/WARNING  ⚠️ \n \n APPLY HACKS AFTER PLAYING SOME GAME TO EARN MONEY WHICH HELPS TO FIND MONEY/DIAMONDS EASILY')
gg.toast('🔴  GS47 Mods  🔴')


 menu = gg.choice({'1️⃣ Hack Coins 🪙','2️⃣ Hack Diamonds 💎'},nil,'🔴    GS47 Mods    🔴')

if menu == nil then
else
if menu == 1 then 
gg.clearResults()
local currentCoins = gg.prompt(
{'Enter Current Coins 🪙🪙🪙'},
{[1]=nil},
{[1]='number'}
)
gg.setRanges(gg.REGION_C_BSS)
gg.searchNumber(currentCoins[1],gg.TYPE_DWORD)
gg.getResults(100)
gg.editAll('99999999',
gg.TYPE_DWORD)
gg.toast('🪙 Hack Applied Successfully ✅')

end

if menu == 2 then 
gg.clearResults()
local currentDiamonds = gg.prompt(
{'Enter Current Diamonds 💎💎💎'},
{[1]=nil},
{[1]='number'}
)
gg.setRanges(gg.REGION_C_BSS)
gg.searchNumber(currentDiamonds[1],gg.TYPE_DWORD)
gg.getResults(100)
gg.editAll('99999999',
gg.TYPE_DWORD)
gg.toast('💎 Hack Applied Successfully ✅')


end

end




