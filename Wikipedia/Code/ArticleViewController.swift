
import UIKit
import WMF

private extension CharacterSet {
    static let pathComponentAllowed: CharacterSet = {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/.")
        return allowed
    }()
}

@objc(WMFArticleViewController)
class ArticleViewController: ViewController {
    
    enum ViewState {
        case unknown
        case loading
        case data
    }
    
    internal lazy var toolbarController: ArticleToolbarController = {
        return ArticleToolbarController(toolbar: toolbar, delegate: self)
    }()
    
    @objc public let articleURL: URL
    public var visibleSectionAnchor: String? // TODO: Implement
    @objc public var loadCompletion: (() -> Void)?
    
    private let schemeHandler: SchemeHandler
    internal let dataStore: MWKDataStore
    private let authManager: WMFAuthenticationManager = WMFAuthenticationManager.sharedInstance // TODO: DI?
    internal let alertManager: WMFAlertManager = WMFAlertManager.sharedInstance
    private let cacheController: CacheController
    private let article: WMFArticle

    private var leadImageHeight: CGFloat = 210
    
    @objc init?(articleURL: URL, dataStore: MWKDataStore, theme: Theme) {
        guard
            let article = dataStore.fetchOrCreateArticle(with: articleURL),
            let cacheController = dataStore.articleCacheControllerWrapper.cacheController
        else {
            return nil
        }
        
        self.articleURL = articleURL
        self.dataStore = dataStore
        self.article = article
        self.schemeHandler = SchemeHandler.shared // TODO: DI?
        self.schemeHandler.articleCacheController = cacheController
        self.cacheController = cacheController
        
        super.init(theme: theme)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: WebView
    
    static let webProcessPool = WKProcessPool()
    
    lazy var messagingController: ArticleWebMessagingController = ArticleWebMessagingController(delegate: self)
    
    lazy var webViewConfiguration: WKWebViewConfiguration = {
        let configuration = WKWebViewConfiguration()
        configuration.processPool = ArticleViewController.webProcessPool
        configuration.setURLSchemeHandler(schemeHandler, forURLScheme: schemeHandler.scheme)
        return configuration
    }()
    
    lazy var webView: WKWebView = {
        return WKWebView(frame: view.bounds, configuration: webViewConfiguration)
    }()

    // MARK: Lead Image
    
    @objc func userDidTapLeadImage() {
        
    }
    
    func loadLeadImage(with leadImageURL: URL) {
        leadImageHeightConstraint.constant = leadImageHeight
        leadImageView.wmf_setImage(with: leadImageURL, detectFaces: true, onGPU: true, failure: { (error) in
            DDLogError("Error loading lead image: \(error)")
        }) {
            self.layoutLeadImage()
        }
    }
    
    lazy var leadImageHeightConstraint: NSLayoutConstraint = {
        return leadImageContainerView.heightAnchor.constraint(equalToConstant: 0)
    }()
    
    lazy var leadImageView: UIImageView = {
        let imageView = FLAnimatedImageView(frame: .zero)
        imageView.isUserInteractionEnabled = true
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
        imageView.accessibilityIgnoresInvertColors = true
        let tapGR = UITapGestureRecognizer(target: self, action: #selector(userDidTapLeadImage))
        imageView.addGestureRecognizer(tapGR)
        return imageView
    }()
    
    lazy var leadImageContainerView: UIView = {
        let scale = UIScreen.main.scale
        let borderHeight: CGFloat = scale > 1 ? 0.5 : 1
        let height: CGFloat = 10
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: height))
        containerView.clipsToBounds = true
        
        let borderView = UIView(frame: CGRect(x: 0, y: height - borderHeight, width: 1, height: borderHeight))
        borderView.backgroundColor = UIColor(white: 0, alpha: 0.2)
        borderView.autoresizingMask = [.flexibleTopMargin, .flexibleWidth]
        
        leadImageView.frame = CGRect(x: 0, y: 0, width: 1, height: height - borderHeight)
        containerView.addSubview(leadImageView)
        containerView.addSubview(borderView)
        return containerView
    }()
        
