//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

import Foundation

@objc
public class PaymentsViewUtils: NSObject {

    // MARK: - Dependencies

    private static var databaseStorage: SDSDatabaseStorage {
        return .shared
    }

    // MARK: -

    @available(*, unavailable, message:"Do not instantiate this class.")
    private override init() {}

    public static func buildMemoLabel(memoMessage: String?) -> UIView? {
        guard let memoMessage = memoMessage?.ows_stripped(),
              memoMessage.count > 0 else {
            return nil
        }

        let label = UILabel()
        label.textColor = Theme.primaryTextColor
        label.font = UIFont.ows_dynamicTypeBody2Clamped
        label.textAlignment = .center
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping

        let format = NSLocalizedString("SETTINGS_PAYMENTS_MEMO_MESSAGE_FORMAT",
                                       comment: "Format string for payment memo messages. Embeds: {{ the memo message }}.")
        label.text = String(format: format, memoMessage)

        let stack = UIStackView(arrangedSubviews: [label])
        stack.axis = .vertical
        stack.layoutMargins = UIEdgeInsets(hMargin: 16, vMargin: 8)
        stack.isLayoutMarginsRelativeArrangement = true

        let backgroundView = OWSLayerView.pillView()
        backgroundView.backgroundColor = Theme.secondaryBackgroundColor
        stack.addSubview(backgroundView)
        backgroundView.autoPinEdgesToSuperviewEdges()
        stack.sendSubviewToBack(backgroundView)

        return stack
    }

    static func buildUnidentifiedTransactionAvatar(avatarSize: UInt) -> UIView {
        let circleView = OWSLayerView.circleView()
        circleView.backgroundColor = (Theme.isDarkThemeEnabled ? .ows_gray75 : .ows_gray02)
        circleView.autoSetDimensions(to: .square(CGFloat(avatarSize)))

        let iconColor: UIColor = (Theme.isDarkThemeEnabled ? .ows_gray05 : .ows_gray75)
        let iconView = UIImageView.withTemplateImageName("mobilecoin-24",
                                                         tintColor: iconColor)
        circleView.addSubview(iconView)
        iconView.autoCenterInSuperview()
        iconView.autoSetDimensions(to: .square(CGFloat(avatarSize) * 20.0 / 36.0))

        return circleView
    }

    static func buildUnidentifiedTransactionString(paymentModel: TSPaymentModel) -> String {
        // TODO: What is the correct value here?
        owsAssertDebug(paymentModel.isUnidentified)
        return paymentModel.uniqueId
    }

    // MARK: -

    @objc
    static func addUnreadBadge(toView: UIView) {
        let avatarBadge = OWSLayerView.circleView(size: 12)
        avatarBadge.backgroundColor = Theme.accentBlueColor
        avatarBadge.layer.borderColor = UIColor.ows_white.cgColor
        avatarBadge.layer.borderWidth = 1
        toView.addSubview(avatarBadge)
        avatarBadge.autoPinEdge(toSuperviewEdge: .top, withInset: -3)
        avatarBadge.autoPinEdge(toSuperviewEdge: .trailing, withInset: -3)
    }

    static func markPaymentAsReadWithSneakyTransaction(_ paymentModel: TSPaymentModel) {
        owsAssertDebug(paymentModel.isUnread)

        databaseStorage.write { transaction in
            paymentModel.update(withIsUnread: false, transaction: transaction)
        }
    }

    static func markAllUnreadPaymentsAsReadWithSneakyTransaction() {
        databaseStorage.write { transaction in
            for paymentModel in PaymentFinder.allUnreadPaymentModels(transaction: transaction) {
                owsAssertDebug(paymentModel.isUnread)
                paymentModel.update(withIsUnread: false, transaction: transaction)
            }
        }
    }
}

// MARK: -

@objc
public extension TSPaymentModel {

