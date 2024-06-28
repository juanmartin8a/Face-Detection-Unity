using UnityEngine;
using UnityEngine.XR.ARFoundation;
using UnityEngine.XR.ARSubsystems;
using System.Runtime.InteropServices;
using Unity.Collections;
using Unity.Collections.LowLevel.Unsafe;
using System;

public class FaceDetection : MonoBehaviour
{
    private ARCameraManager cameraManager;
    private Texture2D cameraTexture;

    [DllImport("__Internal")]
    private static extern void InitializeFaceDetector();

    [DllImport("__Internal")]
    private static extern void DetectFaces(IntPtr imgBytes, int width, int height, double timestamp);

    private bool isLoading = false;

    void Awake()
    {
        cameraManager = GetComponent<ARCameraManager>();
        if (cameraManager == null)
        {
            Debug.LogError("ARCameraManager component not found on GameObject in Awake.");
            return;
        }
    }

    void Start()
    {
        Debug.Log("Unity: FaceDetector initialization initialized");
        if (cameraManager == null)
        {
            Debug.LogError("ARCameraManager component not found on GameObject in Start.");
            return;
        }
        InitializeFaceDetector();
        Debug.Log("Unity: FaceDetector initialized");
    }

    void OnEnable()
    {
        Debug.Log("OnEnable called in FaceDetectionController");
        if (cameraManager != null)
        {
            cameraManager.frameReceived += OnCameraFrameReceived;
        }
        else
        {
            Debug.LogError("ARCameraManager is null in OnEnable.");
        }
    }

    void OnDisable()
    {
        Debug.Log("OnDisable called in FaceDetectionController");
        if (cameraManager != null)
        {
            cameraManager.frameReceived -= OnCameraFrameReceived;
        }
        else
        {
            Debug.LogError("ARCameraManager is null in OnDisable.");
        }
    }

    unsafe void OnCameraFrameReceived(ARCameraFrameEventArgs eventArgs)
    {
        if (isLoading)
            return;

        isLoading = true;

        if (cameraManager.TryAcquireLatestCpuImage(out XRCpuImage image))
        {
            using (image)
            {

                Debug.Log($"AR Camera Resolution: {image.width}x{image.height}");

                float displayAspect = (float)Screen.width / Screen.height;
                float imageAspect = (float)image.width / image.height;

                int croppedWidth, croppedHeight;
                int xOffset = 0, yOffset = 0;

                if (displayAspect > imageAspect)
                {
                    croppedWidth = image.width;
                    croppedHeight = Mathf.RoundToInt(croppedWidth / displayAspect);
                    yOffset = (image.height - croppedHeight) / 2;
                }
                else
                {
                    croppedHeight = image.height;
                    croppedWidth = Mathf.RoundToInt(croppedHeight * displayAspect);
                    xOffset = (image.width - croppedWidth) / 2;
                }


                var conversionParams = new XRCpuImage.ConversionParams
                {
                    // inputRect = new RectInt(0, 0, image.width, image.height),
                    inputRect = new RectInt(xOffset, yOffset, croppedWidth, croppedHeight),
                    outputDimensions = new Vector2Int(croppedWidth, croppedHeight),
                    outputFormat = TextureFormat.RGBA32,
                    transformation = XRCpuImage.Transformation.None
                };

                int size = image.GetConvertedDataSize(conversionParams);
                var buffer = new NativeArray<byte>(size, Allocator.Temp);

                Debug.Log($"AR Camera Resolution 2: {croppedWidth}x{croppedHeight}");

                try
                {
                    image.Convert(conversionParams, new IntPtr(buffer.GetUnsafePtr()), buffer.Length);
                    void* ptr = NativeArrayUnsafeUtility.GetUnsafePtr(buffer);
                    double timestamp = (double)image.timestamp;
                    DetectFaces((IntPtr)ptr, conversionParams.outputDimensions.x, conversionParams.outputDimensions.y, timestamp);
                }
                finally
                {
                    buffer.Dispose();
                    isLoading = false;
                }
            }
        }
    }

}