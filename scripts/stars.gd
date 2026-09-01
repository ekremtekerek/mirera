class_name Stars
extends RefCounted
##
## Yildiz kurali: DOKUNUS SAYISI.
##
##   par kadar dokunus      -> 3 yildiz
##   par + 1 veya par + 2   -> 2 yildiz
##   daha fazlasi           -> 1 yildiz
##
## Olcu par'a GORE, mutlak sayiya gore degil: 2 dokunusluk bir bolumde 4
## dokunus savruk, 6 dokunusluk bir bolumde ise iyi bir sonuc. Sabit esik
## koymak zorlasan bolumleri haksiz sekilde cezalandirirdi.
##
## "Deneme sayisi" olcusu bu oyunda ANLAMSIZ: geri alinamaz bir "calistir"
## hamlesi yok, oyuncu istedigi kadar ayna cevirebiliyor ve isin her
## dokunusta aninda yeniden ciziliyor. Olculebilir tek sey ne kadar TEMIZ
## cozdugu.
##
## Taban 1'de duruyor. Sifir yildiz vermek "basaramadim" hissi birakiyor,
## oysa bolum COZULDU; en dusuk odul de bir odul. Ustelik yildiz tema
## acilislarini besliyor, yani sifir vermek ilerlemeyi de durdururdu.

static func rate(taps: int, par: int) -> int:
	if taps <= par:
		return 3
	if taps <= par + 2:
		return 2
	return 1
