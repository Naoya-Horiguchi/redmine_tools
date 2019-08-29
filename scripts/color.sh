CL_BLACK='\033[0;30m'    # Black
CL_RED='\033[0;31m'      # Red
CL_GREEN='\033[0;32m'    # Green
CL_ORANGE='\033[0;33m'   # Brown/Orange
CL_BLUE='\033[0;34m'     # Blue
CL_PURPLE='\033[0;35m'   # Purple
CL_CYAN='\033[0;36m'     # Cyan
CL_GRAY='\033[0;37m'     # Light Gray
CL_DGRAY='\033[1;30m'    # Dark Gray
CL_LRED='\033[1;31m'     # Light Red
CL_LGREEN='\033[1;32m'   # Light Green
CL_YELLOW='\033[1;33m'   # Yellow
CL_LBLUE='\033[1;34m'    # Light Blue
CL_LPURPLE='\033[1;35m'  # Light Purple
CL_LCYAN='\033[1;36m'    # Light Cyan
CL_WHITE='\033[1;37m'    # White
CL_NC='\033[0m'          # No Color

CL_RGB_START='\e[0;31m'
CL_RGB_END='\e[1;31m'

# format:name:RR;GG;BB
cat <<EOF > $TMPDIR/color_list
wheat:245;222;179
light_slate_gray:119;136;153
snow:255;250;250
crimson:220;20;60
light_gray:211;211;211
tan:210;180;140
light_steel_blue:176;196;222
dark_orange:255;140;0
aqua_marine:127;255;212
brown:165;42;42
medium_turquoise:72;209;204
coral:255;127;80
light_yellow:255;255;224
gainsboro:220;220;220
moccasin:255;228;181
golden_rod:218;165;32
firebrick:178;34;34
azure:240;255;255
antique_white:250;235;215
beige:245;245;220
sienna:160;82;45
deep_pink:255;20;147
olive:128;128;0
pale_golden_rod:238;232;170
blue_violet:138;43;226
light_pink:255;182;193
silver:192;192;192
dark_cyan:0;139;139
dark_green:0;100;0
salmon:250;128;114
royal_blue:65;105;225
dark_khaki:189;183;107
medium_blue:0;0;205
aqua:0;255;255
green:0;128;0
light_salmon:255;160;122
alice_blue:240;248;255
yellow_green:154;205;50
papaya_whip:255;239;213
cadet_blue:95;158;160
cyan:0;255;255
medium_purple:147;112;219
misty_rose:255;228;225
mint_cream:245;255;250
dark_gray:169;169;169
green_yellow:173;255;47
medium_aqua_marine:102;205;170
medium_slate_blue:123;104;238
teal:0;128;128
dark_red:139;0;0
linen:250;240;230
indigo:75;0;130
violet:238;130;238
dark_slate_blue:72;61;139
sky_blue:135;206;235
light_coral:240;128;128
plum:221;160;221
navy:0;0;128
ghost_white:248;248;255
dark_turquoise:0;206;209
dim_gray:105;105;105
sea_green:46;139;87
dark_sea_green:143;188;143
lavender:230;230;250
dark_olive_green:85;107;47
powder_blue:176;224;230
floral_white:255;250;240
orange_red:255;69;0
pink:255;192;203
peru:205;133;63
dodger_blue:30;144;255
black:0;0;0
gold:255;215;0
light_cyan:224;255;255
light_blue:173;216;230
pale_violet_red:219;112;147
dark_salmon:233;150;122
ivory:255;255;240
slate_gray:112;128;144
medium_spring_green:0;250;154
rosy_brown:188;143;143
medium_sea_green:60;179;113
spring_green:0;255;127
blue:0;0;255
chocolate:210;105;30
blanched_almond:255;235;205
maroon:128;0;0
lemon_chiffon:255;250;205
dark_blue:0;0;139
pale_green:152;251;152
dark_magenta:139;0;139
indian_red:205;92;92
burly_wood:222;184;135
sandy_brown:244;164;96
pale_turquoise:175;238;238
deep_sky_blue:0;191;255
lawn_green:124;252;0
forest_green:34;139;34
saddle_brown:139;69;19
orange:255;165;0
bisque:255;228;196
magenta:255;0;255
steel_blue:70;130;180
yellow:255;255;0
sea_shell:255;245;238
lime:0;255;0
corn_flower_blue:100;149;237
turquoise:64;224;208
light_sky_blue:135;206;250
red:255;0;0
lime_green:50;205;50
medium_orchid:186;85;211
midnight_blue:25;25;112
slate_blue:106;90;205
tomato:255;99;71
chart_reuse:127;255;0
hot_pink:255;105;180
medium_violet_red:199;21;133
corn_silk:255;248;220
dark_golden_rod:184;134;11
dark_slate_gray:47;79;79
thistle:216;191;216
light_sea_green:32;178;170
dark_orchid:153;50;204
peach_puff:255;218;185
light_green:144;238;144
gray:128;128;128
dark_violet:148;0;211
orchid:218;112;214
lavender_blush:255;240;245
purple:128;0;128
navajo_white:255;222;173
old_lace:253;245;230
olive_drab:107;142;35
khaki:240;230;140
honeydew:240;255;240
EOF

declare -A COLOR_TABLE;

color_string() {
	local cid="$1"
	local string="$2"

	echo -n "${COLOR_TABLE[$cid]}"
	eval printf "'${CL_RGB_START}${COLOR_TABLE[$cid]}$string${CL_RGB_END}'"
}

#TODO: i=0
#TODO: DARK_SIDE_LIMIT=100
#TODO: for col in $(cat $TMPDIR/color_list | sort) ; do
#TODO: 	color_name=$(echo $col | cut -f1 -d:)
#TODO: 	color_code=$(echo $col | cut -f2 -d:)
#TODO: 	color_weight=$[$(echo $color_code | tr ';' '+')]
#TODO: 	if [ "$DARK_SIDE_LIMIT" -lt "$color_weight" ] ; then
#TODO: 		COLOR_TABLE[$i]='\e[38;2;'${color_code}'m'
#TODO: 		i=$[i+1]
#TODO: 	fi
#TODO: done
#TODO: set | grep CL_
#TODO: echo ${COLOR_TABLE[@]}
#TODO: for i in $(seq 40) ; do
#TODO: 	color_string $i "test $i\n"
#TODO: done
#TODO: # CL_RGB_1='\e[38;2;255;95;255m'
#TODO: exit
