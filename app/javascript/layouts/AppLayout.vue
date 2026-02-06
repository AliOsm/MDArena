<script setup>
import { onMounted, onBeforeUnmount } from "vue"
import { router, usePage } from "@inertiajs/vue3"
import { createConsumer } from "@rails/actioncable"

const toast = useToast()
const page = usePage()
const currentUser = page.props.currentUser

let consumer = null
let subscription = null

onMounted(() => {
  if (!currentUser?.id) return

  consumer = createConsumer()
  subscription = consumer.subscriptions.create("UserNotificationsChannel", {
    received(data) {
      if (data.type === "pdf_ready") {
        toast.add({
          title: "PDF Ready",
          description: `${data.filename} is ready for download.`,
          color: "success",
          actions: [
            {
              label: "Download",
              click: () => {
                window.location.href = data.download_url
              },
            },
          ],
        })
      }
    },
  })
})

onBeforeUnmount(() => {
  if (subscription) {
    subscription.unsubscribe()
    subscription = null
  }
  if (consumer) {
    consumer.disconnect()
    consumer = null
  }
})

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
              to="/settings/tokens"
              label="Tokens"
            />

            <UButton
              variant="ghost"
              color="neutral"
              icon="i-lucide-settings"
              to="/settings"
              label="Settings"
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
