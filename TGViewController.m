//
//  TGViewController.m
//  SpO2 strongly based on TgForce App.
//
//  Created by Gerald Plamondon on 2016-02-26
//  Copyright (c) 2016 Kelsec Systems Inc. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import "TGViewController.h"



//#define debug 1

@interface TGViewController ()

@property (nonatomic, strong) ShinobiChart *chart;
@property (nonatomic,strong) AVAudioPlayer *player;


//Core bluetooth
@property (nonatomic, strong) CBPeripheral *tgforcePeripheral;
//@property (nonatomic, strong) CBCharacteristic *gThresholdChar;  //needed for writing to it
//@property (nonatomic, strong) CBCharacteristic *delayChar;  //needed for writing to it
@property (nonatomic, strong) NSMutableArray *discoveredPeripheral;

@property NSInteger currentDataIndex;
@property NSInteger receivedDataIndex;
@property (nonatomic, strong)   NSTimer *timer;
@property (nonatomic, strong)   NSMutableArray *streamedData;
@property (nonatomic, strong)   NSMutableArray *gMaxDataForDisplay;
@property (nonatomic, strong)   NSURL *musicFile;

@property int totalStep;
@property double totalPPA;
@property double averagePPA;
@property double realTimePPA;

@property double totalCadence;
@property double averageCadence;
@property int totalCadenceStep;
@property int cadenceLevel;

@property int SPo2StatusValue;


@property NSDate *stopSliderTouchTime; //record the time when user stop a session

@property int realTimeGraphic;

@property int feedbackSoundType;
@property BOOL  audioFeedbackStatus;

@property BOOL gMaxNotificationStatus;
@property float gMaxValue;

//stopWatch
@property (nonatomic, strong) NSTimer *stopTimer;
@property (nonatomic, strong) NSDate *startDate;
@property (nonatomic) BOOL stopWatchRunning;


//spo2 ui
@property (strong, nonatomic) IBOutlet UILabel *okStatusLabel;
@property (strong, nonatomic) IBOutlet UILabel *snsdLabel;
@property (strong, nonatomic) IBOutlet UILabel *ootLabel;
@property (strong, nonatomic) IBOutlet UILabel *lprfLabel;
@property (strong, nonatomic) IBOutlet UILabel *mprfLabel;
@property (strong, nonatomic) IBOutlet UILabel *artfLabel;



-(void) updateStopWatch;

//spo2
-(void)updateFirebase;


-(void)tryConnectingWithUUIDfromUserDefaults;
-(void)setDisplayDisconnected;
//-(void)playSound;
-(void)resetCalcDisplay;
-(void)displayAlertMessage:(NSString *)alertMessage;
//-(void)updateOperatingCharacteristics;

-(void)bluetoothCleanup;

// Instance method to get the PPA information
- (void) getPPAImpactData:(CBCharacteristic *)characteristic error:(NSError *)error;
// Instance method to get the BatteryLevel information
- (void) getBatteryLevelData:(CBCharacteristic *)characteristic error:(NSError *)error;
// Instance method to grab device Manufacturer Name,
- (void) getManufacturerName:(CBCharacteristic *)characteristic;
// instance method to get spo2 device serial number
- (void) getSerialNumber:(CBCharacteristic *)characteristic;
//- (void) getgThreshold:(CBCharacteristic *)characteristic error:(NSError *)error;
// Instance method to perform  animations
- (void) doAnimation;

// Properties to hold data characteristics for the peripheral device
@property (nonatomic, strong) NSString   *connected;
@property (nonatomic, strong) NSString   *manufacturer;
@property (nonatomic, strong) NSString   *serialNumber;

@property (nonatomic, strong) NSString   *gThresholdData;

@property (nonatomic, strong) NSString   *tgForceDeviceData;
@property (nonatomic, strong) NSString   *batteryLevelData;
@property float ppaLevel;
@property uint8_t batLevel;
@property uint8_t gThLevel;

// Properties to handle storing the tgforce PPA level
@property (nonatomic, strong) UILabel    *tgForcePPA;
@property (nonatomic, strong) NSTimer    *pulseTimer;



@end

@implementation TGViewController


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}


- (BOOL)shouldAutorotate {
    NSLog(@"Running %@ '%@'", self.class, NSStringFromSelector(_cmd));
    return NO;
}



- (void)viewDidLoad
{
    [super viewDidLoad];
    //NSLog(@"viewDidLoad");
    //Initialize Core Bluetooth LE Central manager
    //This will start BLE but we must wait to receive delegate method saying is is ready before doing anything -
    //check delegate method centralManagerDidUpdateState for subsequent actions
    CBCentralManager *centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    
    //from web tutorial
    self.centralManager = centralManager;
    
    //initialize array for discovering peripheral
    _discoveredPeripheral = [[NSMutableArray alloc]init];
    
    //initialize array containing dataModel object
    //self.stepDataSetArray = [[NSMutableArray alloc]init];
    
    
    
    //This is for making status tool bar on top with white letters instead of black
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
    //Note that you'll also need to set UIViewControllerBasedStatusBarAppearance to NO in the plist file if you use this method.
    
    _totalStep = 0;
    _totalPPA = 0;
    _averagePPA = 0;
    
    //shinobi stuff here below
    // Create the chart
    self.chart = [[ShinobiChart alloc] initWithFrame:CGRectInset(self.view2.bounds, 0, 0)];
    
    self.chart.autoresizingMask = ~UIViewAutoresizingNone;
    
    //premium licence needed
    self.chart.licenseKey = SHINOBI_LICENCE;
    
    // Use a number axis for the x axis.
    self.chart.xAxis = [[SChartNumberAxis alloc] init];
    self.chart.xAxis.style.gridStripeStyle.showGridStripes = false;
    self.chart.xAxis.style.majorTickStyle.showLabels = false;
    
    //CONFIGURE Y AXIS
    NSNumber *yMinimum = [[NSNumber alloc]initWithInt:87];
    NSNumber *yMaximum = [[NSNumber alloc]initWithInt:101];
    SChartRange *yRange = [[SChartRange alloc]initWithMinimum:yMinimum andMaximum:yMaximum];
    
    // Use a number axis for the y axis.
    self.chart.yAxis = [[SChartNumberAxis alloc] initWithRange:(SChartNumberRange*)yRange];
    self.chart.yAxis.style.majorTickStyle.labelFont = [UIFont fontWithName:@"Helvetica-Bold" size:18];
    self.chart.yAxis.style.majorTickStyle.labelColor = [UIColor purpleColor];
    self.chart.yAxis.majorTickFrequency = [[NSNumber alloc]initWithInt:(2)];
    //self.chart.yAxis.style.titleStyle.font =[UIFont fontWithName:@"Helvetica Neue" size:25];
    //self.chart.yAxis.title = [[NSString alloc]initWithString:@("g")];
    
    self.chart.datasource = self;
    
    //animation
    
    
    //add subview that will contain chart object
    [self.view addSubview:self.view2];
    
    // Add the chart to the view controller
    [self.view2 addSubview:self.chart];
    
    // Initialize our data
    // We  going negative to display the data on the chart from the left - otherwise new data would be displayed on the right.
    self.streamedData = [NSMutableArray array];
    //for (int i = 0; i > -20; --i)  {
    for (int i = 0; i > -10; --i)  {
        [_streamedData addObject:[self dataPointWithIndex:i]];
    }
    _receivedDataIndex = 0;
    _currentDataIndex = (_streamedData.count)*-1;
    
    //THIS IS FOR DISPLAY OF A LINE INDICATING gMax value
    /*
    self.gMaxDataForDisplay = [NSMutableArray array];
    for (int i = 0; i > -20; --i)  {
        [_gMaxDataForDisplay addObject:[self gMaxdataPointWithIndex:i]];
    }
     */
    
    [self resetCalcDisplay];
    
    
	// Do any additional setup after loading the view, typically from a nib.
    self.tgForceDeviceData = nil;
    
    
    //config separator for display
    
    self.viewLine1.backgroundColor = [UIColor colorWithRed:191.f/255.f green:210.f/255.f blue:239.f/255.f alpha:1.f];

    
    //self.viewTitle.backgroundColor = [UIColor colorWithRed:34.0f/255.0f green:62.0f/255.0f blue:146.0f/255.0f alpha:1.0];
    self.viewTitle.backgroundColor = [UIColor purpleColor];
    
    //Start Button display & slider
    self.startButton.layer.cornerRadius = 9 ;
    self.startButton.layer.borderWidth =1;
    self.startButton.layer.borderColor = self.startButton.tintColor.CGColor;
    [self.startButton setHidden:NO];
    self.isRunning = NO;
    
    //stopwatch
    self.stopWatchLbl.text = @"00:00:00";
    self.stopWatchRunning = NO;
    
    //label color
    //self.avgValueLabel.textColor = [UIColor colorWithRed:108.0f/255.0f green:158.0f/255.0f blue:255.0f/255.0f alpha:1.0];
    //self.cadenceValueLabel.textColor = [UIColor colorWithRed:108.0f/255.0f green:158.0f/255.0f blue:255.0f/255.0f alpha:1.0];
    self.cadenceValueLabel.textColor = [UIColor blueColor];
    self.okStatusLabel.hidden = YES;
    

}


