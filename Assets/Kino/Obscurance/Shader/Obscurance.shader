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
        _MainTex("-", 2D) = "" {}
    }
    CGINCLUDE

    #include "UnityCG.cginc"

    #pragma multi_compile _ _COUNT_LOW _COUNT_MEDIUM
    #pragma multi_compile _METHOD_DISC _METHOD_SPHERE

    sampler2D _MainTex;
    float2 _MainTex_TexelSize;

    sampler2D _CameraDepthNormalsTexture;

    float _Intensity;
    float _Contrast;
    float _Radius;

    static const float kFallOffDist = 100;

    #if _COUNT_LOW
    static const int _SampleCount = 8;
    #elif _COUNT_MEDIUM
    static const int _SampleCount = 16;
    #else
    int _SampleCount; // given as a uniform
    #endif

    float UVRandom(float2 uv, float dx, float dy)
    {
        uv += float2(dx, dy + _Time.x);
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

    half4 frag_ao(v2f_img i) : SV_Target
    {
        // Source color
        half4 src = tex2D(_MainTex, i.uv);

        // Parameters used for coordinate conversion
        float3x3 proj = (float3x3)unity_CameraProjection;
        float2 p11_22 = float2(unity_CameraProjection._11, unity_CameraProjection._22);
        float2 p13_31 = float2(unity_CameraProjection._13, unity_CameraProjection._23);

        // View space normal and depth
        float3 norm_o;
        float depth_o = SampleDepthNormal(i.uv, norm_o);

        // Early-out case
        if (depth_o > kFallOffDist) return src;

        // Reconstruct the view-space position.
        float3 pos_o = ReconstructWorldPos(i.uv, depth_o, p11_22, p13_31);

        float ao = 0.0;
        for (int s = 0; s < _SampleCount; s++)
        {
#if _METHOD_SPHERE
            // Sampling point (sphere)
            float3 v1 = RandomVectorSphere(i.uv, s);
            v1 = faceforward(v1, -norm_o, v1);
            float3 pos_s = pos_o + v1 * _Radius;

            // Re-project the sampling point
            float3 pos_sc = mul(proj, pos_s);
            float2 uv_s = (pos_sc.xy / pos_s.z + 1) * 0.5;
#else
            // Sampling point (disc)
            float2 v1 = RandomVectorDisc(i.uv, s);
            float2 uv_s = i.uv + v1 * _Radius / depth_o;
#endif
            // Sample linear depth at the sampling point.
            float depth_s = SampleDepth(uv_s);

            // Get the distance.
            float3 pos_s2 = ReconstructWorldPos(uv_s, depth_s, p11_22, p13_31);
            float3 v = pos_s2 - pos_o;

            // Calculate the obscurance value.
            ao += max(dot(v, norm_o) - 0.1, 0) / (dot(v, v) + 0.01);
        }

        // Calculate the final AO value.
        float falloff = 1.0 - depth_o / kFallOffDist;
        ao = pow(ao / _SampleCount, _Contrast) * _Intensity * falloff;

        // Apply the AO.
        return half4(lerp(src.rgb, (half3)0.0, ao), src.a);
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
    }
}
