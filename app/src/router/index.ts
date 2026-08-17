import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: '/',
      name: 'home',
      component: () => import('@/views/HomeView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/login',
      name: 'login',
      component: () => import('@/views/LoginView.vue'),
    },
    {
      path: '/select-user',
      name: 'select-user',
      component: () => import('@/views/UserSelectView.vue'),
    },
  ],
})

// Navigation guard
router.beforeEach((to, _from, next) => {
  const authStore = useAuthStore()

  // Logged in -> home
  if (authStore.isLoggedIn) {
    if (to.path === '/login' || to.path === '/select-user') {
      next('/')
    } else {
      next()
    }
    return
  }

  // Not logged in -> routing based on .env
  
  // Accessing login page
  if (to.path === '/login') {
    // .env -> redirect
    if (authStore.hasEnvConfig) {
      if (authStore.hasSingleEnvUser) {
        authStore.autoLoginSingleUser()
        next('/')
      } else {
        // multi user -> select
        next('/select-user')
      }
    } else {
      // No .env -> login page
      next()
    }
    return
  }

  // Accessing selection
  if (to.path === '/select-user') {
    if (!authStore.hasEnvConfig) {
      // No .env -> login page
      next('/login')
    } else if (authStore.hasSingleEnvUser) {
      // Single user -> auto login
      authStore.autoLoginSingleUser()
      next('/')
    } else {
      // multi user -> allow selection
      next()
    }
    return
  }

  // Protected routes
  if (to.meta.requiresAuth) {
    if (authStore.hasEnvConfig) {
      if (authStore.hasSingleEnvUser) {
        authStore.autoLoginSingleUser()
        next()
      } else {
        // multi user -> selection
        next('/select-user')
      }
    } else {
      // No .env -> login page
      next('/login')
    }
    return
  }

  // Default -> allow
  next()
})

export default router
