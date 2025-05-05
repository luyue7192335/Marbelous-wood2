using UnityEngine;
using UnityEngine.UI;

public class ColorPicker : MonoBehaviour
{
    public DropBasicTest dropBasicTest; // 让 ClickToDraw 知道当前颜色
     //public DropController dropController; 
    public GameObject colorPanel;  // 用于存放颜色按钮的 Panel
    public Button[] colorButtons;  // 颜色按钮数组
    public Color[] colors; // 颜色数组

    private bool isPanelVisible = false; // 颜色面板是否显示

    void Start()
    {
        // 初始化所有颜色按钮
        for (int i = 0; i < colorButtons.Length; i++)
        {
            int index = i; // 避免 Lambda 捕获问题
            colorButtons[i].onClick.AddListener(() => SelectColor(colors[index]));
        }

        // 颜色面板默认隐藏
        colorPanel.SetActive(false);
    }

    // **点击 "SelectColor" 按钮时调用**
    public void ToggleColorButtons()
    {
        isPanelVisible = !isPanelVisible;
        colorPanel.SetActive(isPanelVisible);
    }

    // **当选择颜色时调用**
    public void SelectColor(Color newColor)
    {
        //dropController.OnColorSelected(newColor);
        dropBasicTest.SetSelectedColor(newColor); // 通知 ClickToDraw 当前颜色
        ToggleColorButtons(); // 选择完颜色后，隐藏颜色面板
    }
}
