DPI=300

all:
# Heroes
	ruby lib/cardmaker.rb --name='Onemus ReAlpha' --cardlist='\/hero_cardlist.yaml' --cardlayout='\/cardlayout_hero.yaml' -v --dpi=${DPI} --tile=1x3 --padding='+40+40' --sheets='Heroes' --cardlistname='\/hero-output.png' -p -c
# Terrain
	ruby lib/cardmaker.rb --name='Onemus ReAlpha' --cardlist='\/terrain_cardlist.yaml' --cardlayout='\/cardlayout_terrain.yaml' -v --dpi=${DPI} --tile=2x3 --padding='+40+40' --sheets='Terrain' --cardlistname='\/terrain-output.png' -p
# Everything else
	ruby lib/cardmaker.rb --name='Onemus ReAlpha' --cardlayout='\/cardlayout_spells.yaml' -v --dpi=${DPI} --sheets='Spells'
	ruby lib/cardmaker.rb --name='Onemus ReAlpha' --cardlayout='\/cardlayout_equipment.yaml' -v --dpi=${DPI} --sheets='Equipment'
	ruby lib/cardmaker.rb --name='Onemus ReAlpha' --cardlayout='\/cardlayout.yaml' -v --dpi=${DPI} --sheets='Troops,Mercenaries'
	ruby lib/cardmaker.rb --name='Onemus ReAlpha' --cardlist='\/cardlist.yaml' -v --dpi=${DPI} --tile=3x3 --padding='+40+40' --cardlistname='\/output.png' -p --nogen
