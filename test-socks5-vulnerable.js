// Тестовый SOCKS5 сервер БЕЗ авторизации (уязвимый)
// Запускай только для теста! После теста ОБЯЗАТЕЛЬНО останови (Ctrl+C)

const net = require('net');

const PORT = 1080;

const server = net.createServer((socket) => {
  console.log(`\n📡 Подключение от ${socket.remoteAddress}:${socket.remotePort}`);

  socket.once('data', (data) => {
    // SOCKS5 handshake
    // Клиент отправил: [0x05, NMETHODS, METHODS...]
    // Мы отвечаем: [0x05, 0x00] — SOCKS5, метод NO AUTH (УЯЗВИМО!)
    socket.write(Buffer.from([0x05, 0x00]));
    console.log('   Отправлен ответ: SOCKS5 v5, метод NO AUTH (0x00)');
    console.log('   🔴 Это значит — уязвимый прокси без пароля!');

    // Ждём запрос CONNECT
    socket.once('data', (data2) => {
      if (data2[0] === 0x05 && data2[1] === 0x01) {
        // CONNECT запрос — отправляем success ответ
        // [0x05, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        const response = Buffer.from([
          0x05, 0x00, // Версия 5, успех
          0x00,       // RSV
          0x01,       // IPv4
          0x00, 0x00, 0x00, 0x00, // 0.0.0.0
          0x00, 0x00,             // порт 0
        ]);
        socket.write(response);
        console.log('   Отправлен CONNECT success');
      }
      // Держим соединение открытым чтобы сканер смог прочитать ответ
    });
  });

  socket.on('error', () => {});
});

server.listen(PORT, '127.0.0.1', () => {
  console.log('');
  console.log('══════════════════════════════════════════════╗');
  console.log('║  🔴 ТЕСТОВЫЙ SOCKS5 СЕРВЕР (БЕЗ ПАРОЛЯ)     ║');
  console.log('║                                              ║');
  console.log('║  Порт: 1080                                  ║');
  console.log('║  Статус: УЯЗВИМЫЙ (без авторизации)          ║');
  console.log('║                                              ║');
  console.log('║  Теперь открой Morok VPN → SOCKS5 Shield    ║');
  console.log('║  Нажми "Проверить устройство"                ║');
  console.log('║  Ты должен увидеть КРАСНОЕ предупреждение!   ║');
  console.log('║                                              ║');
  console.log('║  Для остановки: Ctrl+C                       ║');
  console.log('╚══════════════════════════════════════════════╝');
  console.log('');
});

process.on('SIGINT', () => {
  server.close();
  console.log('\n✅ Тестовый сервер остановлен');
  process.exit(0);
});
