using System.Collections;
using System.Collections.Generic;
// 修改后的完整DropController.cs
using UnityEngine;

public class DropController : MonoBehaviour {
    public Material drawMaterial; // 必须包含_ClickPos/_MainColor/_DropRadius参数
    public Camera paintCamera;
    [Range(0.01f, 0.5f)] public float dropRadius = 0.1f;
    public Color currentColor = Color.red;

    private RenderTexture _renderTexture;
    private Vector2 _lastClickUV;

    void Start() {
        CreateRenderTexture();
        InitializeMaterial();
    }

    void CreateRenderTexture() {
        _renderTexture = new RenderTexture(Screen.width, Screen.height, 0, RenderTextureFormat.ARGB32) {
            wrapMode = TextureWrapMode.Clamp,
            filterMode = FilterMode.Bilinear
        };
        paintCamera.targetTexture = _renderTexture;
        drawMaterial.SetTexture("_MainTex", _renderTexture);
    }

    void InitializeMaterial() {
        drawMaterial.SetColor("_MainColor", currentColor);
        drawMaterial.SetFloat("_DropRadius", dropRadius);
    }

    void Update() {
        if (Input.GetMouseButton(0)) { // 改为持续检测
            var mousePos = Input.mousePosition;
            mousePos.z = paintCamera.nearClipPlane + 0.1f; // 确保在近平面上
            var worldPos = paintCamera.ScreenToWorldPoint(mousePos);
            
            if (Physics.Raycast(worldPos, paintCamera.transform.forward, out var hit)) {
                UpdateShaderParameters(hit.textureCoord);
                ExecuteGPUOperations();
            }
        }
    }

    void UpdateShaderParameters(Vector2 uv) {
        // 关键修正：使用正确的UV坐标系
        var correctedUV = new Vector2(uv.x, 1 - uv.y); // 翻转Y轴
        drawMaterial.SetVector("_ClickPos", new Vector4(correctedUV.x, correctedUV.y, 0, 0));
        drawMaterial.SetFloat("_DropRadius", dropRadius);
    }

    void ExecuteGPUOperations() {
        // 使用双缓冲技术保留绘制痕迹
        RenderTexture temp = RenderTexture.GetTemporary(_renderTexture.width, _renderTexture.height, 0);
        Graphics.Blit(_renderTexture, temp); // 先复制当前状态
        Graphics.Blit(temp, _renderTexture, drawMaterial); // 应用材质效果
        RenderTexture.ReleaseTemporary(temp);
    }

    public void OnColorSelected(Color newColor) {
        currentColor = newColor;
        drawMaterial.SetColor("_MainColor", currentColor);
    }
}