-(void) viewWillAppear:(BOOL)animated{
    
    //NSLog(@"Running %@ '%@'", self.class, NSStringFromSelector(_cmd));
    [super viewWillAppear:animated];
    
    //This is for making status tool bar on top with white letters instead of black
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
    //Note that you'll also need to set UIViewControllerBasedStatusBarAppearance to NO in the plist file if you use this method.    
    
     //userdefaults
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
   
    
    //int sensorStatus = (int)[userDefaults integerForKey:@"sensorStatus"];
    //NSLog(@"sensorStatus in TGVIEW:%d",sensorStatus);
    
    
    //Load from userdefaults the values needed for operation (into instance variable)
    _realTimeGraphic = (int)[userDefaults integerForKey:@"realTimeGraphic"];
    
    _feedbackSoundType = (int)[userDefaults integerForKey:@"feedbackSoundType"];
    
    _audioFeedbackStatus = [userDefaults boolForKey:@"audioFeedbackStatus"];
    
    _gMaxNotificationStatus = [userDefaults boolForKey:@"gMaxNotificationStatus"];
    
    _gMaxValue = [userDefaults floatForKey:@"gMaxValue"];

    //maybe chart type was modified so reload
    [self.chart reloadData];
    [self.chart redrawChartIncludePlotArea:YES];
    
    //Always update sensor parameters if connected
    /*

        if(_isConnected){
                    NSLog(@" WILL SET SENSOR PARAMETERS");
            //ok update operating characteristic
            [self updateOperatingCharacteristics];
            // UPDATED, UPDATE FLAG TO NO.
            [userDefaults setBool:NO forKey:@"setSensorParameters"];
            [userDefaults synchronize];
        }
     */
    
    
    //highlighted image is connected, the non-highlightedimage is disconnected
    self.bleStatusImage.highlighted = self.isConnected;
    

}


-(void) viewDidAppear:(BOOL)animated{
    
    NSLog(@"Running %@ '%@'", self.class, NSStringFromSelector(_cmd));
    [super viewDidAppear:animated];
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    int sensorStatus = (int)[userDefaults integerForKey:@"sensorStatus"];
    
    //we need to know if we are transitioning from the select sensor option of the setting view
    if(sensorStatus==1){
        //yes we just made some modification to sensor comms.
        //Disconnect the sensor, it will try to reconnect using the new uuid store in userdefaults.
        //But is it scanning?
        
        if(self.tgforcePeripheral){
            [self.centralManager cancelPeripheralConnection:self.tgforcePeripheral];
        }
        sensorStatus=0;
        [userDefaults setInteger:sensorStatus forKey:@"sensorStatus"];
        [userDefaults synchronize];
        
        //But maybe we were not connected to a sensor, need to connect to the selected sensor
        if(!_isConnected){
            NSLog(@"tryConnectingWithUUIDfromUserDefaults");
            [self tryConnectingWithUUIDfromUserDefaults];
        }
        
        
    }
    
    self.isRunning = YES;
    //start stopwatch
    if (self.stopTimer == nil) {
        self.startDate = [NSDate date];
        self.stopTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                          target:self
                                                        selector:@selector(updateStopWatch)
                                                        userInfo:nil
                                                         repeats:YES];
        
        
    }
    self.snsdLabel.textColor = [UIColor redColor];
    self.artfLabel.textColor = [UIColor redColor];
    
    
    
}

-(void) viewWillDisappear:(BOOL)animated{
    
    //NSLog(@"SessionViewWillDisappear");
    //if bluetooth scanning, maybe we should stop it here
    [_centralManager stopScan];
    
    //NSLog(@"Scanning stopped from viewWillDisappear - maybe it was not scanning");
    //[_centralManager cancelPeripheralConnection:_tgforcePeripheral];
    //[self bluetoothCleanup];
    
    //disable the whole live thing to prevent problems
    // ******** STOP AND DISCARD **********
    //NSLog(@"Stop and discard Clicked");
    //Restart everything, discard current session
    self.isRunning = NO;
    
    //stop the stopwatch
    self.stopWatchRunning = NO;
    [self.stopTimer invalidate];
    self.stopTimer = nil;
    
    //clean up stuff on the screen to show we are restarting
    //reset everything to zero
    [self resetCalcDisplay];
    //reset chart
    for(int i = 0;i<10;i++){
        [self graphPPA:(0)];
    }
    //time display should be reset also
    self.stopWatchLbl.text =[NSString stringWithFormat:@"-"];
    
    
    
    [super viewWillDisappear:animated];
    
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - BLE Tgforce helper methods

-(void)tryConnectingWithUUIDfromUserDefaults{
    
    //make sure we have uuid default value - if this is first time launch, it will be "0".
    //try connecting with sensor uuidString stored in userdefaults
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString *uuidString = [userDefaults objectForKey:@"uuidString"];
    
    if(![uuidString isEqualToString:(@"0")]){
        
        //There is a UUID in the default value - try connecting to it
        NSUUID *nsUUID = [[NSUUID UUID] initWithUUIDString:uuidString];
        
        if(_centralManager.state == CBCentralManagerStatePoweredOn){
            
            //try connecting to it:
            if(nsUUID)
            {
                NSArray *peripheralArray = [self.centralManager retrievePeripheralsWithIdentifiers:@[nsUUID]];
                
                // Check for known Peripherals
                if([peripheralArray count] > 0)
                {
                    for(CBPeripheral *peripheral in peripheralArray)
                    {
                        //NSLog(@"Connecting to Peripheral - %@", peripheral);
                        
                        [self.centralManager connectPeripheral:peripheral options:nil];
                        self.tgforcePeripheral = peripheral;
                    }
                }
                // There are no known Peripherals so we should check for connected Peripherals if any (apple rec)
                else{
                }
            }
        }
    }
}

-(void)setDisplayDisconnected{
    
}


#pragma mark - CBCentralManagerDelegate
// method called whenever the device state changes.
// we must wait that this method been called before looking for peripheral.

//TODO: handle results from all scenarios:
- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    // Determine the state of the peripheral
    if ([central state] == CBCentralManagerStatePoweredOff) {
        //ios is taking care of this scenario by asking user to switch bluetooth on
        NSLog(@"CoreBluetooth BLE hardware is powered off");
                [self displayAlertMessage:@"CoreBluetooth BLE hardware is powered off"];
    }
    else if ([central state] == CBCentralManagerStatePoweredOn) {
        //NSLog(@"CoreBluetooth BLE hardware is powered on and ready");
        
        
        //if this is first Launch - start scanning. if not try connecting directly with stored uuid
        //check if we have uuid default value - if this is first time launch, it will be "0".
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        NSString *uuidString = [userDefaults objectForKey:@"uuidString"];
        
        if([uuidString isEqualToString:(@"0")]){
            //UUID not set in default value - first launch
            //NSLog(@"scanForPeripheralsWithServices:service");
            //create array for containing uuid of info & tgforce services
            NSArray *service = @[[CBUUID UUIDWithString:TGFORCE_RUNNING_DEVICE_INFO_SERVICE_UUID],[CBUUID UUIDWithString:TGFORCE_RUNNING_DEVICE_IMPACT_SERVICE_UUID]];
            //Start Scanning for UUID we are interested in
            
            [self.centralManager scanForPeripheralsWithServices:service options:nil];
            NSLog(@"Scanning Started");
        
        } else {
            //try connecting to a peripheral we know from previous run. - not first time.
            [self tryConnectingWithUUIDfromUserDefaults];
        }

    }
    else if ([central state] == CBCentralManagerStateUnauthorized) {
        NSLog(@"CoreBluetooth BLE state is unauthorized");
                [self displayAlertMessage:@"CoreBluetooth BLE state is unauthorized"];
    }
    else if ([central state] == CBCentralManagerStateUnknown) {
        NSLog(@"CoreBluetooth BLE state is unknown");
        [self displayAlertMessage:@"CoreBluetooth BLE state is unknown"];
        
    }
    else if ([central state] == CBCentralManagerStateUnsupported) {
        NSLog(@"CoreBluetooth BLE hardware is unsupported on this platform");
        [self displayAlertMessage:@"CoreBluetooth BLE hardware is unsupported on this platform"];
        
    }
    
}

