//
/**
 * Copyright (c) 2019 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
 * distribute, sublicense, create a derivative work, and/or sell copies of the
 * Software in any work that is designed, intended, or marketed for pedagogical or
 * instructional purposes related to programming, coding, application development,
 * or information technology.  Permission for such use, copying, modification,
 * merger, publication, distribution, sublicensing, creation of derivative works,
 * or sale is expressly withheld.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */


#include <metal_stdlib>
using namespace metal;
#import "Common.h"

struct VertexIn {
  float4 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
};

/*
struct VertexOut {
    float4 position [[position]];
    /*
     The last two properties, worldPosition and worldNormal,
     will hold the vertex position and normal in world space.
     
    float3 worldPosition;
    float3 worldNormal;
};
*/
struct VertexOut {
  float4 position [[position]];
  float3 worldPosition;
  float3 worldNormal;
};

/*
vertex float4 vertex_main(const VertexIn vertexIn [[stage_in]],
                          constant Uniforms &uniforms [[buffer(1)]])
{
  float4 position = uniforms.projectionMatrix * uniforms.viewMatrix
  * uniforms.modelMatrix * vertexIn.position;
  return position;
}
 */
vertex VertexOut vertex_main(const VertexIn vertexIn [[stage_in]],
                             constant Uniforms &uniforms [[buffer(1)]]){
    VertexOut out {
        .position = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix * vertexIn.position,
        //.normal = vertexIn.normal,
        .worldPosition = (uniforms.modelMatrix * vertexIn.position).xyz,
        .worldNormal = uniforms.normalMatrix * vertexIn.normal
    };
    return out;
}

/*
fragment float4 fragment_main() {
  return float4(0, 0, 1, 1);
}
 */

/*
fragment float4 fragment_main(VertexOut in [[stage_in]]) {
    return float4(in.normal, 1);
}
 */

/*
fragment float4 fragment_main(VertexOut in [[stage_in]]) {
    float4 sky = float4(0.34, 0.9, 1.0, 1.0);
    float4 earth = float4(0.29, 0.58, 0.2, 1.0);
    float intensity = in.normal.y * 0.5 + 0.5;
    /*
     The function mix interpolates between the first two values depending
     on the third value which needs to be between 0 and 1.
     Your normal values are between -1 and 1, so you convert the intensity to be between 0 and 1.
     
    return mix(earth, sky, intensity);
}
*/

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              /*
                               You accept the lights into constant space.
                               You also make the base color of the train blue again
                               */
                              constant Light * lights [[buffer(2)]],
                              constant FragmentUniforms &fragmentUniforms [[buffer(3)]]) {
    float3 baseColor = float3(1, 1, 1);
    float3 diffuseColor = 0;
    float3 ambientColor = 0;
    float3 specularColor = 0;
    float materialShininess = 32;
    float3 materialSpecularColor = float3(1, 1, 1);
    /*
     You get the light’s direction vector from the light’s position and
     turn the direction vectors into unit vectors so that both the normal and
     light vectors have a length of 1
     */
    float3 normalDirection = normalize(in.worldNormal);
    for (uint i = 0; i < fragmentUniforms.lightCount; i++) {
        Light light = lights[i];
        if(light.type == Sunlight) {
            float3 lightDirction = normalize(-light.position);
            /*
             You get the dot product of the two vectors.
             When the fragment fully points toward the light, the dot product will be -1.
             It’s easier for further calculation to make this value positive,
             so you negate the dot product.
             saturate() makes sure the value is between 0 and 1
             by clamping the negative numbers.
             This gives you the slope of the surface,
             and therefore the intensity of the diffuse factor.
             */
            float diffuseIntensity = saturate(-dot(lightDirction, normalDirection));
            // Multiply the blue color by the diffuse intensity to get the diffuse shading
            diffuseColor += light.color * baseColor * diffuseIntensity;
            
            if (diffuseIntensity > 0) {
                /*
                 (R)
                 Looking at the image above, for the calculation, you’ll need (L)ight,
                 (R)eflection, (N)ormal and (V)iew. You already have (L) and (N),
                 so here you use the Metal Shading Language function reflect() to get (R)
                 */
                float3 reflection = reflect(lightDirction, normalDirection);
                /*
                 (V)
                 You need the view vector between the fragment and the camera for (V).
                 */
                float3 cameraDirection = normalize(in.worldPosition - fragmentUniforms.cameraPosition);
                /*
                 Now you calculate the specular intensity.
                 You find the angle between the reflection and the view using the dot product,
                 clamp the result between 0 and 1 using saturate(),
                 and raise the result to a shininess power using pow().
                 You then use this intensity to work out the specular color for the fragment.
                 */
                float specularIntensity = pow(saturate(-dot(reflection, cameraDirection)),
                                              materialShininess);
                specularColor += light.specularColor * materialSpecularColor * specularIntensity;
            }
            
        } else if(light.type == Ambientlight) {
            ambientColor += light.color * light.intensity;
        } else if(light.type == Pointlight) {
            /*
             You find out the distance between the light and the fragment position
             */
            float d = distance(light.position, in.worldPosition);
            /*
             With the directional sun light, you used the position as a direction.
             Here, you calculate the direction from the fragment position to the light position.
             */
            float3 lightDirection = normalize(in.worldPosition - light.position);
            /*
             Calculate the attenuation using the attenuation formula and the distance
             to see how bright the fragment will be
             */
            float attenuation = 1.0 / (light.attenuation.x + light.attenuation.y * d
                                       + light.attenuation.z * d * d);
            
            float diffuseIntensity = saturate(-dot(lightDirection, normalDirection));
            float3 color = light.color * baseColor * diffuseIntensity;
            /*
             After calculating the diffuse color as you did for the sun light,
             multiply this color by the attenuation
             */
            color *= attenuation;
            diffuseColor += color;
        } else if(light.type == Spotlight) {
            /*
             Calculate the distance and direction as you did for the point light.
             This ray of light may be outside of the spot cone
             */
            float d = distance(light.position, in.worldPosition);
            float3 lightDirection = normalize(in.worldPosition - light.position);
            /*
             Calculate the cosine angle (that’s the dot product)
             between that ray direction and the direction the spot light is pointing.
             */
            float3 coneDirection = normalize(light.coneDirection);
            float spotResult = dot(lightDirection, coneDirection);
            /*
             If that result is outside of the cone angle, then ignore the ray.
             Otherwise, calculate the attenuation as for the point light.
             Vectors pointing in the same direction have a dot product of 1.0
             */
            if (spotResult > cos(light.coneAngle)) {
                float attenuation = 1.0 / (light.attenuation.x +
                    light.attenuation.y * d + light.attenuation.z * d * d);
                /*
                 Calculate the attenuation at the edge of the spot light using
                 coneAttenuation as the power
                 */
                attenuation *= pow(spotResult, light.coneAttenuation);
                float diffuseIntensity =
                         saturate(dot(-lightDirection, normalDirection));
                float3 color = light.color * baseColor * diffuseIntensity;
                color *= attenuation;
                diffuseColor += color;
              }
            
            
        }
    }
    /*
     Set the final color to the diffuse color.
     Shortly this value will include ambient, specular and other lights too
     */
    float3 color = diffuseColor + ambientColor + specularColor;
    return float4(color, 1);

}


