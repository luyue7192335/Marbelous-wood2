using UnityEngine;
using System.Collections.Generic;
using System.Linq; 
using UnityEngine.UI;
using TMPro;
using System.Collections;

public class MovingScene : MonoBehaviour
{
   public Material drawMaterial;  // **用于绘制的 Shader Material**
    [Header("Transition Settings")]
    [SerializeField] private float transitionDuration = 0.5f;
    private float _currentLerpFactor = 1f;
    private Coroutine _activeTransition;

    public Slider randomStrengthSlider;
    public Button generateButton;
    public GameObject variationPanel; 
    public GameObject originalPlane;
    public RawImage[] variationImages;        // 四个 UI RawImage
    RenderTexture[] variationRTs = new RenderTexture[4];
    Material[] variationMats  = new Material[4];
    [SerializeField] private Button exitGenerateButton;

    public PlaneZoomController zoomController; // 负责Plane缩放的脚本
    private bool isLocked = false;
    public static MovingScene Instance;

        void Awake()
        {
            Instance = this;
        }

    public class LiquidOperation
    {
        public enum OpType { Drop = 0, Drag = 1, Curl = 2 ,Comb=3}
        
        public OpType operationType;
        public Vector4 data; // x,y,z,w根据类型复用
        public Color color;
        public float scale;
        public float noiseStrength; 

        // Drop构造器
        public LiquidOperation(Vector2 uvPos, float radius, Color color, float noiseStrength)
        {
            operationType = OpType.Drop;
            data = new Vector4(uvPos.x, uvPos.y, radius, 0);
            this.color = color;
            this.scale = radius; 
            this.noiseStrength = noiseStrength;
        }

        // Drag构造器
        public LiquidOperation(Vector2 startPos, Vector2 endPos, float scale)
        {
            operationType = OpType.Drag;
            data = new Vector4(startPos.x, startPos.y, endPos.x, endPos.y);
            this.scale = scale; 
        }

         public LiquidOperation(Vector2 startPos, float scale, Vector2 endPos)
        {
            operationType = OpType.Curl;
            data = new Vector4(startPos.x, startPos.y, endPos.x, endPos.y);
            this.scale = scale; 
        }

                // .Comb构造器
        public LiquidOperation(Vector2 startPos,  float scale, Vector2 endPos, bool isCurl)
        {
            operationType = OpType.Comb;
            data = new Vector4(startPos.x, startPos.y, endPos.x, endPos.y);
            this.scale = scale; 
        }

        public LiquidOperation(LiquidOperation other) {
            this.operationType = other.operationType;
            this.data          = other.data;
            this.color         = other.color;
            this.scale         = other.scale;
            this.noiseStrength = other.noiseStrength;
        }

    }

    public List<LiquidOperation> allOperations = new List<LiquidOperation>();
    public int maxOperations = 100;

    private Color selectedColor = Color.blue;
    private float dropRadius = 0.1f;
    private float noiseStrength = 0;
    private float dragBrushSize = 0.1f;

    [Header("UI Controls")]
    [SerializeField] private GameObject toolsPanel;
    [SerializeField] private Button dropButton;
    [SerializeField] private Button dragButton;
    [SerializeField] private Button curlButton;
    [SerializeField] private Button combButton;
    [SerializeField] private Slider sizeSlider;
    [SerializeField] private Slider noiseSlider;
    [SerializeField] private TMP_Text sizeText;
    [SerializeField] private TMP_Text noiseText;

    // private bool isBasicDropActive = false;
    // private bool isDragActive = false;
    // private bool isCurlActive = false;
    // private bool isCombActive = false;
    private bool isDragging = false;  // **新增变量：用于判断是否处于拖拽状态**
    private Vector2 dragStartUV;  // **新增变量：存储拖拽起点**

    public enum ToolMode
    {
        None,
        Drop,
        Drag,
        Curl,
        Comb,
        ZoomIn
    }

    private ToolMode currentToolMode = ToolMode.None;


