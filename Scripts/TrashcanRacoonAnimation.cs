using Godot;
using System.Collections.Generic;

public partial class TrashcanRacoonAnimation : Node2D
{
	private int coins = 0;

	// Racoon animatie
	private Area2D racoon;
	private AnimatedSprite2D racoonAnimation;

	private double timeSinceLastClick = 0.0;
	private bool isDigging = false;
	private bool wantsToKeepDigging = false;

	private const double DigTimeout = 0.5;

	public class DropItem
	{
		public string Name { get; set; }
		public int Value { get; set; }
		public float Weight { get; set; }
		public int AmountFound { get; set; }
		public bool Unlocked { get; set; }
		public string ReqItem { get; set; }
		public int ReqAmount { get; set; }
		public string Icon { get; set; }
	}

	// Alle items
	private List<DropItem> drops = new List<DropItem>
	{
		new DropItem { Name = "Banana", Value = 1, Weight = 50.0f, AmountFound = 0, Unlocked = true, ReqItem = "", ReqAmount = 0, Icon = "res://Sprites/BananaSprite.png" },
		new DropItem { Name = "Can", Value = 2, Weight = 30.0f, AmountFound = 0, Unlocked = false, ReqItem = "Banana", ReqAmount = 100, Icon = "res://Sprites/CanSprite.png" },
		new DropItem { Name = "Pizza", Value = 5, Weight = 12.0f, AmountFound = 0, Unlocked = false, ReqItem = "Can", ReqAmount = 50, Icon = "res://Sprites/PizzaSprite.png" },
		new DropItem { Name = "Donut", Value = 10, Weight = 5.0f, AmountFound = 0, Unlocked = false, ReqItem = "Pizza", ReqAmount = 10, Icon = "res://Sprites/DonutSprite.png" },
		new DropItem { Name = "Phone", Value = 50, Weight = 2.5f, AmountFound = 0, Unlocked = false, ReqItem = "Donut", ReqAmount = 5, Icon = "res://Sprites/PhoneSprite.png" },
		new DropItem { Name = "Ring", Value = 250, Weight = 0.5f, AmountFound = 0, Unlocked = false, ReqItem = "Phone", ReqAmount = 2, Icon = "res://Sprites/RingSprite.png" }
	};

	public override void _Ready()
	{
		// Nodes ophalen
		racoon = GetNode<Area2D>("Racoon");
		racoonAnimation = GetNode<AnimatedSprite2D>("Racoon/AnimatedSprite2D");

		// Klikken op racoon
		racoon.InputEvent += OnRacoonInputEvent;

		// Kijken wanneer een animatie klaar is
		racoonAnimation.AnimationFinished += OnAnimationFinished;

		racoonAnimation.Play("idle");

		UpdateUnlockUI();
	}

	public override void _Process(double delta)
	{
		if (!isDigging)
			return;

		timeSinceLastClick += delta;

		// Er wordt niet meer geklikt
		if (timeSinceLastClick >= DigTimeout)
		{
			wantsToKeepDigging = false;

			// Alleen vanuit de loop stoppen
			if (racoonAnimation.Animation == "dig_loop")
			{
				racoonAnimation.Play("dig_end");
			}
		}
	}

	private void OnRacoonInputEvent(
		Node viewport,
		InputEvent @event,
		long shapeIdx
	)
	{
		if (@event is InputEventMouseButton mouseEvent &&
			mouseEvent.ButtonIndex == MouseButton.Left &&
			mouseEvent.Pressed)
		{
			OnRacoonClicked();
		}
	}

	private void OnRacoonClicked()
	{
		StartDigging();

		DropItem droppedItem = GetRandomDrop();

		coins += droppedItem.Value;
		GetNode<Label>("%CoinCounter").Text = coins.ToString();

		droppedItem.AmountFound++;

		CheckForUnlocks(droppedItem);
		UpdateUnlockUI();
		AddRecentItem(droppedItem);
	}

	private void StartDigging()
	{
		timeSinceLastClick = 0.0;

		// Eerste klik
		if (!isDigging)
		{
			isDigging = true;
			wantsToKeepDigging = false;

			racoonAnimation.Play("dig_start");
			return;
		}

		// Extra klik betekent dat we door willen graven
		wantsToKeepDigging = true;

		// Als hij net bezig was met omhoog komen,
		// meteen weer beginnen met graven
		if (racoonAnimation.Animation == "dig_end")
		{
			racoonAnimation.Play("dig_start");
		}
	}