    func layoutLeadImage() {
        let containerBounds = leadImageContainerView.bounds
//        // TODO: iPad margin handling after ToC is implemented

//        let imageSize = leadImageView.image?.size ?? .zero
//        let isImageNarrow = imageSize.height < 1 ? false : imageSize.width / imageSize.height < 2
        let marginWidth: CGFloat = 0
//        if isImageNarrow { // TODO: && self.tableOfContentsDisplayState == TableOfContentsDisplayStateInlineHidden) {
//            marginWidth = 32
//        }
        leadImageView.frame = CGRect(x: marginWidth, y: 0, width: containerBounds.size.width - 2 * marginWidth, height: CGFloat(leadImageHeight))
    }
    
    
    // MARK: Previewing
    
    public var articlePreviewingDelegate: ArticlePreviewingDelegate?
    
    // MARK: Layout
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutLeadImage()
    }
    
    // MARK: Loading
    
    private var state: ViewState = .loading {
        didSet {
            switch state {
            case .unknown:
                fakeProgressController.stop()
            case .loading:
                fakeProgressController.start()
            case .data:
                fakeProgressController.stop()
            }
        }
    }
    
    lazy private var fakeProgressController: FakeProgressController = {
        let progressController = FakeProgressController(progress: navigationBar, delegate: navigationBar)
        progressController.delay = 0.0
        return progressController
    }()
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        setup()
        super.viewDidLoad()
        setupToolbar() // setup toolbar needs to be after super.viewDidLoad because the superview owns the toolbar
        apply(theme: theme)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cancelWIconPopoverDisplay()
    }
    
    // MARK: Theme
    
    private lazy var themesPresenter: ReadingThemesControlsArticlePresenter = {
        return ReadingThemesControlsArticlePresenter(readingThemesControlsViewController: themesViewController, wkWebView: webView, readingThemesControlsToolbarItem: toolbarController.themeButton)
    }()
    
    private lazy var themesViewController: ReadingThemesControlsViewController = {
        return ReadingThemesControlsViewController(nibName: ReadingThemesControlsViewController.nibName, bundle: nil)
    }()
    
    override func apply(theme: Theme) {
        super.apply(theme: theme)
        view.backgroundColor = theme.colors.paperBackground
        webView.backgroundColor = theme.colors.paperBackground
        toolbarController.apply(theme: theme)
        if state == .data {
            messagingController.updateTheme(theme)
        }
    }
    
    // MARK: Sharing
    
    @objc public func shareArticleWhenReady() {
        // TODO: implement
    }
    
    // MARK: Overrideable functionality
    
    internal func handleLink(with title: String) {
        guard let host = articleURL.host,
            let newArticleURL = ArticleURLConverter.desktopURL(host: host, title: title) else {
            assertionFailure("Failure initializing new Article VC")
            //tonitodo: error state
            return
        }
        navigate(to: newArticleURL)
    }
    
    // MARK: Table of contents
    
    var tableOfContentsViewController: TableOfContentsViewController?
    var tableOfContentsDisplayMode: TableOfContentsDisplayMode = .modal
    var tableOfContentsDisplaySide: TableOfContentsDisplaySide = .left
    var isTableOfContentsVisible: Bool = false
    var isUpdatingTableOfContentsSectionOnScroll: Bool = false
    lazy var tableOfContentsSeparatorView: UIView = {
        return UIView()
    }()
}

private extension ArticleViewController {
    
    func setup() {
        setupWButton()
        setupSearchButton()
        addNotificationHandlers()
        setupWebView()
        load()
    }
    
