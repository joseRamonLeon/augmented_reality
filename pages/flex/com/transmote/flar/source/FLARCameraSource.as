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

package com.transmote.flar.source {
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.Sprite;
	import flash.geom.Matrix;
	import flash.geom.Rectangle;
	import flash.media.Camera;
	import flash.media.Video;

	/**
	 * Use the contents of a Camera feed as a source image for FLARToolkit marker detection.
	 * 
	 * @author	Eric Socolofsky
	 * @url		http://transmote.com/flar
	 * @see		com.transmote.flar.FLARManager
	 */
	public class FLARCameraSource extends Sprite implements IFLARSource {
		private var _resultsToDisplayRatio:Number;
		private var _mirrored:Boolean;
		private var _inited:Boolean;
		
		private var camera:Camera;
		private var video:Video;
		private var downsampleRatio:Number;
		
		private var displayBmpData:BitmapData;
		private var displayBitmap:Bitmap;
		private var displayMatrix:Matrix;
		
		private var sampleWidth:Number;
		private var sampleHeight:Number;
		private var sampleBmpData:BitmapData;
		private var sampleBitmap:Bitmap;
		private var sampleMatrix:Matrix;
		
		/**
		 * constructor.
		 */
		public function FLARCameraSource () {}
		
		/**
		 * Initialize this FLARCameraSource.
		 * @param	captureWidth		width at which to capture video.
		 * @param	captureHeight		height at which to capture video.
		 * @param	fps					framerate of camera capture.
		 * @param	mirrored			if true, video is flipped horizontally. 
		 * @param	displayWidth		width at which to display video.
		 * @param	displayHeight		height at which to display video.
		 * @param	downsampleRatio		amount to downsample camera input.
		 *								The captured video is scaled down by this value
		 * 								before being sent to FLARToolkit for analysis.  
		 * 								FLARToolkit runs faster with more downsampling,
		 * 								but also has more difficulty recognizing marker patterns.
		 * 								a value of 1.0 results in no downsampling;
		 * 								a value of 0.5 (the default) downsamples the camera input by half.
		 * 
		 * @throws	Error				if no camera is found.
		 * 								(thrown by this.initCamera, called from this method.)
		 */
		public function init (
			captureWidth:int=320, captureHeight:int=240,
			fps:Number=30, mirrored:Boolean=true,
			displayWidth:int=-1, displayHeight:int=-1,
			downsampleRatio:Number=0.5) :void {
			
			// NOTE: removed init from ctor and made public to allow instantiation and addition to display list
			//		 while waiting for configuration file to load.
			
			if (displayWidth == -1) {
				displayWidth = captureWidth;
			}
			if (displayHeight == -1) {
				displayHeight = captureHeight;
			}
			
			this.initCamera(captureWidth, captureHeight, fps);
			
			this.downsampleRatio = downsampleRatio;
			
			// sampleWidth/Height describe size of BitmapData sent to FLARToolkit every frame
			this.sampleWidth = captureWidth * this.downsampleRatio;
			this.sampleHeight = captureHeight * this.downsampleRatio;

			// scale and crop camera source to fit within specified display width/height.
			var fitWidthRatio:Number = displayWidth / captureWidth;
			var fitHeightRatio:Number = displayHeight / captureHeight;
			
			var videoWidth:Number, videoHeight:Number;
			var videoX:Number=0, videoY:Number=0;
			
			if (fitHeightRatio > fitWidthRatio) {
				// fit to height, center horizontally, crop left/right edges
				videoWidth = fitHeightRatio * captureWidth;
				videoHeight = displayHeight;
				videoX = -0.5 * (videoWidth - displayWidth);
				this._resultsToDisplayRatio = 1 / fitHeightRatio;
				this.sampleWidth = this.sampleHeight * (displayWidth/displayHeight);
			} else {
				// fit to width, center vertically, crop top/bottom edges
				videoWidth = displayWidth;
				videoHeight = fitWidthRatio * captureHeight;
				videoY = -0.5 * (videoHeight - displayHeight);
				this._resultsToDisplayRatio = 1 / fitWidthRatio;
				this.sampleHeight = this.sampleWidth / (displayWidth/displayHeight);
			}
			this._resultsToDisplayRatio *= this.downsampleRatio;
			
			// source video
			this.video = new Video(videoWidth, videoHeight);
			this.video.x = videoX;
			this.video.y = videoY;
			this.video.attachCamera(this.camera);
			
			// BitmapData downsampled from source video, sent to FLARToolkit every frame
			this.sampleBmpData = new BitmapData(this.sampleWidth, this.sampleHeight, false, 0);
			this.sampleBitmap = new Bitmap(this.sampleBmpData);
			this.sampleBitmap.width = displayWidth;
			this.sampleBitmap.height = displayHeight;
			
			// cropped, full-res video displayed on-screen
			this.displayBmpData = new BitmapData(displayWidth, displayHeight, false, 0);
			this.displayBitmap = new Bitmap(this.displayBmpData);
			
			// cropped, full-res video for display
			this.addChild(this.displayBitmap);
			
			// uncomment to view source video
//			this.addChild(this.video);
			
			// uncomment to view downsampled video sent to FLARToolkit
//			this.addChild(this.sampleBitmap);
			
			// calls buildSampleMatrices
			this.mirrored = mirrored;
			
			this._inited = true;
		}
		
		/**
		 * update the BitmapData source.
		 */
		public function update () :void {
			this.displayBmpData.draw(this.video, this.displayMatrix);
			this.sampleBmpData.draw(this.video, this.sampleMatrix);
		}
		
		/**
		 * retrieve the BitmapData source used for analysis.
		 * NOTE: returns the actual BitmapData object, not a clone.
		 */
		public function get source () :BitmapData {
			return this.sampleBmpData;
		}
		
		/**
		 * size of BitmapData source used for analysis.
		 */
		public function get sourceSize () :Rectangle {
			return new Rectangle(0, 0, this.sampleWidth, this.sampleHeight);
		}
		
		/**
		 * ratio of area of reported results to display size.
		 * use to scale (multiply) results of FLARToolkit analysis to correctly fit display area.
		 */
		public function get resultsToDisplayRatio () :Number {
			return this._resultsToDisplayRatio;
		}
		
		/**
		 * set to true to flip the camera image horizontally.
		 */
		public function get mirrored () :Boolean {
			return this._mirrored;
		}
		public function set mirrored (val:Boolean) :void {
			this._mirrored = val;
			this.buildSampleMatrices();
		}
		
		/**
		 * returns true if initialization is complete.
		 */
		public function get inited () :Boolean {
			return this._inited;
		}
		
		private function initCamera (captureWidth:int, captureHeight:int, fps:int) :void {
			// set up Camera to capture source video
			var i:uint = Camera.names.length;
			while (i--) {
				// auto-select built-in USB camera (i.e. Mac ISight)
				if (Camera.names[i] == "USB Video Class Video") {
					break;
				}
			}
			
			// if no "USB Video Class Video" camera found, use default camera.
			if (i == uint.MAX_VALUE) {
				this.camera = Camera.getCamera();
			} else {
				this.camera = Camera.getCamera(i.toString());
			}			
			
			if (!this.camera) {
				throw new Error("Camera not found.  Please check your connections and ensure that your camera is not in use by another application.");
			}
			
			this.camera.setMode(captureWidth, captureHeight, fps);
		}
		
		private function buildSampleMatrices () :void {
			if (!this.video) { return; }
			
			// construct transformation matrix used when updating displayed video
			// and when updating BitmapData source for FLARToolkit
			if (this._mirrored) {
				this.displayMatrix = new Matrix(-1, 0, 0, 1, this.video.width+this.video.x, this.video.y);
			} else {
				this.displayMatrix = new Matrix(1, 0, 0, 1, this.video.x, this.video.y);
			}
			
			// source does not get mirrored;
			// FLARToolkit must be able to recognize non-mirrored patterns.
			// transformation mirroring happens in FLARManager.detectMarkers().
			this.sampleMatrix = new Matrix(
				this._resultsToDisplayRatio, 0,
				0, this._resultsToDisplayRatio,
				this._resultsToDisplayRatio*this.video.x,
				this._resultsToDisplayRatio*this.video.y);
		}
	}
}