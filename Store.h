//
//  Store.h
//  Version 1.9
//
//  Created by Сергей Ваничкин on 10/23/18.
//  Copyright © 2018 👽 Technology. All rights reserved.
//
//
//  Класс сам следит за тем что приложение выгрузилось или загрузилось, делает все необходимые действия
//  Когда класс загрузил покупки, сделал восстановление покупок и проверил их актуальность на сервере эпл, свойство isReady станет YES
//
//
//  Инициализация в AppDelegate:
//
//  -(BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary  *)launchOptions
//  {
//      [Store
//       setupWithSharedSecret:@"shared secret key fot inapp"
//       storeItems:@[@"com.purchase.money".storeItem.consumable, @"com.purchase.month".storeItem.autoRenewableSubscription]
//       completion:^(NSError *error)
//      {
//          if (error)
//              return;
//
//          if (Store.storeItemsPurchased.count == 0)
//              [self.window.rootViewController
//               presentViewController:StoreViewController.newFromStoryboard
//               animated:YES
//               completion:nil];
//      }];
//
//      return YES;
//  }
//
//
//  Для чего нужны идентификаторы с обращением к NSString.storeItem?
//
//  1. Для инициализации, как описано выше;
//  2. Для обращения к покупке через идентификатор, минуя длинные конструкции поиска или обращения к классам;
//  3. Для простого добавления в шаблоны страниц покупок.
//
//  Обращение к покупке может осуществляться через идентификатор, например:
//
//  StoreItem *money = @"com.purchase.money".storeItem;
//
//  В результате будет создан новый либо найден уже имеющийся StoreItem
//
//  Например нам необходимо получить название покупки для вставки в кнопку мы можем сделать так:
//
//  NSString *title = @"com.purchase.money".storeItem.title;
//
//  И далее назначить title кнопке
//
//
//  Обычно используется какое то окно для показа списка покупок, например у нас есть готовый шаблон в сторибоарде, тогда
//  можно создать правило, в каких случаях необходимо это окно показать (или например несколько разных окон, или же
//  создать несколько разных условий).
//
//  [Store setLockRules:^(UIViewController *controller)
//  {
//      // Например consumable покупка
//      NSArray <StoreItem *> *consumable =
//      [Store storeItemsWithType:StoreItemTypeConsumable];
//
//      if (consumable.count == 0); // если ее нет, покажем окно с покупкой
//      {
//          [controller
//           presentViewController:MyStoreController
//           animated:YES
//           completion:nil];
//
//          return YES; // блокировка
//      }
//
//      else // Если есть, потратим ее
//          [consumable.firstObject consumablePurchaseReset];
//
//      return NO; // нет блокировки
//  }];
//
//  В месте где необходимо потратить (или показать окно покупок, если ни одной нет) достаточно добавить код:
//
//  -(BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
//  {
//      return
//      ![Store isLockWithController:self];
//  }
//
//  В данном случае при переходе к странице произойдет проверка указанная в блоке setLockRules: и будет потрачена
//  одна consumable покупка и юзер перейдет по shouldPerformSegueWithIdentifier:, либо перехода не будет, а вместо
//  него будет показан контроллер MyStoreController, из блока setRules
//
//  isLockWithController: возвращает значение YES/NO, на основе return из setLockRules:
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

@class StoreItem;

#define STORE_MANAGER_CHANGED @"StoreManagerChanged"

typedef enum
{
    StoreItemTypeUnknown,
    StoreItemTypeConsumable,
    StoreItemTypeNonConsumable,
    StoreItemTypeAutoRenewableSubscription,
    StoreItemTypeNonRenewingSubscription
}StoreItemType;

typedef enum
{
    StoreItemPeriodNone,
    StoreItemPeriodWeek,
    StoreItemPeriodMonth,
    StoreItemPeriodYear,
}StoreItemPeriod;

typedef void(^PurchaseCompletion)(NSError *error);

#pragma mark - Store Item Category

@interface NSString (StoreItem)

// Ищет Store Item в имеющихся, по identifier, если не находит создает новый
-(StoreItem *)storeItem;

@end

#pragma mark - Store Item

@interface StoreItem : NSObject

