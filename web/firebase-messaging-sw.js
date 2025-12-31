importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyCOOdDHPR2C_4nEo3OiRt3mE_JAgCA3YOg",
  authDomain: "private-messaging-2cdd1.firebaseapp.com",
  projectId: "private-messaging-2cdd1",
  storageBucket: "private-messaging-2cdd1.firebasestorage.app",
  messagingSenderId: "496711474371",
  appId: "1:496711474371:web:858129c09fa2910d601676"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  // Customize notification here
  const notificationTitle = payload.data.title;
  const notificationOptions = {
    body: payload.data.body,
    icon: '/icons/icon-192.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
