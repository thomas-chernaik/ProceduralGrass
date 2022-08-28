Shader "Instanced/InstancedSurfaceShader" {
    Properties{
        _MainTex("Albedo (RGB)", 2D) = "white" {}
        _Glossiness("Smoothness", Range(0,1)) = 0.5
        _Metallic("Metallic", Range(0,1)) = 0.0
    }
        

        SubShader{
            Tags { "RenderType" = "Opaque" }
            LOD 200

            CGPROGRAM
            // Physically based Standard lighting model
            #pragma surface surf Standard
            #pragma multi_compile_instancing
            #pragma instancing_options procedural:setup

            sampler2D _MainTex;
            struct transform
            {
                float4 rotation;
                float3 position;
                float3 scale;
            };

            struct Input {
                float2 uv_MainTex;
            };

        #ifdef UNITY_PROCEDURAL_INSTANCING_ENABLED
            StructuredBuffer<transform> positionBuffer;
        #endif

            void setup()
            {
            #ifdef UNITY_PROCEDURAL_INSTANCING_ENABLED
               // float4 data = positionBuffer[unity_InstanceID];
                
                transform data = positionBuffer[unity_InstanceID];


                //wavey
                //data.position.y += 10*sin(_Time.w+atan2(data.position.z, data.position.x));

                //apply posotion
                unity_ObjectToWorld._14_24_34_44 = float4(data.position, 1);
                //so I dont have to type so much
                float4 rot = data.rotation;
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
                    
                //apply scale
                unity_ObjectToWorld._11_21_31_41 = float4(data.scale.x, 0, 0, 0);
                unity_ObjectToWorld._12_22_32_42 = float4(0, data.scale.y, 0, 0);
                unity_ObjectToWorld._13_23_33_43 = float4(0, 0, data.scale.z, 0);
                unity_ObjectToWorld = mul(unity_ObjectToWorld, rotationMatrix);
                //unity_ObjectToWorld._11_21_31_41 = float4(data.w, 0, 0, 0);
                //unity_ObjectToWorld._12_22_32_42 = float4(0, data.w, 0, 0);
                //unity_ObjectToWorld._13_23_33_43 = float4(0, 0, data.w, 0);
                //unity_ObjectToWorld._14_24_34_44 = float4(data.xyz, 1);
                unity_WorldToObject = unity_ObjectToWorld;
                unity_WorldToObject._14_24_34 *= -1;
                unity_WorldToObject._11_22_33 = 1.0f / unity_WorldToObject._11_22_33;
            #endif
            }

            half _Glossiness;
            half _Metallic;

            void surf(Input IN, inout SurfaceOutputStandard o) {
                fixed4 c = tex2D(_MainTex, IN.uv_MainTex);
                o.Albedo = c.rgb;
                o.Metallic = _Metallic;
                o.Smoothness = _Glossiness;
                o.Alpha = c.a;
            }
            ENDCG
        }
            FallBack "Diffuse"
}



