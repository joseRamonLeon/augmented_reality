package examples {
	import com.transmote.flar.FLARManager;
	import com.transmote.flar.marker.FLARMarkerEvent;
	import com.transmote.utils.time.FramerateDisplay;
	
	import examples.support.MarkerOutliner;
	
	import flash.display.Sprite;
	import flash.events.ErrorEvent;
	
	/**
	 * FLARManagerExample_2D simply draws an outline around all detected markers.
	 * 
	 * @author	Eric Socolofsky
	 * @url		http://transmote.com/flar
	 */
	public class FLARManagerExample_2D extends Sprite {
		private var flarManager:FLARManager;
		private var markerOutliner:MarkerOutliner;
		
		public function FLARManagerExample_2D () {
			this.init();
		}
		
		private function init () :void {
			// pass the path to the FLARManager xml config file into the FLARManager constructor.
			// FLARManager creates and uses a FLARCameraSource by default.
			// the image from the first detected camera will be used for marker detection.
			this.flarManager = new FLARManager("../resources/flar/flarConfig.xml");
			
			// handle any errors generated during FLARManager initialization.
			this.flarManager.addEventListener(ErrorEvent.ERROR, this.onFlarManagerError);
			
			// add FLARManager.flarSource to the display list to display the video capture.
			this.addChild(Sprite(this.flarManager.flarSource));
			
			// begin listening for FLARMarkerEvents.
			this.flarManager.addEventListener(FLARMarkerEvent.MARKER_ADDED, this.onMarkerAdded);
			this.flarManager.addEventListener(FLARMarkerEvent.MARKER_UPDATED, this.onMarkerUpdated);
			this.flarManager.addEventListener(FLARMarkerEvent.MARKER_REMOVED, this.onMarkerRemoved);
			
			// framerate display helps to keep an eye on performance.
			var framerateDisplay:FramerateDisplay = new FramerateDisplay();
			this.addChild(framerateDisplay);
			
			// MarkerOutliner is a simple class that draws an outline
			// around the edge of detected markers.
			this.markerOutliner = new MarkerOutliner();
			this.addChild(this.markerOutliner);
			
			// turn off interactivity in markerOutliner
			this.markerOutliner.mouseChildren = false;
		}
		
		private function onFlarManagerError (evt:ErrorEvent) :void {
			this.flarManager.removeEventListener(ErrorEvent.ERROR, this.onFlarManagerError);
			
			trace(evt.text);
			// NOTE: developers can include better feedback to the end user here if desired.
		}
		
		private function onMarkerAdded (evt:FLARMarkerEvent) :void {
			//trace("["+evt.marker.patternId+"] added");
			this.markerOutliner.drawOutlines(evt.marker, 8, this.getColorByPatternId(evt.marker.patternId));
		}
		
		private function onMarkerUpdated (evt:FLARMarkerEvent) :void {
			//trace("["+evt.marker.patternId+"] updated");
			this.markerOutliner.drawOutlines(evt.marker, 1, this.getColorByPatternId(evt.marker.patternId));
		}
		
		private function onMarkerRemoved (evt:FLARMarkerEvent) :void {
			//trace("["+evt.marker.patternId+"] removed");
			this.markerOutliner.drawOutlines(evt.marker, 4, this.getColorByPatternId(evt.marker.patternId));
		}
		
		private function getColorByPatternId (patternId:int) :Number {
			switch (patternId) {
				case 0:
					return 0x47b200;
				case 1:
					return 0x990000;
				case 2:
					return 0xFF7F00;
				case 3:
					return 0xF2F2B2;
				default:
					return 0x666666;
			}
		}
	}
}