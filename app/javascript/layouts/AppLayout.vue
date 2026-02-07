<script setup>
import { router, usePage } from "@inertiajs/vue3"

const page = usePage()
const currentUser = page.props.currentUser

function logout() {
  router.delete("/logout")
}
</script>

<template>
  <UApp>
    <div class="min-h-screen bg-gray-50 dark:bg-gray-950">
      <header class="border-b border-gray-200 bg-white dark:border-gray-800 dark:bg-gray-900">
        <UContainer class="flex h-16 items-center justify-between">
          <a
            href="/projects"
            class="text-lg font-bold text-gray-900 dark:text-white"
            @click.prevent="router.visit('/projects')"
          >
            MarkdownForge
          </a>

          <div class="flex items-center gap-2">
            <span class="text-sm text-gray-600 dark:text-gray-400">{{ currentUser?.name }}</span>

            <UButton
              variant="ghost"
              color="neutral"
              icon="i-lucide-key"
              label="Tokens"
              @click="router.visit('/settings/tokens')"
            />

            <UButton
              variant="ghost"
              color="neutral"
              icon="i-lucide-settings"
              label="Settings"
              @click="router.visit('/settings')"
            />

            <UButton variant="ghost" color="neutral" icon="i-lucide-log-out" @click="logout">
              Log out
            </UButton>
          </div>
        </UContainer>
      </header>

      <main>
        <UContainer class="py-8">
          <slot />
        </UContainer>
      </main>
    </div>
  </UApp>
</template>
