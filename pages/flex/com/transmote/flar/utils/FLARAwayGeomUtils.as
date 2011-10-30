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

package com.transmote.flar.utils {
	import away3d.core.math.Matrix3D;
	
	import org.libspark.flartoolkit.core.types.matrix.FLARDoubleMatrix34;
	
	/**
	 * @author	Eric Socolofsky
	 * @url		http://transmote.com/flar
	 */
	public class FLARAwayGeomUtils {
		
		public static function convertFLARMatrixToAwayMatrix (fm:FLARDoubleMatrix34) :Matrix3D {
			var m:Matrix3D = new Matrix3D();
			m.sxx = fm.m00;		m.sxy = fm.m02;		m.sxz = fm.m01;		m.tx = fm.m03;
			m.syx = -fm.m10;	m.syy = -fm.m12;	m.syz = -fm.m11;	m.ty = -fm.m13;
			m.szx = fm.m20;		m.szy = fm.m22;		m.szz = fm.m21;		m.tz = fm.m23;
			return m;
		}
		
		public function FLARAwayGeomUtils () {}
	}
}