    func addNotificationHandlers() {
        NotificationCenter.default.addObserver(self, selector: #selector(didReceiveArticleUpdatedNotification), name: NSNotification.Name.WMFArticleUpdated, object: article)
    }
    
    @objc func didReceiveArticleUpdatedNotification(_ notification: Notification) {
        toolbarController.setSavedState(isSaved: article.isSaved)
    }
    
    func setupSearchButton() {
        navigationItem.rightBarButtonItem = AppSearchBarButtonItem.newAppSearchBarButtonItem
    }
    
    func setupWebView() {
        view.wmf_addSubviewWithConstraintsToEdges(webView)
        scrollView = webView.scrollView // so that content insets are inherited
        scrollView?.delegate = self
        leadImageContainerView.translatesAutoresizingMaskIntoConstraints = false
        webView.scrollView.addSubview(leadImageContainerView)
            
        let leadingConstraint = webView.leadingAnchor.constraint(equalTo: leadImageContainerView.leadingAnchor)
        let trailingConstraint = webView.trailingAnchor.constraint(equalTo: leadImageContainerView.trailingAnchor)
        let topConstraint = webView.scrollView.topAnchor.constraint(equalTo: leadImageContainerView.topAnchor)
        NSLayoutConstraint.activate([topConstraint, leadingConstraint, trailingConstraint, leadImageHeightConstraint])
        
        guard let siteURL = articleURL.wmf_site else {
            DDLogError("Missing site for \(articleURL)")
            alertManager.showErrorAlert(RequestError.invalidParameters, sticky: true, dismissPreviousAlerts: true)
            return
        }
        
        // Need user groups to let the Page Content Service know if the page is editable for this user
        authManager.getLoggedInUser(for: siteURL) { (result) in
            switch result {
            case .success(let user):
                self.setupPageContentServiceJavaScriptInterface(with: user?.groups ?? [])
            case .failure(let error):
                self.alertManager.showErrorAlert(error, sticky: true, dismissPreviousAlerts: true)
            }
        }
    }
    
    func setupPageContentServiceJavaScriptInterface(with userGroups: [String]) {
        let areTablesInitiallyExpanded = UserDefaults.wmf.wmf_isAutomaticTableOpeningEnabled
        let textSizeAdjustment = UserDefaults.wmf.wmf_articleFontSizeMultiplier() as? Int ?? 100
        let language = articleURL.wmf_language ?? Locale.current.languageCode ?? "en"
        messagingController.setup(with: webView, language: language, theme: theme, leadImageHeight: Int(leadImageHeight), areTablesInitiallyExpanded: areTablesInitiallyExpanded, textSizeAdjustment: textSizeAdjustment, userGroups: userGroups)
    }
    
    func load() {
        state = .loading
        if let leadImageURL = article.imageURL(forWidth: traitCollection.wmf_leadImageWidth) {
            loadLeadImage(with: leadImageURL)
        }
        guard let mobileHTMLURL = ArticleURLConverter.mobileHTMLURL(desktopURL: articleURL, endpointType: .mobileHTML, scheme: WMFURLSchemeHandlerScheme) else {
            WMFAlertManager.sharedInstance.showErrorAlert(RequestError.invalidParameters as NSError, sticky: true, dismissPreviousAlerts: true)
            return
        }
        let request = URLRequest(url: mobileHTMLURL)
        webView.load(request)
    }
    
    func setupToolbar() {
        enableToolbar()
        toolbarController.apply(theme: theme)
        toolbarController.setSavedState(isSaved: article.isSaved)
        setToolbarHidden(false, animated: false)
    }
}

extension ArticleViewController: ArticleWebMessageHandling {
    func didTapLink(messagingController: ArticleWebMessagingController, title: String) {
        handleLink(with: title)
    }
    
    func didSetup(messagingController: ArticleWebMessagingController) {
        state = .data
        webView.becomeFirstResponder()
        showWIconPopoverIfNecessary()
        loadCompletion?()
    }
    
    func didGetLeadImage(messagingcontroller: ArticleWebMessagingController, source: String, width: Int?, height: Int?) {
        guard leadImageView.image == nil && leadImageView.wmf_imageURLToFetch == nil else {
            return
        }
        guard let leadImageURLToRequest = WMFArticle.imageURL(forTargetImageWidth: traitCollection.wmf_leadImageWidth, fromImageSource: source, withOriginalWidth: width ?? 0) else {
            return
        }
        loadLeadImage(with: leadImageURLToRequest)
    }
}

extension ArticleViewController: ArticleToolbarHandling {
    
    func toggleSave(from viewController: ArticleToolbarController) {
        article.isSaved = !article.isSaved
        try? article.managedObjectContext?.save()
    }
    
    func showThemePopover(from controller: ArticleToolbarController) {
        themesPresenter.showReadingThemesControlsPopup(on: self, responder: self, theme: theme)
    }
    