// CBCentralManagerDelegate - This is called with the CBPeripheral class as its main input parameter. This contains most of the information there is to know about a BLE peripheral.
// WILL Be called for all device in Range that fit the search UUID criteria
-(void) centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    NSLog(@"Running %@ '%@'", self.class, NSStringFromSelector(_cmd));
    //WHAT TO DO IF MORE THAN ONE tgforce Device IN RANGE? just take the first one for now. use settings for selecting one.
    
    NSString *localName = [advertisementData objectForKey:CBAdvertisementDataLocalNameKey];
    //NSUUID *perifNsuuid = [peripheral identifier];
    //First check we have at least 7 characters
    NSLog(@"Found device: %@", localName);
    if([localName length]>7){
    
    NSString *bleMatchName = [localName substringToIndex:5];
    

        NSLog(@"blematchname: %@", bleMatchName);
        if([bleMatchName  isEqual: BLE_DEVICE_NAME]){
            
            //store in array:
            [self.discoveredPeripheral addObject:peripheral];
            
            
            NSLog(@"object added");
            //int objectCount=[self.discoveredPeripheral count];
            //NSLog(@"1-discoveredPeripheral count: %u",objectCount);
            
            [self.centralManager stopScan];
            NSLog(@"Stop Scanning");
            
            //store in cache system for faster communication
            self.tgforcePeripheral = peripheral;
            
            // don't understand this one below... from web tutorial needed?
            peripheral.delegate = self;
            
            //Store UUID in userdefaults for direct connection next time the application start
            NSString *uuidString = [NSString stringWithFormat:@"%@", [[self.tgforcePeripheral identifier] UUIDString]];
            //store this in User Defaults
            NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
            [userDefaults setObject:uuidString forKey:@"uuidString"];
            [userDefaults synchronize];

            [self.centralManager connectPeripheral:peripheral options:nil];
        }
    }
}

//- delegate method. conforming to the protocol specified in the .h file.
// method called whenever you have successfully connected to the BLE peripheral
-(void) centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    [peripheral setDelegate:self];
    [peripheral discoverServices:nil];
    self.connected = [NSString stringWithFormat:@"Connected: %@", peripheral.state == CBPeripheralStateConnected ? @"YES" : @"NO"];
    NSLog(@"didConnectPeripheral:");
    NSLog(@"%@", self.connected);
    
    self.isConnected = YES;
    self.bleStatusImage.highlighted = self.isConnected;
    
    
    //spo2, start display and tx as soon as we have valid bluetooth comms
    self.isRunning  = YES;
    
    //start stopwatch
    if (self.stopTimer == nil) {
        self.startDate = [NSDate date];
        self.stopTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                          target:self
                                                        selector:@selector(updateStopWatch)
                                                        userInfo:nil
                                                         repeats:YES];
    }
    
    
    
    
    //set button to <disconnect> lavbel
    //[self.btleButton setTitle:@"Disconnect" forState:UIControlStateNormal];
    
}

-(void) centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"didFailToConnectPeripheral:");
    //display pop-up window here
    //[self bluetoothCleanup];
    
    
}

// SHOW graphical icon - not connected anymore
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"didDisconnectPeripheral:");
    
    self.isConnected = NO;
    self.bleStatusImage.highlighted = self.isConnected;
    [self setDisplayDisconnected];
    
    //try reconnecting with previous uuid
    [self tryConnectingWithUUIDfromUserDefaults];
}

// ******************************************************************
#pragma mark - CBPeripheralDelegate

// CBPeripheralDelegate - Invoked when you discover the peripheral's available services.
-(void) peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    for (CBService *service in peripheral.services) {
        NSLog(@"Discovered service: %@", service.UUID);
        [peripheral discoverCharacteristics:nil forService:service];
    }
}

// Invoked when you discover the characteristics of a specified service.
-(void) peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    
    if ([service.UUID isEqual:[CBUUID UUIDWithString:TGFORCE_RUNNING_DEVICE_BATTERY_SERVICE_UUID]])  {  // 1
        for (CBCharacteristic *aChar in service.characteristics)
        {
            // Request battery level notifications
            if ([aChar.UUID isEqual:[CBUUID UUIDWithString:TGFORCE_BATTERY_LEVEL_CHARACTERISTIC_UUID]]) { // 2
                [self.tgforcePeripheral setNotifyValue:YES forCharacteristic:aChar];
                //NSLog(@"Found battery level characteristic");
            }
            
        }
    } //1
    
    if([service.UUID isEqual:[CBUUID UUIDWithString:TGFORCE_RUNNING_DEVICE_IMPACT_SERVICE_UUID]]) {
        for(CBCharacteristic *aChar in service.characteristics)
        {
            //request PPA notifications - SpO2 Level Value
            if([aChar.UUID isEqual:[CBUUID UUIDWithString:TGFORCE_PPA_LEVEL_CHARACTERISTIC_UUID]]){ //in SpO2, SpO2 level
                [self.tgforcePeripheral setNotifyValue:YES forCharacteristic:aChar];
                //NSLog(@"Found PPA level characteristic");
            }
            //request CADENCE notifications - Heart Rate
            if([aChar.UUID isEqual:[CBUUID UUIDWithString:TGFORCE_CADENCE_CHARACTERISTIC_UUID]]){ // in spo2, heart rate
                [self.tgforcePeripheral setNotifyValue:YES forCharacteristic:aChar];
                //NSLog(@"Found cadence level characteristic");
            }
            //request SpO2 Status notifications - spo2 status
            if([aChar.UUID isEqual:[CBUUID UUIDWithString:SPO2_STATUS_CHARACTERISTIC_UUID]]){ // in spo2, status
                [self.tgforcePeripheral setNotifyValue:YES forCharacteristic:aChar];
                NSLog(@"Found SPO2 STATUS  characteristic");
            }
        
        }
    }
    
    
    
    
    // Retrieve Device Information Services for the Manufacturer Name
    if ([service.UUID isEqual:[CBUUID UUIDWithString:TGFORCE_RUNNING_DEVICE_INFO_SERVICE_UUID]])  { // 4
        for (CBCharacteristic *aChar in service.characteristics)
        {
            if ([aChar.UUID isEqual:[CBUUID UUIDWithString:TGFORCE_MANUFACTURER_NAME_CHARACTERISTIC_UUID]]) {
                [self.tgforcePeripheral readValueForCharacteristic:aChar];
                NSLog(@"Found a device manufacturer name characteristic");
            }
            if ([aChar.UUID isEqual:[CBUUID UUIDWithString:SPO2_SERIAL_NUMBER_STRING_CHARACTERISTIC_UUID]]) {
                [self.tgforcePeripheral readValueForCharacteristic:aChar];
                NSLog(@"Found SERIAL NUMBER characteristic");
            }
        }
    }

}

