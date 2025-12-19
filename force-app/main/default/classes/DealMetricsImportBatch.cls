/**
 * DealMetricsImportBatch - Batch job to import deal metrics from Static Resource
 * Run with: Database.executeBatch(new DealMetricsImportBatch(), 200);
 */
global class DealMetricsImportBatch implements Database.Batchable<sObject>, Database.Stateful {

    // Lookup maps built from CSV
    global Map<String, DealMetricsImporter.DealMetric> metricsByDomain;
    global Map<String, DealMetricsImporter.DealMetric> metricsByName;

    // Stats
    global Integer domainMatches = 0;
    global Integer nameMatches = 0;
    global Integer accountsUpdated = 0;

    global DealMetricsImportBatch() {
        // Load CSV data from static resource
        StaticResource sr = [SELECT Body FROM StaticResource WHERE Name = 'TopCompaniesCSV' LIMIT 1];
        String csvContent = sr.Body.toString();

        // Parse CSV into metrics
        List<DealMetricsImporter.DealMetric> metrics = DealMetricsImporter.parseCSV(csvContent);

        // Build lookup maps
        metricsByDomain = new Map<String, DealMetricsImporter.DealMetric>();
        metricsByName = new Map<String, DealMetricsImporter.DealMetric>();

        for (DealMetricsImporter.DealMetric dm : metrics) {
            if (String.isNotBlank(dm.emailDomain)) {
                metricsByDomain.put(dm.emailDomain.toLowerCase(), dm);
            }
            if (String.isNotBlank(dm.name)) {
                metricsByName.put(dm.name.toLowerCase(), dm);
            }
        }

        System.debug('Loaded ' + metrics.size() + ' metrics from CSV');
        System.debug('Domain lookup size: ' + metricsByDomain.size());
        System.debug('Name lookup size: ' + metricsByName.size());
    }

    global Database.QueryLocator start(Database.BatchableContext BC) {
        // Query all accounts that might have matches
        return Database.getQueryLocator([
            SELECT Id, Name, Website, In_Deals__c, Allocated__c, Declined_Pass__c, Other_Deals__c
            FROM Account
            WHERE Website != null OR Name != null
        ]);
    }

    global void execute(Database.BatchableContext BC, List<Account> accounts) {
        List<Account> toUpdate = new List<Account>();

        for (Account acc : accounts) {
            DealMetricsImporter.DealMetric matched = null;
            Boolean isDomainMatch = false;

            // Try domain match first
            if (String.isNotBlank(acc.Website)) {
                String domain = DealMetricsImporter.extractDomain(acc.Website);
                if (domain != null && metricsByDomain.containsKey(domain)) {
                    matched = metricsByDomain.get(domain);
                    isDomainMatch = true;
                }
            }

            // Try name match as fallback
            if (matched == null && String.isNotBlank(acc.Name)) {
                String nameLower = acc.Name.toLowerCase();
                if (metricsByName.containsKey(nameLower)) {
                    matched = metricsByName.get(nameLower);
                }
            }

            // Update if matched
            if (matched != null) {
                acc.In_Deals__c = matched.inDeals;
                acc.Allocated__c = matched.allocated;
                acc.Declined_Pass__c = matched.declinedPass;
                acc.Other_Deals__c = matched.otherDeals;
                toUpdate.add(acc);

                if (isDomainMatch) {
                    domainMatches++;
                } else {
                    nameMatches++;
                }
            }
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
            accountsUpdated += toUpdate.size();
        }
    }

    global void finish(Database.BatchableContext BC) {
        System.debug('=== IMPORT COMPLETE ===');
        System.debug('Domain Matches: ' + domainMatches);
        System.debug('Name Matches: ' + nameMatches);
        System.debug('Total Accounts Updated: ' + accountsUpdated);
    }
}
