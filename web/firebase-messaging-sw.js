importScripts('https://www.gstatic.com/firebasejs/9.6.8/firebase-app.js');
importScripts('https://www.gstatic.com/firebasejs/9.6.8/firebase-messaging.js');

const firebaseConfig = {
  apiKey: "AIzaSyAYWd7GUhRP3GfQDqd25Po1camKGPTc18c",
        authDomain: "habit-tracker-f4f47.firebaseapp.com",
        projectId: "habit-tracker-f4f47",
        storageBucket: "habit-tracker-f4f47.appspot.com",
        messagingSenderId: "435208808943",
        appId: "1:435208808943:web:d82b62559ddcca8df9959a",
        measurementId: "G-V7SX1TVC3B",
};

firebase.initializeApp(firebaseConfig);

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('Received background message: ', payload);
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
