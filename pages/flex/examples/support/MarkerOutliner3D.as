package examples.support {
	import com.transmote.flar.marker.FLARMarker;
	import com.transmote.flar.utils.FLARGeomUtils;
	
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.utils.Dictionary;
	
	/**
	 * draws outlines around detected markers, using Flash Player 10's 3D capabilities.
	 * 
	 * @author	Eric Socolofsky
	 * @url		http://transmote.com/flar
	 */
	public class MarkerOutliner3D extends Sprite {
		private var markers:Vector.<FLARMarker>;
		private var markerOutlines:Dictionary;		// marker outlines (Sprites), hashed by FLARMarker
		
		public function MarkerOutliner3D () {
			this.markers = new Vector.<FLARMarker>();
			this.markerOutlines = new Dictionary(true);
			this.addEventListener(Event.ENTER_FRAME, this.onEnterFrame);
		}
		
		public function addMarker (marker:FLARMarker) :void {
			this.markers.push(marker);
			
			var outline:Sprite = new Sprite();
			this.markerOutlines[marker] = outline;
			this.addChild(outline);
			
			var outArrow:Sprite = new Sprite();
			outArrow.rotationX = 90;
			outline.addChild(outArrow);
			
			var outArrow2:Sprite = new Sprite();
			outArrow2.rotationX = 90;
			outArrow2.rotationZ = 90;
			outline.addChild(outArrow2);
		}
		
		public function removeMarker (marker:FLARMarker) :void {
			var markerIndex:uint = this.markers.indexOf(marker);
			if (markerIndex != -1) {
				this.markers.splice(markerIndex, 1);
			}
			
			var outline:Sprite = this.markerOutlines[marker];
			if (outline) {
				this.removeChild(outline);
				delete this.markerOutlines[marker];
			}
		}
		
		private function onEnterFrame (evt:Event) :void {
			this.drawOutlines();
		}
		
		private function drawOutlines () :void {
			var marker:FLARMarker;
			var outline:Sprite;
			for (var key:* in this.markerOutlines) {
				marker = key as FLARMarker;
				
				outline = this.markerOutlines[marker];
				outline.graphics.clear();
				outline.graphics.lineStyle(2, 0xFF0000);
				outline.graphics.drawRect(-40, -40, 80, 80);
				outline.graphics.lineStyle(4, 0xFF0000);
				outline.graphics.moveTo(0, 0);
				outline.graphics.lineTo(0, -40);
				outline.graphics.lineTo(-10, -30);
				outline.graphics.lineTo(0, -40);
				outline.graphics.lineTo(10, -30);
				
				var outArrow:Sprite = Sprite(outline.getChildAt(0));
				outArrow.graphics.clear();
				outArrow.graphics.lineStyle(4, 0x00FF00);
				outArrow.graphics.moveTo(0, 0);
				outArrow.graphics.lineTo(0, -40);
				outArrow.graphics.lineTo(-10, -30);
				outArrow.graphics.lineTo(0, -40);
				outArrow.graphics.lineTo(10, -30);
				
				var outArrow2:Sprite = Sprite(outline.getChildAt(1));
				outArrow2.graphics.clear();
				outArrow2.graphics.lineStyle(4, 0x00FF00);
				outArrow2.graphics.moveTo(0, 0);
				outArrow2.graphics.lineTo(0, -40);
				outArrow2.graphics.lineTo(-10, -30);
				outArrow2.graphics.lineTo(0, -40);
				outArrow2.graphics.lineTo(10, -30);
				
				outline.transform.matrix3D = FLARGeomUtils.convertFLARMatrixToFlashMatrix(marker.transformMatrix);
			}
		}
	}
}