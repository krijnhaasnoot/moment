package com.moment.app

import android.app.Application
import com.moment.app.service.SupabaseService

class MomentApplication : Application() {
    
    override fun onCreate() {
        super.onCreate()
        
        // Initialize Supabase
        SupabaseService.initialize(this)
    }
}