    private static var statusDateShortFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    private static var statusDateTimeLongFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    func statusDescription(isLongForm: Bool) -> String {
        // PAYMENTS TODO: What's the correct copy here? What are all of the possible states?

        //        let defaultState = (isLongForm
        //                                ? NSLocalizedString("PAYMENTS_PAYMENT_STATUS_LONG_UNKNOWN",
        //                                                    comment: "Status indicator for payments which had an unknown failure.")
        //                                : NSLocalizedString("PAYMENTS_PAYMENT_STATUS_SHORT_UNKNOWN",
        //                                                    comment: "Status indicator for payments which had an unknown failure."))

        var result: String

        if isOutgoingTransfer || isUnidentified {
            if isOutgoing {
                result = (isLongForm
                            ? NSLocalizedString("PAYMENTS_PAYMENT_STATUS_LONG_OUTGOING_COMPLETE",
                                                comment: "Status indicator for outgoing payments which are complete.")
                            : NSLocalizedString("PAYMENTS_PAYMENT_STATUS_SHORT_OUTGOING_COMPLETE",
                                                comment: "Status indicator for outgoing payments which are complete."))
            } else {
                result = (isLongForm
                            ? NSLocalizedString("PAYMENTS_PAYMENT_STATUS_LONG_INCOMING_COMPLETE",
                                                comment: "Status indicator for incoming payments which are complete.")
                            : NSLocalizedString("PAYMENTS_PAYMENT_STATUS_SHORT_INCOMING_COMPLETE",
                                                comment: "Status indicator for incoming payments which are complete."))
            }
        } else {
            switch paymentState {
            case .outgoingUnsubmitted:
                result = (isLongForm
                            ? NSLocalizedString("PAYMENTS_PAYMENT_STATUS_LONG_OUTGOING_UNSUBMITTED",
                                                comment: "Status indicator for outgoing payments which have not yet been submitted.")
                            : NSLocalizedString("PAYMENTS_PAYMENT_STATUS_SHORT_OUTGOING_UNSUBMITTED",
                                                comment: "Status indicator for outgoing payments which have not yet been submitted."))
            case .outgoingUnverified:
                result = (isLongForm
                            ? NSLocalizedString("PAYMENTS_PAYMENT_STATUS_LONG_OUTGOING_UNVERIFIED",
                                                comment: "Status indicator for outgoing payments which have been submitted but not yet verified.")
                            : NSLocalizedString("PAYMENTS_PAYMENT_STATUS_SHORT_OUTGOING_UNVERIFIED",
                                                comment: "Status indicator for outgoing payments which have been submitted but not yet verified."))
            case .outgoingVerified:
                result = (isLongForm
                            ? NSLocalizedString("PAYMENTS_PAYMENT_STATUS_LONG_OUTGOING_VERIFIED",
                                                comment: "Status indicator for outgoing payments which have been verified but not yet sent.")
                            : NSLocalizedString("PAYMENTS_PAYMENT_STATUS_SHORT_OUTGOING_VERIFIED",
                                                comment: "Status indicator for outgoing payments which have been verified but not yet sent."))
            //        case .outgoingSent:
            case .outgoingSending:
                result = (isLongForm
                            ? NSLocalizedString("PAYMENTS_PAYMENT_STATUS_LONG_OUTGOING_SENDING",
                                                comment: "Status indicator for outgoing payments which are being sent.")
                            : NSLocalizedString("PAYMENTS_PAYMENT_STATUS_SHORT_OUTGOING_SENDING",
                                                comment: "Status indicator for outgoing payments which are being sent."))
            //        case .outgoingSendFailed:
            //            result = NSLocalizedString("PAYMENTS_PAYMENT_STATUS_SHORT_OUTGOING_SEND_FAILED",
            //                                       comment: "Status indicator for outgoing payments failed to be sent.")
            case .outgoingSent,
                 .outgoingMissingLedgerTimestamp,
                 .outgoingComplete:
                result = (isLongForm
                            ? NSLocalizedString("PAYMENTS_PAYMENT_STATUS_LONG_OUTGOING_SENT",
                                                comment: "Status indicator for outgoing payments which have been sent.")
                            : NSLocalizedString("PAYMENTS_PAYMENT_STATUS_SHORT_OUTGOING_SENT",
                                                comment: "Status indicator for outgoing payments which have been sent."))
            case .outgoingFailed:
                result = Self.description(forFailure: paymentFailure, isIncoming: false, isLongForm: isLongForm)
            case .incomingUnverified:
                result = (isLongForm
                            ? NSLocalizedString("PAYMENTS_PAYMENT_STATUS_LONG_INCOMING_UNVERIFIED",
                                                comment: "Status indicator for incoming payments which have not yet been verified.")
                            : NSLocalizedString("PAYMENTS_PAYMENT_STATUS_SHORT_INCOMING_UNVERIFIED",
                                                comment: "Status indicator for incoming payments which have not yet been verified."))
            //        case .incomingVerified:
            case .incomingVerified,
                 .incomingMissingLedgerTimestamp,
                 .incomingComplete:
                result = (isLongForm
                            ? NSLocalizedString("PAYMENTS_PAYMENT_STATUS_LONG_INCOMING_VERIFIED",
                                                comment: "Status indicator for incoming payments which have been verified.")
                            : NSLocalizedString("PAYMENTS_PAYMENT_STATUS_SHORT_INCOMING_VERIFIED",
                                                comment: "Status indicator for incoming payments which have been verified."))
            case .incomingFailed:
                result = Self.description(forFailure: paymentFailure, isIncoming: true, isLongForm: isLongForm)
            //        case .incomingDuplicate:
            //            // PAYMENTS TODO: We need copy from design.
            //            result = NSLocalizedString("PAYMENTS_PAYMENT_STATUS_SHORT_INCOMING_DUPLICATE",
            //                                       comment: "Status indicator for incoming payments which are duplicates.")
            //        case .incomingUnidentified:
            //            if let mcReceiptData = self.mcReceiptData else {
            //            } else {
            //                result = defaultState
            //            }
            //            guard let
            //             .outgoingUnidentified:
            //            // TODO: This should use an identifier
            @unknown default:
                result = (isLongForm
                            ? NSLocalizedString("PAYMENTS_PAYMENT_STATUS_LONG_UNKNOWN",
                                                comment: "Status indicator for payments which had an unknown failure.")
                            : NSLocalizedString("PAYMENTS_PAYMENT_STATUS_SHORT_UNKNOWN",
                                                comment: "Status indicator for payments which had an unknown failure."))
            }
        }
        result.append(" ")
        result.append(Self.formateDate(sortDate, isLongForm: isLongForm))

        return result
    }

