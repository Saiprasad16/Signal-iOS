//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

import Foundation
import UIKit
import PromiseKit
import Lottie

@objc
public protocol SendPaymentCompletionDelegate {
    func didSendPayment()
}

// MARK: -

@objc
public class SendPaymentCompletionActionSheet: ActionSheetController {

    public typealias PaymentInfo = SendPaymentInfo
    public typealias RequestInfo = SendRequestInfo

    @objc
    public weak var delegate: SendPaymentCompletionDelegate?

    public enum Mode {
        case payment(paymentInfo: PaymentInfo)
        // TODO: Add support for requests.
        // case request(requestInfo: RequestInfo)
    }

    private let mode: Mode

    private enum Step {
        case confirmPay(paymentInfo: PaymentInfo)
        case progressPay(paymentInfo: PaymentInfo)
        case successPay(paymentInfo: PaymentInfo)
        case failurePay(paymentInfo: PaymentInfo, error: Error)
        // TODO: Add support for requests.
        //        case confirmRequest(paymentAmount: TSPaymentAmount,
        //                            currencyConversion: CurrencyConversionInfo?)
        //        case failureRequest
    }

    private var currentStep: Step {
        didSet {
            if self.isViewLoaded {
                updateContentsForMode()
            }
        }
    }

    private let outerStack = UIStackView()

    private let innerStack = UIStackView()

    private let headerStack = UIStackView()

    private let balanceLabel = SendPaymentHelper.buildBottomLabel()

    private var helper: SendPaymentHelper?

    private var currentCurrencyConversion: CurrencyConversionInfo? { helper?.currentCurrencyConversion }

    public required init(mode: Mode, delegate: SendPaymentCompletionDelegate) {
        self.mode = mode
        self.delegate = delegate

        // TODO: Add support for requests.
        switch mode {
        case .payment(let paymentInfo):
            currentStep = .confirmPay(paymentInfo: paymentInfo)
        @unknown default:
            owsFail("Unknown mode.")
        }

        super.init(theme: .default)

        helper = SendPaymentHelper(delegate: self)
    }

    @objc
    public func present(fromViewController: UIViewController) {
        self.customHeader = outerStack
        self.isCancelable = true
        fromViewController.presentFormSheet(self, animated: true)
    }

    open override func viewDidLoad() {
        super.viewDidLoad()

        createSubviews()

        helper?.refreshObservedValues()
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        updateContentsForMode()
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // For now, the design only allows for portrait layout on non-iPads
        //
        // PAYMENTS TODO:
        if !UIDevice.current.isIPad && CurrentAppContext().interfaceOrientation != .portrait {
            UIDevice.current.ows_setOrientation(.portrait)
        }

        helper?.refreshObservedValues()
    }

