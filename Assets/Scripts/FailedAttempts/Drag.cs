using UnityEngine;
using System.Collections.Generic;
using System.Linq; 
using UnityEngine.UI;
using TMPro;

public class Drag : MonoBehaviour
{
    public Material drawMaterial;  // **用于绘制的 Shader Material**

    public class LiquidOperation
    {
        public enum OpType { Drop = 0, Drag = 1 }
        
        public OpType operationType;
        public Vector4 data; // x,y,z,w根据类型复用
        public Color color;
         public float scale;
         

        // Drop构造器
        public LiquidOperation(Vector2 uvPos, float radius, Color color)
        {
            operationType = OpType.Drop;
            data = new Vector4(uvPos.x, uvPos.y, radius, 0);
            this.color = color;
            this.scale = radius; 
        }

        // Drag构造器
        public LiquidOperation(Vector2 startPos, Vector2 endPos, float scale)
        {
            operationType = OpType.Drag;
            data = new Vector4(startPos.x, startPos.y, endPos.x, endPos.y);
            this.scale = scale; 
        }
    }

    public List<LiquidOperation> allOperations = new List<LiquidOperation>();
    public int maxOperations = 100;

    private Color selectedColor = Color.blue;
    private float dropRadius = 0.1f;
    public float dragBrushSize = 0.1f;

    [Header("UI Controls")]
    [SerializeField] private GameObject toolsPanel;
    [SerializeField] private Button dropButton;
    [SerializeField] private Button dragButton;
    [SerializeField] private Slider sizeSlider;
    [SerializeField] private TMP_Text sizeText;

    private bool isBasicDropActive = false;
    private bool isDragActive = false;
    private bool isDragging = false;  // **新增变量：用于判断是否处于拖拽状态**
    private Vector2 dragStartUV;  // **新增变量：存储拖拽起点**

    void Start()
    {
        toolsPanel.SetActive(false);
        UpdateSizeDisplay();

        // 绑定按钮事件
        dropButton.onClick.AddListener(ActivateBasicDropTool);
        dragButton.onClick.AddListener(ActivateDragTool);
        sizeSlider.onValueChanged.AddListener(OnSizeSliderChanged);
    }

    void Update()
    {
        if (isBasicDropActive && Input.GetMouseButtonDown(0))
        {
            HandleDrop();
        }
        else if (isDragActive)
        {
            HandleDrag();
        }
    }

    void HandleDrop()
    {
        Ray ray = Camera.main.ScreenPointToRay(Input.mousePosition);
        RaycastHit hit;

        if (Physics.Raycast(ray, out hit))
        {
            MeshCollider meshCollider = hit.collider.GetComponent<MeshCollider>();
            if (meshCollider == null) return;

            Vector2 pixelUV = hit.textureCoord;
            if (!IsValidUV(pixelUV)) return;

            AddNewOperation(new LiquidOperation(pixelUV, dropRadius, selectedColor));
            Debug.Log($"✅ Drop Added at {pixelUV}");
        }
    }

    void HandleDrag()
    {
        if (Input.GetMouseButtonDown(0))
        {
            Ray ray = Camera.main.ScreenPointToRay(Input.mousePosition);
            RaycastHit hit;
            if (Physics.Raycast(ray, out hit))
            {
                dragStartUV = hit.textureCoord;
                isDragging = true;
                Debug.Log($"🔹 Drag Start: {dragStartUV}");
            }
        }
        
        if (Input.GetMouseButtonUp(0) && isDragging)
        {
            Ray ray = Camera.main.ScreenPointToRay(Input.mousePosition);
            RaycastHit hit;
            if (Physics.Raycast(ray, out hit))
            {
                Vector2 dragEndUV = hit.textureCoord;
                if (!IsValidUV(dragEndUV)) return;

                if (Vector2.Distance(dragStartUV, dragEndUV) > 0.01f)
                {
                    AddNewOperation(new LiquidOperation(dragStartUV, dragEndUV, dropRadius));
                    Debug.Log($"✅ Drag Completed from {dragStartUV} to {dragEndUV}");
                }
            }
            isDragging = false;
        }
    }

    bool IsValidUV(Vector2 uv)
    {
        return !float.IsNaN(uv.x) && !float.IsNaN(uv.y) 
            && uv.x >= 0 && uv.x <= 1 
            && uv.y >= 0 && uv.y <= 1;
    }

    void AddNewOperation(LiquidOperation operation)
    {
        // **管理列表长度**
        if (allOperations.Count >= maxOperations) allOperations.RemoveAt(0);
        allOperations.Add(operation);

        UpdateShaderData();
    }

    public void ToggleToolsPanel()
    {
        toolsPanel.SetActive(!toolsPanel.activeSelf);
    }

    private void ActivateBasicDropTool()
    {
        isBasicDropActive = true;
        isDragActive = false; // **确保只激活一个工具**
    }

    public void ActivateDragTool()
    {
        isBasicDropActive = false;
        isDragActive = true;
        Debug.Log("🟡 Drag Tool Activated");
    }

    private void OnSizeSliderChanged(float value)
    {
        dropRadius = value;
        dragBrushSize = value;
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

    public void ClearAllOperations()
    {
        allOperations.Clear();  // **清空操作列表**
        UpdateShaderData();  // **更新 Shader**
    }

    void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        UpdateShaderData();
        Graphics.Blit(src, dest, drawMaterial);
    }

    void UpdateShaderData()
    {
        Vector4[] positions = new Vector4[maxOperations];
        Color[] colors = new Color[maxOperations];
        float[] scales = new float[maxOperations];
        float[] opTypes = new float[maxOperations];// 0 = Drop, 1 = Drag

        for (int i = 0; i < maxOperations; i++)
        {
            if (i < allOperations.Count)
            {
                var op = allOperations[i];

                if (op.operationType == LiquidOperation.OpType.Drop)
                {
                    positions[i] = new Vector4(op.data.x, op.data.y, op.data.z, 0);
                    scales[i] = op.scale;   // **Drop 的 scale 代表半径**
                    colors[i] = op.color;
                    opTypes[i] = 0; // **Drop**
                }
                else if (op.operationType == LiquidOperation.OpType.Drag)
                {
                    positions[i] = new Vector4(op.data.x, op.data.y, op.data.z, op.data.w);
                    scales[i] = op.scale;   // **Drag 没有半径**
                    opTypes[i] = 1; // **Drag**
                }
                colors[i] = op.color;
            }
            else
            {
                positions[i] = new Vector4(-1, -1, 0, 0);
                scales[i] = 0;
                colors[i] = Color.clear;
                opTypes[i] = -1; // 无效操作
            }
        }

        // 传递数组到 Shader
        drawMaterial.SetInt("_OpCount", allOperations.Count);
        drawMaterial.SetVectorArray("_AllOpData", positions);
        drawMaterial.SetFloatArray("_AllScales", scales);
        drawMaterial.SetColorArray("_AllColors", colors);
        drawMaterial.SetFloatArray("_OpTypes", opTypes);
    }
}
