package com.linuxclicks.blazeds.ui.main
{
	import com.transmote.flar.FLARManager;
	import com.transmote.flar.marker.FLARMarker;
	import com.transmote.flar.marker.FLARMarkerEvent;
	import com.transmote.flar.utils.FLARPVGeomUtils;
	
	import flash.display.Sprite;
	import flash.events.Event;
	import com.transmote.flar.FLARManager;
	import com.transmote.flar.marker.FLARMarkerEvent;
	import com.transmote.utils.time.FramerateDisplay;
	import com.transmote.flar.FLARManager;
	import com.transmote.flar.marker.FLARMarkerEvent;
	import com.transmote.utils.time.FramerateDisplay;
	
	import examples.support.SimpleCubes_PV3D;
	
	import flash.display.Sprite;
	import flash.events.ErrorEvent;
	import flash.events.Event;	
	import examples.support.MarkerOutliner;
	import org.papervision3d.objects.parsers.KMZ;
	
	import flash.display.Sprite;
	import flash.events.ErrorEvent;
	import org.libspark.flartoolkit.pv3d.FLARCamera3D;
	import org.papervision3d.lights.PointLight3D;
	import org.papervision3d.objects.DisplayObject3D;
	import org.papervision3d.objects.parsers.DAE;
	import org.papervision3d.render.LazyRenderEngine;
	import org.papervision3d.scenes.Scene3D;
	import org.papervision3d.view.Viewport3D;
	
	import org.osflash.thunderbolt.Logger;

/*
			this.flarManager = new FLARManager("../flex/flar/resources/flar/flarConfig.xml");
			*/
	public class Main extends Sprite {
		private var flarManager:FLARManager;
		
		private var scene3D:Scene3D;
		private var camera3D:FLARCamera3D;
		private var viewport3D:Viewport3D;
		private var renderEngine:LazyRenderEngine;
		private var pointLight3D:PointLight3D;
		
		private var activeMarker:FLARMarker;
		private var modelContainer:DisplayObject3D;
		
		public function Main () {
			// pass the path to the FLARManager xml config file into the FLARManager constructor.
			// FLARManager creates and uses a FLARCameraSource by default.
			// the image from the first detected camera will be used for marker detection.
			this.flarManager = new FLARManager();
						
			// pass the path to the FLARManager config file into FLARManager.initFromFile.
			this.flarManager.initFromFile("../flex/flar/resources/flar/flarConfig.xml");
			
			// add FLARManager.flarSource to the display list to display the video capture.
			this.addChild(Sprite(this.flarManager.flarSource));
			
			// begin listening for FLARMarkerEvents.
			this.flarManager.addEventListener(FLARMarkerEvent.MARKER_ADDED, this.onMarkerAdded);
			this.flarManager.addEventListener(FLARMarkerEvent.MARKER_REMOVED, this.onMarkerRemoved);
			
			// wait for FLARManager to initialize before setting up Papervision3D environment.
			this.flarManager.addEventListener(Event.INIT, this.onFlarManagerInited);
		}
		
		private function onFlarManagerInited (evt:Event) :void {
			this.flarManager.removeEventListener(Event.INIT, this.onFlarManagerInited);
			
			this.scene3D = new Scene3D();
			
			// initialize FLARCamera3D with parsed camera parameters.
			this.camera3D = new FLARCamera3D(this.flarManager.cameraParams);
			
			this.viewport3D = new Viewport3D(this.stage.stageWidth, this.stage.stageHeight);
			this.addChild(this.viewport3D);
			
			// flip display to match mirrored source;
			// this is temporary until FLARManager has full support for mirroring.
			this.viewport3D.x = this.stage.stageWidth;
			this.viewport3D.scaleX = -1;
			
			this.renderEngine = new LazyRenderEngine(this.scene3D, this.camera3D, this.viewport3D);
			
			this.pointLight3D = new PointLight3D();
			this.pointLight3D.x = 1000;
			this.pointLight3D.y = 1000;
			this.pointLight3D.z = -1000;
			
			// load the model.
			// (this model has to be scaled and rotated to fit the marker; every model is different.)
			var model:KMZ = new KMZ();
			model.load("../flex/flar/resources/googleSketchUp3D/PineTree.kmz");
			model.rotationX = 0;
			model.rotationY = 90;
			model.rotationZ = 0;
			model.scale = 1.0;
			
			// create a container for the model, that will accept matrix transformations.
			this.modelContainer = new DisplayObject3D();
			this.modelContainer.addChild(model);
			this.modelContainer.visible = false;
			this.scene3D.addChild(this.modelContainer);
			
			this.addEventListener(Event.ENTER_FRAME, this.onEnterFrame);
		}
		
		private function onMarkerAdded (evt:FLARMarkerEvent) :void {
			trace("["+evt.marker.patternId+"] added");
			this.modelContainer.visible = true;
			this.activeMarker = evt.marker;
		}
		
		private function onMarkerRemoved (evt:FLARMarkerEvent) :void {
			trace("["+evt.marker.patternId+"] removed");
			this.modelContainer.visible = false;
			this.activeMarker = null;
		}
		
		private function onEnterFrame (evt:Event) :void {
			// apply the FLARToolkit transformation matrix to the Cube.
			if (this.activeMarker) {
				this.modelContainer.transform = FLARPVGeomUtils.convertFLARMatrixToPVMatrix(this.activeMarker.transformMatrix);
			}
			
			// update the Papervision3D view.
			this.renderEngine.render();
		}
	}
}