<script setup>
import { usePage, router } from "@inertiajs/vue3"

const page = usePage()
const project = page.props.project
const path = page.props.path
const history = page.props.history || []

function formatDate(dateStr) {
  if (!dateStr) return ""
  return new Date(dateStr).toLocaleDateString("en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  })
}

const columns = [
  { key: "sha", label: "Commit" },
  { key: "message", label: "Message" },
  { key: "author", label: "Author" },
  { key: "time", label: "Date" },
  { key: "actions", label: "" },
]
</script>

<template>
  <div>
    <div class="mb-6">
      <div class="mb-2 flex items-center gap-2 text-sm text-gray-500 dark:text-gray-400">
        <UButton
          variant="link"
          :label="project.name"
          @click="router.visit(`/projects/${project.slug}`)"
          class="p-0"
        />
        <span>/</span>
        <UButton
          variant="link"
          :label="path"
          @click="router.visit(`/projects/${project.slug}/files/${path}`)"
          class="p-0"
        />
        <span>/</span>
      </div>
      <h1 class="text-2xl font-bold text-gray-900 dark:text-white">History</h1>
    </div>

    <div class="mb-6">
      <UButton
        icon="i-lucide-arrow-left"
        label="Back to file"
        variant="soft"
        color="neutral"
        @click="router.visit(`/projects/${project.slug}/files/${path}`)"
      />
    </div>

    <UTable v-if="history.length" :columns="columns" :rows="history">
      <template #sha-cell="{ row }">
        <UBadge variant="subtle" color="neutral">
          <code class="font-mono text-xs">{{ row.sha.slice(0, 8) }}</code>
        </UBadge>
      </template>

      <template #message-cell="{ row }">
        {{ row.message }}
      </template>

      <template #author-cell="{ row }">
        {{ row.author.name }}
      </template>

      <template #time-cell="{ row }">
        {{ formatDate(row.time) }}
      </template>

      <template #actions-cell="{ row }">
        <UButton
          label="View"
          variant="soft"
          size="xs"
          @click="router.visit(`/projects/${project.slug}/files/${path}/history/${row.sha}`)"
        />
      </template>
    </UTable>

    <UAlert
      v-else
      icon="i-lucide-history"
      title="No history"
      description="This file has no commit history yet."
      color="neutral"
    />
  </div>
</template>
