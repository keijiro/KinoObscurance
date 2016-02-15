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

        [SerializeField, Range(0, 2)]
        float _intensity = 1;

        /// Obscurance contrast
        public float contrast {
            get { return _contrast; }
            set { _contrast = value; }
        }

        [SerializeField, Range(0.01f, 2)]
        float _contrast = 0.8f;

        /// Sampling radius
        public float radius {
            get { return _radius; }
            set { _radius = value; }
        }

        [SerializeField]
        float _radius = 0.5f;

        /// Sampling method
        public SamplingMethod samplingMethod {
            get { return _samplingMethod; }
            set { _samplingMethod = value; }
        }

        public enum SamplingMethod { Disc, Sphere }

        [SerializeField]
        SamplingMethod _samplingMethod = SamplingMethod.Sphere;

        /// Sample count option
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
        int _sampleCountValue = 24;

        /// Noise filter
        public float NoiseFilter {
            get { return _noiseFilter; }
            set { _noiseFilter = value; }
        }

        [SerializeField, Range(0, 1)]
        float _noiseFilter = 0;

        /// Downsampling
        public bool downsample {
            get { return _downsample; }
            set { _downsample = value; }
        }

        [SerializeField]
        bool _downsample = false;

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

            _material.SetFloat("_Intensity", _intensity);
            _material.SetFloat("_Contrast", _contrast);
            _material.SetFloat("_Radius", _radius);

            _material.shaderKeywords = null;

            if (_samplingMethod == SamplingMethod.Disc)
                _material.EnableKeyword("_METHOD_DISC");
            else
                _material.EnableKeyword("_METHOD_SPHERE");

            if (_sampleCount == SampleCount.Low)
                _material.EnableKeyword("_COUNT_LOW");
            else if (_sampleCount == SampleCount.Medium)
                _material.EnableKeyword("_COUNT_MEDIUM");
            else
                _material.SetInt("_SampleCount", _sampleCountValue);

            Graphics.Blit(source, destination, _material, 0);
        }

        #endregion
    }
}