    private List<LiquidOperation> _operationQueue = new List<LiquidOperation>();
    void Start()
    {
        toolsPanel.SetActive(false);
        UpdateSizeDisplay();
        variationPanel.SetActive(false);
        originalPlane.SetActive(true);

        // 绑定按钮事件
        dropButton.onClick.AddListener(ActivateBasicDropTool);
        dragButton.onClick.AddListener(ActivateDragTool);
        curlButton.onClick.AddListener(ActivateCurlTool);
        combButton.onClick.AddListener(ActivateCombTool);
        sizeSlider.onValueChanged.AddListener(OnSizeSliderChanged);
        noiseSlider.onValueChanged.AddListener(OnNoiseSliderChanged);
        generateButton.onClick.AddListener(GenerateVariations);
        exitGenerateButton.onClick.AddListener(ExitVariationMode);

        for (int i = 0; i < 4; i++) {
            // 假设你的画布是 512×512，按需调整
            variationRTs[i]  = new RenderTexture(512, 512, 0, RenderTextureFormat.ARGB32);
            variationMats[i] = new Material(drawMaterial);
            variationImages[i].texture = variationRTs[i];
        }
    }

    void Update()
    {
        // if (PlaneZoomController.Instance != null && PlaneZoomController.Instance.IsZoomMode()){
        //    Debug.Log($" lock the click");
        //     return;
        // }
        

        if (Input.GetMouseButtonDown(0))
        {
            

            Ray ray = Camera.main.ScreenPointToRay(Input.mousePosition);
            RaycastHit hit;

            if (Physics.Raycast(ray, out hit))
            {
                Vector2 pixelUV = hit.textureCoord;
                if (!IsValidUV(pixelUV)) return;

                if (PlaneZoomController.Instance != null && PlaneZoomController.Instance.TryZoomIn(pixelUV))
                {
                    Debug.Log($"Zoom handled this click.");
                    return; // ✅ 吃掉了点击，不再继续
                }
                if (PlaneZoomController.Instance != null )
                {
                    Debug.Log($"PlaneZoomController.Instance != null.");
                    
                }
                if ( PlaneZoomController.Instance.TryZoomIn(pixelUV))
                {
                    Debug.Log($"Instance.TryZoomIn(pixelUV).");
                   
                }

                switch (currentToolMode)
                {
                    case ToolMode.Drop:
                        _operationQueue.Add(new LiquidOperation(pixelUV, dropRadius, selectedColor, noiseStrength));
                        Debug.Log($" Drop Added at {pixelUV}");
                        break;

                    case ToolMode.Drag:
                        dragStartUV = pixelUV;
                        isDragging = true;
                        Debug.Log($" Drag Start at {pixelUV}");
                        break;

                    case ToolMode.Curl:
                        dragStartUV = pixelUV;
                        isDragging = true;
                        Debug.Log($" Curl Start at {pixelUV}");
                        break;

                    case ToolMode.Comb:
                        dragStartUV = pixelUV;
                        isDragging = true;
                        Debug.Log($" Comb Start at {pixelUV}");
                        break;

                    case ToolMode.ZoomIn:
                        if (PlaneZoomController.Instance != null)
                        {
                            PlaneZoomController.Instance.ZoomInAt(pixelUV);
                            currentToolMode = ToolMode.None; // 放大后退出Zoom
                            Debug.Log($" Zoom In at {pixelUV}");
                        }
                        else
                        {
                            Debug.LogWarning("Zoom Controller not found.");
                        }
                        break;
                }
            }
        }

        // 拖拽型操作（Drag / Curl / Comb）
        if (Input.GetMouseButtonUp(0) && isDragging)
        {
            Ray ray = Camera.main.ScreenPointToRay(Input.mousePosition);
            RaycastHit hit;

            if (Physics.Raycast(ray, out hit))
            {
                Vector2 dragEndUV = hit.textureCoord;
                if (!IsValidUV(dragEndUV))
                {
                    isDragging = false;
                    return;
                }

                switch (currentToolMode)
                {
                    case ToolMode.Drag:
                        _operationQueue.Add(new LiquidOperation(dragStartUV, dragEndUV, dropRadius));
                        Debug.Log($" Drag Completed from {dragStartUV} to {dragEndUV}");
                        break;

                    case ToolMode.Curl:
                        _operationQueue.Add(new LiquidOperation(dragStartUV, dropRadius, dragEndUV));
                        Debug.Log($" Curl Completed from {dragStartUV} to {dragEndUV}");
                        break;

                    case ToolMode.Comb:
                        _operationQueue.Add(new LiquidOperation(dragStartUV, dropRadius, dragEndUV, true));
                        Debug.Log($" Comb Completed from {dragStartUV} to {dragEndUV}");
                        break;
                }
            }

            isDragging = false;
        }

        // 排队执行操作
        if (_operationQueue.Count > 0 && _activeTransition == null)
        {
            var oldestOp = _operationQueue[0];
            _operationQueue.RemoveAt(0);
            AddNewOperation(oldestOp);
            Debug.Log($"从队列取出操作：{oldestOp}");
        }
    }


