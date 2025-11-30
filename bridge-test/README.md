# Bridge Test Script

Script ini digunakan untuk menguji fungsi bridging dari sisi client (JavaScript/Node.js).

## Persiapan

1.  Masuk ke folder `bridge-test`:
    ```bash
    cd bridge-test
    ```

2.  Install dependencies:
    ```bash
    npm install
    ```

3.  Buat file `.env` dari contoh:
    ```bash
    cp .env.example .env
    ```

4.  Isi konfigurasi di `.env`:
    -   `RPC_URL`: URL RPC network source (misal Mantle Sepolia).
    -   `PRIVATE_KEY`: Private key wallet pengirim (pastikan ada saldo native token untuk gas).
    -   `BRIDGE_LAYER_ADDRESS`: Alamat kontrak `BridgeLayer` yang sudah dideploy.
    -   `MIDRX_ADDRESS`, `MUSDT_ADDRESS`, `MUSDC_ADDRESS`: Alamat token mock yang sudah dideploy.

## Menjalankan Test

Script `test-bridge.js` mendukung argumen untuk memilih token yang akan ditest.

### Syntax
```bash
node test-bridge.js [TOKEN_SYMBOL]
```

### Contoh

Test bridging **mIDRX**:
```bash
node test-bridge.js mIDRX
```

Test bridging **mUSDT**:
```bash
node test-bridge.js mUSDT
```

Test bridging **mUSDC**:
```bash
node test-bridge.js mUSDC
```

Jika dijalankan tanpa argumen, defaultnya akan menggunakan `mIDRX`.

## Apa yang dilakukan script ini?

1.  Mengecek allowance token ke `BridgeLayer`.
2.  Melakukan `approve` jika allowance kurang.
3.  Memanggil fungsi `bridge` di `BridgeLayer` untuk mengirim token ke chain tujuan (hardcoded chainId `84532` / Base Sepolia di dalam script, bisa disesuaikan jika perlu).
