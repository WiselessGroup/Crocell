package net.wiseless.crocell

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager

/**
 * The launcher icon: one activity-alias per picture and background, declared
 * in the manifest by scripts/make-icons.sh, exactly one of them enabled.
 */
object AppIcons {
    private val arts = listOf("glyph_red", "glyph_ember", "glyph_white", "glyph_inverse", "crocell", "crocell_grey")
    private val backgrounds = listOf("dark", "paper", "crimson", "ember")

    fun select(context: Context, alias: String) {
        val pm = context.packageManager
        val all = arts.flatMap { a -> backgrounds.map { b -> "Icon_${a}_$b" } }
        if (alias !in all) return
        fun component(name: String) = ComponentName(context, "${context.packageName}.$name")

        // Enable first: with none enabled for a moment, launchers drop the app.
        pm.setComponentEnabledSetting(
            component(alias), PackageManager.COMPONENT_ENABLED_STATE_ENABLED, PackageManager.DONT_KILL_APP,
        )
        for (other in all) {
            if (other == alias) continue
            pm.setComponentEnabledSetting(
                component(other), PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP,
            )
        }
    }
}