    // void HandleDrop()
    // {
    //     Ray ray = Camera.main.ScreenPointToRay(Input.mousePosition);
    //     RaycastHit hit;

    //     if (Physics.Raycast(ray, out hit))
    //     {
    //         MeshCollider meshCollider = hit.collider.GetComponent<MeshCollider>();
    //         if (meshCollider == null) return;

    //         Vector2 pixelUV = hit.textureCoord;
    //         if (!IsValidUV(pixelUV)) return;

    //         //AddNewOperation(new LiquidOperation(pixelUV, dropRadius, selectedColor));
    //         _operationQueue.Add(new LiquidOperation(pixelUV, dropRadius, selectedColor, noiseStrength));
    //         Debug.Log($" Drop Added at {pixelUV}");
    //     }
    // }

    // void HandleDrag()
    // {
    //     if (Input.GetMouseButtonDown(0))
    //     {
    //         Ray ray = Camera.main.ScreenPointToRay(Input.mousePosition);
    //         RaycastHit hit;
    //         if (Physics.Raycast(ray, out hit))
    //         {
    //             dragStartUV = hit.textureCoord;
    //             isDragging = true;
    //             Debug.Log($"🔹 Drag Start: {dragStartUV}");
    //         }
    //     }
        
    //     if (Input.GetMouseButtonUp(0) && isDragging)
    //     {
    //         Ray ray = Camera.main.ScreenPointToRay(Input.mousePosition);
    //         RaycastHit hit;
    //         if (Physics.Raycast(ray, out hit))
    //         {
    //             Vector2 dragEndUV = hit.textureCoord;
    //             if (!IsValidUV(dragEndUV)) return;

    //             if (Vector2.Distance(dragStartUV, dragEndUV) > 0.01f)
    //             {
    //                 //AddNewOperation(new LiquidOperation(dragStartUV, dragEndUV, dropRadius));
    //                  _operationQueue.Add(new LiquidOperation(dragStartUV, dragEndUV, dropRadius));
          
    //                 Debug.Log($" Drag Completed from {dragStartUV} to {dragEndUV}");
    //             }
    //         }
    //         isDragging = false;
    //     }
    // }

    // void HandleComb()
    // {
    //     if (Input.GetMouseButtonDown(0))
    //     {
    //         Ray ray = Camera.main.ScreenPointToRay(Input.mousePosition);
    //         RaycastHit hit;
    //         if (Physics.Raycast(ray, out hit))
    //         {
    //             dragStartUV = hit.textureCoord;
    //             isDragging = true;
    //             Debug.Log($"🔹 comb Start");
    //         }
    //     }
        
