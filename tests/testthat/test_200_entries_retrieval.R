test.hmdbmetabolite.nbentries <- function(conn) {

    # Check number of entries
    n <- conn$getNbEntries(count=TRUE)
    expect_is(n, 'integer')
    if (conn$isDownloaded())
        expect_gt(n, 0)
    else
        expect_true(is.na(n))
}

test.old.accession <- function(conn) {

    entry <- conn$getEntry('HMDB00002')
    testthat::expect_is(entry, 'HmdbMetabolitesEntry')
    testthat::expect_equal(entry$getFieldValue('accession'), 'HMDB0000002')
}

# Set test context
biodb::testContext("Test retrieval of entries")

source('zip_builder.R')

# Instantiate Biodb
biodb <- biodb::createBiodbTestInstance(ack=TRUE)

# Load package definitions
defFile <- system.file("definitions.yml", package='biodbHmdb')
biodb$loadDefinitions(defFile)

# Create connector
conn <- biodb$getFactory()$createConn('hmdb.metabolites')
conn$setPropValSlot('urls', 'db.zip.url', two_entries_zip_file)

# Run tests
biodb::testThat("HMDB metabolite returns enough entries.",
                test.hmdbmetabolite.nbentries, conn=conn)
biodb::testThat("We can retrieve entries using old accession numbers.",
                test.old.accession, conn=conn)

# Terminate Biodb
biodb$terminate()
