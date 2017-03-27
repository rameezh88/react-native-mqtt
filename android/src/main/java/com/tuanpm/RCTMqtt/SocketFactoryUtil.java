package com.tuanpm.RCTMqtt;

import android.content.Context;
import android.util.Log;

import java.io.ByteArrayOutputStream;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.security.KeyFactory;
import java.security.KeyStore;
import java.security.PrivateKey;
import java.security.cert.CertificateException;
import java.security.cert.CertificateFactory;
import java.security.cert.X509Certificate;
import java.security.spec.PKCS8EncodedKeySpec;

import javax.net.ssl.KeyManagerFactory;
import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLSocketFactory;
import javax.net.ssl.TrustManager;
import javax.net.ssl.TrustManagerFactory;
import javax.net.ssl.X509TrustManager;

public class SocketFactoryUtil {

    private static final String TAG = SocketFactoryUtil.class.getSimpleName();

    private SocketFactoryUtil() {        
    }

    private static byte[] readFile(Context ctx, String filename) throws IOException {
        InputStream file = ctx.openFileInput(filename);
        byte[] buf = new byte[1024];
        try {
            ByteArrayOutputStream baos = new ByteArrayOutputStream();
            for (;;) {
                int read = file.read(buf);
                if (read < 0) {
                    break;
                }
                baos.write(buf, 0, read);
            }
            return baos.toByteArray();
        } finally {
            file.close();
        }
    }
    
    public static SSLSocketFactory createSocketFactory(Context ctx, final String caCrtFile, final String crtFile, final String keyFile, final String password, final String protocol) throws Exception {
        // Load CA certificate
        X509Certificate caCert;
        InputStream in = ctx.openFileInput(caCrtFile);
        try {
            CertificateFactory factory = CertificateFactory.getInstance("X509");
            caCert = (X509Certificate) factory.generateCertificate(in);
        } finally {
            in.close();
        }

        
        // Load client certificate
        X509Certificate cert;
        in = ctx.openFileInput(crtFile);
        try {
            CertificateFactory factory = CertificateFactory.getInstance("X.509");
            cert = (X509Certificate) factory.generateCertificate(in);
        } finally {
            in.close();
        }

        
        // Load client private key
        PrivateKey pk = readPrivateKey(ctx, keyFile);
        
                
        // Now, put the above things in Java structures:
        
        // CA certificate is used to authenticate server
        final KeyStore caKs = KeyStore.getInstance(KeyStore.getDefaultType());
        caKs.load(null, null);
        caKs.setCertificateEntry("ca", caCert);
        final TrustManagerFactory tmf = TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm());
        tmf.init(caKs);

        // client key and certificates are sent to server so it can authenticate us
        final char[] passwordArr = ((password == null) ? "" : password).toCharArray();
        final KeyStore ks = KeyStore.getInstance(KeyStore.getDefaultType());
        ks.load(null, null);
        ks.setCertificateEntry("certificate", cert);
        ks.setKeyEntry("private-key", pk, passwordArr, new java.security.cert.Certificate[]{cert});
        final KeyManagerFactory kmf = KeyManagerFactory.getInstance(KeyManagerFactory.getDefaultAlgorithm());
        kmf.init(ks, passwordArr);

        // finally, create SSL socket factory
        final SSLContext context = SSLContext.getInstance(protocol);
        context.init(kmf.getKeyManagers(), tmf.getTrustManagers(), null);

        return context.getSocketFactory();
    }

    private static PrivateKey readPrivateKey(Context ctx, String filename) throws Exception {
        //final byte[] keyBytes = Files.readAllBytes(new File(filename).toPath());
        final byte[] keyBytes = readFile(ctx, filename);
        final PKCS8EncodedKeySpec spec = new PKCS8EncodedKeySpec(keyBytes);
        final KeyFactory kf = KeyFactory.getInstance("RSA");
        return kf.generatePrivate(spec);
    }
        
}
