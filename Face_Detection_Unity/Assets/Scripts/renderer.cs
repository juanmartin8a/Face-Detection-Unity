using UnityEngine;

public class Renderer : MonoBehaviour
{
    void ReceiveMessage(string message) {
        Debug.Log("message recieved: " + message);
    }
}
