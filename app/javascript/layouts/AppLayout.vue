<script setup>
import { router, usePage } from "@inertiajs/vue3"
import { computed } from "vue"

const page = usePage()
const currentUser = page.props.currentUser

const avatarUrl = computed(() =>
  currentUser?.id ? `https://api.dicebear.com/9.x/notionists/svg?seed=${currentUser.id}` : null,
)

const currentPath = computed(() => page.url)

function isActive(path) {
  return currentPath.value.startsWith(path)
}

const navItems = computed(() => [
  [
    {
      label: "Projects",
      icon: "i-lucide-folder",
      active: isActive("/projects"),
      onSelect() {
        router.visit("/projects")
      },
    },
    {
      label: "Settings",
      icon: "i-lucide-settings",
      active: isActive("/settings") && !isActive("/settings/tokens"),
      onSelect() {
        router.visit("/settings")
      },
    },
    {
      label: "Tokens",
      icon: "i-lucide-key",
      active: isActive("/settings/tokens"),
      onSelect() {
        router.visit("/settings/tokens")
      },
    },
  ],
])

function logout() {
  router.delete("/logout")
}
</script>

<template>
  <UApp>
    <UDashboardGroup storage-key="app-sidebar" class="h-screen">
      <UDashboardSidebar
        collapsible
        resizable
        :default-size="15"
        :min-size="10"
        :max-size="20"
        :ui="{ footer: 'border-t border-(--ui-border)' }"
      >
        <template #header="{ collapsed }">
          <div class="flex items-center gap-2" :class="collapsed ? 'justify-center' : ''">
            <UIcon name="i-lucide-swords" class="size-5 shrink-0 text-(--ui-primary)" />
            <span v-if="!collapsed" class="font-semibold text-sm truncate">MDArena</span>
          </div>
        </template>

        <template #default="{ collapsed }">
          <UNavigationMenu :collapsed="collapsed" :items="navItems" orientation="vertical" />
        </template>

        <template #footer="{ collapsed }">
          <div class="flex items-center gap-2" :class="collapsed ? 'flex-col' : ''">
            <UAvatar :src="avatarUrl" :label="currentUser?.name?.[0]" size="xs" />
            <span v-if="!collapsed" class="flex-1 truncate text-sm">{{ currentUser?.name }}</span>
            <div class="flex items-center gap-1" :class="collapsed ? 'flex-col' : ''">
              <UColorModeButton size="xs" variant="ghost" color="neutral" />
              <UButton
                icon="i-lucide-log-out"
                size="xs"
                variant="ghost"
                color="neutral"
                @click="logout"
              />
            </div>
          </div>
        </template>
      </UDashboardSidebar>

      <UDashboardPanel>
        <template #body>
          <div class="p-6">
            <slot />
          </div>
        </template>
      </UDashboardPanel>
    </UDashboardGroup>
  </UApp>
</template>
