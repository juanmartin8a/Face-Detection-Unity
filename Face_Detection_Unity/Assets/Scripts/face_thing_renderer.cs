using UnityEngine;
using System.Collections.Generic;
using Newtonsoft.Json;

public class FaceThingRenderer : MonoBehaviour
{
    public GameObject cubePrefab;
    public FaceDetection faceDetection;
    private Dictionary<int, RectTransform> faces = new Dictionary<int, RectTransform>();
    private HashSet<int> detectedFaceIds = new HashSet<int>();
    private List<int> cubesToRemove = new List<int>();
    private List<FaceData> faceData = new List<FaceData>();

    void ReceiveMessage(string message) {
        Debug.Log($"message received: {message}");

        detectedFaceIds.Clear();
        faceData.Clear();

        if (message != "[]") {
            Debug.Log("message siiuuuu");
            try
            {
                JsonConvert.PopulateObject(message, faceData);
                foreach (FaceData face in faceData)
                {
                    UpdateOrCreateCube(face.trackingId, face.rect.x, face.rect.y, face.rect.width, face.rect.height);
                    detectedFaceIds.Add(face.trackingId);
                }
            }
            catch (JsonException e)
            {
                Debug.LogError($"Error parsing JSON: {e.Message}");
                return;
            }
        }
        Debug.Log("message noouuuuu");

        cubesToRemove.Clear();
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
            Renderer cubeRenderer = cubeObject.GetComponent<Renderer>();
            if (cubeRenderer != null)
            {
                cubeRenderer.material.color = Color.red;
            }
        }

        float cubeSize = width * 0.5f;
        float cubeX = (float)(x + (width * 0.5f)) * (float)faceDetection.ppImageWidth / Screen.width;
        float cubeY = (float)(y + height + (cubeSize * 0.5f)) * (float)faceDetection.ppImageHeight / Screen.height;

        cubeTransform.anchoredPosition = new Vector2(cubeX, cubeY);
        cubeTransform.sizeDelta = new Vector2(cubeSize, cubeSize);
        cubeTransform.gameObject.SetActive(true);
    }
}
