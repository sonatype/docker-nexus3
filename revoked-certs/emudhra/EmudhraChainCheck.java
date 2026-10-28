/*
 * Copyright (c) 2017-present Sonatype, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.math.BigInteger;
import java.security.KeyStore;
import java.security.cert.CertPath;
import java.security.cert.CertPathValidator;
import java.security.cert.CertificateFactory;
import java.security.cert.PKIXParameters;
import java.security.cert.TrustAnchor;
import java.security.cert.X509Certificate;
import java.security.interfaces.ECPublicKey;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Date;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import javax.net.ssl.TrustManagerFactory;
import javax.net.ssl.X509TrustManager;

/**
 * Build-time check that this JRE rejects every certificate chain served by the eMudhra advisory's test hosts
 * (https://emudhra.we-have-a-problem.com/, CLM-55187), using the trust store the JRE loads by default.
 *
 * <p>For each chain it also builds re-encoded copies of the compromised intermediate that keep a valid signature
 * from the same issuer, without that issuer's private key: ECDSA {@code s -> n-s}, and for RSA an outer
 * signatureAlgorithm without its NULL parameters. Such a copy has a different SHA-256, so
 * {@code lib/security/blocked.certs} does not list it; only removing the root it chains to stops it.
 *
 * <p>Validation runs at a fixed date, inside every certificate's validity window, so the result does not change when
 * the test hosts' leaf certificates expire. Exits 0 only if every chain and every re-encoded variant is rejected.
 *
 * <p>Usage: {@code java EmudhraChainCheck.java <directory of PEM chains, leaf first> <PEM file of the advisory's
 * roots>}. The roots are used only to re-sign-check the re-encoded variants of chains that end at a cross-signed
 * intermediate; trust is always decided by the JRE's own trust store.
 */
public class EmudhraChainCheck
{
  private static final Date VALIDATION_DATE = Date.from(Instant.parse("2026-11-01T00:00:00Z"));

  /** Issuers for chains that end at a cross-signed intermediate: the advisory's roots.json. Set in main. */
  private static List<X509Certificate> ROOTS = List.of();

  public static void main(String[] args) throws Exception {
    File[] files = new File(args[0]).listFiles((dir, name) -> name.endsWith(".pem"));
    if (files == null || files.length == 0) {
      System.err.println("ERROR: no PEM chains in " + args[0]);
      System.exit(1);
    }
    Arrays.sort(files);
    File roots = new File(args[1]);
    ROOTS = readChain(CertificateFactory.getInstance("X.509"), roots);
    if (ROOTS.isEmpty()) {
      System.err.println("ERROR: no root certificates in " + roots);
      System.exit(1);
    }

    Set<TrustAnchor> anchors = defaultTrustAnchors();
    CertificateFactory factory = CertificateFactory.getInstance("X.509");
    int checked = 0;
    List<String> trusted = new ArrayList<>();
    for (File file : files) {
      List<X509Certificate> chain = readChain(factory, file);
      if (chain.size() < 2) {
        System.err.println("ERROR: " + file.getName() + " holds no intermediate");
        System.exit(1);
      }
      checked++;
      if (validates(factory, anchors, chain)) {
        trusted.add(file.getName());
      }
      X509Certificate issuer = chain.size() > 2 ? chain.get(2) : issuerAmong(chain.get(1), ROOTS);
      if (issuer == null) {
        System.err.println("ERROR: no issuer for the intermediate in " + file.getName());
        System.exit(1);
      }
      for (X509Certificate variant : reencodedVariants(factory, chain.get(1), issuer)) {
        List<X509Certificate> forged = new ArrayList<>(chain);
        forged.set(1, variant);
        checked++;
        if (validates(factory, anchors, forged)) {
          trusted.add(file.getName() + " (re-encoded intermediate)");
        }
      }
    }

    if (!trusted.isEmpty()) {
      trusted.forEach(name -> System.err.println("ERROR: this JRE trusts " + name));
      System.exit(1);
    }
    System.out.println("This JRE rejects all " + checked + " compromised eMudhra chains and re-encoded variants");
  }

