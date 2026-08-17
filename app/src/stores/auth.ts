import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { ImmichConfig, EnvUser, EnvConfig } from '@/types/immich'

const STORAGE_KEY = 'immich-swipe-config'

// Parse .env at module load time
function parseEnvConfig(): EnvConfig | null {
  const serverUrl = import.meta.env.VITE_SERVER_URL

  // Debug
  console.log('[Auth] Parsing env config...')
  console.log('[Auth] VITE_SERVER_URL:', serverUrl)
  
  if (!serverUrl) {
    console.log('[Auth] No VITE_SERVER_URL found, skipping env config')
    return null
  }

  const users: EnvUser[] = []
  
  // Parse users from .env
  let i = 1
  while (true) {
    const name = import.meta.env[`VITE_USER_${i}_NAME`]
    const apiKey = import.meta.env[`VITE_USER_${i}_API_KEY`]
    
    if (!name || !apiKey) break
    
    users.push({ name, apiKey })
    i++
  }

  if (users.length === 0) {
    console.log('[Auth] No users found in env config')
    return null
  }

  console.log(`[Auth] Found ${users.length} users:`, users.map(u => u.name))
  return { serverUrl, users }
}

const envConfig = parseEnvConfig()

export const useAuthStore = defineStore('auth', () => {
  const serverUrl = ref<string>('')
  const apiKey = ref<string>('')
  const currentUserName = ref<string>('')
  const hasStoredConfig = ref<boolean>(false)
  const proxyBaseUrl = '/api'

  // .env state
  const hasEnvConfig = computed(() => envConfig !== null && envConfig.users.length > 0)
  const envUsers = computed(() => envConfig?.users || [])
  const needsUserSelection = computed(() => hasEnvConfig.value && envConfig!.users.length > 1 && !isLoggedIn.value)
  const hasSingleEnvUser = computed(() => hasEnvConfig.value && envConfig!.users.length === 1)

  function readStoredConfig(): ImmichConfig | null {
    const stored = localStorage.getItem(STORAGE_KEY)
    if (stored) {
      try {
        const config: ImmichConfig = JSON.parse(stored)
        return {
          serverUrl: config.serverUrl || '',
          apiKey: config.apiKey || '',
        }
      } catch {
        console.error('Failed to parse stored config')
      }
    }
    return null
  }

  // Load from localStorage on init or when requested
  function loadConfig() {
    const config = readStoredConfig()
    if (config) {
      serverUrl.value = config.serverUrl
      apiKey.value = config.apiKey
      hasStoredConfig.value = true
    } else {
      serverUrl.value = ''
      apiKey.value = ''
      hasStoredConfig.value = false
    }
  }

  // Save to localStorage
  function saveConfig() {
    const config: ImmichConfig = {
      serverUrl: serverUrl.value,
      apiKey: apiKey.value,
    }
    localStorage.setItem(STORAGE_KEY, JSON.stringify(config))
    hasStoredConfig.value = true
  }

  // Set config
  function setConfig(url: string, key: string, userName: string = '') {
    // Normalize URL - remove trailing slash
    serverUrl.value = url.replace(/\/+$/, '')
    apiKey.value = key
    currentUserName.value = userName
    saveConfig()
  }

  // Get user from .env
  function selectEnvUser(user: EnvUser) {
    if (!envConfig) return
    setConfig(envConfig.serverUrl, user.apiKey, user.name)
  }

  // Auto-login if single .env user
  function autoLoginSingleUser() {
    if (hasSingleEnvUser.value && envConfig) {
      const user = envConfig.users[0]
      setConfig(envConfig.serverUrl, user.apiKey, user.name)
      return true
    }
    return false
  }

  // Clear config (logout)
  function clearConfig() {
    serverUrl.value = ''
    apiKey.value = ''
    currentUserName.value = ''
    localStorage.removeItem(STORAGE_KEY)
    hasStoredConfig.value = false
  }

  function getStoredConfig(): ImmichConfig | null {
    return readStoredConfig()
  }

  // Check if logged in
  const isLoggedIn = computed(() => {
    return serverUrl.value.length > 0 && apiKey.value.length > 0
  })

  // Immich server base URL without /api suffix
  const immichBaseUrl = computed(() => {
    if (!serverUrl.value) return ''
    return serverUrl.value.replace(/\/api\/?$/, '')
  })

  // Base URL for direct Immich API calls (always ends with /api)
  const apiBaseUrl = computed(() => {
    if (!serverUrl.value) return ''
    const normalized = serverUrl.value.replace(/\/+$/, '')
    return normalized.endsWith('/api') ? normalized : `${normalized}/api`
  })

  // Initialize
  loadConfig()

  return {
    serverUrl,
    apiKey,
    currentUserName,
    isLoggedIn,
    hasStoredConfig,
    immichBaseUrl,
    apiBaseUrl,
    proxyBaseUrl,
    hasEnvConfig,
    envUsers,
    needsUserSelection,
    hasSingleEnvUser,
    setConfig,
    clearConfig,
    loadConfig,
    getStoredConfig,
    selectEnvUser,
    autoLoginSingleUser,
  }
})
