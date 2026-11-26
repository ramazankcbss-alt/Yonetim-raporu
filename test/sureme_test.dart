import 'package:flutter_test/flutter_test.dart';
import 'package:yonetim_raporu/veri/sureme.dart';

void main() {
  test('Sürü sağlığı ve üreme arşivi çözülür (örnek veri)', () {
    const j = '{"ciftlik":["A","B"],"sekil":["Normal","Müdahale/güç doğum","Günsüz","Ölü doğum","Abort"],'
        '"grup":["İnek","Düve","Belirtilmemiş"],"gebelik":["Gebe","Boş","Boş (kist)","Diğer"],'
        '"yontem":["Gözlem","Senkronizasyon","Belirtilmemiş"],"bogalar":["X"],"asilar":["ŞAP"],'
        '"dogum":[[2026,3,4,0,0,1,2,1,1,2,0]],"tohumlama":[[2026,3,5,1,1,2,0,3]],"boga":[[2026,3,1,0,3]],'
        '"senk":[[2026,3,1,0,12]],"gebelikMuayene":[[2026,3,6,0,0,0,5]],"asi":[[2026,3,7,1,0,"Tüm sürü",1]],'
        '"gelen":[[2026,3,8,1,"Brangus",53,19950]],"satis":[[2026,3,9,1,"Erkek buzağı",2,190000,340]],'
        '"sut":[[2026,3,10,1,{"yag":3.6}]],"diger":[[2026,3,11,1,"Boynuz köreltme",4]],'
        '"suruAlan":["sagmal","bos_inek"],"suru":[[2026,3,12,405,null]],"olusturma":"2026-11-26"}';
    final a = SuremeArsiv.coz(j);
    expect(a.dogum.single.tur, 'Müdahale/güç doğum');
    expect(a.dogum.single.v('dogum'), 2);
    expect(a.tohumlama.single.alt, 'Düve|2. tohumlama');
    expect(a.gebelik.single.tur, 'Gebe');
    expect(a.satis.single.v('tutar'), 190000);
    expect(a.suru.single.d.containsKey('bos_inek'), isFalse);
    expect(a.suru.single.v('sagmal'), 405);
    expect(a.bosMu, isFalse);
  });
}
