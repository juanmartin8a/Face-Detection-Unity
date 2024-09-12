using UnityEngine;
using System.Collections.Generic;
using Newtonsoft.Json;

public class FaceThingRenderer : MonoBehaviour
{
    public GameObject cubePrefab;
    private Dictionary<int, RectTransform> faces = new Dictionary<int, RectTransform>();
    private HashSet<int> detectedFaceIds = new HashSet<int>();
    private List<int> cubesToRemove = new List<int>();
    private FacesData facesData = new FacesData();

    void ReceiveMessage(string message) {
        Debug.Log($"message received: {message}");

        detectedFaceIds.Clear();

        if (message != "[]") {
            Debug.Log("message siiuuuu");
            try
            {
                facesData = JsonConvert.DeserializeObject<FacesData>(message);
                foreach (FaceData face in facesData.faces)
                {
                    UpdateOrCreateCube(face.trackingId, face.rect.x, face.rect.y, face.rect.width, face.rect.height); detectedFaceIds.Add(face.trackingId);
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
            } else {
                Debug.LogError("Cube prefab must have a renderer!");
            }
        }

        float cubeSize = width * 0.5f;
        float cubeX = (float)(x + (width * 0.5f)) * (float)facesData.imageWidth / Screen.width;
        float cubeY = (float)(y + height + (cubeSize * 0.5f)) * (float)facesData.imageHeight / Screen.height;

        cubeTransform.anchoredPosition = new Vector2(cubeX, cubeY);
        cubeTransform.localScale = new Vector2(cubeSize, cubeSize);
        cubeTransform.gameObject.SetActive(true);
        
        Vector3 worldPosition = Camera.main.ViewportToWorldPoint(new Vector3(cubeX / Screen.width, cubeY / Screen.height, 0.5f));
         Debug.DrawLine(Camera.main.transform.position, worldPosition, Color.yellow, 0.1f);
    Debug.Log($"Cube for face {trackingId} positioned at world coordinates: {worldPosition}");
    }
}
