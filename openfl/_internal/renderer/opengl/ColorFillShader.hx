package openfl._internal.renderer.opengl;
import openfl.display.Shader;

/**
 * ...
 * @author Zaphod
 */
class ColorFillShader extends Shader
{

	@:glVertexSource(
		
		"attribute float aAlpha;
		attribute vec4 aPosition;
		
		varying float vAlpha;
		
		uniform mat4 uMatrix;
		
		void main(void) 
		{	
			vAlpha = aAlpha;
			gl_Position = uMatrix * aPosition;
		}"
	)
	
	@:glFragmentSource( 
		
		"varying float vAlpha;
		
		uniform vec3 uColor;
		
		void main()
		{
			gl_FragColor = vec4(uColor, vAlpha);
		}"
	)
	
	public function new() 
	{
		super();
		
		#if !macro
		data.uColor.value = [1.0, 1.0, 1.0];
		#end
	}
	
}