permissionset 50190 PerfionPermission
{
    Assignable = true;
    Permissions =
        tabledata PerfionItems = RIMD,
        table PerfionItems = X,
        page perfionItem = X,
        page PerfionItemList = X,

        tabledata PerfionConfig = RIMD,
        table PerfionConfig = X,
        page PerfionConfig = X,

        tabledata PerfionLog = RIMD,
        table PerfionLog = X,
        page PerfionLog = X,

        codeunit PerfionPriceSync = X,
        table PerfionPriceSync = X,
        page PerfionPriceSync = X,
        tabledata PerfionPriceSyncLog = RIMD,
        table PerfionPriceSyncLog = X,
        page PerfionPriceSyncLog = X,

        codeunit PerfionDataSyncOut = X,
        table PerfionDataSyncOut = X,
        page PerfionDataSyncOut = X,
        page PerfionDataSyncOutLog = X,

        codeunit PerfionDataSyncIn = X,
        table PerfionDataSyncIn = X,
        page PerfionDataSyncIn = X,
        tabledata PerfionDataSyncInLog = RIMD,
        table PerfionDataSyncInLog = X,
        page PerfionDataSyncInLog = X,

        codeunit MagentoDataSync = X,
        codeunit PerfionLogHandler = X,
        codeunit MagentoLogHandler = X,

        tabledata MagentoLog = RIMD,
        table MagentoLog = X,
        page MagentoLog = X;
    ;
}