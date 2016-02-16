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
        _AOTex("", 2D) = ""{}
    }
    CGINCLUDE

    #include "UnityCG.cginc"

    #pragma multi_compile _ _COUNT_LOW _COUNT_MEDIUM
    #pragma multi_compile _METHOD_DISC _METHOD_SPHERE

    sampler2D _MainTex;
    float2 _MainTex_TexelSize;

    sampler2D _AOTex;
    float2 _AOTex_TexelSize;

    sampler2D _CameraDepthNormalsTexture;

    half _Intensity;
    half _Contrast;
    float _Radius;
    float2 _BlurVector;

    static const float kFallOffDist = 100;

    #if _COUNT_LOW
    static const int _SampleCount = 10;
    #elif _COUNT_MEDIUM
    static const int _SampleCount = 16;
    #else
    int _SampleCount; // given as a uniform
    #endif

    float UVRandom(float2 uv, float dx, float dy)
    {
        uv += float2(dx, dy + _Time.x * 0);
        return frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453);
    }

    float3 RandomVectorSphere(float2 uv, float index)
    {
        // Uniformaly distributed points
        // http://mathworld.wolfram.com/SpherePointPicking.html
        float u = UVRandom(uv, 0, index) * 2 - 1;
        float theta = UVRandom(uv, 1, index) * UNITY_PI * 2;
        float u2 = sqrt(1 - u * u);
        float3 v = float3(u2 * cos(theta), u2 * sin(theta), u);
        // Adjustment for distance distribution
        float l = index / _SampleCount;
        return v * lerp(0.1, 1.0, pow(l, 1.0 / 3));
    }

    float2 RandomVectorDisc(float2 uv, float index)
    {
        float sn, cs;
        sincos(UVRandom(uv, 0, index) * UNITY_PI * 2, sn, cs);
        float l = index / _SampleCount;
        return float2(sn, cs) * sqrt(l);
    }

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

    float3 ReconstructWorldPos(float2 uv, float depth, float2 p11_22, float2 p13_31)
    {
        return float3((uv * 2 - 1 - p13_31) / p11_22, 1) * depth;
    }

    half CompareNormal(half3 d1, half3 d2)
    {
        return pow((dot(d1, d2) + 1) * 0.5, 80);
    }

    half3 CombineObscurance(half3 src, half3 ao)
    {
        return lerp(src, 0, ao);
    }

    float CalculateObscurance(float2 uv)
    {
        // Parameters used for coordinate conversion
        float3x3 proj = (float3x3)unity_CameraProjection;
        float2 p11_22 = float2(unity_CameraProjection._11, unity_CameraProjection._22);
        float2 p13_31 = float2(unity_CameraProjection._13, unity_CameraProjection._23);

        // View space normal and depth
        float3 norm_o;
        float depth_o = SampleDepthNormal(uv, norm_o);

        // Early-out case
        if (depth_o > kFallOffDist) return 0;

        // Reconstruct the view-space position.
        float3 pos_o = ReconstructWorldPos(uv, depth_o, p11_22, p13_31);

        float ao = 0.0;
        for (int s = 0; s < _SampleCount; s++)
        {
#if _METHOD_SPHERE
            // Sampling point (sphere)
            float3 v1 = RandomVectorSphere(uv, s);
            v1 = faceforward(v1, -norm_o, v1);
            float3 pos_s = pos_o + v1 * _Radius;

            // Re-project the sampling point
            float3 pos_sc = mul(proj, pos_s);
            float2 uv_s = (pos_sc.xy / pos_s.z + 1) * 0.5;
#else
            // Sampling point (disc)
            float2 v1 = RandomVectorDisc(uv, s);
            float2 uv_s = uv + v1 * _Radius / depth_o;
#endif
            // Sample linear depth at the sampling point.
            float depth_s = SampleDepth(uv_s);

            // Get the distance.
            float3 pos_s2 = ReconstructWorldPos(uv_s, depth_s, p11_22, p13_31);
            float3 v = pos_s2 - pos_o;

            // Calculate the obscurance value.
            ao += max(dot(v, norm_o) - 0.01, 0) / (dot(v, v) + 0.001);
        }

        // Calculate the final AO value.
        float falloff = 1.0 - depth_o / kFallOffDist;
        return pow(ao * _Intensity * falloff / _SampleCount, _Contrast);
    }

    half3 SeparableBlur(float2 uv, float2 delta)
    {
        half3 n0 = SampleNormal(uv);

        half2 uv1 = uv - delta * 2;
        half2 uv2 = uv - delta;
        half2 uv3 = uv + delta;
        half2 uv4 = uv + delta * 2;

        half w1 = CompareNormal(n0, SampleNormal(uv1));
        half w2 = CompareNormal(n0, SampleNormal(uv2));
        half w3 = CompareNormal(n0, SampleNormal(uv3));
        half w4 = CompareNormal(n0, SampleNormal(uv4));

        half3 s = tex2D(_MainTex, uv) * 3;
        s += tex2D(_MainTex, uv1) * w1;
        s += tex2D(_MainTex, uv2) * w2 * 2;
        s += tex2D(_MainTex, uv3) * w3 * 2;
        s += tex2D(_MainTex, uv4) * w4;

        return s / (3 + w1 + w2 *2 + w3 *2 + w4);
    }

    half4 frag_ao_combined(v2f_img i) : SV_Target
    {
        half4 src = tex2D(_MainTex, i.uv);
        half ao = CalculateObscurance(i.uv);
        return half4(CombineObscurance(src.rgb, ao), src.a);
    }

    half4 frag_ao(v2f_img i) : SV_Target
    {
        return CalculateObscurance(i.uv);
    }

    half4 frag_blur(v2f_img i) : SV_Target
    {
        float2 delta = _MainTex_TexelSize.xy * _BlurVector;
        return half4(SeparableBlur(i.uv, delta), 0);
    }

    half4 frag_combine(v2f_img i) : SV_Target
    {
        half4 src = tex2D(_MainTex, i.uv);
        half ao = tex2D(_AOTex, i.uv);
        return half4(CombineObscurance(src.rgb, ao), src.a);
    }

    ENDCG
    SubShader
    {
        Pass
        {
            ZTest Always Cull Off ZWrite Off
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag_ao_combined
            #pragma target 3.0
            ENDCG
        }
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
