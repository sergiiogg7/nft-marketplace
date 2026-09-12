/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  webpack: (config) => {
    // The wagmi baseAccount connector (bundled in the connectors barrel) pulls in
    // @base-org/account -> @coinbase/cdp-sdk -> optional @x402/* payment modules that
    // aren't installed. We only use the injected (MetaMask) connector, so cut the whole
    // subtree by stubbing its roots to empty modules. Prevents module-not-found in both
    // dev and build.
    config.resolve.alias = {
      ...config.resolve.alias,
      "@base-org/account": false,
      "@coinbase/cdp-sdk": false,
      // optional deps of unused connectors (metaMask RN storage, walletconnect logger)
      "@react-native-async-storage/async-storage": false,
      "pino-pretty": false,
    };
    return config;
  },
};

export default nextConfig;