// Invoked when you retrieve a specified characteristic's value, or when the peripheral device notifies your app that the characteristic's value has changed.
- (void) peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    
    //UPDATE VALUE - BATTERY LEVEL
    if([characteristic.UUID isEqual:[CBUUID UUIDWithString:TGFORCE_BATTERY_LEVEL_CHARACTERISTIC_UUID]]){
        
        //get battery level value
        [self getBatteryLevelData:characteristic error:error];
        
    }
    
    //UPDATE VALUE - PPA LEVEL - SPO2 - SPO2 LEVEL
    if([characteristic.UUID isEqual:[CBUUID UUIDWithString:TGFORCE_PPA_LEVEL_CHARACTERISTIC_UUID]]){
        
        //get ppa level value
        [self getPPAImpactData:characteristic error:error];
        
    }
    //UPDATE VALUE - CADENCE - SPO2 HEART RATE
    if([characteristic.UUID isEqual:[CBUUID UUIDWithString:TGFORCE_CADENCE_CHARACTERISTIC_UUID]]){
        
        //get SPO2 HEART RATE level value
        [self getCadenceData:characteristic error:error];
        
    }
    //UPDATE VALUE - SPO2 STATUS
    if([characteristic.UUID isEqual:[CBUUID UUIDWithString:SPO2_STATUS_CHARACTERISTIC_UUID]]){
        
        //get SPO2 STATUS INDICATOR
        [self getSPO2StatusData:characteristic error:error];
        
    }
    
    
    
    if([characteristic.UUID isEqual:[CBUUID UUIDWithString:TGFORCE_MANUFACTURER_NAME_CHARACTERISTIC_UUID]]){
        
        [self getManufacturerName:characteristic];
        
    }
    
    if([characteristic.UUID isEqual:[CBUUID UUIDWithString:SPO2_SERIAL_NUMBER_STRING_CHARACTERISTIC_UUID]]){
        
        [self getSerialNumber:characteristic];
        
    }
    
    //add more here

}

//invoke when characteristic has been succesfully written - ie ACK
-(void) peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    if (error) {
        NSLog(@"Error writing characteristic value: %@", error.localizedDescription);
        
    } else {
        //success
        NSLog(@"Success writing characteristic: %@", peripheral.name);
    }
    
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    
    if (characteristic.isNotifying) {
        //NSLog(@"Notification began on %@", characteristic);
    } else {
        // Notification has stopped
        [_centralManager cancelPeripheralConnection:peripheral];
    }
}


- (void)bluetoothCleanup {
    
    NSLog(@"Bluetooth Cleanup started");
    // See if we are subscribed to a characteristic on the peripheral
    if (_tgforcePeripheral.services != nil) {
        for (CBService *service in _tgforcePeripheral.services) {
            if (service.characteristics != nil) {
                for (CBCharacteristic *characteristic in service.characteristics) {
                    
                    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:TGFORCE_PPA_LEVEL_CHARACTERISTIC_UUID]]) {
                        if (characteristic.isNotifying) {
                            [_tgforcePeripheral setNotifyValue:NO forCharacteristic:characteristic];
                            NSLog(@"Bluetooth Cleanup ppa completed");
                            //return;
                        }
                    }
                    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:TGFORCE_CADENCE_CHARACTERISTIC_UUID]]) {
                        if (characteristic.isNotifying) {
                            [_tgforcePeripheral setNotifyValue:NO forCharacteristic:characteristic];
                            NSLog(@"Bluetooth Cleanup cadence completed");
                            //return;
                        }
                    }
                    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:TGFORCE_BATTERY_LEVEL_CHARACTERISTIC_UUID]]) {
                        if (characteristic.isNotifying) {
                            [_tgforcePeripheral setNotifyValue:NO forCharacteristic:characteristic];
                            NSLog(@"Bluetooth Cleanup battery completed");
                            //return;
                        }
                    }
                    
                }
            }
        }
    }
    
    [_centralManager cancelPeripheralConnection:_tgforcePeripheral];
    NSLog(@"Bluetooth Cleanup completed");
}


// ******************************************************************
#pragma mark - CBCharacteristic helpers

