import { NativeModules } from 'react-native'

const { RNFastCrypto } = NativeModules

export async function moneroMethodByString(method: string, jsonParams: string) {
  const result = await RNFastCrypto.moneroCore(method, jsonParams)
  return result
}

export async function keygenMethodByString(method: string, jsonParams: string) {
  const result = await RNFastCrypto.keygen(method, jsonParams)
  return result
}
