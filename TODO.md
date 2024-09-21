```
cat WebUI-API-\(qBittorrent-4.1\).md \
	| grep -v API \
	| grep -e '^##' -e 'Name:' \
	| tr '\n' '\r' \
	| sed 's/\rName://g;' \
	| tr '\r' '\n' \
	| sed 's/^##/- [ ]/; s/ ##//;' \
	>TODO.md
```

- [ ] Login `login`
- [ ] Logout `logout`
- [ ] Get application version `version` `webapiVersion`
- [ ] Get build info `buildInfo`
- [ ] Shutdown application `shutdown`
- [x] Get application preferences `preferences`
- [x] Set application preferences `setPreferences`
- [ ] Get default save path `defaultSavePath`
- [ ] Get log `main`
- [ ] Get peer log `peers`
- [ ] Get main data `maindata`
- [x] Get torrent peers data `torrentPeers`
- [x] Get global transfer info `info`
- [x] Get alternative speed limits state `speedLimitsMode`
- [x] Toggle alternative speed limits `toggleSpeedLimitsMode`
- [x] Get global download limit `downloadLimit`
- [x] Set global download limit `setDownloadLimit`
- [x] Get global upload limit `uploadLimit`
- [x] Set global upload limit `setUploadLimit`
- [ ] Ban peers `banPeers`
- [x] Get torrent list `info`
- [ ] Get torrent generic properties `properties`
- [ ] Get torrent trackers `trackers`
- [ ] Get torrent web seeds `webseeds`
- [x] Get torrent contents `files`
- [x] Get torrent pieces' states `pieceStates`
- [ ] Get torrent pieces' hashes `pieceHashes`
- [x] Pause torrents `pause`
- [x] Resume torrents `resume`
- [ ] Delete torrents `delete`
- [x] Recheck torrents `recheck`
- [ ] Reannounce torrents `reannounce`
- [ ] Add new torrent
- [ ] Add trackers to torrent
- [ ] Edit trackers `editTracker`
- [ ] Remove trackers `removeTrackers`
- [ ] Add peers `addPeers`
- [ ] Increase torrent priority `increasePrio`
- [ ] Decrease torrent priority `decreasePrio`
- [x] Maximal torrent priority `topPrio`
- [x] Minimal torrent priority `bottomPrio`
- [x] Set file priority `filePrio`
- [ ] Get torrent download limit
- [ ] Set torrent download limit
- [ ] Set torrent share limit
- [ ] Get torrent upload limit
- [ ] Set torrent upload limit
- [x] Set torrent location
- [ ] Set torrent name
- [x] Set torrent category
- [ ] Get all categories `categories`
- [ ] Add new category
- [ ] Edit category
- [ ] Remove categories
- [ ] Add torrent tags
- [ ] Remove torrent tags
- [ ] Get all tags `tags`
- [ ] Create tags
- [ ] Delete tags
- [ ] Set automatic torrent management
- [ ] Toggle sequential download `toggleSequentialDownload`
- [ ] Set first/last piece priority `toggleFirstLastPiecePrio`
- [ ] Set force start
- [ ] Set super seeding
- [ ] Rename file `renameFile`
- [ ] Rename folder `renameFolder`
- [ ] Add folder `addFolder`
- [ ] Add feed `addFeed`
- [ ] Remove item `removeItem`
- [ ] Move item `moveItem`
- [ ] Get all items `items`
- [ ] Mark as read `markAsRead`
- [ ] Refresh item `refreshItem`
- [ ] Set auto-downloading rule `setRule`
- [ ] Rename auto-downloading rule `renameRule`
- [ ] Remove auto-downloading rule `removeRule`
- [ ] Get all auto-downloading rules `rules`
- [ ] Get all articles matching a rule `matchingArticles`
- [ ] Start search `start`
- [ ] Stop search `stop`
- [ ] Get search status `status`
- [ ] Get search results `results`
- [ ] Delete search `delete`
- [ ] Get search plugins `plugins`
- [ ] Install search plugin `installPlugin`
- [ ] Uninstall search plugin `uninstallPlugin`
- [ ] Enable search plugin `enablePlugin`
- [ ] Update search plugins `updatePlugins`