// Instance method to display the PPA information received - SPo2 Level
// For SPO2, The SPo2 Level
- (void) getPPAImpactData:(CBCharacteristic *)characteristic error:(NSError *)error
{
    
    //only process this if we are running
    if(self.isRunning){
        
        
        NSData *data = [characteristic value];
        const uint8_t *reportData = [data bytes];
        uint8_t ppaTempLevel = reportData[0];
        
        NSLog(@"SPo2 Level: %d",ppaTempLevel);
        if(ppaTempLevel>126){ //this means value is not right.
            ppaTempLevel = 0;
        }
        
        
        //float ppaCorrected = (ppaTempLevel/2) *  LIS3DSH_ACCELERATION_CONVERSION;   //0.188346; // constant is 23.920g / 127
        
        _realTimePPA = ppaTempLevel;
        
        //gMax Warning: //noneed
        /*
        if((ppaCorrected>_gMaxValue) && (_gMaxNotificationStatus)){
            //color is red
            self.ppaValueDisplayed.textColor = [UIColor redColor];
            self.bigGlabel.textColor = [UIColor redColor];
            //beep?
            if(_audioFeedbackStatus){
                [self playSound];
            }
         */
        //} else { //color is
        //color is
            self.ppaValueDisplayed.textColor = [UIColor purpleColor];
            self.bigGlabel.textColor = [UIColor purpleColor];

        //}
        
        
        if((characteristic.value) || !error){
            //self.ppaLevel = ppaCorrected;
            if(ppaTempLevel == 0){
                //self.ppaValueDisplayed.text = [NSString stringWithFormat:@"-"]; //invalid, 0, replace by -
                self.ppaValueDisplayed.text = [NSString stringWithFormat:@"97"]; //invalid, 0, replace by -
            } else {
                self.ppaValueDisplayed.text = [NSString stringWithFormat:@"%d", ppaTempLevel];
            }
        }
        //Put on graphic
        [self graphPPA:ppaTempLevel];
        
        //Update the average Value
        ++_totalStep;
        self.totalPPA = _totalPPA + ppaTempLevel;
        self.averagePPA = _totalPPA/_totalStep;
        
        
        //Average label text is also RED is over gMaxValue
        /*
        if((_averagePPA>_gMaxValue) && (_gMaxNotificationStatus)){
            self.avgValueLabel.textColor = [UIColor redColor];
        } else { 
            //self.avgValueLabel.textColor = [UIColor colorWithRed:108.0f/255.0f green:158.0f/255.0f blue:239.0f/255.0f alpha:1.0];
            self.avgValueLabel.textColor = [UIColor colorWithRed:108.0f/255.0f green:158.0f/255.0f blue:255.0f/255.0f alpha:1.0];
            
        }
         
        */
        //blue
        //self.avgValueLabel.textColor = [UIColor colorWithRed:108.0f/255.0f green:158.0f/255.0f blue:255.0f/255.0f alpha:1.0];
        
        //self.avgValueLabel.text = [NSString stringWithFormat:@"%d", ppaTempLevel];
        
        //Total steps
        self.stepCount.text = [NSString stringWithFormat:@"%d",_totalStep];
        
        //put this information in data model TGDataModel
        
        //self.thisStepInfo = [[TGdataModel alloc]init];
        
        //self.thisStepInfo.stepDate = [NSDate date];
        //self.thisStepInfo.ppa = [NSNumber numberWithFloat:ppaCorrected];
        //self.thisStepInfo.avgPpa = [NSNumber numberWithFloat:_averagePPA];
        //self.thisStepInfo.cadence = [NSNumber numberWithInt:_cadenceLevel];
        
        /*
        NSLog(@"datamodel.ppa:%f",[self.thisStepInfo.ppa floatValue]);
        NSLog(@"avg:%f",[_thisStepInfo.avgPpa floatValue]);
        NSLog(@"cadence:%d",[_thisStepInfo.cadence intValue]);
        */
        
        //add to mutable array
        /*
        if([self.stepDataSetArray count]<MAXIMUM_STEPS_RECORDED_FOR_EXPORT){
            //did not reach max limit
            [self.stepDataSetArray addObject:_thisStepInfo];
            //NSLog(@"1-stepdataset count:%d",[self.stepDataSetArray count]);
            
        } else {
            //ok, we need tu pull out oldest record before inserting one
            [self.stepDataSetArray removeObjectAtIndex:0];
            //now insert
            [self.stepDataSetArray addObject:_thisStepInfo];
            //NSLog(@"2-stepdataset count:%d",[self.stepDataSetArray count]);
            
        }
         */

    
        //Add to CoreData **************** CORE DATA
        // NO need for Core Data for SP02
        
        //step data insert for this session
        /*
        TGAppDelegate *delegate = (TGAppDelegate *) [[UIApplication sharedApplication]delegate];
        NSManagedObjectContext *context = delegate.persistence.managedObjectContext;
        
        Step *thisStep = [NSEntityDescription insertNewObjectForEntityForName:@"Step" inManagedObjectContext:context];
        
        thisStep.runningCadence = [[NSNumber alloc]initWithFloat:_cadenceLevel];
        thisStep.runningPPA = [[NSNumber alloc]initWithFloat:ppaCorrected];
        thisStep.runningAvgPPA = [[NSNumber alloc]initWithFloat:_averagePPA];
        thisStep.distance = [[NSNumber alloc]initWithInt:10];
        thisStep.speed = [[NSNumber alloc]initWithInt:20];
        thisStep.recordedAt = [NSDate date];
        thisStep.session = self.currentSession;
         */
        
        //NSLog(@"inserted new managed object PPA for '%@'", thisStep.runningPPA);
        //NSLog(@"inserted new managed object runningavgppafor '%@'", thisStep.runningAvgPPA);
        //NSLog(@"inserted new managed object stepCadencefor '%@'", thisStep.runningCadence);
        //NSLog(@"inserted new managed object step-session for '%@'", thisStep.session);
        
        
        //needed here?
        //[delegate.persistence saveContext];
        
    }
}

// Instance method to get the cadence value, which is Heart rate for SPo2
// SPO2 Heart Rate
- (void) getCadenceData:(CBCharacteristic *)characteristic error:(NSError *)error
{
    //only process this if we are running
    if(self.isRunning){
        
        NSData *data = [characteristic value];
        const uint8_t *reportData = [data bytes];
        _cadenceLevel = reportData[0];
        
        //self.cadenceValueLabel.textColor = [UIColor colorWithRed:108.0f/255.0f green:158.0f/255.0f blue:239.0f/255.0f alpha:1.0];
        self.cadenceValueLabel.textColor = [UIColor blueColor];
        
        /*
        if(_totalStep > 5){
            self.cadenceValueLabel.text = [NSString stringWithFormat:@"%i", _cadenceLevel];
            
            //update the average cadence
            ++_totalCadenceStep;
            self.totalCadence = _totalCadence + _cadenceLevel;
            self.averageCadence = _totalCadence/_totalCadenceStep;
            
            
        } else {
            self.cadenceValueLabel.text = [NSString stringWithFormat:@"---"];
        }
        */

        //check if valid value.. 255?
        if(_cadenceLevel > 254){
                self.cadenceValueLabel.text = [NSString stringWithFormat:@"-"];
        } else {
                self.cadenceValueLabel.text = [NSString stringWithFormat:@"%i", _cadenceLevel];
            
      // ************************* FIREBASE *******************
            //UPDATE FIREBASE cause HR is fine
            
            if (_gMaxNotificationStatus == TRUE) {  //gmax for now for firebase update
                [self updateFirebase];
            }
            
            
        }
        
        
        NSLog(@"Heart Rate: %d",_cadenceLevel);
        
        
    }
    
}

// Instance method to get the spo2 status data value
- (void) getSPO2StatusData:(CBCharacteristic *)characteristic error:(NSError *)error
{

    
    
    //only process this if we are running
    if(self.isRunning){
        
        NSData *data = [characteristic value];
        const uint8_t *reportData = [data bytes];
        _SPo2StatusValue = reportData[0];
        
        /*
        self.cadenceValueLabel.textColor = [UIColor colorWithRed:108.0f/255.0f green:158.0f/255.0f blue:239.0f/255.0f alpha:1.0];
        
        if(_totalStep > 5){
            self.cadenceValueLabel.text = [NSString stringWithFormat:@"%i", _cadenceLevel];
            
            //update the average cadence
            ++_totalCadenceStep;
            self.totalCadence = _totalCadence + _cadenceLevel;
            self.averageCadence = _totalCadence/_totalCadenceStep;
            
            
        } else {
            self.cadenceValueLabel.text = [NSString stringWithFormat:@"---"];
        }
         */
        NSLog(@"SPo2Status: %d",_SPo2StatusValue);
        
        //update label based on Status:
        // GREEN OK
        //BYTE1 STATUS 100000XX means OK, bitwise and to 01111100 (124) must give 0
        if((self.SPo2StatusValue & 124) == 0){
            self.okStatusLabel.hidden = NO;
            self.okStatusLabel.text =@"OK";
            self.okStatusLabel.textColor = [UIColor colorWithRed:0.0f/255.0f green:51.0f/255.0f blue:0.0f/255.0f alpha:1.0];
            
        } else {
            self.okStatusLabel.hidden = YES;
        }
        //SNSD
        if((self.SPo2StatusValue & 192)== 192){
            self.snsdLabel.textColor = [UIColor redColor];
        } else {
            self.snsdLabel.textColor = [UIColor lightGrayColor];
        }
        //OOT
        if((self.SPo2StatusValue & 160)== 160){
            self.ootLabel.textColor = [UIColor redColor];
        } else {
            self.ootLabel.textColor = [UIColor lightGrayColor];
        }
        //LPRF
        if((self.SPo2StatusValue & 144)== 144){
            self.lprfLabel.textColor = [UIColor redColor];
        } else {
            self.lprfLabel.textColor = [UIColor lightGrayColor];
        }
        //MPRF
        if((self.SPo2StatusValue & 136)== 136){
            self.mprfLabel.textColor = [UIColor redColor];
        } else {
            self.mprfLabel.textColor = [UIColor lightGrayColor];
        }
        //ARTF
        if((self.SPo2StatusValue & 132)== 132){
            self.artfLabel.textColor = [UIColor redColor];
        } else {
            self.artfLabel.textColor = [UIColor lightGrayColor];
        }
        
    }
    
}


