using UnityEngine;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine.XR.ARFoundation;
using UnityEngine.XR.ARSubsystems;

public class FaceThingRenderer : MonoBehaviour
{
    public GameObject cubePrefab;
    private Dictionary<int, RectTransform> faces = new Dictionary<int, RectTransform>();

    void ReceiveMessage(string message) {
        List<FaceData> faceData = JsonUtility.FromJson<List<FaceData>>(message);        
        HashSet<int> detectedFaceIds = new HashSet<int>();

        foreach (FaceData face in faceData) {
            UpdateOrCreateCube(face.faceId, face.x, face.y, face.width, face.height);
            detectedFaceIds.Add(face.faceId);
        }

        // if (cubeRectTransform != null)
        // {
        //     float cubeSize = faceData.width * cubeSizeFactor;
        //     Vector2 position = new Vector2(
        //         faceData.x + faceData.width / 2,
        //         faceData.y + faceData.height * verticalOffsetFactor + cubeSize / 2
        //     );
        //     cubeRectTransform.anchoredPosition = position;
        //
        //     cubeRectTransform.sizeDelta = new Vector2(cubeSize, cubeSize);
        //
        //
        //     cubeRectTransform.rotation = Quaternion.Euler(faceData.rotationX, faceData.rotationY, faceData.rotationZ);
        //
        //     cubeRectTransform.gameObject.SetActive(true);
        // }

        List<int> cubesToRemove = new List<int>();
        foreach (var kvp in faces)
        {
            if (!detectedFaceIds.Contains(kvp.Key))
            {
                Destroy(kvp.Value.gameObject);
                cubesToRemove.Add(kvp.Key);
            }
        }
        foreach (int id in cubesToRemove)
        {
            faces.Remove(id);
        }
    }

    void UpdateOrCreateCube(int faceId, float x, float y, float width, float height)
    {
        RectTransform cubeTransform;
        if (!faces.TryGetValue(faceId, out cubeTransform))
        {
            GameObject cubeObject = Instantiate(cubePrefab, transform);
            cubeTransform = cubeObject.GetComponent<RectTransform>();
            if (cubeTransform == null)
            {
                Debug.LogError("Cube prefab must have a RectTransform component!");
                return;
            }
            faces[faceId] = cubeTransform;
        }

        float cubeSize = width * 0.5f;
        float cubeX = x + (width * 0.5f);
        float cubeY = y + height + (cubeSize * 0.5f);

        cubeTransform.position = new Vector3(cubeX, cubeY, 0);
        cubeTransform.sizeDelta = new Vector2(cubeSize, cubeSize);
        cubeTransform.gameObject.SetActive(true);
    }
}
