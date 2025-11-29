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
        Stargate["Stargate <br>(Liquidity Transport)"]
        Axelar["Axelar <br>(Interoperability)"]
        L0["LayerZero <br>(Omnichain)"]
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
    BridgeMgr -- Route: Stargate --> Stargate
    BridgeMgr -- Route: Axelar --> Axelar
    BridgeMgr -- Route: LayerZero --> L0
    Stargate -.-> ChainEth
    Axelar -.-> ChainArb
    L0 -.-> ChainOp
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
     Stargate:::ext
     Axelar:::ext
     L0:::ext
    classDef core fill:#f9f,stroke:#333,stroke-width:2px
    classDef vault fill:#ccf,stroke:#333,stroke-width:2px
    classDef ext fill:#eee,stroke:#333,stroke-dasharray: 5 5
```

---

## Detail Komponen (Mantle Ecosystem)

### A. Main Contract (Controller)
*   **Peran:** Sentral otorisasi dan orkestrasi (Facade).
*   **Fungsi Detail:**
    *   `depositToYield(token, amount, protocol)`: Mengarahkan user ke Smart Router untuk deposit ke protokol pilihan.
    *   `executeSwap(tokenIn, tokenOut, amount, route)`: Memanggil SwapRouter untuk eksekusi trade.
    *   `bridgeAsset(token, amount, destChain, bridgeProvider)`: Menginisiasi transaksi cross-chain via BridgeManager.
    *   **Keamanan:** Menerapkan `nonReentrant` dan `onlyOwner`/`onlyGovernance` untuk fungsi administratif.

### B. Yield Routing Layer (Smart Router)
Layer ini menggantikan konsep "Vault" tradisional. Dana tidak disimpan di kontrak ini, melainkan langsung diteruskan ke protokol tujuan (Non-Custodial).

*   **Smart Yield Router:**
    *   **Fungsi:** Menerima aset dari user, memanggil adapter yang sesuai, dan mengirimkan bukti deposit (aToken/cToken) kembali ke user.
    *   **Direct Ownership:** User memegang kendali penuh atas aset mereka di protokol lending.
    *   **Fleksibilitas:** User bisa memilih protokol mana (INIT, MethLab, Aurelius) yang ingin digunakan.

**Adapter Protokol (Mantle Top 3):**
1.  **INIT Capital Adapter:**
    *   *Protokol:* **INIT Capital** (Liquidity Hook Money Market).
    *   *Integrasi:* `deposit()` memanggil `InitCore.supply()`, `withdraw()` memanggil `InitCore.withdraw()`.
2.  **MethLab Adapter:**
    *   *Protokol:* **MethLab** (Liquidation-free, Oracle-less Lending).
    *   *Integrasi:* Adapter mengelola interaksi dengan pasar Fixed Rate/Fixed Term.
3.  **Aurelius Adapter:**
    *   *Protokol:* **Aurelius Finance** (CDP & Lending).
    *   *Integrasi:* Supply collateral untuk minting stablecoin atau lending pool.

### C. Swap/DEX Layer (Mantle Top 3)
Layer ini menangani pertukaran aset dengan likuiditas terdalam di Mantle.

1.  **Merchant Moe Adapter:**
    *   *Protokol:* **Merchant Moe** (DEX Utama Mantle).
    *   *Teknis:* Menggunakan Router V2/V3 standard.
    *   *Keunggulan:* Likuiditas terdalam untuk pair native Mantle (MNT, mETH). Adapter akan mencari jalur dengan slippage terendah.
2.  **Vertex Adapter:**
    *   *Protokol:* **Vertex Protocol**.
    *   *Teknis:* Interaksi dengan on-chain clearinghouse atau smart contract Vertex.
    *   *Keunggulan:* Eksekusi ultra-cepat dan efisien modal (cross-margin). Cocok untuk swap size besar atau hedging strategi.
3.  **FusionX Adapter:**
    *   *Protokol:* **FusionX**.
    *   *Teknis:* V3 Concentrated Liquidity AMM.
    *   *Keunggulan:* Efisiensi modal tinggi untuk stable pair (misal USDC/USDT) atau correlated assets (ETH/mETH).

### D. Bridge Layer (Top 3 Interoperability)
Layer ini menghubungkan aplikasi dengan chain lain (Omnichain).

1.  **Stargate Adapter:**
    *   *Protokol:* **Stargate**.
    *   *Teknologi:* LayerZero messaging + Unified Liquidity Pools.
    *   *Flow:* User deposit di Chain A -> Stargate lock -> Pesan via LayerZero -> Stargate Chain B release aset native.
    *   *Keunggulan:* Instant finality (probabilistik) dan menerima aset native (bukan wrapped token).
2.  **Axelar Adapter:**
    *   *Protokol:* **Axelar**.
    *   *Teknologi:* Gateway Contract & Axelar Network (Cosmos SDK chain).
    *   *Flow:* Memanggil `callContractWithToken` pada Axelar Gateway. Validator Axelar memverifikasi dan merelay pesan ke chain tujuan.
    *   *Keunggulan:* General Message Passing (GMP) yang sangat kuat, bisa memanggil fungsi smart contract di chain tujuan (misal: Deposit ke Vault di chain lain dalam 1 klik).
3.  **LayerZero Adapter:**
    *   *Protokol:* **LayerZero**.
    *   *Teknologi:* Ultra Light Nodes (ULN) & Relayers.
    *   *Flow:* Mengirim payload pesan via `endpoint.send()`. Aplikasi mendefinisikan logic eksekusi di sisi penerima (`lzReceive`).
    *   *Keunggulan:* Standar industri untuk interoperabilitas, sangat fleksibel untuk membangun OFT (Omnichain Fungible Token).

---

## 📋 PART 1: PROJECT STRUCTURE (Foundry)

Berikut adalah struktur proyek yang disesuaikan dengan konsep **Smart Router**.

```text
textdefi-aggregator/
├── src/                                # Source contracts
│   ├── core/
│   │   ├── MainController.sol          # Main entry point (Facade)
│   │   ├── AdapterRegistry.sol         # Adapter management
│   │   └── AccessControl.sol           # RBAC
│   │
│   ├── yield/                          # Yield Routing Layer
│   │   ├── SmartYieldRouter.sol        # Router Logic (Non-Custodial)
│   │   ├── adapters/
│   │   │   ├── InitCapitalAdapter.sol
│   │   │   ├── MethLabAdapter.sol
│   │   │   ├── AureliusAdapter.sol
│   │   │   └── BaseAdapter.sol         # Abstract base adapter
│   │   └── IYieldAdapter.sol
│   │
│   ├── swap/
│   │   ├── SwapLayer.sol               # Swap orchestration
│   │   ├── adapters/
│   │   │   ├── MerchantMoeAdapter.sol
│   │   │   ├── VertexAdapter.sol
│   │   │   └── FusionXAdapter.sol
│   │   └── ISwapAdapter.sol
│   │
│   ├── bridge/
│   │   ├── BridgeLayer.sol             # Bridge orchestration
│   │   ├── adapters/
│   │   │   ├── StargateBridgeAdapter.sol
│   │   │   ├── AxelarBridgeAdapter.sol
│   │   │   └── LayerZeroBridgeAdapter.sol
│   │   └── IBridgeAdapter.sol
│   │
│   └── interfaces/                     # Shared interfaces
│       ├── IERC20.sol
│       └── IAggregator.sol
│
├── test/                               # Tests
│   ├── unit/
│   │   ├── Router.t.sol                # Test Smart Router
│   │   ├── Swap.t.sol
│   │   └── Bridge.t.sol
│   │
│   └── integration/
│       ├── RouterSwap.t.sol
│       └── FullFlow.t.sol
│
├── script/                             # Deployment scripts
│   ├── Deploy.s.sol
│   ├── RegisterAdapters.s.sol
│   └── Verify.s.sol
│
├── lib/                                # Dependencies
├── foundry.toml                        # Foundry configuration
├── .env.example
└── README.md
```
