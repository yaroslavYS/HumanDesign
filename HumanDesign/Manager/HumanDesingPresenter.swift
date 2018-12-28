//
//  HumanDesingPresenter.swift
//  HumanDesign
//
//  Created by Pavlo Kharambura on 12/18/18.
//  Copyright © 2018 Pavlo Kharambura. All rights reserved.
//

import Foundation
import FirebaseDatabase

enum PickerDataType {
    case Day
    case Month
    case Year
    case Time
    case Country
    case City
    case Approximately
}

enum ComputationType: String {
    case PersonalMap = "PersonalMap"
    case FindLove = "FindLove"
}

class HumanDesignPresenter {
    
    static let shared = HumanDesignPresenter()
    var dataSource = HumanDesignDataSource()
    private var pickerType: PickerDataType = .Day

    fileprivate let backendService = BackendService()

    func getPickerType() -> PickerDataType {
        return pickerType
    }
    func setPickerType(type: PickerDataType) {
        pickerType = type
    }
    func getDataForPicker() -> [String] {
        var data: [String] = []
        
        switch pickerType {
        case .Day:
            data = dataSource.getDays().map {"\($0)"}
        case .Country:
            data = dataSource.getContries()
        case .City:
            if dataSource.getUser().country == "Украина" {
                data = dataSource.getUaPlaces()
            } else {
                data = dataSource.getRuPlaces()
            }
        case .Month:
            data = dataSource.getMonths()
        case .Year:
            data = dataSource.getYears().map {"\($0)"}
        case .Approximately:
            data = dataSource.getApproximately()
        case .Time:
            data = dataSource.getTime()
        }
        return data
    }
    func setDataFromPicker(index: Int) {
        var data = String()
        switch pickerType {
        case .Day:
            data = dataSource.getDays().map {"\($0)"}[index]
            dataSource.setDay(day: Int(data)!)
        case .Country:
            data = dataSource.getContries()[index]
            dataSource.setCountry(country: data)
        case .City:
            if dataSource.getUser().country == "Украина" {
                data = dataSource.getUaPlaces()[index]
            } else {
                data = dataSource.getRuPlaces()[index]
            }
            dataSource.setCity(city: data)
        case .Month:
            dataSource.setMonth(month: index)
        case .Year:
            dataSource.setYear(year: dataSource.getYears()[index])
        case .Approximately:
            data = dataSource.getApproximately()[index]
            let array = data.components(separatedBy: ":")
            dataSource.setHour(hour: Int(array.first ?? "0")!)
            dataSource.setMinute(min: Int(array.last ?? "0")!)
        case .Time:
            data = dataSource.getTime()[index]
            let array = data.components(separatedBy: ":")
            dataSource.setHour(hour: Int(array.first ?? "0")!)
            dataSource.setMinute(min: Int(array.last ?? "0")!)
        }
        
    }
    func getCountForPicker() -> Int {
        
        return getDataForPicker().count
    }
    
    func getUser() -> UserModel {
        return dataSource.getUser()
    }
    
    private func modifyDate(d:Int,m:Int,y:Int,h:Int,utc:Int) -> (Int,Int,Int,Int) {
        var day = d
        var month = m
        var year = y
        var hour = h
        let utc = utc
        
        let difference = hour - utc
        if difference < 0 {
            if day == 1 {
                if month == 1 {
                    month = 12
                    day = 31
                    hour = 24+difference
                    year -= 1
                } else {
                    month -= 1
                    switch month {
                    case 4,6,9,11:
                        day = 30
                    case 2:
                        if year % 4 == 0 {
                            day = 29
                        } else {
                            day = 28
                        }
                    default:
                        day = 31
                    }
                    hour = 24+difference
                }
            } else {
                day -= 1
                hour = 24+difference
            }
        } else {
            hour -= utc
        }
        return (day,month,year,hour)
    }
    
    func getGraphInfo(success: @escaping ()->(), failure: @escaping (_ error: Error)-> (), internetError: @escaping ()->()) {
        if InternetReachability.isConnectedToNetwork() {

            let minute = dataSource.getUser().birthMinute
            
            let dateComp = modifyDate(d: dataSource.getUser().birthDay, m: dataSource.getUser().birthMonth+1, y: dataSource.getUser().birthYear, h: dataSource.getUser().birthHour, utc: dataSource.getUser().UTC)

            let request = BodyGraphAPIRequest(day: dateComp.0, month: dateComp.1, year: dateComp.2, hour: dateComp.3, minute: minute)
            
            backendService.request(request: request, success: { (json) in
                guard let json = json as? [String: Any] else {
                    return
                }
                let userInfo = GraphMapper.mapJSON(json: json)
                self.dataSource.setUserInfo(info: userInfo)
                DispatchQueue.main.async {
                    success()
                }
            }) { (error) in
                DispatchQueue.main.async {
                   failure(error)
                }
            }
        } else {
            DispatchQueue.main.async {
                internetError()
            }
        }
    }
    
