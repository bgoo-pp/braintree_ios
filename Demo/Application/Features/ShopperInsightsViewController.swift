import UIKit
import BraintreeCore
import BraintreePayPal
import BraintreeVenmo
import BraintreeShopperInsights

class ShopperInsightsViewController: PaymentButtonBaseViewController {
    
    lazy var shopperInsightsClient = BTShopperInsightsClient(apiClient: apiClient, shopperSessionID: "test-shopper-session-id")
    lazy var payPalClient = BTPayPalClient(apiClient: apiClient)
    lazy var venmoClient = BTVenmoClient(apiClient: apiClient)
    
    lazy var payPalVaultButton = createButton(title: "PayPal Vault", action: #selector(payPalVaultButtonTapped))
    lazy var venmoButton = createButton(title: "Venmo", action: #selector(venmoButtonTapped))
    
    private var shopperSessionID = "test-shopper-session-id"
    
    lazy var emailView: TextFieldWithLabel = {
        let view = TextFieldWithLabel()
        view.label.text = "Email"
        view.textField.placeholder = "Email"
        view.textField.text = "PR1_merchantname@personal.example.com"
        return view
    }()
    
    lazy var countryCodeView: TextFieldWithLabel = {
        let view = TextFieldWithLabel()
        view.label.text = "Country Code"
        view.textField.placeholder = "Country Code"
        view.textField.text = "1"
        return view
    }()
    
    lazy var nationalNumberView: TextFieldWithLabel = {
        let view = TextFieldWithLabel()
        view.label.text = "National Number"
        view.textField.placeholder = "National Number"
        view.textField.text = "4082321001"
        return view
    }()
    
    lazy var shopperInsightsButton = createButton(title: "Fetch Shopper Insights", action: #selector(shopperInsightsButtonTapped))
    
    lazy var shopperInsightsInputView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [emailView, countryCodeView, nationalNumberView])
        stackView.axis = .vertical
        stackView.spacing = 10
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        createSubviews()
        layoutConstraints()
    }
    
    override func createPaymentButton() -> UIView {
        let buttons = [shopperInsightsButton, payPalVaultButton, venmoButton]
        shopperInsightsButton.isEnabled = true
        payPalVaultButton.isEnabled = false
        venmoButton.isEnabled = false

        let stackView = UIStackView(arrangedSubviews: buttons)
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        return stackView
    }
    
    @objc func shopperInsightsButtonTapped(_ button: UIButton) {
        self.progressBlock("Fetching shopper insights...")
        
        let request = BTShopperInsightsRequest(
            email: emailView.textField.text ?? "",
            phone: Phone(
                countryCode: countryCodeView.textField.text ?? "",
                nationalNumber: nationalNumberView.textField.text ?? ""
            )
        )
        Task {
            do {
                let sampleExperiment =
                    """
                    [
                        { "experimentName" : "payment ready conversion" },
                        { "experimentID" : "a1b2c3" },
                        { "treatmentName" : "control group 1" }
                    ]
                    """
                let result = try await shopperInsightsClient.getRecommendedPaymentMethods(request: request, experiment: sampleExperiment)
                // swiftlint:disable:next line_length
                progressBlock("PayPal Recommended: \(result.isPayPalRecommended)\nVenmo Recommended: \(result.isVenmoRecommended)\nEligible in PayPal Network: \(result.isEligibleInPayPalNetwork)")
                
                togglePayPalVaultButton(enabled: result.isPayPalRecommended)
                toggleVenmoButton(enabled: result.isVenmoRecommended)
            } catch {
                progressBlock("Error: \(error.localizedDescription)")
            }
        }
    }
    
    private func togglePayPalVaultButton(enabled: Bool) {
        payPalVaultButton.isEnabled = enabled
        
        guard enabled else { return }
        
        let presentmentDetails = BTPresentmentDetails(
            buttonOrder: .first,
            experimentType: .control,
            pageType: .about
        )
        
        shopperInsightsClient.sendPresentedEvent(
            for: .payPal,
            presentmentDetails: presentmentDetails
        )
    }
    
    private func toggleVenmoButton(enabled: Bool) {
        venmoButton.isEnabled = enabled
        
        guard enabled else { return }
        
        let presentmentDetails = BTPresentmentDetails(
            buttonOrder: .second,
            experimentType: .control,
            pageType: .about
        )
        
        shopperInsightsClient.sendPresentedEvent(
            for: .venmo,
            presentmentDetails: presentmentDetails
        )
    }
    
    @objc func payPalVaultButtonTapped(_ button: UIButton) {
        progressBlock("Tapped PayPal Vault")
        shopperInsightsClient.sendSelectedEvent(for: .payPal)
        
        button.setTitle("Processing...", for: .disabled)
        button.isEnabled = false
        
        let paypalRequest = BTPayPalVaultRequest()
        paypalRequest.shopperSessionID = shopperSessionID
        paypalRequest.userAuthenticationEmail = emailView.textField.text
        
        payPalClient.tokenize(paypalRequest) { nonce, error in
            button.isEnabled = true
            self.displayResultDetails(nonce: nonce, error: error)
        }
    }
    
    @objc func venmoButtonTapped(_ button: UIButton) {
        progressBlock("Tapped Venmo")
        shopperInsightsClient.sendSelectedEvent(for: .venmo)
        
        button.setTitle("Processing...", for: .disabled)
        button.isEnabled = false

        let venmoRequest = BTVenmoRequest(paymentMethodUsage: .multiUse)
        venmoClient.tokenize(venmoRequest) { nonce, error in
            button.isEnabled = true
            self.displayResultDetails(nonce: nonce, error: error)
        }
    }
    
    private func displayResultDetails(nonce: BTPaymentMethodNonce?, error: Error?) {
        if let error {
            progressBlock(error.localizedDescription)
        } else if let nonce {
            completionBlock(nonce)
        } else {
            progressBlock("Canceled")
        }
    }

    private func createSubviews() {
        shopperInsightsInputView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(shopperInsightsInputView)
    }

    private func layoutConstraints() {
        NSLayoutConstraint.activate(
            [
                shopperInsightsInputView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                shopperInsightsInputView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
                shopperInsightsInputView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
                shopperInsightsInputView.heightAnchor.constraint(equalToConstant: 200)
            ]
        )
    }
}
