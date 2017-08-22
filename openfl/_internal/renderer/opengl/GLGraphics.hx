package openfl._internal.renderer.opengl;


import flash.geom.Point;
import lime.graphics.GLRenderContext;
import lime.graphics.opengl.GLBuffer;
import lime.utils.Float32Array;
import openfl._internal.renderer.cairo.CairoGraphics;
import openfl._internal.renderer.canvas.CanvasGraphics;
import openfl.display.Graphics;
import openfl.geom.Matrix;
import openfl.geom.Rectangle;

#if !openfl_debug
@:fileXml('tags="haxe,release"')
@:noDebug
#end

@:access(openfl.display.Graphics)


class GLGraphics {
	
	private static var inverseMatrix:Matrix = new Matrix();
	
	private static var graphicsRect:Rectangle = new Rectangle();
	private static var graphicsUV:Rectangle = new Rectangle();
	
	private static var graphicsBuffer:GLBuffer;
	private static var graphicsContext:GLRenderContext;
	private static var graphicsBufferData:Float32Array;
	
	private static var colorFillShader:ColorFillShader = new ColorFillShader();
	
	private static function isCompatible (graphics:Graphics, parentTransform:Matrix):Bool {
		
		#if !openfl_glgraphics
		return false;
		#end
		
		var data = new DrawCommandReader (graphics.__commands);
		var bitmap = null;
		
		for (type in graphics.__commands.types) {
			
			switch (type) {
				
				case BEGIN_BITMAP_FILL:
					
					var c = data.readBeginBitmapFill ();
					bitmap = c.bitmap;
					
				case BEGIN_FILL:
					
					data.skip (type);
				
				case END_FILL:
					
					bitmap = null;
					data.skip (type);
				
				case DRAW_RECT:
					
					/*
					if (bitmap != null) {
						
						var c = data.readDrawRect ();
						
						if (c.width != bitmap.width || c.height != bitmap.height) {
							
							data.destroy ();
							return false;
							
						}
						
					} else {
						
						data.skip (type);
						
					}
					*/
					data.skip (type);
				
				case MOVE_TO, END_FILL, DRAW_RECT:
					
					data.skip (type);
				
				default:
					
					data.destroy ();
					return false;
				
			}
			
		}
		
		return true;
		
	}
	
	
	public static function render (graphics:Graphics, renderSession:RenderSession, parentTransform:Matrix, worldAlpha:Float):Void {
		
		if (!graphics.__visible || graphics.__commands.length == 0)
		{
			return;
		}
		
		if (!isCompatible (graphics, parentTransform)) {
			
			#if (js && html5)
			CanvasGraphics.render (graphics, renderSession, parentTransform);
			#elseif lime_cairo
			CairoGraphics.render (graphics, renderSession, parentTransform);
			#end
			
		} else {
			
			graphics.__update ();
			
			var bounds = graphics.__bounds;
			
			var width = graphics.__width;
			var height = graphics.__height;
			
			if (bounds != null && width >= 1 && height >= 1) {
				
				var data = new DrawCommandReader (graphics.__commands);
				
				var renderer:GLRenderer = cast renderSession.renderer;
				var gl = renderSession.gl;
				
				// bitmap fill parameters
				var bitmap = null;
				var smooth = false;
				var matrix:Matrix = null;
				var repeat:Bool = false;
				
				// color fill parameters
				var color:Int = 0;
				var alpha:Float = 1.0;
				
				var positionX = 0.0;
				var positionY = 0.0;
				
				for (type in graphics.__commands.types) {
					
					switch (type) {
						
						case MOVE_TO:
							
							var c = data.readMoveTo ();
							positionX = c.x;
							positionY = c.y;
						
						case END_FILL:
							
							bitmap = null;
							matrix = null;
						
						case BEGIN_BITMAP_FILL:
							
							var c = data.readBeginBitmapFill ();
							bitmap = c.bitmap;
							smooth = c.smooth;
							matrix = c.matrix;
							repeat = c.repeat;
						
						case BEGIN_FILL:
							var c = data.readBeginFill ();
							color = c.color;
							alpha = c.alpha;
						
						case DRAW_RECT:
							
							if (bitmap != null && matrix != null && (matrix.b != 0 || matrix.c != 0))
							{
								data.skip (type);
							}
							else
							{
								var c = data.readDrawRect ();
								
								var x1:Float = c.x;
								var y1:Float = c.y;
								var x2:Float = x1 + c.width;
								var y2:Float = y1 + c.height;
								
								if (bitmap != null) 
								{
									// bitmap fill
									var u1:Float = x1;
									var v1:Float = y1;
									var u2:Float = x2;
									var v2:Float = y2;
									
									var bitmapWidth:Int = bitmap.width;
									var bitmapHeight:Int = bitmap.height;
									
									// TODO (Zaphod): move UV calculations to shader???
									
									if (matrix != null)
									{
										inverseMatrix.copyFrom(matrix);
										inverseMatrix.invert();
										
										u1 = inverseMatrix.__transformX(x1, y1);
										v1 = inverseMatrix.__transformY(x1, y1);
										
										u2 = inverseMatrix.__transformX(x2, y2);
										v2 = inverseMatrix.__transformY(x2, y2);
									}
									
									u1 /= bitmapWidth;
									v1 /= bitmapHeight;
									
									u2 /= bitmapWidth;
									v2 /= bitmapHeight;
									
									var skip:Bool = false;
									
									if (!repeat)
									{
										u1 = Math.max(Math.min(u1, 1.0), 0.0);
										v1 = Math.max(Math.min(v1, 1.0), 0.0);
										
										u2 = Math.max(Math.min(u2, 1.0), 0.0);
										v2 = Math.max(Math.min(v2, 1.0), 0.0);
										
										skip = (u2 <= u1 || v2 <= v1);
										
										if (!skip && matrix != null)
										{
											x1 = matrix.__transformX(u1 * bitmapWidth, v1 * bitmapHeight);
											y1 = matrix.__transformY(u1 * bitmapWidth, v1 * bitmapHeight);
											
											x2 = matrix.__transformX(u2 * bitmapWidth, v2 * bitmapHeight);
											y2 = matrix.__transformY(u2 * bitmapWidth, v2 * bitmapHeight);
										}
									}
									
									if (!skip)
									{
										var shader = renderSession.shaderManager.defaultShader;
										
										shader.data.uImage0.input = bitmap;
										shader.data.uImage0.smoothing = renderSession.allowSmoothing && (smooth || renderSession.upscaled);
										shader.data.uMatrix.value = renderer.getMatrix (parentTransform);
										
										renderSession.shaderManager.setShader (shader);
										
										if (repeat)
										{
											gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
											gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
										}
										else
										{
											gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
											gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
										}
										
										graphicsRect.setTo(x1, y1, x2, y2);
										
										// TODO (Zaphod): move this block of code to getBuffer() method...
										#if openfl_power_of_two
										var textureWidth:Int = 1;
										var textureHeight:Int = 1;
										
										while (textureWidth < bitmapWidth) 
										{
											textureWidth <<= 1;
										}
										
										while (textureHeight < bitmapHeight) 
										{
											textureHeight <<= 1;
										}
										
										var scaleX = (bitmapWidth / textureWidth);
										var scaleY = (bitmapHeight / textureHeight);
										
										u1 *= scaleX;
										u2 *= scaleX;
										v1 *= scaleY;
										v2 *= scaleY;
										#end
										// end of TODO...
										
										graphicsUV.setTo(u1, v1, u2, v2);
										
										var buffer = getBuffer(gl, worldAlpha, graphicsRect, graphicsUV);
										
										gl.bindBuffer (gl.ARRAY_BUFFER, buffer);
										gl.vertexAttribPointer (shader.data.aPosition.index, 3, gl.FLOAT, false, 6 * Float32Array.BYTES_PER_ELEMENT, 0);
										gl.vertexAttribPointer (shader.data.aTexCoord.index, 2, gl.FLOAT, false, 6 * Float32Array.BYTES_PER_ELEMENT, 3 * Float32Array.BYTES_PER_ELEMENT);
										gl.vertexAttribPointer (shader.data.aAlpha.index, 1, gl.FLOAT, false, 6 * Float32Array.BYTES_PER_ELEMENT, 5 * Float32Array.BYTES_PER_ELEMENT);
										
										gl.drawArrays (gl.TRIANGLE_STRIP, 0, 4);
									}
								}
								else
								{
									// color fill
									var shader = colorFillShader;
									
									shader.data.uMatrix.value = renderer.getMatrix (parentTransform);
									
									var uColor = shader.data.uColor.value;
									uColor[0] = ((color >> 16) & 0xff) / 255;
									uColor[1] = ((color >> 8) & 0xff) / 255;
									uColor[2] = (color & 0xff) / 255;
									
									renderSession.shaderManager.setShader (shader);
									
									gl.bindTexture (gl.TEXTURE_2D, null);
									
									if (gl.type == OPENGL) {
										
										gl.disable (gl.TEXTURE_2D);
										
									}
									
									graphicsRect.setTo(x1, y1, x2, y2);
									var buffer = getBuffer(gl, worldAlpha * alpha, graphicsRect, null);
									gl.bindBuffer (gl.ARRAY_BUFFER, buffer);
									gl.vertexAttribPointer (shader.data.aPosition.index, 3, gl.FLOAT, false, 6 * Float32Array.BYTES_PER_ELEMENT, 0);
									gl.vertexAttribPointer (shader.data.aAlpha.index, 1, gl.FLOAT, false, 6 * Float32Array.BYTES_PER_ELEMENT, 5 * Float32Array.BYTES_PER_ELEMENT);
									
									gl.drawArrays (gl.TRIANGLE_STRIP, 0, 4);
								}
							}
						
						
						default:
							
							data.skip (type);
						
					}
					
				}
				
			}
			
			graphics.__dirty = false;
			
		}
		
	}
	
