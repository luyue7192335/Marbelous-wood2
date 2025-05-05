
Shader "Unlit/Moving"

{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _LerpFactor ("Lerp Factor", Range(0, 1)) = 0.0 // 用于过渡的控制参数
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            #define MAX_OPS 100

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _LerpFactor;

            // C# 传递的数据
            int _OpCount;
            float4 _AllOpData[MAX_OPS];
            float _AllScales[MAX_OPS];
            fixed4 _AllColors[MAX_OPS];
            int _OpTypes[MAX_OPS];

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            

            fixed4 frag (v2f i) : SV_Target
            {
                float2 displacedUV = i.uv;

                if(_OpCount > 0)
                {
                    int lastOpIndex = _OpCount - 1;
                    if(_OpTypes[lastOpIndex] == 0) // DROP操作
                    {
                        float2 dropPos = _AllOpData[lastOpIndex].xy;
                        float baseRadius = _AllOpData[lastOpIndex].z;
                        
                        // 动态半径计算（带时间插值）
                        float dynamicRadius = lerp(0.0, baseRadius, _LerpFactor);
                        float2 delta = displacedUV - dropPos;
                        float dist = length(delta);
                        
                        if(dist <= dynamicRadius)
                        {
                            // 进入动态区域时返回颜色
                            return _AllColors[lastOpIndex]; 
                        }
                        else
                        {
                            // 动态位移计算
                            float l2 = sqrt(max(dot(delta, delta) - dynamicRadius*dynamicRadius, 0));
                            displacedUV = dropPos + (delta / dist) * l2;
                        }
                    }
                    else if(_OpTypes[lastOpIndex] == 1) // DRAG操作
                    {
                        #define LAMBDA 0.02
                        #define FALLOFF 1.0
                        float _DragIntensity = 0.7;
                        #define EDGE_SMOOTHNESS 0.3 // [0.1-0.5] 边缘柔化系数

                        
                        float2 start = _AllOpData[lastOpIndex].xy;
                        float2 end = _AllOpData[lastOpIndex].zw;
                        float baseScale = _AllScales[lastOpIndex];
                        
                        // 动态缩放系数
                        float dynamicScale = lerp(0.0, baseScale, _LerpFactor);
                        
                        // 基于动态缩放重新计算位移
                        float2 dragVec = end - start;
                        float alpha = length(dragVec);
                        if(alpha < 0.01) return tex2D(_MainTex, displacedUV);
                        
                        float beta = dynamicScale * 0.5;
                        float2 m = dragVec / alpha;
                        float2 n = float2(-m.y, m.x);
                        
                        float2 toStart = displacedUV - start;
                        float l1 = dot(toStart, n);
                         float l2_raw = 1.0 - smoothstep(0.0, beta, abs(l1));

                        // 纺锤形改造 ▼
                        float t = dot(toStart, m) / alpha; // 新增轴向位置参数
                        float radial_atten = exp(-4.0 * t * t); // 新增径向衰减
                        //float radial_atten = (t < 0.0) ? -exp(-4.0 * t * t) : exp(-4.0 * t * t);
                        
                     
                        // float l2 = saturate(l2_raw);
                         float l2 = saturate(l2_raw * radial_atten);
                         float denominator = max(beta * 0.5 + 0.02, 0.01);
                        // float l3 = (alpha * 0.02) / denominator;
                        float l3 = (alpha * 0.02 * (1.0 + 2.0 * radial_atten)) / denominator; // 动态调节长度系数
                        
                        float attenuation = pow(l2, 1.0);

                        
                         
                        // 动态位移强度
                        float dynamicIntensity = lerp(0.0, 0.7, _LerpFactor);
                        displacedUV -= m * l3 * attenuation * dynamicIntensity;
                    }
                }

                // 统一逆向处理所有操作（`_OpCount - 2` 方式）
                for(int j = _OpCount - 2; j >= 0; --j)
                {
                    if(_OpTypes[j] == 0) // DROP 操作
                    {
                        float2 dropPos = _AllOpData[j].xy;
                        float radius = _AllOpData[j].z;
                        fixed4 dropColor = _AllColors[j];

                        float2 delta = displacedUV - dropPos;
                        float dist = length(delta);
                        float radiusSqr = radius * radius;

                        if(dist > radius)
                        {
                            float l2 = sqrt(dot(delta, delta) - radiusSqr);
                            displacedUV = dropPos + (delta / dist) * l2;
                        }
                        else
                        {
                            return dropColor;
                        }
                    }
                    else if(_OpTypes[j] == 1) // DRAG 操作
                    {
                        #define LAMBDA 0.02  
                        #define FALLOFF 1.0   
                        float ALPHA = 0.4;
                        float _DragIntensity = 0.7;
                        #define EDGE_SMOOTHNESS 0.3 // [0.1-0.5] 边缘柔化系数

                        float2 start = _AllOpData[j].xy;
                        float2 end = _AllOpData[j].zw;
                        float scale = _AllScales[j];

                        float2 dragVec = end - start;
                        float alpha = length(dragVec);
                        if(alpha < 0.01) continue;
                        float beta = scale * 0.5;
                        if(scale < 0.01) continue;

                        float2 m = dragVec / alpha;
                        float2 n = float2(-m.y, m.x);

                        float2 toStart = displacedUV - start;
                        float l1 = dot(toStart, n);

                        // float l2_raw = 1.0 - smoothstep(0.0, beta, abs(l1));
                        // float l2 = saturate(l2_raw);
                        // float denominator = max(beta * 0.5 + 0.02, 0.01);
                        // float l3 = (alpha * LAMBDA) / denominator;
                        // float attenuation = pow(l2, FALLOFF);

                       float l2_raw = 1.0 - smoothstep(0.0, beta, abs(l1));
    
                        // 纺锤形改造 ▼
                        float t = dot(toStart, m) / alpha; // 新增轴向位置参数
                        float radial_atten = exp(-4.0 * t * t); // 新增径向衰减
                        //float radial_atten = (t < 0.0) ? -exp(-4.0 * t * t) : exp(-4.0 * t * t);
         


                        // 合成衰减场
                        float l2 = saturate(l2_raw * radial_atten);
                        float denominator = max(beta * 0.5 + LAMBDA, 0.01);
                        float l3 = (alpha * LAMBDA * (1.0 + 2.0 * radial_atten)) / denominator;
                        float attenuation = pow(l2, FALLOFF);

                        

                        float2 displacement = m * l3 * attenuation * _DragIntensity;
                        displacedUV -= displacement;
                    }
                }

                
                
                // 最终采样
                return tex2D(_MainTex, displacedUV);

            }

        
            ENDCG
        }
    }
}
