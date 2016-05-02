//
// Copyright (c) 2016 PHUNG ANH TUAN. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import UIKit

var UITableLoadingViewKey = "UITableLoadingViewKey"

typealias Mapping = (heightBlock:((model: Any) -> CGFloat), configureCellBlock: (cell: UITableViewCell, model: Any) -> (), identifier: String, modelType: Any.Type)

public class ATTableViewDelegateConfiguration {
    public var scrollViewDidScroll: ((scrollView: UIScrollView) -> ())?
}

public class ATTableView: UITableView {
    public var defaultSection = ATTableViewSection()
    
    public var delegateConfiguration = ATTableViewDelegateConfiguration()
    
    public var onDidSelectItem: ((item: Any) -> ())?
    
    // Abstract the way to implement LoadMore feature.
    // Under implementation.
    public var shouldLoadMore: Bool = false
    private var isLoadingMore = false
    public var onLoadMore: (() -> ())?
    
    private var signalMonitorHandler: ((signal: ATSignal) -> ())?
    
    public func loadDataCompletedWithItems(items: [Any]) {
        self.shouldLoadMore = (items.count == 0) ? false : true
        self.addItems(items)
        
        isLoadingMore = false
    }
    
    // Keep referrence to models, encapsulated into LazyTableViewSection.
    public var source = [ATTableViewSection]()
    
    // Keep all setup for each CellType registered.
    private var mappings = [Mapping]()
    
    // Find registed cell type that accept model.
    private func mappingForModel(model: Any) -> Mapping? {
        for mapping in mappings {
            if mapping.modelType == model.dynamicType {
                return mapping
            }
        }
        
        return nil
    }
    
    // MARK: - Loading View
    public var loadingView: UIView?
    public var centerOffset = CGPointZero
    
    public func showLoadingIndicator(centerOffset: CGPoint = CGPointZero) {
        self.centerOffset = centerOffset
        
        if let loadingView = self.loadingView {
            if loadingView.superview == nil {
                self.addSubview(loadingView)
            }
            
            loadingView.hidden = false
            self.bringSubviewToFront(loadingView)
        }
    }
    
    public func hideLoadingIndicator() {
        self.loadingView?.hidden = true
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        self.adjustSizeOfLoadingIndicator()
    }
    
    func adjustSizeOfLoadingIndicator() {
        if let loadingView = self.loadingView {
            let bounds = self.frame
            loadingView.center = CGPoint(x: bounds.width / 2 + self.centerOffset.x, y: bounds.height / 2 + centerOffset.y)
        }
    }
    
    // Initializers
    public override init(frame: CGRect, style: UITableViewStyle) {
        super.init(frame: frame, style: style)
        
        self.initialize()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        self.initialize()
    }
    
    public func initialize() {
        self.dataSource = self
        self.delegate = self
        self.scrollsToTop = false
        
        // Auto Setup first section
        self.source.append(defaultSection)
    }

    public func addSection(section: ATTableViewSection, atIndex index: Int) {
        self.source.insert(section, atIndex: index)
    }
    
    public func addSection(section: ATTableViewSection) {
        self.source.append(section)
        
        // Render data
        self.reloadData()
    }
    
    public func addItems(items: [Any], section: Int) {
        let sectionData = self.source[section]
        sectionData.addItems(items)
        
        // Render data
        self.reloadData()
    }
    
    public func addItems(items: [Any]) {
        self.addItems(items, section: 0)
    }
    
    // To fix issue `array cannot be bridged from Objective-C` when push array of AnyObject.
    // https://forums.developer.apple.com/thread/28678
    public func addObjects(objects: [AnyObject]) {
        self.addObjects(objects, section: 0)
    }
    
    public func addObjects(objects: [AnyObject], section: Int) {
        let section = self.source[section]
        section.addItems(objects.map { $0 as AnyObject })
        
        // Render data
        self.reloadData()
    }
    
