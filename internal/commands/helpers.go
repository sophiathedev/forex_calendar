package commands

import (
	"github.com/bwmarrin/discordgo"

	"forexbot/internal/embeds"
	"forexbot/internal/models"
)

// maxEmbeds là giới hạn embed mỗi message của Discord.
const maxEmbeds = 10

// buildChunkEmbeds chia events thành các nhóm size phần tử rồi dựng embed bằng
// builder. Luôn trả ít nhất một embed (rỗng) và không vượt quá maxEmbeds.
func buildChunkEmbeds(events []models.Event, size int, builder func([]models.Event) *discordgo.MessageEmbed) []*discordgo.MessageEmbed {
	chunks := models.Chunk(events, size)
	out := make([]*discordgo.MessageEmbed, 0, len(chunks))
	for _, ch := range chunks {
		out = append(out, builder(ch))
		if len(out) == maxEmbeds {
			break
		}
	}
	if len(out) == 0 {
		out = append(out, builder(nil))
	}
	return out
}

// respondEphemeralEmbed trả lời ngay một embed riêng tư (ephemeral).
func respondEphemeralEmbed(s *discordgo.Session, i *discordgo.InteractionCreate, em *discordgo.MessageEmbed) {
	_ = s.InteractionRespond(i.Interaction, &discordgo.InteractionResponse{
		Type: discordgo.InteractionResponseChannelMessageWithSource,
		Data: &discordgo.InteractionResponseData{
			Embeds: []*discordgo.MessageEmbed{em},
			Flags:  discordgo.MessageFlagsEphemeral,
		},
	})
}

// editError sửa một deferred response thành embed báo lỗi.
func editError(s *discordgo.Session, i *discordgo.InteractionCreate, msg string) {
	em := []*discordgo.MessageEmbed{embeds.SimpleEmbed(msg, embeds.ColorRed)}
	_, _ = s.InteractionResponseEdit(i.Interaction, &discordgo.WebhookEdit{Embeds: &em})
}
