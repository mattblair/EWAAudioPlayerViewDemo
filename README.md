## What is this?

`EWAAudioPlayerView` is intended to be a drop-in audio player for projects supporting iOS 7.0+. It combines the subviews necessary for playback control with the underlying objects needed to play in-bundle and remote audio. It allows customization of colors and graphics. For audio files included in the app bundle, it also manages duration, position, and scrubbing, using the slider. 

This Cocoapod is based on code originally developed for the [PDX Social History Guide app](https://github.com/mattblair/social-history-guide-ios), combined with code from as-yet unpublished projects. 

As of October 2014, it's probably not stable enough for general use. APIs are not guaranteed, etc.


## Future Improvements

#### Layout

* Use Auto Layout instead of passing frame for y and width. (I need to update a few apps still depending on code-based frame calculations first...)

#### Refactor
* There's too much piled into one class at this point. It's obviously much more than a view should handle, but part of the point was to have a single class to add for comprehensive audio management.
* Creating distinct subclasses for local v. remote sources might eliminate some conditionals, but much of the behavior might be shared in a superclass. TBD, pending feature stabilization. 

#### Improve Remote UI
* Add an activity indicator during the connect phase? 
* Under what conditions *is* duration available from remote sources? E.g. file formats that have it in the header data, or streaming sources that transmit the duration at the start of playback? How can UI reflect/handle that? 
* Would it be helpful to have a playback counter, even if total duration is unknown? Or init the view with a duration stored in the data driving the app?

