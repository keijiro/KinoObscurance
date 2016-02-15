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

        /// Effect intensity
        public float intensity {
            get { return _intensity; }
            set { _intensity = value; }
        }

        [SerializeField] float _intensity = 1;

        /// Sample radius
        public float sampleRadius {
            get { return _sampleRadius; }
            set { _sampleRadius = value; }
        }

        [SerializeField] float _sampleRadius = 1;

        /// Fall-off distance
        public float fallOffDistance {
            get { return _fallOffDistance; }
            set { _fallOffDistance = value; }
        }

        [SerializeField] float _fallOffDistance = 100;

        /// Sampling quality
        public SampleQuality sampleQuality {
            get { return _sampleQuality; }
            set { _sampleQuality = value; }
        }

        public enum SampleQuality { Low, Medium, High, Variable }

        [SerializeField] SampleQuality _sampleQuality = SampleQuality.Medium;

        /// Variable sample count
        public int sampleCount {
            get { return _sampleCount; }
            set { _sampleCount = value; }
        }

        [SerializeField] int _sampleCount = 30;

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

            _material.SetFloat("_Radius", _sampleRadius);
            _material.SetFloat("_Intensity", _intensity);
            _material.SetFloat("_FallOff", _fallOffDistance);

            _material.shaderKeywords = null;

            if (_sampleQuality == SampleQuality.Low)
                _material.EnableKeyword("_SAMPLE_LOW");
            else if (_sampleQuality == SampleQuality.Medium)
                _material.EnableKeyword("_SAMPLE_MEDIUM");
            else if (_sampleQuality == SampleQuality.High)
                _material.EnableKeyword("_SAMPLE_HIGH");
            else
                _material.SetInt("_SampleCount", _sampleCount);

            Graphics.Blit(source, destination, _material, 0);
        }

        #endregion
    }
}
