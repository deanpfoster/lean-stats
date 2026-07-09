/-! # LeanTab.Crypto — simple symmetric encryption for catalog secrets

Pure encrypt/decrypt for connection strings stored in the data catalog.
Uses a repeating-key XOR with key stretching (hash-based). This is NOT
cryptographically strong against a determined attacker with the ciphertext
— but it's sufficient for our threat model:

- The catalog file is checked into git
- The key is in an environment variable (never in git)
- The goal is: without the key, the connection string is unreadable
- We're not defending against NSA; we're defending against `git log`

For production use with real security requirements, swap this for
AES-256-GCM via FFI to libsodium. The interface stays the same.
-/

set_option autoImplicit false

namespace LeanTab.Crypto

/-- Simple hash function for key stretching (DJB2 variant, iterated). -/
private def hashKey (key : String) (length : Nat) : ByteArray :=
  -- Generate a pseudorandom byte stream from the key
  let seed := key.foldl (fun h c => h * 33 + c.toNat) 5381
  let bytes := (Array.range length).map fun i =>
    let v := (seed * (i + 1) * 2654435761 + i * 1103515245 + 12345)
    (v % 256).toUInt8
  ⟨bytes⟩

/-- XOR two byte arrays. -/
private def xorBytes (a b : ByteArray) : ByteArray :=
  let len := Nat.min a.size b.size
  ⟨(Array.range len).map fun i => a.get! i ^^^ b.get! i⟩

/-- Encode bytes as hex string. -/
private def toHex (bs : ByteArray) : String :=
  let hexChars : Array Char :=
    #['0', '1', '2', '3', '4', '5', '6', '7',
      '8', '9', 'a', 'b', 'c', 'd', 'e', 'f']
  String.ofList (bs.toList.flatMap fun b =>
    [hexChars.getD (b.toNat / 16) '0', hexChars.getD (b.toNat % 16) '0'])

/-- Decode hex string to bytes. -/
private def fromHex (s : String) : ByteArray :=
  let chars := s.toList
  let pairs := go chars []
  ⟨pairs.toArray⟩
where
  hexVal (c : Char) : UInt8 :=
    if c >= '0' && c <= '9' then (c.toNat - '0'.toNat).toUInt8
    else if c >= 'a' && c <= 'f' then (c.toNat - 'a'.toNat + 10).toUInt8
    else if c >= 'A' && c <= 'F' then (c.toNat - 'A'.toNat + 10).toUInt8
    else 0
  go : List Char → List UInt8 → List UInt8
    | c1 :: c2 :: rest, acc => go rest (acc ++ [hexVal c1 * 16 + hexVal c2])
    | _, acc => acc

/-- Encrypt a plaintext string with a key. Returns hex-encoded ciphertext. -/
def encrypt (key : String) (plaintext : String) : String :=
  let ptBytes := plaintext.toUTF8
  let pad := hashKey key ptBytes.size
  let ct := xorBytes ptBytes pad
  toHex ct

/-- Decrypt a hex-encoded ciphertext with a key. Returns plaintext string. -/
def decrypt (key : String) (ciphertext : String) : Except String String :=
  let ctBytes := fromHex ciphertext
  if ctBytes.size == 0 && ciphertext.length > 0 then
    .error "invalid hex encoding"
  else
    let pad := hashKey key ctBytes.size
    let ptBytes := xorBytes ctBytes pad
    .ok (String.fromUTF8! ptBytes)

/-- An encrypted field in the catalog. -/
structure EncryptedField where
  /-- Hex-encoded ciphertext. -/
  ciphertext : String
  /-- Which environment variable holds the decryption key. -/
  keyEnvVar : String := "LEAN_STATS_CATALOG_KEY"
  /-- Human-readable hint about what this connects to (not secret). -/
  hint : String := ""
  deriving Repr

/-- Encrypt a connection string for storage in the catalog. -/
def encryptForCatalog (key : String) (connStr : String) (hint : String := "") : EncryptedField :=
  { ciphertext := encrypt key connStr, hint }

/-- Decrypt a catalog field. The key comes from the environment (l3m reads it). -/
def decryptCatalogField (key : String) (field : EncryptedField) : Except String String :=
  decrypt key field.ciphertext

end LeanTab.Crypto
