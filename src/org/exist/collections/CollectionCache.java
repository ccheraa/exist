package org.exist.collections;

import org.exist.storage.BrokerPool;
import org.exist.storage.CacheManager;
import org.exist.storage.cache.Cacheable;
import org.exist.storage.cache.LRDCache;
import org.exist.storage.cache.LRUCache;
import org.exist.storage.lock.Lock;
import org.exist.util.hashtable.Long2ObjectHashMap;
import org.exist.util.hashtable.Object2LongHashMap;
import org.exist.util.hashtable.SequencedLongHashMap;
import org.exist.xmldb.XmldbURI;

import java.util.Iterator;

/**
 * Global cache for {@link org.exist.collections.Collection} objects. The
 * cache is owned by {@link org.exist.storage.index.CollectionStore}. It is not
 * synchronized. Thus a lock should be obtained on the collection store before
 * accessing the cache.
 * 
 * @author wolf
 */
public class CollectionCache extends LRUCache {

	private Object2LongHashMap names;
	private BrokerPool pool;

	public CollectionCache(BrokerPool pool, int blockBuffers, double growthThreshold) {
		super(blockBuffers, 2.0, 0.000001, CacheManager.DATA_CACHE);
        this.names = new Object2LongHashMap(blockBuffers);
		this.pool = pool;
        setFileName("collection cache");
    }
	
	public void add(Collection collection) {
		add(collection, 1);
	}

	public void add(Collection collection, int initialRefCount) {
		super.add(collection, initialRefCount);
        String name = collection.getURI().getRawCollectionPath();
        names.put(name, collection.getKey());
	}

	public Collection get(Collection collection) {
		return (Collection) get(collection.getKey());
	}

	public Collection get(XmldbURI name) {
		long key = names.get(name.getRawCollectionPath());
		if (key < 0) {
			return null;
        }
		return (Collection) get(key);
	}

	/**
	 * Overwritten to lock collections before they are removed.
	 */
	protected void removeOne(Cacheable item) {
        boolean removed = false;
        SequencedLongHashMap.Entry next = map.getFirstEntry();
        do {
            Cacheable cached = (Cacheable) next.getValue();
            if(cached.allowUnload() && cached.getKey() != item.getKey()) {
                Collection old = (Collection) cached;
                if(pool.getConfigurationManager()!=null) { // might be null during db initialization
                    pool.getConfigurationManager().invalidate(old.getURI());
                }
                names.remove(old.getURI().getRawCollectionPath());
                cached.sync(true);
                map.remove(next.getKey());
                removed = true;
            } else {
                next = next.getNext();
                if(next == null) {
                    LOG.debug("Unable to remove entry");
                    next = map.getFirstEntry();
                }
            }
        } while(!removed);
        cacheManager.requestMem(this);
	}

    public void remove(Cacheable item) {
    	final Collection col = (Collection) item;
        super.remove(item);
        names.remove(col.getURI().getRawCollectionPath());
        if(pool.getConfigurationManager() != null) // might be null during db initialization
           pool.getConfigurationManager().invalidate(col.getURI());
    }

    /**
     * Compute and return the in-memory size of all collections
     * currently contained in this cache.
     *
     * @see org.exist.storage.CollectionCacheManager
     * @return in-memory size in bytes.
     */
    public int getRealSize() {
        int size = 0;
        for (Iterator<Long> i = names.valueIterator(); i.hasNext(); ) {
            Collection collection = (Collection) get(i.next());
            if (collection != null) {
                size += collection.getMemorySize();
            }
        }
        return size;
    }

    public void resize(int newSize) {
        if (newSize < max) {
            shrink(newSize);
        } else {
            LOG.debug("Growing collection cache to " + newSize);
            SequencedLongHashMap newMap = new SequencedLongHashMap(newSize * 2);
            Object2LongHashMap newNames = new Object2LongHashMap(newSize);
            SequencedLongHashMap.Entry next = map.getFirstEntry();
            Cacheable cacheable;
            while(next != null) {
                cacheable = (Cacheable) next.getValue();
                newMap.put(cacheable.getKey(), cacheable);
                newNames.put(((Collection) cacheable).getURI().getRawCollectionPath(), cacheable.getKey());
                next = next.getNext();
            }
            max = newSize;
            map = newMap;
            names = newNames;
            accounting.reset();
            accounting.setTotalSize(max);
        }
    }

    @Override
    protected void shrink(int newSize) {
        super.shrink(newSize);
        names = new Object2LongHashMap(newSize);
    }
}
