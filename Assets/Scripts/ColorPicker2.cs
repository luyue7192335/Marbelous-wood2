using UnityEngine;
using UnityEngine.UI;
using System.Collections.Generic;
using UnityEngine.EventSystems;

public class ColorPicker2 : MonoBehaviour
{
    public MovingScene movingscene;
    public Transform colorPanel;
    public GameObject colorButtonPrefab;
    
    // 颜色选择器组件
    public GameObject colorPickerPanel;
    public Image colorPickerImage;
    public Image colorPreview;
    public Slider brightnessSlider;
    public Button confirmColorButton;
    public Button addColorButton;

    private List<Color> colors = new List<Color>(); // 包含所有颜色的列表
    private Color selectedColor = Color.white;
    
    // 预定义36种标准颜色（RGB值来自标准色环）
    private readonly Color[] standardColors = new Color[] {
        // Soft reds and pinks
    new Color(0.96f, 0.80f, 0.80f),  // Soft pink
    new Color(0.94f, 0.68f, 0.70f),  // Warm rose
    new Color(0.90f, 0.60f, 0.64f),  // Muted red

    // Soft oranges and yellows
    new Color(0.98f, 0.88f, 0.70f),  // Light apricot
    new Color(0.97f, 0.83f, 0.55f),  // Warm gold
    new Color(0.95f, 0.78f, 0.40f),  // Soft amber

    // Soft greens
    new Color(0.80f, 0.92f, 0.80f),  // Pastel green
    new Color(0.70f, 0.88f, 0.70f),  // Mint green
    new Color(0.60f, 0.84f, 0.60f),  // Muted green

    // Soft blues
    new Color(0.70f, 0.84f, 0.95f),  // Light blue
    new Color(0.60f, 0.78f, 0.90f),  // Soft sky blue
    new Color(0.50f, 0.72f, 0.85f),  // Muted blue

    // Soft violets
    new Color(0.85f, 0.80f, 0.90f),  // Pastel violet
    new Color(0.75f, 0.70f, 0.85f),  // Lavender gray
    new Color(0.65f, 0.60f, 0.80f),  // Soft indigo

    // Neutrals
    new Color(0.95f, 0.95f, 0.95f),  // Near white
    new Color(0.80f, 0.80f, 0.80f),  // Light gray
    new Color(0.65f, 0.65f, 0.65f),  // Medium gray
    new Color(0.50f, 0.50f, 0.50f),  // Dark gray
    };

    void Start()
    {
        colorPickerPanel.SetActive(false);
        
        // 初始化标准颜色按钮
        foreach (Color c in standardColors)
        {
            
            colors.Add(c); // 将标准色加入颜色列表
            CreateColorButton(c);
        }

        // 绑定事件
        brightnessSlider.onValueChanged.AddListener(UpdateBrightness);
        confirmColorButton.onClick.AddListener(ConfirmColorSelection);
        addColorButton.onClick.AddListener(() => {
            colorPickerPanel.SetActive(true);
            selectedColor = Color.white; // 重置选择
            brightnessSlider.value = 1f;
            colorPreview.color = Color.white;
        });
    }

    void CreateColorButton(Color color)
    {
            GameObject buttonObj = Instantiate(colorButtonPrefab, colorPanel);
        buttonObj.GetComponent<Image>().color = color;
        
        // 添加按钮特殊处理
        // if(isAddButton)
        // {
        //     //buttonObj.GetComponent<Button>().onClick.AddListener(OpenColorPicker);
        //     buttonObj.transform.SetAsLastSibling(); // 始终保持在最后
        //     return;
        // }

        // 颜色按钮布局逻辑
        buttonObj.GetComponent<Button>().onClick.AddListener(() => SelectColor(color));
        PositionColorButton(buttonObj.GetComponent<RectTransform>(), colors.Count-1);
    }

    void PositionColorButton(RectTransform rect, int index)
    {
        // 每行10个按钮，间距80px
        const int buttonsPerRow = 10;
        const float buttonSize = 60f;
        const float startX = 290f;
        const float startY = 30f;

        // 计算位置
        int row = index / buttonsPerRow;
        int col = index % buttonsPerRow;
        
        rect.anchoredPosition = new Vector2(
            startX + col * buttonSize,
            startY - row * buttonSize
        );
    }

    public void SelectColor(Color color)
    {
        movingscene.SetSelectedColor(color);
    }

    // 颜色选择器点击事件（需绑定到EventTrigger组件）
    public void OnColorPickerClicked(BaseEventData data)
    {
        PointerEventData pointerData = (PointerEventData)data;
        
        Vector2 localPoint;
        RectTransformUtility.ScreenPointToLocalPointInRectangle(
            colorPickerImage.rectTransform,
            pointerData.position,
            pointerData.pressEventCamera,
            out localPoint
        );

        float x = Mathf.Clamp01((localPoint.x + colorPickerImage.rectTransform.rect.width/2) / colorPickerImage.rectTransform.rect.width);
        float y = Mathf.Clamp01((localPoint.y + colorPickerImage.rectTransform.rect.height/2) / colorPickerImage.rectTransform.rect.height);

        selectedColor = colorPickerImage.sprite.texture.GetPixelBilinear(x, y);
        selectedColor.a = brightnessSlider.value; // 控制透明度
        colorPreview.color = selectedColor;
    }

    void UpdateBrightness(float value)
    {
        selectedColor.a = value;
        colorPreview.color = selectedColor;
    }

    void ConfirmColorSelection()
    {
        // 添加到颜色列表
        colors.Add(selectedColor);
        // 创建新按钮
        CreateColorButton(selectedColor);
        // 关闭面板
        colorPickerPanel.SetActive(false);
    }
}

