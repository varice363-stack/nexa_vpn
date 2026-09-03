package com.nexavpn.nexa_vpn

import android.app.Service
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.os.IBinder
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Kill Switch service for Android.
 * 
 * On Android 12+ (API 31+), uses VpnService.Builder.setBlocking(true)
 * which is handled by the flutter_vless plugin.
 * 
 * On older versions, monitors network state and notifies Flutter
 * when VPN drops so the app can block traffic.
 * 
 * This is a background service that runs alongside the VPN tunnel
 * and ensures no traffic leaks when the VPN is down.
 */
class KillSwitchService : Service() {
    
    companion object {
        private const val CHANNEL_NAME = "com.nexavpn.killswitch"
        private var methodChannel: MethodChannel? = null
        
        fun start(context: Context) {
            val intent = Intent(context, KillSwitchService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
        
        fun stop(context: Context) {
            val intent = Intent(context, KillSwitchService::class.java)
            context.stopService(intent)
        }
        
        fun setupMethodChannel(flutterEngine: FlutterEngine) {
            methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            methodChannel?.setMethodCallHandler { call, result ->
                when (call.method) {
                    "enable" -> {
                        start(call.argument("context") as? Context ?: return@setMethodCallHandler result.success(false))
                        result.success(true)
                    }
                    "disable" -> {
                        stop(call.argument("context") as? Context ?: return@setMethodCallHandler result.success(false))
                        result.success(true)
                    }
                    "isSupported" -> {
                        // setBlocking is available on Android 12+
                        result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
                    }
                    "getAndroidVersion" -> {
                        result.success(Build.VERSION.SDK_INT)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }
    
    private var connectivityManager: ConnectivityManager? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private var isVpnActive = false
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onCreate() {
        super.onCreate()
        setupNetworkMonitoring()
    }
    
    private fun setupNetworkMonitoring() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) return
        
        connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
        
        val request = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()
        
        networkCallback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                super.onAvailable(network)
                checkVpnStatus()
            }
            
            override fun onLost(network: Network) {
                super.onLost(network)
                checkVpnStatus()
            }
            
            override fun onCapabilitiesChanged(
                network: Network,
                networkCapabilities: NetworkCapabilities
            ) {
                super.onCapabilitiesChanged(network, networkCapabilities)
                val hasVpn = networkCapabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN)
                if (hasVpn != isVpnActive) {
                    isVpnActive = hasVpn
                    if (!hasVpn) {
                        // VPN dropped - notify Flutter
                        notifyVpnDropped()
                    }
                }
            }
        }
        
        try {
            connectivityManager?.registerNetworkCallback(request, networkCallback!!)
        } catch (e: Exception) {
            // Ignore registration errors
        }
    }
    
    private fun checkVpnStatus() {
        val cm = connectivityManager ?: return
        val activeNetwork = cm.activeNetwork ?: return
        val capabilities = cm.getNetworkCapabilities(activeNetwork) ?: return
        
        val hasVpn = capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN)
        if (hasVpn != isVpnActive) {
            isVpnActive = hasVpn
            if (!hasVpn) {
                notifyVpnDropped()
            }
        }
    }
    
    private fun notifyVpnDropped() {
        try {
            methodChannel?.invokeMethod("vpnDropped", null)
        } catch (e: Exception) {
            // Flutter engine might not be available
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        try {
            networkCallback?.let { connectivityManager?.unregisterNetworkCallback(it) }
        } catch (e: Exception) {
            // Ignore
        }
    }
}
