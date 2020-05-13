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