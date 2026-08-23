package com.zeez3o.zepos

import android.Manifest
import android.bluetooth.BluetoothManager
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.UUID
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val channelName = "com.zeez3o.zepos/bluetooth_printer"
    private val permissionRequestCode = 7312
    private val sppUuid = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    private val executor = Executors.newSingleThreadExecutor()
    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "listBondedPrinters" -> withBluetoothPermission(result) {
                        listBondedPrinters(result)
                    }
                    "write" -> withBluetoothPermission(result) {
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

    private fun withBluetoothPermission(
        result: MethodChannel.Result,
        action: () -> Unit,
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
        ) {
            action()
            return
        }
        if (pendingPermissionResult != null) {
            result.error("BLUETOOTH_PERMISSION_BUSY", "Permintaan izin sedang diproses.", null)
            return
        }
        pendingPermissionResult = result
        pendingPermissionAction = action
        requestPermissions(arrayOf(Manifest.permission.BLUETOOTH_CONNECT), permissionRequestCode)
    }

    private var pendingPermissionAction: (() -> Unit)? = null

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
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            action?.invoke()
        } else {
            result?.error(
                "BLUETOOTH_PERMISSION_DENIED",
                "Izin Perangkat di sekitar ditolak.",
                null,
            )
        }
    }

    private fun bluetoothAdapter() =
        getSystemService(BluetoothManager::class.java)?.adapter

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
            .map { device -> mapOf("name" to device.name, "address" to device.address) }
        result.success(devices)
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
        executor.shutdownNow()
        super.onDestroy()
    }

    private class BluetoothPrintException(val code: String) : Exception(code)
}
