package com.zeez3o.zepos

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.UUID
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val channelName = "com.zeez3o.zepos/bluetooth_printer"
    private val deviceChannelName = "com.zeez3o.zepos/device"
    private val permissionRequestCode = 7312
    private val pairTimeoutMillis = 60_000L
    private val sppUuid = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var channel: MethodChannel? = null
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingPermissionAction: (() -> Unit)? = null
    private var discoveryReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // ANDROID_ID is stable per device and per app signing key, so it
        // survives reinstalling ZePOS. The model is a label only: every phone
        // of one model shares it.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, deviceChannelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "identity") {
                    val id = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
                    result.success(
                        mapOf("id" to (id ?: ""), "model" to "${Build.MANUFACTURER} ${Build.MODEL}"),
                    )
                } else {
                    result.notImplemented()
                }
            }

        val methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        channel = methodChannel
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "listBondedPrinters" -> withPermissions(connectPermissions(), result) {
                    listBondedPrinters(result)
                }
                "startDiscovery" -> withPermissions(scanPermissions(), result) {
                    startDiscovery(result)
                }
                "stopDiscovery" -> {
                    stopDiscovery()
                    result.success(null)
                }
                "pair" -> withPermissions(connectPermissions(), result) {
                    val address = call.argument<String>("address")
                    if (address == null) {
                        result.error("INVALID_ARGUMENT", "Alamat printer wajib diisi.", null)
                    } else {
                        pairDevice(address, result)
                    }
                }
                "openSettings" -> {
                    startActivity(Intent(Settings.ACTION_BLUETOOTH_SETTINGS))
                    result.success(null)
                }
                "write" -> withPermissions(connectPermissions(), result) {
                    val address = call.argument<String>("address")
                    val bytes = call.argument<ByteArray>("bytes")
                    if (address == null || bytes == null) {
                        result.error("INVALID_ARGUMENT", "Alamat dan data printer wajib diisi.", null)
                    } else {
                        writeToPrinter(address, bytes, result)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    // Android 12+ gates Bluetooth behind "Perangkat di sekitar". Older versions
    // only ask for Location, and only when scanning for new devices.
    private fun connectPermissions(): Array<String> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            emptyArray()
        }

    private fun scanPermissions(): Array<String> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }

    private fun withPermissions(
        permissions: Array<String>,
        result: MethodChannel.Result,
        action: () -> Unit,
    ) {
        val missing = permissions.filter {
            checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED
        }
        if (missing.isEmpty()) {
            action()
            return
        }
        if (pendingPermissionResult != null) {
            result.error("BLUETOOTH_PERMISSION_BUSY", "Permintaan izin sedang diproses.", null)
            return
        }
        pendingPermissionResult = result
        pendingPermissionAction = action
        requestPermissions(missing.toTypedArray(), permissionRequestCode)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != permissionRequestCode) return
        val result = pendingPermissionResult
        val action = pendingPermissionAction
        pendingPermissionResult = null
        pendingPermissionAction = null
        val granted = grantResults.isNotEmpty() &&
            grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        if (granted) {
            action?.invoke()
        } else {
            val locationOnly = permissions.contains(Manifest.permission.ACCESS_FINE_LOCATION)
            result?.error(
                if (locationOnly) "BLUETOOTH_LOCATION_DENIED" else "BLUETOOTH_PERMISSION_DENIED",
                "Izin Bluetooth ditolak.",
                null,
            )
        }
    }

    private fun bluetoothAdapter() =
        getSystemService(BluetoothManager::class.java)?.adapter

    private fun deviceMap(device: BluetoothDevice) = mapOf(
        "name" to device.name,
        "address" to device.address,
        "bonded" to (device.bondState == BluetoothDevice.BOND_BONDED),
    )

    private fun listBondedPrinters(result: MethodChannel.Result) {
        val adapter = bluetoothAdapter()
        if (adapter == null) {
            result.error("BLUETOOTH_NOT_SUPPORTED", "Bluetooth tidak tersedia.", null)
            return
        }
        if (!adapter.isEnabled) {
            result.error("BLUETOOTH_DISABLED", "Bluetooth belum aktif.", null)
            return
        }
        val devices = adapter.bondedDevices
            .sortedBy { it.name ?: it.address }
            .map { deviceMap(it) }
        result.success(devices)
    }

    private fun startDiscovery(result: MethodChannel.Result) {
        val adapter = bluetoothAdapter()
        if (adapter == null) {
            result.error("BLUETOOTH_NOT_SUPPORTED", "Bluetooth tidak tersedia.", null)
            return
        }
        if (!adapter.isEnabled) {
            result.error("BLUETOOTH_DISABLED", "Bluetooth belum aktif.", null)
            return
        }
        stopDiscovery()

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                when (intent.action) {
                    BluetoothDevice.ACTION_FOUND -> {
                        val device = deviceFrom(intent) ?: return
                        channel?.invokeMethod("deviceFound", deviceMap(device))
                    }
                    BluetoothAdapter.ACTION_DISCOVERY_FINISHED -> {
                        stopDiscovery()
                        channel?.invokeMethod("discoveryFinished", null)
                    }
                }
            }
        }
        registerBluetoothReceiver(
            receiver,
            IntentFilter().apply {
                addAction(BluetoothDevice.ACTION_FOUND)
                addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED)
            },
        )
        discoveryReceiver = receiver

        if (adapter.startDiscovery()) {
            result.success(true)
        } else {
            stopDiscovery()
            result.error("BLUETOOTH_SCAN_FAILED", "Pemindaian tidak dapat dimulai.", null)
        }
    }

    private fun stopDiscovery() {
        discoveryReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (_: IllegalArgumentException) {
                // Already unregistered.
            }
        }
        discoveryReceiver = null
        try {
            if (checkSelfPermission(scanPermissions().first()) == PackageManager.PERMISSION_GRANTED) {
                bluetoothAdapter()?.cancelDiscovery()
            }
        } catch (_: SecurityException) {
            // Permission revoked while scanning; nothing left to cancel.
        }
    }

    // Pairing is slower and less reliable while the radio is still scanning, so
    // the scan is stopped first.
    private fun pairDevice(address: String, result: MethodChannel.Result) {
        val adapter = bluetoothAdapter()
        if (adapter == null || !adapter.isEnabled) {
            result.error("BLUETOOTH_DISABLED", "Bluetooth belum aktif.", null)
            return
        }
        stopDiscovery()
        val device = try {
            adapter.getRemoteDevice(address)
        } catch (_: IllegalArgumentException) {
            result.error("BLUETOOTH_DEVICE_NOT_FOUND", "Alamat printer tidak valid.", null)
            return
        }
        if (device.bondState == BluetoothDevice.BOND_BONDED) {
            result.success(true)
            return
        }

        var finished = false
        lateinit var receiver: BroadcastReceiver
        fun finish(error: String?) {
            if (finished) return
            finished = true
            mainHandler.removeCallbacksAndMessages(null)
            try {
                unregisterReceiver(receiver)
            } catch (_: IllegalArgumentException) {
                // Already unregistered.
            }
            if (error == null) result.success(true) else result.error(error, error, null)
        }
        receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                val changed = deviceFrom(intent) ?: return
                if (changed.address != address) return
                val state = intent.getIntExtra(BluetoothDevice.EXTRA_BOND_STATE, BluetoothDevice.ERROR)
                val previous = intent.getIntExtra(BluetoothDevice.EXTRA_PREVIOUS_BOND_STATE, BluetoothDevice.ERROR)
                when {
                    state == BluetoothDevice.BOND_BONDED -> finish(null)
                    state == BluetoothDevice.BOND_NONE && previous == BluetoothDevice.BOND_BONDING ->
                        finish("BLUETOOTH_PAIR_FAILED")
                }
            }
        }
        registerBluetoothReceiver(receiver, IntentFilter(BluetoothDevice.ACTION_BOND_STATE_CHANGED))
        mainHandler.postDelayed({ finish("BLUETOOTH_PAIR_TIMEOUT") }, pairTimeoutMillis)
        if (!device.createBond()) finish("BLUETOOTH_PAIR_FAILED")
    }

    private fun deviceFrom(intent: Intent): BluetoothDevice? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
        }

    // The broadcasts come from the Bluetooth service, so the receiver has to be
    // exported to hear them on Android 13+.
    private fun registerBluetoothReceiver(receiver: BroadcastReceiver, filter: IntentFilter) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(receiver, filter)
        }
    }

    private fun writeToPrinter(
        address: String,
        bytes: ByteArray,
        result: MethodChannel.Result,
    ) {
        executor.execute {
            try {
                val adapter = bluetoothAdapter()
                    ?: throw BluetoothPrintException("BLUETOOTH_NOT_SUPPORTED")
                if (!adapter.isEnabled) throw BluetoothPrintException("BLUETOOTH_DISABLED")
                val device = adapter.bondedDevices.firstOrNull { it.address == address }
                    ?: throw BluetoothPrintException("BLUETOOTH_DEVICE_NOT_FOUND")
                val socket = device.createRfcommSocketToServiceRecord(sppUuid)
                try {
                    socket.connect()
                    socket.outputStream.use { output ->
                        var offset = 0
                        while (offset < bytes.size) {
                            val length = minOf(1024, bytes.size - offset)
                            output.write(bytes, offset, length)
                            output.flush()
                            offset += length
                            if (offset < bytes.size) Thread.sleep(8)
                        }
                    }
                } finally {
                    socket.close()
                }
                runOnUiThread { result.success(true) }
            } catch (error: BluetoothPrintException) {
                runOnUiThread { result.error(error.code, error.code, null) }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error("BLUETOOTH_CONNECTION_FAILED", error.message, null)
                }
            }
        }
    }

    override fun onDestroy() {
        stopDiscovery()
        executor.shutdownNow()
        super.onDestroy()
    }

    private class BluetoothPrintException(val code: String) : Exception(code)
}
