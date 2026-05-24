# ManastormBars

[![Interface](https://img.shields.io/badge/Interface-3.3.5a-blue.svg)]()
[![Server](https://img.shields.io/badge/Server-Project_Ascension-gold.svg)]()
[![Sub-Expansion](https://img.shields.io/badge/Mod-Conquest_of_Azeroth-orange.svg)]()

**ManastormBars** es un addon ligero y personalizado para el cliente 3.3.5a de **Project Ascension** (específicamente optimizado para *Conquest of Azeroth*). El addon añade una barra de acción dedicada y completamente independiente para gestionar los hechizos de la baraja (*loadout*) del modo de juego **Manastorm**, junto con un bloque opcional de consumibles y objetos situacionales.

---

## ✨ Características

* 📦 **Bloque Especial de Consumibles**: Añade accesos directos automatizados para las pociones y objetos clave de Manastorm:
  * *Manastorm: Interrupt Rod*
  * *Endless Manastorm Potion*
  * *Millhouse's Magical Escape*
  * *Millhouse's Regeneration Matrix*
  * *Manastorm: Taunting Tonic*
* 🔄 **Detección Dinámica de Hechizos**: Escanea automáticamente las ranuras activas de tu loadout de Manastorm.
* 🛡️ **Tooltips Nativos Asegurados**: Corrección en el renderizado de tooltips que soluciona los problemas de IDs personalizadas de Ascension para objetos como el *Interrupt Rod* y el *Taunting Tonic*.
* 🎛️ **Ventana de Configuración In-Game**: Ajusta el número de filas, columnas, escala visual y visibilidad del fondo.
* ⌨️ **Soporte de Atajos (Keybindings)**: Totalmente integrado con el menú oficial de asignación de teclas de World of Warcraft.
* ⚔️ **Seguro en Combate**: Implementa plantillas seguras (`SecureActionButtonTemplate`) para evitar errores de *taint* en medio de una partida.

---

## 🛠️ Comandos de Chat

Puedes controlar el addon utilizando el comando principal `/msb` o `/manastormbars`:

| Comando | Descripción |
| :--- | :--- |
| `/msb` | Abre/cierra la ventana de configuración visual. |
| `/msb lock` | Bloquea o desbloquea el arrastre de la barra en la pantalla. |
| `/msb reset` | Restablece todas las opciones de posición y tamaño por defecto. |
| `/msb debug` | Muestra en el chat de errores las IDs internas de tus ranuras de Manastorm actuales. |

---

## 🚀 Instalación

1. Descarga el repositorio como un archivo `.zip`.
2. Descomprime el contenido dentro de la carpeta de Addons de tu cliente de Ascension:
   `...\World of Warcraft\Interface\AddOns\`
3. Asegúrate de que la carpeta contenedora se llame exactamente **`ManastormBars`** (y dentro de ella se encuentren los archivos `.toc` y `.lua`).
4. Inicia el juego y asegúrate de tener activado el addon en la lista de personajes.

---

## 📐 Estructura del Código

El addon está construido de forma monolítica pero modular para garantizar el menor consumo de memoria del cliente:
* **Mapeo de IDs de Servidor**: Interceptación manual de hechizos custom como el Interrupt Rod (`93429`) y el Taunting Tonic (`991868`).
* **Actualización en Segundo Plano**: Bucle `OnUpdate` optimizado a intervalos de 0.1s para refrescar enfriamientos (cooldowns) y texturas sin afectar a los FPS.
