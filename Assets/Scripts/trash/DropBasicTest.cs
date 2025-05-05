using UnityEngine;
using System.Collections.Generic;
using System.Linq; 
using UnityEngine.UI;
using TMPro;


public class DropBasicTest : MonoBehaviour
{
        public Material drawMaterial;  // **用于绘制的 Shader Material**
    
        [System.Serializable]
        public class DropPoint 
        {
        // 定义一个Vector2类型的uvPosition变量，用于存储点的UV坐标
        public Vector2 uvPosition;
        // 定义一个Color类型的color变量，用于存储点的颜色
        public Color color;
        // 定义一个float类型的radius变量，用于存储点的半径
        public float radius;
        }
    
    public List<DropPoint> allDrops = new List<DropPoint>();
    public int maxDrops = 100; // 最大保存点数

    private Color selectedColor = Color.blue;
    private float dropRadius = 0.1f;

    [Header("UI Controls")]
    [SerializeField] private GameObject toolsPanel; // 工具面板
    [SerializeField] private Button basicDropButton; // 基础工具按钮
    [SerializeField] private Slider sizeSlider; // 尺寸滑块
    [SerializeField] private TMP_Text sizeText; // 尺寸显示文本

    private bool isBasicDropActive = false;

    void Start()
    {
        toolsPanel.SetActive(false);
        UpdateSizeDisplay();

        // 绑定按钮事件
        basicDropButton.onClick.AddListener(ActivateBasicDropTool);
        sizeSlider.onValueChanged.AddListener(OnSizeSliderChanged);
    }

    void Update()
    {
        if (isBasicDropActive && Input.GetMouseButtonDown(0))
        {
        if (Input.GetMouseButtonDown(0))
        {
            Ray ray = Camera.main.ScreenPointToRay(Input.mousePosition);
            RaycastHit hit;

            if (Physics.Raycast(ray, out hit))
            {
                MeshCollider meshCollider = hit.collider.GetComponent<MeshCollider>();
                if (meshCollider == null)
                {
                    Debug.Log("❌ No MeshCollider found on " + hit.collider.gameObject.name);
                    return;
                }

                Vector2 pixelUV = hit.textureCoord;

                
                if (!IsValidUV(pixelUV)) 
                    {
                        Debug.LogWarning($"❌ Invalid UV: {pixelUV}");
                        return;
                    }

                    AddNewDropPoint(pixelUV);
                    Debug.Log($"✅ Added Drop: {pixelUV}");
            }
        }
        }
    }
    bool IsValidUV(Vector2 uv)
    {
        return !float.IsNaN(uv.x) && !float.IsNaN(uv.y) 
            && uv.x >= 0 && uv.x <= 1 
            && uv.y >= 0 && uv.y <= 1;
    }

    void AddNewDropPoint(Vector2 uv)
    {
        // 创建新数据点
        var newDrop = new DropPoint{
            uvPosition = uv,
            color = selectedColor,
            radius = dropRadius
        };

        // 管理列表长度
        if(allDrops.Count >= maxDrops) allDrops.RemoveAt(0);
        allDrops.Add(newDrop);

        UpdateShaderData();
    }

    public void ToggleToolsPanel()
    {
        toolsPanel.SetActive(!toolsPanel.activeSelf);
    }

    private void ActivateBasicDropTool()
    {
        isBasicDropActive = true;
        // 这里可以添加其他工具的关闭逻辑
    }

    private void OnSizeSliderChanged(float value)
    {
        dropRadius = value;
        UpdateSizeDisplay();
    }
    private void UpdateSizeDisplay()
    {
        sizeText.text = $"Size: {dropRadius:0.00}";
    }

    // 设置选中的颜色
    public void SetSelectedColor(Color newColor)
    {
        selectedColor = newColor;
    }

     public void ClearAllDrops()
    {
        allDrops.Clear();  // **清空点的列表**
        UpdateShaderData();  // **更新 Shader**
        //ClearRenderTexture();  // **重置 Texture**
    }

    void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        UpdateShaderData();
        Graphics.Blit(src, dest, drawMaterial);
    }

     void UpdateShaderData()
    {
         Vector4[] positions = new Vector4[maxDrops];
        Color[] colors = new Color[maxDrops];
        float[] radii = new float[maxDrops];

        for(int i = 0; i < maxDrops; i++)
        {
            if (i < allDrops.Count) 
            {
                positions[i] = new Vector4(
                    allDrops[i].uvPosition.x, 
                    //1 - allDrops[i].uvPosition.y, // **UV 可能需要翻转**
                    allDrops[i].uvPosition.y,
                    0, 
                    0
                );
                colors[i] = allDrops[i].color;
                radii[i] = allDrops[i].radius;
            }
            else 
            {
                // **如果没有这么多滴落点，填充默认值**
                positions[i] = new Vector4(-1, -1, 0, 0);
                colors[i] = Color.clear;
                radii[i] = 0;
            }
        }
        
        // 传递数组到Shader
        drawMaterial.SetInt("_DropCount", allDrops.Count);
        drawMaterial.SetVectorArray("_AllClickPos", positions);
        drawMaterial.SetColorArray("_AllColors", colors);
        drawMaterial.SetFloatArray("_AllRadii", radii);
    }
}
