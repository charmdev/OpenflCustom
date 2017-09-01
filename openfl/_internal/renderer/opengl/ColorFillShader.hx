package openfl._internal.renderer.opengl;
import openfl.display.Shader;

/**
 * ...
 * @author Zaphod
 */
class ColorFillShader extends Shader
{

	@:glVertexSource(
		
		"attribute vec2 aPosition;
		
		uniform mat4 uMatrix;
		
		uniform vec4 uPositionRegion;
		
		void main(void) 
		{	
			vec2 position = uPositionRegion.xy + aPosition.xy * uPositionRegion.zw;
			gl_Position = uMatrix * vec4(position.x, position.y, 0.0, 1.0);
		}"
	)
	
	@:glFragmentSource( 
		
		"uniform float uAlpha;
		
		uniform vec3 uColor;
		
		void main()
		{
			gl_FragColor = vec4(uColor, uAlpha);
		}"
	)
	
	public function new() 
	{
		super();
		
		#if !macro
		data.uColor.value = [1.0, 1.0, 1.0];
		data.uPositionRegion.value = [0.0, 0.0, 1.0, 1.0];
		data.uAlpha.value = [1.0];
		#end
	}
	
}