	private void OnAnimationFinished()
	{
		// Start is klaar
		if (racoonAnimation.Animation == "dig_start")
		{
			if (wantsToKeepDigging &&
				timeSinceLastClick < DigTimeout)
			{
				racoonAnimation.Play("dig_loop");
			}
			else
			{
				racoonAnimation.Play("dig_end");
			}

			return;
		}

		// Einde is klaar
		if (racoonAnimation.Animation == "dig_end")
		{
			isDigging = false;
			wantsToKeepDigging = false;

			racoonAnimation.Play("idle");
		}
	}

	private DropItem GetRandomDrop()
	{
		List<DropItem> availableDrops = new List<DropItem>();
		float totalWeight = 0.0f;

		foreach (var item in drops)
		{
			if (item.Unlocked)
			{
				availableDrops.Add(item);
				totalWeight += item.Weight;
			}
		}

		float roll = (float)GD.RandRange(0.0, totalWeight);
		float cumulativeChance = 0.0f;

		foreach (var item in availableDrops)
		{
			cumulativeChance += item.Weight;

			if (roll <= cumulativeChance)
			{
				return item;
			}
		}

		return availableDrops[0];
	}

	private void CheckForUnlocks(DropItem lastFoundItem)
	{
		foreach (var item in drops)
		{
			if (!item.Unlocked && item.ReqItem == lastFoundItem.Name)
			{
				if (lastFoundItem.AmountFound >= item.ReqAmount)
				{
					item.Unlocked = true;
					GD.Print($"Nieuw item unlocked: {item.Name}!");
				}
			}
		}
	}

	private void UpdateUnlockUI()
	{
		DropItem nextItem = null;

		foreach (var item in drops)
		{
			if (!item.Unlocked)
			{
				nextItem = item;
				break;
			}
		}

		var unlockLabel = GetNode<Label>("%UnlockLabel");
		var unlockProgressBar = GetNode<ProgressBar>("%UnlockProgressBar");
		var nextItemIcon = GetNode<TextureRect>("%NextItemIcon");

		if (nextItem != null)
		{
			int currentAmount = 0;

			foreach (var item in drops)
			{
				if (item.Name == nextItem.ReqItem)
				{
					currentAmount = item.AmountFound;
					break;
				}
			}

			unlockLabel.Text =
				$"Next item: {nextItem.Name}  ({currentAmount} / {nextItem.ReqAmount})";

			unlockProgressBar.MaxValue = nextItem.ReqAmount;
			unlockProgressBar.Value = currentAmount;
			unlockProgressBar.Visible = true;

			nextItemIcon.Texture = GD.Load<Texture2D>(nextItem.Icon);
			nextItemIcon.Visible = true;
		}
		else
		{
			unlockLabel.Text = "All items unlocked!";
			unlockProgressBar.Visible = false;
			nextItemIcon.Visible = false;
		}
	}

	private void AddRecentItem(DropItem item)
	{
		var recentItemsContainer =
			GetNode<HBoxContainer>("%RecentItemsContainer");

		VBoxContainer itemBox = new VBoxContainer();

		// Item afbeelding
		TextureRect icon = new TextureRect();
		icon.Texture = GD.Load<Texture2D>(item.Icon);
		icon.ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize;
		icon.StretchMode = TextureRect.StretchModeEnum.KeepAspectCentered;
		icon.CustomMinimumSize = new Vector2(48, 48);

		// Waarde
		Label valueLabel = new Label();
		valueLabel.Text = $"+{item.Value}";
		valueLabel.HorizontalAlignment = HorizontalAlignment.Center;
		valueLabel.AddThemeFontSizeOverride("font_size", 16);

		itemBox.AddChild(icon);
		itemBox.AddChild(valueLabel);

		recentItemsContainer.AddChild(itemBox);

		// Maximaal 5 recente items
		if (recentItemsContainer.GetChildCount() > 5)
		{
			Node oldestItem = recentItemsContainer.GetChild(0);
			oldestItem.QueueFree();
		}
	}
}
