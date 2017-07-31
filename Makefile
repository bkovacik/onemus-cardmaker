DPI=300

heroes:
	ruby lib/cardmaker.rb --name='Onemus ReAlpha' --cardlist='\/hero_cardlist.yaml' --cardlayout='\/cardlayout_hero.yaml' -v --dpi=${DPI} --tile=1x3 --padding='+40+40' --sheets='Heroes' --cardlistname='\/hero-output.png' -p -c

terrain:
	ruby lib/cardmaker.rb --name='Onemus ReAlpha' --cardlist='\/terrain_cardlist.yaml' --cardlayout='\/cardlayout_terrain.yaml' -v --dpi=${DPI} --tile=2x3 --padding='+40+40' --sheets='Terrain' --cardlistname='\/terrain-output.png' -p

spells:
	ruby lib/cardmaker.rb --name='Onemus ReAlpha' --cardlayout='\/cardlayout_spells.yaml' -v --dpi=${DPI} --sheets='Spells'

equipment:
	ruby lib/cardmaker.rb --name='Onemus ReAlpha' --cardlayout='\/cardlayout_equipment.yaml' -v --dpi=${DPI} --sheets='Equipment'

troops-and-mercenaries:
	ruby lib/cardmaker.rb --name='Onemus ReAlpha' --cardlayout='\/cardlayout.yaml' -v --dpi=${DPI} --sheets='Troops,Mercenaries'

compile-all:
	ruby lib/cardmaker.rb --name='Onemus ReAlpha' --cardlist='\/cardlist.yaml' -v --dpi=${DPI} --tile=3x3 --padding='+40+40' --cardlistname='\/output.png' -p --nogen

all:
	make heroes
	make terrain
	make spells
	make equipment
	make troops-and-mercenaries
	make compile-all
