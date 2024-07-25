using UnityEngine;
using System.Collections.Generic;
using Newtonsoft.Json;

public class FaceThingRenderer : MonoBehaviour
{
    public GameObject cubePrefab;
    public FaceDetection faceDetection;
    private Dictionary<int, RectTransform> faces = new Dictionary<int, RectTransform>();

    void ReceiveMessage(string message) {
        Debug.Log($"message received: {message}");
        // Debug.Log("message is == []: " + message == "[]" );

        HashSet<int> detectedFaceIds = new HashSet<int>();

        if (message != "[]") {
            Debug.Log("message siiuuuu");
            List<FaceData> faceData = JsonConvert.DeserializeObject<List<FaceData>>(message);        

            foreach (FaceData face in faceData) {
                UpdateOrCreateCube(face.trackingId, face.rect.x, face.rect.y, face.rect.width, face.rect.height);
                detectedFaceIds.Add(face.trackingId);
            }
        }
        Debug.Log("message noouuuuu");

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

    void UpdateOrCreateCube(int trackingId, float x, float y, float width, float height)
    {
        RectTransform cubeTransform;
        if (!faces.TryGetValue(trackingId, out cubeTransform))
        {
            GameObject cubeObject = Instantiate(cubePrefab, transform);
            cubeTransform = cubeObject.GetComponent<RectTransform>();
            if (cubeTransform == null)
            {
                Debug.LogError("Cube prefab must have a RectTransform component!");
                return;
            }
            faces[trackingId] = cubeTransform;
        }

        float cubeSize = width * 0.5f;
        float cubeX = (float)(x + (width * 0.5f)) * (float)faceDetection.ppImageWidth / Screen.width;
        float cubeY = (float)(y + height + (cubeSize * 0.5f)) * (float)faceDetection.ppImageHeight / Screen.height;

        cubeTransform.position = new Vector3(cubeX, cubeY, 0);
        cubeTransform.sizeDelta = new Vector2(cubeSize, cubeSize);
        cubeTransform.gameObject.SetActive(true);
    }
}
