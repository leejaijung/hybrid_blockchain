// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract ColdChainTrakingV4 {

    event deliverRegistEvent(uint32 round, string article);//배송등록
    event deliverTempOutBoundEvent(uint32 round, int24 temperature);//온도이탈 발생
    event deliverHumOutBoundEvent(uint32 round, int24 humidity);//습도이탈 발생
    event deliverVibOutBoundEvent(uint32 round, int24 vibration);//진동이탈 발생
    event traceEvent(bool isTemperatureOutBound, bool isHumidityOutBound, bool isVibrationOutBound);//이탈 발생여부
    
    event certificatesRegistEvent(string _certNum);//인증서 발급

    struct Deliver {
        uint8 stat; //현재상태 0:초기, 1:배송시작, 2:배송완료

        string article;//의약품 정보 json
        string articleDetail;//의약품 정보 상세 json
        
        bool checkTemperatureOutBound;//온도이탈체크여부
        bool checkHumidityOutBound;//습도이탈체크여부
        bool checkVibrationOutBound;//진동이탈체크여부 

        bool isTemperatureOutBound;//온도이탈발생여부
        bool isHumidityOutBound;//습도이탈발생여부
        bool isVibrationOutBound;//진동이탈발생여부

        int24 temperatureOutBound1;//기준온도 시작 온도*1000, -99000 이상
        int24 temperatureOutBound2;//기준온도 종료 온도*1000
        int24 humidityOutBound1;//기준습도 시작 습도*1000, -99000 이상
        int24 humidityOutBound2;//기준습도 종료 습도*1000
        int24 vibrationOutBound1;//기준진동 시작 진동*1000, -99000 이상
        int24 vibrationOutBound2;//기준진동 종료 진동*1000

        uint tempTimeOut;//온도이탈 지속시간
        uint humiTimeOut;//습도이탈 지속시간
        uint vibrTimeOut;//진동이탈 지속시간

        uint startTempTimeOut;//온도이탈 발생시간
        uint startHumiTimeOut;//습도이탈 발생시간
        uint startVibrTimeOut;//진동이탈 발생시간
        
        uint startTime;//배송시작시간
        uint endTime;//배송종료시간
        uint timestamp;//등록시간

        Trace[] tracking;//트래킹
        string[] certificates;
    }

    struct Trace {
        int64 latitude;//위도, 위도*10000000000
        int64 longitude;//경도, 경도*10000000000
        int24 temperature;//온도 온도*1000
        int24 humidity;//습도 습도*1000
        int24 vibration;//진동 진동*1000
        bool isTemperatureOutBound;//온도이탈발생여부
        bool isHumidityOutBound;//습도이탈발생여부
        bool isVibrationOutBound;//진동이탈발생여부
        uint deviceDt;//디바이스시간
        uint timestamp;//등록시간
        int24 aiStatus;//AI 예측 0 : 정상, 1 : 시작 일탈, 2 : 오픈 일탈, 3 : 상향 일탈, 4 : 하향 일탈
    }

    struct Certificate {
        string name; //이름
        uint32 deliverId;
        uint timestamp;//시간
    }

    address owner;
    mapping (uint32=> Deliver) deliverList; //배송종류
    mapping (string=> Certificate) certificateList; //인증서발행

    uint32 public round = 0; //라운드 1부터 시작
    
    constructor() {
        owner = msg.sender;
    }

    // 배송을 하기위한 물품 정보 등록
    function addDelivery(string memory _article, string memory _articleDetail, int24 _temperatureOutBound1, int24 _temperatureOutBound2
                          , int24 _humidityOutBound1, int24 _humidityOutBound2, int24 _vibrationOutBound1, int24 _vibrationOutBound2) public returns (uint32) {
        require(owner == msg.sender);

        round++;
        Deliver storage deliver = deliverList[round];
        //deliver.number = 0;
        deliver.stat = 0;
        deliver.article = _article;
        deliver.articleDetail = _articleDetail;
        deliver.isTemperatureOutBound = false;
        deliver.isHumidityOutBound = false;
        deliver.isVibrationOutBound = false;

        deliver.temperatureOutBound1 = _temperatureOutBound1;
        deliver.temperatureOutBound2 = _temperatureOutBound2;
        deliver.humidityOutBound1 = _humidityOutBound1;
        deliver.humidityOutBound2 = _humidityOutBound2;
        deliver.vibrationOutBound1 = _vibrationOutBound1;
        deliver.vibrationOutBound2 = _vibrationOutBound2;

        deliver.startTempTimeOut = 0;
        deliver.startHumiTimeOut = 0;
        deliver.startVibrTimeOut = 0;

        if(_temperatureOutBound1>-99000) {//-99 이상일때만 체크
            deliver.checkTemperatureOutBound = true;
        } else {
            deliver.checkTemperatureOutBound = false;
        }

        if(_humidityOutBound1>-99000) {//-99 이상일때만 체크
            deliver.checkHumidityOutBound = true;
        } else {
            deliver.checkHumidityOutBound = false;
        }

        if(_vibrationOutBound1>-99000) {//-99 이상일때만 체크
            deliver.checkVibrationOutBound = true;
        } else {
            deliver.checkVibrationOutBound = false;
        }
        deliver.timestamp = block.timestamp;

        emit deliverRegistEvent(round, _article);

        return round;
    }

    //온도, 습도, 진도 이탈 지속시간 설정
    function setDeliveryTimeOut(uint32 _round, uint _tempTimeOut, uint _humiTimeOut, uint _vibrTimeOut) public {
        require(owner == msg.sender);
        require(deliverList[_round].timestamp != 0);//비어있는지체크
        require(deliverList[_round].stat == 0);

        Deliver storage deliver = deliverList[_round];
        deliver.tempTimeOut = _tempTimeOut;
        deliver.humiTimeOut = _humiTimeOut;
        deliver.vibrTimeOut = _vibrTimeOut;
    }
    
    // 물품 정보 수정
    function updateDelivery(uint32 _round, string memory _article, string memory _articleDetail, int24 _temperatureOutBound1, int24 _temperatureOutBound2
                                               , int24 _humidityOutBound1, int24 _humidityOutBound2, int24 _vibrationOutBound1, int24 _vibrationOutBound2) public {
        require(owner == msg.sender);
        require(deliverList[_round].timestamp != 0);//비어있는지체크
        require(deliverList[_round].stat == 0);

        Deliver storage deliver = deliverList[_round];
        deliver.article = _article;
        deliver.articleDetail = _articleDetail;
        deliver.isTemperatureOutBound = false;
        deliver.isHumidityOutBound = false;
        deliver.isVibrationOutBound = false;

        deliver.temperatureOutBound1 = _temperatureOutBound1;
        deliver.temperatureOutBound2 = _temperatureOutBound2;
        deliver.humidityOutBound1 = _humidityOutBound1;
        deliver.humidityOutBound2 = _humidityOutBound2;
        deliver.vibrationOutBound1 = _vibrationOutBound1;
        deliver.vibrationOutBound2 = _vibrationOutBound2;

        if(_temperatureOutBound1>-99000) {//-99 이상일때만 체크
            deliver.checkTemperatureOutBound = true;
        } else {
            deliver.checkTemperatureOutBound = false;
        }

        if(_humidityOutBound1>-99000) {//-99 이상일때만 체크
            deliver.checkHumidityOutBound = true;
        } else {
            deliver.checkHumidityOutBound = false;
        }

        if(_vibrationOutBound1>-99000) {//-99 이상일때만 체크
            deliver.checkVibrationOutBound = true;
        } else {
            deliver.checkVibrationOutBound = false;
        }
    }

    
    // 배송시작
    function startTraking(uint32 _round, uint startDt) public {
        require(owner == msg.sender);
        // Deliver storage deliver = deliverList[_round];
        require(deliverList[_round].timestamp != 0);//비어있는지체크
        require(deliverList[_round].stat == 0);

        deliverList[_round].stat = 1;
        deliverList[_round].startTime = startDt;
    }

    // 배송종료
    function endTraking(uint32 _round, uint endDt) public {
        require(owner == msg.sender);
        // Deliver storage deliver = deliverList[_round];
        require(deliverList[_round].timestamp != 0);//비어있는지체크
        require(deliverList[_round].stat == 1);

        deliverList[_round].stat = 2;
        deliverList[_round].endTime = endDt;
    }

    // 운송정보 추가
    function addTraking(uint32 _round, int64 _latitude, int64 _longitude, int24 _temperature, int24 _humidity, int24 _vibration, uint deviceDt, int24 aiStatus) public returns(Trace memory){
        require(owner == msg.sender);
        require(deliverList[_round].timestamp != 0);//비어있는지체크
        Deliver storage deliver = deliverList[_round];

        if(deliver.stat == 0) {
            startTraking(_round, block.timestamp);
        }

        require(deliver.stat == 1);

        bool isTempOutBound = false;
        bool isHumidityOutBound = false;
        bool isVibrationOutBound = false;

        if(deliver.checkTemperatureOutBound && (deliver.temperatureOutBound1>_temperature || deliver.temperatureOutBound2<_temperature)) {
            //온도이탈여부
            if((deliver.tempTimeOut == 0) || (deliver.startTempTimeOut>0 && (block.timestamp - deliver.startTempTimeOut >= deliver.tempTimeOut))) {
                isTempOutBound = true;
                deliver.isTemperatureOutBound = true;
                emit deliverTempOutBoundEvent(_round, _temperature);
            }
            if(deliver.startTempTimeOut==0) {
                deliver.startTempTimeOut = block.timestamp;
            }
        } else {
            deliver.startTempTimeOut = 0;
        }

        if(deliver.checkHumidityOutBound && (deliver.humidityOutBound1>_humidity || deliver.humidityOutBound2<_humidity)) {
            //습도이탈여부
            if((deliver.humiTimeOut == 0) || (deliver.startHumiTimeOut>0 && (block.timestamp - deliver.startHumiTimeOut >= deliver.humiTimeOut))) {
                isHumidityOutBound = true;
                deliver.isHumidityOutBound = true;
                emit deliverHumOutBoundEvent(_round, _humidity);
            }
            if(deliver.startHumiTimeOut==0) {
                deliver.startHumiTimeOut = block.timestamp;
            }
        } else {
            deliver.startHumiTimeOut = 0;
        }

        if(deliver.checkVibrationOutBound && (deliver.vibrationOutBound1>_vibration || deliver.vibrationOutBound2<_vibration)) {
            //진동이탈여부
            if((deliver.vibrTimeOut==0) || (deliver.startVibrTimeOut>0 && (block.timestamp - deliver.startVibrTimeOut >= deliver.vibrTimeOut))) {
                isVibrationOutBound = true;
                deliver.isVibrationOutBound = true;
                emit deliverVibOutBoundEvent(_round, _vibration);
            }
            if(deliver.startVibrTimeOut==0) {
                deliver.startVibrTimeOut = block.timestamp;
            }
        } else {
            deliver.startVibrTimeOut = 0;
        }

        Trace memory trace = Trace(_latitude, _longitude, _temperature, _humidity, _vibration, isTempOutBound, isHumidityOutBound, isVibrationOutBound, deviceDt, block.timestamp, aiStatus);
        deliver.tracking.push(trace);
        
        emit traceEvent(isTempOutBound, isHumidityOutBound, isVibrationOutBound);
        return trace;
    }

    // 물품정보
    function getDeliveryInfo(uint32 _round) public view returns (uint8, string memory, string memory, uint, uint, uint) {
        require(deliverList[_round].timestamp != 0);//비어있는지체크
        return (deliverList[_round].stat, deliverList[_round].article, deliverList[_round].articleDetail, deliverList[_round].startTime, deliverList[_round].endTime, deliverList[_round].timestamp);
    }

    // 물품체크항목
    function getDeliveryCheckInfo(uint32 _round) public view returns (bool, bool, bool, bool, bool, bool, int24, int24, int24, int24, int24, int24) {
        require(deliverList[_round].timestamp != 0);//비어있는지체크
        Deliver storage deliver = deliverList[_round];

        return (deliver.checkTemperatureOutBound, deliver.checkHumidityOutBound, deliver.checkVibrationOutBound
        , deliver.isTemperatureOutBound, deliver.isHumidityOutBound, deliver.isVibrationOutBound
        , deliver.temperatureOutBound1, deliver.temperatureOutBound2, deliver.humidityOutBound1, deliver.humidityOutBound2
        , deliver.vibrationOutBound1, deliver.vibrationOutBound2);
    }

    //온도이탈 지속시간 가져오기
    function getDeliveryTimeOut(uint32 _round) public view returns (uint, uint, uint) {
        require(deliverList[_round].timestamp != 0);//비어있는지체크
        return (deliverList[_round].tempTimeOut, deliverList[_round].humiTimeOut, deliverList[_round].vibrTimeOut);
    }

    // 배송상태
    function getStat(uint32 _round) public view returns (uint8) {
        require(deliverList[_round].timestamp != 0);//비어있는지체크
        return deliverList[_round].stat;
    }

    // 트래킹리스트
    function getRoundTraking(uint32 _round) public view returns(Trace[] memory) {
        require(deliverList[_round].timestamp != 0);//비어있는지체크
        return deliverList[_round].tracking;
    }

    // 마지막 트래킹 정보
    function getRoundLastTraking(uint32 _round) public view returns(Trace memory) {
        require(deliverList[_round].timestamp != 0);//비어있는지체크
        return deliverList[_round].tracking[deliverList[_round].tracking.length-1];
    }

    // 배송 인증서 발급 정보
    function getRoundCertificate(uint32 _round)  public view returns(string[] memory) {
        return deliverList[_round].certificates;
    }

    // 인증서 발급
    function generateCertificate(string memory _certNum, string memory _name, uint32 _round) public {
        require(owner == msg.sender);

        Deliver storage deliver = deliverList[_round];
        require(!deliver.isTemperatureOutBound);//온도이탈체크
        require(!deliver.isHumidityOutBound);//습도이탈체크
        require(!deliver.isVibrationOutBound);//진동이탈체크
        require(deliver.stat == 2);//배송완료체크
        require(certificateList[_certNum].timestamp == 0);//이미 발급이 되었는지 체크

        Certificate storage certificate = certificateList[_certNum];        
        certificate.name = _name;
        certificate.deliverId = _round;
        certificate.timestamp = block.timestamp;

        emit certificatesRegistEvent(_certNum);
        deliver.certificates.push(_certNum);
    }

    // 인증서정보
    function getCertificate(string memory _certNum) public view returns (Certificate memory) {
        return certificateList[_certNum];
    }
}