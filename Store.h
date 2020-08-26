//
//  Store.h
//  Version 2.5
//
//  Created by Сергей Ваничкин on 10/23/18.
//  Copyright © 2018 👽 Technology. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
//
/*///////////////////////////////////////////////////////////////////
 
 Класс для встроенных покупок позволяет:
 
    1. Автоматически отслеживать изменения чека (при выходе/входе в приложение);
    2. Упростить показ PayWall контроллера;
    3. Задать правила и логику проверки в одном месте а не по всем контроллерам как в обычных классах;
    4. Указать бесплатные периоды, например если приложение перешло на встроенные покупки с версии 2.0;
    5. Упростить проверки купленных продуктов.
 
 Максимально упрощено любое обращение с покупками, настолько, насколько это вообще возможно.
 Класс имеет лишь один метод инициализации, после чего им можно полноценно пользоваться.
 Второй метод для настройки логики и правил, убирает 90% кода из контроллеров.
 
 ////////////////////////////////////////////////////////////////////
 
 Инициализация покупок:
 
 #define MONEY @"com.purchase.money"
 #define MONTH @"com.purchase.month"
 
 #define PURCHASES @[MONEY.storeItem.consumable,\
                     MONTH.storeItem.autoRenewableSubscription]

 Для чего нужны идентификаторы с обращением к NSString.storeItem?
 
 1. Для инициализации;
 2. Для обращения к покупке через без длинных конструкций поиска или обращения к классам;
 3. Для простого добавления в шаблоны страниц покупок.
 
 Обращение к покупке может осуществляться через идентификатор, например так:
 
 StoreItem *money = @"com.purchase.money".storeItem;
 or
 StoreItem *money = MONEY.storeItem;
 
 В результате будет создан новый либо найден уже имеющийся StoreItem
 
 Например нам необходимо получить название покупки для вставки в кнопку мы можем сделать так:
 
 NSString *title = @"com.purchase.money".storeItem.title;
 or
 NSString *title = MONEY.storeItem.title;
 
 И далее назначить title кнопке...
 
 ////////////////////////////////////////////////////////////////////

 Инициализация класса:
 
 [Store
  setupWithSharedSecret:@"shared secret key fot inapp"
  storeItems:PURCHASES
  completion:^(NSError *error)
 {
     // Сразу после инициализации можем показать PayWall контроллер со споском покупок
     if (Store.storeItemsPurchased.count == 0)
         [self.window.rootViewController
          presentViewController:myPayWallContoller
          animated:YES
          completion:nil];
 }];

 Во время инициализации, класс делает несколько вещей.
 Первое это проверяет список переданных в него покупок, загрузжает их и инициализирует записи названия и стоимости.
 Затем класс проверяет чек на устройстве и устанавливает дату покупки приложения, его версию.
 После этого проверяет полученные покупки в чеке и если в чеке есть купленные продукты он отмечает это.
 Все неверные идентификаторы игнорируются.
 После всех проверок, класс либо возвращает ошибку либо вызывает completion без ошибки.
 В блоке completion можно указать логику для показа PayWall т.е. контроллера со списком покупок / подписок.
 
 ////////////////////////////////////////////////////////////////////
 
 Работа с покупками:
 
 После того как создан список покупок и произведена инициализация класса, мы уже можем работать с покупками.
 Проверять куплена ли она, и если нет, то покупать ее.
 
 if (!MONTH.storeItem.isPurchased)
     [MONTH.storeItem
      purchaseWithCompletion:nil];
 
 Так же можно получить весь список купленных покупок, например так:
 
 if (Store.storeItemsPurchased.count == 0)
     [MONTH.storeItem
      purchaseWithCompletion:nil];
 
 Или получить конкретный список по типу:
 
 NSArray <StoreItem *> *consumable =
 [Store
  storeItemsWithType:StoreItemTypeConsumable];
 
 if (consumable.count == 0)
     [MONTH.storeItem
      purchaseWithCompletion:nil];

 Но делать такие проверки в различных контроллерах не совсем хорошо, лучше держать все проверки в одном месте.
 И этот класс позволяет это сделать, задав правила в одном месте.
 
 ////////////////////////////////////////////////////////////////////
 
 Задаем правила:

 Правила необохдимы, для того что бы не размещать логику проверки покупок по разным контроллерам.
 Все правила в одном месте легче посмотреть и изменить если требуется, не нужно искать по разным местам.
 
 [Store
  setLockRules:^(UIViewController *controller)
 {
     NSArray <StoreItem *> *consumable =
     [Store
      storeItemsWithType:StoreItemTypeConsumable]; // получаем список покупок "consumable"
 
     if (consumable.count == 0); // если покупки нет
     {
         [controller
          presentViewController:myPayWallContoller // покажем контроллер для предложния купить
          animated:YES
          completion:nil];

         return YES; // говорим, что правила вернули Lock
     }
    
     else // если покупка есть
     [consumable.firstObject
      consumablePurchaseReset]; // потратим покупку
 
     return NO; // говорим, что правила вернули UnLock
 }];
 
 ////////////////////////////////////////////////////////////////////
 
 Работа с правилами:
 
 Теперь в месте где необходимо потратить (или показать окно покупок, если ни одной нет) достаточно проверить

 -(BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier
                                  sender:(id        )sender
 {
     return
     ![Store
       isLockWithController:self];
 }

 В данном случае при переходе к странице по segue произойдет проверка указанная в блоке setLockRules:
 Затем по описанию указанных в правилах, consumable покупка будет потрачена isLockWithController: вернет YES
 Либо если в правилах покупка не будет найдена, вернется NO и будет показан контроллер myPayWallContoller
 isLockWithController: возвращает значение YES/NO, на основе return из setLockRules:
 
 ////////////////////////////////////////////////////////////////////
 
 Работа с переходом от продаж к inn-app:
 
 Если ваше приложение было платным и вы переходите на inn-app покупки.
 Например версия 1.0 продавалась прямо в AppStore, а теперь с версии 2.0 бесплатна, но внутри in-app.
 
 Для этого нужно выбрать одну из покупок, и указать ее как "куплена" для периода с 1.0 по 2.0.
 
 [@"com.purchase.month".storeItem
  setAsPurchasedForRanges:@[@"1.0"]];
 or
 [@"com.purchase.month".storeItem
  setAsPurchasedForRanges:@[@"1.0-1.9"]]; // включительно
 or
 [MONTH.storeItem
  setAsPurchasedForRanges:@[@"01/01/2020-12/31/2020"]]; // включительно
 
 Теперь покупка будет считаться приобретенной для указанного периода.
 
 ////////////////////////////////////////////////////////////////////
 
 Дополнительные фичи, настройка по URL из конфига:
 
 +(void)setupWithURLString:(NSString        *)urlString
                completion:(RestoreCompletion)completion;
 
 Метод подтягивает такой конфиг в формате JSON:
 
 {
    "sharedSecred":"shared secret key fot inapp",
    "identifiers":
    [
        {
            "identifier":"com.purchase.money",
            "type":"consumable"
        },
 
        {
            "identifier":"com.purchase.month",
            "type":"autoRenewableSubscription"
        },
 
        {
            "identifier":"com.purchase.subscripe.week",
            "type":"nonRenewingSubscriptionWeek"
        },
 
        {
            "identifier":"com.purchase.unlimited",
            "type":"nonConsumable",
            "asPurchasedForRanges":
            [
                "1.0",
                "2.0-2.9",
                "1/1/2020-12/31/2020"
            ]
        }
    ]
 }
 
*/

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

