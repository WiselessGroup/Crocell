package net.wiseless.crocell

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.drawable.Icon

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
        CrocellVpnService.notificationChoiceChanged(context)
    }

    /** The alias in use, which is the only record of the choice on this side. */
    private fun current(context: Context): String? {
        val pm = context.packageManager
        return arts.flatMap { a -> backgrounds.map { b -> "Icon_${a}_$b" } }.firstOrNull { alias ->
            pm.getComponentEnabledSetting(ComponentName(context, "${context.packageName}.$alias")) ==
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED
        }
    }

    /** The status bar icon: the shape of the chosen picture, in one colour. */
    fun small(context: Context): Int =
        if (current(context)?.startsWith("Icon_crocell") == true) R.drawable.ic_notification_crocell else R.drawable.ic_notification

    /**
     * The chosen icon as a notification's large icon. Null while the default
     * one is on: until the person chooses, the manifest has it enabled but
     * reports DEFAULT, not ENABLED, and the system's own icon is the same one.
     */
    fun large(context: Context): Icon? {
        val alias = current(context) ?: return null
        val id = context.resources.getIdentifier(alias.lowercase(), "mipmap", context.packageName)
        return if (id == 0) null else Icon.createWithResource(context, id)
    }
}
