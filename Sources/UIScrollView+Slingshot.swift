//
//  Copyright © 2020 by GreenJell0. All rights reserved.
//

import UIKit

// MARK: - Slingshot

/*
 Overview:

 This extension adds a "slingshot" behavior to any scroll view via `isSlingshotEnabled`. When enabled, if the user scrolls past the bottom of
 the content a certain amount (the "threshold") and releases, the scroll view will slingshot and scroll back to the top of the content. As they scroll past
 the content, a view (the slingshot view) appears and hints that this behavior is available and when they've scrolled sufficiently far. This behavior is
 implemented by observing the scroll view's content offset and keying off of certain stateful properties (see `startObserving`) to determine whether the user
 is scrolling and whether the slingshot should engage and trigger.
 */

public extension UIScrollView {

    // MARK: Constants

    /// The distance the user must scroll past the content in this scroll view for the slingshot to engage.
    private static let slingshotThreshold = CGFloat(150)

    /// The required height the content must be in relation to the scroll view itself in order for the slingshot to be available.
    /// This can be read as: "The content must be x times taller than the scroll view for the slingshot to be available."
    private static let requiredHeightRatioForSlingshot = CGFloat(1.2)

    // MARK: Supporting Types

    /// The view that indicates that the slingshot is available and what its current state is.
    private final class SlingshotView: UIView {

        let arrow = UIImageView()
        let label = UILabel()

        override init(frame: CGRect = .zero) {
            super.init(frame: frame)

            label.font = .preferredFont(forTextStyle: .footnote)
            label.adjustsFontForContentSizeCategory = true
            
            if #available(iOS 13.0, tvOS 13.0, *) {
                arrow.image = UIImage(systemName: "arrow.up")
            } else {
                arrow.image = UIImage(named: "SlingshotArrow")
            }
            
            arrow.setContentCompressionResistancePriority(.required, for: .horizontal)

            let stack = UIStackView()
            stack.axis = .horizontal
            stack.alignment = .center
            stack.spacing = 10
            stack.addArrangedSubview(arrow)
            stack.addArrangedSubview(label)
            stack.translatesAutoresizingMaskIntoConstraints = false
            addSubview(stack)

            NSLayoutConstraint.activate([
                stack.centerXAnchor.constraint(equalTo: centerXAnchor),
                stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
                stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
                stack.topAnchor.constraint(equalTo: topAnchor),
                stack.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        }

        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }

    /// Stores the properties necessary to execute the slingshot.
    /// Because the slingshot is implemented as an extension on UIScrollView it can't have any stored properites.
    /// Using a storage container like this allows us to store any needed properties as an associated object.
    private class Storage {
        static var key: UInt8 = 0

        /// Backing storage for `UIScrollView.isSlingshotEnabled`.
        var isSlingshotEnabled = false
        /// Backing storage for `UIScrollView.isSlingshotEngaged`.
        var isSlingshotEngaged = false
        /// Backing storage to maintain a reference to the slingshot view.
        lazy private(set) var slingshotView = SlingshotView()
        /// Observation token for the scroll view's content offset.
        var scrollViewObservation: NSKeyValueObservation?
    }

    // MARK: Properties

