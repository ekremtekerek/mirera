class_name Stars
extends RefCounted
##
## Yildiz kurali.
##
## Bu oyunda "daha az hamle" olcusu YOK: oyuncu tam olarak par kadar tohum
## seciyor, ya tutuyor ya tutmuyor. O yuzden olcu DENEME SAYISI:
##
##   1. denemede  -> 3 yildiz
##   2-3. deneme  -> 2 yildiz
##   sonrasi      -> 1 yildiz
##
## Boylece oyun "once dusun, sonra bas" davranisini oduluyor -- ki bu zaten
## mekanigin ruhu: kurulum sessiz, calistirma geri alinamaz.
##
## Tabani 1'de tuttum. Sifir yildiz vermek cocuk oyuncuda "basaramadim"
## hissi birakiyor; oysa seviye COZULDU. En dusuk odul de bir odul.

static func rate(attempts: int) -> int:
	if attempts <= 1:
		return 3
	if attempts <= 3:
		return 2
	return 1
