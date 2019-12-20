
import Foundation

//Responsible for writing mobile-html & shared resource urls to Core Data as PersistentCacheGroup & PersistentCacheItem.

@objc(WMFArticleCacheDBWriter)
final public class ArticleCacheDBWriter: NSObject {
    
    private let articleFetcher: ArticleFetcher
    private let fileManager: FileManager
    public let cacheBackgroundContext: NSManagedObjectContext
    public let cacheURL: URL

    init?(articleFetcher: ArticleFetcher, fileManager: FileManager) {
        
        self.articleFetcher = articleFetcher
        self.fileManager = fileManager
        
        //create cacheURL and directory
        guard let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).last else {
            assertionFailure("Failure to pull documents directory")
            return nil
        }
        
        let documentsURL = URL(fileURLWithPath: documentsPath)
        cacheURL = documentsURL.appendingPathComponent("PersistentArticleCache", isDirectory: true)
        do {
            try fileManager.createDirectory(at: cacheURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            assertionFailure("Failure to create article cache directory")
            return nil
        }

        //create ManagedObjectModel based on Cache.momd
        guard let modelURL = Bundle.wmf.url(forResource: "PersistentCache", withExtension: "momd"),
            let model = NSManagedObjectModel(contentsOf: modelURL) else {
                assertionFailure("Failure to create managed object model")
                return nil
        }
        
        //create persistent store coordinator / persistent store
        let dbURL = cacheURL.deletingLastPathComponent().appendingPathComponent("PersistentCache.sqlite", isDirectory: false)
        let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        
        let options = [
            NSMigratePersistentStoresAutomaticallyOption: NSNumber(booleanLiteral: true),
            NSInferMappingModelAutomaticallyOption: NSNumber(booleanLiteral: true)
        ]
        
        do {
            try persistentStoreCoordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: dbURL, options: options)
        } catch {
            do {
                try FileManager.default.removeItem(at: dbURL)
            } catch {
                assertionFailure("Failure to remove old db file")
                return nil
            }

            do {
                try persistentStoreCoordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: dbURL, options: options)
            } catch {
                assertionFailure("Failure to add persistent store to coordinator")
                return nil
            }
        }

        cacheBackgroundContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        cacheBackgroundContext.persistentStoreCoordinator = persistentStoreCoordinator
   }
    
    public func isCached(articleURL: URL) -> Bool {
        
        guard let groupKey = articleURL.wmf_databaseKey else {
            return false
        }
        
        assert(Thread.isMainThread)
        let context = cacheBackgroundContext
        return context.performWaitAndReturn {
            cacheGroup(with: groupKey, in: context) != nil
        } ?? false
    }
    
    public func cacheMobileHtmlUrlFromMigration(articleURL: URL) { //articleURL should be desktopURL
        guard let groupKey = articleURL.wmf_databaseKey else {
            return
        }
        
        cacheEndpoint(articleURL: articleURL, endpointType: .mobileHTML, groupKey: groupKey, fromMigration: true)
    }
   
    public func toggleCache(articleURL: URL) {
        assert(Thread.isMainThread)
        toggleCache(!isCached(articleURL: articleURL), for: articleURL)
    }
   
    func clearURLCache() {
        //maybe settings hook? clear only url cache.
    }

    func clearCoreDataCache() {
        //todo: Settings hook, logout don't sync hook, etc.
        //clear out from core data, leave URL cache as-is.
    }

}

private extension ArticleCacheDBWriter {
    
    func toggleCache(_ cache: Bool, for articleURL: URL) {
        
        guard let groupKey = articleURL.wmf_databaseKey else {
            return
        }
        
        //todo: if not already cached...
            //1. add mobile-html key to DB, isDownloaded = false and isSaved = true, SavedArticlesSyncHandler will pick it up later.
            //2. fetch offline resources, loop through results and add key to DB, isDownloaded = false and isSaved = true, SavedArticlesSyncHandler will pick it up later. group key should be mobilehtml key
            //3. fetch media resources, loop through results and add key to DB, isDownloaded = false and isSaved = true, SavedArticlesSyncHandler will pick it up later. group key should be mobilehtml key
            //4. toc?
            //5. references?
            //6. summary?
        //if cached
            //go through items with that group key, delete the files, delete the records in CD.
        
        if cache {
            cacheEndpoint(articleURL: articleURL, endpointType: .mobileHTML, groupKey: groupKey)
            cacheEndpoint(articleURL: articleURL, endpointType: .mobileHtmlOfflineResources, groupKey: groupKey)
        } else {
            removeCachedArticle(groupKey: groupKey)
        }
    }
    
    func cacheEndpoint(articleURL: URL, endpointType: ArticleFetcher.EndpointType, groupKey: String, fromMigration: Bool = false) {
        
        switch endpointType {
        case .mobileHTML:
            cacheURL(groupKey: groupKey, itemKey: groupKey, fromMigration: fromMigration)
        case .mobileHtmlOfflineResources, .mediaList:
            
            guard let siteURL = articleURL.wmf_site,
                let articleTitle = articleURL.wmf_title else {
                return
            }
            
            articleFetcher.fetchResourceList(siteURL: siteURL, articleTitle: articleTitle, endpointType: endpointType) { (result) in
                switch result {
                case .success(let urls):
                    for url in urls {
                        
                        guard let itemKey = url.wmf_databaseKey else {
                            continue
                        }
                         
                        self.cacheURL(groupKey: groupKey, itemKey: itemKey, fromMigration: fromMigration)
                    }
                case .failure:
                    break
                }
            }
        default:
            break
            
        }
    }
    