    func sendEmailTo(type: ComputationType, email: String, success: @escaping ()->(), failure: @escaping (_ error: Error)->()) {
      
        let info = "\(String(format: "%02d",getUser().birthDay)).\(String(format: "%02d", getUser().birthMonth)).\(String(format: "%04d", getUser().birthYear)), \(String(format: "%02d", getUser().birthHour)):\(String(format: "%02d", getUser().birthMinute)), \(getUser().city)"
        
        let params = ["email": email,
                      "info": info]
        
        Database.database().reference().child(type.rawValue).child(UUID().uuidString).setValue(params) { (error, ref) in
            if let error = error {
                failure(error)
            } else {
                success()
            }
        }
    }
    
}

class HumanDesignDataSource {
    
    private var user = UserModel()

    func setUserInfo(info: UserInfo) {
        user.info = info
    }
    
    func getUser() -> UserModel {
        return user
    }
    
    func setDay(day: Int) {
        user.birthDay = day
    }
    func setMonth(month: Int) {
        user.birthMonth = month
    }
    func setYear(year: Int) {
        user.birthYear = year
    }
    func setHour(hour: Int) {
        user.birthHour = hour
    }
    func setMinute(min: Int) {
        user.birthMinute = min
    }
    func setCountry(country: String) {
        user.country = country
    }
    func setCity(city: String) {
        user.UTC = 2
        for city_ in CityManager.russianPlaces {
            let array = city.components(separatedBy: ")-")
            if city_.value.contains(array.last ?? "") {
                user.UTC = Int(city_.key) ?? 0
            }
        }
        let array = city.components(separatedBy: ")-")
        user.city = array.last ?? city
    }
    
    func getYears() -> [Int] {
        var years = [Int]()
        for i in 1930...2018 {
            years.insert(i, at: 0)
        }
        return years
    }
    func getDays() -> [Int] {
        var days = [Int]()
        for i in 1...31 {
            days.append(i)
        }
        return days
    }
    func getMonths() -> [String] {
        return ["Январь", "Февраль", "Март", "Апрель", "Май", "Июнь", "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"]
    }
    func getContries() -> [String] {
        return ["Украина", "Россия"]
    }
    func getUaPlaces() -> [String] {
        return CityManager.ukrainianPlaces
    }
    func getRuPlaces() -> [String] {
        var data = [String]()
        for item in CityManager.russianPlaces {
            let places = item.value.map {"(UTC:+\(item.key))-\($0)"}
            data.append(contentsOf: places)
        }
        return data
    }
    func getApproximately() -> [String] {
        return ["03:00", "09:00", "15:00", "21:00"]
    }
    func getTime() -> [String] {
        var data: [String] = []
        let hours = ["00","01","02","03","04","05","06","07","08","09","10","11","12","13","14","15","16","17","18","19","20","21","22","23"]
        let minutes = ["00","05","10","15","20","25","30","35","40","45","50","55"]
        for hour in hours {
            for minute in minutes {
                data.append(hour+":"+minute)
            }
        }
        return data
    }
    
}

enum TypeInfoState {
    case type
    case profile
}

class UserProfileTypeManager {
    
    static var state: TypeInfoState = .type
    static let profiles = [ProfileModel]()
    static let types = ProfilesTypes.types
    static var selectedProfile: ProfileModel?
    static var selectedType: TypeModel?
    
//    static func convertTypeName(from name: String) -> String {
//
//    }
    
    static func getType(by nameId: String) -> TypeModel? {
        return types.first(where: {$0.id == nameId})
    }
    
    static func getProfile(by nameId: String) -> ProfileModel? {
        return profiles.first(where: {$0.id == nameId})
    }
    static func getProfilesCount() -> Int {
        return profiles.count
    }
    static func getTypesCount() -> Int {
        return types.count
    }
}

