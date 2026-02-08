<script setup>
import { computed } from "vue"
import { usePage, router } from "@inertiajs/vue3"
import { encodePath } from "@/lib/url.js"

const page = usePage()
const project = page.props.project
const path = page.props.path
const history = page.props.history || []

const encodedPath = computed(() => encodePath(path))

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
  { accessorKey: "sha", header: "Commit" },
  { accessorKey: "message", header: "Message" },
  { accessorKey: "author", header: "Author" },
  { accessorKey: "time", header: "Date" },
  { id: "actions" },
]
</script>

<template>
  <div>
    <!-- Breadcrumb -->
    <div class="mb-4 flex items-center gap-1 text-sm text-(--ui-text-muted)">
      <UButton
        variant="link"
        :label="project.name"
        @click="router.visit(`/projects/${project.slug}`)"
        class="p-0"
      />
      <UIcon name="i-lucide-chevron-right" class="size-3.5" />
      <UButton
        variant="link"
        :label="path"
        @click="router.visit(`/projects/${project.slug}/files/${encodedPath}`)"
        class="p-0"
      />
      <UIcon name="i-lucide-chevron-right" class="size-3.5" />
      <span class="font-medium text-(--ui-text)">History</span>
    </div>

    <div class="mb-6">
      <UButton
        icon="i-lucide-arrow-left"
        label="Back to file"
        variant="soft"
        color="neutral"
        @click="router.visit(`/projects/${project.slug}/files/${encodedPath}`)"
      />
    </div>

    <UCard>
      <div v-if="history.length" class="overflow-x-auto">
      <UTable :columns="columns" :data="history">
        <template #sha-cell="{ row }">
          <UBadge variant="subtle" color="neutral">
            <code class="font-mono text-xs">{{ row.original.sha.slice(0, 8) }}</code>
          </UBadge>
        </template>

        <template #message-cell="{ row }">
          {{ row.original.message }}
        </template>

        <template #author-cell="{ row }">
          {{ row.original.author.name }}
        </template>

        <template #time-cell="{ row }">
          {{ formatDate(row.original.time) }}
        </template>

        <template #actions-cell="{ row }">
          <UButton
            label="View"
            variant="soft"
            size="xs"
            @click="router.visit(`/projects/${project.slug}/files/${encodedPath}/history/${row.original.sha}`)"
          />
        </template>
      </UTable>
      </div>

      <div v-else class="flex flex-col items-center justify-center py-12">
        <UIcon name="i-lucide-history" class="size-10 text-(--ui-text-dimmed)" />
        <p class="mt-3 font-medium">No history</p>
        <p class="mt-1 text-sm text-(--ui-text-muted)">This file has no commit history yet.</p>
      </div>
    </UCard>
  </div>
</template>
