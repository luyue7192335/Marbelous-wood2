Shader "DropBasic"
{
    Properties
    {
        _MainTex ("Main Texture", 2D) = "white" {}
        
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" }
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
           
            sampler2D _MainTex;
            
            float4 _MainTex_ST;

            
            int _DropCount;
            float4 _AllClickPos[100];
            float4 _AllColors[100];
            float _AllRadii[100];

            struct appdata_t
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            v2f vert(appdata_t v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                
                float2 uv = i.uv;
                //fixed4 baseColor = tex2D(_MainTex, uv);  // **获取原始颜色**
                //fixed4 accumulatedColor = baseColor;  // **初始颜色等于原始颜色**
                //fixed4 finalColor = baseColor;
                float2 displacedUV = uv;

                 for(int j = _DropCount-1; j >= 0; j--)
                {
                    float2 dropPos = _AllClickPos[j].xy;
                    float radius = _AllRadii[j];
                    float4 dropColor = _AllColors[j];
                    
                    // 计算到当前滴落中心的距离
                    float2 delta = displacedUV - dropPos;
                    float dist = length(delta);
                    float radiusSqr = radius * radius;

                    // 核心位移算法（来自你的参考代码）
                    if(dist > radius)
                    {
                        // 保持硬边界的关键计算
                        float l2 = sqrt(dot(delta, delta) - radiusSqr);
                        displacedUV = dropPos + (delta / dist) * l2;
                    }
                    else
                    {
                        // 直接返回滴落颜色（硬边界）
                        return dropColor;
                    }
                }

                // 最终采样被多次位移后的UV
                fixed4 finalColor = tex2D(_MainTex, displacedUV);

                

                return finalColor;
                


            }
            ENDCG
        }
    }
}

