DPI=300

all:
	ifeq ($(OS),Windows_NT)
		@echo %cd%
	endif
	@echo '----Heroes----'
	ruby lib/cardmaker.rb --name='Onemus ReAlpha' --cardlist='hero_cardlist.yaml' --cardlayout='/cardlayout_hero.yaml' -v --dpi=${DPI} --tile=2x3 --padding='+40+40' --sheets='Heroes' -p
