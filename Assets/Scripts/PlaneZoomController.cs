using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class PlaneZoomController : MonoBehaviour
{
    public Transform planeTransform;    // 绑定你的Plane
    public float zoomFactor = 2.0f;     // 每次放大的倍率
    public float zoomDuration = 0.3f;   // 缩放过渡时间
    public float maxZoom = 4.0f;        // 最大缩放限制
    public float minZoom = 1.0f;        // 最小缩放限制

    private Vector3 originalPosition;
    private Vector3 originalScale;

    private Vector3 targetPosition;
    private Vector3 targetScale;

    private bool isZooming = false;
    private float zoomTimer = 0f;

    public static PlaneZoomController Instance;

    private void Awake()
    {
        Instance = this;
    }

    [Header("Zoom In Mode")]
    public bool waitingForZoomInClick = false;

    


    private void Start()
    {
        if (planeTransform == null) planeTransform = transform;

        originalPosition = planeTransform.position;
        originalScale = planeTransform.localScale;

        targetPosition = originalPosition;
        targetScale = originalScale;
    }

    private void Update()
    {
        if (isZooming)
        {
            zoomTimer += Time.deltaTime;
            float t = Mathf.Clamp01(zoomTimer / zoomDuration);

            planeTransform.position = Vector3.Lerp(planeTransform.position, targetPosition, t);
            planeTransform.localScale = Vector3.Lerp(planeTransform.localScale, targetScale, t);

            if (t >= 1f)
                isZooming = false;
            MovingScene.Instance.OnZoomInCompleted();
        }
        // if (waitingForZoomInClick && Input.GetMouseButtonDown(0))
        // {
        //     Ray ray = Camera.main.ScreenPointToRay(Input.mousePosition);
        //     RaycastHit hit;
        //     if (Physics.Raycast(ray, out hit))
        //     {
        //         Vector2 pixelUV = hit.textureCoord;
        //         OnPlaneClicked(pixelUV);
        //     }
        // }
    }

    public bool TryZoomIn(Vector2 uv)
{
    if (!waitingForZoomInClick)
        return false;

    ZoomInAt(uv);
    waitingForZoomInClick = false;

    return true; // ✅ 说明吃掉了这次点击
}


    /// <summary>
    /// 进入Zoom In模式（按钮调用）
    /// </summary>
    public void EnterZoomInMode()
    {
        waitingForZoomInClick = true;
        Debug.Log("Zoom In Mode Activated, click plane to zoom in.");
    }

    /// <summary>
    /// 判断是否是Zoom模式（供其他脚本判断用）
    /// </summary>
    public bool IsZoomMode()
    {
        return waitingForZoomInClick;
    }

    /// <summary>
    /// 点击Plane时调用
    /// </summary>
    public void OnPlaneClicked(Vector2 uv)
    {
        if (!waitingForZoomInClick)
            return;

        ZoomInAt(uv);
        waitingForZoomInClick = false;
    }

    /// <summary>
    /// Zoom In (根据UV点计算目标位置和缩放)
    /// </summary>
    public void ZoomInAt(Vector2 uv)
    {
        Vector3 worldPoint = UVToWorld(uv);

        Vector3 currentScale = planeTransform.localScale;
        Vector3 newScale = currentScale * zoomFactor;

        // 限制最大缩放
        if (newScale.x > originalScale.x * maxZoom)
            newScale = originalScale * maxZoom;

        Vector3 offset = 1*(planeTransform.position - worldPoint);
        Vector3 newPosition = worldPoint + 2*offset / zoomFactor;

        targetScale = newScale;
        targetPosition = newPosition;
        zoomTimer = 0f;
        isZooming = true;
    }

    /// <summary>
    /// Zoom Out (按钮调用)
    /// </summary>
    public void ZoomOut()
    {
        targetScale = originalScale;
        targetPosition = originalPosition;
        zoomTimer = 0f;
        isZooming = true;
    }

    /// <summary>
    /// UV -> 世界坐标
    /// </summary>
    private Vector3 UVToWorld(Vector2 uv)
    {
        Renderer renderer = planeTransform.GetComponent<Renderer>();
        if (renderer == null)
            return planeTransform.position;

        Bounds bounds = renderer.bounds;
        Vector3 min = bounds.min;
        Vector3 size = bounds.size;

        Vector3 local = new Vector3(uv.x * size.x, uv.y * size.y, size.z * 0.5f);
        return min + local;
    }
}
