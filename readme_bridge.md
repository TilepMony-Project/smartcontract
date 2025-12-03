# Bridge Module Overview

Dokumen ini merangkum seluruh komponen bridge di `src/bridge`, bagaimana alurnya, serta bagaimana cara menambah penyedia baru di masa depan. Saat ini **hanya Axelar** yang aktif karena token lintas-chain yang tersedia baru mengikuti standar Axelar (`transferRemote`), namun arsitekturnya sudah modular sehingga provider tambahan bisa ditambahkan kembali hanya dengan membuat turunan baru.

## Arsitektur Tingkat Tinggi

```
User / Aggregator
        |
        v
Bridge Adapter (src/bridge/adapters)
        |
        v
Bridge Router (src/bridge/routers)
        |
        v
ICrossChainToken.transferRemote -> Axelar Network
```

- **Router** memegang logika inti bridging: validasi token, kalkulasi biaya, penyimpanan nonce, dan emisi event.
- **Adapter** adalah lapisan tipis agar kontrak aggregator/front-end tidak berinteraksi langsung dengan router.
- **ICrossChainToken** adalah token ERC20 yang mendukung `transferRemote`, gaya Axelar (burn di chain asal, mint di chain tujuan).

## Skenario & Jaringan Aktif

- **Chain sumber/destinasi yang tersedia**: Mantle Sepolia, Base Sepolia, dan Arbitrum Sepolia.
- **Token lintas-chain**: mIDRX, mUSDC, mUSDT (mengikuti antarmuka `ICrossChainToken` sehingga dapat dipanggil lewat Axelar).
- **Alur dasar**: user pada Mantle Sepolia mengirim token ke `AxelarBridgeRouter`, router membakar token dan mengirim pesan ke chain tujuan, lalu token dicetak ulang di chain tersebut sebelum `completeBridge` menyalurkan ke `receiver`.
- **Frontend helper**: folder `halo/` berisi skrip Node (`bridge.js`) untuk memanggil `AxelarBridgeAdapter` dari RPC mana pun. Tinggal isi `.env` dengan RPC/PK/adaptor address dan siapkan payload JSON.

### Daftar Token Cross-Chain

| Token  | Mantle Sepolia | Catatan |
|--------|----------------|---------|
| mIDRX  | `0xc39DfE81DcAd49F1Da4Ff8d41f723922Febb75dc` | ERC20 lintas-chain utama. |
| mUSDC  | `0x681db03Ef13e37151e9fd68920d2c34273194379` | Stablecoin kompatibel Axelar. |
| mUSDT  | `0x9a82fC0c460A499b6ce3d6d8A29835a438B5Ec28` | Stablecoin lintas-chain tambahan. |

*(Replikasi alamat pada Base/Arbitrum Sepolia mengikuti deployment masing-masing; catat begitu tersedia.)*

### Referensi Kontrak Bridge (per chain)

| Chain            | AxelarBridgeRouter                         | AxelarBridgeAdapter                        | Catatan |
|------------------|--------------------------------------------|--------------------------------------------|---------|
| Mantle Sepolia   | `0x1111111111111111111111111111111111111111` | `0x2222222222222222222222222222222222222222` | Isi dengan alamat deploy asli saat tersedia. |
| Base Sepolia     | `0x3333333333333333333333333333333333333333` | `0x4444444444444444444444444444444444444444` | Placeholder untuk memetakan kontrak setelah deployment. |
| Arbitrum Sepolia | `0x5555555555555555555555555555555555555555` | `0x6666666666666666666666666666666666666666` | Ganti dengan alamat final setelah deploy. |

> Gunakan tabel ini sebagai “katalog alamat” supaya tim FE tidak kebingungan saat mengonfigurasi environment atau skrip (mis. `halo/.env`).

## Kontrak Router

| Kontrak            | Fungsi utama                                                                                         | Provider ID                   | Catatan `extraData`                                                                                      |
|--------------------|-------------------------------------------------------------------------------------------------------|-------------------------------|-----------------------------------------------------------------------------------------------------------|
| `BaseBridgeRouter` | Implementasi umum `IBridgeRouter`. Mengelola token yang diizinkan, nonce, dan fee.                    | virtual (via `_providerId`)   | Tidak dipakai langsung, hanya kelas dasar untuk router spesifik.                                         |
| `AxelarBridgeRouter` | Router aktif saat ini. Menghitung biaya berdasarkan panjang metadata dan nama chain.                | `keccak256("AXELAR_ROUTER")`  | `extraData` bisa berisi metadata tambahan. Fee meningkat seiring panjang `extraData` dan `destinationChain`. |

