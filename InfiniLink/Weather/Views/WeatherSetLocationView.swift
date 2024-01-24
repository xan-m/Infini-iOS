//
//  WeatherSetLocationView.swift
//  InfiniLink
//
//  Created by Liam Willey on 1/22/24.
//

import SwiftUI
import Combine
import MapKit

struct WeatherSetLocationView: View {
    @ObservedObject var weatherController = WeatherController.shared
    
    @AppStorage("setLocation") var setLocation: String = "Cupertino"
    @AppStorage("displayLocation") var displayLocation : String = "Cupertino"
    @StateObject private var mapSearch = MapSearch()
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 0) {
                    HStack(spacing: 15) {
                        Button {
                            presentationMode.wrappedValue.dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .imageScale(.medium)
                                .padding(14)
                                .font(.body.weight(.semibold))
                                .foregroundColor(colorScheme == .dark ? .white : .darkGray)
                                .background(Color.gray.opacity(0.15))
                                .clipShape(Circle())
                        }
                        Text(NSLocalizedString("set_location", comment: ""))
                            .foregroundColor(.primary)
                            .font(.title.weight(.bold))
                        Spacer()
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
                    Divider()
                    VStack {
                        VStack {
                            TextField("Address", text: $mapSearch.searchTerm)
                                .padding()
                                .background(Color.gray.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        .padding()
                        Form {
                            ForEach(mapSearch.locationResults, id: \.self) { location in
                                Button {
                                    displayLocation = location.title
                                    setLocation = "\(location.title), \(location.subtitle)"
                                    weatherController.tryRefreshingWeatherData()
                                    presentationMode.wrappedValue.dismiss()
                                } label: {
                                    VStack(alignment: .leading) {
                                        Text(location.title)
                                        Text(location.subtitle)
                                            .font(.system(.caption))
                                    }
                                }
                                .foregroundColor(Color(UIColor.gray))
                            }
                        }
                    }
                }
                .navigationBarBackButtonHidden()
    }
}
    
    

class MapSearch : NSObject, ObservableObject {
    @Published var locationResults : [MKLocalSearchCompletion] = []
    @Published var searchTerm = ""
    
    private var cancellables : Set<AnyCancellable> = []
    
    private var searchCompleter = MKLocalSearchCompleter()
    private var currentPromise : ((Result<[MKLocalSearchCompletion], Error>) -> Void)?
    
    override init() {
        super.init()
        searchCompleter.delegate = self
        searchCompleter.region = MKCoordinateRegion(.world)
        searchCompleter.resultTypes = MKLocalSearchCompleter.ResultType([.address])
        
        $searchTerm
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .removeDuplicates()
            .flatMap({ (currentSearchTerm) in
                self.searchTermToResults(searchTerm: currentSearchTerm)
            })
            .sink(receiveCompletion: { (completion) in
                //handle error
            }, receiveValue: { (results) in
                self.locationResults = results
            })
            .store(in: &cancellables)
    }
    
    func searchTermToResults(searchTerm: String) -> Future<[MKLocalSearchCompletion], Error> {
        Future { promise in
            self.searchCompleter.queryFragment = searchTerm
            self.currentPromise = promise
        }
    }
}

extension MapSearch : MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
            currentPromise?(.success(completer.results))
        }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        //currentPromise?(.failure(error))
    }
}

//
//#Preview {
//    WeatherSetLocationView()
//}
