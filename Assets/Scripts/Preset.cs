using System.Collections;
using System.Collections.Generic;

using UnityEngine;
using UnityEngine.UI;
using TMPro; 

public class OperationPreset
{
    public string presetName;
    public string opType;
    public string colorHex;
    public float scale;
    public float noiseStrength;
}

[System.Serializable]
public class PresetData
{
    public List<OperationPreset> presets = new List<OperationPreset>();
}


public class Preset : MonoBehaviour
{
   private const string PRESET_SAVE_KEY = "UserOperationPresets";

    [Header("Reference to MovingScene")]
    public MovingScene movingScene;

    [Header("UI References")]
    public TMP_InputField presetNameInput;
    public TMP_Dropdown presetDropdown;

    private PresetData currentPresets;

    void Start()
    {
        LoadPresets();
        RefreshDropdown();
    }

    #region 保存与加载

    void SavePresets()
    {
        string json = JsonUtility.ToJson(currentPresets);
        PlayerPrefs.SetString(PRESET_SAVE_KEY, json);
        PlayerPrefs.Save();
    }

    void LoadPresets()
    {
        if (PlayerPrefs.HasKey(PRESET_SAVE_KEY))
        {
            string json = PlayerPrefs.GetString(PRESET_SAVE_KEY);
            currentPresets = JsonUtility.FromJson<PresetData>(json);
        }
        else
        {
            currentPresets = new PresetData();
        }
    }

    #endregion

    #region UI 刷新 & 预设保存

    void RefreshDropdown()
    {
        presetDropdown.ClearOptions();

        List<string> options = new List<string>();
        foreach (var preset in currentPresets.presets)
        {
            options.Add(preset.presetName);
        }

        presetDropdown.AddOptions(options);

        // ✅ ✅ ✅ 加在这里（防止自动选择第一个并且让UI强制刷新）
        presetDropdown.value = -1;  // 取消当前选择，避免触发选择事件
        presetDropdown.RefreshShownValue();  // 强制UI刷新，防止旧数据残留
    }

    public void SaveCurrentAsPreset()
    {
        if (presetNameInput == null || string.IsNullOrEmpty(presetNameInput.text))
        {
            Debug.LogWarning("Preset name is empty!");
            return;
        }

        OperationPreset newPreset = new OperationPreset();
       newPreset.presetName = presetNameInput.text;
        newPreset.opType = movingScene.CurrentToolMode().ToString();   // ✅ 获取当前模式
        newPreset.colorHex = ColorUtility.ToHtmlStringRGBA(movingScene.GetSelectedColor1());  // ✅ 获取当前颜色
        newPreset.scale = movingScene.GetDropRadius();   // ✅ 获取当前大小
        newPreset.noiseStrength = movingScene.GetNoiseStrength();  // ✅ 获取当前噪声

        currentPresets.presets.Add(newPreset);
        SavePresets();
        RefreshDropdown();

        Debug.Log($"Saved preset: {newPreset.presetName}");
    }

    #endregion

    #region 加载预设

    public void OnPresetSelected(TMP_Dropdown dropdown)
    {
        int index = dropdown.value;
        if (index < 0 || index >= currentPresets.presets.Count)
            return;

        var preset = currentPresets.presets[index];
        LoadPreset(preset);
    }

    void LoadPreset(OperationPreset preset)
    {
        if (System.Enum.TryParse(preset.opType, out MovingScene.ToolMode mode))
        {
            movingScene.SetToolMode(mode);
        }

        if (ColorUtility.TryParseHtmlString("#" + preset.colorHex, out Color color))
        {
            movingScene.SetSelectedColor(color);
        }

        movingScene.SetDropRadius(preset.scale);
        movingScene.SetNoiseStrength(preset.noiseStrength);

        Debug.Log($"Loaded preset: {preset.presetName}");
    }

    #endregion

    #region 清空预设

    public void ClearAllPresets()
    {
        currentPresets.presets.Clear();
        SavePresets();
        RefreshDropdown();
        Debug.Log("Cleared all presets");
    }

    #endregion
}
