Inkpad
======

Inkpad is a vector illustration app designed from scratch for the iPad. It supports paths, compound paths, text, images, groups, masks, gradient fills, and an unlimited number of layers.

Inkpad was designed with performance in mind – it can easily handle drawings with hundreds to thousands of shapes without bogging down. Export your finished illustrations directly to your Dropbox as SVG or PDF.

Features:

* Very high performance. Select, scale and rotate hundreds of objects with zero lag.
* Create arbitrary bezier paths with the Pen tool.
* Create compound paths, masks and groups.
* Create text objects.
* Place photos from your albums.
* Boolean operators on paths (Unite, Intersect, Exclude, Subtract Front)
* Powerful scale and rotate tools.
* Gradient fills with interactive editing on canvas.
* Arbitrary stroke dash patterns.
* Swatch library.
* Unlimited layers per drawing.
* Rename, rearrange, delete, hide and lock layers.
* Adjust layer transparency.
* Snap to grid, points, and path edges.
* Isolate the active layer for easy editing.
* Email drawings as SVG, PDF, PNG and JPEG.
* Send SVG, PDF, PNG, and JPEG directly to your Dropbox.

Inkpad was originally developed by Steve Sprang, and you can see his original repository at
[https://github.com/sprang/Inkpad](https://github.com/sprang/Inkpad).
Ben Burton is currently maintaining it on the App Store under the name *Inkpad Libre*.

License
-------

Inkpad is Free/Libre Open Source Software. It is distributed under the [Mozilla Public License v2.0](http://mozilla.org/MPL/2.0/).

Please do not submit unmodified (or trivially modified) versions of this application to the App Store.
The license grants both rights and responsibilities.
If you choose to clone and submit this application to the App Store,
*you are required to make this source code -- and any changes that you've made to it -- publicly available*.
You must also make it clear that the source code is available and provide a link to it.

I will ask Apple to pull any apps that do not comply. Please don't waste your time and mine.

Privacy Policy
--------------

This app does not collect any personal data.

How to Contribute
-----------------

Following Steve Sprang's original intentions, this is meant to be a community project.
I'd appreciate help with bug fixes, new features, localizations, testing, and other ideas,
and I encourage you to use the [GitHub issue tracker](https://github.com/baburton/Inkpad/issues) for this.

If you're taking on a big change, I'd be happy to discuss design ideas or answer questions before you get too far along.

To build Inkpad, you will need to set up [Carthage](https://github.com/Carthage/Carthage), which Inkpad uses
to build and embed the Dropbox SDK.
If you wish to test Dropbox functionality, you will also need to replace "xxxx" with a real Dropbox app key
in Inkpad-Info.plist and Classes/WDAppDelegate.m. This Dropbox app should be set up with _App folder_ permissions,
not _Full Dropbox_.

Contributors
------------

* [Steve Sprang](https://github.com/sprang)
* [Scott Vachalek](https://github.com/svachalek) / SVG Import
* [Joe Ricioppo](https://github.com/joericioppo) / Initial Dropbox Integration
* [Sam Green](https://github.com/samgreen)
* [Alistair McMillan](https://github.com/alistairmcmillan)
* [Oscar Rysdyk](https://github.com/32Beat)
* [Ben Burton](https://github.com/baburton)

Localizations:

* [Carlo Gandolfi](https://github.com/cgand) / Italian
* [Miguel Dussán](https://github.com/migdus) / Spanish
* [Yannick Loriot](https://github.com/YannickL) / French
* [Ersen Tekin](https://github.com/ersentekin) / Turkish
* [Henry Wagler](https://github.com/number-six) / German
* [Delfim Rodrigues](http://asebenta.wordpress.com) / Portuguese
* Pedro Lovisoto / Brazilian Portuguese
* [Juan Casares](http://www.usablehack.com) / Spanish
* [Ale Muñoz](https://github.com/bomberstudios) / Spanish
* [Pillow Tse](https://github.com/xiezhhw), [Zhang Yungui](https://github.com/rhcad) / Chinese Simplified
* [Akiji Tanaka](https://github.com/akiji) / Japanese
* [Abduolkader Idriss](https://github.com/zaxf) / Arabic

App Icon:

* [Matthew Rex Downham](http://www.mrexd.com/)