// Instance method to get the BatteryLevel information
- (void) getBatteryLevelData:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSData *data = [characteristic value];
    const uint8_t *reportData = [data bytes];
    uint8_t batteryLevel = reportData[0];
    
    if((characteristic.value) || !error){
        
        self.batLevel = batteryLevel;
        
        self.batteryLevelData = [NSString stringWithFormat:@"%i%%", batteryLevel];
        
        self.batLevelLabel.text = [NSString stringWithFormat:@"%i%%", batteryLevel];
        if(batteryLevel<15){
            self.batLevelLabel.textColor = [UIColor redColor];
        } else {
            self.batLevelLabel.textColor = [UIColor blackColor];
        }
        
    }
    
    
}

// Instance method to get the manufacturer name of the device
- (void) getManufacturerName:(CBCharacteristic *)characteristic
{
    
    NSString *manufacturerName = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    self.manufacturer = manufacturerName;
    
    
}

// Instance method to get the serial number of the device
- (void) getSerialNumber:(CBCharacteristic *)characteristic
{
    
    NSString *serialNumberSpO2 = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    self.serialNumber = serialNumberSpO2;
    
    
}

// Instance method to get the gThreshold of the device
/*
- (void) getgThreshold:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSData *data = [characteristic value];
    const uint8_t *reportData = [data bytes];
    uint8_t gThresholdLevel = reportData[0];
    
    if((characteristic.value) || !error){
        
        self.gThLevel = gThresholdLevel;
        
        self.gThresholdData = [NSString stringWithFormat:@"%i ", gThresholdLevel];
        
    }
    
}
 */

/*
// Instance method to get the delay value of the device
- (void) getDelayValue:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSData *data = [characteristic value];
    const uint8_t *reportData = [data bytes];
    uint8_t delayValue = reportData[0];
    
    if((characteristic.value) || !error){
        
        self.gThLevel = delayValue;
        
        self.gThresholdData = [NSString stringWithFormat:@"%i ", delayValue];
        
        NSLog(@"self.gThresholdData:");NSLog(self.gThresholdData);
        
    }
    
}
 */


// Helper method to perform a tGforce animation
- (void)doAnimation
{
}

#pragma mark - Imported from shinobi example

//method for initializing first ppa data on the graphic at zero value
- (SChartDataPoint*)dataPointWithIndex:(NSInteger)index  {
    SChartDataPoint *datapoint = [[SChartDataPoint alloc] init];
    datapoint.xValue = @(index);
    //datapoint.yValue = @([self sinOfValue:index]);
    datapoint.yValue = @(0);
    return datapoint;
}

/*
//method for initializing gMaxline of data on the graphic at gMaxValue
- (SChartDataPoint*)gMaxdataPointWithIndex:(NSInteger)index  {
    SChartDataPoint *datapoint = [[SChartDataPoint alloc] init];
    datapoint.xValue = @(index);
    datapoint.yValue = @([[NSUserDefaults standardUserDefaults] floatForKey:@"gMaxValue"]);
    return datapoint;
}
 */

- (void) graphPPA:(float)ppaValue {
    // Update our data, by adding a new value, and removing the first value
    
    SChartDataPoint *datapoint = [[SChartDataPoint alloc] init];
    //SChartDataPoint *gMaxdatapoint = [[SChartDataPoint alloc] init];
    
    
    //PPA
    datapoint.xValue = @(_currentDataIndex);
    datapoint.yValue = @((double)ppaValue);
   
    
    [self.streamedData addObject:datapoint];
    [self.streamedData removeObjectAtIndex:0];
    
    //gmax value line
    //gMaxdatapoint.xValue = @(_currentDataIndex);
    //gMaxdatapoint.yValue = @([[NSUserDefaults standardUserDefaults] floatForKey:@"gMaxValue"]);
    //NSLog(@"gMaxvelue for chart:%@",gMaxdatapoint.yValue);

    //[self.gMaxDataForDisplay addObject:gMaxdatapoint];
    //[self.gMaxDataForDisplay removeObjectAtIndex:0];
    
    //decrease index. in fact augment negatively
     --_currentDataIndex;
    
    // Refresh the chart
    
    [self.chart removeNumberOfDataPoints:1 fromStartOfSeriesAtIndex:0];
    [self.chart appendNumberOfDataPoints:1 toEndOfSeriesAtIndex:0];
    
    //if(_gMaxNotificationStatus){
    //    [self.chart removeNumberOfDataPoints:1 fromStartOfSeriesAtIndex:1];
    //    [self.chart appendNumberOfDataPoints:1 toEndOfSeriesAtIndex:1];
    //}
    [self.chart redrawChart];
    //NSLog(@"shinobi chart redraw with ppavalue: %f",ppaValue);
    
    
}



- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation   {
    return YES;
}

#pragma mark - SChartDatasource

// Returns the number of series in the specified chart
- (NSInteger)numberOfSeriesInSChart:(ShinobiChart *)chart {
    
    //if(_gMaxNotificationStatus){
    //        return 2;
    //} else {
        return 1;
    //}
}

// Returns the series at the specified index for a given chart
-(SChartSeries *)sChart:(ShinobiChart *)chart seriesAtIndex:(NSInteger)index {
    
    
    //serie 0 is ppa, serie 1 is gMax Line
    //if(index == 0){
    
        //if(_realTimeGraphic == 1) { //1 IS BAR CHART AND 0 IS LINE CHART
        
            //bar chart
            SChartColumnSeries *Series = [[SChartColumnSeries alloc] init];

            //Series.style.areaColor = Series.style.areaColor = [UIColor colorWithRed:10.f/255.f green:50.f/255.f blue:125.f/255.f alpha:1.f];
            Series.style.areaColor = Series.style.areaColor = [UIColor purpleColor];
    /*
    Series.animationEnabled = true;
    SChartAnimation *animation = [SChartAnimation growVerticalAnimation];
    animation.duration = @0.3;
    Series.entryAnimation = [animation copy];
    Series.exitAnimation = [animation copy];
     */
    

            return Series;
        /*
        } else {
            //lie chart
            SChartLineSeries *Series = [[SChartLineSeries alloc] init];
            Series.style.lineWidth = [NSNumber numberWithInt:10];
            Series.style.lineColor = [UIColor colorWithRed:10.f/255.f green:50.f/255.f blue:125.f/255.f alpha:1.f];
            Series.style.areaColorLowGradient = [UIColor colorWithRed:10.f/255.f green:80.f/255.f blue:155.f/255.f alpha:1.f];
            
            Series.style.areaColor = [UIColor colorWithRed:208.0f/255.0f green:16.0f/255.0f blue:16.0f/255.0f alpha:1.0]; //[UIColor purpleColor];
            Series.style.fillWithGradient = YES;
            Series.style.showFill = YES;
            Series.baseline = [NSNumber numberWithInt:0];
            return Series;
        }
    } else {
        //serie 1 is line for gMax value to display
        //lie chart
        SChartLineSeries *Series = [[SChartLineSeries alloc] init];
        Series.style.lineWidth = [NSNumber numberWithInt:4];
        Series.style.lineColor = [UIColor redColor];
        return Series;
     
         */
    //}
}

// Returns the number of points for a specific series in the specified chart
- (NSInteger)sChart:(ShinobiChart *)chart numberOfDataPointsForSeriesAtIndex:(NSInteger)seriesIndex {
    return self.streamedData.count;
}