    func saveButtonWasLongPressed(from controller: ArticleToolbarController) {
        let addArticlesToReadingListVC = AddArticlesToReadingListViewController(with: dataStore, articles: [article], theme: theme)
        let nc = WMFThemeableNavigationController(rootViewController: addArticlesToReadingListVC, theme: theme)
        nc.setNavigationBarHidden(false, animated: false)
        present(nc, animated: true)
    }
}

extension ArticleViewController: ReadingThemesControlsResponding {
    func updateWebViewTextSize(textSize: Int) {
        messagingController.updateTextSizeAdjustmentPercentage(textSize)
    }
    
    func toggleSyntaxHighlighting(_ controller: ReadingThemesControlsViewController) {
        // no-op here, syntax highlighting shouldnt be displayed
    }
}

extension ArticleViewController: ImageScaleTransitionProviding {
    var imageScaleTransitionView: UIImageView? {
        return leadImageView
    }
    
    func prepareViewsForIncomingImageScaleTransition(with imageView: UIImageView?) {
        guard let imageView = imageView, let image = imageView.image else {
            return
        }

        leadImageView.image = image
        leadImageView.layer.contentsRect = imageView.layer.contentsRect

        view.layoutIfNeeded()
    }

}

private extension UIViewController {
    
    struct Offsets {
        let top: CGFloat?
        let bottom: CGFloat?
        let leading: CGFloat?
        let trailing: CGFloat?
    }
    
    func addChildViewController(childViewController: UIViewController, offsets: Offsets) {
        addChild(childViewController)
        childViewController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(childViewController.view)
        
        var constraintsToActivate: [NSLayoutConstraint] = []
        if let top = offsets.top {
            let topConstraint = childViewController.view.topAnchor.constraint(equalTo: view.topAnchor, constant: top)
            constraintsToActivate.append(topConstraint)
        }
        
        if let bottom = offsets.bottom {
            let bottomConstraint = childViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: bottom)
            constraintsToActivate.append(bottomConstraint)
        }
        
        if let leading = offsets.leading {
            let leadingConstraint = childViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: leading)
            constraintsToActivate.append(leadingConstraint)
        }
        
        if let trailing = offsets.trailing {
            let trailingConstraint = childViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: trailing)
            constraintsToActivate.append(trailingConstraint)
        }
        
        NSLayoutConstraint.activate(constraintsToActivate)
        
        childViewController.didMove(toParent: self)
    }
}

//WMFLocalizedStringWithDefaultValue(@"article-title", nil, nil, @"Article", @"Generic article title")
//WMFLocalizedStringWithDefaultValue(@"button-read-now", nil, nil, @"Read now", @"Read now button text used in various places.")
//WMFLocalizedStringWithDefaultValue(@"button-saved-remove", nil, nil, @"Remove from saved", @"Remove from saved button text used in various places.")
//WMFLocalizedStringWithDefaultValue(@"description-edit-pencil-title", nil, nil, @"Edit title description", @"Title for button used to show title description editor")
//WMFLocalizedStringWithDefaultValue(@"description-edit-pencil-introduction", nil, nil, @"Edit introduction", @"Title for button used to show article lead section editor")
//WMFLocalizedStringWithDefaultValue(@"page-protected-can-not-edit-title", nil, nil, @"This page is protected", @"Title of alert dialog shown when trying to edit a page that is protected beyond what the user can edit.")
//WMFLocalizedStringWithDefaultValue(@"page-protected-can-not-edit", nil, nil, @"You do not have the rights to edit this page", @"Text of alert dialog shown when trying to edit a page that is protected beyond what the user can edit.")
//WMFLocalizedStringWithDefaultValue(@"share-custom-menu-item", nil, nil, @"Share...", @"Button label for text selection Share {{Identical|Share}}")
//WMFLocalizedStringWithDefaultValue(@"table-of-contents-button-label", nil, nil, @"Table of contents", @"Accessibility label for the Table of Contents button {{Identical|Table of contents}}")
//WMFLocalizedStringWithDefaultValue(@"edit-menu-item", nil, nil, @"Edit", @"Button label for text selection 'Edit' menu item")
//WMFLocalizedStringWithDefaultValue(@"share-menu-item", nil, nil, @"Share…", @"Button label for 'Share…' menu")