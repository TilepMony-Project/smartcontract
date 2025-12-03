# Dokumentasi Arsitektur Smart Contract: Multi-Protocol DeFi App (Mantle Ecosystem)

Dokumen ini menjelaskan desain teknis untuk aplikasi DeFi yang mengintegrasikan fitur Yield Routing (Smart Router), Swapping, dan Bridging dalam satu ekosistem terpadu, dikhususkan untuk ekosistem **Mantle Network**.

## Diagram Arsitektur Sistem

Berikut adalah diagram arsitektur yang menggambarkan hubungan antar komponen dengan protokol-protokol spesifik di Mantle. Diagram ini menggunakan konsep **Smart Router** untuk fleksibilitas maksimal user.

```mermaid
---
config:
  layout: elk
  look: classic
---
flowchart TB
 subgraph subGraph0["Core Layer"]
        Controller["MainController"]
        Registry["Address Registry"]
  end
 subgraph Adapters["Adapters"]
        AdptInit["INIT Capital Adapter"]
        AdptMeth["MethLab Adapter"]
        AdptAurelius["Aurelius Adapter"]
  end
 subgraph subGraph2["Mantle Yield Protocols"]
        ProtoInit["INIT Capital <br>(Liquidity Hook)"]
        ProtoMeth["MethLab <br>(Fixed Rate/Term)"]
        ProtoAurelius["Aurelius Finance <br>(CDP &amp; Lending)"]
  end
 subgraph subGraph3["Yield Routing Layer"]
        Router["Smart Yield Router <br>(Non-Custodial)"]
        Adapters
        subGraph2
  end
 subgraph DEXs["DEXs"]
        Moe["Merchant Moe"]
        Vertex["Vertex Protocol"]
        FusionX["FusionX"]
  end
 subgraph subGraph5["Swap Layer"]
        SwapRouter["SwapRouter Aggregator"]
        DEXs
 end
 subgraph subGraph6["Cross-Chain Providers"]
        Axelar["Axelar <br>(Interoperability & Messaging)"]
 end
 subgraph subGraph7["Destination Chains"]
        ChainEth["Ethereum"]
        ChainArb["Arbitrum"]
        ChainOp["Optimism"]
  end
 subgraph subGraph8["Bridge Layer"]
        BridgeMgr["BridgeManager"]
        subGraph6
        subGraph7
  end
 subgraph subGraph9["Management & Utils"]
        FeeMgr["FeeManager"]
        RewardDist["RewardDistributor"]
        Gov["GovernanceProxy"]
        Oracle["PriceOracle"]
        Math["MathLib"]
  end
    User(("User")) --> Wallet["User Wallet"]
    Wallet --> Frontend["Frontend DApp"]
    Frontend --> Controller
    Controller -- "1. Yield Deposit" --> Router
    Controller -- "2. Swap Request" --> SwapRouter
    Controller -- "3. Bridge Request" --> BridgeMgr
    Controller -.-> Registry
    Router -- Delegate Call --> AdptInit & AdptMeth & AdptAurelius
    Router -.-> Oracle & Math
    AdptInit <==> ProtoInit
    AdptMeth <==> ProtoMeth
    AdptAurelius <==> ProtoAurelius
    SwapRouter --> Moe & Vertex & FusionX
    BridgeMgr -- Route: Axelar --> Axelar
    Axelar -.-> ChainEth
    Axelar -.-> ChainArb
    Axelar -.-> ChainOp
    Controller -- Collect Fees --> FeeMgr
    Router -- Yield Fees (if any) --> FeeMgr
    FeeMgr --> RewardDist
    Gov -- Admin Control --> Controller
    Gov -- Update Params --> FeeMgr

     Controller:::core
     Registry:::core
     Router:::vault
     AdptInit:::vault
     AdptMeth:::vault
     AdptAurelius:::vault
     ProtoInit:::ext
     ProtoMeth:::ext
     ProtoAurelius:::ext
     Moe:::ext
     Vertex:::ext
     FusionX:::ext
     Axelar:::ext
    classDef core fill:#f9f,stroke:#333,stroke-width:2px
    classDef vault fill:#ccf,stroke:#333,stroke-width:2px
    classDef ext fill:#eee,stroke:#333,stroke-dasharray: 5 5
```

---

## Detail Komponen (Mantle Ecosystem)

### A. Main Contract (Controller)

