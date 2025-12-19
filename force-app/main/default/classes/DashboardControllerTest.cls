/**
 * Test class for DashboardController
 * Comprehensive test coverage for all dashboard methods
 */
@isTest
private class DashboardControllerTest {

    @TestSetup
    static void setupTestData() {
        List<Account> accounts = new List<Account>();

        // Create Target A accounts with large assets (D525 universe)
        for (Integer i = 0; i < 5; i++) {
            accounts.add(new Account(
                Name = 'Target A Bank ' + i,
                Status__c = 'Target A',
                Priority__c = '500',
                Total_Assets__c = 3000000, // $3B - qualifies for D525
                BillingState = 'CA'
            ));
        }

        // Create Target B accounts
        for (Integer i = 0; i < 10; i++) {
            accounts.add(new Account(
                Name = 'Target B Bank ' + i,
                Status__c = 'Target B',
                Priority__c = '510',
                Total_Assets__c = 1000000
            ));
        }

        // Create Target C accounts with various priorities
        for (Integer i = 0; i < 15; i++) {
            String priority = i < 5 ? '600' : (i < 10 ? '610' : '700');
            accounts.add(new Account(
                Name = 'Target C Bank ' + i,
                Status__c = 'Target C',
                Priority__c = priority,
                Total_Assets__c = 500000
            ));
        }

        // Create Target D accounts
        for (Integer i = 0; i < 10; i++) {
            accounts.add(new Account(
                Name = 'Target D Bank ' + i,
                Status__c = 'Target D',
                Priority__c = '553',
                Total_Assets__c = 2600000 // D525 eligible
            ));
        }

        // Create Customer accounts
        for (Integer i = 0; i < 3; i++) {
            accounts.add(new Account(
                Name = 'Customer ' + i,
                Status__c = 'Customer',
                Priority__c = '501',
                Total_Assets__c = 4000000,
                In_Deals__c = 5,
                Allocated__c = 10,
                Declined_Pass__c = 2
            ));
        }

        // Create Opportunity accounts
        accounts.add(new Account(
            Name = 'Opportunity Bank',
            Status__c = 'Opportunity',
            Priority__c = '520',
            Total_Assets__c = 5000000
        ));

        // Create Dead and Partner accounts (excluded from D525)
        accounts.add(new Account(
            Name = 'Dead Bank',
            Status__c = 'Dead',
            Priority__c = '555',
            Total_Assets__c = 3000000
        ));

        accounts.add(new Account(
            Name = 'Partner Bank',
            Status__c = 'Partner',
            Priority__c = '599'
        ));

        insert accounts;

        // Create some tasks for activity tracking
        List<Task> tasks = new List<Task>();
        for (Account acc : [SELECT Id FROM Account WHERE Status__c = 'Target A' LIMIT 3]) {
            tasks.add(new Task(
                WhatId = acc.Id,
                Subject = 'Test Call',
                Status = 'Completed',
                ActivityDate = Date.today()
            ));
        }
        insert tasks;
    }

    @isTest
    static void testGetTargetUniverseData() {
        Test.startTest();
        List<DashboardController.TargetData> result = DashboardController.getTargetUniverseData();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.size() > 0, 'Should have at least one target data entry');

