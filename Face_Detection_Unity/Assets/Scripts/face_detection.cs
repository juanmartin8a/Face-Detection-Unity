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

    public int? ppImageWidth { get; private set; }
    public int? ppImageHeight { get; private set; }

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

                float displayAspect = (float)Screen.width / Screen.height;
                float imageAspect = (float)image.width / image.height;

                int croppedWidth, croppedHeight;
                int xOffset = 0, yOffset = 0;
                int outWidth, outHeight;


                // var conversionParams0 = new XRCpuImage.ConversionParams
                // {
                //     inputRect = new RectInt(0, 0, image.width, image.height),
                //     outputDimensions = new Vector2Int(image.width, image.height),
                //     outputFormat = TextureFormat.RGBA32,
                //     transformation = XRCpuImage.Transformation.None
                // };
                //
                // int size0 = image.GetConvertedDataSize(conversionParams0);
                // var buffer0 = new NativeArray<byte>(size0, Allocator.Temp);
                //
                // image.Convert(conversionParams0, new IntPtr(buffer0.GetUnsafePtr()), buffer0.Length);
                // 
                // SaveImage2(buffer0, image.width, image.height);

                if (displayAspect > imageAspect)
                {
                    croppedWidth = image.width;
                    croppedHeight = Mathf.RoundToInt(croppedWidth / displayAspect);
                    yOffset = (image.height - croppedHeight) / 2;
                    if (croppedWidth > 1080) {
                        outWidth = 1080;
                        outHeight = Mathf.RoundToInt((float)outWidth / croppedWidth * croppedHeight);
                    } else {
                        outWidth = croppedWidth;
                        outHeight = croppedHeight;
                    }
                }
                else
                {
                    croppedHeight = image.height;
                    croppedWidth = Mathf.RoundToInt(croppedHeight * displayAspect);
                    xOffset = (image.width - croppedWidth) / 2;
                    if (croppedHeight > 1080) {
                        outHeight = 1080;
                        outWidth = Mathf.RoundToInt((float)outHeight / croppedHeight * croppedWidth);
                    } else {
                        outHeight = croppedHeight;
                        outWidth = croppedWidth;
                    }

                }

                if (!ppImageHeight.HasValue || !ppImageHeight.HasValue) {
                    ppImageWidth = outWidth;
                    ppImageHeight = outHeight;
                }

                var conversionParams = new XRCpuImage.ConversionParams
                {
                    // inputRect = new RectInt(0, 0, image.width, image.height),
                    inputRect = new RectInt(xOffset, yOffset, croppedWidth, croppedHeight),
                    outputDimensions = new Vector2Int(outWidth, outHeight),
                    outputFormat = TextureFormat.BGRA32,
                    transformation = XRCpuImage.Transformation.None
                };

                int size = image.GetConvertedDataSize(conversionParams);
                var buffer = new NativeArray<byte>(size, Allocator.Temp);

                Debug.Log($"AR Camera Resolution 2: {croppedWidth}x{croppedHeight}");
                Debug.Log($"AR Camera Resolution 3: {outWidth}x{outHeight}");

                try
                {
                    image.Convert(conversionParams, new IntPtr(buffer.GetUnsafePtr()), buffer.Length);
                    void* ptr = NativeArrayUnsafeUtility.GetUnsafePtr(buffer);
                    double timestamp = (double)image.timestamp;
                    SaveImage(buffer, conversionParams.outputDimensions.x, conversionParams.outputDimensions.y);
                    // Log bytes per row
            int bytesPerRow = image.width * 4;
            Debug.Log($"Bytes per row (Unity): {bytesPerRow}");

            // Log a portion of the image data for verification
            byte[] imageData = buffer.ToArray();
            Debug.Log($"Image data (Unity): {BitConverter.ToString(imageData, 0, Math.Min(imageData.Length, 100))}");
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

    private void SaveImage(NativeArray<byte> imageData, int width, int height) {
    Texture2D tex = new Texture2D(width, height, TextureFormat.RGBA32, false);
    tex.LoadRawTextureData(imageData);
    tex.Apply();

    byte[] pngData = tex.EncodeToPNG();
    string filename = $"UnityFrame_{System.DateTime.Now:yyyyMMdd_HHmmss}.png";
    System.IO.File.WriteAllBytes(Application.persistentDataPath + "/" + filename, pngData);
    Debug.Log($"Saved image: {Application.persistentDataPath}/{filename}");

    Destroy(tex);
}
    private void SaveImage2(NativeArray<byte> imageData, int width, int height) {
    Texture2D tex = new Texture2D(width, height, TextureFormat.RGBA32, false);
    tex.LoadRawTextureData(imageData);
    tex.Apply();

    byte[] pngData = tex.EncodeToPNG();
    string filename = $"UnityFrame2_{System.DateTime.Now:yyyyMMdd_HHmmss}.png";
    System.IO.File.WriteAllBytes(Application.persistentDataPath + "/" + filename, pngData);
    Debug.Log($"Saved image 2: {Application.persistentDataPath}/{filename}");

    Destroy(tex);
}

}
