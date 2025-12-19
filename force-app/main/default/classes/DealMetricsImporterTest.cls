@isTest
private class DealMetricsImporterTest {

    @isTest
    static void testParseCSV() {
        String csvContent = 'UID,SFDC Account ID,Portal,Name,EmailDomain,In Deals,Allocated,Declined/Pass,Other\n' +
            '123,,Portal1,Test Bank,testbank.com,10,5,3,2\n' +
            '456,,Portal2,"Bank, With Comma",commabank.com,8,4,2,2';

        Test.startTest();
        List<DealMetricsImporter.DealMetric> metrics = DealMetricsImporter.parseCSV(csvContent);
        Test.stopTest();

        System.assertEquals(2, metrics.size(), 'Should parse 2 rows');
        System.assertEquals('Test Bank', metrics[0].name, 'Name should match');
        System.assertEquals('testbank.com', metrics[0].emailDomain, 'Domain should match');
        System.assertEquals(10, metrics[0].inDeals, 'In Deals should be 10');
        System.assertEquals(5, metrics[0].allocated, 'Allocated should be 5');
        System.assertEquals(3, metrics[0].declinedPass, 'Declined/Pass should be 3');
        System.assertEquals(2, metrics[0].otherDeals, 'Other should be 2');

        // Test quoted field with comma
        System.assertEquals('Bank, With Comma', metrics[1].name, 'Quoted name with comma should parse correctly');
    }

    @isTest
    static void testExtractDomain() {
        System.assertEquals('testbank.com', DealMetricsImporter.extractDomain('https://www.testbank.com'), 'Should extract from https with www');
        System.assertEquals('testbank.com', DealMetricsImporter.extractDomain('http://testbank.com'), 'Should extract from http');
        System.assertEquals('testbank.com', DealMetricsImporter.extractDomain('testbank.com/about'), 'Should remove path');
        System.assertEquals('testbank.com', DealMetricsImporter.extractDomain('www.testbank.com'), 'Should remove www');
        System.assertEquals(null, DealMetricsImporter.extractDomain(null), 'Should handle null');
        System.assertEquals(null, DealMetricsImporter.extractDomain(''), 'Should handle empty string');
    }

    @isTest
    static void testImportMetrics_DomainMatch() {
        // Create test account with website
        Account acc = new Account(
            Name = 'Different Name',
            Website = 'https://www.testbank.com'
        );
        insert acc;

        // Create test metric
        DealMetricsImporter.DealMetric dm = new DealMetricsImporter.DealMetric();
        dm.name = 'Test Bank';
        dm.emailDomain = 'testbank.com';
        dm.inDeals = 15;
        dm.allocated = 8;
        dm.declinedPass = 4;
        dm.otherDeals = 3;

        Test.startTest();
        Map<String, Integer> stats = DealMetricsImporter.importMetrics(new List<DealMetricsImporter.DealMetric>{dm});
        Test.stopTest();

        System.assertEquals(1, stats.get('domainMatches'), 'Should have 1 domain match');
        System.assertEquals(1, stats.get('accountsUpdated'), 'Should update 1 account');

        // Verify account was updated
        Account updated = [SELECT In_Deals__c, Allocated__c, Declined_Pass__c, Other_Deals__c FROM Account WHERE Id = :acc.Id];
        System.assertEquals(15, updated.In_Deals__c, 'In Deals should be updated');
        System.assertEquals(8, updated.Allocated__c, 'Allocated should be updated');
        System.assertEquals(4, updated.Declined_Pass__c, 'Declined Pass should be updated');
        System.assertEquals(3, updated.Other_Deals__c, 'Other Deals should be updated');
    }

    @isTest
    static void testImportMetrics_NameMatch() {
        // Create test account without website
        Account acc = new Account(
            Name = 'Test Bank'
        );
        insert acc;

        // Create test metric
        DealMetricsImporter.DealMetric dm = new DealMetricsImporter.DealMetric();
        dm.name = 'Test Bank';
        dm.emailDomain = 'differentdomain.com';
        dm.inDeals = 20;
        dm.allocated = 10;
        dm.declinedPass = 5;
        dm.otherDeals = 5;

        Test.startTest();
        Map<String, Integer> stats = DealMetricsImporter.importMetrics(new List<DealMetricsImporter.DealMetric>{dm});
        Test.stopTest();

        System.assertEquals(1, stats.get('nameMatches'), 'Should have 1 name match');
        System.assertEquals(1, stats.get('accountsUpdated'), 'Should update 1 account');
    }

    @isTest
    static void testImportMetrics_NoMatch() {
        // Create test account that won't match
        Account acc = new Account(
            Name = 'Unrelated Company',
            Website = 'https://unrelated.com'
        );
        insert acc;

        // Create test metric with no matching domain or name
        DealMetricsImporter.DealMetric dm = new DealMetricsImporter.DealMetric();
        dm.name = 'Some Other Bank';
        dm.emailDomain = 'otherbank.com';
        dm.inDeals = 5;
        dm.allocated = 2;
        dm.declinedPass = 1;
        dm.otherDeals = 2;

        Test.startTest();
        Map<String, Integer> stats = DealMetricsImporter.importMetrics(new List<DealMetricsImporter.DealMetric>{dm});
        Test.stopTest();

        System.assertEquals(0, stats.get('domainMatches'), 'Should have no domain matches');
        System.assertEquals(0, stats.get('nameMatches'), 'Should have no name matches');
        System.assertEquals(0, stats.get('accountsUpdated'), 'Should not update any accounts');
    }
}
