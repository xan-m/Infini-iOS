//
//  File.swift
//  InfiniLink
//
//  Created by Alex Emry on 8/18/21.
//
//


import Foundation
import SwiftUI
import SwiftUICharts
import CoreData

struct HeartChart: View {
    @ObservedObject var bleManager = BLEManager.shared
    @ObservedObject var chartManager = ChartManager.shared
    @AppStorage("heartChartFill") var heartChartFill: Bool = true
    @Environment(\.managedObjectContext) var viewContext
    @Environment(\.colorScheme) var colorScheme
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \ChartDataPoint.timestamp, ascending: true)], predicate: NSPredicate(format: "chart == 0"))
    private var chartPoints: FetchedResults<ChartDataPoint>
    
    
    func setLineStyle() -> LineStyle {
        if heartChartFill {
            return LineStyle(lineColour: ColourStyle(colours: [Color.red.opacity(0.7), Color.red.opacity(0.3)], startPoint: .top, endPoint: .bottom), lineType: .curvedLine, ignoreZero: false)
        } else {
            return LineStyle(lineColour: ColourStyle(colour: Color.red), lineType: .curvedLine, ignoreZero: false)
        }
    }
    
    func setGraphType(data: LineChartData) -> some View {
        if heartChartFill {
            return AnyView(FilledLineChart(chartData: data))
        } else {
            return AnyView(LineChart(chartData: data))
        }
    }
    
    var body: some View {
        let dataPoints = ChartManager.shared.convert(results: chartPoints)
        let chartStyle = LineChartStyle(infoBoxPlacement: .floating, baseline: .minimumWithMaximum(of: 50), topLine: .maximum(of: 160))
        let data = LineChartData(dataSets: LineDataSet(dataPoints: ChartManager.shared.convert(results: chartPoints), style: setLineStyle()), chartStyle: chartStyle)
        
        if dataPoints.count > 1 {
            setGraphType(data: data)
                .animation(.easeIn)
                .floatingInfoBox(chartData: data)
                .touchOverlay(chartData: data, unit: .suffix(of: "BPM"))
                .yAxisLabels(chartData: data)
                .padding(.leading)
        } else {
            VStack(alignment: .center, spacing: 14) {
                Spacer()
                Image(systemName: "heart")
                    .imageScale(.large)
                    .font(.system(size: 30).weight(.semibold))
                    .foregroundColor(.red)
                VStack(spacing: 8) {
                    Text(NSLocalizedString("oops!", comment: "").capitalized)
                        .font(.largeTitle.weight(.bold))
                    Text(NSLocalizedString("insufficient_heart_rate_data", comment: ""))
                        .font(.title2.weight(.semibold))
                }
                Spacer()
            }
        }
    }
}

#Preview {
    HeartChart()
}