class ProfilesTypes {
    static let types: [TypeModel] = [
        TypeModel(id: "projector", name: "Проектор", image: UIImage(named: "Проектор")!, info: "Проектор,проектор,проектор,проектор,проектор,проектор,проектор,проектор,проектор,проектор,проектор,проектор,проектор,проектор,проектор,проектор,проектор", peoples: "Бред Пит,Бред Пит,Бред Пит,Бред Пит"),
        TypeModel(id: "reflector", name: "Рефлектор", image: UIImage(named: "Рефлектор")!, info: "Рефлектор,Рефлектор,Рефлектор,Рефлектор,Рефлектор,Рефлектор", peoples: "Джони Депп,Джони Депп,Джони Депп,Джони Депп"),
        TypeModel(id: "manifestor", name: "Манифестор", image: UIImage(named: "Манифестор")!, info: "Манифестор,Манифестор,Манифестор,Манифестор,Манифестор,Манифестор,Манифестор", peoples: "Анджелина Джоли,Анджелина Джоли,Анджелина Джоли,Анджелина Джоли"),
        TypeModel(id: "generator", name: "Генератор", image: UIImage(named: "Генератор")!, info: "Генератор,Генератор,Генератор,Генератор,Генератор,Генератор", peoples: "Леонардо Дикаприо,Леонардо Дикаприо,Леонардо Дикаприо,Леонардо Дикаприо"),
        TypeModel(id: "mangenerator", name: "Манифестирующий генератор", image: UIImage(named: "Манифестирующий генератор")!, info: "Манифестирующий генератор,Манифестирующий генератор,Манифестирующий генератор,Манифестирующий генератор", peoples: "Джимм Керри,Джимм Керри,Джимм Керри,Джимм Керри")
    ]
}

class CityManager {
    static let russianPlaces = [
        "2": ["Калининградская обл."],
        "3": ["Санкт-Петербург", "Севастополь", "Респ. Адыгея", "Респ. Дагестан", "Респ. Ингушетия", "Кабардино-Балкарская Респ.", "Респ. Калмыкия", "Респ. Крым", "Карачаево-Черкесская Респ.", "Респ. Карелия", "Респ. Коми", "Респ. Марий Эл", "Респ. Мордовия", "Респ. Северная Осетия — Алания", "Респ. Татарстан", "Чеченская Респ.", "Чувашская Респ.", "Краснодарский край", "Ставропольский край", "Архангельская обл.", "Астраханская обл.", "Белгородская обл.", "Брянская обл.", "Владимирская обл.", "Волгоградская обл.", "Вологодская обл.", "Воронежская обл.", "Ивановская обл.", "Калужская обл.", "Кировская обл.", "Костромская обл.", "Курская обл.", "Ленинградская обл.", "Липецкая обл.", "Московская обл.", "Мурманская обл.", "Нижегородская обл.", "Новгородская обл.", "Орловская обл.", "Пензенская обл.", "Псковская обл.", "Ростовская обл.", "Рязанская обл.", "Саратовская обл.", "Смоленская обл.", "Тамбовская обл.", "Тверская обл.", "Тульская обл.", "Ульяновская обл.", "Ярославская обл.", "Ненецкий автономный округ"],
        "4": ["Самарская обл.", "Респ. Удмуртия"],
        "5": ["Респ. Башкортостан", "Пермский край", "Курганская обл.", "Оренбургская обл.", "Свердловская обл.", "Тюменская обл.", "Челябинская обл.", "Ямало-Ненецкий автономный округ"],
        "6": ["Респ. Алтай", "Алтайский край", "Новосибирская обл.", "Омская обл.", "Томская обл."],
        "7": ["Респ. Тыва", "Респ. Хакасия", "Красноярский край", "Кемеровская обл."],
        "8": ["Респ. Бурятия", "Забайкальский край", "Иркутская обл."],
        "9": ["часть Респ. Саха (Якутия)", "Амурская обл."],
        "10": ["Приморский край", "Хабаровский край", "Магаданская обл.", "Сахалинская обл. (кроме Северо-Курильского района)", "Еврейская автономная обл."],
        "11": ["Сахалинская обл. (только Северо-Курильский район)"],
        "12": ["Камчатский край", "Чукотский автономный округ"]
    ]
    static let ukrainianPlaces = ["Винницкая Обл.", "Волынская Обл.", "Днепропетровская Обл.", "Донецкая Обл.", "Житомирская Обл.", "Закарпатская Обл.", "Запорожская Обл.", "Ивано-Франковская Обл.", "Киевская Обл.", "Кировоградская Обл.", "Курорт Буковель", "Луганская Обл.", "Львовская Обл.", "Николаевская Обл.", "Одесская Обл.", "Полтавская Обл.", "Ровенская Обл.", "Сумская Обл.", "Тернопольская Обл.", "Харьковская Обл.", "Херсонская Обл.", "Хмельницкая Обл.", "Черкасская Обл.", "Черниговская Обл.", "Черновицкая Обл."]
}