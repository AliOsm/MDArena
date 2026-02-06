<script setup>
import { usePage, router } from "@inertiajs/vue3"
import MarkdownPreview from "@/components/MarkdownPreview.vue"

const page = usePage()
const project = page.props.project
const path = page.props.path
const content = page.props.content

const toast = useToast()

function downloadPdf() {
  router.post(`/projects/${project.slug}/files/${path}/download_pdf`, {}, {
    preserveScroll: true,
    onSuccess: () => {
      toast.add({
        title: "PDF export started",
        description: "You'll be notified when it's ready.",
        color: "success",
      })
    },
  })
}
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
      </div>
      <h1 class="text-2xl font-bold text-gray-900 dark:text-white">{{ path }}</h1>
    </div>

    <div class="mb-6 flex flex-wrap gap-2">
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
        label="Download MD"
        variant="soft"
        color="neutral"
        :href="`/projects/${project.slug}/files/${path}/download_md`"
        tag="a"
      />
      <UButton
        icon="i-lucide-file-text"
        label="Download PDF"
        variant="soft"
        color="neutral"
        @click="downloadPdf"
      />
    </div>

    <div class="rounded-lg border border-gray-200 p-6 dark:border-gray-700">
      <MarkdownPreview :content="content" />
    </div>
  </div>
</template>
