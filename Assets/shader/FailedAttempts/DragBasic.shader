Shader "Unlit/DragBasic"
//Shader "Unlit/WithDrag"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
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

            // C#传递的数据
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
                float2 uv = i.uv;
                float2 displacedUV = uv;

                // 统一逆向处理所有操作
                for(int j = _OpCount-1; j >= 0; --j)
                {
                    if(_OpTypes[j] == 0) // DROP操作
                    {
                        float2 dropPos = _AllOpData[j].xy;
                        float radius = _AllOpData[j].z;
                        fixed4 dropColor = _AllColors[j];
                        
                        float2 delta = displacedUV - dropPos;
                        float dist = length(delta);
                        float radiusSqr = radius * radius;

                        if(dist > radius)
                        {
                            // 硬边界位移（您的原始算法）
                            float l2 = sqrt(dot(delta, delta) - radiusSqr);
                            displacedUV = dropPos + (delta / dist) * l2;
                        }
                        else
                        {
                            return dropColor; // 直接覆盖颜色
                        }
                    }
                 
                    

                    else if(_OpTypes[j] == 1) // DRAG操作
                    {
                        #define LAMBDA 0.02  // 防止除零的最小量
                        #define FALLOFF 1.0   // 衰减曲线陡度
                        float ALPHA = 0.4;
                        float _DragIntensity = 0.7;
                        
                        // 解析操作数据
                        float2 start = _AllOpData[j].xy; // 拖拽起点（UV坐标）
                        float2 end = _AllOpData[j].zw;   // 拖拽终点（UV坐标）
                        float scale = _AllScales[j];     // 影响范围系数（0~1）
                        
                        // 计算基础向量
                        float2 dragVec = end - start;
                        float alpha = length(dragVec);   // 拖拽路径长度
                        if(alpha < 0.01) continue;       // 过滤无效短路径
                        float beta = scale * 0.5;
                        if(scale < 0.01) continue; 
                        
                        float2 m = dragVec / alpha;      // 拖拽方向单位向量
                        float2 n = float2(-m.y, m.x);    // 垂直方向单位向量
                        
                        // 计算当前点到拖拽路径的投影
                        float2 toStart = displacedUV - start;
                        //float along = dot(toStart, m);   // 沿拖拽方向的投影长度
                        float l1 = dot(toStart, n);  // 垂直方向的距离（有符号）
                        float l2_raw = 1.0 - smoothstep(0.0, beta, abs(l1));
                       // float l2_raw = 1.0 - smoothstep(beta* 0.3, beta, abs(l1));
                        float l2 = saturate(l2_raw);
                        float denominator = max(beta * 0.5 + LAMBDA, 0.01); // 基础分母量
                        float l3 = (alpha * LAMBDA) / denominator;
                        //displacedUV =displacedUV - (m * l3 * pow(l2 / beta, 2.0)); // 应用位移
                        float attenuation = pow(l2, FALLOFF); // 代替原l2/beta方案

                        // 最终位移计算（加入强度控制）
                        float2 displacement = m * l3 * attenuation * _DragIntensity;
                        displacedUV -= displacement; // 应用位移        
                    }
                }

                // 最终采样
                fixed4 finalColor = tex2D(_MainTex, displacedUV);
                return finalColor;
            }
            ENDCG
        }
    }
}
