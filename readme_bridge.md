# Modul Bridge Tilepmony

Dokumen ini menjelaskan cara kerja lapisan bridge di folder `src/bridge`, bagaimana mengkonfigurasi adapter Axelar, serta langkah-langkah yang diperlukan sebelum melakukan bridging aset.

## Gambaran Umum

- **BridgeLayer (`src/bridge/BridgeLayer.sol`)** adalah fasad tunggal yang dipanggil aplikasi lain. Kontrak ini memilih adapter yang tepat dan mem-forward native value/gas sekaligus data bridging.
- **Adapter** mengimplementasikan `IBridgeAdapter` dan bertanggung jawab pada logika spesifik jaringan/penyedia bridge. Saat ini hanya tersedia `AxelarBridgeAdapter`.
- Desain ini memungkinkan menambahkan adapter baru tanpa mengubah aplikasi yang sudah memanggil `BridgeLayer`.

## Komponen Kontrak

| Kontrak | Peran |
| --- | --- |
| `BridgeLayer` | Menyimpan alamat adapter aktif, memancarkan event `BridgeRequested`, lalu meneruskan eksekusi ke adapter. |
| `AxelarBridgeAdapter` | Mengunci token ERC20, menyiapkan payload, membayar gas melalui `IAxelarGasService`, dan memanggil `IAxelarGateway.callContract`. |
| `IAxelarGateway` & `IAxelarGasService` | Interface minimal untuk Axelar GMP. |
| `IBridgeAdapter` | Interface generik yang harus diimplementasi adapter lain (signature fungsi `bridge`). |

### Event Penting

- `BridgeLayer.AdapterUpdated(adapter)`: membantu front-end mengamati pergantian adapter.
- `BridgeLayer.BridgeRequested(token, amount, dstChainId, recipient)`: dicatat sebelum token dikunci.
- `AxelarBridgeAdapter.DestinationSet(chainId, axelarChain, receiver)`: memastikan mapping chain tujuan terdokumentasi on-chain.

## Alur Kerja Bridging

1. **Owner menentukan adapter aktif**\
   Panggil `BridgeLayer.setAxelarAdapter(address adapter)` setelah adapter dideploy.
2. **Owner adapter mendaftarkan destinasi**\
   Untuk setiap `dstChainId`, panggil `AxelarBridgeAdapter.setDestination(chainId, axelarChainName, receiverAddressString)`. `axelarChainName` harus cocok dengan nama chain versi Axelar (mis. `"base-sepolia"`), sedangkan `receiver` adalah alamat kontrak tujuan dalam format string Axelar.
3. **Pengguna menyiapkan token**\
   Pengguna melakukan `IERC20.approve(BridgeLayer, amount)` agar adapter dapat men-transfer token menggunakan `transferFrom`.
4. **Eksekusi bridge**\
   Pengguna memanggil `BridgeLayer.bridge(token, amount, dstChainId, recipient, extraData)` dan dapat menyertakan `msg.value` untuk membayar gas Axelar. Fungsi ini akan:
   - Mengirim event `BridgeRequested`.
   - Meneruskan panggilan ke adapter.
5. **Adapter memproses**\
   `AxelarBridgeAdapter` mengunci token di kontraknya, menyusun payload `abi.encode(token, amount, recipient, extraData)`, membayar gas jika ada `msg.value`, lalu memanggil `gateway.callContract`.
6. **Kontrak tujuan**\
   Kontrak di chain tujuan menerima payload, membaca data `(token, amount, recipient, extraData)`, dan melakukan aksi (mint/mirror transfer) sesuai kebutuhan aplikasi.

## Konfigurasi & Deployment

### Persiapan File `.env`

1. Salin contoh konfigurasi lalu isi variabel penting:
   ```shell
   cp .env.example .env
   ```
2. Lengkapi nilai berikut:
    - `OWNER` & `PRIVATE_KEY`: alamat/kunci wallet deployer (jangan pernah commit nilai asli).
    - `RPC_URL`: endpoint RPC chain sumber yang akan menjalankan BridgeLayer dan adapter.
    - `ETHERSCAN_API_KEY`: API key untuk Etherscan/Basescan/Mantlescan (dipakai saat verifikasi).
    - `AXELAR_GATEWAY` & `AXELAR_GAS_SERVICE`: alamat resmi Axelar untuk chain sumber.
    - `DST_CHAIN_IDS`: daftar chainId tujuan yang ingin diaktifkan (pisahkan dengan koma).
    - `AXELAR_CHAIN_NAMES`: nama chain Axelar yang berurutan dengan `DST_CHAIN_IDS`.
   - `AXELAR_DEST_RECEIVERS`: alamat kontrak receiver dalam format string (berurutan dengan daftar chainId).
3. Setelah proses deploy, simpan alamat hasil deploy pada `AXELAR_ADAPTER_ADDRESS` dan `BRIDGE_LAYER_ADDRESS` supaya dapat digunakan ulang oleh tooling atau skrip otomasi.

### Langkah Deploy Manual

1. Export variabel `.env` ke shell (opsional).
   ```shell
   set -a && source .env && set +a      # bash/zsh
   ```
2. Deploy `AxelarBridgeAdapter` dengan parameter gateway & gas service:
   ```shell
   forge create src/bridge/adapters/AxelarBridgeAdapter.sol:AxelarBridgeAdapter \
     --rpc-url $RPC_URL \
     --private-key $PRIVATE_KEY \
     --constructor-args $AXELAR_GATEWAY $AXELAR_GAS_SERVICE
   ```
   Catat alamat kontrak dan perbarui `AXELAR_ADAPTER_ADDRESS` di `.env`.
