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
        SerializedProperty _sampleRadius;
        SerializedProperty _fallOffDistance;
        SerializedProperty _sampleQuality;
        SerializedProperty _sampleCount;

        void OnEnable()
        {
            _intensity = serializedObject.FindProperty("_intensity");
            _sampleRadius = serializedObject.FindProperty("_sampleRadius");
            _fallOffDistance = serializedObject.FindProperty("_fallOffDistance");
            _sampleQuality = serializedObject.FindProperty("_sampleQuality");
            _sampleCount = serializedObject.FindProperty("_sampleCount");
        }

        public override void OnInspectorGUI()
        {
            serializedObject.Update();

            EditorGUILayout.PropertyField(_intensity);
            EditorGUILayout.PropertyField(_sampleRadius);
            EditorGUILayout.PropertyField(_fallOffDistance);
            EditorGUILayout.PropertyField(_sampleQuality);

            if (_sampleQuality.hasMultipleDifferentValues ||
                _sampleQuality.enumValueIndex == (int)Obscurance.SampleQuality.Variable)
                EditorGUILayout.PropertyField(_sampleCount);

            serializedObject.ApplyModifiedProperties();
        }
    }
}
