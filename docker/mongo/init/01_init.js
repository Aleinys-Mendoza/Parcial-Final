db = db.getSiblingDB('conectasucre_nosql');

db.createCollection('tracking_events', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['dispatch_id', 'incident_id', 'event_type', 'description', 'event_date', 'delay_minutes', 'details', 'evidence'],
      properties: {
        dispatch_id: { bsonType: 'int', minimum: 1 },
        incident_id: { bsonType: ['int', 'null'], minimum: 1 },
        event_type: { bsonType: 'string', minLength: 1 },
        description: { bsonType: 'string', minLength: 1 },
        event_date: { bsonType: 'date' },
        delay_minutes: { bsonType: 'int', minimum: 0 },
        details: { bsonType: 'object' },
        evidence: { bsonType: 'array', items: { bsonType: 'object' } }
      }
    }
  },
  validationLevel: 'strict',
  validationAction: 'error'
});

db.tracking_events.createIndex({ dispatch_id: 1, event_date: -1 }, { name: 'idx_dispatch_event_date' });
db.tracking_events.createIndex({ event_type: 1, delay_minutes: -1 }, { name: 'idx_event_type_delay' });
