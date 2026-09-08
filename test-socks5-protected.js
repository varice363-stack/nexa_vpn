// Тестовый SOCKS5 сервер С ПАРОЛЕМ (защищённый)
// Запускай для проверки что защищённый прокси не определяется как уязвимый

const net = require('net');

const PORT = 1080;

const server = net.createServer((socket) => {
  console.log(`\n Подключение от ${socket.remoteAddress}:${socket.remotePort}`);

  socket.once('data', (data) => {
    // Клиент предлагает методы
    const nmethods = data[1];
    const methods = [];
    for (let i = 2; i < 2 + nmethods; i++) {
      methods.push(data[i]);
    }
    console.log(`   Предложенные методы: [${methods.map(m => '0x' + m.toString(16)).join(', ')}]`);

    // Проверяем есть ли метод USERNAME/PASSWORD (0x02)
    const hasAuth = methods.includes(0x02);

    if (hasAuth) {
      // Отвечаем: требуем авторизацию
      socket.write(Buffer.from([0x05, 0x02]));
      console.log('   ✅ Отправлен ответ: SOCKS5 v5, метод USERNAME/PASSWORD (0x02)');
      console.log('   ✅ Это значит — ЗАЩИЩЁННЫЙ прокси!');

      // Ждём авторизацию
      socket.once('data', (authData) => {
        if (authData[0] === 0x01) {
          // Username/password subnegotiation
          const userLen = authData[1];
          const user = authData.slice(2, 2 + userLen).toString();
          const passLen = authData[2 + userLen];
          const pass = authData.slice(3 + userLen, 3 + userLen + passLen).toString();
          console.log(`   Получен логин: "${user}", пароль: "${pass}"`);

          // Проверяем пароль
          if (user === 'morok' && pass === 'test123') {
            socket.write(Buffer.from([0x01, 0x00])); // Успех
            console.log('   ✅ Авторизация успешна');
          } else {
            socket.write(Buffer.from([0x01, 0x01])); // Ошибка
            console.log('   ❌ Неверный логин/пароль');
          }
        }
      });
    } else {
      // Нет метода авторизации — отклоняем
      socket.write(Buffer.from([0x05, 0xFF]));
      console.log('   Отправлен ответ: нет приемлемых методов (0xFF)');
    }
  });

  socket.on('error', () => {});
});

server.listen(PORT, '127.0.0.1', () => {
  console.log('');
  console.log('╔══════════════════════════════════════════════╗');
  console.log('║  🟢 ТЕСТОВЫЙ SOCKS5 СЕРВЕР (С ПАРОЛЕМ)     ║');
  console.log('║                                              ║');
  console.log('║  Порт: 1080                                  ║');
  console.log('║  Статус: ЗАЩИЩЁН (требует пароль)            ║');
  console.log('║                                              ║');
  console.log('║  Теперь открой Morok VPN → SOCKS5 Shield    ║');
  console.log('║  Нажми "Проверить устройство"                ║');
  console.log('║  Ты должен увидеть ЗЕЛЁНОЕ — безопасно!     ║');
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
