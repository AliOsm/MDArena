<script setup>
import { usePage, router } from "@inertiajs/vue3"
import MarkdownPreview from "@/components/MarkdownPreview.vue"

const page = usePage()
const project = page.props.project
const path = page.props.path
const sha = page.props.sha
const content = page.props.content
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
        <UButton
          variant="link"
          label="History"
          @click="router.visit(`/projects/${project.slug}/files/${path}/history`)"
          class="p-0"
        />
        <span>/</span>
      </div>
      <div class="flex items-center gap-3">
        <h1 class="text-2xl font-bold text-gray-900 dark:text-white">Revision</h1>
        <UBadge variant="subtle" color="neutral">
          <code class="font-mono text-xs">{{ sha.slice(0, 8) }}</code>
        </UBadge>
      </div>
    </div>

    <div class="mb-6">
      <UButton
        icon="i-lucide-arrow-left"
        label="Back to history"
        variant="soft"
        color="neutral"
        @click="router.visit(`/projects/${project.slug}/files/${path}/history`)"
      />
    </div>

    <div class="rounded-lg border border-gray-200 p-6 dark:border-gray-700">
      <MarkdownPreview :content="content" />
    </div>
  </div>
</template>
