//
//  Store.m
//  Version 1.6
//
//  Created by Сергей Ваничкин on 10/23/18.
//  Copyright © 2018 👽 Technology. All rights reserved.
//

#import "Store.h"

#pragma mark - Store Item Category

@implementation NSString (Identifier)

-(StoreItem *)storeItem
{
    return
    [Store storeItemWithIdentifier:self];
}

@end

#pragma mark - Store Item

@interface StoreItem () <SKPaymentTransactionObserver>

@property (nonatomic, strong) SKProduct      *product;
@property (nonatomic, strong) SKPaymentQueue *purchaseQueue;

@property (nonatomic, strong) NSMutableArray <PurchaseCompletion> *purchaseCompletions;

@property (nonatomic, assign) BOOL            isPurchasing;

@end

@implementation StoreItem

-(instancetype)init
{
    if (self = [super init])
    {
        self.purchaseCompletions = NSMutableArray.new;
        self.purchaseQueue       = SKPaymentQueue.new;
        
        [self.purchaseQueue addTransactionObserver:self];
    }
    
    return self;
}

-(void)setIdentifier:(NSString *)identifier
{
    _identifier = identifier;
}

-(void)setStartDate:(NSDate *)startDate
{
    _startDate = startDate;
}

-(void)setEndDate:(NSDate *)endDate
{
    _endDate = endDate;
}

-(void)setIsTrial:(BOOL)isTrial
{
    _isTrial = isTrial;
}

-(void)setType:(StoreItemType)type
{
    _type = type;
}

-(void)setPeriod:(StoreItemPeriod)period
{
    _period = period;
}

-(void)setProduct:(SKProduct *)product
{
    _product = product;

    NSNumberFormatter *numberFormatter = NSNumberFormatter.new;
    
    numberFormatter.formatterBehavior = NSNumberFormatterBehavior10_4;
    numberFormatter.numberStyle       = NSNumberFormatterCurrencyStyle;
    numberFormatter.locale            = product.priceLocale;
    
    NSString *formattedPrice =
    [numberFormatter stringFromNumber:product.price];
    
    formattedPrice =
    [formattedPrice
     stringByReplacingOccurrencesOfString:@" "
     withString:@""];
    
    formattedPrice =
    [formattedPrice
     stringByReplacingOccurrencesOfString:@".00"
     withString:@""];
    
    formattedPrice =
    [formattedPrice
     stringByReplacingOccurrencesOfString:@",00"
     withString:@""];
    
    _priceString    = formattedPrice;
    _priceNumber    = product.price;
    _titleWithPrice =
    [NSString
     stringWithFormat:@"%@ %@",
     formattedPrice,
     product.localizedTitle];
    
    _title  = product.localizedTitle;
    _detail = product.localizedDescription;
    
    NSInteger days   = 0;
    NSInteger months = 0;
    NSInteger years  = 0;
    
    if (product.subscriptionPeriod.unit == SKProductPeriodUnitDay)
        days = 1 * product.subscriptionPeriod.numberOfUnits;
    
    else if (product.subscriptionPeriod.unit == SKProductPeriodUnitWeek)
        days = 7 * product.subscriptionPeriod.numberOfUnits;
    
    else if (product.subscriptionPeriod.unit == SKProductPeriodUnitMonth)
        months = 1 * product.subscriptionPeriod.numberOfUnits;
    
    else if (product.subscriptionPeriod.unit == SKProductPeriodUnitYear)
        years = 1 * product.subscriptionPeriod.numberOfUnits;
    
    if (days > 0 && days < 8)
        _period = StoreItemPeriodWeek;
    
    else if (months > 0)
        _period = StoreItemPeriodMonth;
    
    else if (years > 0)
        _period = StoreItemPeriodYear;
}

-(BOOL)isPurchased
{
    BOOL purchased = NO;
    
    if (self.type == StoreItemTypeConsumable ||
        self.type == StoreItemTypeNonConsumable)
        purchased =
        [NSUserDefaults.standardUserDefaults
         objectForKey:_identifier] != nil;
    
    else if (self.type == StoreItemTypeNonRenewingSubscription ||
             self.type == StoreItemTypeAutoRenewableSubscription)
        purchased =
        [NSUserDefaults.standardUserDefaults objectForKey:_identifier] &&
        _endDate.timeIntervalSince1970 > NSDate.new.timeIntervalSince1970;
    
    NSLog (@"[INFO] Store: Identifier '%@' %@",
           _identifier,
           purchased ? @"is purchased" : @"is not purchased");
    
    return purchased;
}

#pragma mark - Purchase Product

