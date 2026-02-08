<script setup>
import { computed } from "vue"
import { usePage, router } from "@inertiajs/vue3"
import MarkdownPreview from "@/components/MarkdownPreview.vue"
import { encodePath } from "@/lib/url.js"

const page = usePage()
const project = page.props.project
const path = page.props.path
const sha = page.props.sha
const content = page.props.content

const encodedPath = computed(() => encodePath(path))
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
      <UButton
        variant="link"
        label="History"
        @click="router.visit(`/projects/${project.slug}/files/${encodedPath}/history`)"
        class="p-0"
      />
      <UIcon name="i-lucide-chevron-right" class="size-3.5" />
      <span class="font-medium text-(--ui-text)">Revision</span>
    </div>

    <div class="mb-6 flex items-center gap-3">
      <UButton
        icon="i-lucide-arrow-left"
        label="Back to history"
        variant="soft"
        color="neutral"
        @click="router.visit(`/projects/${project.slug}/files/${encodedPath}/history`)"
      />
      <UBadge variant="subtle" color="neutral">
        <code class="font-mono text-xs">{{ sha.slice(0, 8) }}</code>
      </UBadge>
    </div>

    <UCard>
      <div class="p-2">
        <MarkdownPreview :content="content" />
      </div>
    </UCard>
  </div>
</template>
