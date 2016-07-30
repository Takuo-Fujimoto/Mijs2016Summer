import UIKit
import CoreLocation
import CoreBluetooth
import CoreMotion
import AVFoundation

class ViewController: UIViewController, CLLocationManagerDelegate, CBCentralManagerDelegate {
    
    //ストーリーボードで設定
    @IBOutlet weak var status: UILabel!
    
    @IBOutlet weak var uuid: UILabel!
    
    @IBOutlet weak var major: UILabel!
    
    
    @IBOutlet weak var minor: UILabel!
    
    @IBOutlet weak var accuracy: UILabel!
    
    @IBOutlet weak var rssi: UILabel!
    
    @IBOutlet weak var distance: UILabel!
    
    
    var counter : Int = 0;
    
    var timer = NSTimer()
    
    var trackLocationManager : CLLocationManager!
    var beaconRegion : CLBeaconRegion!
    var myCentralManager: CBCentralManager!
    
    var myLocationManager:CLLocationManager!
    
    var myCMAltimeter: CMAltimeter!
    
    var lap:Int!
    
    // セッション.
    var mySession : AVCaptureSession!
    // デバイス.
    var myDevice : AVCaptureDevice!
    // 画像のアウトプット.
    var myImageOutput : AVCaptureStillImageOutput!
    
    var isBackGround:Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.uuid.text="didLoad1";
        self.major.text="didLoad2";
        self.minor.text="didLoad3";
        self.accuracy.text="didLoad4";
        self.rssi.text="didLoad5";
        self.distance.text="didLoad6";
        
        // ロケーションマネージャを作成する
        self.trackLocationManager = CLLocationManager();
        
        // デリゲートを自身に設定
        self.trackLocationManager.delegate = self;
        
        // セキュリティ認証のステータスを取得
        let status = CLLocationManager.authorizationStatus()
        
        // まだ認証が得られていない場合は、認証ダイアログを表示
        if(status == CLAuthorizationStatus.NotDetermined) {
            
            self.trackLocationManager.requestAlwaysAuthorization();
        }
        
        // BeaconのUUIDを設定
        let uuid:NSUUID? = NSUUID(UUIDString: "00000000-EF07-1001-B000-001C4DBDFBC6")
        
        //Beacon領域を作成
        self.beaconRegion = CLBeaconRegion(proximityUUID: uuid!, identifier: "net.noumenon-th")
        
        // CoreBluetoothを初期化および始動.
        //myCentralManager = CBCentralManager(delegate: self, queue: nil, options: nil)
        
        
        // CMAltimeterを取得.
        myCMAltimeter = CMAltimeter()
        
        // CMAltimeterが利用できるか(iPhone5SではNoが返ってくる).
        let isAltimeter = CMAltimeter.isRelativeAltitudeAvailable()
       
        
        
        // セッションの作成.
        mySession = AVCaptureSession()
        
        // デバイス一覧の取得.
        let devices = AVCaptureDevice.devices()
        
        // バックカメラをmyDeviceに格納.
        for device in devices{
            if(device.position == AVCaptureDevicePosition.Back){
                myDevice = device as! AVCaptureDevice
            }
        }
        
        // バックカメラからVideoInputを取得.
        let videoInput: AVCaptureInput!
        do {
            videoInput = try AVCaptureDeviceInput.init(device: myDevice!)
        }catch{
            videoInput = nil
        }
        // セッションに追加.
        mySession.addInput(videoInput)
        
        // 出力先を生成.
        myImageOutput = AVCaptureStillImageOutput()
        
        // セッションに追加.
        mySession.addOutput(myImageOutput)
        
        // セッション開始.
        mySession.startRunning()
        
