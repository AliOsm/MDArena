<script setup>
import { usePage, router } from "@inertiajs/vue3"
import MarkdownPreview from "@/components/MarkdownPreview.vue"

const page = usePage()
const project = page.props.project
const path = page.props.path
const content = page.props.content

const toast = useToast()

function downloadMd() {
  const blob = new Blob([content], { type: "text/markdown" })
  const url = URL.createObjectURL(blob)
  const a = document.createElement("a")
  a.href = url
  a.download = path
  a.click()
  URL.revokeObjectURL(url)
}

function deleteFile() {
  router.delete(`/projects/${project.slug}/files/${path}`, {
    onSuccess: () => {
      toast.add({ title: "File deleted", color: "success" })
    },
  })
}
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
      <span class="font-medium text-(--ui-text)">{{ path }}</span>
    </div>

    <!-- Actions -->
    <div class="mb-6 flex flex-wrap items-center gap-2">
      <UButton
        icon="i-lucide-pencil"
        label="Edit"
        @click="router.visit(`/projects/${project.slug}/files/${path}/edit`)"
      />
      <UButton
        icon="i-lucide-history"
        label="History"
        variant="soft"
        color="neutral"
        @click="router.visit(`/projects/${project.slug}/files/${path}/history`)"
      />
      <UButton
        icon="i-lucide-download"
        label="Download"
        variant="soft"
        color="neutral"
        @click="downloadMd"
      />
      <USeparator orientation="vertical" class="h-5" />
      <UButton
        icon="i-lucide-trash-2"
        label="Delete"
        variant="ghost"
        color="error"
        @click="deleteFile"
      />
    </div>

    <!-- Content -->
    <UCard>
      <div class="p-2">
        <MarkdownPreview :content="content" />
      </div>
    </UCard>
  </div>
</template>
