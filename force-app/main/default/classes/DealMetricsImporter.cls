/**
 * DealMetricsImporter - Imports deal metrics from TopCompanies CSV to Account records
 *
 * Matching Strategy:
 * 1. Primary: Match CSV EmailDomain to Account Website domain
 * 2. Secondary: Match CSV Name to Account Name (exact match for banks)
 *
 * Fields Updated:
 * - In_Deals__c
 * - Allocated__c
 * - Declined_Pass__c
 * - Other_Deals__c
 */
public class DealMetricsImporter {

    // Inner class to hold CSV data
    public class DealMetric {
        public String name;
        public String emailDomain;
        public Decimal inDeals;
        public Decimal allocated;
        public Decimal declinedPass;
        public Decimal otherDeals;
    }

    /**
     * Parse CSV content and return list of DealMetric records
     * Expected columns: UID, SFDC Account ID, Portal, Name, EmailDomain, In Deals, Allocated, Declined/Pass, Other
     * Uses manual line splitting to avoid regex limits with large files
     */
    public static List<DealMetric> parseCSV(String csvContent) {
        List<DealMetric> metrics = new List<DealMetric>();

        // Manual line splitting to avoid regex limits
        Integer startPos = 0;
        Integer lineNum = 0;
        Integer contentLength = csvContent.length();

        while (startPos < contentLength) {
            Integer newlinePos = csvContent.indexOf('\n', startPos);
            String line;

            if (newlinePos == -1) {
                // Last line without newline
                line = csvContent.substring(startPos);
                startPos = contentLength;
            } else {
                line = csvContent.substring(startPos, newlinePos);
                startPos = newlinePos + 1;
            }

            // Remove carriage return if present
            if (line.endsWith('\r')) {
                line = line.substring(0, line.length() - 1);
            }

            lineNum++;

            // Skip header row (line 1)
            if (lineNum == 1) continue;

            line = line.trim();
            if (String.isBlank(line)) continue;

            List<String> fields = parseCSVLine(line);
            if (fields.size() < 9) continue;

            DealMetric dm = new DealMetric();
            dm.name = fields[3].trim().replace('"', '');
            dm.emailDomain = fields[4].trim().replace('"', '').toLowerCase();
            dm.inDeals = parseDecimal(fields[5]);
            dm.allocated = parseDecimal(fields[6]);
            dm.declinedPass = parseDecimal(fields[7]);
            dm.otherDeals = parseDecimal(fields[8]);

            metrics.add(dm);
        }

        return metrics;
    }

    /**
     * Parse a CSV line handling quoted fields with commas
     */
    private static List<String> parseCSVLine(String line) {
        List<String> result = new List<String>();
        Boolean inQuotes = false;
        String currentField = '';

        for (Integer i = 0; i < line.length(); i++) {
            String c = line.substring(i, i + 1);

            if (c == '"') {
                inQuotes = !inQuotes;
            } else if (c == ',' && !inQuotes) {
                result.add(currentField);
                currentField = '';
            } else {
                currentField += c;
            }
        }
        result.add(currentField); // Add last field

        return result;
    }

    /**
     * Safely parse decimal from string
     */
    private static Decimal parseDecimal(String value) {
        if (String.isBlank(value)) return 0;
        try {
            return Decimal.valueOf(value.trim());
        } catch (Exception e) {
            return 0;
        }
    }

    /**
     * Extract domain from Website URL
     */
    public static String extractDomain(String website) {
        if (String.isBlank(website)) return null;

        String domain = website.toLowerCase().trim();

        // Remove protocol
        domain = domain.replace('https://', '');
        domain = domain.replace('http://', '');

        // Remove www.
        if (domain.startsWith('www.')) {
            domain = domain.substring(4);
        }

        // Remove path
        Integer slashIndex = domain.indexOf('/');
        if (slashIndex > 0) {
            domain = domain.substring(0, slashIndex);
        }

        return domain;
    }

    /**
     * Match and update accounts with deal metrics
     * Returns a map with match statistics
     */
    public static Map<String, Integer> importMetrics(List<DealMetric> metrics) {
        Map<String, Integer> stats = new Map<String, Integer>{
            'totalCSVRows' => metrics.size(),
            'domainMatches' => 0,
            'nameMatches' => 0,
            'noMatches' => 0,
            'accountsUpdated' => 0
        };

        // Build lookup maps from metrics
        Map<String, DealMetric> metricsByDomain = new Map<String, DealMetric>();
        Map<String, DealMetric> metricsByName = new Map<String, DealMetric>();

        for (DealMetric dm : metrics) {
            if (String.isNotBlank(dm.emailDomain)) {
                metricsByDomain.put(dm.emailDomain.toLowerCase(), dm);
            }
            if (String.isNotBlank(dm.name)) {
                metricsByName.put(dm.name.toLowerCase(), dm);
            }
        }

        // Query accounts with Website or matching Name
        List<Account> accounts = [
            SELECT Id, Name, Website, In_Deals__c, Allocated__c, Declined_Pass__c, Other_Deals__c
            FROM Account
            WHERE Website != null OR Name IN :metricsByName.keySet()
            LIMIT 50000
        ];

        List<Account> toUpdate = new List<Account>();
        Set<String> matchedDomains = new Set<String>();
        Set<String> matchedNames = new Set<String>();

        for (Account acc : accounts) {
            DealMetric matched = null;
            Boolean isDomainMatch = false;

            // Try domain match first (primary)
            if (String.isNotBlank(acc.Website)) {
                String domain = extractDomain(acc.Website);
                if (domain != null && metricsByDomain.containsKey(domain)) {
                    matched = metricsByDomain.get(domain);
                    isDomainMatch = true;
                    matchedDomains.add(domain);
                }
            }

            // Try name match as fallback (secondary)
            if (matched == null && String.isNotBlank(acc.Name)) {
                String nameLower = acc.Name.toLowerCase();
                if (metricsByName.containsKey(nameLower)) {
                    matched = metricsByName.get(nameLower);
                    matchedNames.add(nameLower);
                }
            }

            // Update account if match found
            if (matched != null) {
                acc.In_Deals__c = matched.inDeals;
                acc.Allocated__c = matched.allocated;
                acc.Declined_Pass__c = matched.declinedPass;
                acc.Other_Deals__c = matched.otherDeals;
                toUpdate.add(acc);

                if (isDomainMatch) {
                    stats.put('domainMatches', stats.get('domainMatches') + 1);
                } else {
                    stats.put('nameMatches', stats.get('nameMatches') + 1);
                }
            }
        }

        // Calculate no matches
        stats.put('noMatches', metrics.size() - matchedDomains.size() - matchedNames.size());

        // Update accounts
        if (!toUpdate.isEmpty()) {
            update toUpdate;
            stats.put('accountsUpdated', toUpdate.size());
        }

        return stats;
    }

    /**
     * Run import from Static Resource containing CSV
     * Usage: DealMetricsImporter.runFromStaticResource('TopCompaniesCSV');
     */
    public static Map<String, Integer> runFromStaticResource(String resourceName) {
        StaticResource sr = [SELECT Body FROM StaticResource WHERE Name = :resourceName LIMIT 1];
        String csvContent = sr.Body.toString();
        List<DealMetric> metrics = parseCSV(csvContent);
        return importMetrics(metrics);
    }
}