        //バックグラウンドでも実行したい処理
        updating()
    }
    
    //位置認証のステータスが変更された時に呼ばれる
    func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        
        // 認証のステータス
        var statusStr = "";
        print("CLAuthorizationStatus: \(statusStr)")
        
        // 認証のステータスをチェック
        switch (status) {
        case .NotDetermined:
            statusStr = "NotDetermined"
        case .Restricted:
            statusStr = "Restricted"
        case .Denied:
            statusStr = "Denied"
            self.status.text   = "位置情報を許可していません"
        case .Authorized:
            statusStr = "Authorized"
            self.status.text   = "位置情報認証OK"
        default:
            break;
        }
        
        print(" CLAuthorizationStatus: \(statusStr)")
        
        //観測を開始させる
        trackLocationManager.startMonitoringForRegion(self.beaconRegion)
        
    }
    
    //観測の開始に成功すると呼ばれる
    func locationManager(manager: CLLocationManager, didStartMonitoringForRegion region: CLRegion) {
        
        print("didStartMonitoringForRegion");
        
        //観測開始に成功したら、領域内にいるかどうかの判定をおこなう。→（didDetermineState）へ
        trackLocationManager.requestStateForRegion(self.beaconRegion);
    }
    
    //領域内にいるかどうかを判定する
    func locationManager(manager: CLLocationManager, didDetermineState state: CLRegionState, forRegion inRegion: CLRegion) {
        
        switch (state) {
            
        case .Inside: // すでに領域内にいる場合は（didEnterRegion）は呼ばれない
            
            trackLocationManager.startRangingBeaconsInRegion(beaconRegion);
            // →(didRangeBeacons)で測定をはじめる
            break;
            
        case .Outside:
            
            // 領域外→領域に入った場合はdidEnterRegionが呼ばれる
            break;
            
        case .Unknown:
            
            // 不明→領域に入った場合はdidEnterRegionが呼ばれる
            break;
            
        default:
            
            break;
            
        }
    }
    
    //領域に入った時
    func locationManager(manager: CLLocationManager, didEnterRegion region: CLRegion) {
        
        // →(didRangeBeacons)で測定をはじめる
        self.trackLocationManager.startRangingBeaconsInRegion(self.beaconRegion)
        self.status.text = "didEnterRegion"
        
        sendLocalNotificationWithMessage("領域に入りました")
        

    }
    
    func postTimeToSlack() {
        let today = NSDate();
//        let secStr:String = "\(floor(today.timeIntervalSince1970))"
        //print(secStr)
        //let sec:Int = Int(secStr)!
        let sec:Int = Int(today.timeIntervalSince1970)
        var time:Int
        if self.lap == nil {
            lap = sec;
            return;
        } else {
            time = sec - self.lap
            lap = sec;
        }
        postMessageToSlack("[" + String(today) + "]ごはん食べてるにゃー（前回の測定からの経過時間：" + String(time) + ")", dist: "", accr: "", rsi: "")
    }
    
    func postMessageToSlack(msg: String, dist: String, accr: String, rsi: String) {
        // create the url-request
        let urlString = "https://hooks.slack.com/services/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"
        let request   = NSMutableURLRequest(URL: NSURL(string: urlString)!)
        
        // set the method(HTTP-POST)
        request.HTTPMethod = "POST"
        // set the headers
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        // set the request-body(JSON)
        //proximityUUID   :   regionの識別子
        //major           :   識別子１
        //minor           :   識別子２
        //proximity       :   相対距離
        //accuracy        :   精度
        //rssi            :   電波強度
        var param1:String = ""
        var param2:String = ""
        var param3:String = ""
        if dist != "" {
            param1 = "[" + dist + "]"
        }
        if dist != "" {
            param2 = "[" + accr + "]"
        }
        if dist != "" {
            param3 = "[" + rsi + "]"
        }
        let params: [String: AnyObject] = [
            "channel"   : "#general",
            "username"  : "takuo.fujimoto",
            "text"      : msg + param1 + param2 + param3,
            "icon_emoji": ":beginner:"
        ]
        do {
            try request.HTTPBody = NSJSONSerialization.dataWithJSONObject(params, options: NSJSONWritingOptions(rawValue: 0))
        } catch let parsingError as NSError {
            print(parsingError.description)
        }
        
        // use NSURLSessionDataTask
        let task = NSURLSession.sharedSession().dataTaskWithRequest(request, completionHandler: {
            (data, response, error) in
            let result = NSString(data: data!, encoding: NSUTF8StringEncoding)
            print(result)
        })
        task.resume()
    }
    
    
    func postMessageToCloudDB(lat: String, lng: String, accl: String) {
        // create the url-request
        let urlString = "https://iotmmsp1941995523trial.hanatrial.ondemand.com/com.sap.iotservices.mms/v1/api/http/data/d6e0944c-56d1-48fb-95fb-8582264b84cd"
        var request   = NSMutableURLRequest(URL: NSURL(string: urlString)!)
        
        // set the method(HTTP-POST)
        request.HTTPMethod = "POST"
        // set the headers
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer 9cca13ea513eb5ff66dc8cec9b94f8", forHTTPHeaderField: "Authorization")
        // set the request-body(JSON)
        
        let today = NSDate();
        let sec = floor(today.timeIntervalSince1970)
        
        
        let messages: [String: AnyObject] = [
            "exCordinate" : lat,
            "wiCordinate" : lng,
            "acceleration" : accl,
            "timestamp" : sec
        ]
        
        let messageArray:[AnyObject] = [messages]
        
        let params: [String: AnyObject] = [
            "mode"         : "async",
            "messageType"  : "aa51feb71af64fbb286f",
            "messages"     : messageArray
        ]
        
        //print(params)
        
        do {
            try request.HTTPBody = NSJSONSerialization.dataWithJSONObject(params, options: NSJSONWritingOptions(rawValue: 0))
        } catch let parsingError as NSError {
            print(parsingError.description)
        }
        
        // use NSURLSessionDataTask
        var task = NSURLSession.sharedSession().dataTaskWithRequest(request, completionHandler: {
            (data, response, error) in
            var result = NSString(data: data!, encoding: NSUTF8StringEncoding)
            print(result)
        })
        task.resume()
    }
    
    
    //領域から出た時
    func locationManager(manager: CLLocationManager, didExitRegion region: CLRegion) {
        
        //測定を停止する
        self.trackLocationManager.stopRangingBeaconsInRegion(self.beaconRegion)
        
        reset()
        
        sendLocalNotificationWithMessage("領域から出ました")
        
    }
    
    //観測失敗
    func locationManager(manager: CLLocationManager, monitoringDidFailForRegion region: CLRegion?, withError error: NSError) {
        
        print("monitoringDidFailForRegion \(error)")
        
    }
    
    //通信失敗
    func locationManager(manager: CLLocationManager, didFailWithError error: NSError) {
        
        print("didFailWithError \(error)")
        
    }
    
    //領域内にいるので測定をする
    func locationManager(manager: CLLocationManager, didRangeBeacons beacons: [CLBeacon], inRegion region: CLBeaconRegion) {
        //println(beacons)
        
        if(beacons.count == 0) { return }
        //複数あった場合は一番先頭のものを処理する
        var beacon = beacons[0] as CLBeacon
        
        /*
         beaconから取得できるデータ
         proximityUUID   :   regionの識別子
         major           :   識別子１
         minor           :   識別子２
         proximity       :   相対距離
         accuracy        :   精度
         rssi            :   電波強度
         */
        if (beacon.proximity == CLProximity.Unknown) {
            self.distance.text = "Unknown Proximity"
            reset()
            return
        } else if (beacon.proximity == CLProximity.Immediate) {
            self.distance.text = "Immediate"
        } else if (beacon.proximity == CLProximity.Near) {
            if self.distance.text != "Near" {
                postTimeToSlack()
                takePhoto()
            }
            self.distance.text = "Near"
        } else if (beacon.proximity == CLProximity.Far) {
            self.distance.text = "Far"
        }
        self.status.text   = "領域内です"
        self.uuid.text     = beacon.proximityUUID.UUIDString
        self.major.text    = "\(beacon.major)"
        self.minor.text    = "\(beacon.minor)"
        self.accuracy.text = "\(beacon.accuracy)"
        self.rssi.text     = "\(beacon.rssi)"
        counter = counter + 1;
        //if counter == 1 || counter % 30 == 0 {
            //postMessageToSlack("Beaconの距離感", dist: self.distance.text!, accr: self.accuracy.text!, rsi:self.rssi.text!);
        //}
        print("in Range" + self.accuracy.text!)
        
    }
    
    func reset(){
        self.status.text   = "none"
        self.uuid.text     = "none"
        self.major.text    = "none"
        self.minor.text    = "none"
        self.accuracy.text = "none"
        self.rssi.text     = "none"
        self.distance.text = "none"
    }
    
    //ローカル通知
    func sendLocalNotificationWithMessage(message: String!) {
        print(message)
        let notification:UILocalNotification = UILocalNotification()
        notification.alertBody = message
        
        UIApplication.sharedApplication().scheduleLocalNotification(notification)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    
    /*
     BLEデバイスが検出された際に呼び出される.
     func centralManager(central: CBCentralManager!, didDiscoverPeripheral peripheral: CBPeripheral!, advertisementData: [String]!, RSSI: NSNumber!) {
        print("pheripheral.name: \(peripheral.name)")
        print("advertisementData:\(advertisementData)")
        print("RSSI: \(RSSI)")
        print("peripheral.identifier.UUIDString: \(peripheral.identifier.UUIDString)")
        
        var name: NSString? = advertisementData["kCBAdvDataLocalName"] as? NSString
        if (name == nil) {
            name = "no name";
        }
     }
     */

    
    func centralManager(central: CBCentralManager,
                        didDiscoverPeripheral peripheral: CBPeripheral,
                                              advertisementData: [String : AnyObject],
                                              RSSI: NSNumber!)
    {
        print("peripheral: \(peripheral)")
        print("pheripheral.name: \(peripheral.name)")
        print("advertisementData:\(advertisementData)")
        print("RSSI: \(RSSI)")
        print("peripheral.identifier.UUIDString: \(peripheral.identifier.UUIDString)")
        print();
    }
    
    func centralManagerDidUpdateState(central: CBCentralManager) {
        print("state \(central.state)");
        switch (central.state) {
        case .PoweredOff:
            print("Bluetoothの電源がOff")
        case .PoweredOn:
            print("Bluetoothの電源はOn")
            // BLEデバイスの検出を開始.
            myCentralManager.scanForPeripheralsWithServices(nil, options: nil)
        case .Resetting:
            print("レスティング状態")
        case .Unauthorized:
            print("非認証状態")
        case .Unknown:
            print("不明")
        case .Unsupported:
            print("非対応")
        }
    }
    func updating()  {
        if self.timer.valid {
            self.timer.invalidate()
        }
        
        self.timer = NSTimer.scheduledTimerWithTimeInterval(30, target: self, selector: #selector(updating), userInfo: nil, repeats: true)
        
        // 現在地の取得.
        myLocationManager = CLLocationManager()
        
        myLocationManager.delegate = self
        
        // 取得精度の設定.
        myLocationManager.desiredAccuracy = kCLLocationAccuracyBest
        // 取得頻度の設定.
        myLocationManager.distanceFilter = 15
        myLocationManager.startUpdatingLocation()
        let lat:String = "\(myLocationManager.location!.coordinate.latitude)"
        let lng:String = "\(myLocationManager.location!.coordinate.longitude)"
        
        let alti:String = "\(myLocationManager.location!.altitude)"
        
        let today:String = String(NSDate());
        
        
        /*
        // CMAltimeterが利用できるか(iPhone5SではNoが返ってくる).
        let isAltimeter = CMAltimeter.isRelativeAltitudeAvailable()
        if isAltimeter {
            // Altimeterのモニタリングのスタート.
            myCMAltimeter.startRelativeAltitudeUpdatesToQueue(NSOperationQueue.mainQueue(), withHandler: {
                data, error in
                if error == nil {
                    if alti == "0" {
                        alti = "\(data!.relativeAltitude)"
                        print("altimeter: " + alti)
                    }
                }
            })
        } else {
            print("not use altimeter")
        }
 */
        
        print("updating_now_time:" + NSDate().description)
        postMessageToSlack("[" + today + "]" + "いま、ここにいるにゃー", dist: "緯度：" + lat, accr: "経度:" + lng, rsi:"高度:" + alti);
        print(alti)
        postMessageToCloudDB(lat, lng: lng, accl: alti)
    }
    
    func takePhoto() {
        
        if (self.isBackGround == true) {	
            return
        }
        
        // ビデオ出力に接続.
        let myVideoConnection = myImageOutput.connectionWithMediaType(AVMediaTypeVideo)
        
        // 接続から画像を取得.
        self.myImageOutput.captureStillImageAsynchronouslyFromConnection(myVideoConnection, completionHandler: { (imageDataBuffer, error) -> Void in
            
            // 取得したImageのDataBufferをJpegに変換.
            let myImageData : NSData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageDataBuffer)
            
            // JpegからUIIMageを作成.
            let myImage : UIImage = UIImage(data: myImageData)!
            
            // アルバムに追加.
            UIImageWriteToSavedPhotosAlbum(myImage, self, nil, nil)
            
        })
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        // 登録
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "viewWillEnterForeground:", name: "applicationWillEnterForeground", object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "viewDidEnterBackground:", name: "applicationDidEnterBackground", object: nil)
    }
    
    // AppDelegate -> applicationWillEnterForegroundの通知
    func viewWillEnterForeground(notification: NSNotification?) {
        self.isBackGround = false
    }
    
    // AppDelegate -> applicationDidEnterBackgroundの通知
    func viewDidEnterBackground(notification: NSNotification?) {
        self.isBackGround = true
    }
    
}