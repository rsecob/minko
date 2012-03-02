package aerys.minko.render
{
	import aerys.minko.ns.minko_scene;
	import aerys.minko.scene.node.Scene;
	import aerys.minko.type.Factory;
	import aerys.minko.type.Signal;
	
	import flash.display.BitmapData;
	import flash.display.Stage;
	import flash.display.Stage3D;
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.display3D.Context3D;
	import flash.events.Event;
	import flash.utils.getTimer;

	public final class Viewport
	{
		use namespace minko_scene;
		
		private var _stage3d			: Stage3D		= null;
		
		private var _width				: uint			= 0;
		private var _height				: uint			= 0;
		private var _autoResize			: Boolean		= false;
		private var _antiAliasing		: uint			= 0;
		private var _backgroundColor	: uint			= 0;
		private var _backBuffer			: RenderTarget	= null;
		private var _invalidBackBuffer	: Boolean		= false;
		
		private var _renderingTime		: int			= 0;
		
		private var _changed			: Signal		= new Signal();
		private var _enterFrame			: Signal		= new Signal();
		private var _exitFrame			: Signal		= new Signal();
		
		public function get visible() : Boolean
		{
			return _stage3d.visible;
		}
		public function set visible(v : Boolean) : void
		{
			_stage3d.visible = v;
		}
		
		public function get width() : uint
		{
			return _width;
		}
		public function set width(value : uint) : void
		{
			_width = value;
			_invalidBackBuffer = true;
			_changed.execute(this, "width");
		}
		
		public function get height() : uint
		{
			return _height;
		}
		public function set height(value : uint) : void
		{
			_height = value;
			_invalidBackBuffer = true;
			_changed.execute(this, "height");
		}
		
		public function get changed() : Signal
		{
			return _changed;
		}
		
		public function get renderingTime() : int
		{
			return _renderingTime;
		}
		
		public function get backgroundColor() : uint
		{
			return _backgroundColor;
		}
		public function set backgroundColor(value : uint) : void
		{
			_backgroundColor = value;
		}
		
		public function get antiAliasing() : uint
		{
			return _antiAliasing;
		}
		public function set antiAliasing(value : uint) : void
		{
			_antiAliasing = value;
			_invalidBackBuffer = true;
		}
		
		public function get enterFrame() : Signal
		{
			return _enterFrame;
		}
		
		public function get exitFrame() : Signal
		{
			return _exitFrame;
		}
		
		public function get driverInfo() : String
		{
			return _stage3d && _stage3d.context3D
				? _stage3d.context3D.driverInfo
				: null;
		}
		
		public function Viewport(stage	 		: Stage,
								 antiAliasing	: uint	= 0,
								 width			: uint 	= 0,
								 height			: uint	= 0)
		{
			_antiAliasing = antiAliasing;
			
			initialize(stage, width, height);
		}
		
		private function initialize(stage 	: Stage,
									width	: uint,
									height	: uint) : void
		{
			stage.scaleMode = StageScaleMode.NO_SCALE;
			stage.align = StageAlign.TOP_LEFT;
			
			_autoResize = width == 0 && height == 0;
			if (_autoResize)
			{
				stage.addEventListener(Event.RESIZE, stageResizedHandler);
				
				width = stage.stageWidth;
				height = stage.stageHeight;
			}
			
			_width = width;
			_height = height;
			
			_stage3d = stage.stage3Ds[0];
			_stage3d.addEventListener(Event.CONTEXT3D_CREATE, context3dCreatedHandler);
			_stage3d.requestContext3D();
		}
		
		private function stageResizedHandler(event : Event) : void
		{
			var stage : Stage = event.target as Stage;
			
			width = stage.stageWidth;
			height = stage.stageHeight;
		}
		
		private function context3dCreatedHandler(event : Event) : void
		{
			_invalidBackBuffer = true;
		}
		
		private function updateBackBuffer() : void
		{
			_invalidBackBuffer = false;
			_stage3d.context3D.configureBackBuffer(
				_width,
				_height,
				_antiAliasing,
				true
			);
			_backBuffer = new RenderTarget(
				_width,
				_height,
				null,
				0,
				_backgroundColor
			);
		}
		
		public function render(scene : Scene, destination : BitmapData = null) : void
		{
			_enterFrame.execute(this, scene);
			
			scene.update();
			
			var context : Context3D 	= _stage3d.context3D;
			var list	: RenderingList	= scene.renderingList;
			
			_renderingTime = 0;
			
			if (context)
			{
				var time : int = getTimer();
				
				if (_invalidBackBuffer)
					updateBackBuffer();
				
				if (list.render(context, _backBuffer) == 0)
				{
					var color : uint = _backBuffer.backgroundColor;
					
					context.clear(
						((color >> 16) & 0xff) / 255.,
						((color >> 8) & 0xff) / 255.,
						(color & 0xff) / 255.,
						((color >> 24) & 0xff) / 255.
					);
				}
				
				if (destination)
					context.drawToBitmapData(destination);
				else
					context.present();
				
				_renderingTime = getTimer() - time;
			}
			
			Factory.sweep();
			
			_exitFrame.execute(this, scene);
		}
	}
}