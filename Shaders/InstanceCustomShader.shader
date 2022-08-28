Shader "Instanced/InstanceCustomShader" {
    Properties{
        _MainTex("Albedo (RGB)", 2D) = "white" {}
    }
        SubShader{

            Pass {

                Tags {"LightMode" = "ForwardBase"}

                CGPROGRAM

                #pragma vertex vert
                #pragma fragment frag
                #pragma multi_compile_fwdbase nolightmap nodirlightmap nodynlightmap novertexlight
                #pragma target 4.5


                #include "UnityCG.cginc"
                #include "UnityLightingCommon.cginc"
                #include "AutoLight.cginc"

                sampler2D _MainTex;
                struct transform
                {
                    float4 rotation;
                    float3 position;
                    float3 scale;
                    float pushDistance;
                };

                float PseudoRandomNumber(float i, float j)
                {
                    float u = 50. * frac(i / radians(180.));
                    float v = 50. * frac(j / radians(180.));
                    return 2. * frac(u * v * (u + v)) - 1.;
                }

                float4 GetCornerValues(float i, float j)
                {
                    float a = PseudoRandomNumber(i, j);
                    float b = PseudoRandomNumber(i + 1., j);
                    float c = PseudoRandomNumber(i, j + 1.);
                    float d = PseudoRandomNumber(i + 1., j + 1.);
                    return float4(a, b, c, d);
                }

                //substitute function for smoothstep for our noise
                float S(float l)
                {
                    return 3. * pow(l, 2.) - 2. * pow(l, 3.);
                }

                float GetNoise(float x, float z, float scale)
                {
                    //we are dividing the place up into a grid based on scale
                    x *= scale;
                    z *= scale;
                    float i = floor(x);
                    float j = floor(z);
                    float4 cornerValues = GetCornerValues(i, j);
                    return cornerValues.x +
                        (cornerValues.y - cornerValues.x) * S(x - i) +
                        (cornerValues.z - cornerValues.x) * S(z - j) +
                        (cornerValues.x - cornerValues.y - cornerValues.z + cornerValues.w) * S(x - i) * S(z - j);


                }


            #if SHADER_TARGET >= 45
                StructuredBuffer<transform> positionBuffer;
            #endif
                

                struct v2f
                {
                    float4 pos : SV_POSITION;
                    float2 uv_MainTex : TEXCOORD0;
                    float3 ambient : TEXCOORD1;
                    float3 diffuse : TEXCOORD2;
                    float3 color : TEXCOORD3;
                    SHADOW_COORDS(4)
                };
                

                v2f vert(appdata_full v, uint instanceID : SV_InstanceID)
                {
                #if SHADER_TARGET >= 45
                    transform data = positionBuffer[instanceID];
                #else
                    transform data = 0;
                #endif
                    //put our instanceID into a nice range to use
                    float instanceRand = (instanceID + 500) / 10000;
                    float3 localPosition = v.vertex.xyz;
                    
                    
                    float4x4 localTransform = 0;
                    localTransform._14_24_34_44 = float4(0,0,0, 1);
                    //apply rotation
                    float4x4 rotationMatrix = 0;


                    rotationMatrix._11_21_31_41 = float4(
                        2 * (data.rotation.x * data.rotation.x + data.rotation.y * data.rotation.y) - 1,
                        2 * (data.rotation.y * data.rotation.z - data.rotation.x * data.rotation.w),
                        2 * (data.rotation.y * data.rotation.w + data.rotation.x * data.rotation.z),
                        0);
                    rotationMatrix._12_22_32_42 = float4(
                        2 * (data.rotation.y * data.rotation.z + data.rotation.x * data.rotation.w),
                        2 * (data.rotation.x * data.rotation.x + data.rotation.z * data.rotation.z) - 1,
                        2 * (data.rotation.z * data.rotation.w - data.rotation.x * data.rotation.y),
                        0);
                    rotationMatrix._13_23_33_43 = float4(
                        2 * (data.rotation.y * data.rotation.w - data.rotation.x * data.rotation.z),
                        2 * (data.rotation.z * data.rotation.w + data.rotation.x * data.rotation.y),
                        2 * (data.rotation.x * data.rotation.x + data.rotation.w * data.rotation.w) - 1,
                        0);
                    rotationMatrix._14_24_34_44 = float4(0, 0, 0, 1);
                    //apply scale to matrix
                    localTransform._11_21_31_41 = float4(data.scale.x, 0, 0, 0);
                    localTransform._12_22_32_42 = float4(0, data.scale.y, 0, 0);
                    localTransform._13_23_33_43 = float4(0, 0, data.scale.z, 0);
                    //apply scale and rotation to our vertex position
                    localTransform = mul(localTransform, rotationMatrix);

                    localPosition = -mul(localPosition, localTransform);
                    float magnitude = length(localPosition);
                    //if the grass is pushed it needs to be lower
                    if (data.pushDistance < 0)
                    {
                        //generate random push direction
                        float2 pushDirection = normalize(float2(PseudoRandomNumber(data.position.x, data.position.z), PseudoRandomNumber(data.position.x * 2, data.position.z * 2)));
                        //multiply by a push magnitude and the distance
                        pushDirection *= 5 * data.pushDistance;
                        localPosition += float3(clamp(v.vertex.y, 0, 10) * (GetNoise(_Time.w + data.position.x + 7657, _Time.w + data.position.z + 7657, 0.1) - pushDirection.x), 0, clamp(v.vertex.y, 0, 10) * (GetNoise(_Time.w + data.position.x + 123, _Time.w + data.position.z + 123, 0.1) - pushDirection.y));

                    }
                    else
                    {
                        localPosition += float3(clamp(v.vertex.y, 0, 10) * GetNoise(_Time.w + data.position.x + 7657, _Time.w + data.position.z + 7657, 0.1), 0, clamp(v.vertex.y, 0, 10) * GetNoise(_Time.w + data.position.x + 123, _Time.w + data.position.z + 123, 0.1));
                    }
                    //make sure our sway doesn't extend the blade of grass
                    localPosition = normalize(localPosition) * magnitude;
                    float3 worldPosition = data.position.xyz + localPosition;
                    float3 worldNormal = v.normal;


                    //make the grass shaded, the translucency value is multiplied by the diffuse value of the opposite surface normal
                    float translucency = 0.8;
                    float3 ndotl = max(saturate(dot(worldNormal, _WorldSpaceLightPos0.xyz)), saturate(dot(-worldNormal, _WorldSpaceLightPos0.xyz)) * translucency);
                    float3 ambient = ShadeSH9(float4(worldNormal, 1.0f));
                    float3 diffuse = (ndotl * _LightColor0.rgb);
                    float3 color = v.color;

                    v2f o;
                    o.pos = mul(UNITY_MATRIX_VP, float4(worldPosition, 1.0f));
                    o.uv_MainTex = v.texcoord;
                    o.ambient = ambient;
                    o.diffuse = diffuse;
                    

                    float colourMultiplier = clamp(v.vertex.y+2, 2, 6)/6;


                    o.color = color * colourMultiplier;
                    //TRANSFER_SHADOW(o)
                    return o;
                }

                fixed4 frag(v2f i) : SV_Target
                {
                    fixed shadow = SHADOW_ATTENUATION(i);
                    fixed4 albedo = tex2D(_MainTex, i.uv_MainTex);
                    float3 lighting = i.diffuse * shadow + i.ambient ;
                    fixed4 output = fixed4(albedo.rgb * i.color * lighting, albedo.w);
                    UNITY_APPLY_FOG(i.fogCoord, output);
                    return output;
                }

                ENDCG
            }
    }
}