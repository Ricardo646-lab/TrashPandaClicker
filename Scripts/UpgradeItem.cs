using Godot;

public partial class UpgradeItem : PanelContainer
{
    [Export] public int BaseCost = 100;
    [Export] public float CostMultiplier = 1.5f;

    private int _currentCost;
    private int _level = 0;

    private Label _levelLabel;
    private Button _buyButton;
    private TrashcanMain _mainGame;

    // Styleboxes for dynamic button backgrounds
    private StyleBoxFlat _greenNormalStyle;
    private StyleBoxFlat _greenHoverStyle;
    private StyleBoxFlat _redStyle;

    public override void _Ready()
    {
        _currentCost = BaseCost;

        _levelLabel = GetNode<Label>("ItemRow/LevelLabel");
        _buyButton = GetNode<Button>("ItemRow/BuyButton");

        _mainGame = FindTrashcanMain(GetTree().Root);

        _buyButton.Pressed += OnBuyButtonPressed;

        SetupStyles();
        UpdateUI();
    }

    private void SetupStyles()
    {
        // 1. Green Normal Style (Affordable)
        _greenNormalStyle = new StyleBoxFlat();
        _greenNormalStyle.BgColor = new Color("#4CAF50"); // Standard green
        _greenNormalStyle.SetCornerRadiusAll(6);

        // 2. Dark Green Hover Style (Affordable + Hovered)
        _greenHoverStyle = new StyleBoxFlat();
        _greenHoverStyle.BgColor = new Color("#2E7D32"); // Darker green
        _greenHoverStyle.SetCornerRadiusAll(6);

        // 3. Red Style (Unaffordable)
        _redStyle = new StyleBoxFlat();
        _redStyle.BgColor = new Color("#E53935"); // Clean red
        _redStyle.SetCornerRadiusAll(6);
    }

    public override void _Process(double delta)
    {
        UpdateAffordability();
    }

    private void UpdateAffordability()
    {
        if (_mainGame == null) return;

        bool canAfford = _mainGame.GetCoins() >= _currentCost;

        // Keep text color crisp white for both red and green states
        _buyButton.AddThemeColorOverride("font_color", Colors.White);

        if (canAfford)
        {
            // Green background + Dark green hover effect
            _buyButton.AddThemeStyleboxOverride("normal", _greenNormalStyle);
            _buyButton.AddThemeStyleboxOverride("hover", _greenHoverStyle);
            _buyButton.AddThemeStyleboxOverride("pressed", _greenHoverStyle);
        }
        else
        {
            // Red background + static hover (no hover color change)
            _buyButton.AddThemeStyleboxOverride("normal", _redStyle);
            _buyButton.AddThemeStyleboxOverride("hover", _redStyle);
            _buyButton.AddThemeStyleboxOverride("pressed", _redStyle);
        }
    }

    private void OnBuyButtonPressed()
    {
        if (_mainGame == null)
        {
            _mainGame = FindTrashcanMain(GetTree().Root);
        }

        if (_mainGame == null) return;

        if (_mainGame.TrySpendCoins(_currentCost))
        {
            _level++;
            _currentCost = (int)(_currentCost * CostMultiplier);

            _mainGame.AddBonusPerClick(1);

            UpdateUI();
        }
    }

    private void UpdateUI()
    {
        _levelLabel.Text = $"Lv. {_level}";
        _buyButton.Text = $"{_currentCost}";
    }

    private TrashcanMain FindTrashcanMain(Node startNode)
    {
        if (startNode is TrashcanMain target)
            return target;

        foreach (Node child in startNode.GetChildren())
        {
            var found = FindTrashcanMain(child);
            if (found != null)
                return found;
        }

        return null;
    }
}