	private static function getBuffer(gl:GLRenderContext, alpha:Float, graphicsRect:Rectangle, ?graphicsUV:Rectangle):GLBuffer {
		
		if (graphicsBuffer == null || graphicsContext != gl) {
			
			graphicsBufferData = new Float32Array (24);
			
			for (i in 0...24)
			{
				graphicsBufferData[i] = 0.0;
			}
			
			graphicsContext = gl;
			graphicsBuffer = gl.createBuffer ();
			
		}
		
		graphicsBufferData[0] = graphicsRect.width;
		graphicsBufferData[1] = graphicsRect.height;
		graphicsBufferData[5] = alpha;
		
		graphicsBufferData[6] = graphicsRect.x;
		graphicsBufferData[7] = graphicsRect.height;
		graphicsBufferData[11] = alpha;
		
		graphicsBufferData[12] = graphicsRect.width;
		graphicsBufferData[13] = graphicsRect.y;
		graphicsBufferData[17] = alpha;
		
		graphicsBufferData[18] = graphicsRect.x;
		graphicsBufferData[19] = graphicsRect.y;
		graphicsBufferData[23] = alpha;
		
		if (graphicsUV != null)
		{
			graphicsBufferData[3] = graphicsUV.width;
			graphicsBufferData[4] = graphicsUV.height;
			
			graphicsBufferData[9] = graphicsUV.x;
			graphicsBufferData[10] = graphicsUV.height;
			
			graphicsBufferData[15] = graphicsUV.width;
			graphicsBufferData[16] = graphicsUV.y;
			
			graphicsBufferData[21] = graphicsUV.x;
			graphicsBufferData[22] = graphicsUV.y;
		}
		
		gl.bindBuffer (gl.ARRAY_BUFFER, graphicsBuffer);
		gl.bufferData (gl.ARRAY_BUFFER, graphicsBufferData.byteLength, graphicsBufferData, gl.STATIC_DRAW);
		
		return graphicsBuffer;
		
	}
	
}