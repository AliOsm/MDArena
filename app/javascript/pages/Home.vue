<script setup>
import { onMounted } from "vue"
import { router } from "@inertiajs/vue3"

onMounted(() => {
  router.visit("/projects")
})
</script>

<template>
  <div class="flex items-center justify-center py-16">
    <div class="flex flex-col items-center gap-3">
      <div class="size-8 animate-spin rounded-full border-2 border-(--ui-primary) border-t-transparent" />
      <span class="text-sm text-(--ui-text-muted)">Redirecting...</span>
    </div>
  </div>
</template>
