using UnityEngine;

public class FrameRegulator : MonoBehaviour
{
    void Start() {
        Application.targetFrameRate = 30;
    }
}
