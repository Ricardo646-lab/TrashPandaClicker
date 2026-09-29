using Godot;

public partial class UpgradeItem : PanelContainer
{
    [Export] public int BaseCost = 100;
    [Export] public float CostMultiplier = 1.5f;

    private int _currentCost;
    private int _level = 0;

    private Label _levelLabel;
    private Button _buyButton;
    private TrashcanRacoonAnimation _mainGame;

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
        _greenNormalStyle = new StyleBoxFlat();
        _greenNormalStyle.BgColor = new Color("#4CAF50");
        _greenNormalStyle.SetCornerRadiusAll(6);

        _greenHoverStyle = new StyleBoxFlat();
        _greenHoverStyle.BgColor = new Color("#2E7D32");
        _greenHoverStyle.SetCornerRadiusAll(6);

        _redStyle = new StyleBoxFlat();
        _redStyle.BgColor = new Color("#E53935");
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

        _buyButton.AddThemeColorOverride("font_color", Colors.White);

        if (canAfford)
        {
            _buyButton.AddThemeStyleboxOverride("normal", _greenNormalStyle);
            _buyButton.AddThemeStyleboxOverride("hover", _greenHoverStyle);
            _buyButton.AddThemeStyleboxOverride("pressed", _greenHoverStyle);
        }
        else
        {
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

    private TrashcanRacoonAnimation FindTrashcanMain(Node startNode)
    {
        if (startNode is TrashcanRacoonAnimation target)
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