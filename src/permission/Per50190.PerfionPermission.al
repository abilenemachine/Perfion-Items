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

        tabledata PerfionErrorLog = RIMD,
        table PerfionErrorLog = X,
        page PerfionErrorLog = X,

        codeunit PerfionPriceSync = X,
        table PerfionPriceSync = X,
        page PerfionPriceSync = X,
        tabledata PerfionPriceSyncLog = RIMD,
        table PerfionPriceSyncLog = X,
        page PerfionPriceSyncLog = X,

        codeunit PerfionDataSync = X,
        table PerfionDataSync = X,
        page PerfionDataSync = X,
        tabledata PerfionDataSyncLog = RIMD,
        table PerfionDataSyncLog = X,
        page PerfionDataSyncLog = X;
    ;
}