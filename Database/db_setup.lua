return [[
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
	PRIMARY KEY("position" AUTOINCREMENT)
);

INSERT INTO settings (setting_name, setting_value)
VALUES	('autoResizing', 1),
		('experimental', 0),
		('openWithOverlay', 1);
]]