    //     if (Input.GetMouseButtonUp(0) && isDragging)
    //     {
    //         Ray ray = Camera.main.ScreenPointToRay(Input.mousePosition);
    //         RaycastHit hit;
    //         if (Physics.Raycast(ray, out hit))
    //         {
    //             Vector2 dragEndUV = hit.textureCoord;
    //             if (!IsValidUV(dragEndUV)) return;

    //             if (Vector2.Distance(dragStartUV, dragEndUV) > 0.01f)
    //             {
    //                 //AddNewOperation(new LiquidOperation(dragStartUV, dragEndUV, dropRadius));
    //                  _operationQueue.Add(new LiquidOperation(dragStartUV, dropRadius,dragEndUV,true));
          
    //                 Debug.Log($" comb Completed from {dragStartUV} to {dragEndUV}");
    //             }
    //         }
    //         isDragging = false;
    //     }
    // }

    // void HandleCurl()
    // {
    //     if (Input.GetMouseButtonDown(0))
    //     {
    //         Ray ray = Camera.main.ScreenPointToRay(Input.mousePosition);
    //         RaycastHit hit;
    //         if (Physics.Raycast(ray, out hit))
    //         {
    //             dragStartUV = hit.textureCoord;
    //             isDragging = true;
    //             Debug.Log($"🔹 curl Start: {dragStartUV}");
    //         }
    //     }
        
    //     if (Input.GetMouseButtonUp(0) && isDragging)
    //     {
    //         Ray ray = Camera.main.ScreenPointToRay(Input.mousePosition);
    //         RaycastHit hit;
    //         if (Physics.Raycast(ray, out hit))
    //         {
    //             Vector2 dragEndUV = hit.textureCoord;
    //             if (!IsValidUV(dragEndUV)) return;

    //             if (Vector2.Distance(dragStartUV, dragEndUV) > 0.01f)
    //             {
    //                 //AddNewOperation(new LiquidOperation(dragStartUV, dragEndUV, dropRadius));
    //                  _operationQueue.Add(new LiquidOperation(dragStartUV,  dropRadius, dragEndUV));
          
    //                 Debug.Log($" curl Completed from {dragStartUV} to {dragEndUV}");
    //             }
    //         }
    //         isDragging = false;
    //     }
    // }

    void GenerateVariations() {
        
        originalPlane.SetActive(false);
        variationPanel .SetActive(true);
        variationPanel.transform.SetAsLastSibling(); // 把整个变体图像面板放到最前

        float strength = randomStrengthSlider.value;

        for (int i = 0; i < variationMats.Length; i++) 
        {
            if (variationMats[i] != null && variationMats[i] != drawMaterial)
                Destroy(variationMats[i]);
        }

        for (int i = 0; i < 4; i++) 
        {
            variationMats[i] = new Material(drawMaterial);

            // 深拷贝并随机化操作列表
            var opsCopy = allOperations
                .Select(op => RandomizeOp(op, strength))
                .ToList();

            // 把这份新的操作数组写到第 i 份材质里
            UpdateShaderData(opsCopy, variationMats[i]);

            // 直接把材质渲染到对应的 RenderTexture
            Graphics.Blit(null, variationRTs[i], variationMats[i]);
        }
    }
    
    LiquidOperation RandomizeOp(LiquidOperation op, float s) {
        // 拷贝基本字段
        var copy = new LiquidOperation(op); // 需要你给 LiquidOperation 添加一个“拷贝构造”
        // 把 scale、noiseStrength、data.x/y/z/w 都乘以 1±rand*s
        float r1 = Random.Range(1 - s, 1 + s);
        copy.scale          *= r1;
        copy.noiseStrength  *= r1;
        var d = copy.data;
        d.x *= Random.Range(1 - s, 1 + s);
        d.y *= Random.Range(1 - s, 1 + s);
        d.z *= Random.Range(1 - s, 1 + s);
        d.w *= Random.Range(1 - s, 1 + s);
        copy.data = d;
        return copy;
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
        Debug.Log(allOperations.Count);

        if (_activeTransition != null) StopCoroutine(_activeTransition);
        _activeTransition = StartCoroutine(TransitionRoutine());

        UpdateShaderData();
    }

