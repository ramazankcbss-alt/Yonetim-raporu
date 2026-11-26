/// Android / test: köprü yok.
bool get webKopruVar => false;

Future<String> webKopru(String islem, String govde) => Future.error(UnsupportedError('Web köprüsü yok'));