    static func formateDate(_ date: Date, isLongForm: Bool) -> String {
        if isLongForm {
            return statusDateTimeLongFormatter.string(from: date)
        } else {
            return statusDateShortFormatter.string(from: date)
        }
    }

    private static func description(forFailure failure: TSPaymentFailure,
                                    isIncoming: Bool,
                                    isLongForm: Bool) -> String {
        // PAYMENTS TODO: What's the correct copy here? What are all of the possible states?

        let defaultDescription = (isIncoming
                                    ? NSLocalizedString("PAYMENTS_FAILURE_INCOMING_FAILED",
                                                        comment: "Status indicator for incoming payments which failed.")
                                    : NSLocalizedString("PAYMENTS_FAILURE_OUTGOING_FAILED",
                                                        comment: "Status indicator for outgoing payments which failed."))

        switch failure {
        case .none:
            // TODO: We should eventually convert this to an owsFailDebug().
            Logger.warn("Unexpected failure type: \(failure.rawValue)")
            if DebugFlags.paymentsIgnoreBadData.get() {
            } else {
                owsFailDebug("Unexpected failure type: \(failure.rawValue)")
            }
            return defaultDescription
        case .unknown:
            // TODO: We should eventually convert this to an owsFailDebug().
            owsFailDebug("Unexpected failure type: \(failure.rawValue)")
            return defaultDescription
        case .insufficientFunds:
            owsAssertDebug(!isIncoming)
            return NSLocalizedString("PAYMENTS_FAILURE_OUTGOING_INSUFFICIENT_FUNDS",
                                     comment: "Status indicator for outgoing payments which failed due to insufficient funds.")
        case .validationFailed:
            return (isIncoming
                        ? NSLocalizedString("PAYMENTS_FAILURE_INCOMING_VALIDATION_FAILED",
                                            comment: "Status indicator for incoming payments which failed to verify.")
                        : NSLocalizedString("PAYMENTS_FAILURE_OUTGOING_VALIDATION_FAILED",
                                            comment: "Status indicator for outgoing payments which failed to verify."))
        case .notificationSendFailed:
            owsAssertDebug(!isIncoming)
            return NSLocalizedString("PAYMENTS_FAILURE_OUTGOING_NOTIFICATION_SEND_FAILED",
                                     comment: "Status indicator for outgoing payments for which the notification could not be sent.")
        case .invalid, .expired:
            return NSLocalizedString("PAYMENTS_FAILURE_INVALID",
                                     comment: "Status indicator for invalid payments which could not be processed.")
        @unknown default:
            owsFailDebug("Unknown failure type: \(failure.rawValue)")
            return defaultDescription
        }
    }
}
