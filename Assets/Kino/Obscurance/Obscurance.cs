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
using UnityEngine;

namespace Kino
{
    [ExecuteInEditMode]
    [RequireComponent(typeof(Camera))]
    [AddComponentMenu("Kino Image Effects/Obscurance")]
    public class Obscurance : MonoBehaviour
    {
        #region Public Properties

        /// Obscurance intensity
        public float intensity {
            get { return _intensity; }
            set { _intensity = value; }
        }

        [SerializeField, Range(0, 4)]
        float _intensity = 1;

        /// Sampling radius
        public float radius {
            get { return _radius; }
            set { _radius = value; }
        }

        [SerializeField]
        float _radius = 0.3f;

        /// Obscurance estimator type
        public EstimatorType estimatorType {
            get { return _estimatorType; }
            set { _estimatorType = value; }
        }

        public enum EstimatorType {
            AngleBased,
            DistanceBased
        }

        [SerializeField]
        EstimatorType _estimatorType = EstimatorType.DistanceBased;

        /// Sample count options
        public SampleCount sampleCount {
            get { return _sampleCount; }
            set { _sampleCount = value; }
        }

        public enum SampleCount { Low, Medium, Variable }

        [SerializeField]
        SampleCount _sampleCount = SampleCount.Medium;

        /// Variable sample count value
        public int sampleCountValue {
            get { return _sampleCountValue; }
            set { _sampleCountValue = value; }
        }

        [SerializeField]
        int _sampleCountValue = 20;

        /// Noise filter
        public int NoiseFilter {
            get { return _noiseFilter; }
            set { _noiseFilter = value; }
        }

        [SerializeField, Range(0, 2)]
        int _noiseFilter = 2;

        /// Downsampling (half-resolution mode)
        public bool downsampling {
            get { return _downsampling; }
            set { _downsampling = value; }
        }

        [SerializeField]
        bool _downsampling = false;

        #endregion

        #region Private Resources

        [SerializeField] Shader _shader;
        Material _material;

        #endregion

        #region MonoBehaviour Functions

        void Start()
        {
            GetComponent<Camera>().depthTextureMode =
                DepthTextureMode.DepthNormals;
        }

        [ImageEffectOpaque]
        void OnRenderImage(RenderTexture source, RenderTexture destination)
        {
            if (_material == null) {
                _material = new Material(_shader);
                _material.hideFlags = HideFlags.DontSave;
            }

            // common properties
            _material.SetFloat("_Intensity", _intensity);
            _material.SetFloat("_Contrast", 0.6f);
            _material.SetFloat("_Radius", Mathf.Max(_radius, 1e-5f));
            _material.SetFloat("_DepthFallOff", 100);

            // common keywords
            _material.shaderKeywords = null;

            if (_estimatorType == EstimatorType.DistanceBased)
                _material.EnableKeyword("_METHOD_DISTANCE");

            if (_sampleCount == SampleCount.Low)
                _material.EnableKeyword("_COUNT_LOW");
            else if (_sampleCount == SampleCount.Medium)
                _material.EnableKeyword("_COUNT_MEDIUM");
            else
                _material.SetInt("_SampleCount",
                    Mathf.Clamp(_sampleCountValue, 1, 120));

            // use the combined single-pass shader when no filtering
            if (_noiseFilter == 0 && !_downsampling)
            {
                Graphics.Blit(source, destination, _material, 0);
            }
            else
            {
                var div = _downsampling ? 2 : 1;
                var tw = source.width;
                var th = source.height;
                var r8 = RenderTextureFormat.R8;

                // estimate ao
                var rtMask = RenderTexture.GetTemporary(tw / div, th / div, 0, r8);
                Graphics.Blit(source, rtMask, _material, 1);

                if (_noiseFilter == 0)
                {
                    // combine ao
                    _material.SetTexture("_MaskTex", rtMask);
                    Graphics.Blit(source, destination, _material, 2);
                }
                else
                {
                    // apply the separable blur filter
                    var rtBlur = RenderTexture.GetTemporary(tw, th, 0, r8);

                    if (_noiseFilter == 2) _material.EnableKeyword("_BLUR_5TAP");

                    _material.SetTexture("_MaskTex", rtMask);
                    _material.SetVector("_BlurVector", Vector2.right);
                    Graphics.Blit(source, rtBlur, _material, 3);

                    _material.SetTexture("_MaskTex", rtBlur);
                    _material.SetVector("_BlurVector", Vector2.up * div);
                    Graphics.Blit(source, destination, _material, 4);

                    RenderTexture.ReleaseTemporary(rtBlur);
                }

                RenderTexture.ReleaseTemporary(rtMask);
            }
        }

        #endregion
    }
}
