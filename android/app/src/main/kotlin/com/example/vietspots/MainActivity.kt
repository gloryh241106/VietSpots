package com.example.vietspots

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.content.Intent
import android.os.Bundle
import java.io.FileOutputStream
import java.io.FileInputStream
import java.io.RandomAccessFile
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
	private var audioRecord: AudioRecord? = null
	private var recordingThread: Thread? = null
	private var isRecording = false
	private var outputPath: String? = null
    private var speechRecognizer: SpeechRecognizer? = null
    private var lastTranscript: String? = null
    private var listening = false

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vietspots/recorder")
			.setMethodCallHandler { call, result ->
				try {
					when (call.method) {

						// Start Android SpeechRecognizer (live STT) - preferred
						"startListening" -> {
							try {
								if (!SpeechRecognizer.isRecognitionAvailable(this)) {
									result.success(false)
									return@setMethodCallHandler
								}
								if (speechRecognizer == null) {
									speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this)
									speechRecognizer?.setRecognitionListener(object : RecognitionListener {
										override fun onReadyForSpeech(params: Bundle?) {}
										override fun onBeginningOfSpeech() { lastTranscript = null }
										override fun onRmsChanged(rmsdB: Float) {}
										override fun onBufferReceived(buffer: ByteArray?) {}
										override fun onEndOfSpeech() {}
										override fun onError(error: Int) {
										// record error and stop
										listening = false
									}
										override fun onResults(results: Bundle?) {
										val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
										if (!matches.isNullOrEmpty()) {
											lastTranscript = matches.joinToString(" ")
										}
										listening = false
									}
										override fun onPartialResults(partialResults: Bundle?) {
										val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
										if (!matches.isNullOrEmpty()) {
											lastTranscript = matches.joinToString(" ")
										}
									}
										override fun onEvent(eventType: Int, params: Bundle?) {}
									})
								}
								val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
								intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
								intent.putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
								// Use device default locale; change if needed
								intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, java.util.Locale.getDefault())
								lastTranscript = null
								listening = true
								speechRecognizer?.startListening(intent)
								result.success(true)
							} catch (e: Exception) {
								result.error("LISTEN_START_ERROR", e.message, null)
							}
						}

						"stopListening" -> {
							try {
								if (speechRecognizer != null && listening) {
									speechRecognizer?.stopListening()
								}
								// Wait briefly if partial results still arriving
								val transcript = lastTranscript
								// cleanup
								try { speechRecognizer?.cancel(); speechRecognizer?.destroy() } catch (_: Throwable) {}
								speechRecognizer = null
								listening = false
								result.success(transcript)
							} catch (e: Exception) {
								result.error("LISTEN_STOP_ERROR", e.message, null)
							}
						}

						// Existing recorder-based methods follow
						"start" -> {
							// Start low-level AudioRecord and write raw PCM to temp file
							val sampleRate = 16000
							val channelConfig = AudioFormat.CHANNEL_IN_MONO
							val audioFormat = AudioFormat.ENCODING_PCM_16BIT

							val minBuf = AudioRecord.getMinBufferSize(sampleRate, channelConfig, audioFormat)
							val bufferSize = if (minBuf == AudioRecord.ERROR || minBuf == AudioRecord.ERROR_BAD_VALUE) {
								sampleRate * 2
							} else minBuf

							audioRecord = AudioRecord(
								MediaRecorder.AudioSource.MIC,
								sampleRate,
								channelConfig,
								audioFormat,
								bufferSize
							)

							val rawFile = File(cacheDir, "vietspots_rec_${System.currentTimeMillis()}.pcm")
							outputPath = File(cacheDir, "vietspots_rec_${System.currentTimeMillis()}.wav").absolutePath

							try {
								audioRecord?.startRecording()
								isRecording = true

								recordingThread = Thread {
									try {
										val fos = FileOutputStream(rawFile)
										val buffer = ByteArray(bufferSize)
										while (isRecording && audioRecord != null) {
											val read = audioRecord!!.read(buffer, 0, buffer.size)
											if (read > 0) {
												fos.write(buffer, 0, read)
											}
										}
										fos.flush()
										fos.close()

										// Convert raw PCM to WAV
										val pcmLength = rawFile.length()
										val wavFile = File(outputPath!!)
										val wavOut = FileOutputStream(wavFile)
										// write placeholder header
										wavOut.write(ByteArray(44))
										val fis = FileInputStream(rawFile)
										val buf = ByteArray(1024)
										var readBytes: Int
										while (fis.read(buf).also { readBytes = it } > 0) {
											wavOut.write(buf, 0, readBytes)
										}
										fis.close()

										// Write WAV header now that sizes are known
										val totalAudioLen = pcmLength
										val totalDataLen = totalAudioLen + 36
										val channels = 1
										val byteRate = 16 * sampleRate * channels / 8

										val raf = RandomAccessFile(wavFile, "rw")
										raf.seek(0)
										val header = ByteArray(44)
										// RIFF header
										header[0] = 'R'.code.toByte()
										header[1] = 'I'.code.toByte()
										header[2] = 'F'.code.toByte()
										header[3] = 'F'.code.toByte()
										// file size minus 8
										writeInt(header, 4, (totalDataLen + 8).toInt())
										header[8] = 'W'.code.toByte()
										header[9] = 'A'.code.toByte()
										header[10] = 'V'.code.toByte()
										header[11] = 'E'.code.toByte()
										header[12] = 'f'.code.toByte()
										header[13] = 'm'.code.toByte()
										header[14] = 't'.code.toByte()
										header[15] = ' '.code.toByte()
										writeInt(header, 16, 16) // Sub-chunk size
										writeShort(header, 20, 1.toShort()) // audio format (1 = PCM)
										writeShort(header, 22, channels.toShort())
										writeInt(header, 24, sampleRate)
										writeInt(header, 28, byteRate)
										writeShort(header, 32, (channels * 16 / 8).toShort())
										writeShort(header, 34, 16.toShort())
										header[36] = 'd'.code.toByte()
										header[37] = 'a'.code.toByte()
										header[38] = 't'.code.toByte()
										header[39] = 'a'.code.toByte()
										writeInt(header, 40, totalAudioLen.toInt())

										raf.write(header)
										raf.close()

										// Delete raw pcm file
										rawFile.delete()
									} catch (e: Exception) {
										// No-op; we'll report null path if fail
									}
								}
								recordingThread?.start()
								result.success(outputPath)
							} catch (e: Exception) {
								result.error("REC_START_ERROR", e.message, null)
							}
						}
						"stop" -> {
							try {
								isRecording = false
								audioRecord?.stop()
							} catch (_: Throwable) { }
							try { audioRecord?.release() } catch (_: Throwable) { }
							audioRecord = null
							recordingThread = null
							val path = outputPath
							outputPath = null
							result.success(path)
						}
						else -> result.notImplemented()
					}
				} catch (e: Exception) {
					result.error("REC_ERROR", e.message, null)
				}
			}
	}

		private fun writeInt(header: ByteArray, offset: Int, value: Int) {
			header[offset] = (value and 0xff).toByte()
			header[offset + 1] = ((value shr 8) and 0xff).toByte()
			header[offset + 2] = ((value shr 16) and 0xff).toByte()
			header[offset + 3] = ((value shr 24) and 0xff).toByte()
		}

		private fun writeShort(header: ByteArray, offset: Int, value: Short) {
			val v = value.toInt()
			header[offset] = (v and 0xff).toByte()
			header[offset + 1] = ((v shr 8) and 0xff).toByte()
		}
}
