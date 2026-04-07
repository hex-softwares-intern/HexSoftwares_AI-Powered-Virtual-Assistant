# 🤖 ARIA: AI-Responsive Intelligent Assistant

![Internship](https://img.shields.io/badge/HexSoftwares-Internship-blue?style=flat-square) ![Domain](https://img.shields.io/badge/Domain-Artificial%20Intelligence-purple?style=flat-square) ![Task](https://img.shields.io/badge/Task-1%20%7C%20Project%202-orange?style=flat-square) ![Flutter](https://img.shields.io/badge/Flutter-Dart-02569B?style=flat-square&logo=flutter) ![Groq](https://img.shields.io/badge/Groq-Llama--3.1--8B-red?style=flat-square)

> **📌 Internship Track:** Artificial Intelligence · Task 1 · Project 2

> ARIA is a high-performance, low-latency AI assistant built with **Flutter**. It leverages the **Groq Llama-3.1-8B-Instant** model to provide near-instantaneous voice and text interactions, capable of controlling **Windows system settings** and **Android device functions** through a custom Intent-Parsing engine.

---

## 🚀 Key Features

| Feature | Description |
|---|---|
| ⚡ Ultra-Fast Response | Powered by Groq's 8b-instant model for **<1s latency** |
| 🧠 Intent Recognition | Custom Regex-based engine extracting actions like `SET_VOLUME`, `OPEN_APP`, `SET_ALARM` |
| 🖥️ Windows Integration | Control system volume, brightness & launch UWP apps via PowerShell |
| 📱 Android Support | Deep linking & package mapping for WhatsApp, Spotify, YMusic, and more |
| 🔄 Context Aware | Injects real-time system data (Battery, Date, Time) into the AI's prompt |

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter (Dart) |
| AI Orchestration | Groq API (Llama 3.3 & 3.1) |
| Networking | Dio (REST & Streaming) |
| Windows Backend | PowerShell Core / Process Execution |
| Android Backend | Platform Channels / Method Channels |

---

## 📂 Project Structure

```
lib/core/services/
├── groq_service.dart       # Manages AI streaming and system prompts
├── intent_service.dart     # Parses raw AI text into executable intent tags
└── intent_executor.dart    # The "Body" of the AI — executes system-level commands
```

---

## ⚙️ Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-username/aria.git
   cd aria
   ```

2. **Add your Groq API Key** to your environment variables or secure storage

3. **Install dependencies**
   ```bash
   flutter pub get
   ```

4. **Build for your platform**
   ```bash
   # Windows
   flutter build windows

   # Android
   flutter build apk
   ```

---

## 📜 License

Copyright 2024 \[Your Name/Handle\]

Licensed under the **Apache License, Version 2.0**. You may not use this file except in compliance with the License.

You may obtain a copy of the License at:
🔗 http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an **"AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND**, either express or implied. See the License for the specific language governing permissions and limitations under the License.

---

## 🎯 Acknowledgment

> Developed as part of the **HexSoftwares Internship Program** 🚀
