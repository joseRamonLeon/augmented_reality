package examples {
	import com.transmote.flar.FLARManager;
	import com.transmote.flar.marker.FLARMarkerEvent;
	
	import flash.display.Sprite;
	
	/**
	 * FLARManager_Tutorial2D demonstrates how to set up a basic FLARManager application. 
	 * see the accompanying tutorial writeup here:
	 * http://words.transmote.com/wp/flarmanager/inside-flarmanager/2d-marker-tracking/
	 * 
	 * @author	Eric Socolofsky
	 * @url		http://transmote.com/flar
	 */
	public class FLARManagerTutorial_2D extends Sprite {
		private var flarManager:FLARManager;
		private var drawSurface:Sprite;
		
		public function FLARManagerTutorial_2D () {
			// pass the path to the FLARManager xml config file into the FLARManager constructor.
			// FLARManager creates and uses a FLARCameraSource by default.
			// the image from the first detected camera will be used for marker detection.
			this.flarManager = new FLARManager();
			
			// pass the path to the FLARManager config file into FLARManager.initFromFile.
			this.flarManager.initFromFile("../resources/flar/flarConfig.xml");
			
			// add FLARManager.flarSource to the display list to display the video capture.
			this.addChild(Sprite(this.flarManager.flarSource));
			
			// add a Sprite into which to draw rectangles for detected markers.
			this.drawSurface = new Sprite();
			this.addChild(this.drawSurface);
			
			// begin listening for FLARMarkerEvents.
			this.flarManager.addEventListener(FLARMarkerEvent.MARKER_ADDED, this.onMarkerAdded);
			this.flarManager.addEventListener(FLARMarkerEvent.MARKER_UPDATED, this.onMarkerUpdated);
			this.flarManager.addEventListener(FLARMarkerEvent.MARKER_REMOVED, this.onMarkerRemoved);
		}
		
		private function onMarkerAdded (evt:FLARMarkerEvent) :void {
			trace("["+evt.marker.patternId+"] added");
			
			// draw a thick red circle where a new marker is added.
			this.drawSurface.graphics.clear();
			this.drawSurface.graphics.lineStyle(4, 0xFF0000);
			this.drawSurface.graphics.drawCircle(evt.marker.centerpoint.x, evt.marker.centerpoint.y, 40);
		}
		
		private function onMarkerUpdated (evt:FLARMarkerEvent) :void {
			trace("["+evt.marker.patternId+"] updated");
			
			// draw a thin green circle at the marker's new position.
			this.drawSurface.graphics.clear();
			this.drawSurface.graphics.lineStyle(1, 0x00FF00);
			this.drawSurface.graphics.drawCircle(evt.marker.centerpoint.x, evt.marker.centerpoint.y, 40);
		}
		
		private function onMarkerRemoved (evt:FLARMarkerEvent) :void {
			trace("["+evt.marker.patternId+"] removed");
			
			// erase the circle.
			this.drawSurface.graphics.clear();
		}
	}
}