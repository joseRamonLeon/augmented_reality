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

package com.transmote.flar.marker {
	import __AS3__.vec.Vector;
	
	import com.transmote.flar.source.IFLARSource;
	import com.transmote.flar.utils.FLARGeomUtils;
	import com.transmote.flar.utils.IFLARMatrixSmoother;
	
	import flash.geom.Point;
	import flash.geom.Vector3D;
	
	import org.libspark.flartoolkit.core.FLARSquare;
	import org.libspark.flartoolkit.core.types.FLARDoublePoint2d;
	import org.libspark.flartoolkit.core.types.FLARIntPoint;
	import org.libspark.flartoolkit.core.types.FLARLinear;
	import org.libspark.flartoolkit.core.types.matrix.FLARDoubleMatrix34;
	import org.libspark.flartoolkit.detector.FLARMultiMarkerDetectorResult;
	
	/**
	 * <p>
	 * Container for information about a detected marker, including:<br>
	 * <ul>
	 * <li>pattern and session ids</li>
	 * <li>centerpoint of marker</li>
	 * <li>corners of marker outline</li>
	 * <li>Vector3D instance that describes x, y, and z location, and rotation (in the z-axis) of marker</li>
	 * <li>rotation of marker around x, y, and z axes</li>
	 * </ul>
	 * </p>
	 * 
	 * @author	Eric Socolofsky
	 * @url		http://transmote.com/flar
	 * @see		com.transmote.flar.marker.FLARMarkerEvent
	 */
	public class FLARMarker {
		private static var sessionIdCounter:uint = 0;
		
		internal var _sessionId:int = -1;
		internal var _patternId:int;
		internal var _direction:int;
		internal var _flarSquare:FLARSquare;
		internal var _confidence:Number;
		internal var _transformMatrix:FLARDoubleMatrix34;
		internal var _flarSource:IFLARSource;
		
		private var matrixHistory:Vector.<FLARDoubleMatrix34>;
		private var screenCenter:Point;
		
		internal var _centerpoint2D:Point = null;
		internal var _centerpoint3D:Point = null;
		internal var _vector3D:Vector3D = null;
		internal var _rotationX:Number = NaN;
		internal var _rotationY:Number = NaN;
		internal var _rotationZ:Number = NaN;
		
		private var rotations:Vector3D;
		private var _corners:Vector.<Point>;
		
		private var removalAge:uint = 0;
		
		/**
		 * constructor.
		 */
		public function FLARMarker (detectorResult:FLARMultiMarkerDetectorResult, transformMatrix:FLARDoubleMatrix34,
			flarSource:IFLARSource) {
			
			this._patternId = detectorResult.codeId;
			this._direction = detectorResult.direction;
			this._flarSquare = detectorResult.square;
			this._confidence = detectorResult.confidence;
			this._transformMatrix = transformMatrix;
			this._flarSource = flarSource;
			
			if (this._flarSource.mirrored) {
				this.mirror();
			}
			
			this.screenCenter = new Point(0.5*this._flarSource.sourceSize.width, 0.5*this._flarSource.sourceSize.height);
			this.calcCorners();
		}
		
		/**
		 * copy the properties of a FLARMarker into this FLARMarker.
		 */
		public function copy (otherMarker:FLARMarker) :void {
			this._patternId = otherMarker._patternId;
			this._direction = otherMarker._direction;
			this._flarSquare = otherMarker._flarSquare;
			this._confidence = otherMarker._confidence;
			this._transformMatrix = otherMarker._transformMatrix;
			this._flarSource = otherMarker._flarSource;
			
			this.resetAllCalculations();
		}
		
		/**
		 * reset removal age to zero.
		 * removal age is the number of frames that have elapsed since this FLARMarker was last detected by FLARToolkit.
		 * this method is used by FLARManager, and should generally not be called by developers.
		 */
		public function resetRemovalAge () :void {
			this.removalAge = 0;
		}
		
		/**
		 * increment removal age by one.
		 * removal age is the number of frames that have elapsed since this FLARMarker was last detected by FLARToolkit.
		 * this method is used by FLARManager, and should generally not be called by developers.
		 */
		public function incrementRemovalAge () :uint {
			return ++this.removalAge;
		}
		
		/**
		 * ID unique to this marker in this session.
		 * no two markers in a session share the same sessionId.
		 */
		public function get sessionId () :uint {
			return this._sessionId;
		}
		
		/**
		 * called only by FLARManager, when a new FLARMarker is detected.
		 * this method should not be called by developers.
		 * (poor OOP, i know....sorry.)
		 */
		public function setSessionId () :void {
			if (this._sessionId == -1) {
				this._sessionId = FLARMarker.sessionIdCounter++;
			}
		}
		
		/**
		 * ID of this marker's pattern.
		 * pattern IDs are zero-indexed, and are
		 * assigned to patterns in the order they were initially loaded.
		 */
		public function get patternId () :int {
			return this._patternId;
		}
		
		/**
		 * closest orthographic orientation of detected marker.
		 * value between 0 and 3, inclusive:
		 * 0: up
		 * 1: left
		 * 2: down
		 * 3: right
		 */
		public function get direction () :int {
			return this._direction;
		}
		
		/**
		 * 'confidence' is a value assigned by FLARToolkit to each detected marker,
		 * that describes the algorithm's perceived accuracy of the pattern match.
		 */
		public function get confidence () :Number {
			return this._confidence;
		}
		
		/**
		 * FLARDoubleMatrix34 matrix that describes transformation of marker relative to the camera.
		 * apply to FLARBaseNodes that should appear 'tethered' to the marker.
		 */
		public function get transformMatrix () :FLARDoubleMatrix34 {
			return this._transformMatrix;
		}
		
		/**
		 * FLARSquare instance used to create this FLARMarker instance.
		 * can be accessed if direct access to FLARToolkit output is desired;
		 * no downsampling correction is applied.
		 */
		public function get flarSquare () :FLARSquare {
			return this._flarSquare;
		}
		
		public function get corners () :Vector.<Point> {
			return this._corners;
		}
		
		/**
		 * centerpoint of marker outline in the 2D space of the screen,
		 * calculated as the average of the outline's four corner points.
		 * to access the centerpoint reported by FLARToolkit in three dimensions,
		 * use FLARMarker.centerpoint.
		 */
		public function get centerpoint () :Point {
			if (!this._centerpoint2D) {
				this._centerpoint2D = this.calcCenterpoint2D();
			}
			return this._centerpoint2D;
		}
		
		/**
		 * centerpoint of marker outline extracted from FLARToolkit transformation matrix.
		 * this centerpoint is determined based on the 3D location of the detected marker,
		 * and is used by FLARManager in 3D calculations.
		 * to avoid having to correct for Z location, use centerpoint2D.
		 */
		public function get centerpoint3D () :Point {
			if (!this._centerpoint3D) {
				this._centerpoint3D = this.calcCenterpoint3D(this._transformMatrix);
			}
			return this._centerpoint3D;
		}
		
		/**
		 * returns centerpoint at location toward which this FLARMarker is moving
		 * (target location at end of smoothing animation).
		 */
		public function get targetCenterpoint3D () :Point {
			if (!this.matrixHistory) {
				return this.centerpoint3D;
			}
			
			// find most recent stored transformation matrix
			var i:int = this.matrixHistory.length - 1;
			while (this.matrixHistory[i] == null) {
				i--;
				if (i == -1) {
					return this.centerpoint3D;
				}
			}
						
			return this.calcCenterpoint3D(this.matrixHistory[i]);
		}
		
		/**
		 * Vector3D instance that describes x, y, and z coordinates,
		 * as well as rotationZ (stored as vector3D.w).
		 */
		public function get vector3D () :Vector3D {
			if (!this._vector3D) {
				if (this._transformMatrix) {
					this._vector3D = new Vector3D(
						this._transformMatrix.m03 / this._flarSource.resultsToDisplayRatio,
						this._transformMatrix.m13 / this._flarSource.resultsToDisplayRatio,
						this._transformMatrix.m23, this.rotationZ);
				} else {
					// no transformMatrix when using FLARProxy
					this._vector3D = new Vector3D(this.centerpoint.x, this.centerpoint.y, 0, 0);
				}
			}
			return this._vector3D;
		}
		
		/**
		 * rotation of marker along X axis.
		 */
		public function get rotationX () :Number {
			if (!this.rotations) {
				this.calcRotations();
			}
			return this.rotations.x;
		}
		
		/**
		 * rotation of marker along Y axis.
		 */
		public function get rotationY () :Number {
			if (!this.rotations) {
				this.calcRotations();
			}
			return this.rotations.y;
		}
		
		/**
		 * rotation of marker along Z axis.
		 */
		public function get rotationZ () :Number {
			if (!this.rotations) {
				this.calcRotations();
			}
			return this.rotations.z;
		}
		
		/**
		 * apply smoothing algorithm over a number of frames.
		 * called by FLARManager as part of marker tracking/maintenance process.
		 */
		public function applySmoothing (smoother:IFLARMatrixSmoother, numFrames:int) :void {
			if (!this.matrixHistory) {
				this.matrixHistory = new Vector.<FLARDoubleMatrix34>(numFrames, false);
			} else if (this.matrixHistory.length != numFrames) {
				this.matrixHistory.length = numFrames;
			}
			
			for (var i:int=0; i<numFrames-1; i++) {
				this.matrixHistory[i] = this.matrixHistory[i+1]
			}
			this.matrixHistory[i] = this._transformMatrix;
			
			this._transformMatrix = smoother.smoothMatrices(this.matrixHistory);
		}
		
		/**
		 * free this FLARMarker instance up for garbage collection.
		 */
		public function dispose () :void {
			this._flarSquare = null;
			this._transformMatrix = null;
			this._flarSource = null;
			this.matrixHistory = null;
			this._centerpoint2D = null;
			this._centerpoint3D = null;
			this._vector3D = null;
			this.rotations = null;
			this._corners = null;
		}
		
		public function toString () :String {
			return ("FLARMarker [sId:"+ this.sessionId +", patternId:"+ this.patternId +"]");
		}
		
		private function mirror () :void {
			const sourceWidth:Number = this._flarSource.sourceSize.width;
			
			// mirror FLARSquare
			var i:int = 4;
			var flarCorner:FLARDoublePoint2d;
			var flarCornerInt:FLARIntPoint;
			var flarLine:FLARLinear;
			while (i--) {
				flarCorner = FLARDoublePoint2d(this.flarSquare.sqvertex[i]);
				flarCorner.x = sourceWidth - flarCorner.x;
				
				// NOTE: flarCornerInt and flarLine mirroring is untested.
				flarCornerInt = FLARIntPoint(this.flarSquare.imvertex[i]);
				flarCornerInt.x = sourceWidth - flarCornerInt.x;
				
				flarLine = FLARLinear(this.flarSquare.line[i]);
				flarLine.run *= -1;
			}
			
			// mirror FLARDoubleMatrix34
			/*
			// NOTE: this works for Flash 3D, but not for PV3D...
			this._transformMatrix.m00 *= -1;
			this._transformMatrix.m01 *= -1;
			this._transformMatrix.m02 *= -1;
			this._transformMatrix.m03 *= -1;
			*/
		}
		
		private function calcCenterpoint2D () :Point {
			var x:Number = 0;
			var y:Number = 0;
			var i:int = 4;
			while (i--) {
				x += this.corners[i].x;
				y += this.corners[i].y;
			}
			return new Point(0.25*x, 0.25*y);
		}
		
		private function calcCenterpoint3D (matrix:FLARDoubleMatrix34) :Point {
			var centerPt:Point = new Point(this.screenCenter.x + matrix.m03, this.screenCenter.y + matrix.m13);
			centerPt.x /= this._flarSource.resultsToDisplayRatio;
			centerPt.y /= this._flarSource.resultsToDisplayRatio;
			return centerPt;
		}
		
		private function calcCorners () :void {
			this._corners = new Vector.<Point>(4);
			var i:int = 4;
			var flarCorner:FLARDoublePoint2d;
			while (i--) {
				flarCorner = FLARDoublePoint2d(this.flarSquare.sqvertex[i]);
				this._corners[i] = new Point(flarCorner.x / this._flarSource.resultsToDisplayRatio, flarCorner.y / this._flarSource.resultsToDisplayRatio);
			}
		}
		
		private function calcRotations () :void {
			this.rotations = FLARGeomUtils.calcFLARMatrixRotations(this._transformMatrix);
		}
		
		private function resetAllCalculations () :void {
			this._centerpoint2D = null;
			this._centerpoint3D = null;
			this._vector3D = null;
			this.rotations = null;
			this.calcCorners();
		}
	}
}