- **Peran:** Sentral otorisasi dan orkestrasi (Facade).
- **Fungsi Detail:**
  - `depositToYield(token, amount, protocol)`: Mengarahkan user ke Smart Router untuk deposit ke protokol pilihan.
  - `executeSwap(tokenIn, tokenOut, amount, route)`: Memanggil SwapRouter untuk eksekusi trade.
  - `bridgeAsset(token, amount, destChain, bridgeProvider)`: Menginisiasi transaksi cross-chain via BridgeManager.
  - **Keamanan:** Menerapkan `nonReentrant` dan `onlyOwner`/`onlyGovernance` untuk fungsi administratif.

### B. Yield Routing Layer (Smart Router)

Layer ini menggantikan konsep "Vault" tradisional. Dana tidak disimpan di kontrak ini, melainkan langsung diteruskan ke protokol tujuan (Non-Custodial).

- **Smart Yield Router:**
  - **Fungsi:** Menerima aset dari user, memanggil adapter yang sesuai, dan mengirimkan bukti deposit (aToken/cToken) kembali ke user.
  - **Direct Ownership:** User memegang kendali penuh atas aset mereka di protokol lending.
  - **Fleksibilitas:** User bisa memilih protokol mana (INIT, MethLab, Aurelius) yang ingin digunakan.

**Adapter Protokol (Mantle Top 3):**

1.  **INIT Capital Adapter:**
    - _Protokol:_ **INIT Capital** (Liquidity Hook Money Market).
    - _Integrasi:_ `deposit()` memanggil `InitCore.supply()`, `withdraw()` memanggil `InitCore.withdraw()`.
2.  **MethLab Adapter:**
    - _Protokol:_ **MethLab** (Liquidation-free, Oracle-less Lending).
    - _Integrasi:_ Adapter mengelola interaksi dengan pasar Fixed Rate/Fixed Term.
3.  **Aurelius Adapter:**
    - _Protokol:_ **Aurelius Finance** (CDP & Lending).
    - _Integrasi:_ Supply collateral untuk minting stablecoin atau lending pool.

### C. Swap/DEX Layer (Mantle Top 3)

Layer ini menangani pertukaran aset dengan likuiditas terdalam di Mantle.

1.  **Merchant Moe Adapter:**
    - _Protokol:_ **Merchant Moe** (DEX Utama Mantle).
    - _Teknis:_ Menggunakan Router V2/V3 standard.
    - _Keunggulan:_ Likuiditas terdalam untuk pair native Mantle (MNT, mETH). Adapter akan mencari jalur dengan slippage terendah.
2.  **Vertex Adapter:**
    - _Protokol:_ **Vertex Protocol**.
    - _Teknis:_ Interaksi dengan on-chain clearinghouse atau smart contract Vertex.
    - _Keunggulan:_ Eksekusi ultra-cepat dan efisien modal (cross-margin). Cocok untuk swap size besar atau hedging strategi.
3.  **FusionX Adapter:**
    - _Protokol:_ **FusionX**.
    - _Teknis:_ V3 Concentrated Liquidity AMM.
    - _Keunggulan:_ Efisiensi modal tinggi untuk stable pair (misal USDC/USDT) atau correlated assets (ETH/mETH).

### D. Bridge Layer (Axelar-first & Extensible)

Layer ini menghubungkan aplikasi dengan chain lain (Omnichain). Untuk saat ini hanya **Axelar** yang aktif karena token lintas-chain yang tersedia baru mendukung standar Axelar. Struktur kontrak tetap modular sehingga Stargate atau LayerZero dapat diaktifkan kembali cukup dengan menambahkan router/adapter baru.

- **Axelar Adapter (aktif):**
  - _Teknologi:_ Gateway Contract & Axelar Network (Cosmos SDK chain).
  - _Flow:_ Memanggil `transferRemote` pada token bergaya Axelar. Validator Axelar memverifikasi dan merelay pesan ke chain tujuan.
  - _Keunggulan:_ General Message Passing (GMP) yang kuat sehingga bisa menjalankan call lintas chain dalam satu transaksi user.
- **Penyedia lain (dinonaktifkan sementara):**
  - Kerangka router/adapter tetap ada melalui `BaseBridgeRouter` dan `BaseBridgeAdapter`.
  - Saat token/protokol baru siap, cukup menambahkan turunan baru dan mendaftarkannya di registry/FE tanpa mengubah arsitektur inti.

---

## ðŸ“‹ PART 1: PROJECT STRUCTURE (Foundry)

