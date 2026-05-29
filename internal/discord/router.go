package discord

import "github.com/bwmarrin/discordgo"

// onInteraction định tuyến interaction: slash command (type 2) theo tên,
// component (type 3) sang package interactions.
func (b *Bot) onInteraction(s *discordgo.Session, i *discordgo.InteractionCreate) {
	switch i.Type {
	case discordgo.InteractionApplicationCommand:
		switch i.ApplicationCommandData().Name {
		case "today":
			b.commands.Today(s, i)
		case "data":
			b.commands.Data(s, i)
		case "announce":
			b.commands.Announce(s, i)
		case "help":
			b.commands.Help(s, i)
		}
	case discordgo.InteractionMessageComponent:
		b.interactions.Handle(s, i)
	}
}