// Returns the data point at the specified index for the given series/chart.
- (id<SChartData>)sChart:(ShinobiChart *)chart dataPointAtIndex:(NSInteger)dataIndex forSeriesAtIndex:(NSInteger)seriesIndex {
    
    //if(seriesIndex==0){ //ppa value
        return [self.streamedData objectAtIndex:dataIndex];
    //} else { //gMax display
    //    return [self.gMaxDataForDisplay objectAtIndex:dataIndex];
    //}
}

#pragma mark - ActionSheet related methods

- (IBAction)sliderForStopTouchUp:(id)sender {
    //also include touch up outside. inside
    /*
    
    if (self.sliderForStop.value < 0.92){ //did not slide enough - back to start
        self.sliderForStop.value = 0;
        
    } else {
        // OK user wants to stop, pause or restart
        
        self.isRunning = NO;
        self.stopSliderTouchTime = [NSDate date];
        //set slider back to 0
        //self.sliderForStop.value = 0;

        
        //if number of step more than 1,else do nothing
        if(self.totalStep>0){
            //Send active menu for selecting what to do when stopping
            UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:@"Session Paused" delegate:self cancelButtonTitle:@"Resume" destructiveButtonTitle:@"Stop and Discard session" otherButtonTitles:@"Stop and Save session", nil];
            
            //[actionSheet showInView:[UIApplication sharedApplication].keyWindow];
            [actionSheet showFromTabBar:self.tabBarController.tabBar];
        } else {
            //no steps recorded
            
            // ******** STOP AND DISCARD **********
            //NSLog(@"Stop and discard Clicked");
            //Restart everything, discard current session
            self.isRunning = NO;
            //[self.slideToStopLabel setHidden:YES];
            //[self.arrowBlueStop setHidden:YES];
            //[self.sliderForStop setHidden:YES];
            [self.startButton setHidden:NO];
            //stop the stopwatch
            self.stopWatchRunning = NO;
            [self.stopTimer invalidate];
            self.stopTimer = nil;
            
            //Discard current session in coredata
            TGAppDelegate *delegate = (TGAppDelegate *) [[UIApplication sharedApplication]delegate];
            NSManagedObjectContext *context = delegate.persistence.managedObjectContext;
            
            //NSLog(@"self.currentSession.startTime to delete is  '%@'", self.currentSession.startTime);
            
            [context deleteObject:self.currentSession];
            [delegate.persistence saveContext];
            
            //clean up stuff on the screen to show we are restarting
            //reset everything to zero
            [self resetCalcDisplay];
            //reset chart
            for(int i = 0;i<20;i++){
                [self graphPPA:(0)];
            }
            //time display should be reset also
            self.stopWatchLbl.text =[NSString stringWithFormat:@"-"];
            // Display setting & History button tab bar - Enabled
            [[[[self.tabBarController tabBar]items]objectAtIndex:2]setEnabled:YES];
            [[[[self.tabBarController tabBar]items]objectAtIndex:1]setEnabled:YES];
            
            
            
        }
        
    }
    */
}


-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex{
    if(buttonIndex == 0) //stop and discard
    {
        // ******** STOP AND DISCARD **********
        //NSLog(@"Stop and discard Clicked");
        //Restart everything, discard current session
        self.isRunning = NO;
        //[self.slideToStopLabel setHidden:YES];
        //[self.arrowBlueStop setHidden:YES];
        //[self.sliderForStop setHidden:YES];
        [self.startButton setHidden:NO];
        //stop the stopwatch
        self.stopWatchRunning = NO;
        [self.stopTimer invalidate];
        self.stopTimer = nil;
      
        //Discard current session in coredata
        TGAppDelegate *delegate = (TGAppDelegate *) [[UIApplication sharedApplication]delegate];
        NSManagedObjectContext *context = delegate.persistence.managedObjectContext;
        
        //NSLog(@"self.currentSession.startTime to delete is  '%@'", self.currentSession.startTime);
        
        [context deleteObject:self.currentSession];
        [delegate.persistence saveContext];
        
        //clean up stuff on the screen to show we are restarting
        //reset everything to zero
        [self resetCalcDisplay];
        //reset chart
        for(int i = 0;i<20;i++){
            [self graphPPA:(0)];
        }
        //time display should be reset also
        self.stopWatchLbl.text =[NSString stringWithFormat:@"-"];
        // Display setting & History button tab bar - Enabled
        [[[[self.tabBarController tabBar]items]objectAtIndex:2]setEnabled:YES];
        [[[[self.tabBarController tabBar]items]objectAtIndex:1]setEnabled:YES];
        
        
    }
    else if(buttonIndex == 1) //Stop and save Button Clicked - ***************** STOP AND SAVE
    {
        //NSLog(@"Stop and save Button Clicked");
        TGAppDelegate *delegate = (TGAppDelegate *) [[UIApplication sharedApplication]delegate];
        //NSManagedObjectContext *context = delegate.persistence.managedObjectContext;
        
        self.currentSession.endTime = self.stopSliderTouchTime;
        //NSLog(@"STOP&SAVE endTime for '%@'", self.currentSession.endTime);
        
        
        //*************   how many steps:
        //this does not provide accurate account, todo
        /*
        NSFetchRequest *request = [[NSFetchRequest alloc]init];
        [request setEntity:[NSEntityDescription entityForName:@"Step" inManagedObjectContext:context]];
        [request setIncludesSubentities:NO]; //Omit subentities. Default is YES
        NSError *err;
        NSInteger count = [context countForFetchRequest:request error:&err];
        if(count == NSNotFound) {
            //Handle error
        }
        */
        self.currentSession.stepsQty = [[NSNumber alloc] initWithInt:_totalStep];
        //NSLog(@"STOP&SAVE stepsQty countfor '%@'", self.currentSession.stepsQty);
        
        //avgPPA
        //we arleady calculate this
        self.currentSession.avgPPA = [[NSNumber alloc]initWithDouble:self.averagePPA];
        //NSLog(@"STOP&SAVE avgPPA for '%@'", self.currentSession.avgPPA);
        
        //avgCadence
        self.currentSession.avgCadence = [[NSNumber alloc]initWithDouble:self.averageCadence];
        //NSLog(@"STOP&SAVE avgCadence for '%@'", self.currentSession.avgCadence);
        
        //avgSpeed, totaldistance not done.
        
        //Save the context.
        [delegate.persistence saveContext];
        
        //put back START Button for eventual new sesssion
        self.isRunning = NO;
        //[self.slideToStopLabel setHidden:YES];
        //[self.arrowBlueStop setHidden:YES];
        //[self.sliderForStop setHidden:YES];
        [self.startButton setHidden:NO];
        //stop the stopwatch
        self.stopWatchRunning = NO;
        [self.stopTimer invalidate];
        self.stopTimer = nil;
        // Display setting & History button tab bar - Enabled
        // Display setting & History button tab bar - Enabled
        [[[[self.tabBarController tabBar]items]objectAtIndex:2]setEnabled:YES];
        [[[[self.tabBarController tabBar]items]objectAtIndex:1]setEnabled:YES];
        
        //Display and switch to History with session TAB index is 1
        [self.tabBarController setSelectedIndex:1];
        
        
    }
    else if(buttonIndex == 2)       //********** RESUME
    {
        //NSLog(@"Resume Button Clicked");
        //Keep going
        self.isRunning = YES;
        self.stopWatchRunning = YES;
        //hide the setting & History Tab Bar button when running
        [[[[self.tabBarController tabBar]items]objectAtIndex:2]setEnabled:NO];
        [[[[self.tabBarController tabBar]items]objectAtIndex:1]setEnabled:NO];
        
        //[self.slideToStopLabel setHidden:NO];
        //[self.arrowBlueStop setHidden:NO];
        //[self.sliderForStop setHidden:NO];
    }
    
}


