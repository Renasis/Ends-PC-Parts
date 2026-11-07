import { initializeApp } from "https://www.gstatic.com/firebasejs/10.13.2/firebase-app.js";
import { getDatabase } from "https://www.gstatic.com/firebasejs/10.13.2/firebase-database.js";
import { getAuth } from "https://www.gstatic.com/firebasejs/10.13.2/firebase-auth.js";

export const firebaseConfig = { 
    apiKey: "AIzaSyDk74-PpzcvAOMOXBhi6SllF_3Z1h4Xf6Q", 
    authDomain: "it7-lab-act.firebaseapp.com", 
    databaseURL: "https://it7-lab-act-default-rtdb.firebaseio.com", 
    projectId: "it7-lab-act",
    storageBucket: "it7-lab-act.firebasestorage.app",
    messagingSenderId: "972098400292",
    appId: "1:972098400292:web:2ef47b3395a8292de2a8b1"
};

const app = initializeApp(firebaseConfig);
export const db = getDatabase(app);
export const auth = getAuth(app);