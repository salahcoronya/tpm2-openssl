# Identity Certificates

## Certificate Signing

The tpm2 provider implements all operations required for certificate signing.
Therefore, the
[`openssl req`](https://www.openssl.org/docs/manmaster/man1/openssl-req.html)
commands work as usual.

For example, to generate a new TPM-based key and a self-signed certificate:
```
openssl req -provider tpm2 -x509 -subj "/C=GB/CN=foo" -keyout testkey.pem -out testcert.pem
```

Or, to create a Certificate Signing Request (CSR) based on a persistent
Attestation Key at a given handle, previously created with `tpm2_createak` and
`tpm2_evictcontrol`:
```
openssl req -provider tpm2 -new -subj "/C=GB/CN=foo" -key handle:0x81000000 -out testcsr.pem
```

If the key is not associated with any specific algorithm you may define the
hash algorithm using the `-digest` parameter and the padding scheme using the
`-sigopt pad-mode:` parameter.


## TLS Handshake

The tpm2 provider implements all operations required for establishing a
TLS (e.g. HTTPS) connection authenticated using a TPM-based private key.
To perform the TLS handshake you need to:
 * Load the tpm2 provider to get support of TPM-based private keys.
 * Load the default provider to get a faster and wider set of symmetric ciphers.
 * Exclude TPM2 hashes, which are incompatible with the TLS implementation.

When using a restricted signing key, which is associated with a specific hash
algorithm, you also need to limit the signature algorithms (using `-sigalgs`
or `SSL_CTX_set1_sigalgs`) to those supported by the key. The argument should
be a colon separated list of TLSv1.3 algorithm names in order of decreasing
preference.

The following TLSv1.2 and TLSv1.3 signature algorithms are supported:

| key      | pad-mode | digest | TLSv1.3 name           |
| -------- | -------- | ------ | ---------------------- |
| RSA      | pkcs1    | sha1   | rsa_pkcs1_sha1         |
| RSA      | pkcs1    | sha256 | rsa_pkcs1_sha256       |
| RSA      | pkcs1    | sha384 | rsa_pkcs1_sha384       |
| RSA      | pkcs1    | sha512 | rsa_pkcs1_sha512       |
| RSA      | pss      | sha256 | rsa_pss_rsae_sha256    |
| RSA      | pss      | sha384 | rsa_pss_rsae_sha384    |
| RSA      | pss      | sha512 | rsa_pss_rsae_sha512    |
| RSA-PSS  | pss      | sha256 | rsa_pss_pss_sha256     |
| RSA-PSS  | pss      | sha384 | rsa_pss_pss_sha384     |
| RSA-PSS  | pss      | sha512 | rsa_pss_pss_sha512     |
| EC P-256 | ecdsa    | sha256 | ecdsa_secp256r1_sha256 |
| EC P-384 | ecdsa    | sha384 | ecdsa_secp384r1_sha384 |
| EC P-512 | ecdsa    | sha512 | ecdsa_secp521r1_sha512 |

Please note that the **pkcs1** pad-modes are ignored in TLSv1.3 and will not be
negotiated.

To start a test server using the key and X.509 certificate created in the
previous section do:
```
openssl s_server -provider tpm2 -provider default -propquery ?provider=tpm2,tpm2.digest!=yes \
                 -accept 4443 -www -key testkey.pem -cert testcert.pem -sigalgs "rsa_pkcs1_sha256"
```

The `-key` can be also specified using a persistent key handle.

Once the server is started you can access it using the standard `curl`:
```
curl --cacert testcert.pem https://localhost:4443/
```