#pragma mark - UTILITY methods

-(void)updateFirebase{
    
    // Write data to Firebase
    // Create a reference to a Firebase database URL
    //Firebase *ref = [[Firebase alloc]initWithUrl:(@"https://intense-torch-7662.firebaseio.com/SPO2Mon/Devices")];
    Firebase *ref = [[Firebase alloc]initWithUrl:(@"https://brilliant-heat-1397.firebaseio.com/SpO2Mon/Devices")];
    
    long timeStampLong = [[NSDate date] timeIntervalSince1970];
    NSNumber *aLong = [NSNumber numberWithLong:timeStampLong];
    NSNumber *spo2 = [NSNumber numberWithDouble:self.realTimePPA];
    NSNumber *hr = [NSNumber numberWithInt:self.cadenceLevel];
    
    
    NSDictionary *importantInfo = @{
                                    
                                    @"SpO2":spo2,
                                    @"HR":hr,
                                    @"TimeStamp":aLong
                                    
                                    };
    
    Firebase *unitRef = [ref childByAppendingPath:self.serialNumber];
    
    [unitRef setValue: importantInfo];
    
}

-(void)resetCalcDisplay{
    
    //Average Calculation PPA
    _totalStep = 0;
    _totalPPA = 0;
    _averagePPA = 0;
    
    //Average Calculation Cadence
    _totalCadenceStep =0 ;
    _totalCadence = 0;
    _averageCadence = 0;
    
    //Front view labels:
    self.ppaValueDisplayed.text = [NSString stringWithFormat:@"97"];
    //self.avgValueLabel.text = [NSString stringWithFormat:@"-.-"];
    self.cadenceValueLabel.text = [NSString stringWithFormat:@"145"];
    //self.stepCount.text = [NSString stringWithFormat:@"-"];
    
    //labels for ppa and avg should be blue:
    self.ppaValueDisplayed.textColor = [UIColor purpleColor];
    //self.avgValueLabel.textColor = [UIColor blueColor];
    self.bigGlabel.textColor = [UIColor purpleColor];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/


- (IBAction)startButtonPush:(id)sender {
    

    
    
    //are we connected?
    if(!self.isConnected){
        //not connected, display message
        [self displayAlertMessage:TGFORCE_SENSOR_NOT_CONNECTED];
        //self.isRunning = NO;
        //self.startButton.selected = NO;
        
    } else {
        //ok we are connected
        //self.isRunning = YES;
        //[self.slideToStopLabel setHidden:NO];
        //[self.arrowBlueStop setHidden:NO];
        //[self.sliderForStop setHidden:NO];
        //[self.startButton setHidden:YES];
        
        
        //stop the stopwatch
        self.stopWatchRunning = NO;
        [self.stopTimer invalidate];
        self.stopTimer = nil;
        self.stopWatchLbl.text =[NSString stringWithFormat:@"-"];
  
        
        //reset everything to zero
        [self resetCalcDisplay];
        //reset chart
        for(int i = 0;i<10;i++){
        //for(int i = 0;i<20;i++){
            [self graphPPA:(0)];
        }
        //flush arrays containg data
        if (self.stepDataSetArray.count>0) {
            [self.stepDataSetArray removeAllObjects];
        }
        //start stopwatch
        if (self.stopTimer == nil) {
            self.startDate = [NSDate date];
            self.stopTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                         target:self
                                                       selector:@selector(updateStopWatch)
                                                       userInfo:nil
                                                        repeats:YES];
        //hide the setting Tab Bar button when running
        //[[[[self.tabBarController tabBar]items]objectAtIndex:2]setEnabled:NO];
        //hide the
        //[[[[self.tabBarController tabBar]items]objectAtIndex:1]setEnabled:NO];
            
        
            //start Session in CoreData
            /*

            TGAppDelegate *delegate = (TGAppDelegate *) [[UIApplication sharedApplication]delegate];
            NSManagedObjectContext *context = delegate.persistence.managedObjectContext;
             

            
            //actual date
            NSDate *currentdate = [NSDate date];
            
            self.currentSession = [NSEntityDescription insertNewObjectForEntityForName:@"Session" inManagedObjectContext:context];
            self.currentSession.startTime = currentdate;
            //NSLog(@"inserted new managed object startTime for '%@'", self.currentSession.startTime);
             */

            
            
        }
    }
    
}
-(void) updateStopWatch{
    NSDate *currentDate = [NSDate date];
    NSTimeInterval timeInterval = [currentDate timeIntervalSinceDate:self.startDate];
    NSDate *timerDate = [NSDate dateWithTimeIntervalSince1970:timeInterval];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"HH:mm:ss"];
    [dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0.0]];
    NSString *timeString=[dateFormatter stringFromDate:timerDate];
    self.stopWatchLbl.text = timeString;
    
}



-(void)displayAlertMessage:(NSString *)alertMessage{
    
    UIAlertView *alertView1 = [[UIAlertView alloc] initWithTitle:ALERT_MESSAGE_TITLE
                                                         message:alertMessage
                                                        delegate:self
                                               cancelButtonTitle:@"OK"
                                               otherButtonTitles:nil];
    [alertView1 setTag:556];
    [alertView1 show];
}

/*
-(void)updateOperatingCharacteristics{
//make sure we are connected first - we do not know we we are being called from
    if(self.isConnected){
        
        //NSLog(@"-(void)updateOperatingCharacteristics{");
        bool avalue = NO;// this to avoid deadstore warning in analyze
        
        //gThreshold
        NSNumber *helper = [[NSNumber alloc]initWithUnsignedInt:0];
        if(avalue){  // this to avoid deadstore warning in analyze
            //NSLog(@"helper:%d",[helper intValue]);// this to avoid deadstore warning in analyze
        }// this to avoid deadstore warning in analyze
        
        //const uint8_t bytes[] = {20};
        
        helper = [[NSUserDefaults standardUserDefaults] valueForKey:@"gthresholdCharacteristic"]; // use NSNumber for helping because it has property and methods
        const uint8_t bytes[] = {helper.unsignedIntValue};
        
        NSData *data = [NSData dataWithBytes:bytes length:sizeof(bytes)];
        //NSLog(@"gThresholdChar : %@", data);
        [self.tgforcePeripheral writeValue:data forCharacteristic:self.gThresholdChar type:CBCharacteristicWriteWithResponse];
        
        
        //delaydelayCharacteristic (par exemple 8765)
        //First, find MSB, the first byte to send. in this example case 8704 = 256X34
        NSNumber *delayIntValue=[[NSNumber alloc]initWithUnsignedInt:0];
        if(avalue){  // this to avoid deadstore warning in analyze
            //NSLog(@"helper:%d",[delayIntValue intValue]);// this to avoid deadstore warning in analyze
        }// this to avoid deadstore warning in analyze
        
        
        delayIntValue = [[NSUserDefaults standardUserDefaults] valueForKey:@"delayCharacteristic"];
        
        const uint8_t arrayMSB = delayIntValue.unsignedIntValue/256; //will provide only the integer of the division result.
        
        //Next, find LSB
        const uint8_t arrayLSB = delayIntValue.unsignedIntValue - arrayMSB *256;
       
         const uint8_t bytesDelay[] = {arrayMSB, arrayLSB};
        //const uint8_t bytes2[] = {(uint8_t)[[NSUserDefaults standardUserDefaults] valueForKey:@"delayCharacteristic"]};
        NSData *data2 = [NSData dataWithBytes:bytesDelay length:sizeof(bytesDelay)];
        //NSLog(@"delayCharacteristic%@", data2);
        [self.tgforcePeripheral writeValue:data2 forCharacteristic:self.delayChar type:CBCharacteristicWriteWithResponse];

    }
}
 */

@end