    private IEnumerator TransitionRoutine()
    {
        float timer = 0f;
        _currentLerpFactor = 0f;  // 重置过渡进度
        
        while(timer < transitionDuration)
        {
            timer += Time.deltaTime;
            _currentLerpFactor = Mathf.Clamp01(timer / transitionDuration);
            //Debug.Log(_currentLerpFactor);
            UpdateShaderData();  // 实时更新LerpFactor
            yield return null;

        }
        
        _currentLerpFactor = 1f;
        UpdateShaderData();
        _activeTransition = null;
    }

    public void RevertSimplified()
    {
        // 优先处理未执行队列
        if (_operationQueue.Count > 0)
        {
            _operationQueue.RemoveAt(_operationQueue.Count - 1); // 移除最后添加的
            Debug.Log($"丢弃待执行操作，剩余队列：{_operationQueue.Count}");
            return;
        }

        // 处理已执行操作
        if (allOperations.Count > 0)
        {
            allOperations.RemoveAt(allOperations.Count - 1);
            //UpdateShaderImmediately(); // 直接更新无需过渡
            UpdateShaderData();
            Debug.Log($"回退历史操作，剩余操作：{allOperations.Count}");
        }
        else
        {
            Debug.Log("无操作可回退");
        }
    }

    public void ToggleToolsPanel()
    {
        toolsPanel.SetActive(!toolsPanel.activeSelf);
        
    }

    // private void ActivateBasicDropTool()
    // {
    //     isBasicDropActive = true;
    //     isCurlActive = false;
    //     isDragActive = false; // **确保只激活一个工具**
    //     isCombActive = false;
    // }

    // public void ActivateDragTool()
    // {
    //     isBasicDropActive = false;
    //     isDragActive = true;
    //     isCurlActive = false;
    //     isCombActive = false;
    //     Debug.Log(" Drag Tool Activated");
    // }

    // public void ActivateCurlTool()
    // {
    //     isBasicDropActive = false;
    //     isDragActive = false;
    //     isCurlActive = true;
    //     isCombActive = false;
    //     Debug.Log(" Curl Tool Activated");
    // }
    // public void ActivateCombTool()
    // {
    //     isBasicDropActive = false;
    //     isDragActive = false;
    //     isCurlActive = false;
    //     isCombActive = true;
    //     Debug.Log(" Comb Tool Activated");
    // }

    public void ActivateBasicDropTool()
    {
        currentToolMode = ToolMode.Drop;
    }

    public void ActivateDragTool()
    {
        currentToolMode = ToolMode.Drag;
    }

    public void ActivateCurlTool()
    {
        currentToolMode = ToolMode.Curl;
    }

    public void ActivateCombTool()
    {
        currentToolMode = ToolMode.Comb;
    }

    public void ActivateZoomTool()
    {
        if (isLocked) return;  // 如果正在Zoom中，不能再次进入
        currentToolMode = ToolMode.ZoomIn;
        isLocked = true;
        Debug.Log($" is locked");
        PlaneZoomController.Instance.EnterZoomInMode();

    }

