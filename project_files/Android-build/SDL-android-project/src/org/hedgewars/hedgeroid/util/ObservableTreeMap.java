/*
 * Hedgewars for Android. An Android port of Hedgewars, a free turn based strategy game
 * Copyright (C) 2012 Simeon Maxein <smaxein@googlemail.com>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

package org.hedgewars.hedgeroid.util;

import java.util.Collections;
import java.util.Map;
import java.util.TreeMap;

import android.database.DataSetObservable;

public class ObservableTreeMap<K,V> extends DataSetObservable {
    private final Map<K, V> map = new TreeMap<K, V>();

    public void replaceContent(Map<? extends K, ? extends V> newMap) {
        map.clear();
        map.putAll(newMap);
        notifyChanged();
    }

    public void put(K key, V value) {
        map.put(key, value);
        notifyChanged();
    }

    public V get(K key) {
        return map.get(key);
    }

    public void remove(K key) {
        if(map.remove(key) != null) {
            notifyChanged();
        }
    }

    public void clear() {
        if(!map.isEmpty()) {
            map.clear();
            notifyChanged();
        }
    }

    public Map<K, V> getMap() {
        return Collections.unmodifiableMap(map);
    }
}