// Есть ли на сервере покупка с данным айдишником
@property (nonatomic, assign, readonly) BOOL             isInvalid;

@property (nonatomic, assign, readonly) BOOL             isPurchased;

@property (nonatomic, strong, readonly) NSString                 *transactionId;
@property (nonatomic, assign, readonly) SKPaymentTransactionState transactionState;

// Устанавливает значение количества единиц которые будут
// инкрементированы после приобретения данной одноразовой покупки (например +100 монет)
@property (nonatomic, strong) NSNumber *defaultConsumableCount;

// Количество оставшихся единиц в одноразовой покупке (например 83 монеты)
@property (nonatomic, strong, readonly) NSNumber *consumableCount;

// После того как одноразовая покупка использована, необходимо делать сброс (например -1 монета)
-(void)consumablePurchaseDecrease;
-(void)consumablePurchaseDecreaseCount:(NSNumber *)decreaseCount;

// Делает покупку приобретенной, на определенный период или несколько приодов
-(void)setAsPurchasedForRanges:(NSArray <NSString *> *)ranges;
//   определенная дата: @"12/31/2020"
//        диапазон дат: @"1/1/2020-12/31/2020" (включительно)
// определенная версия: @"3.0.1"
//     диапазон версий: @"1.0-3.0.1" (включительно)

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

// Валидация через конфиг с сервера (конфиг кешируется и перепроверяется иногда)
+(void)setupWithURLString:(NSString        *)urlString
               completion:(RestoreCompletion)completion;

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
+(NSArray <StoreItem *> *)storeItemsAll; // Включающие в себя покупки со статусом invalid
+(NSArray <StoreItem *> *)storeItems;    // Только валидные покупки
+(NSArray <StoreItem *> *)storeItemsPurchased;
+(NSArray <StoreItem *> *)storeItemsWithType:(StoreItemType)type;
+(NSArray <StoreItem *> *)storeItemsPurchasedWithType:(StoreItemType)type;

// Дата когда юзер в самый первый раз поставил (купил) апку из стора и ее версия на тот момент
+(NSDate   *)firstInstallDate;
+(NSString *)firstInstallAppVersion;

// Здесь описываются проверки, при которых требуется например показать определенное окно с покупками. Эти проверки будут выполнены, когда будет вызван метод isLockWithController:
+(void)setLockRules:(LockRules)lockRules;
+(BOOL)isLockWithController:(UIViewController *)controller; // Контроллер в котором желательно показать окно покупок
+(BOOL)isLockWithController:(UIViewController *)controller  // Если требуется проверка по определенному правилу,
                       rule:(NSInteger         )rule;       // передаем номер этого правила

@end
