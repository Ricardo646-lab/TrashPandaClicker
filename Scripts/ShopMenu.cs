using Godot;

public partial class ShopMenu : Control
{
    public void OpenShop()
    {
        GD.Print("Cart clicked!");
        Show();
    }

    public void CloseShop()
    {
        Hide();
    }
}