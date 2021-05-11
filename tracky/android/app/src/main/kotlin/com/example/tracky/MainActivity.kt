package com.kacpermarcinkiewicz.tracky

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.net.Uri
import java.io.BufferedReader
import java.io.FileOutputStream
import java.io.IOException
import java.io.InputStreamReader
import java.lang.Exception


class MainActivity: FlutterActivity() {
    lateinit var myResult : MethodChannel.Result
    var replySubmited : Boolean = false
    private val CHANNEL = "tracky.kacpermarcinkiewicz.com/files"
    lateinit var bytes: ByteArray

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            // Note: this method is invoked on the main thread.
            call, result ->
            myResult = result
            replySubmited = false
            if (call.method == "saveFile") {
                try {
                    createFile(call.argument("bytes")!!, call.argument("name")!!)
                }catch ( e: Exception){
                    if(!replySubmited) {
                        replySubmited = true
                        result.error("ERROR", "Error while creating file: " + e.message, null)
                    }
                }


            }
            else if(call.method == "readFile"){
                try {
                    openFile()
                }catch ( e: Exception){
                    if(!replySubmited) {
                        replySubmited = true
                        result.error("ERROR", "Error while opening file: " + e.message, null)
                    }
                }
            }
            else {
                if(!replySubmited){
                    replySubmited = true
                    result.notImplemented()
                }
            }
        }
    }

    //#region create file

    private fun createFile(bytes: ByteArray, name: String) {
        this.bytes = bytes
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT)

        intent.addCategory(Intent.CATEGORY_OPENABLE)
        intent.setType("*/*")
        intent.putExtra(Intent.EXTRA_TITLE, "$name")
        startActivityForResult(intent, 101)
    }

    private fun writeFile(uri: Uri) {

        try {
            val parcelFileDescriptor = this.contentResolver.openFileDescriptor(uri, "w")

            val fileOutputStream = FileOutputStream(parcelFileDescriptor!!.fileDescriptor)
            fileOutputStream.write(this.bytes)

            fileOutputStream.close()
            parcelFileDescriptor!!.close()

            myResult.success(true)
        } catch (e: IOException) {
            e.printStackTrace()
        }

    }
    //#endregion

    //#region read file
    private fun openFile() {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
        intent.addCategory(Intent.CATEGORY_OPENABLE)
        intent.type = "*/*"
        startActivityForResult(intent, 41)
    }
    private fun readFileContent(uri: Uri?): String {

        val inputStream = contentResolver.openInputStream(uri!!)
        val reader = BufferedReader(InputStreamReader(
                inputStream!!))
        val stringBuilder = StringBuilder()


        var currentline = reader.readLine()

        while (currentline != null) {
            stringBuilder.append(currentline + "\n")
            currentline = reader.readLine()
        }
        inputStream.close()
        return stringBuilder.toString()
    }
    //#endregion

    // CODES
    // 101 - create file
    // 41 - open file
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == 101 && resultCode == Activity.RESULT_OK) {
            if (data != null) {
                writeFile(data!!.getData()!!)
            }
        }
        else if(requestCode == 101 && resultCode != Activity.RESULT_OK){
            if(!replySubmited) {
                replySubmited = true
                myResult.error("ERROR", "Error while creating file!", null)
            }
        }
        else if (requestCode == 41 && resultCode == Activity.RESULT_OK){
            var currentUri: Uri? = null

            data?.let {
                currentUri = it.data

                try {
                    val content = readFileContent(currentUri)
                    replySubmited = true
                    myResult.success(content)
                } catch (e: IOException) {
                    if(!replySubmited) {
                        replySubmited = true
                        myResult.error("ERROR", e.message, null)
                    }
                }

            }
        }
        else if (requestCode == 41 && resultCode == Activity.RESULT_CANCELED){
            if(!replySubmited) {
                replySubmited = true
                myResult.error("ERROR", "Operation canceled", null)
            }
        }
        else{
            if(!replySubmited){
                replySubmited = true
                myResult.error("ERROR", "Error!", null)
            }
        }
    }
}
