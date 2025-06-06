import { NativeModules } from 'react-native'

const { RNFastCrypto } = NativeModules

const normalizeFilePath = (path) => (path.startsWith('file://') ? path.slice(7) : path);

export async function methodByString(method, jsonParams) {
  const result = await RNFastCrypto.moneroCore(method, jsonParams)
  return result
}

export async function readSettings(dirpath, filePrefix) {
  return await RNFastCrypto.readSettings(normalizeFilePath(dirpath), filePrefix);
}
