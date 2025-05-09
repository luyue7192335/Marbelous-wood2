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
            fixed4 _AllColors[MAX_OPS];
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
                        float baseRadius = _AllOpData[lastOpIndex].z;
                        float noiseStrength = 5*_AllNoiseStrength[lastOpIndex];
                        
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
                            return _AllColors[lastOpIndex]; 
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
                            float scale  = _AllScales[lastOpIndex];
                            float noiseStrength = _AllNoiseStrength[lastOpIndex];

                            float dynamicRadius = lerp(0.0, scale, _LerpFactor);
                            float2 dragVec = -end + start;
                            float dragLength = length(dragVec);
                            if (dragLength < 0.01) return tex2D(_MainTex, displacedUV);

                            float2 dir = dragVec / dragLength;
                            float2 offset = displacedUV - start;
                            float along = dot(offset, dir);
                            float2 closest = start + dir * along;
                            float distToLine = length(displacedUV - closest);

                            // 沿拖拽线段范围衰减
                            float fadeAlong = smoothstep(0.0, 0.1 * dragLength, along) * (1.0 - smoothstep(0.9 * dragLength, dragLength, along));
                            float fadeAcross = smoothstep(dynamicRadius, 0.0, distToLine);
                            float influence = fadeAlong * fadeAcross;

                            float pushStrength = 0.4 * dragLength * _LerpFactor;

                            // 噪声扰动增强边缘变化感
                            float2 noiseCoord = displacedUV * (50.0 + 80.0 * noiseStrength);
                            float noise = sin(dot(noiseCoord, float2(12.9898, 78.233))) * 0.5 + 0.5;
                            float noisePower = lerp(0.8, 1.2, noiseStrength * noise);

                            displacedUV += dir * pushStrength * influence * noisePower;
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

                    else if(_OpTypes[lastOpIndex] == 2) // DRAG operation (curl-noise based vortex effect)
                    {
                        // Read drag start/end from the operation data.
                        float2 start = _AllOpData[lastOpIndex].xy;
                        float2 end   = _AllOpData[lastOpIndex].zw;
                        float2 dragVec = end - start;
                        float dragLength = length(dragVec);
                        float2 mid = (start + end) * 0.5;
                        
                        // 2. 计算拖拽连线的法向量，用于分割画布为两半
                        float2 n = normalize(float2(-dragVec.y, dragVec.x));
                        
                        // 3. 计算当前像素（displacedUV）到拖拽中线的距离 d（在法向量方向上的绝对值）
                        float d = abs(dot(displacedUV - mid, n));
                        
                        // 4. 以 _AllScales[lastOpIndex] 作为参考尺度 d₀
                        float d0 = 0.5*_AllScales[lastOpIndex];
                        float x = d / d0;
                        
                        // 5. 根据 d 构造噪声偏移的映射
                        // 当 d 接近于0时，偏移应接近1；当 d 达到 d0 时偏移为0；
                        // 当 d 大于 d0 时，随着 d 增加，偏移逐渐平滑过渡到 -1（假设 d 的最大值取1）
                        // float noiseOffset;
                        //  if(d <= d0)
                        // {
                        //     noiseOffset = 0.5*(1.0 - pow(smoothstep(0.0, d0 , d), 2.0));
                        // }
                        // else
                        // {
                        //     noiseOffset = -0.5*smoothstep(d0, 1.0, d);
                        // }
                        // --- 双曲线映射：x=0->+1，x=1->0，x->∞->-1 ---
                        float hyper = (1.0 - x*x) / (1.0 + x*x);

                        // --- 在 x≈1（hyper≈0）附近再做一次 smoothstep 混合，让零点过渡更柔和 ---
                        float crossT = smoothstep(0.95, 1.05, x);
                        float noiseOffset = lerp(hyper, 0.0, crossT);
                                                
                        // 6. 定义噪声密度参数，计算潜能场 ψ
                        float noiseScale = 0.7;
                        // modulation 可进一步调整潜能整体幅度，这里设为1（即完全依赖上面的调制）
                        float modulation = 1.0;
                        float psi = modulation * perlin_noise(displacedUV * noiseScale + noiseOffset);

                        // 7. 利用有限差分计算 ψ 在 x 和 y 方向的偏导数
                        float eps = 0.001;
                        float psi_x = (modulation * perlin_noise((displacedUV + float2(eps, 0)) * noiseScale + noiseOffset) - psi) / eps;
                        float psi_y = (modulation * perlin_noise((displacedUV + float2(0, eps)) * noiseScale + noiseOffset) - psi) / eps;
                        
                        // 8. 根据论文思想计算二维流场 v = (∂ψ/∂y, -∂ψ/∂x)
                        float2 velocity = float2(psi_y, -psi_x);
                        
                        // 9. 根据 _LerpFactor 平滑过渡地将速度场叠加到 UV 上
                        displacedUV += _LerpFactor * velocity;
                        
                    }
                    else if(_OpTypes[lastOpIndex] == 4) // DRAG操作
                    {
                        // #define LAMBDA 0.02
                        // #define FALLOFF 1.0
                        // float _DragIntensity = 0.7;
                        // #define EDGE_SMOOTHNESS 0.3 // [0.1-0.5] 边缘柔化系数

                        
                        float2 start = _AllOpData[lastOpIndex].xy;
                        float2 end = _AllOpData[lastOpIndex].zw;
                        float baseScale = _AllScales[lastOpIndex];
                        float noiseStrength = 4*_AllNoiseStrength[lastOpIndex];
                        
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
                        float radius = _AllOpData[j].z;
                        fixed4 dropColor = _AllColors[j];

                        float noiseStrength = 5*_AllNoiseStrength[j];
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
                            return dropColor;
                        }
                    }
                    else if (_OpTypes[j] == 1) // DRAG 操作（推前补后 + 噪声扰动）
                    {
                        float2 start = _AllOpData[j].xy;
                        float2 end   = _AllOpData[j].zw;
                        float scale  = _AllScales[j];
                        float noiseStrength = _AllNoiseStrength[j];

                        float2 dragVec = -end + start;
                        float dragLength = length(dragVec);
                        if (dragLength < 0.01) continue;

                        float2 dir = dragVec / dragLength;
                        float2 offset = displacedUV - start;
                        float along = dot(offset, dir);
                        float2 closest = start + dir * along;
                        float distToLine = length(displacedUV - closest);

                        float fadeAlong = smoothstep(0.0, 0.1 * dragLength, along) * (1.0 - smoothstep(0.9 * dragLength, dragLength, along));
                        float fadeAcross = smoothstep(scale, 0.0, distToLine);
                        float influence = fadeAlong * fadeAcross;

                        float pushStrength = 0.4 * dragLength;

                        float2 noiseCoord = displacedUV * (50.0 + 80.0 * noiseStrength);
                        float noise = sin(dot(noiseCoord, float2(12.9898, 78.233))) * 0.5 + 0.5;
                        float noisePower = lerp(0.8, 1.2, noiseStrength * noise);

                        displacedUV += dir * pushStrength * influence * noisePower;
                    }

                    else if(_OpTypes[j] == 4) // DRAG 操作
                    {
                            float2 start = _AllOpData[j].xy;
                            float2 end   = _AllOpData[j].zw;
                            float scale  = _AllScales[j];
                            float noiseStrength =4*_AllNoiseStrength[j];

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
                    else if(_OpTypes[j] == 2) // DRAG操作（基于旋度的旋涡效果）
                    {
                        float2 start = _AllOpData[j].xy;
                        float2 end   = _AllOpData[j].zw;
                        float2 dragVec = end - start;
                        float dragLength = length(dragVec);
                        float2 mid = (start + end) * 0.5;
                        
                        // 2. 计算拖拽连线的法向量，用于分割画布为两半
                        float2 n = normalize(float2(-dragVec.y, dragVec.x));
                        
                        // 3. 计算当前像素（displacedUV）到拖拽中线的距离 d（在法向量方向上的绝对值）
                        float d = abs(dot(displacedUV - mid, n));
                        
                        // 4. 以 _AllScales[lastOpIndex] 作为参考尺度 d₀
                        float d0 =0.5* _AllScales[j];
                        float x = d / d0;
                        
                        // 5. 根据 d 构造噪声偏移的映射
                        // 当 d 接近于0时，偏移应接近1；当 d 达到 d0 时偏移为0；
                        // 当 d 大于 d0 时，随着 d 增加，偏移逐渐平滑过渡到 -1（假设 d 的最大值取1）
                        // float noiseOffset;
                        //  if(d <= d0)
                        // {
                        //     noiseOffset = 0.5*(1.0 - pow(smoothstep(0.0, d0 , d), 2.0));
                        // }
                        // else
                        // {
                        //     noiseOffset = -0.5*smoothstep(d0, 1.0, d);
                        // }
                        // --- 双曲线映射：x=0->+1，x=1->0，x->∞->-1 ---
                        float hyper = (1.0 - x*x) / (1.0 + x*x);

                        // --- 在 x≈1（hyper≈0）附近再做一次 smoothstep 混合，让零点过渡更柔和 ---
                        float crossT = smoothstep(0.95, 1.05, x);
                        float noiseOffset = lerp(hyper, 0.0, crossT);
                        
                        // 6. 定义噪声密度参数，计算潜能场 ψ
                        float noiseScale = 0.7;
                        // modulation 可进一步调整潜能整体幅度，这里设为1（即完全依赖上面的调制）
                        float modulation = 1.0;
                        float psi = modulation * perlin_noise(displacedUV * noiseScale + noiseOffset);

                        // 7. 利用有限差分计算 ψ 在 x 和 y 方向的偏导数
                        float eps = 0.001;
                        float psi_x = (modulation * perlin_noise((displacedUV + float2(eps, 0)) * noiseScale + noiseOffset) - psi) / eps;
                        float psi_y = (modulation * perlin_noise((displacedUV + float2(0, eps)) * noiseScale + noiseOffset) - psi) / eps;
                        
                        // 8. 根据论文思想计算二维流场 v = (∂ψ/∂y, -∂ψ/∂x)
                        float2 velocity = float2(psi_y, -psi_x);
    
                        displacedUV +=  velocity;
                        
                        
                        
                      
                        }
                    

                
                }
                // 最终采样
                return tex2D(_MainTex, displacedUV);

            }

        
            ENDCG
        }
    }
}