    public void OnZoomInCompleted()
    {
        isLocked = false;
        Debug.Log($" is not locked");
        currentToolMode = ToolMode.None;
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

    private void OnNoiseSliderChanged(float value)
    {
        noiseStrength = value;
        
        UpdateNoiseDisplay();
    }

    private void UpdateNoiseDisplay()
    {
        noiseText.text = $"noise: {noiseStrength:0.00}";
    }

    // 设置选中的颜色
    public void SetSelectedColor(Color newColor)
    {
        selectedColor = newColor;
    }

    public void ClearAllOperations()
    {
        allOperations.Clear();  // **清空操作列表**
        _currentLerpFactor = 1f;
        UpdateShaderData();  // **更新 Shader**
    }

    void ExitVariationMode()
    {
        variationPanel.SetActive(false);
        originalPlane.SetActive(true);

        Debug.Log("已退出生成界面，回到主界面");
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
        float[] noiseStrengths = new float[maxOperations]; 

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
                    noiseStrengths[i] = op.noiseStrength;
                }
                else if (op.operationType == LiquidOperation.OpType.Drag)
                {
                    positions[i] = new Vector4(op.data.x, op.data.y, op.data.z, op.data.w);
                    scales[i] = op.scale;   // **Drag 没有半径**
                    opTypes[i] = 1; // **Drag**
                }
                else if (op.operationType == LiquidOperation.OpType.Curl)
                {
                    positions[i] = new Vector4(op.data.x, op.data.y, op.data.z, op.data.w);
                    scales[i] = op.scale;   
                    opTypes[i] = 2; 
                }
                else if (op.operationType == LiquidOperation.OpType.Comb)
                {
                    positions[i] = new Vector4(op.data.x, op.data.y, op.data.z, op.data.w);
                    scales[i] = op.scale;   // **Drag 没有半径**
                    opTypes[i] = 3; 
                }
                colors[i] = op.color;
            }
            else
            {
                positions[i] = new Vector4(-1, -1, 0, 0);
                scales[i] = 0;
                colors[i] = Color.clear;
                opTypes[i] = -1; // 无效操作
                noiseStrengths[i] = 0;
            }
        }

        // 传递数组到 Shader
        drawMaterial.SetInt("_OpCount", allOperations.Count);
        drawMaterial.SetVectorArray("_AllOpData", positions);
        drawMaterial.SetFloatArray("_AllScales", scales);
        drawMaterial.SetColorArray("_AllColors", colors);
        drawMaterial.SetFloatArray("_OpTypes", opTypes);
        drawMaterial.SetFloatArray("_AllNoiseStrength", noiseStrengths);
        drawMaterial.SetFloat("_LerpFactor", _currentLerpFactor);
        //Debug.Log(_currentLerpFactor);
    }

    void UpdateShaderData(List<LiquidOperation> ops, Material mat) 
    {
        int count = ops.Count;
        mat.SetInt("_OpCount", count);
        // 构造需要传给 shader 的数组
        Vector4[]  pa = new Vector4[maxOperations];
        float[]    sc = new float   [maxOperations];
        Color[]    co = new Color   [maxOperations];
        float[]    ns = new float   [maxOperations];
        float[]    tp = new float   [maxOperations];
        for (int i = 0; i < maxOperations; i++) {
            if (i < count) {
                var op = ops[i];
                pa[i] = op.data;
                sc[i] = op.scale;
                co[i] = op.color;
                ns[i] = op.noiseStrength;
                tp[i] = (float)op.operationType;
            } else {
                pa[i] = Vector4.zero;
                sc[i] = 0;
                co[i] = Color.clear;
                ns[i] = 0;
                tp[i] = -1;
            }
        }
        mat.SetVectorArray("_AllOpData",       pa);
        mat.SetFloatArray( "_AllScales",       sc);
        mat.SetColorArray( "_AllColors",       co);
        mat.SetFloatArray( "_AllNoiseStrength",ns);
        mat.SetFloatArray( "_OpTypes",         tp);
        mat.SetFloat(      "_LerpFactor",      1f);
    }

    // 获取当前模式
    public ToolMode CurrentToolMode()
    {
        return currentToolMode;
    }

    public Color GetSelectedColor1()
    {
        return selectedColor;
    }

    public float GetDropRadius()
    {
        return dropRadius;
    }

    public float GetNoiseStrength()
    {
        return noiseStrength;
    }

    public void SetToolMode(ToolMode mode)
    {
        currentToolMode = mode;
    }

    public void SetSelectedColor1(Color color)
    {
        selectedColor = color;
    }

    public void SetDropRadius(float radius)
    {
        dropRadius = radius;
    }

    public void SetNoiseStrength(float strength)
    {
        noiseStrength = strength;
    }




}