    /// Storage for slingshot properties. Accessing the storage for the first time will create and associate a new `Storage` container
    /// with this scroll view. Subsequent accesses will return the same instance of the container.
    private var storage: Storage {
        get {
            // Return the existing storage container if it exists.
            if let existingStorage = objc_getAssociatedObject(self, &Storage.key) as? Storage {
                return existingStorage
            } else {
                // Otherwise, create a new container and associate it with this scroll view via the setter.
                self.storage = Storage()
                return self.storage
            }
        }

        set {
            // Update the associated storage container with this scroll view whenever the container is set.
            objc_setAssociatedObject(self, &Storage.key, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    public var slingshotArrowTintColor: UIColor? {
        get { slingshotView.arrow.tintColor }
        set { slingshotView.arrow.tintColor = newValue }
    }
    
    /// Whether or not the slingshot is enabled on this scroll view. By default, the slingshot is disabled.
    public var isSlingshotEnabled: Bool {
        get {
            return storage.isSlingshotEnabled
        }

        set(isEnabled) {
            storage.isSlingshotEnabled = isEnabled
            if isEnabled {
                // Start observing the scroll view's content offset when the slingshot is enabled.
                startObserving()
            } else {
                // Stop observing the scroll view's content offset when the slingshot is disabled.
                stopObserving()
                // Hide the slingshot view in case it was visible
                hideSlingshotViewIfNeeded()
                // Clean up by removing the associated storage since we've disabled the slingshot.
                objc_setAssociatedObject(self, &Storage.key, nil, .OBJC_ASSOCIATION_ASSIGN)
            }
        }
    }

    /// Convenience getter for this scroll view's slingshot view.
    private var slingshotView: SlingshotView { storage.slingshotView }

    /// Whether the user has scrolled sufficiently far past the content (as defined by `Self.slingshotThreshold`) so that when they
    /// lift their finger, the slingshot will trigger, resetting the content offset to the top.
    private var isSlingshotEngaged: Bool {
        get { storage.isSlingshotEngaged }
        set { storage.isSlingshotEngaged = newValue }
    }

    /// Whether the user has scrolled past the the content.
    private var isScrolledPastContentBottom: Bool {
        return contentOffset.y > contentSize.height - bounds.height
    }

    /// The distance the user has scroll past the content. This is a non-negative value.
    private var distancePastContentBottom: CGFloat {
        return max(0, -(contentSize.height - bounds.height - contentOffset.y))
    }

    /// Whether the content is large enough to warrant a slingshot (as defined by `Self.requiredHeightRatioForSlingshot`.)
    private var isSlingshotAvailableByContentSize: Bool {
        return contentSize.height >= Self.requiredHeightRatioForSlingshot * (bounds.height - contentInset.bottom)
    }

    /// Whether the scroll view is in a state where it can slingshot (based on its content size and zooming state.)
    /// - Note: Even if `isSlingshotEnabled` is set to `true`, the slingshot will not be visible or engage if `canSlingshot` returns `false`.
    private var canSlingshot: Bool {
        return isSlingshotAvailableByContentSize && !isZooming && !isZoomBouncing
    }

    // MARK: Methods

    /// Begins observing the scroll view's content offset to determine whether and when to slingshot.
    private func startObserving() {
        storage.scrollViewObservation = self.observe(\.contentOffset) { [weak self] scrollView, _ in
            // Return early if we can't slingshot.
            guard let self = self, self.canSlingshot else { return }

            // If the user is scrolling (if their finger is down inside of the scroll view)
            if scrollView.isTracking, scrollView.isDragging {
                // Engage the slingshot if they have scrolled sufficiently past the content, otherwise disengage.
                self.isSlingshotEngaged = scrollView.distancePastContentBottom > Self.slingshotThreshold

                // If the user has scrolled past the content
                if scrollView.isScrolledPastContentBottom {
                    // Show and update the slingshot
                    self.showSlingshotViewIfNeeded()
                    self.updateSlingshotView()
                } else {
                    // Otherwise, hide the slingshot
                    self.hideSlingshotViewIfNeeded()
                }
            } else if scrollView.isDecelerating, self.isSlingshotEngaged {
                // The user isn't scrolling anymore (they've lifted their finger), and the scroll view has started to decelerate
                // (which happens as the scroll view is released and rubberbands back to its resting position) while the slingshot was engaged.

                // Disengage the slingshot
                self.isSlingshotEngaged = false
                // Trigger the slingshot and scroll back to the top of the content
                let topOffset = CGPoint(x: 0, y: -(scrollView.contentInset.top + scrollView.adjustedContentInset.top))
                scrollView.setContentOffset(topOffset, animated: true)
            }
        }
    }

    /// Stops observing the scroll view's content offset.
    private func stopObserving() {
        storage.scrollViewObservation = nil
    }

    /// Adds and positions the slingshot view as a subview if it isn't already a subview.
    private func showSlingshotViewIfNeeded() {
        // Check that the slingshot view isn't already a subview so that we don't perform this unecessarily.
        if slingshotView.superview != self {
            slingshotView.frame = CGRect(
                x: 0,
                // Position the slingshot view directly below the rest of the content.
                y: self.contentSize.height,
                width: self.frame.width,
                // Give the slingshot view the height of the threshold.
                height: Self.slingshotThreshold
            )

            addSubview(slingshotView)
        }
    }

    /// Removes the slingshot view as a subview if it is a subview.
    private func hideSlingshotViewIfNeeded() {
        // Check that the slingshot view is a subview so that we don't perform this unecessarily.
        if slingshotView.superview == self {
            slingshotView.removeFromSuperview()
        }
    }

    /// Perform any updates to the slingshot view inside this method.
    /// Called when the user scrolls past the content (each time the content offset changes.)
    private func updateSlingshotView() {
        slingshotView.alpha = min(distancePastContentBottom / Self.slingshotThreshold, 1.0)

        self.slingshotView.label.text = self.isSlingshotEngaged
            ? NSLocalizedString("Release to scroll to the top", comment: "Message shown when the user scrolls way beyond the end of the content")
            : NSLocalizedString("Pull to scroll to the top", comment: "Message shown when the user scrolls beyond the end of the content")

        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseInOut, .beginFromCurrentState], animations: {
            self.slingshotView.arrow.layer.transform = CATransform3DMakeRotation(.pi, self.isSlingshotEngaged ? 1 : 0, 0, 0)
        }, completion: { _ in })
    }
}
