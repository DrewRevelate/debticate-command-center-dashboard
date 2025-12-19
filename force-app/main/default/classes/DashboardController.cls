/**
 * Controller for Debticate Command Center Dashboard LWCs
 * Provides aggregated data for target universe, cadence matrix, and engagement health
 */
public with sharing class DashboardController {

    /**
     * Target Universe data - breakdown by Status__c (Target A/B/C/D)
     */
    @AuraEnabled(cacheable=true)
    public static List<TargetData> getTargetUniverseData() {
        List<TargetData> results = new List<TargetData>();

        List<AggregateResult> aggregates = [
            SELECT Status__c status, COUNT(Id) cnt
            FROM Account
            WHERE Status__c IN ('Target A', 'Target B', 'Target C', 'Target D',
                               'Customer', 'Opportunity', 'Dead', 'Partner')
            GROUP BY Status__c
            ORDER BY Status__c
        ];

        for (AggregateResult ar : aggregates) {
            TargetData td = new TargetData();
            td.status = (String) ar.get('status');
            td.count = (Integer) ar.get('cnt');
            td.color = getStatusColor(td.status);
            results.add(td);
        }

        return results;
    }

    /**
     * Cadence Matrix data - Priority codes grouped by series
     */
    @AuraEnabled(cacheable=true)
    public static CadenceMatrixData getCadenceMatrixData() {
        CadenceMatrixData result = new CadenceMatrixData();
        result.series500 = new List<PriorityData>();
        result.series600 = new List<PriorityData>();
        result.series700 = new List<PriorityData>();

        List<AggregateResult> aggregates = [
            SELECT Priority__c priority, Status__c status, COUNT(Id) cnt
            FROM Account
            WHERE Priority__c != null
            GROUP BY Priority__c, Status__c
            ORDER BY Priority__c
        ];

        for (AggregateResult ar : aggregates) {
            String priority = (String) ar.get('priority');
            PriorityData pd = new PriorityData();
            pd.priority = priority;
            pd.status = (String) ar.get('status');
            pd.count = (Integer) ar.get('cnt');

            // D500 series: 500-599 (Top 525 Banks)
            if (priority.startsWith('5')) {
                result.series500.add(pd);
            // D600 series: 600-699 (Non-Banks)
            } else if (priority.startsWith('6')) {
                result.series600.add(pd);
            // D700 series: 700-799 (Other Banks & Intl)
            } else if (priority.startsWith('7')) {
                result.series700.add(pd);
            }
        }

        // Calculate totals
        result.total500 = sumCounts(result.series500);
        result.total600 = sumCounts(result.series600);
        result.total700 = sumCounts(result.series700);

        return result;
    }

    /**
     * Engagement Health data - accounts by last activity age
     */
    @AuraEnabled(cacheable=true)
    public static EngagementHealthData getEngagementHealthData() {
        EngagementHealthData result = new EngagementHealthData();
        result.byStatus = new List<StatusEngagement>();

        // Calculate date thresholds
        Date today = Date.today();
        Date thirtyDaysAgo = today.addDays(-30);
        Date ninetyDaysAgo = today.addDays(-90);

        // Get all target accounts with their activity dates
        List<Account> accounts = [
            SELECT Id, Status__c, LastActivityDate
            FROM Account
            WHERE Status__c IN ('Target A', 'Target B', 'Target C', 'Target D')
            ORDER BY Status__c
        ];

        // Group by status and categorize by engagement
        Map<String, StatusEngagement> statusMap = new Map<String, StatusEngagement>();
        for (String status : new List<String>{'Target A', 'Target B', 'Target C', 'Target D'}) {
            StatusEngagement se = new StatusEngagement();
            se.status = status;
            se.total = 0;
            se.recentCount = 0;
            se.agingCount = 0;
            se.staleCount = 0;
            statusMap.put(status, se);
        }

        Integer totalRecent = 0;
        Integer totalAging = 0;
        Integer totalStale = 0;

        for (Account acc : accounts) {
            StatusEngagement se = statusMap.get(acc.Status__c);
            if (se == null) continue;

            se.total++;

            if (acc.LastActivityDate != null && acc.LastActivityDate >= thirtyDaysAgo) {
                se.recentCount++;
                totalRecent++;
            } else if (acc.LastActivityDate != null && acc.LastActivityDate >= ninetyDaysAgo) {
                se.agingCount++;
                totalAging++;
            } else {
                se.staleCount++;
                totalStale++;
            }
        }

        // Calculate percentages and build result
        for (String status : new List<String>{'Target A', 'Target B', 'Target C', 'Target D'}) {
            StatusEngagement se = statusMap.get(status);
            se.recentPct = se.total > 0 ? (se.recentCount * 100 / se.total) : 0;
            se.agingPct = se.total > 0 ? (se.agingCount * 100 / se.total) : 0;
            se.stalePct = se.total > 0 ? (se.staleCount * 100 / se.total) : 0;
            result.byStatus.add(se);
        }

        result.totalRecent = totalRecent;
        result.totalAging = totalAging;
        result.totalStale = totalStale;
        result.totalAccounts = totalRecent + totalAging + totalStale;

        return result;
    }

    /**
     * Get accounts for drill-down views
     */
    @AuraEnabled(cacheable=true)
    public static List<AccountData> getAccountsByFilter(String filterType, String filterValue) {
        List<AccountData> results = new List<AccountData>();
        String query = 'SELECT Id, Name, Status__c, Priority__c, LastActivityDate, Last_Attempt__c, Last_Reach__c ' +
                       'FROM Account WHERE ';

        if (filterType == 'status') {
            query += 'Status__c = :filterValue';
        } else if (filterType == 'priority') {
            query += 'Priority__c = :filterValue';
        } else if (filterType == 'engagement') {
            if (filterValue == 'recent') {
                query += 'LastActivityDate >= LAST_N_DAYS:30 AND Status__c LIKE \'Target%\'';
            } else if (filterValue == 'aging') {
                query += 'LastActivityDate >= LAST_N_DAYS:90 AND LastActivityDate < LAST_N_DAYS:30 AND Status__c LIKE \'Target%\'';
            } else if (filterValue == 'stale') {
                query += '(LastActivityDate < LAST_N_DAYS:90 OR LastActivityDate = null) AND Status__c LIKE \'Target%\'';
            }
        }

        query += ' ORDER BY Name LIMIT 200';

        for (Account acc : Database.query(query)) {
            AccountData ad = new AccountData();
            ad.id = acc.Id;
            ad.name = acc.Name;
            ad.status = acc.Status__c;
            ad.priority = acc.Priority__c;
            ad.lastActivityDate = acc.LastActivityDate;
            ad.lastAttempt = acc.Last_Attempt__c;
            ad.lastReach = acc.Last_Reach__c;
            ad.url = '/' + acc.Id;
            results.add(ad);
        }

        return results;
    }

    /**
     * Update account inline (legacy method name)
     */
    @AuraEnabled
    public static void updateAccount(Id accountId, String field, Object value) {
        Account acc = new Account(Id = accountId);
        acc.put(field, value);
        update acc;
    }

    /**
     * Update a single field on an Account record (for inline editing)
     */
    @AuraEnabled
    public static void updateAccountField(Id accountId, String fieldName, String fieldValue) {
        Account acc = new Account(Id = accountId);
        acc.put(fieldName, fieldValue);
        update acc;
    }

    // Helper methods - Professional enterprise color palette
    private static String getStatusColor(String status) {
        Map<String, String> colorMap = new Map<String, String>{
            'Target A' => '#0176D3',  // Salesforce Blue - highest priority
            'Target B' => '#0D9DDA',  // Teal
            'Target C' => '#5867E8',  // Indigo
            'Target D' => '#7F8DE1',  // Light Indigo
            'Customer' => '#2E844A',  // Success Green
            'Opportunity' => '#C87F17', // Muted Gold
            'Dead' => '#706E6B',      // Neutral Gray
            'Partner' => '#8A68C5'    // Professional Purple
        };
        return colorMap.get(status) != null ? colorMap.get(status) : '#939393';
    }

    private static Integer sumCounts(List<PriorityData> items) {
        Integer total = 0;
        for (PriorityData pd : items) {
            total += pd.count;
        }
        return total;
    }

    // Data classes
    public class TargetData {
        @AuraEnabled public String status;
        @AuraEnabled public Integer count;
        @AuraEnabled public String color;
    }

    public class CadenceMatrixData {
        @AuraEnabled public List<PriorityData> series500;
        @AuraEnabled public List<PriorityData> series600;
        @AuraEnabled public List<PriorityData> series700;
        @AuraEnabled public Integer total500;
        @AuraEnabled public Integer total600;
        @AuraEnabled public Integer total700;
        @AuraEnabled public Decimal totalAssets500;
        @AuraEnabled public Decimal totalAssets600;
        @AuraEnabled public Decimal totalAssets700;
        @AuraEnabled public Integer d525Count;        // Top 525 banks by assets
        @AuraEnabled public Decimal d525TotalAssets;  // Total assets of D525 universe
    }

    public class PriorityData {
        @AuraEnabled public String priority;
        @AuraEnabled public String status;
        @AuraEnabled public Integer count;
        @AuraEnabled public Decimal totalAssets;
    }

    public class EngagementHealthData {
        @AuraEnabled public List<StatusEngagement> byStatus;
        @AuraEnabled public Integer totalRecent;
        @AuraEnabled public Integer totalAging;
        @AuraEnabled public Integer totalStale;
        @AuraEnabled public Integer totalAccounts;
    }

    public class StatusEngagement {
        @AuraEnabled public String status;
        @AuraEnabled public Integer total;
        @AuraEnabled public Integer recentCount;
        @AuraEnabled public Integer agingCount;
        @AuraEnabled public Integer staleCount;
        @AuraEnabled public Integer recentPct;
        @AuraEnabled public Integer agingPct;
        @AuraEnabled public Integer stalePct;
    }

    public class AccountData {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String priority;
        @AuraEnabled public Decimal totalAssets;
        @AuraEnabled public Decimal annualRevenue;
        @AuraEnabled public Date lastActivityDate;
        @AuraEnabled public Date lastAttempt;
        @AuraEnabled public Date lastReach;
        @AuraEnabled public String url;
        @AuraEnabled public Integer inDeals;
        @AuraEnabled public Integer allocated;
        @AuraEnabled public Integer declinedPass;
    }

    // ========================================
    // FOOTPRINT COMPARISON METHODS
    // ========================================

    /**
     * Search banks for footprint lookup
     */
    @AuraEnabled(cacheable=true)
    public static List<BankOption> searchBanksForFootprint(String searchTerm) {
        List<BankOption> results = new List<BankOption>();
        String searchPattern = '%' + searchTerm + '%';

        List<Account> banks = [
            SELECT Id, Name, Operating_States__c, Status__c, Total_Assets__c
            FROM Account
            WHERE Name LIKE :searchPattern
            AND Operating_States__c != null
            AND Status__c IN ('Target A', 'Target B', 'Target C', 'Target D', 'Customer', 'Opportunity')
            ORDER BY Name
            LIMIT 20
        ];

        for (Account bank : banks) {
            BankOption bo = new BankOption();
            bo.id = bank.Id;
            bo.name = bank.Name;
            bo.status = bank.Status__c;
            bo.stateCount = bank.Operating_States__c != null ?
                bank.Operating_States__c.split(';').size() : 0;
            bo.totalAssets = bank.Total_Assets__c;
            results.add(bo);
        }

        return results;
    }

    /**
     * Get footprint details for a specific bank
     */
    @AuraEnabled(cacheable=true)
    public static FootprintData getBankFootprint(Id bankId) {
        Account bank = [
            SELECT Id, Name, Operating_States__c, Status__c, BillingState
            FROM Account
            WHERE Id = :bankId
            LIMIT 1
        ];

        FootprintData fd = new FootprintData();
        fd.bankId = bank.Id;
        fd.bankName = bank.Name;
        fd.status = bank.Status__c;
        fd.headquartersState = bank.BillingState;
        fd.states = new List<String>();

        if (bank.Operating_States__c != null) {
            fd.states = bank.Operating_States__c.split(';');
            fd.states.sort();
        }
        fd.stateCount = fd.states.size();

        return fd;
    }

    /**
     * Compare footprint between two banks
     */
    @AuraEnabled(cacheable=true)
    public static FootprintComparison compareFootprints(Id bankId1, Id bankId2) {
        List<Account> banks = [
            SELECT Id, Name, Operating_States__c, Status__c
            FROM Account
            WHERE Id IN (:bankId1, :bankId2)
        ];

        if (banks.size() != 2) return null;

        Account bank1 = banks[0].Id == bankId1 ? banks[0] : banks[1];
        Account bank2 = banks[0].Id == bankId2 ? banks[0] : banks[1];

        Set<String> states1 = new Set<String>();
        Set<String> states2 = new Set<String>();

        if (bank1.Operating_States__c != null) {
            states1.addAll(bank1.Operating_States__c.split(';'));
        }
        if (bank2.Operating_States__c != null) {
            states2.addAll(bank2.Operating_States__c.split(';'));
        }

        // Calculate overlap
        Set<String> overlap = new Set<String>(states1);
        overlap.retainAll(states2);

        // States only in bank1
        Set<String> only1 = new Set<String>(states1);
        only1.removeAll(states2);

        // States only in bank2
        Set<String> only2 = new Set<String>(states2);
        only2.removeAll(states1);

        FootprintComparison fc = new FootprintComparison();
        fc.bank1Name = bank1.Name;
        fc.bank2Name = bank2.Name;
        fc.bank1States = new List<String>(states1);
        fc.bank2States = new List<String>(states2);
        fc.overlapStates = new List<String>(overlap);
        fc.onlyBank1States = new List<String>(only1);
        fc.onlyBank2States = new List<String>(only2);
        fc.bank1States.sort();
        fc.bank2States.sort();
        fc.overlapStates.sort();
        fc.onlyBank1States.sort();
        fc.onlyBank2States.sort();

        // Calculate overlap percentage (relative to smaller footprint)
        Integer minStates = Math.min(states1.size(), states2.size());
        fc.overlapPercent = minStates > 0 ? Math.round((Decimal)overlap.size() / minStates * 100) : 0;

        return fc;
    }

    /**
     * Find banks with highest footprint overlap to selected bank
     */
    @AuraEnabled(cacheable=true)
    public static List<FootprintMatch> findFootprintMatches(Id bankId, Integer limitCount) {
        Account sourceBank = [
            SELECT Id, Name, Operating_States__c
            FROM Account
            WHERE Id = :bankId
            LIMIT 1
        ];

        if (sourceBank.Operating_States__c == null) return new List<FootprintMatch>();

        Set<String> sourceStates = new Set<String>(sourceBank.Operating_States__c.split(';'));

        // Get all other banks with footprints
        List<Account> otherBanks = [
            SELECT Id, Name, Operating_States__c, Status__c, Total_Assets__c
            FROM Account
            WHERE Id != :bankId
            AND Operating_States__c != null
            AND Status__c IN ('Target A', 'Target B', 'Target C', 'Target D', 'Customer', 'Opportunity')
            LIMIT 500
        ];

        List<FootprintMatch> matches = new List<FootprintMatch>();

        for (Account bank : otherBanks) {
            Set<String> bankStates = new Set<String>(bank.Operating_States__c.split(';'));

            Set<String> overlap = new Set<String>(sourceStates);
            overlap.retainAll(bankStates);

            if (overlap.size() > 0) {
                FootprintMatch fm = new FootprintMatch();
                fm.bankId = bank.Id;
                fm.bankName = bank.Name;
                fm.status = bank.Status__c;
                fm.totalAssets = bank.Total_Assets__c;
                fm.overlapCount = overlap.size();
                fm.bankStateCount = bankStates.size();
                fm.overlapStates = new List<String>(overlap);
                fm.overlapStates.sort();

                // Calculate overlap % relative to source bank
                fm.overlapPercent = Math.round((Decimal)overlap.size() / sourceStates.size() * 100);
                fm.url = '/' + bank.Id;

                matches.add(fm);
            }
        }

        // Sort by overlap count descending
        matches.sort();

        // Return top matches
        if (matches.size() > limitCount) {
            List<FootprintMatch> topMatches = new List<FootprintMatch>();
            for (Integer i = 0; i < limitCount; i++) {
                topMatches.add(matches[i]);
            }
            return topMatches;
        }

        return matches;
    }

    // Footprint data classes
    public class BankOption {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public Integer stateCount;
        @AuraEnabled public Decimal totalAssets;
    }

    public class FootprintData {
        @AuraEnabled public Id bankId;
        @AuraEnabled public String bankName;
        @AuraEnabled public String status;
        @AuraEnabled public String headquartersState;
        @AuraEnabled public List<String> states;
        @AuraEnabled public Integer stateCount;
    }

    public class FootprintComparison {
        @AuraEnabled public String bank1Name;
        @AuraEnabled public String bank2Name;
        @AuraEnabled public List<String> bank1States;
        @AuraEnabled public List<String> bank2States;
        @AuraEnabled public List<String> overlapStates;
        @AuraEnabled public List<String> onlyBank1States;
        @AuraEnabled public List<String> onlyBank2States;
        @AuraEnabled public Integer overlapPercent;
    }

    public class FootprintMatch implements Comparable {
        @AuraEnabled public Id bankId;
        @AuraEnabled public String bankName;
        @AuraEnabled public String status;
        @AuraEnabled public Decimal totalAssets;
        @AuraEnabled public Integer overlapCount;
        @AuraEnabled public Integer overlapPercent;
        @AuraEnabled public Integer bankStateCount;
        @AuraEnabled public List<String> overlapStates;
        @AuraEnabled public String url;

        public Integer compareTo(Object other) {
            FootprintMatch fm = (FootprintMatch)other;
            // Sort descending by overlap count
            return fm.overlapCount - this.overlapCount;
        }
    }

    // ========================================
    // UNIFIED FILTERED DASHBOARD METHODS
    // ========================================

    /**
     * Filter criteria object for compound queries
     */
    public class DashboardFilters {
        @AuraEnabled public List<String> targetStatuses { get; set; }
        @AuraEnabled public List<String> prioritySeries { get; set; }
        @AuraEnabled public String engagementStatus { get; set; }
        @AuraEnabled public String assetTier { get; set; }  // large, mid, small
        @AuraEnabled public Date startDate { get; set; }
        @AuraEnabled public Date endDate { get; set; }
        @AuraEnabled public String searchTerm { get; set; }
        @AuraEnabled public Boolean top525 { get; set; }    // Filter to top 525 banks by Total_Assets__c
    }

    // Asset tier thresholds (values in thousands - Total_Assets__c field stores in thousands)
    private static final Decimal LARGE_ASSET_THRESHOLD = 2500000;  // $2.5B+
    private static final Decimal MID_ASSET_THRESHOLD = 500000;     // $500M

    /**
     * Unified dashboard data response
     */
    public class DashboardData {
        @AuraEnabled public List<TargetData> targetUniverse { get; set; }
        @AuraEnabled public CadenceMatrixData cadenceMatrix { get; set; }
        @AuraEnabled public EngagementHealthData engagementHealth { get; set; }
        @AuraEnabled public KpiSummary kpiSummary { get; set; }
        @AuraEnabled public List<AccountData> filteredAccounts { get; set; }
    }

    /**
     * KPI summary metrics
     */
    public class KpiSummary {
        @AuraEnabled public Integer totalAccounts { get; set; }
        @AuraEnabled public Integer healthScore { get; set; }
        @AuraEnabled public Integer coverageRate { get; set; }
        @AuraEnabled public Integer staleCount { get; set; }
        @AuraEnabled public Integer activeCount { get; set; }
        @AuraEnabled public Integer agingCount { get; set; }
        @AuraEnabled public Decimal totalAssets { get; set; }
        @AuraEnabled public Integer inDealsCount { get; set; }
        @AuraEnabled public Integer totalInDeals { get; set; }
        @AuraEnabled public Integer totalAllocated { get; set; }
        @AuraEnabled public Integer totalDeclinedPass { get; set; }
    }

    /**
     * Master data fetch with filters - returns all dashboard data in one call
     */
    @AuraEnabled(cacheable=true)
    public static DashboardData getDashboardData(DashboardFilters filters) {
        DashboardData result = new DashboardData();

        // Get filtered accounts first
        List<Account> accounts = getFilteredAccounts(filters);

        // Build all dashboard metrics from filtered data
        result.targetUniverse = buildTargetUniverse(accounts);
        result.cadenceMatrix = buildCadenceMatrix(accounts);
        result.engagementHealth = buildEngagementHealth(accounts);
        result.kpiSummary = buildKpiSummary(accounts);
        result.filteredAccounts = buildAccountList(accounts);

        return result;
    }

    /**
     * Get accounts matching filter criteria
     */
    private static List<Account> getFilteredAccounts(DashboardFilters filters) {
        String query = 'SELECT Id, Name, Status__c, Priority__c, LastActivityDate, ' +
                       'Last_Attempt__c, Last_Reach__c, Operating_States__c, Total_Assets__c, ' +
                       'Annual_Revenue_Est__c, BillingState, In_Deals__c, Allocated__c, ' +
                       'Declined_Pass__c, Other_Deals__c ' +
                       'FROM Account WHERE Id != null';

        List<String> conditions = new List<String>();

        // Top 525 filter - banks with $2.5B+ assets, ordered by assets descending, limited to 525
        Boolean isTop525Filter = filters != null && filters.top525 == true;
        if (isTop525Filter) {
            // For D525: filter by asset threshold
            conditions.add('Total_Assets__c >= ' + D525_ASSET_THRESHOLD);
        }

        // Target status filter
        if (filters != null && filters.targetStatuses != null && !filters.targetStatuses.isEmpty()) {
            List<String> quotedStatuses = new List<String>();
            for (String s : filters.targetStatuses) {
                quotedStatuses.add('\'' + String.escapeSingleQuotes(s) + '\'');
            }
            conditions.add('Status__c IN (' + String.join(quotedStatuses, ',') + ')');
        } else {
            // Default: show all relevant statuses (including null for uncategorized accounts)
            conditions.add('(Status__c IN (\'Target A\', \'Target B\', \'Target C\', \'Target D\', \'Customer\', \'Customer - Lost\', \'Opportunity\', \'Dead\', \'Partner\', \'Interest\') OR Status__c = null)');
        }

        // Priority series filter (D500=500-599, D600=600-699, D700=700-799)
        // Note: This is separate from D525 which is asset-based
        if (filters != null && filters.prioritySeries != null && !filters.prioritySeries.isEmpty()) {
            List<String> priorityConditions = new List<String>();
            for (String series : filters.prioritySeries) {
                if (series == '500') {
                    priorityConditions.add('(Priority__c >= \'500\' AND Priority__c < \'600\')');
                } else if (series == '600') {
                    priorityConditions.add('(Priority__c >= \'600\' AND Priority__c < \'700\')');
                } else if (series == '700') {
                    priorityConditions.add('(Priority__c >= \'700\' AND Priority__c < \'800\')');
                }
            }
            if (!priorityConditions.isEmpty()) {
                conditions.add('(' + String.join(priorityConditions, ' OR ') + ')');
            }
        }
        // When "All" is selected (empty prioritySeries), no Priority filter - include all accounts

        // Engagement status filter
        if (filters != null && filters.engagementStatus != null && filters.engagementStatus != '') {
            Date today = Date.today();
            Date thirtyDaysAgo = today.addDays(-30);
            Date ninetyDaysAgo = today.addDays(-90);

            if (filters.engagementStatus == 'recent') {
                conditions.add('LastActivityDate >= ' + String.valueOf(thirtyDaysAgo));
            } else if (filters.engagementStatus == 'aging') {
                conditions.add('LastActivityDate >= ' + String.valueOf(ninetyDaysAgo));
                conditions.add('LastActivityDate < ' + String.valueOf(thirtyDaysAgo));
            } else if (filters.engagementStatus == 'stale') {
                conditions.add('(LastActivityDate < ' + String.valueOf(ninetyDaysAgo) + ' OR LastActivityDate = null)');
            }
        }

        // Date range filter
        if (filters != null && filters.startDate != null) {
            conditions.add('LastActivityDate >= ' + String.valueOf(filters.startDate));
        }
        if (filters != null && filters.endDate != null) {
            conditions.add('LastActivityDate <= ' + String.valueOf(filters.endDate));
        }

        // Search term filter
        if (filters != null && filters.searchTerm != null && filters.searchTerm.length() > 0) {
            String searchPattern = '%' + String.escapeSingleQuotes(filters.searchTerm) + '%';
            conditions.add('Name LIKE \'' + searchPattern + '\'');
        }

        if (!conditions.isEmpty()) {
            query += ' AND ' + String.join(conditions, ' AND ');
        }

        // For D525: order by assets descending and limit to 525
        if (isTop525Filter) {
            query += ' ORDER BY Total_Assets__c DESC NULLS LAST LIMIT 525';
        } else {
            query += ' ORDER BY Name LIMIT 2000';
        }

        return Database.query(query);
    }

    /**
     * Build target universe data from filtered accounts
     */
    private static List<TargetData> buildTargetUniverse(List<Account> accounts) {
        Map<String, Integer> statusCounts = new Map<String, Integer>();

        for (Account acc : accounts) {
            String status = acc.Status__c;
            if (status != null) {
                Integer count = statusCounts.get(status);
                statusCounts.put(status, count == null ? 1 : count + 1);
            }
        }

        // Build results in predefined order
        List<String> statusOrder = new List<String>{
            'Target A', 'Target B', 'Target C', 'Target D',
            'Customer', 'Opportunity', 'Dead', 'Partner'
        };

        List<TargetData> results = new List<TargetData>();
        for (String status : statusOrder) {
            if (statusCounts.containsKey(status)) {
                TargetData td = new TargetData();
                td.status = status;
                td.count = statusCounts.get(status);
                td.color = getStatusColor(status);
                results.add(td);
            }
        }

        // Add any statuses not in the predefined order
        for (String status : statusCounts.keySet()) {
            Boolean found = false;
            for (String orderedStatus : statusOrder) {
                if (status == orderedStatus) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                TargetData td = new TargetData();
                td.status = status;
                td.count = statusCounts.get(status);
                td.color = getStatusColor(status);
                results.add(td);
            }
        }

        return results;
    }

    /**
     * Build cadence matrix data from filtered accounts
     */
    private static CadenceMatrixData buildCadenceMatrix(List<Account> accounts) {
        CadenceMatrixData result = new CadenceMatrixData();
        result.series500 = new List<PriorityData>();
        result.series600 = new List<PriorityData>();
        result.series700 = new List<PriorityData>();

        // Group by priority and status - track both count and assets
        Map<String, Map<String, Integer>> priorityStatusCounts = new Map<String, Map<String, Integer>>();
        Map<String, Map<String, Decimal>> priorityStatusAssets = new Map<String, Map<String, Decimal>>();

        for (Account acc : accounts) {
            String priority = acc.Priority__c;
            String status = acc.Status__c;
            if (priority == null) continue;

            // Track counts
            if (!priorityStatusCounts.containsKey(priority)) {
                priorityStatusCounts.put(priority, new Map<String, Integer>());
            }
            Map<String, Integer> statusMap = priorityStatusCounts.get(priority);
            Integer count = statusMap.get(status);
            statusMap.put(status, count == null ? 1 : count + 1);

            // Track Annual Revenue Est.
            if (!priorityStatusAssets.containsKey(priority)) {
                priorityStatusAssets.put(priority, new Map<String, Decimal>());
            }
            Map<String, Decimal> assetMap = priorityStatusAssets.get(priority);
            Decimal assets = assetMap.get(status);
            Decimal accRevenue = acc.Annual_Revenue_Est__c != null ? acc.Annual_Revenue_Est__c : 0;
            assetMap.put(status, assets == null ? accRevenue : assets + accRevenue);
        }

        for (String priority : priorityStatusCounts.keySet()) {
            Map<String, Integer> statusMap = priorityStatusCounts.get(priority);
            Map<String, Decimal> assetMap = priorityStatusAssets.get(priority);
            for (String status : statusMap.keySet()) {
                PriorityData pd = new PriorityData();
                pd.priority = priority;
                pd.status = status;
                pd.count = statusMap.get(status);
                pd.totalAssets = assetMap != null && assetMap.get(status) != null ? assetMap.get(status) : 0;

                // D500 series: 500-599 (Top 525 Banks)
                if (priority.startsWith('5')) {
                    result.series500.add(pd);
                // D600 series: 600-699 (Non-Banks)
                } else if (priority.startsWith('6')) {
                    result.series600.add(pd);
                // D700 series: 700-799 (Other Banks & Intl)
                } else if (priority.startsWith('7')) {
                    result.series700.add(pd);
                }
            }
        }

        result.total500 = sumCounts(result.series500);
        result.total600 = sumCounts(result.series600);
        result.total700 = sumCounts(result.series700);
        result.totalAssets500 = sumAssets(result.series500);
        result.totalAssets600 = sumAssets(result.series600);
        result.totalAssets700 = sumAssets(result.series700);

        // Calculate D525: Top 525 banks by Total_Assets__c (regardless of priority series)
        // Query separately to get accurate count of banks with $2.5B+ assets
        List<AggregateResult> d525Agg = [
            SELECT COUNT(Id) cnt, SUM(Total_Assets__c) totalAssets
            FROM Account
            WHERE Total_Assets__c >= :D525_ASSET_THRESHOLD
            AND Status__c IN ('Target A', 'Target B', 'Target C', 'Target D', 'Customer', 'Opportunity')
        ];
        if (!d525Agg.isEmpty()) {
            result.d525Count = (Integer) d525Agg[0].get('cnt');
            result.d525TotalAssets = (Decimal) d525Agg[0].get('totalAssets');
            // Cap at 525 for display (actual filter handles the limit)
            if (result.d525Count > 525) {
                result.d525Count = 525;
            }
        } else {
            result.d525Count = 0;
            result.d525TotalAssets = 0;
        }

        return result;
    }

    /**
     * Helper to sum assets from priority data list
     */
    private static Decimal sumAssets(List<PriorityData> items) {
        Decimal total = 0;
        for (PriorityData pd : items) {
            if (pd.totalAssets != null) {
                total += pd.totalAssets;
            }
        }
        return total;
    }

    /**
     * Build engagement health data from filtered accounts
     */
    private static EngagementHealthData buildEngagementHealth(List<Account> accounts) {
        EngagementHealthData result = new EngagementHealthData();
        result.byStatus = new List<StatusEngagement>();

        Date today = Date.today();
        Date thirtyDaysAgo = today.addDays(-30);
        Date ninetyDaysAgo = today.addDays(-90);

        Map<String, StatusEngagement> statusMap = new Map<String, StatusEngagement>();
        for (String status : new List<String>{'Target A', 'Target B', 'Target C', 'Target D'}) {
            StatusEngagement se = new StatusEngagement();
            se.status = status;
            se.total = 0;
            se.recentCount = 0;
            se.agingCount = 0;
            se.staleCount = 0;
            statusMap.put(status, se);
        }

        Integer totalRecent = 0;
        Integer totalAging = 0;
        Integer totalStale = 0;

        for (Account acc : accounts) {
            if (acc.Status__c == null || !acc.Status__c.startsWith('Target')) continue;

            StatusEngagement se = statusMap.get(acc.Status__c);
            if (se == null) continue;

            se.total++;

            if (acc.LastActivityDate != null && acc.LastActivityDate >= thirtyDaysAgo) {
                se.recentCount++;
                totalRecent++;
            } else if (acc.LastActivityDate != null && acc.LastActivityDate >= ninetyDaysAgo) {
                se.agingCount++;
                totalAging++;
            } else {
                se.staleCount++;
                totalStale++;
            }
        }

        for (String status : new List<String>{'Target A', 'Target B', 'Target C', 'Target D'}) {
            StatusEngagement se = statusMap.get(status);
            se.recentPct = se.total > 0 ? (se.recentCount * 100 / se.total) : 0;
            se.agingPct = se.total > 0 ? (se.agingCount * 100 / se.total) : 0;
            se.stalePct = se.total > 0 ? (se.staleCount * 100 / se.total) : 0;
            result.byStatus.add(se);
        }

        result.totalRecent = totalRecent;
        result.totalAging = totalAging;
        result.totalStale = totalStale;
        result.totalAccounts = totalRecent + totalAging + totalStale;

        return result;
    }

    /**
     * Build KPI summary from filtered accounts
     */
    private static KpiSummary buildKpiSummary(List<Account> accounts) {
        KpiSummary kpi = new KpiSummary();

        Date today = Date.today();
        Date thirtyDaysAgo = today.addDays(-30);
        Date ninetyDaysAgo = today.addDays(-90);

        Integer totalAccounts = 0;
        Integer activeCount = 0;
        Integer agingCount = 0;
        Integer staleCount = 0;
        Integer withPriority = 0;
        Decimal totalAssets = 0;
        Integer inDealsCount = 0;
        Integer totalInDeals = 0;
        Integer totalAllocated = 0;
        Integer totalDeclinedPass = 0;

        for (Account acc : accounts) {
            totalAccounts++;

            if (acc.LastActivityDate != null && acc.LastActivityDate >= thirtyDaysAgo) {
                activeCount++;
            } else if (acc.LastActivityDate != null && acc.LastActivityDate >= ninetyDaysAgo) {
                agingCount++;
            } else {
                staleCount++;
            }

            if (acc.Priority__c != null) {
                withPriority++;
            }

            if (acc.Annual_Revenue_Est__c != null) {
                totalAssets += acc.Annual_Revenue_Est__c;
            }

            // Deal metrics
            if (acc.In_Deals__c != null && acc.In_Deals__c > 0) {
                inDealsCount++;
                totalInDeals += acc.In_Deals__c.intValue();
            }
            if (acc.Allocated__c != null) {
                totalAllocated += acc.Allocated__c.intValue();
            }
            if (acc.Declined_Pass__c != null) {
                totalDeclinedPass += acc.Declined_Pass__c.intValue();
            }
        }

        kpi.totalAccounts = totalAccounts;
        kpi.activeCount = activeCount;
        kpi.agingCount = agingCount;
        kpi.staleCount = staleCount;
        kpi.totalAssets = totalAssets;
        kpi.inDealsCount = inDealsCount;
        kpi.totalInDeals = totalInDeals;
        kpi.totalAllocated = totalAllocated;
        kpi.totalDeclinedPass = totalDeclinedPass;

        // Health score = percentage of accounts with recent activity
        kpi.healthScore = totalAccounts > 0 ? (activeCount * 100 / totalAccounts) : 0;

        // Coverage rate = percentage of accounts with priority codes
        kpi.coverageRate = totalAccounts > 0 ? (withPriority * 100 / totalAccounts) : 0;

        return kpi;
    }

    /**
     * Build account list for drill-down/export
     */
    private static List<AccountData> buildAccountList(List<Account> accounts) {
        List<AccountData> results = new List<AccountData>();
        Integer maxResults = 200;

        for (Account acc : accounts) {
            if (results.size() >= maxResults) break;

            AccountData ad = new AccountData();
            ad.id = acc.Id;
            ad.name = acc.Name;
            ad.status = acc.Status__c;
            ad.priority = acc.Priority__c;
            ad.totalAssets = acc.Total_Assets__c;
            ad.annualRevenue = acc.Annual_Revenue_Est__c;
            ad.lastActivityDate = acc.LastActivityDate;
            ad.lastAttempt = acc.Last_Attempt__c;
            ad.lastReach = acc.Last_Reach__c;
            ad.url = '/' + acc.Id;
            ad.inDeals = acc.In_Deals__c != null ? acc.In_Deals__c.intValue() : 0;
            ad.allocated = acc.Allocated__c != null ? acc.Allocated__c.intValue() : 0;
            ad.declinedPass = acc.Declined_Pass__c != null ? acc.Declined_Pass__c.intValue() : 0;
            results.add(ad);
        }

        return results;
    }

    // ========================================
    // OPPORTUNITIES BY STAGE METHODS
    // ========================================

    /**
     * Opportunity stage data class
     */
    public class OpportunityStageData {
        @AuraEnabled public String stageName { get; set; }
        @AuraEnabled public Integer count { get; set; }
        @AuraEnabled public Decimal amount { get; set; }
        @AuraEnabled public String color { get; set; }
        @AuraEnabled public Integer percentage { get; set; }
    }

    /**
     * Get Opportunities grouped by Stage
     */
    @AuraEnabled(cacheable=true)
    public static List<OpportunityStageData> getOpportunitiesByStage(DashboardFilters filters) {
        List<OpportunityStageData> results = new List<OpportunityStageData>();

        // Build query based on filters
        String query = 'SELECT StageName, COUNT(Id) cnt, SUM(Amount) totalAmount ' +
                       'FROM Opportunity WHERE IsClosed = false';

        List<String> conditions = new List<String>();

        // Filter by Account priority series if specified
        if (filters != null && filters.prioritySeries != null && !filters.prioritySeries.isEmpty()) {
            List<String> priorityConditions = new List<String>();
            for (String series : filters.prioritySeries) {
                if (series == '500') {
                    priorityConditions.add('(Account.Priority__c >= \'500\' AND Account.Priority__c < \'600\')');
                } else if (series == '600') {
                    priorityConditions.add('(Account.Priority__c >= \'600\' AND Account.Priority__c < \'700\')');
                } else if (series == '700') {
                    priorityConditions.add('(Account.Priority__c >= \'700\' AND Account.Priority__c < \'800\')');
                }
            }
            if (!priorityConditions.isEmpty()) {
                conditions.add('(' + String.join(priorityConditions, ' OR ') + ')');
            }
        }

        // Filter by Account status if specified
        if (filters != null && filters.targetStatuses != null && !filters.targetStatuses.isEmpty()) {
            List<String> quotedStatuses = new List<String>();
            for (String s : filters.targetStatuses) {
                quotedStatuses.add('\'' + String.escapeSingleQuotes(s) + '\'');
            }
            conditions.add('Account.Status__c IN (' + String.join(quotedStatuses, ',') + ')');
        }

        if (!conditions.isEmpty()) {
            query += ' AND ' + String.join(conditions, ' AND ');
        }

        query += ' GROUP BY StageName ORDER BY StageName';

        List<AggregateResult> aggregates = Database.query(query);

        // Calculate total for percentages
        Decimal totalAmount = 0;
        for (AggregateResult ar : aggregates) {
            Decimal amt = (Decimal) ar.get('totalAmount');
            if (amt != null) totalAmount += amt;
        }

        // Stage colors (Salesforce-like)
        Map<String, String> stageColors = new Map<String, String>{
            'Prospecting' => '#0070d2',
            'Qualification' => '#1589ee',
            'Needs Analysis' => '#04844b',
            'Value Proposition' => '#3ba755',
            'Id. Decision Makers' => '#f4bc25',
            'Perception Analysis' => '#ff9a3c',
            'Proposal/Price Quote' => '#d4504c',
            'Negotiation/Review' => '#c23934',
            'Closed Won' => '#04844b',
            'Closed Lost' => '#706e6b'
        };

        Integer colorIndex = 0;
        String[] defaultColors = new String[]{'#0070d2', '#1589ee', '#04844b', '#3ba755', '#f4bc25', '#ff9a3c', '#d4504c', '#706e6b'};

        for (AggregateResult ar : aggregates) {
            OpportunityStageData osd = new OpportunityStageData();
            osd.stageName = (String) ar.get('StageName');
            osd.count = (Integer) ar.get('cnt');
            osd.amount = (Decimal) ar.get('totalAmount');
            if (osd.amount == null) osd.amount = 0;

            // Assign color
            osd.color = stageColors.get(osd.stageName);
            if (osd.color == null) {
                osd.color = defaultColors[Math.mod(colorIndex, defaultColors.size())];
                colorIndex++;
            }

            // Calculate percentage of total
            osd.percentage = totalAmount > 0 ? (Integer) Math.round(osd.amount / totalAmount * 100) : 0;

            results.add(osd);
        }

        return results;
    }

    // ========================================
    // SAVED VIEWS METHODS
    // ========================================

    /**
     * Saved view data class
     */
    public class SavedViewData {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String filterJson { get; set; }
        @AuraEnabled public Boolean isDefault { get; set; }
        @AuraEnabled public Datetime createdDate { get; set; }
    }

    /**
     * Get user's saved views
     */
    @AuraEnabled(cacheable=true)
    public static List<SavedViewData> getSavedViews() {
        List<SavedViewData> results = new List<SavedViewData>();

        // Query custom metadata or custom setting for saved views
        // For now, return empty list - will implement with custom object
        return results;
    }

    /**
     * Save a new view
     */
    @AuraEnabled
    public static Id saveView(String viewName, String filterJson, Boolean isDefault) {
        // Will implement with custom object
        return null;
    }

    /**
     * Delete a saved view
     */
    @AuraEnabled
    public static void deleteView(Id viewId) {
        // Will implement with custom object
    }

    // ========================================
    // ACCOUNT DETAIL PANEL METHODS
    // ========================================

    /**
     * Account detail data for split-pane detail panel
     */
    public class AccountDetailData {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String statusLabel { get; set; }
        @AuraEnabled public String priority { get; set; }
        @AuraEnabled public String priorityLabel { get; set; }
        @AuraEnabled public String prioritySeries { get; set; }
        @AuraEnabled public Decimal totalAssets { get; set; }
        @AuraEnabled public Decimal annualRevenue { get; set; }
        @AuraEnabled public String phone { get; set; }
        @AuraEnabled public String website { get; set; }
        @AuraEnabled public String billingCity { get; set; }
        @AuraEnabled public String billingState { get; set; }
        @AuraEnabled public Date lastActivityDate { get; set; }
        @AuraEnabled public Date lastAttempt { get; set; }
        @AuraEnabled public Date lastReach { get; set; }
        @AuraEnabled public Integer inDeals { get; set; }
        @AuraEnabled public Integer allocated { get; set; }
        @AuraEnabled public Integer declinedPass { get; set; }
        @AuraEnabled public Integer otherDeals { get; set; }
        @AuraEnabled public Integer totalDealActivity { get; set; }
        @AuraEnabled public String operatingStates { get; set; }
        @AuraEnabled public Integer stateCount { get; set; }
        @AuraEnabled public String engagementHealth { get; set; }
        @AuraEnabled public Integer daysSinceActivity { get; set; }
        @AuraEnabled public String url { get; set; }
    }

    /**
     * Get detailed account data for split-pane detail panel
     */
    @AuraEnabled(cacheable=true)
    public static AccountDetailData getAccountDetail(Id accountId) {
        Account acc = [
            SELECT Id, Name, Status__c, Priority__c, Total_Assets__c, Annual_Revenue_Est__c,
                   Phone, Website, BillingCity, BillingState, LastActivityDate,
                   Last_Attempt__c, Last_Reach__c, In_Deals__c, Allocated__c,
                   Declined_Pass__c, Other_Deals__c, Operating_States__c
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];

        AccountDetailData detail = new AccountDetailData();
        detail.id = acc.Id;
        detail.name = acc.Name;
        detail.status = acc.Status__c;
        detail.statusLabel = acc.Status__c;
        detail.priority = acc.Priority__c;
        detail.priorityLabel = getPriorityLabel(acc.Priority__c);
        detail.prioritySeries = getPrioritySeries(acc.Priority__c);
        detail.totalAssets = acc.Total_Assets__c;
        detail.annualRevenue = acc.Annual_Revenue_Est__c;
        detail.phone = acc.Phone;
        detail.website = acc.Website;
        detail.billingCity = acc.BillingCity;
        detail.billingState = acc.BillingState;
        detail.lastActivityDate = acc.LastActivityDate;
        detail.lastAttempt = acc.Last_Attempt__c;
        detail.lastReach = acc.Last_Reach__c;
        detail.inDeals = acc.In_Deals__c != null ? acc.In_Deals__c.intValue() : 0;
        detail.allocated = acc.Allocated__c != null ? acc.Allocated__c.intValue() : 0;
        detail.declinedPass = acc.Declined_Pass__c != null ? acc.Declined_Pass__c.intValue() : 0;
        detail.otherDeals = acc.Other_Deals__c != null ? acc.Other_Deals__c.intValue() : 0;
        detail.totalDealActivity = detail.inDeals + detail.allocated + detail.declinedPass + detail.otherDeals;
        detail.operatingStates = acc.Operating_States__c;
        detail.stateCount = acc.Operating_States__c != null ? acc.Operating_States__c.split(';').size() : 0;
        detail.url = '/' + acc.Id;

        // Calculate engagement health
        Date today = Date.today();
        if (acc.LastActivityDate != null) {
            detail.daysSinceActivity = today.daysBetween(acc.LastActivityDate) * -1;
            if (detail.daysSinceActivity <= 30) {
                detail.engagementHealth = 'healthy';
            } else if (detail.daysSinceActivity <= 90) {
                detail.engagementHealth = 'aging';
            } else {
                detail.engagementHealth = 'stale';
            }
        } else {
            detail.daysSinceActivity = null;
            detail.engagementHealth = 'unknown';
        }

        return detail;
    }

    /**
     * Get human-readable priority label from code
     * CRITICAL: Never show codes in UI - always use human labels
     */
    private static String getPriorityLabel(String priorityCode) {
        if (priorityCode == null) return 'No Priority';

        // Extract the status suffix (last 2 digits)
        String suffix = priorityCode.length() >= 3 ? priorityCode.substring(priorityCode.length() - 2) : '';

        Map<String, String> suffixLabels = new Map<String, String>{
            '00' => 'Needs Engagement',
            '01' => 'Customer',
            '10' => 'In Cadence',
            '20' => 'Qualified Prospect',
            '55' => 'Dead for Now',
            '99' => 'Never - Do Not Contact'
        };

        String label = suffixLabels.get(suffix);
        return label != null ? label : priorityCode;
    }

    /**
     * Get priority series label from code
     */
    private static String getPrioritySeries(String priorityCode) {
        if (priorityCode == null) return null;

        if (priorityCode.startsWith('5')) {
            return 'Top Banks';
        } else if (priorityCode.startsWith('6')) {
            return 'Non-Banks';
        } else if (priorityCode.startsWith('7')) {
            return 'Other Banks';
        }
        return null;
    }

    // ========================================
    // PIPELINE FUNNEL (D525 UNIVERSE) METHODS
    // ========================================

    // D525 Universe: Banks with $2.5B+ total assets, excluding Dead/Lost/Partner
    private static final Decimal D525_ASSET_THRESHOLD = 2500000; // $2.5B in thousands

    /**
     * Pipeline Funnel data class - nested structure for pyramid visualization
     */
    public class PipelineFunnelData {
        @AuraEnabled public List<FunnelStage> stages { get; set; }
        @AuraEnabled public Integer totalRecords { get; set; }
        @AuraEnabled public Decimal totalAssets { get; set; }
        @AuraEnabled public Integer d525Count { get; set; }
    }

    /**
     * Individual funnel stage with nested priority breakdown
     */
    public class FunnelStage implements Comparable {
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public Integer recordCount { get; set; }
        @AuraEnabled public Decimal totalAssets { get; set; }
        @AuraEnabled public String color { get; set; }
        @AuraEnabled public Integer percentage { get; set; }
        @AuraEnabled public Integer assetPercentage { get; set; }
        @AuraEnabled public PriorityBreakdown priorityBreakdown { get; set; }
        @AuraEnabled public Integer sortOrder { get; set; }

        public Integer compareTo(Object other) {
            FunnelStage otherStage = (FunnelStage)other;
            return this.sortOrder - otherStage.sortOrder;
        }
    }

    /**
     * Priority series breakdown within each stage
     */
    public class PriorityBreakdown {
        @AuraEnabled public Integer series500Count { get; set; }
        @AuraEnabled public Integer series600Count { get; set; }
        @AuraEnabled public Integer series700Count { get; set; }
        @AuraEnabled public Integer otherCount { get; set; }
        @AuraEnabled public Decimal series500Assets { get; set; }
        @AuraEnabled public Decimal series600Assets { get; set; }
        @AuraEnabled public Decimal series700Assets { get; set; }
        @AuraEnabled public Decimal otherAssets { get; set; }
    }

    /**
     * Get Pipeline Funnel data for D525 Universe
     * Returns nested data structure: Status → Priority Series
     * Supports toggle between record count and total assets metrics
     * Accepts optional filters for global dashboard filtering
     */
    @AuraEnabled(cacheable=true)
    public static PipelineFunnelData getPipelineFunnelData(DashboardFilters filters) {
        PipelineFunnelData result = new PipelineFunnelData();
        result.stages = new List<FunnelStage>();

        // Define funnel stage order (top to bottom of pyramid)
        Map<String, Integer> stageOrder = new Map<String, Integer>{
            'Target D' => 1,
            'Target C' => 2,
            'Target B' => 3,
            'Target A' => 4,
            'Opportunity' => 5,
            'Customer' => 6
        };

        // Stage labels for display
        Map<String, String> stageLabels = new Map<String, String>{
            'Target D' => 'Unqualified',
            'Target C' => 'Low Volume',
            'Target B' => 'Blocked',
            'Target A' => 'Active Prospect',
            'Opportunity' => 'In Pipeline',
            'Customer' => 'Won'
        };

        // Build dynamic query for D525 Universe with filters
        String query = 'SELECT Id, Status__c, Priority__c, Total_Assets__c FROM Account WHERE Total_Assets__c >= ' + D525_ASSET_THRESHOLD;
        query += ' AND Status__c NOT IN (\'Dead\', \'Customer - Lost\', \'Partner\')';
        query += ' AND Status__c != null';

        // Apply priority series filter if specified
        if (filters != null && filters.prioritySeries != null && !filters.prioritySeries.isEmpty()) {
            List<String> priorityConditions = new List<String>();
            for (String series : filters.prioritySeries) {
                if (series == '500') {
                    priorityConditions.add('(Priority__c >= \'500\' AND Priority__c < \'600\')');
                } else if (series == '600') {
                    priorityConditions.add('(Priority__c >= \'600\' AND Priority__c < \'700\')');
                } else if (series == '700') {
                    priorityConditions.add('(Priority__c >= \'700\' AND Priority__c < \'800\')');
                }
            }
            if (!priorityConditions.isEmpty()) {
                query += ' AND (' + String.join(priorityConditions, ' OR ') + ')';
            }
        }

        // Apply engagement status filter if specified
        if (filters != null && filters.engagementStatus != null && filters.engagementStatus != '') {
            Date today = Date.today();
            Date thirtyDaysAgo = today.addDays(-30);
            Date ninetyDaysAgo = today.addDays(-90);

            if (filters.engagementStatus == 'recent') {
                query += ' AND LastActivityDate >= ' + String.valueOf(thirtyDaysAgo);
            } else if (filters.engagementStatus == 'aging') {
                query += ' AND LastActivityDate >= ' + String.valueOf(ninetyDaysAgo);
                query += ' AND LastActivityDate < ' + String.valueOf(thirtyDaysAgo);
            } else if (filters.engagementStatus == 'stale') {
                query += ' AND (LastActivityDate < ' + String.valueOf(ninetyDaysAgo) + ' OR LastActivityDate = null)';
            }
        }

        List<Account> d525Accounts = Database.query(query);

        result.d525Count = d525Accounts.size();

        // Build nested aggregation: Status → Priority Series
        Map<String, FunnelStage> stageMap = new Map<String, FunnelStage>();

        // Initialize all stages
        for (String status : stageOrder.keySet()) {
            FunnelStage stage = new FunnelStage();
            stage.status = status;
            stage.label = stageLabels.get(status);
            stage.recordCount = 0;
            stage.totalAssets = 0;
            stage.color = getStatusColor(status);
            stage.sortOrder = stageOrder.get(status);
            stage.priorityBreakdown = new PriorityBreakdown();
            stage.priorityBreakdown.series500Count = 0;
            stage.priorityBreakdown.series600Count = 0;
            stage.priorityBreakdown.series700Count = 0;
            stage.priorityBreakdown.otherCount = 0;
            stage.priorityBreakdown.series500Assets = 0;
            stage.priorityBreakdown.series600Assets = 0;
            stage.priorityBreakdown.series700Assets = 0;
            stage.priorityBreakdown.otherAssets = 0;
            stageMap.put(status, stage);
        }

        // Aggregate data
        Decimal grandTotalAssets = 0;

        for (Account acc : d525Accounts) {
            FunnelStage stage = stageMap.get(acc.Status__c);
            if (stage == null) continue;

            stage.recordCount++;
            Decimal assets = acc.Total_Assets__c != null ? acc.Total_Assets__c : 0;
            stage.totalAssets += assets;
            grandTotalAssets += assets;

            // Categorize by priority series
            String priority = acc.Priority__c;
            if (priority != null && priority.startsWith('5')) {
                stage.priorityBreakdown.series500Count++;
                stage.priorityBreakdown.series500Assets += assets;
            } else if (priority != null && priority.startsWith('6')) {
                stage.priorityBreakdown.series600Count++;
                stage.priorityBreakdown.series600Assets += assets;
            } else if (priority != null && priority.startsWith('7')) {
                stage.priorityBreakdown.series700Count++;
                stage.priorityBreakdown.series700Assets += assets;
            } else {
                stage.priorityBreakdown.otherCount++;
                stage.priorityBreakdown.otherAssets += assets;
            }
        }

        // Calculate percentages and build result list
        Integer totalRecords = d525Accounts.size();
        result.totalRecords = totalRecords;
        result.totalAssets = grandTotalAssets;

        for (String status : stageOrder.keySet()) {
            FunnelStage stage = stageMap.get(status);
            stage.percentage = totalRecords > 0 ?
                (Integer)Math.round((Decimal)stage.recordCount / totalRecords * 100) : 0;
            stage.assetPercentage = grandTotalAssets > 0 ?
                (Integer)Math.round(stage.totalAssets / grandTotalAssets * 100) : 0;
            result.stages.add(stage);
        }

        // Sort by sortOrder
        result.stages.sort();

        return result;
    }
}
