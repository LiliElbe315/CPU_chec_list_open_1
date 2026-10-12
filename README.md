# CPU_chec_list_open_1
# BareMetal-Insight: Cross-Platform System Topology & Firmware Damper

A lightweight, zero-dependency, cross-platform system utility written in **Free Pascal** with inline **Intel Assembly**. It bypasses high-level OS abstractions to collect raw hardware topology, CPU capabilities, SMBIOS/DMI tables, and hardware registry trees directly from user-mode (Ring 3).

Originally developed as a research project to reverse-engineer and compare legacy and modern mobile CPU architectures (Intel Haswell platform).

## 🚀 Key Features

* **Low-Level CPUID Explorer:** Uses inline x86/x64 assembly (`cpuid` instruction) to fetch exact hardware vendor/brand strings. Features native support for multi-page standard and extended leaves (crucial for parsing architectural thread/cache topologies like Leaves 4, 7, 11, 13).
* **Pure Ring 3 SMBIOS/DMI Parser:** Dynamically fetches and parses raw SMBIOS data structures (Type 0, 1, 2, 3, 4, 7, 16, 17, 22, 39) using Windows `GetSystemFirmwareTable` API. Implements custom pointer-arithmetic algorithms to safely stream unaligned null-terminated DMI string arrays.
* **Hardware Tree (Configuration Data) Extraction:** Scans and dumps Windows dynamic hardware registries (`HARDWARE\DESCRIPTION\System`). Safely extracts raw binary `CM_FULL_RESOURCE_DESCRIPTOR` configurations from active system buses (PCI, ACPI, ISA).
* **Asynchronous COM Port Scanner:** Implements non-destructive Win32 `CreateFile` polling to map active and blocked hardware communication interfaces via system error-code evaluation (e.g., handling `ERROR_ACCESS_DENIED`).
* **Cross-Platform Foundation:** Built-in modular `{$IFDEF}` routing for seamless migration between Windows WinAPI and Linux `sysfs` filesystem parsing structures.

## 🛠 Architectural Design & Traps Avoided

* **Zero-Driver Requirement:** Bypasses the need for signed Ring 0 kernel drivers (`WHQL`/`Secure Boot` constraints) by leveraging native low-level subsystem interfaces available to the user-mode.
* **Custom String Streaming:** Because SMBIOS text blocks are appended as raw byte sequences immediately after formatted structures, the utility implements an elegant double-pointer verification algorithm to avoid string corruption and memory alignment faults.

## 📊 Sample Output (Pentium 3560M / Clevo W940SU1 Platform)

The utility extracts raw metrics that often expose unconfigured factory firmware templates (e.g., Clevo OEM legacy tags) and asymmetrical memory configurations:

```text
CPU Vendor: GenuineIntel
CPU Model: Intel(R) Pentium(R) CPU 3560M @ 2.40GHz
Max standard leaf: 13
Leaf 11 [Sub  0]: EAX=00000001:EBX=00000001:ECX=00000100:EDX=00000002

=== SYSTEM INFORMATION (SMBIOS/DMI) ===
SMBIOS Version: 2.7
BIOS Vendor: American Megatrends Inc.
Motherboard: Clevo W940SU1
Memory Array: Max Supported 32GB | 4 Slots Detected
  -> Slot 0: 2048 MB (A-Data / 1600 MHz)
  -> Slot 2: 4096 MB (Samsung / 1600 MHz)
```

## 🏗 How to Compile

Requires **Free Pascal Compiler (FPC)** 3.2.0 or newer.

```bash
# Compile for Windows (Intel Mode)
fpc -Mdelphi -Twin64 damper.pas

# Compile for Linux
fpc -Mdelphi -Tlinux damper.pas
```

## 📜 License
MIT / Educational Resource. Feel free to use for hardware reverse-engineering and system research.