-(void)purchaseWithCompletion:(PurchaseCompletion)completion
{
    NSLog(@"[INFO] Store: Try purchaing product with identifier '%@'...",
          _identifier);
    
    if (!self.product || !Store.isReady)
    {
        NSLog(@"[ERROR] Store: Purchase with identifier '%@' failed. Store is not Ready, or product for this identifier not found!",
              _identifier);
        
        if (completion)
            completion(nil);
        
        return;
    }
    
    if (completion)
        [self.purchaseCompletions
         addObject:completion];
    
    if (self.isPurchasing)
        return;
    
    self.isPurchasing = YES;
    
    SKMutablePayment *payment =
    [SKMutablePayment
     paymentWithProduct:self.product];
    
    payment.quantity = 1;
    
    [self.purchaseQueue addPayment:payment];
}

-(void)consumablePurchaseReset
{
    NSLog(@"[INFO] Store: Purchaing reset product with identifier '%@'",
          _identifier);
          
    [NSUserDefaults.standardUserDefaults
     setObject:nil
     forKey:self.identifier];
    
    [NSUserDefaults.standardUserDefaults synchronize];
    
    [NSNotificationCenter.defaultCenter
     postNotificationName:STORE_MANAGER_CHANGED
     object:nil];
}

-(void)returnCompletionsWithError:(NSError *)error
{
    self.isPurchasing = NO;
    
    for (PurchaseCompletion completion in self.purchaseCompletions)
        completion(error);
    
    [self.purchaseCompletions removeAllObjects];
    
    [NSNotificationCenter.defaultCenter
     postNotificationName:STORE_MANAGER_CHANGED
     object:error];
}

-(void)paymentQueue:(SKPaymentQueue *)queue
updatedTransactions:(NSArray        *)transactions
{
    NSLog (@"[INFO] Store: Update transaction fired with Purchase Queue");
    
    for (SKPaymentTransaction *transaction in transactions)
    {
        if (![transaction.payment.productIdentifier isEqualToString:_identifier])
            continue;
        
        switch (transaction.transactionState)
        {
            case SKPaymentTransactionStateFailed:
            {
                NSLog (@"[ERROR] Store: Update transaction fired [SKPaymentTransactionStateFailed]");
                
                dispatch_async(dispatch_get_main_queue(), ^(void)
                {
                    NSLog (@"[ERROR] Store: %@", transaction.error);
                    
                    [self returnCompletionsWithError:transaction.error];
                });
                
                [queue finishTransaction:transaction];
                
                break;
            }
                
            case SKPaymentTransactionStateRestored:
            case SKPaymentTransactionStatePurchased:
            {
                NSLog (@"[INFO] Store: Update transaction fired [SKPaymentTransactionStatePurchased || restored]");

                [NSUserDefaults.standardUserDefaults
                 setObject:transaction.transactionDate
                 forKey:transaction.payment.productIdentifier];
                
                [NSUserDefaults.standardUserDefaults synchronize];
                
                _startDate =
                transaction.transactionDate;
                
                if (_product.subscriptionPeriod)
                {
                    NSDateComponents *dayComponent =
                    NSDateComponents.new;
                
                    if (_product.subscriptionPeriod.unit == SKProductPeriodUnitDay)
                        dayComponent.day = 1 * self.product.subscriptionPeriod.numberOfUnits;
                    
                    else if (_product.subscriptionPeriod.unit == SKProductPeriodUnitWeek)
                        dayComponent.day = 7 * self.product.subscriptionPeriod.numberOfUnits;
                    
                    else if (_product.subscriptionPeriod.unit == SKProductPeriodUnitMonth)
                        dayComponent.month = 1 * self.product.subscriptionPeriod.numberOfUnits;
                        
                    else if (_product.subscriptionPeriod.unit == SKProductPeriodUnitYear)
                        dayComponent.year = 1 * self.product.subscriptionPeriod.numberOfUnits;
                                    
                    _endDate =
                    [NSCalendar.currentCalendar
                     dateByAddingComponents:dayComponent
                     toDate:_startDate
                     options:0];
                }
                
                else if (_type == StoreItemTypeNonRenewingSubscription)
                {
                    NSDateComponents *dayComponent =
                    NSDateComponents.new;
                    
                    if (_period == StoreItemPeriodWeek)
                        dayComponent.day = 7;
                    
                    else if (_period == StoreItemPeriodMonth)
                        dayComponent.month = 1;
                    
                    else if (_period == StoreItemPeriodYear)
                        dayComponent.year = 1;
                    
                    _endDate =
                    [NSCalendar.currentCalendar
                     dateByAddingComponents:dayComponent
                     toDate:_startDate
                     options:0];
                }
                
                NSLog (@"[INFO] Store: SKPaymentTransactionStatePurchased %@, result:%@",
                       transaction.payment.productIdentifier,
                       [NSUserDefaults.standardUserDefaults
                        objectForKey:transaction.payment.productIdentifier] ? @"YES" : @"NO");
                
                dispatch_async(dispatch_get_main_queue(), ^(void)
                {
                    [self returnCompletionsWithError:nil];
                });
                
                [queue finishTransaction:transaction];
                
                break;
            }
                
            case SKPaymentTransactionStatePurchasing:
            case SKPaymentTransactionStateDeferred:
            default:
                break;
        }
    }
}

