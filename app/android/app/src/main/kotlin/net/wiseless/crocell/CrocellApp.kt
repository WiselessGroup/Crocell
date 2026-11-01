package net.wiseless.crocell

import android.app.Application

/** Starts the core with the process, before any screen or service needs it. */
class CrocellApp : Application() {
    override fun onCreate() {
        super.onCreate()
        Core.start(this)
    }
}
