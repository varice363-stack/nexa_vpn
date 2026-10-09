/// Живые счётчики туннеля, как их отдаёт нативный движок Xray.
///
/// Итоги (`uploadBytes`, `downloadBytes`) — байты с момента запуска туннеля.
/// Скорости (`…BytesPerSec`) — объём за последнюю секунду. Приложение ничего
/// не досчитывает и не придумывает: значения берутся из движка как есть.
class TunnelTraffic {
  const TunnelTraffic({
    this.uploadBytes = 0,
    this.downloadBytes = 0,
    this.uploadBytesPerSec = 0,
    this.downloadBytesPerSec = 0,
  });

  final int uploadBytes;
  final int downloadBytes;
  final int uploadBytesPerSec;
  final int downloadBytesPerSec;
}