#pragma mark - Store Item Helpers

-(StoreItem *)consumable
{
    _type =
    StoreItemTypeConsumable;
    
    return self;
}

-(StoreItem *)nonConsumable
{
    _type =
    StoreItemTypeNonConsumable;
    
    return self;
}

-(StoreItem *)autoRenewableSubscription
{
    _type =
    StoreItemTypeAutoRenewableSubscription;
    
    return self;
}

-(StoreItem *)nonRenewingSubscriptionWeek
{
    _type =
    StoreItemTypeNonRenewingSubscription;
    
    _period =
    StoreItemPeriodWeek;
    
    return self;
}

-(StoreItem *)nonRenewingSubscriptionMonth
{
    _type =
    StoreItemTypeNonRenewingSubscription;
    
    _period =
    StoreItemPeriodMonth;
    
    return self;
}

-(StoreItem *)nonRenewingSubscriptionYear
{
    _type =
    StoreItemTypeNonRenewingSubscription;
    
    _period =
    StoreItemPeriodYear;
    
    return self;
}

@end

#pragma mark - Store Manager

@interface Store () <SKProductsRequestDelegate, SKRequestDelegate, SKPaymentTransactionObserver>

@property (nonatomic, strong) NSString              *sharedSecret;
@property (nonatomic, strong) NSArray <StoreItem *> *storeItems;

@property (nonatomic, strong) NSArray <SKProduct *> *products;

@property (nonatomic, assign) BOOL isRestoring;
@property (nonatomic, assign) BOOL isSandbox;

@property (nonatomic, strong) SKProductsRequest       *productsRequest;
@property (nonatomic, strong) SKReceiptRefreshRequest *receiptRequest;

@property (nonatomic, strong) SKPaymentQueue          *restoreQueue;

// Массивы для хранения блоков
@property (nonatomic, strong) NSMutableArray <RestoreCompletion> *restoreCompletions;

@property (nonatomic, assign) BOOL      isTrialPeriod;

@property (nonatomic, strong) NSDate   *purchasedDate;
@property (nonatomic, strong) NSString *purchasedVersion;

@property (nonatomic, strong) LockRules lockRules;

@end

@implementation Store

+(instancetype)current
{
    static Store *_current = nil;
    static dispatch_once_t oncePredicate;
    
    dispatch_once(&oncePredicate, ^
    {
        _current = self.new;
    });
    
    return _current;
}

+(void)setupWithSharedSecret:(NSString              *)sharedSecret
                  storeItems:(NSArray <StoreItem *> *)storeItems
                  completion:(RestoreCompletion      )completion;
{
    Store.current.sharedSecret = sharedSecret;
    Store.current.storeItems   = storeItems;
    
    [Store.current
     restoreProductsCompletion:completion];
}

+(void)restoreWithCompletion:(RestoreCompletion)completion
{
    [Store.current
     restoreProductsCompletion:completion];
}

+(StoreItem *)storeItemWithIdentifier:(NSString *)identifier
{
    NSArray *storeItems =
    Store.storeItems;
    
    for (StoreItem *storeItem in storeItems)
        if ([storeItem.identifier isEqualToString:identifier])
            return storeItem;
    
    StoreItem *storeItem =
    StoreItem.new;
    
    storeItem.identifier = identifier;
    
    return
    storeItem;
}

+(BOOL)isReady
{
    return
    (Store.current.isSetupComplete &&
     Store.current.products.count &&
     !Store.current.isRestoring);
}

+(BOOL)isSandbox
{
    return
    Store.current.isSandbox;
}

+(NSArray<StoreItem *> *)storeItems
{
    NSSortDescriptor *sortDescriptorType =
    [NSSortDescriptor.alloc
     initWithKey:@"type"
     ascending:YES];
    
    NSSortDescriptor *sortDescriptorPrice =
    [NSSortDescriptor.alloc
     initWithKey:@"priceNumber"
     ascending:YES];
    
    return
    [Store.current.storeItems
     sortedArrayUsingDescriptors:@[sortDescriptorType, sortDescriptorPrice]];
}

+(NSArray<StoreItem *> *)storeItemsPurchased
{
    NSMutableArray *storeItems =
    NSMutableArray.new;
    
    for (StoreItem *storeItem in Store.current.storeItems)
        if (storeItem.isPurchased == YES)
            [storeItems addObject:storeItem];
    
    NSSortDescriptor *sortDescriptorType =
    [NSSortDescriptor.alloc
     initWithKey:@"type"
     ascending:YES];
    
    NSSortDescriptor *sortDescriptorPrice =
    [NSSortDescriptor.alloc
     initWithKey:@"priceNumber"
     ascending:YES];
    
    return
    [storeItems
     sortedArrayUsingDescriptors:@[sortDescriptorType, sortDescriptorPrice]];
}