3. Deploy `BridgeLayer`:
   ```shell
   forge create src/bridge/BridgeLayer.sol:BridgeLayer \
     --rpc-url $RPC_URL \
     --private-key $PRIVATE_KEY
   ```
   Catat alamatnya pada `BRIDGE_LAYER_ADDRESS`.
4. Kaitkan adapter dengan bridge layer:
   ```shell
   cast send $BRIDGE_LAYER_ADDRESS \
     "setAxelarAdapter(address)" $AXELAR_ADAPTER_ADDRESS \
     --rpc-url $RPC_URL --private-key $PRIVATE_KEY
   ```
5. Daftarkan destinasi lintas chain. Contoh skrip shell untuk mengiterasi pasangan konfigurasi:
   ```shell
   IFS=',' read -r -a chain_ids <<< "$DST_CHAIN_IDS"
   IFS=',' read -r -a chain_names <<< "$AXELAR_CHAIN_NAMES"
   IFS=',' read -r -a receivers <<< "$AXELAR_DEST_RECEIVERS"

   for idx in "${!chain_ids[@]}"; do
     cast send $AXELAR_ADAPTER_ADDRESS \
       "setDestination(uint256,string,string)" \
       "${chain_ids[$idx]}" "${chain_names[$idx]}" "${receivers[$idx]}" \
       --rpc-url $RPC_URL --private-key $PRIVATE_KEY
   done
   ```
   Pastikan event `DestinationSet` tercatat untuk seluruh kombinasi.
6. (Opsional) Tambahkan adapter lain dengan mengimplementasikan `IBridgeAdapter` dan memanggil `setAxelarAdapter` lagi bila ingin mengganti rute default.

### Verifikasi Kontrak (Etherscan/Basescan)

1. Pastikan `ETHERSCAN_API_KEY` sudah terisi di `.env` dan diexport ke shell.
2. Jalankan verifikasi untuk setiap kontrak (ganti `--chain` sesuai target):
   ```shell
   forge verify-contract \
     --chain base-sepolia \
     $AXELAR_ADAPTER_ADDRESS \
     src/bridge/adapters/AxelarBridgeAdapter.sol:AxelarBridgeAdapter \
     --watch

   forge verify-contract \
     --chain base-sepolia \
     $BRIDGE_LAYER_ADDRESS \
     src/bridge/BridgeLayer.sol:BridgeLayer \
     --watch
   ```
3. Untuk chain lain (mis. Mantle), ganti `--chain mantle-sepolia` atau sesuai Foundry config (`foundry.toml`) dan ulangi perintah di atas. Jika explorer memerlukan URL khusus, Foundry telah dikonfigurasi melalui `[etherscan]` agar menggunakan `ETHERSCAN_API_KEY` yang sama.

### Parameter Penting

- `dstChainId`: menggunakan chain ID EVM standar. Adapter menerjemahkannya ke nama chain Axelar melalui `chainIdToAxelarName`.
- `extraData`: bytes bebas untuk instruksi tambahan (mis. jenis token yang harus dicetak di chain tujuan, data swap, dsb).
- `msg.value` pada `BridgeLayer.bridge`: diteruskan ke `AxelarBridgeAdapter` untuk `gasService.payNativeGasForContractCall`. Jika nol, Axelar dapat menagih biaya di tujuan, namun lebih aman membayar gas dari chain sumber.

## Integrasi Receiver Chain Tujuan

Receiver perlu:

1. Memverifikasi bahwa pemanggil adalah `IAxelarGateway` resmi.
2. Mendecode payload `abi.decode(payload, (address token, uint256 amount, address recipient, bytes extraData))`.
3. Menjalankan logika aplikasi, contoh:
   - Mint token representatif menggunakan `extraData` untuk menentukan pool.
   - Meneruskan bridging ke modul lain.
4. Mencatat event untuk audit.

## Testing & Verifikasi

- Gunakan `forge test` untuk menjalankan seluruh suite. Tambahkan test baru untuk mensimulasikan:
  - Pemanggilan `BridgeLayer.bridge` dengan adapter mock.
  - Unit test pada `AxelarBridgeAdapter` menggunakan mock `IAxelarGateway`/`IAxelarGasService`.
- Contoh target:
  ```shell
  forge test --match-test testBridgeLayer
  forge test --match-contract AxelarBridgeAdapterTest
  ```
- Untuk simulasi manual, gunakan `cast send`:
  ```shell
  cast send <bridgeLayer> "bridge(address,uint256,uint256,address,bytes)" \
    <token> <amount> <dstChainId> <recipient> 0x \
    --value <nativeGas> --private-key <key>
  ```

## Catatan Keamanan

- Fungsi pengaturan (`setAxelarAdapter`, `setDestination`) hanya bisa dipanggil owner. Pastikan kepemilikan dikelola (mis. multisig).
- Token tetap terkunci di `AxelarBridgeAdapter`; lakukan audit dan rencana pemulihan jika terjadi kegagalan di chain tujuan.
- Pengguna harus memantau allowance yang besar untuk mengurangi risiko penyalahgunaan.
- Pertimbangkan untuk menambahkan mekanisme emergency withdraw atau pause bila akan digunakan di lingkungan produksi.

## Struktur Folder

- `src/bridge/BridgeLayer.sol` — kontrak utama layer abstraksi.
- `src/bridge/adapters/AxelarBridgeAdapter.sol` — implementasi adapter Axelar.
- `src/bridge/adapters/IBridgeAdapter.sol` — interface (dapat diperluas ketika adapter baru ditambahkan).
- `src/bridge/interfaces/IAxelarGateway.sol` & `IAxelarGasService.sol` — interface eksternal Axelar.

Dengan mengikuti panduan di atas, modul bridge siap diperluas maupun diintegrasikan dengan komponen Tilepmony lainnya.
