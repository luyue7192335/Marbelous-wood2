Shader "Unlit/NewTestShader"

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
            Blend Off
            ZWrite On
            Cull Off
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            #define MAX_OPS 100
            #define LAMBDA 0.02

           

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
            float4 _AllColors[MAX_OPS];
            int _OpTypes[MAX_OPS];
            float _AllNoiseStrength[MAX_OPS];

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            float2 hash2d(int si, int sj)
            {
                // 定义质数参数（uint 类型）
                uint p1 = 73856093u;
                uint p2 = 19349663u;
                uint p3 = 83492791u;
                uint K  = 93856263u;
                
                // 将输入转换为 uint 类型
                uint i = (uint)si;
                uint j = (uint)sj;
                
                // 计算哈希值
                uint h1 = ((i * p1) ^ (j * p2)) % K;
                uint h2 = ((j * p1) ^ (i * p3)) % K;
                
                // 将结果归一化到 -0.5 ~ 0.5范围内，注意强制类型转换为 float
                return float2(h1, h2) / float(K) - 0.5;
            }

            float perlin_noise(float2 x) {
                    float2 i = floor(x);
                    float2 f = x - i;
                    float2 u = f*f*f*(f*(f*6.0-15.0)+10.0);
                    float2 ga = hash2d(int(i.x), int(i.y));
                    float2 gb = hash2d(int(i.x)+1, int(i.y));
                    float2 gc = hash2d(int(i.x), int(i.y)+1);
                    float2 gd = hash2d(int(i.x)+1, int(i.y)+1);
                    float va = dot(ga, f - float2(0.0,0.0));
                    float vb = dot(gb, f - float2(1.0,0.0));
                    float vc = dot(gc, f - float2(0.0,1.0));
                    float vd = dot(gd, f - float2(1.0,1.0));
                    return va + u[0]*(vb-va) + u[1]*(vc-va) + u[0]*u[1]*(va-vb-vc+vd);
                }

            float ramp(float d) {
                    // 当 d 从 0 到 1 之间，smoothstep 在边缘处平滑过渡
                    return smoothstep(0.1, 0.3, d);
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
                        float baseRadius = 0.5*_AllOpData[lastOpIndex].z;
                        float noiseStrength = _AllNoiseStrength[lastOpIndex];
                        
                        // 动态半径计算（带时间插值）
                        float dynamicRadius = lerp(0.0, baseRadius, _LerpFactor);

                        float2 offset = float2(lastOpIndex, lastOpIndex); 
                        //float noiseVal = perlin_noise(displacedUV * 50.0 + offset); 
                         //float noiseVal = perlin_noise(displacedUV * 50.0 + offset); 
                        float noiseContrast = 1;   // 增强对比度
                        float noiseVal = pow(perlin_noise(displacedUV * 50 + offset), noiseContrast);
                      
                        float dynamicRadiusNoisy = dynamicRadius * (1.0 + noiseStrength * noiseVal);
    
                        float2 delta = displacedUV - dropPos;
                        float dist = length(delta);
                        
                        //if(dist <= dynamicRadius)
                        if(dist <= dynamicRadiusNoisy)
                        {
                            // 进入动态区域时返回颜色
                            //return _AllColors[lastOpIndex]; 
                            //return float4(_AllColors[lastOpIndex].rgb, 1.0);

                            // float4 baseColor = _AllColors[lastOpIndex];
                            // baseColor.a = 1.0; // 避免因透明而变灰
                            // baseColor.rgb = pow(baseColor.rgb, 1.0 / 2.2); // 若你用的是 Linear 色彩空间（需测试）
                            // return baseColor;

                            float4 baseColor = _AllColors[lastOpIndex];
                            baseColor.a = 1.0; // 避免因透明而变灰
                            baseColor.rgb = pow(baseColor.rgb, 1.0 / 0.5); // 若你用的是 Linear 色彩空间（需测试）
                            return baseColor;



                        }
                        else
                        {
                            // 动态位移计算
                            float l2 = sqrt(max(dot(delta, delta) - dynamicRadiusNoisy * dynamicRadiusNoisy, 0));
                            displacedUV = dropPos + (delta / dist) * l2;
                        }
                    }
                    else if (_OpTypes[lastOpIndex] == 1) // DRAG 操作（推前补后 + 噪声扰动）
                    {
                        float2 start = _AllOpData[lastOpIndex].xy;
                        float2 end   = _AllOpData[lastOpIndex].zw;
                        float scale  = 0.5*_AllScales[lastOpIndex];
                        float noiseStrength = _AllNoiseStrength[lastOpIndex];
                        float dynamicScale = lerp(0.0, scale, _LerpFactor);

                        float2 dragVec = start - end;  // 拖拽方向，start → end
                        float dragLength = length(dragVec);
                        if (dragLength < 0.01) return tex2D(_MainTex, displacedUV);

                        float2 dir = normalize(dragVec);
                        float2 offset = displacedUV - start;

                        float along = dot(offset, dir);
                        float2 closest = start + dir * along;
                        float distToLine = length(displacedUV - closest);

                        float radius = dynamicScale;
                        float fade = smoothstep(radius, 0.0, distToLine);  // 法向影响

                        // ------- Perlin噪声扰动（模拟自然破碎边缘）-------
                        
                        // float2 noiseCoord = displacedUV * (150.0 + noiseStrength * 8000.0);
                        // float rawPerlin = perlin_noise(noiseCoord);
                        // // float perlin = saturate(rawPerlin * 0.5 + 0.5);  // [-0.7,0.7] 映射到 [0.15,0.85]
                        //float amplified = pow(abs(perlin - 0.5) * 2.0, 1.5); // 放大中间差异
                        // 简洁模拟 drop 的噪声逻辑
                        float2 offset1 = float2(0, 0); // 或者 lastOpIndex，用于让每个操作有不同噪声相位
                        float perlin = perlin_noise(displacedUV * 50.0 + offset1);
                        float noisePower = 1.0 + 6*noiseStrength * perlin;


                       // float noisePower = lerp(0.3, 10.0, amplified * noiseStrength);  // 更自然地调制边缘强度

                        // ------- 推前补后（方向一致，幅度对称）-------
                        float pushStrength = dragLength * 0.3;

                        float2 displace = dir * pushStrength * fade * noisePower;


                            displacedUV += displace;   // 前推

                    }

                    
                    else if(_OpTypes[lastOpIndex] == 3) // comb操作
                    {
                        float2 start = _AllOpData[lastOpIndex].xy;
                        float2 end   = _AllOpData[lastOpIndex].zw;
                        // 1) 计算 alpha, beta （beta 取 op.scale*0.25 或屏幕最小像素）
                        float alpha = length(end - start);
                        //float beta  = max(_AllScales[lastOpIndex] * 0.25,2.0 / (1+1));//_ScreenParams.x + _ScreenParams.y
                        float beta  = _AllScales[lastOpIndex] * 0.5;
                        if (alpha > 0.01) {
                            // 2) 根据 _LerpFactor 做动态插值
                            float dynamicAlpha = alpha * _LerpFactor;
                            float dynamicBeta  = beta  * _LerpFactor;

                            float2 m = (end - start) / alpha;
                            float2 n = float2(-m.y, m.x);

                            // 3) l1, l2, l3
                            float l1 = abs(dot(displacedUV - start, n));
                            float l2 = abs(fmod(l1, dynamicBeta * 2.0) - dynamicBeta);
                            float l3 = (dynamicAlpha * LAMBDA) / (dynamicBeta - l2 + LAMBDA);

                            // 4) 移动 p
                            displacedUV -= m * l3 * pow(l2 / dynamicBeta, 2.0);   

                        }
                    }

                    else if(_OpTypes[lastOpIndex] == 2) // curl-noise based vortex effect)
                    {
                        // Read drag start/end from the operation data.
                        float2 start = _AllOpData[lastOpIndex].xy;
                        float2 end   = _AllOpData[lastOpIndex].zw;
                        float dragLength = length(end - start);
                        //float noiseStrength = _AllNoiseStrength[lastOpIndex];
                        float noiseStrength = 1;

                        // 基础参数
                        float freqControl = saturate(_AllScales[lastOpIndex]);           // 0–1，决定卷曲频率
                        float ampControl  = saturate(_AllNoiseStrength[lastOpIndex]); 
                        float curlFreq = lerp(2.0, 25.0, freqControl);          
                        // 振幅调节：控制扰动强弱
                        float curlAmp  = lerp(0.01, 0.3, ampControl);  
                        // float curlFreq = lerp(2.0, 15.0, saturate(dragLength));         // 拖越长频率越高
                        // float curlAmp  = lerp(0.02, 0.3, noiseStrength);              // 振幅由 noise 控制

                        // Perlin Noise Curl field approximation
                        float eps = 0.001;

                        // Compute partial derivatives of noise field (perlin_noise 是你已有的）
                        float2 nCoord = displacedUV * curlFreq;
                        float noiseBase = perlin_noise(nCoord);
                        float noiseX = perlin_noise(nCoord + float2(eps, 0.0));
                        float noiseY = perlin_noise(nCoord + float2(0.0, eps));

                        float2 gradient = float2((noiseX - noiseBase)/eps, (noiseY - noiseBase)/eps);

                        // Curl: 2D orthogonal vector
                        float2 curlVec = float2(gradient.y, -gradient.x);

                        // 应用扰动
                        displacedUV += curlVec * curlAmp * _LerpFactor;
                        
                    }
                    else if(_OpTypes[lastOpIndex] == 4) // wave操作
                    {
                        // #define LAMBDA 0.02
                        // #define FALLOFF 1.0
                        // float _DragIntensity = 0.7;
                        // #define EDGE_SMOOTHNESS 0.3 // [0.1-0.5] 边缘柔化系数

                        
                        float2 start = _AllOpData[lastOpIndex].xy;
                        float2 end = _AllOpData[lastOpIndex].zw;
                        float baseScale = 0.5*_AllScales[lastOpIndex];
                        float noiseStrength = 2*_AllNoiseStrength[lastOpIndex];
                        
                        // 动态缩放系数
                        float dynamicScale = lerp(0.0, baseScale, _LerpFactor);
                        
                        // 基于动态缩放重新计算位移
                        float2 dragVec = start-end ;
                        //x(-1)
                        float dragLength = length(dragVec);
                        if(dragLength < 0.01) return tex2D(_MainTex, displacedUV);
                        
                        float2 dir = dragVec / dragLength;  // 方向
                            float2 offset = displacedUV - start;

                            float along = dot(offset, dir);                  // 轴向位置
                            float2 closest = start + dir * along;
                            float distToLine = length(displacedUV - closest); // 法向距离

                            float radius = dynamicScale;  // 影响范围
                            float fade = smoothstep(radius, 0.0, distToLine); // 近=1 远=0

                            //float pushStrength = 0.2;  
                            float pushStrength = dragLength * 0.4;

                            displacedUV += dir * pushStrength * fade;

                            // -------- 涟漪（沿法线方向的波动）---------
                            // float rippleFrequency = 20.0;
                            // float rippleAmplitude = 0.07;
                            float rippleFrequency = lerp(30.0, 600.0, noiseStrength);
                            float rippleAmplitude = lerp(0.1, 2.0, noiseStrength);

                            float alongT = along / dragLength;

                            float ripple = sin(alongT * rippleFrequency) * rippleAmplitude * fade;
                            // float turbulence = sin(alongT * rippleFrequency * 3.0 + displacedUV.x * 100.0 + displacedUV.y * 100.0) * lerp(0.0, 0.05, noiseStrength);

                            // ripple += turbulence;

                            float2 normal = normalize(displacedUV - closest + 0.0001);
                            displacedUV += normal * ripple;

                    }

                }
                // 统一逆向处理所有操作（`_OpCount - 2` 方式）
                for(int j = _OpCount - 2; j >= 0; --j)
                {
                    if(_OpTypes[j] == 0) // DROP 操作
                    {
                        float2 dropPos = _AllOpData[j].xy;
                        float radius =0.5* _AllOpData[j].z;
                        float4 dropColor = _AllColors[j];

                        float noiseStrength = _AllNoiseStrength[j];
                        // 这里以 dropPos 作为噪声参考，也可以使用 displacedUV，以保证整个圆边的连续性
                        float2 offset = float2(j, j); 
                        //float noiseVal = perlin_noise(displacedUV * 50.0 + offset); 
                        float noiseContrast = 1;   // 增强对比度
                        float noiseVal = pow(perlin_noise(displacedUV * 50 + offset), noiseContrast);
                        // 将噪声值映射到 [ -noiseStrength, noiseStrength ]，再加到 dynamicRadius 上
                        float dynamicRadiusNoisy = radius * (1.0 + noiseStrength * noiseVal);
                        

                        float2 delta = displacedUV - dropPos;
                        float dist = length(delta);
                        float radiusSqr = dynamicRadiusNoisy * dynamicRadiusNoisy;

                        if(dist > dynamicRadiusNoisy)
                        {
                            float l2 = sqrt(dot(delta, delta) - radiusSqr);
                            displacedUV = dropPos + (delta / dist) * l2;
                        }
                        else
                        {
                            //return dropColor;
                            //return float4(_AllColors[lastOpIndex].rgb, 1.0);
                            // float4 baseColor = _AllColors[j];
                            // baseColor.a = 1.0; // 避免因透明而变灰
                            // baseColor.rgb = pow(baseColor.rgb, 1.0 / 2.2); // 若你用的是 Linear 色彩空间（需测试）
                            // return baseColor;

                            float4 baseColor = _AllColors[j];
                            baseColor.a = 1.0; // 避免因透明而变灰
                            baseColor.rgb = pow(baseColor.rgb, 1.0 / 0.5); // 若你用的是 Linear 色彩空间（需测试）
                            return baseColor;
                        }
                    }
                    else if (_OpTypes[j] == 1) // DRAG 操作（推前补后 + 噪声扰动）
                    {
                        float2 start = _AllOpData[j].xy;
                        float2 end   = _AllOpData[j].zw;
                        float scale  = _AllScales[j];
                        float noiseStrength = _AllNoiseStrength[j];

                        float2 dragVec = start - end;
                        float dragLength = length(dragVec);
                        if (dragLength < 0.01) continue;

                        float2 dir = normalize(dragVec);
                        float2 offset = displacedUV - start;

                        float along = dot(offset, dir);
                        float2 closest = start + dir * along;
                        float distToLine = length(displacedUV - closest);

                        float radius = scale;
                        float fade = smoothstep(radius, 0.0, distToLine);

                        // float2 noiseCoord = displacedUV * (150.0 + noiseStrength * 8000.0);
                        // float rawPerlin = perlin_noise(noiseCoord);
                        //float perlin = saturate(rawPerlin * 0.5 + 0.5);  // [-0.7,0.7] 映射到 [0.15,0.85]
                        //float amplified = pow(abs(perlin - 0.5) * 2.0, 1.5); // 放大中间差异
                                                // 简洁模拟 drop 的噪声逻辑
                        float2 offset1 = float2(j, j); // 或者 lastOpIndex，用于让每个操作有不同噪声相位
                        float perlin = perlin_noise(displacedUV * 50.0 + offset1);
                        float noisePower = 1.0 + 6*noiseStrength * perlin;


                       // 

                        //float noisePower = lerp(0.3, 10.0, amplified * noiseStrength);  
                        float pushStrength = dragLength * 0.3;
                        float2 displace = dir * pushStrength * fade * noisePower;

                        
                        displacedUV += displace;
    
                    }

                    else if(_OpTypes[j] == 4) // DRAG 操作
                    {
                            float2 start = _AllOpData[j].xy;
                            float2 end   = _AllOpData[j].zw;
                            float scale  = 0.5*_AllScales[j];
                            float noiseStrength =2*_AllNoiseStrength[j];

                            float2 dragVec = start-end ;
                            float dragLength = length(dragVec);
                            if(dragLength < 0.01) continue;

                            float2 dir = dragVec / dragLength;  // 方向
                            float2 offset = displacedUV - start;

                            float along = dot(offset, dir);                  // 轴向位置
                            float2 closest = start + dir * along;
                            float distToLine = length(displacedUV - closest); // 法向距离

                            float radius = scale;  // 影响范围
                            float fade = smoothstep(radius, 0.0, distToLine); // 近=1 远=0

                            // -------- 推动（沿拖拽方向）---------
                            //float pushStrength = 0.2; 
                            float pushStrength = dragLength * 0.4;
 
                            displacedUV += dir * pushStrength * fade;

                            // -------- 涟漪（沿法线方向的波动）---------
                            // float rippleFrequency = 20.0;
                            // float rippleAmplitude = 0.07;
                            float rippleFrequency = lerp(30.0, 600.0, noiseStrength);
                            float rippleAmplitude = lerp(0.1, 2.0, noiseStrength);

                            float alongT = along / dragLength;

                            float ripple = sin(alongT * rippleFrequency) * rippleAmplitude * fade;

                            //float ripple = sin(alongT * rippleFrequency) * rippleAmplitude * fade;
                            // float turbulence = sin(alongT * rippleFrequency * 3.0 + displacedUV.x * 100.0 + displacedUV.y * 100.0) * lerp(0.0, 0.05, noiseStrength);

                            // ripple += turbulence;


                            float2 normal = normalize(displacedUV - closest + 0.0001);
                            displacedUV += normal * ripple;
                    }
                    else if(_OpTypes[j] == 3) // comb 操作
                    {
                        
                        float2 start = _AllOpData[j].xy;
                        float2 end   = _AllOpData[j].zw;
                        float alpha = length(end - start);
                        //float beta  = max(_AllScales[j] * 0.25, 2.0 / (1 + 1));
                         float beta  = _AllScales[j] * 0.25  ;            
                        if (alpha > 0.01) {
                            float2 m = (end - start) / alpha;
                            float2 n = float2(-m.y, m.x);

                            float l1 = abs(dot(displacedUV - start, n));
                            float l2 = abs(fmod(l1, beta * 2.0) - beta);
                            float l3 = (alpha * LAMBDA) / (beta - l2 + LAMBDA);

                            displacedUV -= m * l3 * pow(l2 / beta, 2.0);
                        }
                    }
                    else if(_OpTypes[j] == 2) // curl 操作
                    {
                        float2 start = _AllOpData[j].xy;
                        float2 end   = _AllOpData[j].zw;
                        float dragLength = length(end - start);
                        //float noiseStrength = _AllNoiseStrength[j];
                        float noiseStrength = 1;

                        // 基础参数
                        float freqControl = saturate(_AllScales[j]);           // 0–1，决定卷曲频率
                        float ampControl  = saturate(_AllNoiseStrength[j]); 
                        float curlFreq = lerp(2.0, 25.0, freqControl);          
                        // 振幅调节：控制扰动强弱
                        float curlAmp  = lerp(0.01, 0.3, ampControl);  

                        // float curlFreq = lerp(2.0, 15.0, saturate(dragLength));         // 拖越长频率越高
                        // float curlAmp  = lerp(0.02, 0.3, noiseStrength);              // 振幅由 noise 控制

                        // Perlin Noise Curl field approximation
                        float eps = 0.001;

                        // Compute partial derivatives of noise field (perlin_noise 是你已有的）
                        float2 nCoord = displacedUV * curlFreq;
                        float noiseBase = perlin_noise(nCoord);
                        float noiseX = perlin_noise(nCoord + float2(eps, 0.0));
                        float noiseY = perlin_noise(nCoord + float2(0.0, eps));

                        float2 gradient = float2((noiseX - noiseBase)/eps, (noiseY - noiseBase)/eps);

                        // Curl: 2D orthogonal vector
                        float2 curlVec = float2(gradient.y, -gradient.x);

                        // 应用扰动
                        displacedUV += curlVec * curlAmp;
                    
                      
                        }
                    

                
                }
                // 最终采样
                return tex2D(_MainTex, displacedUV);

            }

        
            ENDCG
        }
    }
}