+(NSArray <StoreItem *> *)storeItemsWithType:(StoreItemType)type
{
    NSMutableArray *storeItems =
    NSMutableArray.new;
    
    for (StoreItem *storeItem in Store.current.storeItems)
        if (storeItem.type == type)
            [storeItems addObject:storeItem];
    
    NSSortDescriptor *sortDescriptor =
    [NSSortDescriptor.alloc
     initWithKey:@"priceNumber"
     ascending:YES];
    
    return
    [storeItems
     sortedArrayUsingDescriptors:@[sortDescriptor]];
}

+(NSArray <StoreItem *> *)storeItemsPurchasedWithType:(StoreItemType)type
{
    NSMutableArray *storeItems =
    NSMutableArray.new;
    
    for (StoreItem *storeItem in Store.current.storeItems)
        if (storeItem.type        == type &&
            storeItem.isPurchased == YES)
            [storeItems addObject:storeItem];
    
    NSSortDescriptor *sortDescriptor =
    [NSSortDescriptor.alloc
     initWithKey:@"priceNumber"
     ascending:YES];
    
    return
    [storeItems
     sortedArrayUsingDescriptors:@[sortDescriptor]];
}

+(NSDate *)firstInstallDate
{
    return
    Store.current.purchasedDate;
}

+(NSString *)firstInstallAppVersion
{
    return
    Store.current.purchasedVersion;
}

+(BOOL)firstInstallDateIsOlderDate:(NSDate *)date
{
    return
    [Store.current purchasedDateIsOlderDate:date];
}

+(BOOL)firstInstallIsOlderVersion:(NSString *)version
{
    return
    [Store.current purchasedVersionIsOlderVersion:version];
}

#pragma mark - Store Manager Init zone

-(instancetype)init
{
    if (self = [super init])
    {
        self.restoreCompletions = NSMutableArray.new;
        
        self.restoreQueue  = SKPaymentQueue.new;
        
        [self.restoreQueue addTransactionObserver:self];
                
        [NSNotificationCenter.defaultCenter
         addObserver:self
         selector:@selector(applicationWillEnterForeground)
         name:UIApplicationWillEnterForegroundNotification
         object:nil];
    }
    
    return self;
}

-(BOOL)isSetupComplete
{
    return
    (Store.current.sharedSecret &&
     Store.current.storeItems.count);
}

-(void)applicationWillEnterForeground
{
    NSLog(@"[INFO] Store: Application will enter foreground");
    
    [self restoreProductsCompletion:nil];
}

-(void)returnCompletionsWithError:(NSError *)error
{
    self.isRestoring = NO;
    
    for (RestoreCompletion restoreCompletion in self.restoreCompletions)
        restoreCompletion(error);
    
    [self.restoreCompletions removeAllObjects];
    
    [NSNotificationCenter.defaultCenter
     postNotificationName:STORE_MANAGER_CHANGED
     object:error];
}

#pragma mark - Product Restore

-(void)restoreProductsCompletion:(RestoreCompletion)completion
{
    NSLog (@"[INFO] Store: Try product list loading...");
    
    if (!Store.current.isSetupComplete)
    {
        NSLog(@"[ERROR] Store: Loading products failed. Store setup is not completed, shared secret or idientifiers is empty!");
        
        completion(nil);
        
        return;
    }
    
    if (completion)
        [self.restoreCompletions
         addObject:completion];
    
    if (self.isRestoring)
        return;
    
    self.isRestoring = YES;
    
    NSMutableSet <NSString *> *productIdentifiers =
    NSMutableSet.new;
    
    for (StoreItem *s in self.storeItems)
        [productIdentifiers addObject:s.identifier];
    
    // Проверим продукты в кеше, может быть не нужно их загружать заново
    if (self.products)
    {
        NSLog (@"[INFO] Store: Products finded in cache...");
        
        NSMutableArray <NSString *> *searched =
        NSMutableArray.new;
        
        for (SKProduct *product in self.products)
            for (NSString *identifier in productIdentifiers)
                if ([product.productIdentifier isEqualToString:identifier])
                    [searched addObject:identifier];
        
        if (searched.count == self.storeItems.count)
        {
//            NSLog (@"[INFO] Store: Try restoring transactions...");
            
            [self refreshReceipt];
//            [self.restoreQueue
//             restoreCompletedTransactions];
            
            return;
        }
        
        self.products = nil;
    }
    
    self.productsRequest =
    [SKProductsRequest.alloc
     initWithProductIdentifiers:productIdentifiers];
    
    self.productsRequest.delegate = self;
    
    [self.productsRequest start];
}