        Boolean hasTargetA = false;
        for (DashboardController.TargetData td : result) {
            if (td.status == 'Target A') {
                hasTargetA = true;
                System.assertEquals(5, td.count, 'Target A should have 5 accounts');
                System.assertNotEquals(null, td.color, 'Color should be set');
            }
        }
        System.assert(hasTargetA, 'Should have Target A in results');
    }

    @isTest
    static void testGetCadenceMatrixData() {
        Test.startTest();
        DashboardController.CadenceMatrixData result = DashboardController.getCadenceMatrixData();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.total500 > 0 || result.total600 > 0 || result.total700 > 0,
                     'Should have some priority data');
    }

    @isTest
    static void testGetEngagementHealthData() {
        Test.startTest();
        DashboardController.EngagementHealthData result = DashboardController.getEngagementHealthData();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.byStatus, 'byStatus should not be null');
        System.assert(result.totalAccounts > 0, 'Should have target accounts');
        System.assertEquals(4, result.byStatus.size(), 'Should have 4 status entries (Target A/B/C/D)');
    }

    @isTest
    static void testGetAccountsByFilterStatus() {
        Test.startTest();
        List<DashboardController.AccountData> result = DashboardController.getAccountsByFilter('status', 'Target A');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(5, result.size(), 'Should have 5 Target A accounts');

        for (DashboardController.AccountData ad : result) {
            System.assertEquals('Target A', ad.status, 'Status should be Target A');
            System.assertNotEquals(null, ad.url, 'URL should be set');
        }
    }

    @isTest
    static void testGetAccountsByFilterPriority() {
        Test.startTest();
        List<DashboardController.AccountData> result = DashboardController.getAccountsByFilter('priority', '500');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(5, result.size(), 'Should have 5 accounts with priority 500');
    }

    @isTest
    static void testGetAccountsByFilterEngagementRecent() {
        Test.startTest();
        List<DashboardController.AccountData> result = DashboardController.getAccountsByFilter('engagement', 'recent');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testGetAccountsByFilterEngagementAging() {
        Test.startTest();
        List<DashboardController.AccountData> result = DashboardController.getAccountsByFilter('engagement', 'aging');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testGetAccountsByFilterEngagementStale() {
        Test.startTest();
        List<DashboardController.AccountData> result = DashboardController.getAccountsByFilter('engagement', 'stale');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testUpdateAccount() {
        Account acc = [SELECT Id, Status__c FROM Account WHERE Status__c = 'Target D' LIMIT 1];

        Test.startTest();
        DashboardController.updateAccount(acc.Id, 'Status__c', 'Target C');
        Test.stopTest();

        Account updated = [SELECT Status__c FROM Account WHERE Id = :acc.Id];
        System.assertEquals('Target C', updated.Status__c, 'Status should be updated to Target C');
    }

    @isTest
    static void testUpdateAccountField() {
        Account acc = [SELECT Id, Status__c FROM Account WHERE Status__c = 'Target B' LIMIT 1];

        Test.startTest();
        DashboardController.updateAccountField(acc.Id, 'Status__c', 'Target A');
        Test.stopTest();

        Account updated = [SELECT Status__c FROM Account WHERE Id = :acc.Id];
        System.assertEquals('Target A', updated.Status__c, 'Status should be updated');
    }

    // ========================================
    // FOOTPRINT COMPARISON TESTS
    // ========================================

    @isTest
    static void testSearchBanksForFootprint() {
        Test.startTest();
        List<DashboardController.BankOption> result = DashboardController.searchBanksForFootprint('Target A');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        // May or may not find banks with footprints
    }

    @isTest
    static void testGetBankFootprint() {
        Account acc = [SELECT Id FROM Account WHERE Status__c = 'Target A' LIMIT 1];

        Test.startTest();
        DashboardController.FootprintData result = DashboardController.getBankFootprint(acc.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.states, 'States should not be null');
    }

    @isTest
    static void testCompareFootprints() {
        List<Account> accounts = [SELECT Id FROM Account WHERE Status__c IN ('Target A', 'Target B') LIMIT 2];
        System.assert(accounts.size() >= 2, 'Need at least 2 accounts');

        Test.startTest();
        DashboardController.FootprintComparison result = DashboardController.compareFootprints(
            accounts[0].Id, accounts[1].Id
        );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.bank1States, 'Bank1 states should not be null');
        System.assertNotEquals(null, result.bank2States, 'Bank2 states should not be null');
    }

    @isTest
    static void testFindFootprintMatches() {
        Account acc = [SELECT Id FROM Account WHERE Status__c = 'Target A' LIMIT 1];

        Test.startTest();
        List<DashboardController.FootprintMatch> result = DashboardController.findFootprintMatches(acc.Id, 10);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testFindFootprintMatchesNoStates() {
        Account acc = [SELECT Id FROM Account WHERE Status__c = 'Target A' LIMIT 1];

        Test.startTest();
        List<DashboardController.FootprintMatch> result = DashboardController.findFootprintMatches(acc.Id, 10);
        Test.stopTest();

        // Account without Operating_States__c returns empty list
        System.assertNotEquals(null, result, 'Result should not be null');
    }

    // ========================================
    // UNIFIED DASHBOARD DATA TESTS
    // ========================================

    @isTest
    static void testGetDashboardDataNoFilters() {
        Test.startTest();
        DashboardController.DashboardData result = DashboardController.getDashboardData(null);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.targetUniverse, 'Target universe should not be null');
        System.assertNotEquals(null, result.cadenceMatrix, 'Cadence matrix should not be null');
        System.assertNotEquals(null, result.engagementHealth, 'Engagement health should not be null');
        System.assertNotEquals(null, result.kpiSummary, 'KPI summary should not be null');
        System.assertNotEquals(null, result.filteredAccounts, 'Filtered accounts should not be null');
    }

    @isTest
    static void testGetDashboardDataWithStatusFilter() {
        DashboardController.DashboardFilters filters = new DashboardController.DashboardFilters();
        filters.targetStatuses = new List<String>{'Target A', 'Target B'};

        Test.startTest();
        DashboardController.DashboardData result = DashboardController.getDashboardData(filters);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.kpiSummary.totalAccounts > 0, 'Should have filtered accounts');
    }

    @isTest
    static void testGetDashboardDataWithPrioritySeriesFilter() {
        DashboardController.DashboardFilters filters = new DashboardController.DashboardFilters();
        filters.prioritySeries = new List<String>{'500', '600'};

        Test.startTest();
        DashboardController.DashboardData result = DashboardController.getDashboardData(filters);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testGetDashboardDataWithEngagementFilter() {
        DashboardController.DashboardFilters filters = new DashboardController.DashboardFilters();
        filters.engagementStatus = 'recent';

        Test.startTest();
        DashboardController.DashboardData result = DashboardController.getDashboardData(filters);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testGetDashboardDataWithAgingFilter() {
        DashboardController.DashboardFilters filters = new DashboardController.DashboardFilters();
        filters.engagementStatus = 'aging';

        Test.startTest();
        DashboardController.DashboardData result = DashboardController.getDashboardData(filters);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testGetDashboardDataWithStaleFilter() {
        DashboardController.DashboardFilters filters = new DashboardController.DashboardFilters();
        filters.engagementStatus = 'stale';

        Test.startTest();
        DashboardController.DashboardData result = DashboardController.getDashboardData(filters);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testGetDashboardDataWithDateFilters() {
        DashboardController.DashboardFilters filters = new DashboardController.DashboardFilters();
        filters.startDate = Date.today().addDays(-30);
        filters.endDate = Date.today();

        Test.startTest();
        DashboardController.DashboardData result = DashboardController.getDashboardData(filters);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testGetDashboardDataWithSearchTerm() {
        DashboardController.DashboardFilters filters = new DashboardController.DashboardFilters();
        filters.searchTerm = 'Target A';

        Test.startTest();
        DashboardController.DashboardData result = DashboardController.getDashboardData(filters);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testGetDashboardDataWithTop525Filter() {
        DashboardController.DashboardFilters filters = new DashboardController.DashboardFilters();
        filters.top525 = true;

        Test.startTest();
        DashboardController.DashboardData result = DashboardController.getDashboardData(filters);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testGetDashboardDataWith700Series() {
        DashboardController.DashboardFilters filters = new DashboardController.DashboardFilters();
        filters.prioritySeries = new List<String>{'700'};

        Test.startTest();
        DashboardController.DashboardData result = DashboardController.getDashboardData(filters);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
    }

    // ========================================
    // OPPORTUNITIES BY STAGE TESTS
    // ========================================

    @isTest
    static void testGetOpportunitiesByStageNoFilters() {
        // Create test opportunities
        Account acc = [SELECT Id FROM Account WHERE Status__c = 'Target A' LIMIT 1];
        insert new Opportunity(
            Name = 'Test Opp',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Amount = 100000
        );

        Test.startTest();
        List<DashboardController.OpportunityStageData> result = DashboardController.getOpportunitiesByStage(null);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testGetOpportunitiesByStageWithFilters() {
        Account acc = [SELECT Id FROM Account WHERE Status__c = 'Target A' LIMIT 1];
        insert new Opportunity(
            Name = 'Test Opp 2',
            AccountId = acc.Id,
            StageName = 'Qualification',
            CloseDate = Date.today().addDays(60),
            Amount = 200000
        );

        DashboardController.DashboardFilters filters = new DashboardController.DashboardFilters();
        filters.prioritySeries = new List<String>{'500'};
        filters.targetStatuses = new List<String>{'Target A'};

        Test.startTest();
        List<DashboardController.OpportunityStageData> result = DashboardController.getOpportunitiesByStage(filters);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
    }

    // ========================================
    // SAVED VIEWS TESTS
    // ========================================

    @isTest
    static void testGetSavedViews() {
        Test.startTest();
        List<DashboardController.SavedViewData> result = DashboardController.getSavedViews();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testSaveView() {
        Test.startTest();
        Id result = DashboardController.saveView('Test View', '{"status":"Target A"}', false);
        Test.stopTest();

        // Currently returns null (not implemented)
        System.assertEquals(null, result, 'Should return null (not implemented)');
    }

    @isTest
    static void testDeleteView() {
        Test.startTest();
        DashboardController.deleteView(null);
        Test.stopTest();

        // No exception should be thrown
        System.assert(true, 'Delete should complete without error');
    }

    // ========================================
    // ACCOUNT DETAIL PANEL TESTS
    // ========================================

    @isTest
    static void testGetAccountDetail() {
        Account acc = [SELECT Id FROM Account WHERE Status__c = 'Target A' LIMIT 1];

        Test.startTest();
        DashboardController.AccountDetailData result = DashboardController.getAccountDetail(acc.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.name, 'Name should not be null');
        System.assertNotEquals(null, result.status, 'Status should not be null');
        System.assertNotEquals(null, result.engagementHealth, 'Engagement health should not be null');
    }

    @isTest
    static void testGetAccountDetailWithDeals() {
        Account acc = [SELECT Id FROM Account WHERE Status__c = 'Customer' AND In_Deals__c > 0 LIMIT 1];

        Test.startTest();
        DashboardController.AccountDetailData result = DashboardController.getAccountDetail(acc.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.inDeals > 0, 'In deals should be greater than 0');
        System.assert(result.totalDealActivity > 0, 'Total deal activity should be calculated');
    }

    @isTest
    static void testGetAccountDetailNoActivity() {
        // Create account with no activity
        Account acc = new Account(
            Name = 'No Activity Bank',
            Status__c = 'Target D',
            Priority__c = '700'
        );
        insert acc;

        Test.startTest();
        DashboardController.AccountDetailData result = DashboardController.getAccountDetail(acc.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals('unknown', result.engagementHealth, 'Should be unknown with no activity');
    }

    // ========================================
    // PIPELINE FUNNEL TESTS
    // ========================================

    @isTest
    static void testGetPipelineFunnelDataNoFilters() {
        Test.startTest();
        DashboardController.PipelineFunnelData result = DashboardController.getPipelineFunnelData(null);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.stages, 'Stages should not be null');
        System.assert(result.stages.size() > 0, 'Should have funnel stages');
    }

    @isTest
    static void testGetPipelineFunnelDataWithPriorityFilter() {
        DashboardController.DashboardFilters filters = new DashboardController.DashboardFilters();
        filters.prioritySeries = new List<String>{'500'};

        Test.startTest();
        DashboardController.PipelineFunnelData result = DashboardController.getPipelineFunnelData(filters);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testGetPipelineFunnelDataWithEngagementFilter() {
        DashboardController.DashboardFilters filters = new DashboardController.DashboardFilters();
        filters.engagementStatus = 'recent';

        Test.startTest();
        DashboardController.PipelineFunnelData result = DashboardController.getPipelineFunnelData(filters);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testGetPipelineFunnelDataWithAgingEngagement() {
        DashboardController.DashboardFilters filters = new DashboardController.DashboardFilters();
        filters.engagementStatus = 'aging';

        Test.startTest();
        DashboardController.PipelineFunnelData result = DashboardController.getPipelineFunnelData(filters);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testGetPipelineFunnelDataWithStaleEngagement() {
        DashboardController.DashboardFilters filters = new DashboardController.DashboardFilters();
        filters.engagementStatus = 'stale';

        Test.startTest();
        DashboardController.PipelineFunnelData result = DashboardController.getPipelineFunnelData(filters);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testFunnelStageComparable() {
        DashboardController.FunnelStage stage1 = new DashboardController.FunnelStage();
        stage1.sortOrder = 1;

        DashboardController.FunnelStage stage2 = new DashboardController.FunnelStage();
        stage2.sortOrder = 2;

        Test.startTest();
        Integer compareResult = stage1.compareTo(stage2);
        Test.stopTest();

        System.assert(compareResult < 0, 'Stage1 should sort before stage2');
    }

    @isTest
    static void testFootprintMatchComparable() {
        DashboardController.FootprintMatch match1 = new DashboardController.FootprintMatch();
        match1.overlapCount = 5;

        DashboardController.FootprintMatch match2 = new DashboardController.FootprintMatch();
        match2.overlapCount = 10;

        Test.startTest();
        Integer compareResult = match1.compareTo(match2);
        Test.stopTest();

        System.assert(compareResult > 0, 'Match2 with higher overlap should sort first');
    }

    // ========================================
    // EDGE CASE TESTS
    // ========================================

    @isTest
    static void testEmptyFiltersObject() {
        DashboardController.DashboardFilters filters = new DashboardController.DashboardFilters();

        Test.startTest();
        DashboardController.DashboardData result = DashboardController.getDashboardData(filters);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should handle empty filters object');
    }

    @isTest
    static void testAllPrioritySeriesFilter() {
        DashboardController.DashboardFilters filters = new DashboardController.DashboardFilters();
        filters.prioritySeries = new List<String>{'500', '600', '700'};

        Test.startTest();
        DashboardController.DashboardData result = DashboardController.getDashboardData(filters);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should handle all priority series');
    }

    @isTest
    static void testCompareFootprintsInvalidIds() {
        // Test with IDs that don't exist
        Test.startTest();
        DashboardController.FootprintComparison result = DashboardController.compareFootprints(
            '001000000000001AAA', '001000000000002AAA'
        );
        Test.stopTest();

        System.assertEquals(null, result, 'Should return null for invalid IDs');
    }
}