    public override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        UIDevice.current.isIPad ? .all : .portrait
    }

    private func createSubviews() {

        outerStack.axis = .vertical
        outerStack.alignment = .fill
        outerStack.addBackgroundView(withBackgroundColor: Theme.actionSheetBackgroundColor)

        innerStack.axis = .vertical
        innerStack.alignment = .fill
        innerStack.layoutMargins = UIEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
        innerStack.isLayoutMarginsRelativeArrangement = true

        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.distribution = .equalSpacing
        headerStack.layoutMargins = UIEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        headerStack.isLayoutMarginsRelativeArrangement = true

        outerStack.addArrangedSubview(headerStack)
        outerStack.addArrangedSubview(innerStack)
    }

    private func updateContentsForMode() {

        switch currentStep {
        case .confirmPay(let paymentInfo):
            updateContentsForConfirmPay(paymentInfo: paymentInfo)
        case .progressPay(let paymentInfo):
            updateContentsForProgressPay(paymentInfo: paymentInfo)
        case .successPay(let paymentInfo):
            updateContentsForSuccessPay(paymentInfo: paymentInfo)
        case .failurePay(let paymentInfo, let error):
            updateContentsForFailurePay(paymentInfo: paymentInfo, error: error)
        // TODO: Add support for requests.
        //        case .confirmRequest:
        //            // TODO: Payment requests
        //            owsFailDebug("Requests not yet supported.")
        //        case .failureRequest:
        //            owsFailDebug("Requests not yet supported.")
        }
    }

    private func setContents(_ subviews: [UIView]) {
        AssertIsOnMainThread()

        innerStack.removeAllSubviews()
        for subview in subviews {
            innerStack.addArrangedSubview(subview)
        }
    }

    private func updateHeader(canCancel: Bool) {
        AssertIsOnMainThread()

        headerStack.removeAllSubviews()

        let cancelLabel = UILabel()
        cancelLabel.text = CommonStrings.cancelButton
        cancelLabel.font = UIFont.ows_dynamicTypeBodyClamped
        if canCancel {
            cancelLabel.textColor = Theme.primaryTextColor
            cancelLabel.isUserInteractionEnabled = true
            cancelLabel.addGestureRecognizer(UITapGestureRecognizer(target: self,
                                                                    action: #selector(didTapCancel)))
        } else {
            cancelLabel.textColor = Theme.secondaryTextAndIconColor
        }
        cancelLabel.setCompressionResistanceHigh()
        cancelLabel.setContentHuggingHigh()

        let titleLabel = UILabel()
        // TODO: Add support for requests.
        titleLabel.text = NSLocalizedString("PAYMENTS_NEW_PAYMENT_CONFIRM_PAYMENT_TITLE",
                                            comment: "Title for the 'confirm payment' ui in the 'send payment' UI.")
        titleLabel.font = UIFont.ows_dynamicTypeBodyClamped.ows_semibold
        titleLabel.textColor = Theme.primaryTextColor
        titleLabel.textAlignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail

        let spacer = UIView.container()
        spacer.setCompressionResistanceHigh()
        spacer.setContentHuggingHigh()

        headerStack.addArrangedSubview(cancelLabel)
        headerStack.addArrangedSubview(titleLabel)
        headerStack.addArrangedSubview(spacer)

        // We use the spacer to balance the layout.
        spacer.autoMatch(.width, to: .width, of: cancelLabel)
    }

    private func updateContentsForConfirmPay(paymentInfo: PaymentInfo) {
        AssertIsOnMainThread()

        updateHeader(canCancel: true)

        updateBalanceLabel()

        setContents([
            UIView.spacer(withHeight: 32),
            buildConfirmPaymentRows(paymentInfo: paymentInfo),
            UIView.spacer(withHeight: 32),
            buildConfirmPaymentButtons(),
            UIView.spacer(withHeight: vSpacingAboveBalance),
            balanceLabel
        ])
    }

    private func updateContentsForProgressPay(paymentInfo: PaymentInfo) {
        AssertIsOnMainThread()

        updateHeader(canCancel: false)

        let animationName = (Theme.isDarkThemeEnabled
                                ? "payments_spinner_dark"
                                : "payments_spinner")
        let animationView = AnimationView(name: animationName)
        animationView.backgroundBehavior = .pauseAndRestore
        animationView.loopMode = .loop
        animationView.contentMode = .scaleAspectFit
        animationView.play()
        animationView.autoSetDimensions(to: .square(48))

        // To void layout jitter, we use a label
        // that occupies exactly the same height.
        let bottomLabel = buildBottomLabel()
        bottomLabel.text = NSLocalizedString("PAYMENTS_NEW_PAYMENT_PROCESSING",
                                             comment: "Indicator that a new payment is being processed in the 'send payment' UI.")

        setContents([
            UIView.spacer(withHeight: 32),
            buildConfirmPaymentRows(paymentInfo: paymentInfo),
            UIView.spacer(withHeight: 32),
            // To void layout jitter, this view replaces the "bottom button"
            // in the layout, exactly matching its height.
            wrapBottomControl(animationView),
            UIView.spacer(withHeight: vSpacingAboveBalance),
            bottomLabel
        ])
    }

    private func updateContentsForSuccessPay(paymentInfo: PaymentInfo) {
        AssertIsOnMainThread()

        updateHeader(canCancel: false)

        let animationView = AnimationView(name: "payments_spinner_success")
        animationView.backgroundBehavior = .pauseAndRestore
        animationView.loopMode = .playOnce
        animationView.contentMode = .scaleAspectFit
        animationView.play()
        animationView.autoSetDimensions(to: .square(48))

        // To void layout jitter, we use a label
        // that occupies exactly the same height.
        let bottomLabel = buildBottomLabel()
        bottomLabel.text = CommonStrings.doneButton

        setContents([
            UIView.spacer(withHeight: 32),
            buildConfirmPaymentRows(paymentInfo: paymentInfo),
            UIView.spacer(withHeight: 32),
            // To void layout jitter, this view replaces the "bottom button"
            // in the layout, exactly matching its height.
            wrapBottomControl(animationView),
            UIView.spacer(withHeight: vSpacingAboveBalance),
            bottomLabel
        ])
    }

    private func wrapBottomControl(_ bottomControl: UIView) -> UIView {
        let bottomStack = UIStackView(arrangedSubviews: [bottomControl])
        bottomStack.axis = .vertical
        bottomStack.alignment = .center
        bottomStack.distribution = .equalCentering
        // To void layout jitter, this view replaces the "bottom button"
        // in the layout, exactly matching its height.
        bottomStack.autoSetDimension(.height, toSize: bottomControlHeight)
        return bottomStack
    }

    private func updateContentsForFailurePay(paymentInfo: PaymentInfo, error: Error) {
        AssertIsOnMainThread()

        updateHeader(canCancel: false)

        let animationView = AnimationView(name: "payments_spinner_fail")
        animationView.backgroundBehavior = .pauseAndRestore
        animationView.loopMode = .playOnce
        animationView.contentMode = .scaleAspectFit
        animationView.play()
        animationView.autoSetDimensions(to: .square(48))

        // To void layout jitter, we use an empty placeholder label
        // that occupies the exact same height
        let bottomLabel = buildBottomLabel()
        bottomLabel.text = Self.formatPaymentFailure(error)

        setContents([
            UIView.spacer(withHeight: 32),
            buildConfirmPaymentRows(paymentInfo: paymentInfo),
            UIView.spacer(withHeight: 32),
            // To void layout jitter, this view replaces the "bottom button"
            // in the layout, exactly matching its height.
            wrapBottomControl(animationView),
            UIView.spacer(withHeight: vSpacingAboveBalance),
            bottomLabel
        ])
    }

    private func buildConfirmPaymentRows(paymentInfo: PaymentInfo) -> UIView {

        var rows = [UIView]()

        func addRow(titleView: UIView, valueView: UIView) {

            valueView.setCompressionResistanceHorizontalHigh()
            valueView.setContentHuggingHorizontalHigh()

            let row = UIStackView(arrangedSubviews: [titleView, valueView])
            row.axis = .horizontal
            row.alignment = .center
            row.spacing = 8

            rows.append(row)
        }

        func addRow(title: String, value: String, isTotal: Bool = false) {

            let titleLabel = UILabel()
            titleLabel.text = title
            titleLabel.font = .ows_dynamicTypeBodyClamped
            titleLabel.textColor = Theme.primaryTextColor
            titleLabel.lineBreakMode = .byTruncatingTail

            let valueLabel = UILabel()
            valueLabel.text = value
            if isTotal {
                valueLabel.font = .ows_dynamicTypeTitle2Clamped
                valueLabel.textColor = Theme.primaryTextColor
            } else {
                valueLabel.font = .ows_dynamicTypeBodyClamped
                valueLabel.textColor = Theme.secondaryTextAndIconColor
            }

            addRow(titleView: titleLabel, valueView: valueLabel)
        }

        let recipientDescription = recipientDescriptionWithSneakyTransaction(paymentInfo: paymentInfo)
        addRow(title: recipientDescription,
               value: formatMobileCoinAmount(paymentInfo.paymentAmount))

        if let currencyConversion = paymentInfo.currencyConversion {
            if let fiatAmountString = PaymentsImpl.formatAsFiatCurrency(paymentAmount: paymentInfo.paymentAmount,
                                                                        currencyConversionInfo: currencyConversion) {
                let fiatFormat = NSLocalizedString("PAYMENTS_NEW_PAYMENT_FIAT_CONVERSION_FORMAT",
                                                   comment: "Format for the 'fiat currency conversion estimate' indicator. Embeds {{ the fiat currency code }}.")
                addRow(title: String(format: fiatFormat, currencyConversion.currencyCode),
                       value: fiatAmountString)
            } else {
                owsFailDebug("Could not convert to fiat.")
            }
        }

        addRow(title: NSLocalizedString("PAYMENTS_NEW_PAYMENT_ESTIMATED_FEE",
                                        comment: "Label for the 'payment estimated fee' indicator."),
               value: formatMobileCoinAmount(paymentInfo.estimatedFeeAmount))

        let separator = UIView()
        separator.backgroundColor = Theme.hairlineColor
        separator.autoSetDimension(.height, toSize: 1)
        let separatorRow = UIStackView(arrangedSubviews: [separator])
        separatorRow.axis = .horizontal
        separatorRow.alignment = .center
        separatorRow.distribution = .fill
        rows.append(separatorRow)

        let totalAmount = paymentInfo.paymentAmount.plus(paymentInfo.estimatedFeeAmount)
        addRow(title: NSLocalizedString("PAYMENTS_NEW_PAYMENT_PAYMENT_TOTAL",
                                        comment: "Label for the 'total payment amount' indicator."),
               value: formatMobileCoinAmount(totalAmount),
               isTotal: true)

        let stack = UIStackView(arrangedSubviews: rows)
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 16

        UIView.matchHeightsOfViews(rows)

        return stack
    }

    private func recipientDescriptionWithSneakyTransaction(paymentInfo: PaymentInfo) -> String {
        guard let recipient = paymentInfo.recipient as? SendPaymentRecipientImpl else {
            owsFailDebug("Invalid recipient.")
            return ""
        }
        let otherUserName: String
        switch recipient {
        case .address(let recipientAddress):
            otherUserName = databaseStorage.uiRead { transaction in
                self.contactsManager.displayName(for: recipientAddress, transaction: transaction)
            }
        case .publicAddress(let recipientPublicAddress):
            otherUserName = PaymentsImpl.formatAsBase58(publicAddress: recipientPublicAddress)
        }
        let userFormat = NSLocalizedString("PAYMENTS_NEW_PAYMENT_RECIPIENT_AMOUNT_FORMAT",
                                           comment: "Format for the 'payment recipient amount' indicator. Embeds {{ the name of the recipient of the payment }}.")
        return String(format: userFormat, otherUserName)
    }

    private static func formatPaymentFailure(_ error: Error) -> String {

        let errorDescription: String
        switch error {
        case PaymentsError.insufficientFunds:
            // PAYMENTS TODO: We need copy from design.
            errorDescription = NSLocalizedString("PAYMENTS_NEW_PAYMENT_ERROR_INSUFFICIENT_FUNDS",
                                                 comment: "Indicates that a payment failed due to insufficient funds.")
        default:
            // PAYMENTS TODO: Revisit which errors we surface and how.
            errorDescription = NSLocalizedString("PAYMENTS_NEW_PAYMENT_ERROR_UNKNOWN",
                                                 comment: "Indicates that an unknown error occurred while sending a payment or payment request.")
        }

        // PAYMENTS TODO: We need copy from design.
        let format = NSLocalizedString("PAYMENTS_NEW_PAYMENT_ERROR_FORMAT",
                                       comment: "Format for message indicating that error occurred while sending a payment or payment request. Embeds: {{ a description of the error that occurred }}.")
        return String(format: format, errorDescription)
    }

    private func buildConfirmPaymentButtons() -> UIView {
        buildBottomButtonStack([
            buildBottomButton(title: NSLocalizedString("PAYMENTS_NEW_PAYMENT_CONFIRM_PAYMENT_BUTTON",
                                                       comment: "Label for the 'confirm payment' button."),
                              target: self,
                              selector: #selector(didTapConfirmButton))
        ])
    }

    @objc
    public func updateBalanceLabel() {
        SendPaymentHelper.updateBalanceLabel(balanceLabel)
    }

    private func tryToSendPayment(paymentInfo: PaymentInfo) {

        self.currentStep = .progressPay(paymentInfo: paymentInfo)

        ModalActivityIndicatorViewController.presentAsInvisible(fromViewController: self) { [weak self] modalActivityIndicator in
            guard let self = self else { return }

            firstly {
                self.paymentsSwift.submitPaymentTransaction(recipient: paymentInfo.recipient,
                                                            paymentAmount: paymentInfo.paymentAmount,
                                                            memoMessage: paymentInfo.memoMessage,
                                                            paymentRequestModel: paymentInfo.paymentRequestModel,
                                                            isOutgoingTransfer: paymentInfo.isOutgoingTransfer)
            }.done { _ in
                AssertIsOnMainThread()

                self.didSucceedPayment(paymentInfo: paymentInfo)

                modalActivityIndicator.dismiss {}
            }.catch { error in
                AssertIsOnMainThread()
                owsFailDebug("Error: \(error)")

                self.didFailPayment(paymentInfo: paymentInfo, error: error)

                modalActivityIndicator.dismiss {}
            }
        }
    }

    private static let autoDismissDelay: TimeInterval = 2.5

    private func didSucceedPayment(paymentInfo: PaymentInfo) {
        self.currentStep = .successPay(paymentInfo: paymentInfo)

        let delegate = self.delegate
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.autoDismissDelay) { [weak self] in
            guard let self = self else { return }
            self.dismiss(animated: true) {
                delegate?.didSendPayment()
            }
        }
    }

    private func didFailPayment(paymentInfo: PaymentInfo, error: Error) {
        self.currentStep = .failurePay(paymentInfo: paymentInfo, error: error)

        let delegate = self.delegate
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.autoDismissDelay) { [weak self] in
            guard let self = self else { return }
            self.dismiss(animated: true) {
                delegate?.didSendPayment()
            }
        }
    }

    // TODO: Add support for requests.
    private func tryToSendPaymentRequest(requestInfo: RequestInfo) {

        ModalActivityIndicatorViewController.present(fromViewController: self, canCancel: false) { [weak self] modalActivityIndicator in
            guard let self = self else { return }

            firstly {
                PaymentsImpl.sendPaymentRequestMessagePromise(address: requestInfo.recipientAddress,
                                                              paymentAmount: requestInfo.paymentAmount,
                                                              memoMessage: requestInfo.memoMessage)
            }.done { _ in
                AssertIsOnMainThread()

                modalActivityIndicator.dismiss {
                    self.dismiss(animated: true)
                }
            }.catch { error in
                AssertIsOnMainThread()
                owsFailDebug("Error: \(error)")

                // TODO: Add support for requests.
                // self.currentStep = .failureRequest

                modalActivityIndicator.dismiss {}
            }
        }
    }

    // MARK: - Events

    @objc
    func didTapCancel() {
        dismiss(animated: true, completion: nil)
    }

    //    private var actionSheet: SendPaymentCompletionActionSheet?
    //
    //    @objc
    //    func didTapPayButton(_ sender: UIButton) {
    //        guard let parsedAmount = parsedAmount,
    //              parsedAmount > 0 else {
    //            showInvalidAmountAlert()
    //            return
    //        }
    //        let paymentAmount = TSPaymentAmount(currency: .mobileCoin, picoMob: parsedAmount)
    //        // TODO: Fill in actual estimates.
    //        let estimatedFeeAmount = TSPaymentAmount(currency: .mobileCoin, picoMob: 1)
    //        // Snapshot the conversion rate.
    //        let currencyConversion = self.currentCurrencyConversion
    //
    //        let paymentInfo = PaymentInfo(recipientAddress: recipientAddress,
    //                                      paymentAmount: paymentAmount,
    //                                      estimatedFeeAmount: estimatedFeeAmount,
    //                                      currencyConversion: currencyConversion,
    //                                      paymentRequestModel: paymentRequestModel)
    //        let actionSheet = SendPaymentCompletionActionSheet(mode: .payment(paymentInfo: paymentInfo))
    //        self.actionSheet = actionSheet
    //        actionSheet.present(fromViewController: self)
    //        //        currentStep = .confirmPay(paymentInfo: paymentInfo)
    //    }

    @objc
    func didTapConfirmButton(_ sender: UIButton) {
        switch currentStep {
        case .confirmPay(let paymentInfo):
            tryToSendPayment(paymentInfo: paymentInfo)
        // TODO: Add support for requests.
        //        case .confirmRequest(let paymentAmount, _):
        //            tryToSendPaymentRequest(paymentAmount)
        default:
            owsFailDebug("Invalid step.")
        }
    }
}

// MARK: -

extension SendPaymentCompletionActionSheet: SendPaymentHelperDelegate {
    public func balanceDidChange() {}

    public func currencyConversionDidChange() {}
}