-(void)productsRequest:(SKProductsRequest  *)request
    didReceiveResponse:(SKProductsResponse *)response
{
    NSLog (@"[INFO] Store: Product list loading finished");
    
    if (response.invalidProductIdentifiers.count)
    {
        NSLog (@"[ERROR] Store: Ignore invalid identifiers: %@",
               response.invalidProductIdentifiers);
        
//        NSString *errorMessage =
//        [NSString stringWithFormat:@"[ERROR] Store: Invalid identifiers: %@",
//         response.invalidProductIdentifiers];
        
//        NSLog (@"%@", errorMessage);
//        dispatch_async(dispatch_get_main_queue(), ^(void)
//        {
//            [self
//             returnCompletionsWithError:[NSError
//                                         errorWithDomain:@"Store"
//                                         code:-1
//                                         userInfo:@{NSLocalizedDescriptionKey:errorMessage}]];
//        });
//
//        return;
    }
    
    self.products =
    response.products;
    
    for (SKProduct *product in self.products)
        for (StoreItem *s in self.storeItems)
            if ([s.identifier isEqualToString:product.productIdentifier])
                s.product = product;
    
//    NSLog (@"[INFO] Store: Try restoring transactions...");
    
    [self refreshReceipt];
//    [self.restoreQueue restoreCompletedTransactions];
}

//-(void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue
//{
//    NSLog (@"[INFO] Store: Restoring transactions finished");
//
//    NSMutableArray <NSString *> *productIdentifiers =
//    NSMutableArray.new;
//
//    for (StoreItem *s in self.storeItems)
//        [productIdentifiers addObject:s.identifier];
//
//    NSLog(@"[INFO] Store: Count of transactions: %lu", (unsigned long)queue.transactions.count);
//
//    self.idsForCheck = NSMutableArray.new;
//
//    for (SKPaymentTransaction *transaction in queue.transactions)
//    {
//        if (transaction.transactionState == SKPaymentTransactionStateRestored)
//            if (![self.idsForCheck containsObject:transaction.payment.productIdentifier])
//                [self.idsForCheck addObject:transaction.payment.productIdentifier];
//
//        [queue finishTransaction:transaction];
//    }
//
//    NSLog(@"[INFO] Store: Ids for check: %@", self.idsForCheck);
//
//    // Если у нас есть подписки nonReniwing то их в списке восстанавленных
//    // транзакций не будет (но они будут в чеке, поэтому эти айдишки так же надо добавить)
//    NSArray *nonRenewing =
//    [Store storeItemsWithType:StoreItemTypeNonRenewingSubscription];
//
//    if (nonRenewing.count)
//        for (StoreItem *storeItem in nonRenewing)
//            [self.idsForCheck addObject:storeItem.identifier];
//
//    NSArray *nonConsumable =
//    [Store storeItemsWithType:StoreItemTypeNonConsumable];
//
//    if (nonConsumable.count)
//        for (StoreItem *storeItem in nonConsumable)
//            [self.idsForCheck addObject:storeItem.identifier];
//
//    NSLog(@"[INFO] Store: Сформирована структура для проверки чека: %@", self.idsForCheck);
//
//    [self refreshReceipt];
//}

-(void)refreshReceipt
{
    NSLog(@"[INFO] Store: Check receipt...");
    
    if (![NSFileManager.defaultManager
          fileExistsAtPath:NSBundle.mainBundle.appStoreReceiptURL.path] ||
        ![NSData
         dataWithContentsOfURL:NSBundle.mainBundle.appStoreReceiptURL])
    {
        NSLog(@"[INFO] Store: Receipt not found, try refresh receipt...");
        
        self.receiptRequest =
        [SKReceiptRefreshRequest.alloc
         initWithReceiptProperties:@{}];
        
        self.receiptRequest.delegate = self;
        
        [self.receiptRequest start];
        
        return;
    }
    
    NSLog(@"[INFO] Store: Receipt found");
    
    [self encryptReceipt];
}

-(void)  request:(SKRequest *)request
didFailWithError:(NSError   *)error
{
    if (![request isKindOfClass:SKReceiptRefreshRequest.class])
        return;
    
    NSLog(@"[ERROR] Store: Receipt refresh failed...");
    
    NSLog(@"[ERROR] Store: %@", error.localizedDescription);
    
    [self returnCompletionsWithError:error];
}

