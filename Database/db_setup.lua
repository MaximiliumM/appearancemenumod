return [[
CREATE TABLE "appearances" (
	"entity_id"	TEXT NOT NULL,
	"app_name"	TEXT NOT NULL,
	FOREIGN KEY("entity_id") REFERENCES "entities"("entity_id"),
	PRIMARY KEY("entity_id","app_name")
);

CREATE TABLE "categories" (
	"cat_id"	INTEGER NOT NULL UNIQUE,
	"cat_name"	TEXT NOT NULL,
	PRIMARY KEY("cat_id")
);

CREATE TABLE "entities" (
	"entity_id"	TEXT NOT NULL UNIQUE,
	"entity_name"	TEXT NOT NULL,
	"cat_id"	INTEGER NOT NULL,
	"parameters"	TEXT,
	"can_be_comp"	INTEGER NOT NULL,
	"entity_path"	TEXT,
	FOREIGN KEY("cat_id") REFERENCES "categories"("cat_id"),
	FOREIGN KEY("entity_id") REFERENCES "appearances"("entity_id"),
	PRIMARY KEY("entity_id")
);

CREATE TABLE "settings" (
	"setting_name"	TEXT NOT NULL,
	"setting_value"	INTEGER NOT NULL,
	PRIMARY KEY("setting_name")
);

CREATE TABLE "saved_appearances" (
	"entity_id"	TEXT,
	"app_name"	TEXT,
	PRIMARY KEY("entity_id")
);

CREATE TABLE "favorites" (
	"position"	INTEGER NOT NULL UNIQUE,
	"entity_id"	TEXT,
	"parameters" TEXT,
	PRIMARY KEY("position" AUTOINCREMENT)
);

CREATE TABLE "metadata" (
	"current_version" TEXT
);

INSERT INTO metadata (current_version)
VALUES ('0.0');

INSERT INTO settings (setting_name, setting_value)
VALUES	('autoResizing', 1),
		('experimental', 0),
		('openWithOverlay', 1);
]]
