package examples.support {
	import com.transmote.flar.marker.FLARMarker;
	
	import flash.display.Shape;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.geom.Point;
	
	import org.libspark.flartoolkit.core.types.FLARDoublePoint2d;
	
	/**
	 * simple class to draw outlines around detected markers.
	 * 
	 * @author	Eric Socolofsky
	 * @url		http://transmote.com/flar
	 */
	public class MarkerOutliner extends Sprite {
		private var slate_corners:Shape;
		private var slate_vector3D:Shape;
		
		public function MarkerOutliner () {
			this.addEventListener(Event.ENTER_FRAME, this.onEnterFrame);
			this.slate_corners = new Shape();
			this.slate_vector3D = new Shape();
			this.addChild(this.slate_corners);
			this.addChild(this.slate_vector3D);
		}
		
		public function drawOutlines (marker:FLARMarker, thickness:Number, color:Number) :void {
			this.drawCornersOutline(marker, thickness, color);
		}
		
		/**
		 * draw marker outline using the four corners of the detected marker.
		 */
		public function drawCornersOutline (marker:FLARMarker, thickness:Number, color:Number) :void {
			this.slate_corners.graphics.lineStyle(thickness, color);
			var corners:Vector.<Point> = marker.corners;
			var vertex:Point = corners[0];
			this.slate_corners.graphics.moveTo(vertex.x, vertex.y);
			for (var i:uint=1; i<corners.length; i++) {
				vertex = corners[i];
				this.slate_corners.graphics.lineTo(vertex.x, vertex.y)
			}
			vertex = corners[0];
			this.slate_corners.graphics.lineTo(vertex.x, vertex.y);
		}
		
		/**
		 * draw marker outline using x, y, and rotationZ from FLARMarker.vector3D.
		 */
		public function drawOutlineVector3D (marker:FLARMarker) :void {
			var size:Number = 80;
			
			this.slate_vector3D.x = marker.vector3D.x + 0.5*this.stage.stageWidth;
			this.slate_vector3D.y = marker.vector3D.y + 0.5*this.stage.stageHeight;
			this.slate_vector3D.rotation = marker.vector3D.w;
			
			this.slate_vector3D.graphics.lineStyle(1, 0x00FF00);
			this.slate_vector3D.graphics.drawRect(-0.5*size, -0.5*size, size, size);
			
//			trace("("+marker.vector3D.x+","+marker.vector3D.y+","+marker.vector3D.z+","+marker.vector3D.w+")");
		}
		
		private function onEnterFrame (evt:Event) :void {
			this.slate_corners.graphics.clear();
			this.slate_vector3D.graphics.clear();
		}
	}
}