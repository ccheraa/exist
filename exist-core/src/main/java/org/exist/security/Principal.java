/*
 * eXist-db Open Source Native XML Database
 * Copyright (C) 2001 The eXist-db Authors
 *
 * info@exist-db.org
 * http://www.exist-db.org
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 */
package org.exist.security;

import org.exist.config.Configurable;
import org.exist.config.ConfigurationException;
import org.exist.security.realm.Realm;
import org.exist.storage.DBBroker;
import java.util.Set;

/**
 * @author <a href="mailto:shabanovd@gmail.com">Dmitriy Shabanov</a>
 *
 */
public interface Principal extends java.security.Principal, Configurable {

    int getId();

    void setName(String name);

    Realm getRealm();

    String getRealmId();

    void save() throws ConfigurationException, PermissionDeniedException;

    void save(DBBroker broker) throws ConfigurationException, PermissionDeniedException;
    
    void setMetadataValue(SchemaType schemaType, String value);

    String getMetadataValue(SchemaType schemaType);

    Set<SchemaType> getMetadataKeys();
    
    void clearMetadata();
}