    // Register cell, setup some code blocks and store them to execute later.
    public func register<T: ATTableViewCellProtocol>(cellType: T.Type) {
        let identifier = cellType.reuseIdentifier()
        
        guard let _ = self.dequeueReusableCellWithIdentifier(identifier) else {
            // Create block code to execute class method `height:`
            // This block will be executed in `tableView:heightForRowAtIndexPath:`
            let heightBlock = { (model: Any) -> CGFloat in
                if let model = model as? T.ModelType {
                    return cellType.height(model)
                }
                return 0
            }
            
            // Create block code to execute method `configureCell:` of cell
            // This block will be executed in `tableView:cellForRowAtIndexPath:`
            let configureCellBlock = { (cell: UITableViewCell, model: Any) in
                if let cell = cell as? T, let model = model as? T.ModelType {
                    cell.configureCell(model)
                }
            }
            
            self.mappings.append(Mapping(heightBlock, configureCellBlock, identifier, T.ModelType.self))
            
            if let nibName = cellType.nibName() {
                self.registerNib(UINib(nibName: nibName, bundle: nil), forCellReuseIdentifier: identifier)
            }
            else {
                self.registerClass(cellType, forCellReuseIdentifier: identifier)
            }
            return
        }
    }
    
    public func clearAll() {
        for section in self.source {
            section.clear()
        }
        
        self.reloadData()
    }
    
    public func clearItemsAtSection(section: Int) {
        self.source[section].clear()
        
        self.reloadData()
    }
    
    public override func reloadData() {
        
        super.reloadData()
    }
    
    public func startMonitorSignal(handler: (signal: ATSignal) -> ()) {
        self.signalMonitorHandler = handler
    }
    
    internal func fireSignal(signal: ATSignal) {
        self.signalMonitorHandler?(signal: signal)
    }
}

extension ATTableView: UITableViewDataSource {
    // Configure sections
    public func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return self.source.count
    }
    
    // Configure header for section
    public func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return self.source[section].headerTitle
    }
    
    // Configure footer for section
    public func tableView(tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return self.source[section].footerTitle
    }
    
    // Configure cells
    public func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.source[section].items.count
    }
    
    public func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let model: Any = self.source[indexPath.section].items[indexPath.row]
        
        if let mapping = self.mappingForModel(model) {
            let cell = tableView.dequeueReusableCellWithIdentifier(mapping.identifier, forIndexPath: indexPath)
            mapping.configureCellBlock(cell: cell, model: model)
            return cell

        }
        return UITableViewCell()
    }
    
    public func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        let model: Any = self.source[indexPath.section].items[indexPath.row]
        
        if let mapping = self.mappingForModel(model) {
            return mapping.heightBlock(model: model)
        }
        
        return 0
    }
}

extension ATTableView: UITableViewDelegate {
    // Customize Section Header
    public func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return self.source[section].customHeaderView?()
    }
    
    public func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return self.source[section].headerHeight
    }

    // Customize Section Footer
    public func tableView(tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return self.source[section].customFooterView?()
    }
    
    public func tableView(tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return self.source[section].footerHeight
    }
    
    // Handle actions
    public func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        
        self.onDidSelectItem?(item: self.source[indexPath.section].items[indexPath.row])
    }
    
    // ScrollViewDelegate
    public func scrollViewDidEndDecelerating(scrollView: UIScrollView) {
        let currentOffset = scrollView.contentOffset.y
        let maximumOffset = scrollView.contentSize.height - scrollView.frame.size.height;
        
        let threhold = maximumOffset - currentOffset
        if threhold <= 10 && (shouldLoadMore && !isLoadingMore) {
            isLoadingMore = true
            self.onLoadMore?()
        }
    }
    
    public func scrollViewDidScroll(scrollView: UIScrollView) {
        self.delegateConfiguration.scrollViewDidScroll?(scrollView: scrollView)
    }
}