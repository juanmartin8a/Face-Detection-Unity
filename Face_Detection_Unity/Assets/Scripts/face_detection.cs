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

    private System.Diagnostics.Stopwatch stopwatch;
    private int frameCount = 0;
    private float fps = 0.0f;
    
    private int processingFrameCount = 0;
    private float processedFps = 0.0f;

    void Awake()
    {
        cameraManager = GetComponent<ARCameraManager>();
        if (cameraManager == null)
        {
            Debug.LogError("ARCameraManager component not found on GameObject in Awake.");
            return;
        }
        stopwatch = new System.Diagnostics.Stopwatch();
        stopwatch.Start();
    }

    void Start()
    {
        UnityEngine.Debug.Log("Unity: FaceDetector initialization initialized");
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
        frameCount++;

        if (isLoading)
            return;

        isLoading = true;

        if (cameraManager.TryAcquireLatestCpuImage(out XRCpuImage image))
        {
            using (image)
            {
                UnityEngine.Debug.Log($"AR Camera Resolution: {image.width}x{image.height}");

                var conversionParams = new XRCpuImage.ConversionParams
                {
                    inputRect = new RectInt(0, 0, image.width, image.height),
                    outputDimensions = new Vector2Int(image.width, image.height),
                    outputFormat = TextureFormat.BGRA32,
                    transformation = XRCpuImage.Transformation.None
                };

                int size = image.GetConvertedDataSize(conversionParams);
                var buffer = new NativeArray<byte>(size, Allocator.Temp);

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
        processingFrameCount++;

        long timePassed = stopwatch.ElapsedMilliseconds;
        if (timePassed >= 1000)
        {
            // Calculate FPS
            fps = frameCount / (timePassed / 1000.0f);
            frameCount = 0;

            processedFps = processingFrameCount / (timePassed / 1000.0f);
            processingFrameCount = 0;

            stopwatch.Restart();

            // Log FPS
            Debug.Log($"FPS: {fps}");
            Debug.Log($"FPS 2: {processedFps}");
        }
    }
}
