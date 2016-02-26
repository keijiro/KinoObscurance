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
            get { return Mathf.Max(_radius, 1e-5f); }
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
            get { return Mathf.Clamp(_sampleCountValue, 1, 120); }
            set { _sampleCountValue = value; }
        }

        [SerializeField]
        int _sampleCountValue = 20;

        /// Noise filter
        public int noiseFilter {
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

        // ao shader
        Shader aoShader {
            get {
                // not using the reference value _aoShader
                // because it's not prepared on object initialization.
                return Shader.Find("Hidden/Kino/Obscurance");
            }
        }

        [SerializeField] Shader _aoShader;

        // material for the ao shader
        Material aoMaterial {
            get {
                if (_aoMaterial == null) {
                    _aoMaterial = new Material(aoShader);
                    _aoMaterial.hideFlags = HideFlags.DontSave;
                }
                return _aoMaterial;
            }
        }

        Material _aoMaterial;

        #endregion

        #region Private methods

        RenderTexture GetTemporaryBuffer(int width, int height)
        {
            return RenderTexture.GetTemporary
                (width, height, 0, RenderTextureFormat.R8);
        }

        void ReleaseTemporaryBuffer(RenderTexture rt)
        {
            RenderTexture.ReleaseTemporary(rt);
        }

        void UpdateMaterialProperties()
        {
            var m = aoMaterial;
            m.shaderKeywords = null;

            // common properties
            m.SetFloat("_Intensity", intensity);
            m.SetFloat("_Contrast", 0.6f);
            m.SetFloat("_Radius", radius);
            m.SetFloat("_DepthFallOff", 100);
            m.SetFloat("_TargetScale", downsampling ? 0.5f : 1);

            // ao method
            if (estimatorType == EstimatorType.DistanceBased)
                m.EnableKeyword("_METHOD_DISTANCE");

            // sample count
            if (sampleCount == SampleCount.Low)
                m.EnableKeyword("_COUNT_LOW");
            else if (sampleCount == SampleCount.Medium)
                m.EnableKeyword("_COUNT_MEDIUM");
            else
                m.SetInt("_SampleCount", sampleCountValue);
        }

        #endregion

        #region MonoBehaviour Functions

        void OnEnable()
        {
            var camera = GetComponent<Camera>();
            camera.depthTextureMode = DepthTextureMode.DepthNormals;
        }

        void OnDisable()
        {
            if (_aoMaterial != null)
                DestroyImmediate(_aoMaterial);

            _aoMaterial = null;
        }

        [ImageEffectOpaque]
        void OnRenderImage(RenderTexture source, RenderTexture destination)
        {
            UpdateMaterialProperties();

            var tw = source.width;
            var th = source.height;

            if (downsampling) {
                tw /= 2;
                th /= 2;
            }

            var m = aoMaterial;
            var rtMask = GetTemporaryBuffer(tw, th);

            // estimate ao
            Graphics.Blit(null, rtMask, m, 0);

            if (noiseFilter > 0)
            {
                var rtBlur = GetTemporaryBuffer(tw, th);

                // geometry-aware blur
                for (var i = 0; i < noiseFilter; i++)
                {
                    m.SetVector("_BlurVector", Vector2.right);
                    Graphics.Blit(rtMask, rtBlur, m, 1);

                    m.SetVector("_BlurVector", Vector2.up);
                    Graphics.Blit(rtBlur, rtMask, m, 1);
                }

                ReleaseTemporaryBuffer(rtBlur);
            }

            // combine ao
            m.SetTexture("_ObscuranceTexture", rtMask);
            Graphics.Blit(source, destination, m, 2);

            ReleaseTemporaryBuffer(rtMask);
        }

        #endregion
    }
}
