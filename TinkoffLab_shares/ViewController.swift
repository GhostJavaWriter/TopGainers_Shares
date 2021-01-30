//
//  ViewController.swift
//  TinkoffLab_shares
//
//  Created by Bair Nadtsalov on 30.01.2021.
//

import UIKit

struct Company: Codable {

    var symbol : String
    var companyName : String
}

struct Companies: Codable {
    
    var companies : [Company]
}

class ViewController: UIViewController {

//MARK: - UI
    @IBOutlet weak var companyNameLabel: UILabel!
    @IBOutlet weak var companyPickerView: UIPickerView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var companySymbolLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var priceChangeLabel: UILabel!
    @IBOutlet weak var logoImageView: UIImageView!
    
//MARK: - Private
    
    private var companies : [Company]?
    
    private func requestLogo(for symbol: String) {
        let token = "pk_6c24b6cc33d54294a13534407c85770a"
        guard let logoUrl = URL(string: "https://cloud.iexapis.com/stable/stock/\(symbol)/logo?&token=\(token)") else { return
        }
        
        let dataTask = URLSession.shared.dataTask(with: logoUrl) { [weak self] (data, response, error) in
            
            if let data = data, (response as? HTTPURLResponse)?.statusCode == 200, error == nil {
                self?.getLogo(from: data)
            } else {
                print("Network error!")
            }
        }
        
        dataTask.resume()
    }
    
    private func getLogo(from data: Data) {
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data)
            guard
                let json = jsonObject as? [String: Any],
                let logo = json["url"] as? String else { return print("Invalid JSON") }
            displayLogo(urlString: logo)
        } catch {
            print("JSON parsing error (request logo)")
        }
    }
    
    private func displayLogo(urlString: String) {
        guard let url = URL(string: urlString) else { return print("wrong image URL")}
        logoImageView.load(url: url)
    }
    
    private func requestQuote(for symbol: String) {
        let token = "pk_6c24b6cc33d54294a13534407c85770a"
        guard let url = URL(string: "https://cloud.iexapis.com/stable/stock/\(symbol)/quote?&token=\(token)") else {
            return
        }
        
        let dataTask = URLSession.shared.dataTask(with: url) { [weak self] (data, response, error) in
            if let data = data, (response as? HTTPURLResponse)?.statusCode == 200, error == nil {
                self?.parseQuote(from: data)
            } else {
                print("Network error!")
            }
        }
        dataTask.resume()
    }
    
    private func parseQuote(from data: Data) {
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data)
            guard
                let json = jsonObject as? [String: Any],
                let companyName = json["companyName"] as? String,
                let companySymbol = json["symbol"] as? String,
                let price = json["latestPrice"] as? Double,
                let priceChange = json["change"] as? Double else { return print("Invalid JSON") }
            
            DispatchQueue.main.async { [weak self] in
                self?.displayStockInfo(companyName: companyName,
                                       companySymbol: companySymbol,
                                       price: price,
                                       priceChange: priceChange)
            }
        } catch {
            print("JSON parsing error: " + error.localizedDescription)
        }
    }
    
    private func displayStockInfo(companyName: String,
                                  companySymbol: String,
                                  price: Double,
                                  priceChange: Double) {
        activityIndicator.stopAnimating()
        companyNameLabel.text = companyName
        companySymbolLabel.text = companySymbol
        priceLabel.text = "\(price)"
        priceChangeLabel.text = "\(priceChange)"
        
        if priceChange < 0 {
            priceChangeLabel.textColor = .red
        } else if priceChange > 0 {
            priceChangeLabel.textColor = .green
        }
    }
    
    private func requestQuoteUpdate() {
        activityIndicator.startAnimating()
        companyNameLabel.text = "-"
        companySymbolLabel.text = "-"
        priceLabel.text = "-"
        priceChangeLabel.text = "-"
        priceChangeLabel.textColor = .black
        logoImageView.image = UIImage(named: "defaultLogo")
        
        let selectedRow = companyPickerView.selectedRow(inComponent: 0)
        let selectedSymbol = companies?[selectedRow].symbol
        
        guard let selectedSymb = selectedSymbol else { return }
        
        requestQuote(for: selectedSymb)
        requestLogo(for: selectedSymb)
    }
    
    private func requestCompaniesList() {
        let token = "pk_6c24b6cc33d54294a13534407c85770a"
        guard let url = URL(string: "https://cloud.iexapis.com/stable/stock/market/list/gainers?&token=\(token)") else {
            return
        }
        
        let dataTask = URLSession.shared.dataTask(with: url) { [weak self] (data, response, error) in
            if let data = data, (response as? HTTPURLResponse)?.statusCode == 200, error == nil {
                self?.loadCompaniesList(from: data)
                
                DispatchQueue.main.async {
                    self?.companyPickerView.reloadAllComponents()
                    self?.requestQuoteUpdate()
                }
            } else {
                print("Network error!")
            }
        }
        dataTask.resume()
    }
    
    private func loadCompaniesList(from data: Data) {
        let decoder = JSONDecoder()
        if let jsonData = try? decoder.decode([Company].self, from: data) {
            companies = jsonData
        } else {
            print("json decode error")
        }
    }
    
    //MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        companyNameLabel.text = "Tinkoff"
        companyPickerView.dataSource = self
        companyPickerView.delegate = self
        
        activityIndicator.hidesWhenStopped = true
        requestCompaniesList()
        requestQuoteUpdate()
    }
}

//MARK: - UIPickerViewDataSource
extension ViewController: UIPickerViewDataSource {
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return companies?.count ?? 0
    }
}

//MARK: - UIPickerViewDelegate
extension ViewController: UIPickerViewDelegate {
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return companies?[row].companyName
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        requestQuoteUpdate()
    }
}

extension UIImageView {
    func load(url: URL) {
        DispatchQueue.global().async { [weak self] in
            if let data = try? Data(contentsOf: url) {
                if let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self?.image = image
                    }
                }
            }
        }
    }
}
