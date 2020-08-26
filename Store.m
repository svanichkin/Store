//
//  Store.m
//  Version 2.5
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

@property (nonatomic, strong) NSArray <NSDictionary <NSString *, NSDate *> *> *asPurchasedDates;
@property (nonatomic, strong) NSArray <NSDictionary <NSString *, NSArray <NSString *> *> *> *asPurchasedVersions;

@end

@implementation StoreItem

-(instancetype)init
{
    if (self = [super init])
    {
        self.purchaseCompletions = NSMutableArray.new;
        self.purchaseQueue       = SKPaymentQueue.defaultQueue;
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

-(void)setIsInvalid:(BOOL)isInvalid
{
    _isInvalid = isInvalid;
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
    [self cleanPrice:formattedPrice];
    
    _priceString = [numberFormatter stringFromNumber:product.price];
    _priceNumber = product.price;
    
    _currencyCode =
    [product.priceLocale objectForKey:NSLocaleCurrencyCode];
    
    _currencySymbol =
    [product.priceLocale objectForKey:NSLocaleCurrencySymbol];
    
    _titleWithPrice =
    [NSString
     stringWithFormat:@"%@ %@",
     formattedPrice,
     product.localizedTitle];
    
    _title = product.localizedTitle;
    
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
    
    if (_period == StoreItemPeriodYear)
    {
        NSInteger p =
        @(_priceNumber.integerValue / 52).integerValue;
        
        if (p > 0)
            _pricePerWeekString  =
            [self
             cleanPrice:[numberFormatter
                         stringFromNumber:@(p)]];
        
        p =
        @(_priceNumber.integerValue / 12).integerValue;
        
        if (p > 0)
            _pricePerMonthString =
            [self
             cleanPrice:[numberFormatter
                         stringFromNumber:@(p)]];
    }
    
    if (_period == StoreItemPeriodMonth)
    {
        NSInteger p =
        @(_priceNumber.integerValue / 4).integerValue;
        
        if (p > 0)
            _pricePerWeekString  =
            [self
             cleanPrice:[numberFormatter
                         stringFromNumber:@(p)]];
    }
}

-(NSString *)detail
{
    if (self.isPurchased == NO ||
        self.startDate   == nil)
        return
        _product.localizedDescription;
    
    NSString *dateString;
    
    if (self.startDate && self.endDate)
        dateString =
        [NSString
         stringWithFormat:@"%@—%@",
         [self
          startDateStringWithFormat:@"dd.MM.yyyy"],
         [self
          endDateStringWithFormat:@"dd.MM.yyyy"]];
    
    else
        dateString =
        [self
         startDateStringWithFormat:@"dd.MM.yyyy"];

    return
    [NSString
     stringWithFormat:@"%@ %@",
     _product.localizedDescription,
     dateString];
}

-(NSString *)cleanPrice:(NSString *)price
{
    price =
    [price
     stringByReplacingOccurrencesOfString:@" "
     withString:@""];
    
    price =
    [price
     stringByReplacingOccurrencesOfString:@".00"
     withString:@""];
    
    price =
    [price
     stringByReplacingOccurrencesOfString:@",00"
     withString:@""];
    
    return price;
}

-(BOOL)isPurchased
{
    BOOL purchased = NO;
    
    if (self.asPurchasedDates.count > 0 && Store.firstInstallDate)
    {
        NSCalendar *calendar = NSCalendar.currentCalendar;
        
        NSDateComponents *purchasedComponents =
        [calendar
         components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay)
         fromDate:Store.firstInstallDate];
        
        for (NSDictionary <NSString *, NSDate *> *range in self.asPurchasedDates)
            if (range[@"single"])
            {
                NSDateComponents *singleComponents =
                [calendar
                 components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay)
                 fromDate:range[@"single"]];
                
                if (singleComponents.year  == purchasedComponents.year  &&
                    singleComponents.month == purchasedComponents.month &&
                    singleComponents.day   == purchasedComponents.day)
                {
                    _startDate = Store.firstInstallDate;
                    
                    purchased = YES;
                }
            }
            
            else if (range[@"from"].timeIntervalSince1970 <= Store.firstInstallDate.timeIntervalSince1970 &&
                     range[@"to"].timeIntervalSince1970 >= Store.firstInstallDate.timeIntervalSince1970)
            {
                _startDate = Store.firstInstallDate;
                
                purchased = YES;
            }
    }
    
    else if (self.asPurchasedVersions > 0 && Store.firstInstallAppVersion)
    {
        NSArray <NSString *> *purchasedVersion =
        [Store.firstInstallAppVersion
         componentsSeparatedByString:@"."];
        
        for (NSDictionary <NSString *, NSArray <NSString *> *> *range in self.asPurchasedVersions)
            if (range[@"single"])
            {
                if (range[@"single"].count != purchasedVersion.count)
                    continue;
                
                if ([[range[@"single"]
                      componentsJoinedByString:@"."]
                     isEqualToString:[purchasedVersion
                                      componentsJoinedByString:@"."]])
                {
                    _startDate = Store.firstInstallDate;
                    
                    purchased = YES;
                }
            }
        
            else
            {
                NSComparisonResult from =
                [self
                 compareVersion:purchasedVersion
                 toVersion:range[@"from"]];
                
                NSComparisonResult to =
                [self
                 compareVersion:purchasedVersion
                 toVersion:range[@"to"]];

                if ((from == NSOrderedDescending || from == NSOrderedSame) &&
                    (to   == NSOrderedAscending  || to   == NSOrderedSame))
                {
                    _startDate = Store.firstInstallDate;
                    
                    purchased = YES;
                }
            }
    }
    
    else if (self.type == StoreItemTypeConsumable)
        purchased =
        self.consumableCount.integerValue > 0;
    
    else if (self.type == StoreItemTypeNonConsumable)
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

-(NSComparisonResult)compareVersion:(NSArray <NSString *> *)versionOneComp
                          toVersion:(NSArray <NSString *> *)versionTwoComp
{
    NSInteger pos = 0;
    
    while (versionOneComp.count > pos || versionTwoComp.count > pos)
    {
        NSInteger v1 =
        versionOneComp.count > pos ? versionOneComp[pos].intValue : 0;
        
        NSInteger v2 =
        versionTwoComp.count > pos ? versionTwoComp[pos].intValue : 0;
        
        if (v1 < v2)
            return
            NSOrderedAscending;
        
        else if (v1 > v2)
            return
            NSOrderedDescending;
        
        pos ++;
    }
    
    return
    NSOrderedSame;
}

//   определенная дата: @"12/31/2020"
//        диапазон дат: @"1/1/2020-12/31/2020"
// определенная версия: @"3.0.1"
//     диапазон версий: @"1.0-3.0.1"
-(void)setAsPurchasedForRanges:(NSArray <NSString *> *)ranges
{
    _asPurchasedDates    = @[];
    _asPurchasedVersions = @[];
    
    if (ranges == nil)
        return;
    
    for (NSString *range in ranges)
    {
        NSCharacterSet *charactersToRemove =
        [[NSCharacterSet
         characterSetWithCharactersInString:@"0123456789./-"]
         invertedSet];
        
        NSString *cleanRange =
        [[range
          componentsSeparatedByCharactersInSet:charactersToRemove]
         componentsJoinedByString:@""];
        
        if (cleanRange.length < 3)
            continue;
        
        NSArray <NSString *> *period =
        [cleanRange
         componentsSeparatedByString:@"-"];
        
        if (period.count > 2)
            [NSException
             raise:@"Store"
             format:@"Wrong range: %@", range];
        
        NSString *from =
        period.firstObject;
        
        NSString *to =
        period.lastObject;
        
        if (([from
              containsString:@"/"] &&
             [from
              containsString:@"."]) ||
            ([to
              containsString:@"/"] &&
             [to
              containsString:@"."]))
            [NSException
             raise:@"Store"
             format:@"Wrong range: %@", range];

        NSDate *fromDate;
        NSDate *toDate;
        
        NSDateFormatter *dateFormater =
        NSDateFormatter.new;
        
        dateFormater.dateFormat = @"dd/MM/yyyy";
        
        dateFormater.timeZone =
        [NSTimeZone
         timeZoneWithName:@"UTC"];
        
        if ([from
             containsString:@"/"])
            fromDate =
            [dateFormater
             dateFromString:from];
        
        if ([to
             containsString:@"/"])
            toDate =
            [dateFormater
             dateFromString:to];

        NSArray <NSString *> *fromVersion;
        NSArray <NSString *> *toVersion;
        
        if ([from
             containsString:@"."])
            fromVersion =
            [from
             componentsSeparatedByString:@"."];
        
        if ([to
             containsString:@"."])
            toVersion =
            [to
             componentsSeparatedByString:@"."];

        NSMutableArray <NSDictionary <NSString *, NSDate *> *> *dates =
        _asPurchasedDates.mutableCopy;
        
        NSMutableArray <NSDictionary <NSString *, NSArray <NSString *> *> *> *versions =
        _asPurchasedVersions.mutableCopy;
        
        if (period.count == 1)
        {
            if (fromDate)
            {
                [dates
                 addObject:@{@"single":fromDate}];
                
                _asPurchasedDates =
                dates.copy;
            }
            
            else if (fromVersion)
            {
                [versions
                 addObject:@{@"single":fromVersion}];
                
                _asPurchasedVersions =
                versions.copy;
            }
            
            else
                [NSException
                 raise:@"Store"
                 format:@"Wrong range: %@", range];
        }
                
        else if (period.count == 2)
        {
            if (fromDate && toDate)
            {
                [dates
                 addObject:@{@"from":fromDate,
                               @"to":toDate}];
                
                _asPurchasedDates =
                dates.copy;
            }
            
            else if (fromVersion && toVersion)
            {
                [versions
                 addObject:@{@"from":fromVersion,
                               @"to":toVersion}];
                
                _asPurchasedVersions =
                versions.copy;
            }
            
            else
                [NSException
                 raise:@"Store"
                 format:@"Wrong range: %@", range];
        }
    }
}

#pragma mark - Purchase Product

-(void)purchaseWithCompletion:(PurchaseCompletion)completion
{
    NSLog(@"[INFO] Store: Try purchasing product with identifier '%@'...",
          _identifier);
    
    if (!self.product || !Store.isReady)
    {
        NSString *errorMessage =
        [NSString stringWithFormat:@"[ERROR] Store: Purchase with identifier '%@' failed. Store is not Ready, or product for this identifier not found!",
              _identifier];
        
        NSLog(@"%@",
              errorMessage);
        
        NSError *error =
        [NSError
         errorWithDomain:@"Store"
         code:-1
         userInfo:@{NSLocalizedDescriptionKey:errorMessage}];
        
        if (completion)
            completion(error);
        
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
    
    [self.purchaseQueue
     addTransactionObserver:self];
    
    [self.purchaseQueue
     addPayment:payment];
}

-(void)setDefaultConsumableCount:(NSNumber *)defaultConsumableCount
{
    [NSUserDefaults.standardUserDefaults
     setObject:defaultConsumableCount
     forKey:[@"defaultConsumableCount:"
             stringByAppendingString:self.identifier]];
    
    [NSUserDefaults.standardUserDefaults
     synchronize];
}

-(NSNumber *)defaultConsumableCount
{
    [NSUserDefaults.standardUserDefaults
     synchronize];
    
    NSNumber *defaultConsumableCount =
    [NSUserDefaults.standardUserDefaults
     objectForKey:[@"defaultConsumableCount:"
                   stringByAppendingString:self.identifier]];
    
    if (defaultConsumableCount == nil)
        return @1;
    
    return
    defaultConsumableCount;
}

-(void)setConsumableCount:(NSNumber *)consumableCount
{
    if (consumableCount == nil)
        [NSUserDefaults.standardUserDefaults
         removeObjectForKey:[@"consumableCount:"
                             stringByAppendingString:self.identifier]];
    
    else
        [NSUserDefaults.standardUserDefaults
         setObject:consumableCount
         forKey:[@"consumableCount:"
                 stringByAppendingString:self.identifier]];
    
    [NSUserDefaults.standardUserDefaults
     synchronize];
}

-(NSNumber *)consumableCount
{
    [NSUserDefaults.standardUserDefaults
     synchronize];
    
    return
    [NSUserDefaults.standardUserDefaults
     objectForKey:[@"consumableCount:"
                   stringByAppendingString:self.identifier]];
}

-(void)consumablePurchaseDecrease
{
    [self 
    consumablePurchaseDecreaseCount:@(1)];
}

-(void)consumablePurchaseDecreaseCount:(NSNumber *)decreaseCount
{
    NSLog(@"[INFO] Store: Purchasing decrease product from:%@ with identifier '%@'",
          self.consumableCount,
          _identifier);

    NSUInteger dCount =
    labs(decreaseCount.integerValue);
    
    NSInteger count =
    self.consumableCount.integerValue;
    
    count =
    count - dCount;
    
    if (count <= 0)
    {
        self.consumableCount =
        nil;
        
        [NSUserDefaults.standardUserDefaults
         removeObjectForKey:self.identifier];
        
        [NSUserDefaults.standardUserDefaults
         synchronize];
        
        NSLog(@"[INFO] Store: Purchasing product remove with identifier '%@'",
              _identifier);
    }
    
    else
    {
        self.consumableCount =
        @(count);
        
        NSLog(@"[INFO] Store: Purchasing decreased product to:%@ with identifier '%@'",
              self.consumableCount,
              _identifier);
    }
            
    [NSNotificationCenter.defaultCenter
     postNotificationName:STORE_MANAGER_CHANGED
     object:nil];
}

-(void)returnCompletionsWithError:(NSError *)error
{
    [self.purchaseQueue
     addTransactionObserver:self];
    
    self.isPurchasing = NO;
    
    for (PurchaseCompletion completion in self.purchaseCompletions)
        completion(error);
    
    [self.purchaseCompletions removeAllObjects];
    
    [NSNotificationCenter.defaultCenter
     postNotificationName:STORE_MANAGER_CHANGED
     object:error];
}

#pragma mark - Purchase Product Delegate

-(void)paymentQueue:(SKPaymentQueue *)queue
updatedTransactions:(NSArray        *)transactions
{
    NSLog (@"[INFO] Store: Update transaction fired with Purchase Queue");
    
    for (SKPaymentTransaction *transaction in transactions)
    {
        NSLog (@"[INFO] Store: Transaction is [%@]", transaction.payment.productIdentifier);
        
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
                _transactionState = transaction.transactionState;
                
                NSLog (@"[INFO] Store: Update transaction fired [SKPaymentTransactionStatePurchased || restored]");

                [NSUserDefaults.standardUserDefaults
                 setObject:transaction.transactionDate
                 forKey:transaction.payment.productIdentifier];
                
                [NSUserDefaults.standardUserDefaults synchronize];
                
                self.consumableCount =
                @(self.consumableCount.integerValue +
                self.defaultConsumableCount.integerValue);
                
                _startDate =
                transaction.transactionDate;
                
                _transactionId = transaction.transactionIdentifier;
                
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

-(NSString *)startDateStringWithFormat:(NSString *)stringFormat
{
    if (!self.startDate)
        return nil;
    
    NSDateFormatter *dateFormater =
    NSDateFormatter.new;
    
    dateFormater.timeZone         =
    [NSTimeZone
     timeZoneWithAbbreviation:@"UTC"];
    
    dateFormater.dateFormat       =
    stringFormat;
    
    dateFormater.locale           =
    NSLocale.currentLocale;
    
    return
    [dateFormater
     stringFromDate:self.startDate];
}

-(NSString *)endDateStringWithFormat:(NSString *)stringFormat
{
    if (!self.endDate)
        return nil;
    
    NSDateFormatter *dateFormater =
    NSDateFormatter.new;
    
    dateFormater.timeZone         =
    [NSTimeZone
     timeZoneWithAbbreviation:@"UTC"];
    
    dateFormater.dateFormat       =
    stringFormat;
    
    dateFormater.locale           =
    NSLocale.currentLocale;
    
    return
    [dateFormater
     stringFromDate:self.endDate];
}

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

#define STORE_SHAREDSECRET  @"StoreSharedSecred"
#define STORE_iTEMS         @"StoreItems"
#define STORE_UPDATE        @"StoreUpdate"

#define CONFiG_SHAREDSECRET @"sharedSecred"
#define CONFiG_iDENTiFiERS  @"identifiers"
#define CONFiG_iDENTiFiER   @"identifier"
#define CONFiG_TYPE         @"type"
#define CONFiG_COUNT        @"count"
#define CONFiG_AS_RANGE     @"asPurchasedForRanges"

#define TYPE_CONSUMABLE     @"consumable"
#define TYPE_NCONSUMABLE    @"nonConsumable"
#define TYPE_NR_WEEK        @"nonRenewingSubscriptionWeek"
#define TYPE_NR_MONTH       @"nonRenewingSubscriptionMonth"
#define TYPE_NR_YEAR        @"nonRenewingSubscriptionYear"
#define TYPE_RENEWABLE      @"autoRenewableSubscription"

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

@property (nonatomic, strong) NSURL *url;

@property (nonatomic, assign) BOOL isSetupProgress;

@property (nonatomic,   copy) RestoreCompletion setupWithURLCompletion;

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

+(void)setupWithURLString:(NSString        *)urlString
               completion:(RestoreCompletion)completion;
{
    if (Store.current.isSetupProgress)
    {
        if (completion)
            completion(nil);
        
        return;
    }
    
    Store.current.isSetupProgress = YES;
    
    Store.current.setupWithURLCompletion = nil;
    
    NSURL *url =
    [NSURL
     URLWithString:urlString];
    
    if (url == nil)
        [NSException
         raise:@"Store"
         format:@"Url string is not valid: %@",
         urlString];
    
    Store.current.url = url;
    
    [NSUserDefaults.standardUserDefaults
     synchronize];
     
    Store.current.sharedSecret =
    [NSUserDefaults.standardUserDefaults
     objectForKey:STORE_SHAREDSECRET];
    
    Store.current.storeItems =
    [self
     storeItemsWithArray:[NSUserDefaults.standardUserDefaults
                          objectForKey:STORE_iTEMS]];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void)
    {
        NSDate *fileDate =
        [self
         lastModificationDateOfFileAtURL:url];

        NSDate *updateDate =
        [NSUserDefaults.standardUserDefaults
         objectForKey:STORE_UPDATE];

        if (updateDate && fileDate)
            if (!([fileDate
                   compare:updateDate] == NSOrderedDescending))
            {
                dispatch_async(dispatch_get_main_queue(), ^(void)
                {
                    [Store.current
                     restoreProductsCompletion:^(NSError *error)
                    {
                        Store.current.isSetupProgress = NO;
                        
                        if (completion)
                            completion(error);
                    }];
                });
                
                return;
            }

        NSData *jsonData =
        [NSData
         dataWithContentsOfURL:url];
        
        NSDictionary *jsonObject;
        
        if (jsonData)
            jsonObject =
            [NSJSONSerialization
             JSONObjectWithData:jsonData
             options:0
             error:nil];

        if (!jsonData || !jsonObject)
        {
            if (Store.current.sharedSecret.length == 0)
            {
                dispatch_async(dispatch_get_main_queue(), ^(void)
                {
                    Store.current.setupWithURLCompletion =
                    completion;
                    
                    Store.current.isSetupProgress = NO;
                    
                    if (completion)
                        completion([NSError
                                    errorWithDomain:@"Store"
                                    code:-1
                                    userInfo:@{NSLocalizedDescriptionKey:@"Invalid Store Config, json data is nil or incorrected."}]);
                });
            }
            
            else
            {
                dispatch_async(dispatch_get_main_queue(), ^(void)
                {
                    [Store.current
                     restoreProductsCompletion:^(NSError *error)
                    {
                        Store.current.isSetupProgress = NO;
                        
                        if (completion)
                            completion(error);
                    }];
                });
            }
            
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^(void)
        {
            if (jsonObject[CONFiG_SHAREDSECRET] && jsonObject[CONFiG_iDENTiFiERS])
            {
                Store.current.sharedSecret =
                jsonObject[CONFiG_SHAREDSECRET];
                
                [NSUserDefaults.standardUserDefaults
                 setObject:jsonObject[CONFiG_SHAREDSECRET]
                 forKey:STORE_SHAREDSECRET];

                Store.current.storeItems =
                [self
                 storeItemsWithArray:jsonObject[CONFiG_iDENTiFiERS]];
                
                [NSUserDefaults.standardUserDefaults
                 setObject:jsonObject[CONFiG_iDENTiFiERS]
                 forKey:STORE_iTEMS];
                
                [NSUserDefaults.standardUserDefaults
                 setObject:fileDate
                 forKey:STORE_UPDATE];
                
                [NSUserDefaults.standardUserDefaults
                 synchronize];
                
                [Store.current
                 restoreProductsCompletion:^(NSError *error)
                {
                    Store.current.isSetupProgress = NO;
                    
                    if (completion)
                        completion(error);
                }];
            }
            
            else
            {
                Store.current.isSetupProgress = NO;
                
                if (completion)
                    completion([NSError
                                errorWithDomain:@"Store"
                                code:-1
                                userInfo:@{NSLocalizedDescriptionKey:@"Invalid Store Config"}]);
            }
        });
    });
}

+(NSArray <StoreItem *> *)storeItemsWithArray:(NSArray <NSDictionary <NSString *, NSString *> *> *)array
{
    NSMutableArray *items =
    NSMutableArray.new;
    
    for (NSDictionary <NSString *, NSString *> *dictionary in array)
    {
        StoreItem *storeItem =
        StoreItem.new;
        
        storeItem.identifier =
        dictionary[CONFiG_iDENTiFiER];
        
        if ([dictionary[CONFiG_TYPE]
             isEqualToString:TYPE_CONSUMABLE])
        {
            storeItem.type =
            StoreItemTypeConsumable;
            
            if (dictionary[CONFiG_COUNT])
                storeItem.defaultConsumableCount =
                @(dictionary[CONFiG_COUNT].integerValue);
        }

        else if ([dictionary[CONFiG_TYPE]
                  isEqualToString:TYPE_NCONSUMABLE])
            storeItem.type =
            StoreItemTypeNonConsumable;
        
        else if ([dictionary[CONFiG_TYPE]
                  isEqualToString:TYPE_RENEWABLE])
            storeItem.type =
            StoreItemTypeAutoRenewableSubscription;
        
        else
        {
            storeItem.type =
            StoreItemTypeNonRenewingSubscription;
            
            if ([dictionary[CONFiG_TYPE]
                 isEqualToString:TYPE_NR_WEEK])
                storeItem.period =
                StoreItemPeriodWeek;
            
            else if ([dictionary[CONFiG_TYPE]
                      isEqualToString:TYPE_NR_MONTH])
                storeItem.period =
                StoreItemPeriodMonth;
            
            else if ([dictionary[CONFiG_TYPE]
                      isEqualToString:TYPE_NR_YEAR])
                storeItem.period =
                StoreItemPeriodYear;
        }
        
        if (dictionary[CONFiG_AS_RANGE])
            [storeItem
             setAsPurchasedForRanges:(NSArray *)dictionary[CONFiG_AS_RANGE]];
        
        [items
         addObject:storeItem];
    }
    
    return
    items.copy;
}

+(NSDate *)lastModificationDateOfFileAtURL:(NSURL *)url
{
    NSMutableURLRequest *request =
    [NSMutableURLRequest.alloc
     initWithURL:url];
    
    request.HTTPMethod = @"HEAD";
    
    NSHTTPURLResponse *response = nil;
    NSError *error = nil;
    
    [NSURLConnection
     sendSynchronousRequest:request
     returningResponse:&response
     error:&error];
    
    if (error)
    {
        NSLog(@"Error: %@",
              error.localizedDescription);
        
        return
        nil;
    }
    
    else if([response
             respondsToSelector:@selector(allHeaderFields)])
    {
        NSDictionary *headerFields =
        response.allHeaderFields;
        
        NSString *lastModification =
        headerFields[@"Last-Modified"];
        
        NSDateFormatter *formatter =
        NSDateFormatter.new;
        
        formatter.dateFormat =
        @"EEE, dd MMM yyyy HH:mm:ss zzz";
        
        return
        [formatter
         dateFromString:lastModification];
    }
    
    return nil;
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

+(NSArray<StoreItem *> *)storeItemsAll
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
    
    NSArray *items =
    [Store.current.storeItems
     sortedArrayUsingDescriptors:@[sortDescriptorType,
                                   sortDescriptorPrice]];
    
    NSMutableArray *mItems =
    items.mutableCopy;
    
    for (StoreItem *item in items)
        if (item.isInvalid)
            [mItems
             removeObject:item];
        
    return
    mItems.copy;
}

+(NSArray<StoreItem *> *)storeItemsPurchased
{
    NSMutableArray *storeItems =
    NSMutableArray.new;
    
    for (StoreItem *storeItem in self.storeItems)
        if (storeItem.isPurchased == YES)
            [storeItems
             addObject:storeItem];
        
    return
    storeItems.copy;
}

+(NSArray <StoreItem *> *)storeItemsWithType:(StoreItemType)type
{
    NSMutableArray *storeItems =
    NSMutableArray.new;
    
    for (StoreItem *storeItem in Store.current.storeItems)
        if (storeItem.type == type &&
            storeItem.title.length)
            [storeItems
             addObject:storeItem];
    
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
            [storeItems
             addObject:storeItem];
    
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
         selector:@selector(willEnterForegroundNotification)
         name:UIApplicationWillEnterForegroundNotification
         object:nil];
        
        if (@available(iOS 13.0, *))
            [NSNotificationCenter.defaultCenter
             addObserver:self
             selector:@selector(willEnterForegroundNotification)
             name:UISceneWillEnterForegroundNotification
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

-(void)willEnterForegroundNotification
{
    NSLog(@"[INFO] Store: Application will enter foreground");
    
    if (self.url)
        [Store
         setupWithURLString:self.url.absoluteString
         completion:self.setupWithURLCompletion];
    
    else
        [self
         restoreProductsCompletion:nil];
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
        
        if (completion)
            completion([NSError
                        errorWithDomain:@"Store"
                        code:-1
                        userInfo:@{NSLocalizedDescriptionKey:@"Loading products failed. Store setup is not completed, shared secret or idientifiers is empty!"}]);
        
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
            for (SKProduct *product in self.products)
                for (StoreItem *s in self.storeItems)
                    if ([s.identifier
                         isEqualToString:product.productIdentifier])
                        s.product = product;

            return
            [self refreshReceipt];
        }

        self.products = nil;
    }

//    [self.restoreQueue
//     restoreCompletedTransactions];
    
    self.productsRequest =
    [SKProductsRequest.alloc
     initWithProductIdentifiers:productIdentifiers];

    self.productsRequest.delegate = self;

    [self.productsRequest start];
}

#pragma mark - Product Restore Delegate

-(void)productsRequest:(SKProductsRequest  *)request
    didReceiveResponse:(SKProductsResponse *)response
{
    NSLog (@"[INFO] Store: Product list loading finished");
    
    if (response.invalidProductIdentifiers.count)
    {
        NSLog (@"[ERROR] Store: Ignore invalid identifiers: %@",
               response.invalidProductIdentifiers);
        
        for (NSString *invalidProductIdentifier in response.invalidProductIdentifiers)
            for (StoreItem *s in self.storeItems)
                if ([s.identifier
                     isEqualToString:invalidProductIdentifier])
                    s.isInvalid =
                    YES;
    }

    self.products =
    response.products;
    
    for (SKProduct *product in self.products)
        for (StoreItem *s in self.storeItems)
            if ([s.identifier
                 isEqualToString:product.productIdentifier])
                s.product = product;
    
    [self
     refreshReceipt];
}

-(void)paymentQueue:(nonnull                  SKPaymentQueue *)queue
updatedTransactions:(nonnull NSArray<SKPaymentTransaction *> *)transactions
{
    for (SKPaymentTransaction *transaction in transactions)
    {
        switch (transaction.transactionState)
        {
            case SKPaymentTransactionStateFailed:
                break;
                
            case SKPaymentTransactionStateRestored:
            {
                [queue
                 finishTransaction:transaction];
                
                break;
            }

            case SKPaymentTransactionStatePurchased:
                break;
                
            case SKPaymentTransactionStatePurchasing:
            case SKPaymentTransactionStateDeferred:
            default:
                break;
        }
    }
}

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

    BOOL sandbox =
    Store.current.isSandbox;
    
    NSLog(@"[INFO] Store: Receipt setup (sandbox = %@)",
          sandbox ? @"YES" : @"NO");
    
    // create the JSON object that describes the request
    NSDictionary *requestContents =
    @{@"receipt-data":[receipt
                       base64EncodedStringWithOptions:0],
      @"password":self.sharedSecret};

    NSError *error = nil;
    
    NSData *requestData =
    [NSJSONSerialization
     dataWithJSONObject:requestContents
     options:0
     error:&error];
    
    if (error || !requestData)
    {
         NSLog(@"[ERROR] Store: %@",
               error.localizedDescription);
        
        [self
         returnCompletionsWithError:error];
        
        return;
    }
    
    // create a POST request with the receipt data.
    NSURL *storeURL =
    [NSURL
     URLWithString:@"https://buy.itunes.apple.com/verifyReceipt"];
    
    if (sandbox)
        storeURL =
        [NSURL
         URLWithString:@"https://sandbox.itunes.apple.com/verifyReceipt"];
    
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
                
                [self
                 returnCompletionsWithError:error];
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
                
                [self
                 returnCompletionsWithError:error];
            });
            
            return;
        }
        
        NSLog(@"[INFO] Store: jsonResponse:%@",
              jsonResponse);
        
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
        
        NSError *receiptError = nil;
        
        if ([jsonResponse[@"status"] integerValue] == 21000)
            receiptError =
            [NSError
             errorWithDomain:@"Store"
             code:-1
             userInfo:@{NSLocalizedDescriptionKey:@"The App Store could not read the JSON object you provided."}];
        
        if ([jsonResponse[@"status"] integerValue] == 21002)
            receiptError =
            [NSError
             errorWithDomain:@"Store"
             code:-1
             userInfo:@{NSLocalizedDescriptionKey:@"The data in the receipt-data property was malformed or missing."}];
        
        if ([jsonResponse[@"status"] integerValue] == 21003)
            receiptError =
            [NSError
             errorWithDomain:@"Store"
             code:-1
             userInfo:@{NSLocalizedDescriptionKey:@"The receipt could not be authenticated."}];
        
        if ([jsonResponse[@"status"] integerValue] == 21004)
            receiptError =
            [NSError
             errorWithDomain:@"Store"
             code:-1
             userInfo:@{NSLocalizedDescriptionKey:@"The shared secret you provided does not match the shared secret on file for your account."}];
        
        if ([jsonResponse[@"status"] integerValue] == 21005)
            receiptError =
            [NSError
             errorWithDomain:@"Store"
             code:-1
             userInfo:@{NSLocalizedDescriptionKey:@"The receipt server is not currently available."}];
        
        if ([jsonResponse[@"status"] integerValue] == 21006)
            receiptError =
            [NSError
             errorWithDomain:@"Store"
             code:-1
             userInfo:@{NSLocalizedDescriptionKey:@"This receipt is valid but the subscription has expired. When this status code is returned to your server, the receipt data is also decoded and returned as part of the response. Only returned for iOS 6 style transaction receipts for auto-renewable subscriptions."}];
        
        if ([jsonResponse[@"status"] integerValue] == 21007)
        {
            Store.current.isSandbox = YES;
            
            // Resend receipt to sandbox with no error
            [self
             encryptReceipt];
            
            return;
        }
        
        if ([jsonResponse[@"status"] integerValue] == 21008)
            receiptError =
            [NSError
             errorWithDomain:@"Store"
             code:-1
             userInfo:@{NSLocalizedDescriptionKey:@"This receipt is from the production environment, but it was sent to the test environment for verification. Send it to the production environment instead."}];
        
        if ([jsonResponse[@"status"] integerValue] == 21010)
            receiptError =
            [NSError
             errorWithDomain:@"Store"
             code:-1
             userInfo:@{NSLocalizedDescriptionKey:@"This receipt could not be authorized. Treat this the same as if a purchase was never made."}];
        
        if ([jsonResponse[@"status"] integerValue] >= 21100 &&
            [jsonResponse[@"status"] integerValue] <= 21199)
            receiptError =
            [NSError
             errorWithDomain:@"Store"
             code:-1
             userInfo:@{NSLocalizedDescriptionKey:@"Internal data access error."}];
        
        if (!receiptError &&
            ![jsonResponse[@"receipt"][@"bundle_id"] isEqualToString:NSBundle.mainBundle.bundleIdentifier])
            receiptError =
            [NSError
             errorWithDomain:@"Store"
             code:-1
             userInfo:@{NSLocalizedDescriptionKey:@"Bundle is incorrected."}];
        
        if (receiptError)
        {
            dispatch_async(dispatch_get_main_queue(), ^(void)
            {
                NSLog(@"[ERROR] Store: %@",
                      receiptError.localizedDescription);
                
                [self
                 returnCompletionsWithError:receiptError];
                
                [NSException
                 raise:@"Store"
                 format:@"%@", receiptError.localizedDescription];
            });
            
            return;
        }
                
        self.purchasedVersion =
        jsonResponse[@"receipt"][@"original_application_version"];
        
        NSDateFormatter *formatter =
        NSDateFormatter.new;
        
        formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss VV";
        
        self.purchasedDate =
        [formatter
         dateFromString:jsonResponse[@"receipt"][@"original_purchase_date"]];
        
        NSTimeInterval requestDateMs =
        [jsonResponse[@"receipt"][@"request_date_ms"]
         integerValue];
        
        //NSLog(@"jsonRECEIPTResponse:%@", jsonResponse[@"receipt"]);
        
        NSMutableDictionary <NSString *, NSDictionary *> *receipts =
        NSMutableDictionary.new;
        
        NSArray *receiptInApp =
        jsonResponse[@"receipt"][@"in_app"];
        
        for (StoreItem *storeItem in self.storeItems)
        {
            NSDictionary *lastReceipt = nil;
            
            for (NSDictionary *receipt in receiptInApp)
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
             dateWithTimeIntervalSince1970:[reciept[@"purchase_date_ms"] integerValue] / 1000.];
            
            if (reciept[@"expires_date_ms"])
                storeItem.endDate =
                [NSDate
                 dateWithTimeIntervalSince1970:[reciept[@"expires_date_ms"] integerValue] / 1000.];
            
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
    return
    [Store isLockWithController:controller
                           rule:0];
}

+(BOOL)isLockWithController:(UIViewController *)controller
                       rule:(NSInteger         )rule
{
    if (Store.current.lockRules)
        return
        Store.current.lockRules(controller, rule);
    
    return NO;
}

@end