@property (nonatomic, strong, readonly) NSString        *identifier;
@property (nonatomic, assign, readonly) StoreItemType    type;
@property (nonatomic, assign, readonly) StoreItemPeriod  period;

@property (nonatomic, strong, readonly) NSString        *title;
@property (nonatomic, strong, readonly) NSString        *titleWithPrice;
@property (nonatomic, strong, readonly) NSString        *detail;

@property (nonatomic, strong, readonly) NSNumber        *priceNumber;
@property (nonatomic, strong, readonly) NSString        *priceString;

@property (nonatomic, strong, readonly) NSString        *currencyCode;   // USD
@property (nonatomic, strong, readonly) NSString        *currencySymbol; // $

// Дополнительный расчет, сколько примерно в неделю и в месяц выйдет для юзера эта покупка
@property (nonatomic, strong, readonly) NSString        *pricePerWeekString;
@property (nonatomic, strong, readonly) NSString        *pricePerMonthString;

// Совершает покупку, либо восстанавливает
-(void)purchaseWithCompletion:(PurchaseCompletion)completion;

@property (nonatomic, assign, readonly) BOOL             isPurchased;

@property (nonatomic, strong, readonly) NSString                 *transactionId;
@property (nonatomic, assign, readonly) SKPaymentTransactionState transactionState;

// После того как одноразовая покупка использована, необходимо делать сброс
-(void)consumablePurchaseReset;

// Время действия покупки
@property (nonatomic, strong, readonly) NSDate          *startDate;
@property (nonatomic, strong, readonly) NSDate          *endDate;
@property (nonatomic, assign, readonly) BOOL             isTrial;

// Устанавливает тип для Store Item, затем возвращает этот Store Item
-(StoreItem *)consumable;
-(StoreItem *)nonConsumable;
-(StoreItem *)autoRenewableSubscription;
-(StoreItem *)nonRenewingSubscriptionWeek;
-(StoreItem *)nonRenewingSubscriptionMonth;
-(StoreItem *)nonRenewingSubscriptionYear;

@end

#pragma mark - Store Manager

typedef void(^RestoreCompletion)(NSError *error);

typedef BOOL(^LockRules)(UIViewController *controller, NSInteger rule);

@interface Store : NSObject

// Ключ для валидации чека на сервере эпл (берется из кабинета встроенных покупок)
+(void)setupWithSharedSecret:(NSString              *)sharedSecret
                  storeItems:(NSArray <StoreItem *> *)storeItems // @[@"com.purchase.year".storeItem.consumable]
                  completion:(RestoreCompletion      )completion;

// Если isReady по каким то причинам NO, нужно еще раз произвести восстановление покупок
+(void)restoreWithCompletion:(RestoreCompletion)completion;

// Создает покупку либо находит в имеющихся
+(StoreItem *)storeItemWithIdentifier:(NSString *)identifier;

+(BOOL)isReady;
+(BOOL)isSandbox;

// Выдает имеющиеся StoreItems, и приобретенные и с определенным типом
+(NSArray <StoreItem *> *)storeItems;
+(NSArray <StoreItem *> *)storeItemsPurchased;
+(NSArray <StoreItem *> *)storeItemsWithType:(StoreItemType)type;
+(NSArray <StoreItem *> *)storeItemsPurchasedWithType:(StoreItemType)type;

// Дата когда юзер в самый первый раз поставил (купил) апку из стора и ее версия на тот момент
+(NSDate   *)firstInstallDate;
+(NSString *)firstInstallAppVersion;

// Сравнение с датой или версией
+(BOOL)firstInstallDateIsOlderDate:(NSDate   *)date;
+(BOOL)firstInstallIsOlderVersion: (NSString *)version;

// Здесь описываются проверки, при которых требуется например показать определенное окно с покупками. Эти проверки будут выполнены, когда будет вызван метод isLockWithController:
+(void)setLockRules:(LockRules)lockRules;
+(BOOL)isLockWithController:(UIViewController *)controller; // Конторллер в котором желательно показать окно покупок
+(BOOL)isLockWithController:(UIViewController *)controller  // Если требуется проверка по определенному правилу,
                       rule:(NSInteger         )rule;       // передаем номер этого правила

@end
