extends Control

@onready var TEXTNode:RichTextLabel = $History

## QUICK PROTOTYPE - - CAN BE DONE WITH ARRAY AND FOR LOOP
func setText(str:Array):
	var text_lines = []
	for i in range(min(str.size(), 5)):
		text_lines.append(str[i])
	
	while text_lines.size() < 5:
		text_lines.append("")

	TEXTNode.text = "[center]" +\
	"[font_size=28] LAST 5 MOVES\n [/font_size]" +\
	"[font_size=20] %s\n%s\n%s\n%s\n%s [/font_size]" % text_lines +\
	"[/center]";
	pass;
