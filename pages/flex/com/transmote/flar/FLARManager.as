/* 
 * PROJECT: FLARManager
 * http://transmote.com/flar
 * Copyright 2009, Eric Socolofsky
 * --------------------------------------------------------------------------------
 * This work complements FLARToolkit, developed by Saqoosha as part of the Libspark project.
 *	http://www.libspark.org/wiki/saqoosha/FLARToolKit
 * FLARToolkit is Copyright (C)2008 Saqoosha,
 * and is ported from NYARToolkit, which is ported from ARToolkit.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this framework; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 * 
 * For further information please contact:
 *	<eric(at)transmote.com>
 *	http://transmote.com/flar
 * 
 */

package com.transmote.flar {
	import __AS3__.vec.Vector;
	
	import com.transmote.flar.marker.FLARMarker;
	import com.transmote.flar.marker.FLARMarkerEvent;
	import com.transmote.flar.pattern.FLARPattern;
	import com.transmote.flar.pattern.FLARPatternLoader;
	import com.transmote.flar.source.FLARCameraSource;
	import com.transmote.flar.source.FLARLoaderSource;
	import com.transmote.flar.source.IFLARSource;
	import com.transmote.flar.utils.FLARMatrixSmoother_Average;
	import com.transmote.flar.utils.FLARProxy;
	import com.transmote.flar.utils.IFLARMatrixSmoother;
	
	import flash.display.Bitmap;
	import flash.display.DisplayObjectContainer;
	import flash.display.Sprite;
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.filters.BlurFilter;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequest;
	import flash.utils.ByteArray;
	
	import org.libspark.flartoolkit.FLARException;
	import org.libspark.flartoolkit.core.param.FLARParam;
	import org.libspark.flartoolkit.core.raster.rgb.FLARRgbRaster_BitmapData;
	import org.libspark.flartoolkit.core.transmat.FLARTransMatResult;
	import org.libspark.flartoolkit.detector.FLARMultiMarkerDetector;
	import org.libspark.flartoolkit.detector.FLARMultiMarkerDetectorResult;
	
	/**
	 * <p>
	 * Manager for computer vision applications using FLARToolkit
	 * (<a href="http://www.libspark.org/wiki/saqoosha/FLARToolKit/en" target="_blank">
	 * http://www.libspark.org/wiki/saqoosha/FLARToolKit/en</a>).
	 * </p>
	 * <p>
	 * Basic usage is as follows:
	 * Pass a path to a camera parameters file and a list of FLARPatterns to the constructor.
	 * Optionally pass an IFLARSource to use as the source image for marker detection;
	 * FLARManager will by default create a FLARCameraSource that uses the first available camera.
	 * Alternatively, FLARManager can be initialized using an xml file that specifies the above and other settings.
	 * </p>
	 * <p>
	 * Assign event listeners to FLARManager for MARKER_ADDED,
	 * MARKER_UPDATED, and MARKER_REMOVED FLARMarkerEvents.
	 * These FLARMarkerEvents encapsulate the FLARMarker instances that they refer to.
	 * Alternatively, it is possible to retrieve all active markers
	 * directly from FLARManager, via FLARManager.activeMarkers.
	 * </p>
	 * <p>
	 * FLARMarkers are simple objects that contain information about detected markers
	 * provided by FLARToolkit.  FLARManager maintains a list of active markers,
	 * and updates the list and the markers within every frame.
	 * </p>
	 * 
	 * @author	Eric Socolofsky
	 * @url		http://transmote.com/flar
	 * @see		com.transmote.flar.marker.FLARMarkerEvent
	 * @see		com.transmote.flar.source.FLARCameraSource
	 * @see		com.transmote.flar.utils.FLARProxy
	 */
	public class FLARManager extends EventDispatcher {
		private static const ZERO_POINT:Point = new Point();
		private static const ADAPTIVE_THRESHOLDING_MIN_VARIANCE:Number = 5;
		private static const ADAPTIVE_THRESHOLDING_MAX_VARIANCE:Number = 50;
		
		// general management
		private var _activeMarkers:Vector.<FLARMarker>;
		private var _cameraParams:FLARParam;
		private var _flarSource:IFLARSource;
		
		// source adjustment
		private var _threshold:Number = 80;
		private var _adaptiveThresholding:Boolean = true; 
		private var _adaptiveThresholdingSpeed:Number = 0.3;
		private var _adaptiveThresholdingBias:Number = -0.1;
		private var _sampleBlurring:int = 1;
		
		// marker adjustment
		private var _markerUpdateThreshold:Number = 80;
		private var _markerRemovalDelay:int = 1;
		private var _smoothing:int = 3;
		private var _smoother:IFLARMatrixSmoother;
		
		// debugging
		private var _mirrorDisplay:Boolean;
		private var _thresholdSourceDisplay:Boolean;
		
		// pattern and marker management
		private var patternLoader:FLARPatternLoader;
		private var allPatterns:Vector.<FLARPattern>;
		private var markerDetector:FLARMultiMarkerDetector;
		private var flarRaster:FLARRgbRaster_BitmapData;
		private var thresholdSourceBitmap:Bitmap;
		private var markersPendingRemoval:Vector.<FLARMarker>;
		
		// marker adjustment (private)
		private var enterframer:Sprite;
		private var averageConfidence:Number = FLARPattern.DEFAULT_MIN_CONFIDENCE;
		private var averageMinConfidence:Number = FLARPattern.DEFAULT_MIN_CONFIDENCE;
		private var adaptiveThresholdingStep:Number;
		private var sampleBlurFilter:BlurFilter;
		
		// application state
		private var bInited:Boolean;
		private var bCameraParamsLoaded:Boolean;
		private var bPatternsLoaded:Boolean;
		
		
		/**
		 * Constructor.
		 * Initialize FLARManager by passing in a configuration file path.
		 * 
		 * @param	flarConfigPath	path to the FLARManager configuration xml file.
		 */
		public function FLARManager (flarConfigPath:String="") {
			this._flarSource = new FLARCameraSource();
			if (flarConfigPath != "") {
				this.initFromFile(flarConfigPath);
			}
		}
		
		/**
		 * the old-fashioned way to initialize FLARManager.
		 * the preferred method is to use an external xml configuration file,
		 * and to pass its path into the FLARManager constructor.
		 * 
		 * @param	cameraParamsPath	camera parameters filename.
		 * @param	patterns			list of FLARPatterns to detect.
		 * @param	source				IFLARSource instance to use as source image for marker detection.
		 * 									if null, FLARManager will create a camera capture source.
		 */
		public function initManual (cameraParamsPath:String, patterns:Vector.<FLARPattern>, source:IFLARSource=null) :void {
			if (source) {
				this._flarSource = source;
				this._mirrorDisplay = source.mirrored;
			} else {
				this._flarSource = new FLARCameraSource();
			}
			
			this.init(cameraParamsPath, patterns);
		}
		
		/**
		 * load FLARManager configuration from an xml file.
		 * note, this method no longer needs to be called manually;
		 * simply passing the configuration file path into the constructor
		 * will also initialize correctly.  this method is here for legacy support only.
		 * 
		 * @param	flarConfigPath	path to the FLARManager configuration xml file.
		 */
		public function initFromFile (flarConfigPath:String) :void {
			var loader:URLLoader = new URLLoader();
			loader.addEventListener(IOErrorEvent.IO_ERROR, this.onFlarConfigLoadError);
			loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, this.onFlarConfigLoadError);
			loader.addEventListener(Event.COMPLETE, this.onFlarConfigLoaded);
			loader.load(new URLRequest(flarConfigPath));
		}
		
		
		//-----<ACCESSORS>---------------------------------//
		/**
		 * Vector of all currently-active markers.
		 */
		public function get activeMarkers () :Vector.<FLARMarker> {
			return this._activeMarkers;
		}
		
		/**
		 * FLARParam used by this FLARManager.
		 * can be used to instantiate a FLARCamera3D for use with Papervision.
		 */
		public function get cameraParams () :FLARParam {
			return this._cameraParams;
		}
				
		/**
		 * IFLARSource instance this FLARManager is using as the source image for marker detection.
		 */
		public function get flarSource () :IFLARSource {
			return this._flarSource;
		}
		
		/**
		 * pixels in source image with a brightness <= to this.threshold are candidates for marker outline detection.
		 * increase to increase likelihood of marker detection;
		 * increasing too high will cause engine to incorrectly detect non-existent markers.
		 * defaults to 80 (values can range from 0 to 255).
		 */
		public function get threshold () :int {
			return this._threshold;
		}
		public function set threshold (val:int) :void {
			this._threshold = val;
		}
		
		/**
		 * adaptive thresholding can result in better marker detection across a range of illumination.
		 * this is desirable for applications with low lighting, or in which the developer has little control
		 * over lighting conditions, such as with web applications.
		 * adaptive thresholding will begin at FLARManager.threshold, and vary according to FLARManager.adaptiveThresholdingStep.
		 * defaults to true.
		 * 
		 * note that adaptive thresholding may cause slower performance in very dark environments.
		 * this happens because a low threshold creates an image with large black areas,
		 * and images with a lot of black can cause slowdown in FLARToolkit's labeling process
		 * (FLARLabeling_BitmapData.labeling()).  in this case, adaptiveThresholding should be set to false.
		 * 
		 * see the following URLs for more information:
		 * http://blog.jactionscripters.com/2009/05/18/adaptive-thresholding-experiment/comment-page-1/#comment-367
		 * http://makc3d.wordpress.com/2009/07/03/alternative-to-adaptive-thresholding/
		 */
		public function get adaptiveThresholding () :Boolean {
			return this._adaptiveThresholding;
		}
		public function set adaptiveThresholding (val:Boolean) :void {
			this._adaptiveThresholding = val;
		}
		
		/**
		 * the speed at which the threshold changes during adaptive thresholding.
		 * larger values may increase the speed at which the markers in uneven illumination are detected,
		 * but may also result in instability in marker detection.
		 * 
		 * value must be zero or greater.  the default is 0.3.
		 * a value of zero will disable adaptive thresholding.
		 */
		public function get adaptiveThresholdingSpeed () :Number {
			return this._adaptiveThresholdingSpeed;
		}
		public function set adaptiveThresholdingSpeed (val:Number) :void {
			this._adaptiveThresholdingSpeed = Math.max(0, val);
		}
		
		/**
		 * the direction toward which adaptive thresholding trends.
		 * lower thresholds favor environments with too little light;
		 * higher thresholds favor environments with too much light.
		 * a value of -1 will adapt only toward a lower threshold.
		 * a value of +1 will adapt only toward a higher threshold.
		 * a value of 0 will adapt randomly in both directions, with no bias.
		 * the default is -0.1, as darker environments tend to be more common
		 * for viewing web applications than oversaturated environments.
		 */
		public function get adaptiveThresholdingBias () :Number {
			return this._adaptiveThresholdingBias;
		}
		public function set adaptiveThresholdingBias (val:Number) :void {
			this._adaptiveThresholdingBias = val;
		}
		
		/**
		 * the amount of blur applied to the source image
		 * before sending to FLARToolkit for marker detection.
		 * higher values increase framerate, but reduce detection accuracy.
		 * value must be zero or greater.  the default value is 2.
		 */
		public function get sampleBlurring () :int {
			return this._sampleBlurring;
		}
		public function set sampleBlurring (val:int) :void {
			if (!this.sampleBlurFilter) {
				this.sampleBlurFilter = new BlurFilter();
			}
			
			if (val <= 0) {
				val = 0;
				this.sampleBlurFilter.blurX = this.sampleBlurFilter.blurY = 0;
			} else {
				this.sampleBlurFilter.blurX = this.sampleBlurFilter.blurY = Math.pow(2, val-1);
			}
			
			this._sampleBlurring = val;
		}
		
		/**
		 * if a detected marker is within this distance (pixels) from an active marker,
		 * FLARManager considers the detected marker to be an update of the active marker.
		 * else, the detected marker is a new marker.
		 * increase this value to accommodate faster-moving markers;
		 * decrease it to accommodate more markers on-screen at once.
		 */
		public function get markerUpdateThreshold () :Number {
			return this._markerUpdateThreshold;
		}
		public function set markerUpdateThreshold (val:Number) :void {
			this._markerUpdateThreshold = val;
		}
		
		/**
		 * number of frames after removal that a marker will persist before dispatching a MARKER_REMOVED event.
		 * if a marker of the same pattern appears within <tt>markerUpdateThreshold</tt> pixels
		 * of the point of removal, before <tt>markerRemovalDelay</tt> frames have elapsed,
		 * the marker will be reinstated as if it was never removed.
		 * 
		 * the default value is 1.
		 */
		public function get markerRemovalDelay () :int {
			return this._markerRemovalDelay;
		}
		public function set markerRemovalDelay (val:int) :void {
			this._markerRemovalDelay = val;
		}
		
		/**
		 * apply a smoothing algorithm to transformation matrices generated by FLARToolkit.
		 * smoothing is equal to the number of frames over which FLARManager
		 * will average transformation matrices; the larger the number, the smoother the animation,
		 * and the slower the response time between marker position/orientation changes.
		 * a value of 0 turns smoothing off.
		 */ 
		public function get smoothing () :int {
			return this._smoothing;
		}
		public function set smoothing (val:int) :void {
			this._smoothing = val;
		}
		
		/**
		 * IFLARMatrixSmoother to use to apply smoothing to transformation matrices generated by FLARToolkit.
		 */
		public function get smoother () :IFLARMatrixSmoother {
			return this._smoother;
		}
		public function set smoother (val:IFLARMatrixSmoother) :void {
			this._smoother = val;
		}
		
		/**
		 * set to true to flip the camera image horizontally;
		 * this value is passed on to this.flarSource;
		 * note that if an IFLARSource is specified after mirrorDisplay is set,
		 * the 'mirrored' property of the new IFLARSource will overwrite this value. 
		 */
		public function get mirrorDisplay () :Boolean {
			return this._mirrorDisplay;
		}
		public function set mirrorDisplay (val:Boolean) :void {
			this._mirrorDisplay = val;
			if (this.flarSource) {
				this.flarSource.mirrored = this._mirrorDisplay;
			}
		}
		
		/**
		 * display the source BitmapData used by FLARToolkit post-thresholding.
		 * useful for debugging.
		 */
		public function get thresholdSourceDisplay () :Boolean {
			return this._thresholdSourceDisplay;
		}
		public function set thresholdSourceDisplay (val:Boolean) :void {
			this._thresholdSourceDisplay = val;
			if (this._thresholdSourceDisplay) {
				try {
					if (!this.thresholdSourceBitmap) {
						if (!this.markerDetector.thresholdedBitmapData) {
							throw new Error("Error initializing FLARMultiMarkerDetector; thresholdedBitmapData not inited.");
						}
						this.thresholdSourceBitmap = new Bitmap(this.markerDetector.thresholdedBitmapData);
						Sprite(this._flarSource).addChild(this.thresholdSourceBitmap);
					}
				} catch (e:Error) {
					this.thresholdSourceBitmap = null;
					return;
				}
			}
		}
		
		/**
		 * the number of patterns loaded for detection.
		 */
		public function get numLoadedPatterns () :int {
			return this.patternLoader.loadedPatterns.length;
		}
		//-----</ACCESSORS>--------------------------------//
		
		
		
		//-----<PUBLIC METHODS>----------------------------//
		/**
		 * begin detecting markers once per frame.
		 * this method is called automatically on initialization.
		 * @return		false if FLARManager is not yet initialized; else true.
		 */
		public function activate () :Boolean {
			if (!this.bInited) {
				return false;
			}
			
			if (this._flarSource is FLARProxy) {
				// activate FLARProxy
				var flarProxy:FLARProxy = this._flarSource as FLARProxy;
				flarProxy.activate();
				flarProxy.addEventListener(FLARMarkerEvent.MARKER_ADDED, this.onProxyMarkerAdded);
				flarProxy.addEventListener(FLARMarkerEvent.MARKER_UPDATED, this.onProxyMarkerUpdated);
				flarProxy.addEventListener(FLARMarkerEvent.MARKER_REMOVED, this.onProxyMarkerRemoved);
			} else {
				// activate normally
				if (!this.enterframer) {
					this.enterframer = new Sprite();
				}
				this.enterframer.addEventListener(Event.ENTER_FRAME, this.onEnterFrame, false, 0, true);
			}
			
			this._activeMarkers = new Vector.<FLARMarker>();
			this.markersPendingRemoval = new Vector.<FLARMarker>();
			
			return true;
		}
		
		/**
		 * stop detecting markers.
		 */
		public function deactivate () :void {
			if (this._flarSource is FLARProxy) {
				// deactivate FLARProxy
				var flarProxy:FLARProxy = this._flarSource as FLARProxy;
				flarProxy.deactivate();
				flarProxy.addEventListener(FLARMarkerEvent.MARKER_ADDED, this.onProxyMarkerAdded);
				flarProxy.addEventListener(FLARMarkerEvent.MARKER_UPDATED, this.onProxyMarkerUpdated);
				flarProxy.addEventListener(FLARMarkerEvent.MARKER_REMOVED, this.onProxyMarkerRemoved);
			} else {
				// deactivate normally
				if (this.enterframer) {
					this.enterframer.removeEventListener(Event.ENTER_FRAME, this.onEnterFrame);
				}
			}
			
			var i:int = this._activeMarkers.length;
			while (i--) {
				this._activeMarkers[i].dispose();
			}
			this._activeMarkers = null;
			
			i = this.markersPendingRemoval.length;
			while (i--) {
				this.markersPendingRemoval[i].dispose();
			}
			this.markersPendingRemoval = null;
		}
		//-----</PUBLIC METHODS>---------------------------//
		
		
		
		//-----<MARKER DETECTION>----------------------------//
		private function onEnterFrame (evt:Event) :void {
			if (!this.updateSource()) { return; }
			
			this.ageRemovedMarkers();
			this.performSourceAdjustments();
			this.detectMarkers();
		}
		
		private function updateSource () :Boolean {
			try {
				// ensure this.flarRaster has been initialized
				if (this.flarRaster == null) {
					this.flarRaster = new FLARRgbRaster_BitmapData(this.flarSource.source);
				}
			} catch (e:Error) {
				// this.flarSource not yet fully initialized
				return false;
			}
			
			// update source image
			this.flarSource.update();
			return true;
		}
		
		private function ageRemovedMarkers () :void {
			// remove all markers older than this.markerRemovalDelay.
			var i:uint = this.markersPendingRemoval.length;
			var removedMarker:FLARMarker;
			while (i--) {
				removedMarker = this.markersPendingRemoval[i];
				if (removedMarker.incrementRemovalAge() > this.markerRemovalDelay) {
					this.removeMarker(removedMarker);
				}
			}
		}
		
		private function performSourceAdjustments () :void {
			if (this._adaptiveThresholding && this.adaptiveThresholdingSpeed) {
				if (this.averageConfidence <= this.averageMinConfidence) {
					// low confidence (poor marker detection); adjust threshold.
					var thresholdAdaptationMod:Number = (Math.random()-0.5 + 0.5*this._adaptiveThresholdingBias);
					this.adaptiveThresholdingStep = Math.min(Math.pow(this.adaptiveThresholdingStep, 1+this._adaptiveThresholdingSpeed), ADAPTIVE_THRESHOLDING_MAX_VARIANCE);
					this.threshold += thresholdAdaptationMod * this.adaptiveThresholdingStep;
					this.threshold = Math.max(0, Math.min(this.threshold, 255));
				} else {
					this.adaptiveThresholdingStep = ADAPTIVE_THRESHOLDING_MIN_VARIANCE;
				}
				this.averageConfidence = this.averageMinConfidence = 0;
			}
			
			if (this.sampleBlurring > 0) {
				// apply blur filter to combine and reduce number of black areas in image to be labeled.
				this.flarRaster.bitmapData.applyFilter(this.flarRaster.bitmapData, this.flarSource.sourceSize, ZERO_POINT, this.sampleBlurFilter);
			}
		}
		
		private function detectMarkers () :void {
			var numFoundMarkers:int = 0;
			
			try {
				// detect marker(s)
				numFoundMarkers = this.markerDetector.detectMarkerLite(this.flarRaster, this.threshold);
			} catch (e:FLARException) {
				// error in FLARToolkit processing; send to console
				trace(e);
				return;
			}
			
			var activeMarker:FLARMarker;
			var i:uint;
			if (numFoundMarkers == 0) {
				// if no markers found, remove any existing markers and exit
				i = this._activeMarkers.length;
				while (i--) {
					this.queueMarkerForRemoval(this._activeMarkers[i]);
				}
				return;
			}
			
			// build list of detected markers
			var detectedMarkers:Vector.<FLARMarker> = new Vector.<FLARMarker>();
			var detectedMarkerResult:FLARMultiMarkerDetectorResult;
			var patternIndex:int;
			var detectedPattern:FLARPattern;
			var confidence:Number;
			var confidenceSum:Number = 0;
			var minConfidenceSum:Number = 0;
			var transmat:FLARTransMatResult;
			i = numFoundMarkers;
			while (i--) {
				detectedMarkerResult = this.markerDetector.getResult(i);
				patternIndex = this.markerDetector.getARCodeIndex(i);
				detectedPattern = this.allPatterns[patternIndex];
				confidence = this.markerDetector.getConfidence(i);
				confidenceSum += confidence;
				minConfidenceSum += detectedPattern.minConfidence;
				if (confidence < detectedPattern.minConfidence) {
					// detected marker's confidence is below the minimum required confidence for its pattern.
					continue;
				}
				
				transmat = new FLARTransMatResult();
				try {
					this.markerDetector.getTransmationMatrix(i, transmat);
				} catch (e:Error) {
					// FLARException happens with rotationX of approx -60 and +60, and rotY&Z of 0.
					// not sure why...
					continue;
				}
				
				detectedMarkers.push(new FLARMarker(detectedMarkerResult, transmat, this.flarSource));
			}
			this.averageConfidence = confidenceSum / numFoundMarkers;
			this.averageMinConfidence = minConfidenceSum / numFoundMarkers;
			
			// compare detected markers against active markers
			i = detectedMarkers.length;
			var j:uint, k:uint;
			var detectedMarker:FLARMarker;
			var closestMarker:FLARMarker;
			var closestDist:Number = Number.POSITIVE_INFINITY;
			var dist:Number;
			var updatedMarkers:Vector.<FLARMarker> = new Vector.<FLARMarker>();
			var newMarkers:Vector.<FLARMarker> = new Vector.<FLARMarker>();
			var removedMarker:FLARMarker;
			var bRemovedMarkerMatched:Boolean = false;
			while (i--) {
				j = this._activeMarkers.length;
				detectedMarker = detectedMarkers[i];
				closestMarker = null;
				closestDist = Number.POSITIVE_INFINITY;
				while (j--) {
					activeMarker = this._activeMarkers[j];
					if (detectedMarker.patternId == activeMarker.patternId) {
						dist = Point.distance(detectedMarker.centerpoint3D, activeMarker.targetCenterpoint3D);
						if (dist < closestDist && dist < this._markerUpdateThreshold) {
							closestMarker = activeMarker;
							closestDist = dist;
						}
					}
				}
				
				if (closestMarker) {
					// updated marker
					closestMarker.copy(detectedMarker);
					detectedMarker.dispose();
					if (this._smoothing) {
						if (!this._smoother) {
							// TODO: log as a WARN-level error
							trace("no smoother set; specify FLARManager.smoother to enable smoothing."); 
						} else {
							closestMarker.applySmoothing(this._smoother, this._smoothing);
						}
					}
					updatedMarkers.push(closestMarker);
					
					// if closestMarker is pending removal, restore it.
					k = this.markersPendingRemoval.length;
					while (k--) {
						if (this.markersPendingRemoval[k] == closestMarker) {
							closestMarker.resetRemovalAge();
							this.markersPendingRemoval.splice(k, 1);
						}
					}
					
					this.dispatchEvent(new FLARMarkerEvent(FLARMarkerEvent.MARKER_UPDATED, closestMarker));
				} else {
					// new marker
					newMarkers.push(detectedMarker);
					detectedMarker.setSessionId();
					this.dispatchEvent(new FLARMarkerEvent(FLARMarkerEvent.MARKER_ADDED, detectedMarker));
				}
			}
			
			i = this._activeMarkers.length;
			while (i--) {
				activeMarker = this._activeMarkers[i];
				if (updatedMarkers.indexOf(activeMarker) == -1) {
					// if activeMarker was not updated, queue it for removal.
					this.queueMarkerForRemoval(activeMarker);
				}
			}
			
			this._activeMarkers = this._activeMarkers.concat(newMarkers);
		}
		
		private function queueMarkerForRemoval (marker:FLARMarker) :void {
			if (this.markersPendingRemoval.indexOf(marker) == -1) {
				this.markersPendingRemoval.push(marker);
			}
		}
		
		private function removeMarker (marker:FLARMarker) :void {
			var i:uint = this._activeMarkers.indexOf(marker);
			if (i >= 0) {
				this._activeMarkers.splice(i, 1);
			}
			
			i = this.markersPendingRemoval.indexOf(marker);
			if (i >= 0) {
				this.markersPendingRemoval.splice(i, 1);
			}
			
			this.dispatchEvent(new FLARMarkerEvent(FLARMarkerEvent.MARKER_REMOVED, marker));
			marker.dispose();
		}
		
		private function onProxyMarkerAdded (evt:FLARMarkerEvent) :void {
			this.dispatchEvent(evt);
		}
		
		private function onProxyMarkerUpdated (evt:FLARMarkerEvent) :void {
			this.dispatchEvent(evt);
		}
		
		private function onProxyMarkerRemoved (evt:FLARMarkerEvent) :void {
			this.dispatchEvent(evt);
		}
		//-----</MARKER DETECTION>---------------------------//
		
		
		
		//-----<INITIALIZATION>----------------------------//
		private function onFlarConfigLoadError (evt:Event) :void {
			var errorText:String = "character list load error.";
			if (evt is IOErrorEvent) {
				errorText = IOErrorEvent(evt).text;
			} else if (evt is SecurityErrorEvent) {
				errorText = SecurityErrorEvent(evt).text;
			}
			
			this.onFlarConfigLoaded(evt, new Error(errorText));
		}
		
		private function onFlarConfigLoaded (evt:Event, error:Error=null) :void {
			var loader:URLLoader = evt.target as URLLoader;
			loader.removeEventListener(IOErrorEvent.IO_ERROR, this.onFlarConfigLoadError);
			loader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, this.onFlarConfigLoadError);
			loader.removeEventListener(Event.COMPLETE, this.onFlarConfigLoaded);
			
			if (error) { throw error; }
			
			this.parseFlarConfigFile(new XML(loader.data as String));
			this.dispatchEvent(new Event(Event.COMPLETE));
		}
		
		private function parseFlarConfigFile (configFileXML:XML) :void {
			// source settings
			var sourceInitStruct:SourceInitStruct = new SourceInitStruct();
			var sourceWidth:int = parseInt(configFileXML.flarSourceSettings.@sourceWidth);
			if (!isNaN(sourceWidth) && sourceWidth > 0) {
				sourceInitStruct.sourceWidth = sourceWidth;
			}
			var sourceHeight:int = parseInt(configFileXML.flarSourceSettings.@sourceHeight);
			if (!isNaN(sourceHeight) && sourceHeight > 0) {
				sourceInitStruct.sourceHeight = sourceHeight;
			}
			var displayWidth:int = parseInt(configFileXML.flarSourceSettings.@displayWidth);
			if (!isNaN(displayWidth) && displayWidth > 0) {
				sourceInitStruct.displayWidth = displayWidth;
			}
			var displayHeight:int = parseInt(configFileXML.flarSourceSettings.@displayHeight);
			if (!isNaN(displayHeight) && displayHeight > 0) {
				sourceInitStruct.displayHeight = displayHeight;
			}
			var framerate:Number = parseFloat(configFileXML.flarSourceSettings.@framerate);
			if (!isNaN(framerate) && framerate > 0) {
				sourceInitStruct.framerate = framerate;
			}
			var downsampleRatio:Number = parseFloat(configFileXML.flarSourceSettings.@downsampleRatio);
			if (!isNaN(downsampleRatio) && downsampleRatio > 0) {
				sourceInitStruct.downsampleRatio = downsampleRatio;
			}
			sourceInitStruct.loaderPath = configFileXML.flarSourceSettings.@loaderPath;
			sourceInitStruct.useProxy = configFileXML.flarSourceSettings.@useProxy == "true";
			
			
			// miscellaneous FLARManager settings
			var mirrorDisplayStr:String = configFileXML.flarManagerSettings.@mirrorDisplay.toString();
			this.mirrorDisplay = mirrorDisplayStr && mirrorDisplayStr.toLowerCase() == "true";
			
			var markerUpdateThresholdVal:Number = parseFloat(configFileXML.flarManagerSettings.@markerUpdateThreshold);
			if (!isNaN(markerUpdateThresholdVal) && markerUpdateThresholdVal > 0) {
				this.markerUpdateThreshold = markerUpdateThresholdVal;
			}
			
			var smoothingVal:int = parseInt(configFileXML.flarManagerSettings.@smoothing);
			if (!isNaN(smoothingVal) && smoothingVal > 0) {
				this.smoothing = smoothingVal;
			}
			
			if (configFileXML.flarManagerSettings.@adaptiveThresholding.toString().toLowerCase() == "true") {
				this.adaptiveThresholding = true;
			} else if (configFileXML.flarManagerSettings.@adaptiveThresholding.toString().toLowerCase() == "false") {
				this.adaptiveThresholding = false;
			}
			
			var adaptiveTholdSpeed:Number = parseFloat(configFileXML.flarManagerSettings.@adaptiveThresholdingSpeed);
			if (!isNaN(adaptiveTholdSpeed) && adaptiveTholdSpeed > 0) {
				this.adaptiveThresholdingSpeed = adaptiveTholdSpeed;
			}
			
			var adaptiveTholdBias:Number = parseFloat(configFileXML.flarManagerSettings.@adaptiveThresholdingBias);
			if (!isNaN(adaptiveTholdBias)) {
				this.adaptiveThresholdingBias = adaptiveTholdBias;
			}
			
			var sampleBlurringVal:int = parseInt(configFileXML.flarManagerSettings.@sampleBlurring);
			if (!isNaN(sampleBlurringVal) && sampleBlurringVal > 0) {
				this.sampleBlurring = sampleBlurringVal;
			}
			
			var markerRemovalDelayVal:int = parseInt(configFileXML.flarManagerSettings.@markerRemovalDelay);
			if (!isNaN(markerRemovalDelayVal) && markerRemovalDelayVal > 0) {
				this.markerRemovalDelay = markerRemovalDelayVal;
			}
			
			// camera parameters file
			var cameraParamsPath:String = configFileXML.cameraParamsFile.@path;
			
			// pattern list
			var resolution:int = parseInt(configFileXML.patterns.@resolution);
			var patternToBorderRatio:Number = parseFloat(configFileXML.patterns.@patternToBorderRatio);
			var minConfidence:Number = parseFloat(configFileXML.patterns.@minConfidence);
			var patterns:Vector.<FLARPattern> = new Vector.<FLARPattern>();
			var patternPath:String;
			for each (var pattern:XML in configFileXML.patterns.pattern) {
				patterns.push(new FLARPattern(pattern.@path, resolution, patternToBorderRatio, NaN, minConfidence));
			}
			
			this.init(cameraParamsPath, patterns, sourceInitStruct);
		}
		
		private function init (cameraParamsPath:String, patterns:Vector.<FLARPattern>, sourceInitStruct:SourceInitStruct=null) :void {
			if (!sourceInitStruct) {
				sourceInitStruct = new SourceInitStruct();
			}
			
			this.initFlarSource(sourceInitStruct);
			this.loadCameraParams(cameraParamsPath);
			this.allPatterns = patterns;
			this.loadPatterns(this.allPatterns);
			
			// initialize sampleBlurFilter
			this.sampleBlurring = this.sampleBlurring;
			
			// initialize adaptive thresholding
			this.adaptiveThresholdingStep = ADAPTIVE_THRESHOLDING_MIN_VARIANCE;
		}
		
		private function initFlarSource (sourceInitStruct:SourceInitStruct) :void {
			var sourceParent:DisplayObjectContainer;
			var sourceAsSprite:Sprite;
			var sourceIndex:int;
			if (this._flarSource) {
				if (this._flarSource.inited) {
					// do not attempt to init if source was inited before passing into FLARManager ctor.
					return;
				}
				
				sourceAsSprite = this._flarSource as Sprite;
				sourceParent = sourceAsSprite.parent;
			}
			
			if (sourceInitStruct.useProxy) {
				if (sourceParent) {
					// if placeholder IFLARSource was already added to the display list, remove it...
					sourceIndex = sourceParent.getChildIndex(sourceAsSprite);
					sourceParent.removeChild(sourceAsSprite);
				}
				
				this._flarSource = new FLARProxy(sourceInitStruct.displayWidth, sourceInitStruct.displayHeight);
				
				if (sourceParent) {
					// ...and replace it with the new FLARLoaderSource.
					sourceParent.addChildAt(Sprite(this._flarSource), sourceIndex);
				}
			} else if (sourceInitStruct.loaderPath) {
				if (sourceParent) {
					// if placeholder IFLARSource was already added to the display list, remove it...
					sourceIndex = sourceParent.getChildIndex(sourceAsSprite);
					sourceParent.removeChild(sourceAsSprite);
				}
				
				this._flarSource = new FLARLoaderSource(
					sourceInitStruct.loaderPath, sourceInitStruct.sourceWidth,
					sourceInitStruct.sourceHeight, sourceInitStruct.downsampleRatio);
				
				if (sourceParent) {
					// ...and replace it with the new FLARLoaderSource.
					sourceParent.addChildAt(Sprite(this._flarSource), sourceIndex);
				}
			} else {
				try {
					FLARCameraSource(this._flarSource).init(
						sourceInitStruct.sourceWidth, sourceInitStruct.sourceHeight,
						sourceInitStruct.framerate, this._mirrorDisplay,
						sourceInitStruct.displayWidth, sourceInitStruct.displayHeight,
						sourceInitStruct.downsampleRatio);
				} catch (e:Error) {
					this.dispatchEvent(new ErrorEvent(ErrorEvent.ERROR, false, false, e.message));
				}
			}
		}
		
		private function loadCameraParams (cameraParamsPath:String) :void {
			var loader:URLLoader = new URLLoader();
			loader.dataFormat = URLLoaderDataFormat.BINARY;
			loader.addEventListener(IOErrorEvent.IO_ERROR, this.onCameraParamsLoadError);
			loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, this.onCameraParamsLoadError);
			loader.addEventListener(Event.COMPLETE, this.onCameraParamsLoaded);
			loader.load(new URLRequest(cameraParamsPath));
		}
		
		private function onCameraParamsLoadError (evt:Event) :void {
			var errorText:String = "Camera params load error.";
			if (evt is IOErrorEvent) {
				errorText = IOErrorEvent(evt).text;
			} else if (evt is SecurityErrorEvent) {
				errorText = SecurityErrorEvent(evt).text;
			}
			
			this.onCameraParamsLoaded(evt, new Error(errorText));
		}
		
		private function onCameraParamsLoaded (evt:Event, error:Error=null) :void {
			var loader:URLLoader = evt.target as URLLoader;
			loader.removeEventListener(IOErrorEvent.IO_ERROR, this.onCameraParamsLoadError);
			loader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, this.onCameraParamsLoadError);
			loader.removeEventListener(Event.COMPLETE, this.onCameraParamsLoaded);
			
			if (error) { throw error; }
			
			this._cameraParams = new FLARParam();
			this._cameraParams.loadARParam(ByteArray(loader.data));
			var sourceSize:Rectangle = this.flarSource.sourceSize;
			this._cameraParams.changeScreenSize(sourceSize.width, sourceSize.height);
			
			this.bCameraParamsLoaded = true;
			this.checkForInitComplete();
		}
		
		private function loadPatterns (patterns:Vector.<FLARPattern>) :void {
			this.patternLoader = new FLARPatternLoader();
			this.patternLoader.addEventListener(Event.INIT, this.onPatternsLoaded);
			this.patternLoader.loadPatterns(patterns);
		}
		
		private function onPatternsLoaded (evt:Event) :void {
			this.patternLoader.removeEventListener(Event.INIT, this.onPatternsLoaded);
			this.bPatternsLoaded = true;
			this.checkForInitComplete();
		}
		
		private function checkForInitComplete () :void {
			if (!this.bCameraParamsLoaded || !this.bPatternsLoaded || !this._flarSource) { return; }
			
			if (this.patternLoader.loadedPatterns.length == 0) {
				throw new Error("no markers successfully loaded.");
			}
			
			try {
				this.flarRaster = new FLARRgbRaster_BitmapData(this.flarSource.source);
			} catch (e:Error) {
				// this.flarSource not yet fully initialized
				this.flarRaster = null;
			}
			
			this.markerDetector = new FLARMultiMarkerDetector(this._cameraParams, this.patternLoader.loadedPatterns, this.patternLoader.unscaledMarkerWidths, this.patternLoader.loadedPatterns.length);
			//this.markerDetector.setContinueMode(true);
			if (this.thresholdSourceDisplay) {
				// if this.thresholdSourceDisplay was set to true before initialization of
				// this.flarSource and this.markerDetector, reset it.
				this.thresholdSourceDisplay = true;
			}
			
			this.smoother = new FLARMatrixSmoother_Average();
			
			this.bInited = true;
			this.activate();
			
			this.dispatchEvent(new Event(Event.INIT));
		}
		//-----</INITIALIZATION>---------------------------//
	}
}

internal class SourceInitStruct {
	internal var sourceWidth:int = 640;
	internal var sourceHeight:int = 480;
	internal var displayWidth:int = 640;
	internal var displayHeight:int = 480;
	internal var framerate:Number = 30;
	internal var downsampleRatio:Number = 0.5;
	internal var useProxy:Boolean = false;
	internal var loaderPath:String = "";
	
	public function SourceInitStruct () {}
}