//
// Kino/Obscurance - SSAO (screen-space ambient obscurance) effect for Unity
//
// Copyright (C) 2016 Keijiro Takahashi
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
Shader "Hidden/Kino/Obscurance"
{
    Properties
    {
        _MainTex("", 2D) = ""{}
        _MaskTex("", 2D) = ""{}
    }
    CGINCLUDE

    #include "UnityCG.cginc"

    // estimator type selection
    #pragma multi_compile _METHOD_ANGLE _METHOD_DISTANCE

    // sample count (reconfigurable when no keyword is given)
    #pragma multi_compile _ _COUNT_LOW _COUNT_MEDIUM

    sampler2D _MainTex;
    sampler2D _MaskTex;

    float4 _MainTex_TexelSize;
    float4 _MaskTex_TexelSize;

    sampler2D _CameraDepthNormalsTexture;

    half _Intensity;
    half _Contrast;
    float _Radius;
    float _DepthFallOff;
    float _TargetScale;
    float2 _BlurVector;

    #if _COUNT_LOW
    static const int _SampleCount = 6;
    #elif _COUNT_MEDIUM
    static const int _SampleCount = 12;
    #else
    int _SampleCount; // given via uniform
    #endif

    // Small utility for sin/cos
    float2 CosSin(float theta)
    {
        float sn, cs;
        sincos(theta, sn, cs);
        return float2(cs, sn);
    }

    // Pseudo random number generator with 2D argument
    float UVRandom(float u, float v)
    {
        float f = dot(float2(12.9898, 78.233), float2(u, v));
        return frac(43758.5453 * sin(f));
    }

    // Interleaved gradient from Jimenez 2014 http://goo.gl/eomGso
    float GradientNoise(float2 uv)
    {
        float f = dot(float2(0.06711056f, 0.00583715f), floor(uv));
        return frac(52.9829189f * frac(f));
    }

    // Sampling functions with CameraDepthNormalTexture
    float SampleDepth(float2 uv)
    {
        float4 cdn = tex2D(_CameraDepthNormalsTexture, uv);
        return DecodeFloatRG(cdn.zw) * _ProjectionParams.z;
    }

    float3 SampleNormal(float2 uv)
    {
        float4 cdn = tex2D(_CameraDepthNormalsTexture, uv);
        float3 normal = DecodeViewNormalStereo(cdn);
        normal.z *= -1;
        return normal;
    }

    float SampleDepthNormal(float2 uv, out float3 normal)
    {
        float4 cdn = tex2D(_CameraDepthNormalsTexture, uv);
        normal = DecodeViewNormalStereo(cdn);
        normal.z *= -1;
        return DecodeFloatRG(cdn.zw) * _ProjectionParams.z;
    }

    // Reconstruct a world space position from a pair of UV and depth
    // p11_22 = (unity_CameraProjection._11, unity_CameraProjection._22)
    // p13_31 = (unity_CameraProjection._13, unity_CameraProjection._23)
    float3 ReconstructWorldPos(float2 uv, float depth, float2 p11_22, float2 p13_31)
    {
        return float3((uv * 2 - 1 - p13_31) / p11_22, 1) * depth;
    }

    // Normal vector comparer (for geometry-aware weighting)
    half CompareNormal(half3 d1, half3 d2)
    {
        return pow((dot(d1, d2) + 1) * 0.5, 80);
    }

    // Final combiner function
    half3 CombineObscurance(half3 src, half3 mask)
    {
        return lerp(src, 0, mask);
    }

    #if _METHOD_ANGLE

    // Sample point picker for the angle-based method
    float2 PickSamplePoint(float2 uv, float index)
    {
        float gn = GradientNoise(uv * _ScreenParams.xy * _TargetScale);
        float theta = (UVRandom(0, index) + gn) * UNITY_PI * 2;
        // make them distributed between [0, _Radius]
        float l = lerp(0.1, 1.0, index / _SampleCount) * _Radius;
        return CosSin(theta) * l;
    }

    #else // _METHOD_DISTANCE

    // Sample point picker for the distance-based method
    float3 PickSamplePoint(float2 uv, float index)
    {
        // uniformaly distributed points on a unit sphere http://goo.gl/X2F1Ho
        float gn = GradientNoise(uv * _ScreenParams.xy * _TargetScale);
        float u = frac(UVRandom(0, index) + gn) * 2 - 1;
        float theta = (UVRandom(1, index) + gn) * UNITY_PI * 2;
        float3 v = float3(CosSin(theta) * sqrt(1 - u * u), u);
        // make them distributed between [0, _Radius]
        float l = lerp(0.1, 1.0, pow(index / _SampleCount, 1.0 / 3)) * _Radius;
        return v * l;
    }

    #endif

    // Obscurance estimator function
    float EstimateObscurance(float2 uv)
    {
        // parameters used in coordinate conversion
        float3x3 proj = (float3x3)unity_CameraProjection;
        float2 p11_22 = float2(unity_CameraProjection._11, unity_CameraProjection._22);
        float2 p13_31 = float2(unity_CameraProjection._13, unity_CameraProjection._23);

        // view space normal and depth
        float3 norm_o;
        float depth_o = SampleDepthNormal(uv, norm_o);

        // early-out case
        // if (depth_o > kFallOffDist) return 0;

        // reconstruct the view-space position
        float3 wpos_o = ReconstructWorldPos(uv, depth_o, p11_22, p13_31);

        float ao = 0.0;

        #if _METHOD_ANGLE

        // Angle-based estimator based on Mittring 2012 http://goo.gl/wPZrAA
        for (int s = 0; s < _SampleCount / 2; s++)
        {
            // pair of sampling point
            float2 v_s = PickSamplePoint(uv, s);
            float2 uv_s1 = uv + v_s / depth_o;
            float2 uv_s2 = uv - v_s / depth_o;

            // fetch depth value
            float depth_s1 = SampleDepth(uv_s1);
            float depth_s2 = SampleDepth(uv_s2);

            // world position
            float3 wpos_s1 = ReconstructWorldPos(uv_s1, depth_s1, p11_22, p13_31);
            float3 wpos_s2 = ReconstructWorldPos(uv_s2, depth_s2, p11_22, p13_31);

            // vector towards the sampling points
            float3 v_s1 = wpos_s1 - wpos_o;
            float3 v_s2 = wpos_s2 - wpos_o;

            // clip the vectors with the tangent plane
            v_s1 = normalize(v_s1 - norm_o * min(0, dot(v_s1, norm_o)));
            v_s2 = normalize(v_s2 - norm_o * min(0, dot(v_s1, norm_o)));

            // get the angle between the vectors
            float3 v_h = normalize(v_s1 + v_s2);
            float op = asin(dot(v_s1, v_h)) * 4 / UNITY_PI;

            // reject backfacing cases
            const float epsilon = 0.05; // empirical value
            op *= dot(v_h, norm_o) > epsilon;

            // fall off with the distance from the origin
            op *= saturate(2 - distance(wpos_o, wpos_s1) / _Radius);
            op *= saturate(2 - distance(wpos_o, wpos_s2) / _Radius);

            ao += op * 2;
        }

        #else // _METHOD_DISTANCE

        // Distance-based estimator based on Morgan 2011 http://goo.gl/2iz3P
        for (int s = 0; s < _SampleCount; s++)
        {
            // sampling point
            float3 v_s1 = PickSamplePoint(uv, s);
            v_s1 = faceforward(v_s1, -norm_o, v_s1);
            float3 wpos_s1 = wpos_o + v_s1;

            // reproject the sampling point
            float3 spos_s1 = mul(proj, wpos_s1);
            float2 uv_s1 = (spos_s1.xy / wpos_s1.z + 1) * 0.5;

            // depth at the sampling point
            float depth_s1 = SampleDepth(uv_s1);

            // distance to the sampling point
            float3 wpos_s2 = ReconstructWorldPos(uv_s1, depth_s1, p11_22, p13_31);
            float3 v_s2 = wpos_s2 - wpos_o;

            // estimate the obscurance value
            const float beta = 0.01;     // empirical value
            const float epsilon = 0.001; // empirical value
            ao += max(dot(v_s2, norm_o) - beta, 0) / (dot(v_s2, v_s2) + epsilon);
        }

        ao *= (1 / UNITY_PI); // intensity normalization

        #endif

        // apply the depth fall-off
        ao *= 1.0 - depth_o / _DepthFallOff;

        // apply other parameters
        return pow(ao * _Intensity / _SampleCount, _Contrast);
    }

    // Separable blur filter for noise reduction
    half3 SeparableBlur(sampler2D tex, float2 uv, float2 delta)
    {
        half3 n0 = SampleNormal(uv);

        half2 uv1 = uv - delta;
        half2 uv2 = uv + delta;
        half2 uv3 = uv - delta * 2;
        half2 uv4 = uv + delta * 2;

        half w0 = 3;
        half w1 = CompareNormal(n0, SampleNormal(uv1)) * 2;
        half w2 = CompareNormal(n0, SampleNormal(uv2)) * 2;
        half w3 = CompareNormal(n0, SampleNormal(uv3));
        half w4 = CompareNormal(n0, SampleNormal(uv4));

        half3 s = tex2D(tex, uv) * w0;
        s += tex2D(tex, uv1) * w1;
        s += tex2D(tex, uv2) * w2;
        s += tex2D(tex, uv3) * w3;
        s += tex2D(tex, uv4) * w4;

        return s / (w0 + w1 + w2 + w3 + w4);
    }

    // Pass 0: obscurance estimation
    half4 frag_ao(v2f_img i) : SV_Target
    {
        return EstimateObscurance(i.uv);
    }

    // Pass1: geometry-aware blur
    half4 frag_blur(v2f_img i) : SV_Target
    {
        float2 delta = _MainTex_TexelSize.xy * _BlurVector;
        return half4(SeparableBlur(_MainTex, i.uv, delta), 0);
    }

    // Pass 2: combiner
    half4 frag_combine(v2f_img i) : SV_Target
    {
        half4 src = tex2D(_MainTex, i.uv);
        half mask = tex2D(_MaskTex, i.uv);
        return half4(CombineObscurance(src.rgb, mask), src.a);
    }

    ENDCG
    SubShader
    {
        Pass
        {
            ZTest Always Cull Off ZWrite Off
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag_ao
            #pragma target 3.0
            ENDCG
        }
        Pass
        {
            ZTest Always Cull Off ZWrite Off
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag_blur
            #pragma target 3.0
            ENDCG
        }
        Pass
        {
            ZTest Always Cull Off ZWrite Off
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag_combine
            #pragma target 3.0
            ENDCG
        }
    }
}
