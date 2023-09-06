import { NativeModules } from 'react-native'

const { RNFastCrypto } = NativeModules

const normalizeFilePath = (path: string) => (path.startsWith('file://') ? path.slice(7) : path);

export async function methodByString(method: string, jsonParams: string) {
  const result = await RNFastCrypto.moneroCore(method, jsonParams)
  return result
}

export async function readSettings(dirpath: string, filePrefix: string) {
  return await RNFastCrypto.readSettings(normalizeFilePath(dirpath), filePrefix);
}

async function publicKeyCreate(privateKey: Uint8Array, compressed: boolean) {
  const privateKeyHex = base16.stringify(privateKey)
  const publicKeyHex: string = await RNFastCrypto.secp256k1EcPubkeyCreate(
    privateKeyHex,
    compressed
  )
  const outBuf = base16.parse(publicKeyHex, { out: Buffer.allocUnsafe })
  return outBuf
}

async function privateKeyTweakAdd(privateKey: Uint8Array, tweak: Uint8Array) {
  const privateKeyHex = base16.stringify(privateKey)
  const tweakHex = base16.stringify(tweak)
  const privateKeyTweakedHex: string =
    await RNFastCrypto.secp256k1EcPrivkeyTweakAdd(privateKeyHex, tweakHex)
  const outBuf = base16.parse(privateKeyTweakedHex, {
    out: Buffer.allocUnsafe
  })
  return outBuf
}

async function publicKeyTweakAdd(
  publicKey: Uint8Array,
  tweak: Uint8Array,
  compressed: boolean
) {
  const publicKeyHex = base16.stringify(publicKey)
  const tweakHex = base16.stringify(tweak)
  const publickKeyTweakedHex: string =
    await RNFastCrypto.secp256k1EcPubkeyTweakAdd(
      publicKeyHex,
      tweakHex,
      compressed
    )
  const outBuf = base16.parse(publickKeyTweakedHex, {
    out: Buffer.allocUnsafe
  })
  return outBuf
}

export const secp256k1 = {
  publicKeyCreate,
  privateKeyTweakAdd,
  publicKeyTweakAdd
}
