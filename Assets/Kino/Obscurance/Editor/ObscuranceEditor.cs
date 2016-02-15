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
using UnityEditor;

namespace Kino
{
    [CanEditMultipleObjects]
    [CustomEditor(typeof(Obscurance))]
    public class ObscuranceEditor : Editor
    {
        SerializedProperty _intensity;
        SerializedProperty _contrast;
        SerializedProperty _radius;
        SerializedProperty _samplingMethod;
        SerializedProperty _sampleCount;
        SerializedProperty _sampleCountValue;
        SerializedProperty _noiseFilter;
        SerializedProperty _downsample;

        static GUIContent _textValue = new GUIContent("Value");

        void OnEnable()
        {
            _intensity = serializedObject.FindProperty("_intensity");
            _contrast = serializedObject.FindProperty("_contrast");
            _radius = serializedObject.FindProperty("_radius");
            _samplingMethod = serializedObject.FindProperty("_samplingMethod");
            _sampleCount = serializedObject.FindProperty("_sampleCount");
            _sampleCountValue = serializedObject.FindProperty("_sampleCountValue");
            _noiseFilter = serializedObject.FindProperty("_noiseFilter");
            _downsample = serializedObject.FindProperty("_downsample");
        }

        public override void OnInspectorGUI()
        {
            serializedObject.Update();

            EditorGUILayout.PropertyField(_intensity);
            EditorGUILayout.PropertyField(_contrast);
            EditorGUILayout.PropertyField(_radius);

            EditorGUILayout.PropertyField(_samplingMethod);
            EditorGUILayout.PropertyField(_sampleCount);

            if (_sampleCount.hasMultipleDifferentValues ||
                _sampleCount.enumValueIndex == (int)Obscurance.SampleCount.Variable)
            {
                EditorGUI.indentLevel++;
                EditorGUILayout.PropertyField(_sampleCountValue, _textValue);
                EditorGUI.indentLevel--;
            }

            EditorGUILayout.PropertyField(_noiseFilter);
            EditorGUILayout.PropertyField(_downsample);

            serializedObject.ApplyModifiedProperties();
        }
    }
}
