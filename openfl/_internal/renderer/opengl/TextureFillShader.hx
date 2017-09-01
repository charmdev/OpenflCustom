package openfl._internal.renderer.opengl;

import openfl.display.Shader;

/**
 * ...
 * @author Zaphod
 */
class TextureFillShader extends Shader
{

	@:glVertexSource(
		
		"attribute vec2 aPosition;
		
		varying vec2 vTexCoord;
		
		uniform mat4 uMatrix;
		
		uniform vec4 uPositionRegion;
		uniform vec4 uTextureRegion;
		
		void main(void) {
			
			vTexCoord = uTextureRegion.xy + aPosition * uTextureRegion.zw;
			vec2 position = uPositionRegion.xy + aPosition * uPositionRegion.zw;
			gl_Position = uMatrix * vec4(position.x, position.y, 0.0, 1.0);
			
		}"
	)
	
	@:glFragmentSource( 
		
		"varying vec2 vTexCoord;
		
		uniform float uAlpha;
		
		uniform sampler2D uImage0;
		
		void main(void) {
			
			vec4 color = texture2D (uImage0, vTexCoord);
			
			if (color.a == 0.0) {
				
				gl_FragColor = vec4 (0.0, 0.0, 0.0, 0.0);
				
			} else {
				
				gl_FragColor = color * uAlpha;
				
			}
			
		}"
	)
	
	public function new() 
	{
		super();
		
		#if !macro
		data.uPositionRegion.value = [0.0, 0.0, 1.0, 1.0];
		data.uTextureRegion.value = [0.0, 0.0, 1.0, 1.0];
		data.uAlpha.value = [1.0];
		#end
	}
	
}