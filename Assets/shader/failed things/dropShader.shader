Shader "Unlit/dropShader"
{
    Properties {
        _MainTex ("Base (RGB)", 2D) = "white" {}
        _ClickPos ("Click Position", Vector) = (0,0,0,0)
        //_MainColor ("Main Color", Color) = (1,1,1,1)
         _MainColor ("Drawing Color", Color) = (1,0,0,1)
        //_DropRadius ("Drop Radius", Range(0,1)) = 0.1
        _DropRadius ("Brush Radius", Range(0.01, 0.5)) = 0.1

        _Displacement ("Displacement", Range(0,1)) = 0.5
    }
    SubShader {
        Tags { "RenderType"="Opaque" }
        
        Pass {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            

            struct appdata {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f {
                float2 uv : TEXCOORD0;
                float4 pos : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _ClickPos;
            float4 _MainColor;
            //float _DropRadius;
            uniform float _DropRadius;
            float _Displacement;

            v2f vert (appdata v) {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target {
                float2 p = i.uv;
                float2 center = _ClickPos.xy;
                float radius = _DropRadius;
                
                // 计算到点击中心的距离
                float2 d = p - center;
                float l = length(d);
                
                if(l < radius) {
                    // 半径内直接使用新颜色
                    return _MainColor;
                }
                else {
                    // 半径外进行位移计算
                    float l2 = sqrt((l * l) - (radius * radius));
                    float2 newUV = center + (d / l) * l2 * _Displacement;
                    
                    // 混合原始颜色和新颜色
                    fixed4 original = tex2D(_MainTex, newUV);
                    return lerp(original, _MainColor, saturate(radius - l + 0.2));
                }
            }
            ENDCG
        }
    }
}