Berikut adalah struktur proyek yang disesuaikan dengan konsep **Smart Router**.

```text
textdefi-aggregator/
â”œâ”€â”€ src/                                # Source contracts
â”‚   â”œâ”€â”€ core/
â”‚   â”‚   â”œâ”€â”€ MainController.sol          # Main entry point (Facade)
â”‚   â”‚   â”œâ”€â”€ AdapterRegistry.sol         # Adapter management
â”‚   â”‚   â””â”€â”€ AccessControl.sol           # RBAC
â”‚   â”‚
â”‚   â”œâ”€â”€ yield/                          # Yield Routing Layer
â”‚   â”‚   â”œâ”€â”€ SmartYieldRouter.sol        # Router Logic (Non-Custodial)
â”‚   â”‚   â”œâ”€â”€ adapters/
â”‚   â”‚   â”‚   â”œâ”€â”€ InitCapitalAdapter.sol
â”‚   â”‚   â”‚   â”œâ”€â”€ MethLabAdapter.sol
â”‚   â”‚   â”‚   â”œâ”€â”€ AureliusAdapter.sol
â”‚   â”‚   â”‚   â””â”€â”€ BaseAdapter.sol         # Abstract base adapter
â”‚   â”‚   â””â”€â”€ IYieldAdapter.sol
â”‚   â”‚
â”‚   â”œâ”€â”€ swap/                           # Swap orchestration
â”‚   â”‚   â”œâ”€â”€ SwapAggregator.sol
â”‚   â”‚   â”œâ”€â”€ adapters/
â”‚   â”‚   â”‚   â”œâ”€â”€ FusionXAdapter.sol
â”‚   â”‚   â”‚   â”œâ”€â”€ MerchantMoeAdapter.sol
â”‚   â”‚   â”‚   â”œâ”€â”€ VertexAdapter.sol
â”‚   â”‚   â”œâ”€â”€ interfaces/
â”‚   â”‚   â”‚   â””â”€â”€ ISwapAdapter.sol
â”‚   â”‚   â”‚   â””â”€â”€ ISwapAggregator.sol
â”‚   â”‚   â”‚   â””â”€â”€ ISwapRouter.sol
â”‚   â”‚   â””â”€â”€ routers/
â”‚   â”‚       â”œâ”€â”€ FusionXRouter.sol
â”‚   â”‚       â”œâ”€â”€ MerchantMoeRouter.sol
â”‚   â”‚       â””â”€â”€ VertexRouter.sol
â”‚   â”‚
â”‚   â”œâ”€â”€ token/                          # Stablecoin tokens
â”‚   â”‚   â”œâ”€â”€ MockIDRX.sol
â”‚   â”‚   â””â”€â”€ MockUSDT.sol
â”‚   â”‚
â”‚   â”œâ”€â”€ bridge/
â”‚   â”‚   â”œâ”€â”€ BridgeLayer.sol             # Bridge orchestration
â”‚   â”‚   â”œâ”€â”€ adapters/
â”‚   â”‚   â”‚   â”œâ”€â”€ AxelarBridgeAdapter.sol
â”‚   â”‚   â””â”€â”€ IBridgeAdapter.sol
â”‚   â”‚
â”‚   â””â”€â”€ interfaces/                     # Shared interfaces
â”‚       â”œâ”€â”€ IERC20.sol
â”‚       â””â”€â”€ IAggregator.sol
â”‚
â”œâ”€â”€ test/                               # Tests
â”‚   â”œâ”€â”€ unit/
â”‚   â”‚   â”œâ”€â”€ Router.t.sol                # Test Smart Router
â”‚   â”‚   â”œâ”€â”€ Swap.t.sol
â”‚   â”‚   â””â”€â”€ Bridge.t.sol
â”‚   â”‚
â”‚   â””â”€â”€ integration/
â”‚       â”œâ”€â”€ RouterSwap.t.sol
â”‚       â””â”€â”€ FullFlow.t.sol
â”‚
â”œâ”€â”€ script/                             # Deployment scripts
â”‚   â”œâ”€â”€ Deploy.s.sol
â”‚   â”œâ”€â”€ RegisterAdapters.s.sol
â”‚   â””â”€â”€ Verify.s.sol
â”‚
â”œâ”€â”€ lib/                                # Dependencies
â”œâ”€â”€ foundry.toml                        # Foundry configuration
â”œâ”€â”€ .env.example
â”œâ”€â”€ Makefile
â””â”€â”€ README.md
```

