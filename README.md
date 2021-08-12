# Store
A simple but unusually powerful class for working with all types of in-app purchases (consumable, nonConsumable, autoRenewable, nonRenewing).

The class itself ensures that the application is unloaded or loaded, does all the necessary actions.
When the class has downloaded the purchases, made the recovery of purchases and checked their relevance on the server Apple, the isReady property will become YES.

Initialization in AppDelegate:

```
  -(BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary  *)launchOptions
  {
      [Store
       setupWithSharedSecret:@"shared secret key fot inapp"
       storeItems:@[@"com.purchase.money".storeItem.consumable, @"com.purchase.month".storeItem.autoRenewableSubscription]
       completion:^(NSError *error)
      {
          if (error)
              return;

          if (Store.storeItemsPurchased.count == 0)
              [self.window.rootViewController
               presentViewController:MyStoreController
               animated:YES
               completion:nil];
      }];

      return YES;
  }

```

What are identifiers with access to NSString.storeItem for?

1. For initialization, as described above;
2. To access a purchase through an identifier, bypassing the long constructions of a search or access to classes;
3. To easily add shopping pages to templates.

A call to a purchase can be made through an identifier, for example:
```
NSString *title = @"com.purchase.money".storeItem.title;
```
And then assign a title to the UIButton...

Usually some window is used to display the shopping list, for example, we have a ready-made template in the storyboard, then you can create a rule in which cases you need to show this window (or for example several different windows, or create several different conditions).

```
  [Store setLockRules:^(UIViewController *controller)
  {
      // For example consumable purchase
      NSArray <StoreItem *> *consumable =
      [Store storeItemsWithType:StoreItemTypeConsumable];

      if (consumable.count == 0); // if not consumable purchase, show store controller
      {
          [controller
           presentViewController:MyStoreController
           animated:YES
           completion:nil];

          return YES; // lock
      }

      else // If there is, we will spend it
          [consumable.firstObject consumablePurchaseReset];

      return NO; // no lock
  }];
```

In the place where you need to spend (or show the shopping window, if not one), just add the code:
```
  -(BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
  {
      return
      ![Store isLockWithController:self];
  }
```
In this case, when you go to the page, the check specified in the setLockRules block is performed: it will be spent one consumable purchase and the user will follow shouldPerformSegueWithIdentifier: either there will be no transition, and instead the MyStoreController controller will be shown, from the setRules block.

isLockWithController: returns YES / NO, based on return from setLockRules:

You can also protect the application from hacking, by transferring check check to your server. Or such a service allow you to do this, such as Apphud. In this method, you can safely cause a synchronous request or asynchronous. For instance:
```
  [Store checkRawReceiptString:^NSDictionary *(BOOL sandbox)
  {
      __block NSDictionary *rawJSON = nil;
    
      dispatch_semaphore_t sem =
      dispatch_semaphore_create(0);
    
      [Apphud fetchRawReceiptInfo:^(ApphudReceipt *receipt)
      {
          rawJSON =
          receipt.rawJSON;
        
          dispatch_semaphore_signal(sem);
      }];
    
      dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    
      return rawJSON;
  }];
```
