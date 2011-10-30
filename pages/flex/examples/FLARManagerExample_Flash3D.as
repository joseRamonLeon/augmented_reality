package examples {
	import com.transmote.flar.FLARManager;
	import com.transmote.flar.marker.FLARMarkerEvent;
	import com.transmote.utils.time.FramerateDisplay;
	
	import examples.support.MarkerOutliner3D;
	
	import flash.display.Sprite;
	import flash.events.ErrorEvent;
	import flash.events.Event;
	
	/**
	 * FLARManagerExample_Flash3D draws outlines around detected markers,
	 * using Flash Player 10's 3D capabilities.
	 * 
	 * @author	Eric Socolofsky
	 * @url		http://transmote.com/flar
	 */
	public class FLARManagerExample_Flash3D extends Sprite {
		private var flarManager:FLARManager;
		private var markerOutliner3D:MarkerOutliner3D;
		
		private var bMouseIsDown:Boolean = false;
		
		
		public function FLARManagerExample_Flash3D () {
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
			
			this.flarManager.addEventListener(Event.INIT, this.onFlarManagerInited);
		}
		
		private function onFlarManagerError (evt:ErrorEvent) :void {
			this.flarManager.removeEventListener(ErrorEvent.ERROR, this.onFlarManagerError);
			this.flarManager.removeEventListener(Event.INIT, this.onFlarManagerInited);
			
			trace(evt.text);
			// NOTE: developers can include better feedback to the end user here if desired.
		}
		
		private function onFlarManagerInited (evt:Event) :void {
			// MarkerOutliner3D is a simple class that draws an outline
			// around the edge of detected markers, using Flash Player 10's 3D capabilities,
			// along with FLARToolkit's transformation matrices.
			this.markerOutliner3D = new MarkerOutliner3D();
			this.markerOutliner3D.x = 0.5 * this.stage.stageWidth;
			this.markerOutliner3D.y = 0.5 * this.stage.stageHeight;
			
			if (this.flarManager.mirrorDisplay) {
				// flip display if source is mirrored;
				// this is temporary until FLARManager has full support for mirroring.
				this.markerOutliner3D.scaleX *= -1;
			}
			
			this.addChild(this.markerOutliner3D);
		}
		
		private function onMarkerAdded (evt:FLARMarkerEvent) :void {
			//trace("["+evt.marker.patternId+"] added");
			this.markerOutliner3D.addMarker(evt.marker);
		}
		
		private function onMarkerUpdated (evt:FLARMarkerEvent) :void {
			//trace("["+evt.marker.patternId+"] updated");
		}
		
		private function onMarkerRemoved (evt:FLARMarkerEvent) :void {
			//trace("["+evt.marker.patternId+"] removed");
			this.markerOutliner3D.removeMarker(evt.marker);
		}
	}
}