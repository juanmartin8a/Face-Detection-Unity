using UnityEngine;

[System.Serializable]
public struct FaceData {
    public int trackingId;
    public FaceRect rect;
    public HeadEulerAngles headEulerAngles;
}

[System.Serializable]
public struct FaceRect {
    public float x;
    public float y;
    public float width;
    public float height;
}

[System.Serializable]
public struct HeadEulerAngles {
    public float x;
    public float y;
    public float z;
}
