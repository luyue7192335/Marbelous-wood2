using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using System.IO;
using System;

public class export : MonoBehaviour
{
    public RawImage[] rawImageSources; // 绑定四个变体图像
    public RawImage hiddenRawImageForPlane; // 用于Plane截图的隐藏图像
    public Material planeMaterial; // Plane使用的材质
    public int textureWidth = 512;
    public int textureHeight = 512;

    public void ExportByIndex(int index)
    {
        if (index < 0 || index >= rawImageSources.Length)
        {
            Debug.LogError("Index out of range.");
            return;
        }

        RenderTexture rt = rawImageSources[index].texture as RenderTexture;
        if (rt == null)
        {
            Debug.LogError("RawImage doesn't have a RenderTexture.");
            return;
        }

        ExportRenderTexture(rt, $"variant_{index}.png");
    }

    public void ExportPlaneTexture()
    {
        // 1. 新建 RT 并渲染 Plane 的材质
        RenderTexture rt = new RenderTexture(textureWidth, textureHeight, 24);
        Graphics.Blit(null, rt, planeMaterial);

        // 2. 给隐藏的 RawImage 赋值（可选调试）
        if (hiddenRawImageForPlane != null)
        {
            hiddenRawImageForPlane.texture = rt;
        }

        GL.Flush();

        // 3. 导出
        ExportRenderTexture(rt, "main_plane.png");
    }

    private void ExportRenderTexture(RenderTexture rt, string fileName)
    {
        RenderTexture currentActiveRT = RenderTexture.active;
        RenderTexture.active = rt;

        Texture2D tex2D = new Texture2D(rt.width, rt.height, TextureFormat.RGB24, false);
        tex2D.ReadPixels(new Rect(0, 0, rt.width, rt.height), 0, 0);
        tex2D.Apply();

        RenderTexture.active = currentActiveRT;

        byte[] bytes = tex2D.EncodeToPNG();

    #if UNITY_WEBGL && !UNITY_EDITOR
        // ✅ WebGL 版本：使用Base64 + 弹出下载
        string base64Image = Convert.ToBase64String(bytes);
        Application.ExternalEval(@"
            var a = document.createElement('a');
            a.href = 'data:image/png;base64," + base64Image + @"';
            a.download = '" + fileName + @"';
            a.click();
        ");
    #else
        // ✅ 桌面版：直接保存到桌面
        string desktopPath = System.Environment.GetFolderPath(System.Environment.SpecialFolder.Desktop);
        string path = Path.Combine(desktopPath, fileName);
        File.WriteAllBytes(path, bytes);
        Debug.Log("Saved to Desktop: " + path);
    #endif
    }

}