-(void)requestDidFinish:(SKRequest *)request
{
    if (![request isKindOfClass:SKReceiptRefreshRequest.class])
        return;
    
    NSLog(@"[INFO] Store: Receipt refreshed...");
    
    if (![NSFileManager.defaultManager
          fileExistsAtPath:NSBundle.mainBundle.appStoreReceiptURL.path])
    {
        NSError *receiptError =
        [NSError
         errorWithDomain:@"Store"
         code:-1
         userInfo:@{NSLocalizedDescriptionKey:@"Receipt is nil, checking products is failed."}];
        
        NSLog(@"[ERROR] Store: %@", receiptError.localizedDescription);
        
        [self returnCompletionsWithError:receiptError];
        
        // This can happen if the user cancels the login screen for the store.
        // If we get here it means there is no receipt and an attempt to get it failed because the user cancelled the login.
        //[self trackFailedAttempt];
        
        return;
    }
    
    [self encryptReceipt];
}

-(void)encryptReceipt
{
    NSLog(@"[INFO] Store: Try receipt encrypt...");
    
    NSData *receipt =
    [NSData
     dataWithContentsOfURL:NSBundle.mainBundle.appStoreReceiptURL];
    
    NSLog(@"[INFO] Store: Receipt setup (receipt.length = %lu)",
          (unsigned long)receipt.length);

    #ifdef DEBUG
    BOOL sandbox =
    Store.current.isSandbox = YES;
    #else
    BOOL sandbox =
    Store.current.isSandbox = NO;
    #endif
    
    NSLog(@"[INFO] Store: Receipt setup (sandbox = %@)",
          sandbox ? @"YES" : @"NO");
    
    // create the JSON object that describes the request
    NSDictionary *requestContents =
    @{@"receipt-data":[receipt base64EncodedStringWithOptions:0],
      @"password":self.sharedSecret};

    NSError *error = nil;
    
    NSData *requestData =
    [NSJSONSerialization
     dataWithJSONObject:requestContents
     options:0
     error:&error];
    
    if (error || !requestData)
    {
         NSLog(@"[ERROR] Store: %@", error.localizedDescription);
        
        [self returnCompletionsWithError:error];
        
        return;
    }
    
    // create a POST request with the receipt data.
    NSURL *storeURL =
    [NSURL URLWithString:@"https://buy.itunes.apple.com/verifyReceipt"];
    
    if (sandbox)
        storeURL =
        [NSURL URLWithString:@"https://sandbox.itunes.apple.com/verifyReceipt"];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void)
    {
        NSError *error = nil;
        
        NSMutableURLRequest *storeRequest =
        [NSMutableURLRequest
         requestWithURL:storeURL];
        
        storeRequest.HTTPMethod = @"POST";
        storeRequest.HTTPBody   = requestData;
        
        NSURLResponse *response = nil;
        
        NSData *resData =
        [self
         sendSynchronousRequest:storeRequest
         returningResponse:&response
         error:&error];
        
        if (error)
        {
            dispatch_async(dispatch_get_main_queue(), ^(void)
            {
                NSLog(@"[ERROR] Store: %@",
                      error.localizedDescription);
                
                [self returnCompletionsWithError:error];
            });
            
            return;
        }
        
        NSDictionary *jsonResponse =
        [NSJSONSerialization
         JSONObjectWithData:resData
         options:0
         error:&error];
        
        if (error || !jsonResponse)
        {
            dispatch_async(dispatch_get_main_queue(), ^(void)
            {
                NSLog(@"[ERROR] Store: %@",
                      error.localizedDescription);
                
                [self returnCompletionsWithError:error];
            });
            
            return;
        }
        
        //NSLog(@"jsonResponse:%@", jsonResponse);
        
        /*
         {
            environment = Sandbox;
            "latest_receipt" = "MIISbwYJ.....kNTVhFEWUMYJIgw==";
            receipt =
            {
                "adam_id" = 0;
                "app_item_id" = 0;
                "application_version" = 29;
                "bundle_id" = "com.site.bundleId";
                "download_id" = 0;
                "in_app" = ();
                "original_application_version" = "1.0";
                "original_purchase_date" = "2013-08-01 07:00:00 Etc/GMT";
                "original_purchase_date_ms" = 1375340400000;
                "original_purchase_date_pst" = "2013-08-01 00:00:00 America/Los_Angeles";
                "receipt_creation_date" = "2019-11-21 16:15:06 Etc/GMT";
                "receipt_creation_date_ms" = 1574352906000;
                "receipt_creation_date_pst" = "2019-11-21 08:15:06 America/Los_Angeles";
                "receipt_type" = ProductionSandbox;
                "request_date" = "2019-11-21 16:15:07 Etc/GMT";
                "request_date_ms" = 1574352907770;
                "request_date_pst" = "2019-11-21 08:15:07 America/Los_Angeles";
                "version_external_identifier" = 0;
            };
            status = 0;
         }
         */
        
        NSArray *dictLatestReceiptsInfo =
        jsonResponse[@"latest_receipt_info"];
        
        if ([jsonResponse[@"status"] integerValue] == 21004)
        {
            NSError *receiptError =
            [NSError
             errorWithDomain:@"Store"
             code:-1
             userInfo:@{NSLocalizedDescriptionKey:@"Shared secret incorrected."}];
            
            dispatch_async(dispatch_get_main_queue(), ^(void)
            {
                NSLog(@"[ERROR] Store: %@",
                      receiptError.localizedDescription);
                
                [self returnCompletionsWithError:receiptError];
                
                [NSException
                 raise:@"Store"
                 format:@"Shared secret incorrected."];
            });
            
            return;
        }
        
        if (![jsonResponse[@"receipt"][@"bundle_id"] isEqualToString:NSBundle.mainBundle.bundleIdentifier])
        {
            NSError *receiptError =
            [NSError
             errorWithDomain:@"Store"
             code:-1
             userInfo:@{NSLocalizedDescriptionKey:@"Bundle is incorrected."}];
            
            dispatch_async(dispatch_get_main_queue(), ^(void)
            {
                NSLog(@"[ERROR] Store: %@",
                      receiptError.localizedDescription);
                
                [self returnCompletionsWithError:receiptError];
                
                [NSException
                 raise:@"Store"
                 format:@"Bundle is incorrected."];
            });
            
            return;
        }
        
        self.purchasedVersion =
        jsonResponse[@"receipt"][@"original_application_version"];
        
        NSDateFormatter *formatter =
        NSDateFormatter.new;
        
        formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss VV";
        
        self.purchasedDate =
        [formatter dateFromString:jsonResponse[@"receipt"][@"original_purchase_date"]];
        
        long long requestDateMs =
        [jsonResponse[@"receipt"][@"request_date_ms"] longLongValue];
        
        //NSLog(@"jsonRECEIPTResponse:%@", jsonResponse[@"receipt"]);
        
        NSMutableDictionary <NSString *, NSDictionary *> *receipts =
        NSMutableDictionary.new;
        
        for (StoreItem *storeItem in self.storeItems)
        {
            NSDictionary *lastReceipt = nil;
            
            for (NSDictionary *receipt in dictLatestReceiptsInfo)
            {
                if ([receipt[@"product_id"] isEqualToString:storeItem.identifier] == NO)
                    continue;
                
                if (lastReceipt == nil)
                {
                    lastReceipt = receipt;
                    
                    continue;
                }
                
                if ([lastReceipt[@"purchase_date_ms"] longLongValue] > [receipt[@"purchase_date_ms"] longLongValue])
                    continue;
                
                lastReceipt = receipt;
            }
            
            if (lastReceipt == nil)
                continue;
            
            receipts[storeItem.identifier] = lastReceipt;
        }
        
        // Удалим сохраненные данные о покупках
        for (StoreItem *s in self.storeItems)
            if (s.type != StoreItemTypeConsumable)
                [NSUserDefaults.standardUserDefaults
                 removeObjectForKey:s.identifier];
                
        [NSUserDefaults.standardUserDefaults synchronize];
        
        for (NSDictionary *reciept in receipts.allValues)
        {
            /*
             "expires_date" = "2018-12-07 19:29:01 Etc/GMT";
             "expires_date_ms" = 1544210941000;
             "expires_date_pst" = "2018-12-07 11:29:01 America/Los_Angeles";
             "is_in_intro_offer_period" = false;
             "is_trial_period" = false;
             "original_purchase_date" = "2018-12-03 17:12:03 Etc/GMT";
             "original_purchase_date_ms" = 1543857123000;
             "original_purchase_date_pst" = "2018-12-03 09:12:03 America/Los_Angeles";
             "original_transaction_id" = 1000000481432187;
             "product_id" = "com.autorenewable.year";
             "purchase_date" = "2018-12-07 18:29:01 Etc/GMT";
             "purchase_date_ms" = 1544207341000;
             "purchase_date_pst" = "2018-12-07 10:29:01 America/Los_Angeles";
             quantity = 1;
             "transaction_id" = 1000000484279676;
             "web_order_line_item_id" = 1000000041696210;
             */
            
            StoreItem *storeItem =
            [Store storeItemWithIdentifier:reciept[@"product_id"]];
            
            storeItem.startDate =
            [NSDate
             dateWithTimeIntervalSinceNow:[reciept[@"purchase_date_ms"] integerValue] / 1000.];
            
            if (reciept[@"expires_date_ms"])
                storeItem.endDate =
                [NSDate
                 dateWithTimeIntervalSinceNow:[reciept[@"expires_date_ms"] integerValue] / 1000.];
            
            storeItem.isTrial   =
            [reciept[@"is_trial_period"] isEqualToString:@"true"];
            
            switch (storeItem.type)
            {
                case StoreItemTypeNonConsumable:
                case StoreItemTypeConsumable:
                {
                    [NSUserDefaults.standardUserDefaults
                     setObject:reciept[@"original_purchase_date"]
                     forKey:reciept[@"product_id"]];
                    
                    break;
                }
                    
                case StoreItemTypeNonRenewingSubscription:
                {
                    NSDateComponents *dayComponent =
                    NSDateComponents.new;
                    
                    if (storeItem.period == StoreItemPeriodWeek)
                        dayComponent.day = 7;
                    
                    else if (storeItem.period == StoreItemPeriodMonth)
                        dayComponent.month = 1;
                    
                    else if (storeItem.period == StoreItemPeriodYear)
                        dayComponent.year = 1;
                    
                    storeItem.endDate =
                    [NSCalendar.currentCalendar
                     dateByAddingComponents:dayComponent
                     toDate:storeItem.startDate
                     options:0];
                    
                    if (storeItem.endDate.timeIntervalSince1970 > requestDateMs / 1000.)
                        [NSUserDefaults.standardUserDefaults
                         setObject:reciept[@"original_purchase_date"]
                         forKey:reciept[@"product_id"]];
                    
                    break;
                }
                    
                case StoreItemTypeAutoRenewableSubscription:
                {
                    if (storeItem.endDate.timeIntervalSince1970 > requestDateMs / 1000.)
                        [NSUserDefaults.standardUserDefaults
                         setObject:reciept[@"original_purchase_date"]
                         forKey:reciept[@"product_id"]];
                    
                    break;
                }
                    
                default:
                    break;
            }
            
            [NSUserDefaults.standardUserDefaults synchronize];
            
            NSLog (@"[INFO] Store: Identifier '%@' %@",
                   reciept[@"product_id"],
                   [NSUserDefaults.standardUserDefaults
                    objectForKey:reciept[@"product_id"]] ? @"is purchased" : @"is not purchased");
        }
        
        dispatch_async(dispatch_get_main_queue(), ^(void)
        {
            NSLog(@"[INFO] Store: Finish parsing reciept");
            
            [self returnCompletionsWithError:nil];
        });
    });
}