    func mobileHTMLTitle(from mobileHTMLURL: URL) -> String {
        return (mobileHTMLURL.lastPathComponent as NSString).wmf_normalizedPageTitle()
    }
    
    func cacheURL(groupKey: String, itemKey: String, fromMigration: Bool = false) {
        
        let context = self.cacheBackgroundContext
        context.perform {

            guard let group = self.fetchOrCreateCacheGroup(with: groupKey, in: context) else {
                return
            }
            
            guard let item = self.fetchOrCreateCacheItem(with: itemKey, in: context) else {
                return
            }
            
            item.fromMigration = fromMigration
            group.addToCacheItems(item)
            self.save(moc: context)
        }
    }
    
    func fetchOrCreateCacheGroup(with groupKey: String, in moc: NSManagedObjectContext) -> PersistentCacheGroup? {
        return cacheGroup(with: groupKey, in: moc) ?? createCacheGroup(with: groupKey, in: moc)
    }

    func fetchOrCreateCacheItem(with itemKey: String, in moc: NSManagedObjectContext) -> PersistentCacheItem? {
        return cacheItem(with: itemKey, in: moc) ?? createCacheItem(with: itemKey, in: moc)
    }

    func cacheGroup(with key: String, in moc: NSManagedObjectContext) -> PersistentCacheGroup? {
        let fetchRequest: NSFetchRequest<PersistentCacheGroup> = PersistentCacheGroup.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "key == %@", key)
        fetchRequest.fetchLimit = 1
        do {
            guard let group = try moc.fetch(fetchRequest).first else {
                return nil
            }
            return group
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }
    
    func createCacheGroup(with groupKey: String, in moc: NSManagedObjectContext) -> PersistentCacheGroup? {
        
        guard let entity = NSEntityDescription.entity(forEntityName: "PersistentCacheGroup", in: moc) else {
            return nil
        }
        let group = PersistentCacheGroup(entity: entity, insertInto: moc)
        group.key = groupKey
        return group
    }
    
    func cacheItem(with itemKey: String, in moc: NSManagedObjectContext) -> PersistentCacheItem? {
        let fetchRequest: NSFetchRequest<PersistentCacheItem> = PersistentCacheItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "key == %@", itemKey)
        fetchRequest.fetchLimit = 1
        do {
            guard let item = try moc.fetch(fetchRequest).first else {
                return nil
            }
            return item
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }

    func createCacheItem(with itemKey: String, in moc: NSManagedObjectContext) -> PersistentCacheItem? {
        guard let entity = NSEntityDescription.entity(forEntityName: "PersistentCacheItem", in: moc) else {
            return nil
        }
        let item = PersistentCacheItem(entity: entity, insertInto: moc)
        item.key = itemKey
        item.date = Date()
        return item
    }
    
    func removeCachedArticle(groupKey: String) {
        
        let context = cacheBackgroundContext
        context.perform {
            //tonitodo: task tracking in ArticleFetcher
            //self.articleFetcher.cancelAllTasks(forGroupWithKey: key)
            guard let group = self.cacheGroup(with: groupKey, in: context) else {
                assertionFailure("Cache group for \(groupKey) doesn't exist")
                return
            }
            guard let cacheItems = group.cacheItems as? Set<PersistentCacheItem> else {
                assertionFailure("Cache group for \(groupKey) has no cache items")
                return
            }
            for cacheItem in cacheItems where cacheItem.cacheGroups?.count == 1 {
                cacheItem.isPendingDelete = true
            }
            self.save(moc: context)
        }
    }
    
    func save(moc: NSManagedObjectContext) {
        guard moc.hasChanges else {
            return
        }
        do {
            try moc.save()
        } catch let error {
            assertionFailure("Error saving cache moc: \(error)")
        }
    }
}

extension ArticleCacheDBWriter: ArticleCacheFileWriterDBDelegate {
    public func failureToDeleteCacheItemFile(cacheItem: PersistentCacheItem, error: Error) {
        //tonitodo: not sure what to do in this case. maybe at least some logging?
    }
    
    public func deletedCacheItemFile(cacheItem: PersistentCacheItem) {
        cacheBackgroundContext.perform {
            self.cacheBackgroundContext.delete(cacheItem)
            
            if let cacheGroups = cacheItem.cacheGroups,
            cacheGroups.count == 1,
                let cacheGroup = cacheGroups.anyObject() as? PersistentCacheGroup {
                self.cacheBackgroundContext.delete(cacheGroup)
            }
            self.save(moc: self.cacheBackgroundContext)
        }
        
        //tonitodo: should we wait for self.save to complete successfully?
        if let key = cacheItem.key {
            NotificationCenter.default.post(name: ArticleCacheFileWriter.didChangeNotification, object: nil, userInfo: [ArticleCacheFileWriter.didChangeNotificationUserInfoDBKey: key,
            ArticleCacheFileWriter.didChangeNotificationUserInfoIsDownloadedKey: false])
        }
    }
    
    public func downloadedCacheItemFile(cacheItem: PersistentCacheItem) {
        cacheBackgroundContext.perform {
            cacheItem.isDownloaded = true
            self.save(moc: self.cacheBackgroundContext)
        }
    }
    
    public func migratedCacheItemFile(cacheItem: PersistentCacheItem) {
        cacheBackgroundContext.perform {
            cacheItem.fromMigration = false
            cacheItem.isDownloaded = true
            self.save(moc: self.cacheBackgroundContext)
        }
    }
}