  /** The anchors the default TrustManagerFactory would use, honouring javax.net.ssl.trustStore. */
  private static Set<TrustAnchor> defaultTrustAnchors() throws Exception {
    TrustManagerFactory tmf = TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm());
    tmf.init((KeyStore) null);
    Set<TrustAnchor> anchors = new HashSet<>();
    for (var manager : tmf.getTrustManagers()) {
      if (manager instanceof X509TrustManager x509) {
        for (X509Certificate issuer : x509.getAcceptedIssuers()) {
          anchors.add(new TrustAnchor(issuer, null));
        }
      }
    }
    if (anchors.isEmpty()) {
      throw new IllegalStateException("the default trust store has no trust anchors");
    }
    return anchors;
  }

  /** PKIX validation, with the JRE's blocked.certs applied, at the fixed validation date. */
  private static boolean validates(
      CertificateFactory factory,
      Set<TrustAnchor> anchors,
      List<X509Certificate> chain) throws Exception
  {
    PKIXParameters parameters = new PKIXParameters(anchors);
    parameters.setRevocationEnabled(false);
    parameters.setDate(VALIDATION_DATE);
    CertPath path = factory.generateCertPath(withoutSelfSigned(chain));
    try {
      CertPathValidator.getInstance("PKIX").validate(path, parameters);
      return true;
    }
    catch (Exception e) {
      return false;
    }
  }

  private static List<X509Certificate> withoutSelfSigned(List<X509Certificate> chain) {
    List<X509Certificate> path = new ArrayList<>();
    for (X509Certificate cert : chain) {
      if (!cert.getSubjectX500Principal().equals(cert.getIssuerX500Principal())) {
        path.add(cert);
      }
    }
    return path;
  }

  private static List<X509Certificate> readChain(CertificateFactory factory, File file) throws Exception {
    try (InputStream in = new FileInputStream(file)) {
      List<X509Certificate> chain = new ArrayList<>();
      factory.generateCertificates(in).forEach(cert -> chain.add((X509Certificate) cert));
      return chain;
    }
  }

  /**
   * Copies of {@code cert} with different DER bytes whose signature still verifies under {@code issuer}'s key.
   */
  private static List<X509Certificate> reencodedVariants(
      CertificateFactory factory,
      X509Certificate cert,
      X509Certificate issuer) throws Exception
  {
    byte[] der = cert.getEncoded();
    Der outer = Der.at(der, 0);
    Der tbs = Der.at(der, outer.contentStart());
    Der algorithm = Der.at(der, tbs.end());
    Der signature = Der.at(der, algorithm.end());
    byte[] tbsBytes = tbs.bytes(der);
    byte[] algorithmBytes = algorithm.bytes(der);
    byte[] signatureValue = Arrays.copyOfRange(der, signature.contentStart() + 1, signature.end());

    List<byte[]> candidates = new ArrayList<>();
    if (cert.getSigAlgName().contains("ECDSA") && issuer != null && issuer.getPublicKey() instanceof ECPublicKey key) {
      Der sequence = Der.at(signatureValue, 0);
      Der r = Der.at(signatureValue, sequence.contentStart());
      Der s = Der.at(signatureValue, r.end());
      BigInteger negated = key.getParams().getOrder().subtract(new BigInteger(s.content(signatureValue)));
      byte[] newSignature = Der.encode(0x30, concat(r.bytes(signatureValue), Der.encode(0x02, negated.toByteArray())));
      candidates.add(Der.encode(0x30, concat(tbsBytes, algorithmBytes, bitString(newSignature))));
    }
    if (cert.getSigAlgName().contains("RSA")) {
      // Drop the NULL parameters from the outer signatureAlgorithm only. The signature covers the TBSCertificate, so
      // it stays valid, and the JDK accepts the mismatch with the inner AlgorithmIdentifier.
      Der algorithmSequence = Der.at(algorithmBytes, 0);
      Der oid = Der.at(algorithmBytes, algorithmSequence.contentStart());
      if (oid.end() < algorithmSequence.end()) {
        byte[] withoutNull = Der.encode(0x30, oid.bytes(algorithmBytes));
        candidates.add(Der.encode(0x30, concat(tbsBytes, withoutNull, bitString(signatureValue))));
      }
    }

    List<X509Certificate> variants = new ArrayList<>();
    for (byte[] candidate : candidates) {
      X509Certificate variant;
      try {
        variant = (X509Certificate) factory.generateCertificate(new ByteArrayInputStream(candidate));
      }
      catch (Exception e) {
        continue;
      }
      if (verifiesUnder(variant, issuer)) {
        variants.add(variant);
      }
    }
    return variants;
  }

  private static X509Certificate issuerAmong(X509Certificate cert, List<X509Certificate> candidates) {
    for (X509Certificate candidate : candidates) {
      if (candidate.getSubjectX500Principal().equals(cert.getIssuerX500Principal()) && verifiesUnder(cert, candidate)) {
        return candidate;
      }
    }
    return null;
  }

  private static boolean verifiesUnder(X509Certificate cert, X509Certificate issuer) {
    try {
      cert.verify(issuer.getPublicKey());
      return true;
    }
    catch (Exception e) {
      return false;
    }
  }

  private static byte[] bitString(byte[] value) {
    return Der.encode(0x03, concat(new byte[]{0}, value));
  }

  private static byte[] concat(byte[]... parts) {
    ByteArrayOutputStream out = new ByteArrayOutputStream();
    for (byte[] part : parts) {
      out.writeBytes(part);
    }
    return out.toByteArray();
  }

  /** A DER TLV located in a byte array. */
  private record Der(int start, int contentStart, int end)
  {
    static Der at(byte[] data, int offset) {
      int length = data[offset + 1] & 0xff;
      int header = 2;
      if ((length & 0x80) != 0) {
        int count = length & 0x7f;
        length = 0;
        for (int i = 0; i < count; i++) {
          length = (length << 8) | (data[offset + 2 + i] & 0xff);
        }
        header += count;
      }
      return new Der(offset, offset + header, offset + header + length);
    }

    byte[] bytes(byte[] data) {
      return Arrays.copyOfRange(data, start, end);
    }

    byte[] content(byte[] data) {
      return Arrays.copyOfRange(data, contentStart, end);
    }

    static byte[] encode(int tag, byte[] content) {
      ByteArrayOutputStream out = new ByteArrayOutputStream();
      out.write(tag);
      int length = content.length;
      if (length < 0x80) {
        out.write(length);
      }
      else if (length < 0x100) {
        out.write(0x81);
        out.write(length);
      }
      else {
        out.write(0x82);
        out.write(length >> 8);
        out.write(length & 0xff);
      }
      out.writeBytes(content);
      return out.toByteArray();
    }
  }
}
