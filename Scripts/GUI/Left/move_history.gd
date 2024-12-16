extends Control

@onready var TEXTNode:RichTextLabel = $History

## QUICK PROTOTYPE - - CAN BE DONE WITH ARRAY AND FOR LOOP
func setText(stir:Array):
	var text_lines = []
	for i in range(min(stir.size(), 5)):
		text_lines.append(stir[i])
	
	while text_lines.size() < 5:
		text_lines.append("")

	TEXTNode.text = "[center]" +\
	"[font_size=28] History\n [/font_size]" +\
	"[font_size=20]%s\n%s\n%s\n%s\n%s[/font_size]" % text_lines +\
	"[/center]";
	return;