-(NSInteger)daysBetweenDate:(NSDate *)fromDateTime
                    andDate:(NSDate *)toDateTime
{
    NSDate *fromDate;
    NSDate *toDate;
    
    NSCalendar *calendar =
    NSCalendar.currentCalendar;
    
    [calendar
     rangeOfUnit:NSCalendarUnitDay
     startDate:&fromDate
     interval:NULL
     forDate:fromDateTime];
    
    [calendar
     rangeOfUnit:NSCalendarUnitDay
     startDate:&toDate
     interval:NULL
     forDate:toDateTime];
    
    NSDateComponents *difference =
    [calendar
     components:NSCalendarUnitDay
     fromDate:fromDate
     toDate:toDate
     options:0];
    
    return difference.day;
}

#pragma mark - Helpers

-(BOOL)purchasedDateIsOlderDate:(NSDate *)date
{
    return
    ([self.purchasedDate timeIntervalSinceDate:date] < 0);
}

-(BOOL)purchasedVersionIsOlderVersion:(NSString *)version
{
    if ([self.purchasedVersion isEqualToString:version])
        return NO;
    
    NSArray *thisVersion =
    [self.purchasedVersion componentsSeparatedByString:@"."];
    
    NSArray *compareVersion =
    [version componentsSeparatedByString:@"."];
    
    NSInteger maxCount =
    MAX(thisVersion.count, compareVersion.count);
    
    for (NSInteger index = 0; index < maxCount; index++)
    {
        NSInteger thisSegment =
        (index < thisVersion.count) ? [[thisVersion objectAtIndex:index] integerValue] : 0;
        
        NSInteger compareSegment = (index < compareVersion.count) ? [[compareVersion objectAtIndex:index] integerValue] : 0;
        
        if (thisSegment < compareSegment)
            return YES;
        
        
        if (thisSegment > compareSegment)
            return NO;
    }
    
    return NO;
}

-(NSData *)sendSynchronousRequest:(NSURLRequest *)request
                returningResponse:(NSURLResponse **)response
                            error:(NSError **)error
{
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);
    
    NSError __block *err = NULL;
    NSData __block *data;
    NSURLResponse __block *resp;
    
    [[NSURLSession.sharedSession
      dataTaskWithRequest:request
      completionHandler:^(NSData* _data, NSURLResponse* _response, NSError* _error)
      {
          resp = _response;
          err = _error;
          data = _data;
          dispatch_group_leave(group);
      }] resume];
    
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    
    if (response)
        *response = resp;
    
    if (error)
        *error = err;
    
    return data;
}

+(void)setLockRules:(LockRules)lockRules
{
    Store.current.lockRules = lockRules;
}

+(BOOL)isLockWithController:(UIViewController *)controller
{
    if (Store.current.lockRules)
        return
        Store.current.lockRules(controller);
    
    return NO;
}

@end
