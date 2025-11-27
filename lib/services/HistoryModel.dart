class HistoryModel {
  bool? success;
  String? message;
  List<Data>? data;

  HistoryModel({this.success, this.message, this.data});

  HistoryModel.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    message = json['message'];
    if (json['data'] != null) {
      data = <Data>[];
      json['data'].forEach((v) {
        data!.add(new Data.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['success'] = this.success;
    data['message'] = this.message;
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Data {
  String? date;
  List<Records>? records;

  Data({this.date, this.records});

  Data.fromJson(Map<String, dynamic> json) {
    date = json['date'];
    if (json['records'] != null) {
      records = <Records>[];
      json['records'].forEach((v) {
        records!.add(new Records.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['date'] = this.date;
    if (this.records != null) {
      data['records'] = this.records!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Records {
  String? id;
  String? staffId;
  String? date;
  String? typeCheck;
  String? type;
  String? routePointId;
  String? workplaceId;
  String? lat;
  String? long;
  String? address;
  String? ip;
  String? deviceType;
  String? deviceFingerprint;
  String? distance;

  Records(
      {this.id,
        this.staffId,
        this.date,
        this.typeCheck,
        this.type,
        this.routePointId,
        this.workplaceId,
        this.lat,
        this.long,
        this.address,
        this.ip,
        this.deviceType,
        this.deviceFingerprint,
        this.distance});

  Records.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    staffId = json['staff_id'];
    date = json['date'];
    typeCheck = json['type_check'];
    type = json['type'];
    routePointId = json['route_point_id'];
    workplaceId = json['workplace_id'];
    lat = json['lat'];
    long = json['long'];
    address = json['address'];
    ip = json['ip'];
    deviceType = json['device_type'];
    deviceFingerprint = json['device_fingerprint'];
    distance = json['distance'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['staff_id'] = this.staffId;
    data['date'] = this.date;
    data['type_check'] = this.typeCheck;
    data['type'] = this.type;
    data['route_point_id'] = this.routePointId;
    data['workplace_id'] = this.workplaceId;
    data['lat'] = this.lat;
    data['long'] = this.long;
    data['address'] = this.address;
    data['ip'] = this.ip;
    data['device_type'] = this.deviceType;
    data['device_fingerprint'] = this.deviceFingerprint;
    data['distance'] = this.distance;
    return data;
  }
}