Setiap router turunan harus:
1. Mewarisi `BaseBridgeRouter`.
2. Override `quoteFee(...)` agar FE bisa tahu `msg.value` yang dibutuhkan.
3. Mengimplementasikan `_providerId()` dengan ID unik (dipakai untuk indexing/telemetri).

### Siklus `bridgeToken`

1. FE memanggil `quoteFee(destinationChain, amount, extraData)` untuk menghitung biaya native.
2. User mengatur allowance ERC20 untuk router atau adapter (jika dipakai).
3. `bridgeToken` menarik token, meneruskan `transferRemote`, menghitung `bridgeId`, dan emit `BridgeInitiated`.
4. `bridgeId` digunakan FE/back-end untuk tracking status.
5. Setelah bukti lintas chain valid, owner router memanggil `completeBridge` di chain tujuan untuk melepas token dan emit `BridgeCompleted`.

### Penanganan Fee & Refund

- Router memastikan `requiredFee > 0` dan `msg.value >= requiredFee`.
- Kelebihan `msg.value` otomatis di-refund ke caller.
- Fee diteruskan sebagai `value` ketika memanggil `ICrossChainToken.transferRemote`.

## Kontrak Adapter

Semua adapter mewarisi `BaseBridgeAdapter` yang mengimplementasikan `IBridgeAdapter`.

```solidity
function bridge(BridgeParams calldata params, address from) external payable returns (bytes32 bridgeId);
```

- `BridgeParams` berisi `token`, `amount`, `destinationChain`, `destinationAddress`, `receiver`, dan `extraData`.
- `from` menentukan sumber dana. Jika `from = address(0)` maka default ke `msg.sender`.
- Adapter memindahkan token dari `from` ke dirinya sendiri, meningkatkan allowance ke router, lalu meneruskan `bridgeToken`.

Adapter aktif:

- `AxelarBridgeAdapter` → gunakan bersama `AxelarBridgeRouter`.

Untuk menambah provider baru nanti, cukup buat file adapter baru yang mengembalikan string `protocol()` sesuai nama dan warisi `BaseBridgeAdapter`.

## Integrasi Frontend / Aggregator

1. **Deteksi Router / Adapter**  
   Saat ini pilih `AxelarBridgeAdapter` atau panggil router langsung.

2. **Tanpa Adapter**  
   Approve token ke router → panggil `quoteFee` → jalankan `bridgeToken` dengan `msg.value = requiredFee` → simpan `bridgeId`.

3. **Dengan Adapter**  
   Approve token ke adapter → panggil `AxelarBridgeAdapter.bridge(params, from)` dengan `from = address(0)` bila user interaksi langsung → adapter meneruskan semua parameter ke router.

4. **Chain Tujuan**  
   Operator/keeper memantau bukti dari Axelar dan memanggil `completeBridge` ketika sudah valid.

## Event & Pelacakan

- `BridgeInitiated`: dipancarkan di chain asal, memuat data caller, receiver, token, amount, destination, dan `extraData`.
- `BridgeCompleted`: dipancarkan saat dana dilepas di chain tujuan.
- `SupportedTokenUpdated`: memberi tahu FE daftar token yang tersedia.

## Menambah Penyedia Baru

1. Buat router baru turunan `BaseBridgeRouter`.
2. Implementasikan `quoteFee` & `_providerId`.
3. Buat adapter turunan `BaseBridgeAdapter` jika ingin menjaga antarmuka aggregator.
4. Registrasikan token yang diizinkan melalui `setSupportedToken`.
5. Update dokumentasi / registry supaya FE tahu provider baru tersebut.

## Ringkasan File Penting

- `src/bridge/interfaces/IBridgeRouter.sol` – antarmuka router.
- `src/bridge/interfaces/IBridgeAdapter.sol` – struktur `BridgeParams` dan fungsi `bridge`.
- `src/bridge/interfaces/ICrossChainToken.sol` – API minimal token lintas chain (gaya Axelar).
- `src/bridge/routers/BaseBridgeRouter.sol` & `src/bridge/routers/AxelarBridgeRouter.sol`.
- `src/bridge/adapters/BaseBridgeAdapter.sol` & `src/bridge/adapters/AxelarBridgeAdapter.sol`.

Dengan konfigurasi ini, seluruh sistem bridge fokus pada Axelar untuk saat ini namun tetap modular sehingga provider baru bisa diaktifkan ulang tanpa mengubah arsitektur inti.
