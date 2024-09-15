using UnityEngine;
using System.Collections.Generic;
using Newtonsoft.Json;

public class FaceThingRenderer : MonoBehaviour
{
    public GameObject cubePrefab;
    private Dictionary<int, GameObject> faces = new Dictionary<int, GameObject>();
    private HashSet<int> detectedFaceIds = new HashSet<int>();
    private List<int> cubesToRemove = new List<int>();
    private FacesData facesData = new FacesData();

    void ReceiveMessage(string message) {

        detectedFaceIds.Clear();

        if (message != "[]") {
            try
            {
                facesData = JsonConvert.DeserializeObject<FacesData>(message);
                foreach (FaceData face in facesData.faces)
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
        cubesToRemove.Clear();
    }

    void UpdateOrCreateCube(int trackingId, float x, float y, float width, float height)
    {
        GameObject cube;

        if (!faces.ContainsKey(trackingId))
        {
            cube = Instantiate(cubePrefab);
            faces[trackingId] = cube;
        }
        else
        {
            cube = faces[trackingId];
        }

        float centerX = x + width / 2f;
        float centerY = y + height / 2f;

        float viewportX = centerX / (float)facesData.imageWidth;
        float viewportY = 1.0f - (centerY / (float)facesData.imageHeight); // Invert Y-axis for Unity's coordinate system

        Ray ray = Camera.main.ViewportPointToRay(new Vector3(viewportX, viewportY, 0));

        float estimatedDepth = 500f / width;

        Vector3 position = ray.GetPoint(estimatedDepth);

        cube.transform.position = position;
    }
}
