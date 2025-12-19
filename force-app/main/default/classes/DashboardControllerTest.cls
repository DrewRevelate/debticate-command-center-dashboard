/**
 * Test class for DashboardController
 */
@isTest
private class DashboardControllerTest {

    @TestSetup
    static void setupTestData() {
        List<Account> accounts = new List<Account>();

        // Create Target A accounts
        for (Integer i = 0; i < 5; i++) {
            accounts.add(new Account(
                Name = 'Target A Bank ' + i,
                Status__c = 'Target A',
                Priority__c = '500'
            ));
        }

        // Create Target B accounts
        for (Integer i = 0; i < 10; i++) {
            accounts.add(new Account(
                Name = 'Target B Bank ' + i,
                Status__c = 'Target B',
                Priority__c = '510'
            ));
        }

        // Create Target C accounts with various priorities
        for (Integer i = 0; i < 15; i++) {
            String priority = i < 5 ? '600' : (i < 10 ? '610' : '700');
            accounts.add(new Account(
                Name = 'Target C Bank ' + i,
                Status__c = 'Target C',
                Priority__c = priority
            ));
        }

        // Create Target D accounts
        for (Integer i = 0; i < 10; i++) {
            accounts.add(new Account(
                Name = 'Target D Bank ' + i,
                Status__c = 'Target D',
                Priority__c = '553'
            ));
        }

        // Create Customer accounts
        for (Integer i = 0; i < 3; i++) {
            accounts.add(new Account(
                Name = 'Customer ' + i,
                Status__c = 'Customer'
            ));
        }

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

        // Verify we have Target A data
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
    static void testGetAccountsByFilterEngagement() {
        Test.startTest();
        // Test stale filter (accounts with no recent activity)
        List<DashboardController.AccountData> staleResult = DashboardController.getAccountsByFilter('engagement', 'stale');
        Test.stopTest();

        System.assertNotEquals(null, staleResult, 'Stale result should not be null');
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
}
