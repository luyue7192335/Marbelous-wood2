Shader "Unlit/drop3"
{
    Properties
    {
        _PreviousFrame ("Previous Frame", 2D) = "black" {}
        _MainColor ("Main Color", Color) = (1,1,1,1)
        _DropRadius ("Drop Radius", Float) = 0.1
        _ClickPos ("Click Position", Vector) = (0,0,0,0)
    }

    SubShader
    {
        Tags { "RenderType"="Transparent" }
        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            sampler2D _PreviousFrame;
            float4 _MainColor;
            float4 _ClickPos;
            float _DropRadius;

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
                float dist = distance(uv, _ClickPos.xy);
                
                // **获取上一帧的颜色**
                fixed4 previousColor = tex2D(_PreviousFrame, uv);

                // **如果在滴落区域内，就填充新的颜色**
                float mask = 1.0 - smoothstep(_DropRadius * 0.9, _DropRadius, dist);
                fixed4 newColor = lerp(previousColor, _MainColor, mask);

                // **模拟颜色向外扩散（流体推移效果）**
                // float l2 = sqrt((dist * dist) - (_DropRadius * _DropRadius));
                // float2 shiftDir = normalize(uv - _ClickPos.xy);
                // float2 pushedUV = _ClickPos.xy + shiftDir * l2;
                // fixed4 pushedColor = tex2D(_PreviousFrame, pushedUV);
                float2 shiftDir = normalize(uv - _ClickPos.xy);
                float2 pushedUV = _ClickPos.xy + shiftDir * (dist * 0.05); // 让颜色微小扩散
                fixed4 pushedColor = tex2D(_PreviousFrame, pushedUV);


                // **最终颜色 = 推开的颜色 + 新颜色**
                return lerp(pushedColor, newColor, mask);
            }
            ENDCG
        }
    }
}
