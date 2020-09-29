CREATE TABLE dbo.Metadata_ADF
(
ID INT IDENTITY(1,1) NOT NULL,
SourceType VARCHAR(50) NOT NULL,
ObjectName VARCHAR(500) NOT NULL,
ObjectValue VARCHAR(1000) NOT NULL
);

- Insert Meta data
INSERT INTO dbo.Metadata_ADF	
		(
		SourceType,
		ObjectName,
		ObjectValue
		)
VALUES  ('BlobContainer','semicolondata','semicolon'),
		('BlobContainer','commadata','comma');

INSERT INTO dbo.Metadata_ADF
		(
		SourceType,
		ObjectName,
		ObjectValue
		)
VALUES  ('Delimiter','semicolondata',';'),
		('Delimiter','commadata',',');

INSERT INTO dbo.Metadata_ADF
		(
		SourceType,
		ObjectName,
		ObjectValue
		)
VALUES  ('SQLTable','semicolondata','topmovies_semicolon'),
		('SQLTable','commadata','topmovies_comma');
