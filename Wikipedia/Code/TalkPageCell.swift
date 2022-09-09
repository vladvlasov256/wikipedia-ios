import Foundation
import UIKit
import WMF

protocol TalkPageCellDelegate: AnyObject {
    func userDidTapDisclosureButton(cellViewModel: TalkPageCellViewModel?, cell: TalkPageCell)
    func userDidTapSubscribeButton(cellViewModel: TalkPageCellViewModel?, cell: TalkPageCell)
}

protocol TalkPageCellReplyDelegate: AnyObject {
    func tappedReply(commentViewModel: TalkPageCellCommentViewModel)
}

final class TalkPageCellRootContainerView: SetupView, Themeable {
    lazy var stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.distribution = .fill
        return stackView
    }()

    lazy var topicView: TalkPageCellTopicView = TalkPageCellTopicView()
    lazy var disclosureRow: TalkPageCellDisclosureRow = TalkPageCellDisclosureRow()
    lazy var commentView = TalkPageCellCommentView()

    override func setup() {
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12)
        ])

        stackView.addArrangedSubview(disclosureRow)
        stackView.addArrangedSubview(topicView)
    }

    func configure(viewModel: TalkPageCellViewModel, linkDelegate: TalkPageTextViewLinkHandling, replyDelegate: TalkPageCellReplyDelegate) {

        disclosureRow.configure(viewModel: viewModel)
        topicView.configure(viewModel: viewModel)
        topicView.linkDelegate = linkDelegate

        let comments: [UIView] = stackView.arrangedSubviews.filter { view in view is TalkPageCellCommentView || view is TalkPageCellCommentSeparator }
        stackView.arrangedSubviews.forEach { view in
            if comments.contains(view) {
                view.removeFromSuperview()
            }
        }

        for commentViewModel in viewModel.replies {
            let separator = TalkPageCellCommentSeparator()
            let commentView = TalkPageCellCommentView()
            commentView.configure(viewModel: commentViewModel)
            commentView.replyDelegate = replyDelegate
            commentView.linkDelegate = linkDelegate

            commentView.isHidden = !viewModel.isThreadExpanded
            separator.isHidden = !viewModel.isThreadExpanded

            stackView.addArrangedSubview(separator)
            stackView.addArrangedSubview(commentView)
        }
    }

    func apply(theme: Theme) {
        backgroundColor = theme.colors.paperBackground
        layer.borderColor = theme.colors.border.cgColor
        stackView.arrangedSubviews.forEach { ($0 as? Themeable)?.apply(theme: theme) }
    }
}

final class TalkPageCell: UICollectionViewCell {

    // MARK: - Properties

    static let reuseIdentifier = "TalkPageCell"

    weak var viewModel: TalkPageCellViewModel?
    weak var delegate: TalkPageCellDelegate?
    weak var replyDelegate: TalkPageCellReplyDelegate?
    
    static let padding = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)

    // MARK: - UI Elements

    lazy var rootContainer: TalkPageCellRootContainerView = {
        let view = TalkPageCellRootContainerView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.masksToBounds = true
        view.layer.cornerCurve = .continuous
        view.layer.cornerRadius = 8
        view.layer.borderWidth = 1.0
        return view
    }()

    // MARK: - Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func prepareForReuse() {
        viewModel = nil
        delegate = nil
        rootContainer.disclosureRow.disclosureButton.removeTarget(nil, action: nil, for: .allEvents)
        rootContainer.disclosureRow.subscribeButton.removeTarget(nil, action: nil, for: .allEvents)
    }

    func setup() {
        contentView.addSubview(rootContainer)
        
        let rootContainerBottomConstraint = rootContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        rootContainerBottomConstraint.priority = .defaultHigh

        NSLayoutConstraint.activate([
            rootContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Self.padding.top),
            rootContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Self.padding.leading),
            rootContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Self.padding.trailing)
        ])
    }

    // MARK: - Configure

    func configure(viewModel: TalkPageCellViewModel, linkDelegate: TalkPageTextViewLinkHandling, replyDelegate: TalkPageCellReplyDelegate) {
        self.viewModel = viewModel
        self.replyDelegate = replyDelegate
        
        rootContainer.configure(viewModel: viewModel, linkDelegate: linkDelegate, replyDelegate: replyDelegate)

        rootContainer.disclosureRow.disclosureButton.addTarget(self, action: #selector(userDidTapDisclosureButton), for: .primaryActionTriggered)
        rootContainer.disclosureRow.subscribeButton.addTarget(self, action: #selector(userDidTapSubscribeButton), for: .primaryActionTriggered)
        rootContainer.topicView.replyButton.addTarget(self, action: #selector(userDidTapLeadReply), for: .touchUpInside)
    }

    // MARK: - Actions

    @objc func userDidTapDisclosureButton() {
        delegate?.userDidTapDisclosureButton(cellViewModel: viewModel, cell: self)
    }

    @objc func userDidTapSubscribeButton() {
        delegate?.userDidTapSubscribeButton(cellViewModel: viewModel, cell: self)
    }
    
    @objc func userDidTapLeadReply() {
        
        guard let commentViewModel = viewModel?.leadComment else {
            return
        }
        
        replyDelegate?.tappedReply(commentViewModel: commentViewModel)
    }
}

// MARK: - Themeable

extension TalkPageCell: Themeable {

    func apply(theme: Theme) {
        rootContainer.apply(theme: theme)
    }

}
