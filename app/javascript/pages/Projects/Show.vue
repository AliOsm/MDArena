<script setup>
import { ref } from "vue"
import { router, usePage } from "@inertiajs/vue3"

const page = usePage()
const project = page.props.project
const files = page.props.files || []

const showCreateModal = ref(false)
const fileName = ref("")
const creating = ref(false)

function createFile() {
  let name = fileName.value.trim()
  if (!name) return

  if (!name.endsWith(".md")) {
    name = `${name}.md`
  }

  creating.value = true
  router.post(
    `/projects/${project.slug}/files`,
    { path: name, content: `# ${name.replace(/\.md$/, "")}\n` },
    {
      onFinish: () => {
        creating.value = false
        showCreateModal.value = false
        fileName.value = ""
      },
    },
  )
}
</script>

<template>
  <div>
    <div class="mb-6 flex items-center justify-between">
      <div class="flex items-center gap-3">
        <h1 class="text-2xl font-bold text-gray-900 dark:text-white">
          {{ project.name }}
        </h1>
        <UBadge
          :label="project.role"
          :color="project.role === 'owner' ? 'primary' : 'neutral'"
          variant="subtle"
        />
      </div>
      <div class="flex gap-2">
        <UButton
          v-if="project.role === 'owner'"
          icon="i-lucide-settings"
          label="Settings"
          color="neutral"
          variant="ghost"
          @click="router.visit(`/projects/${project.slug}/settings`)"
        />
        <UButton icon="i-lucide-plus" label="New File" @click="showCreateModal = true" />
      </div>
    </div>

    <div class="mb-6">
      <span class="text-sm text-gray-500 dark:text-gray-400">Clone URL: </span>
      <code class="rounded bg-gray-100 px-2 py-1 text-sm dark:bg-gray-800">{{
        project.cloneUrl
      }}</code>
    </div>

    <div v-if="files.length" class="flex flex-col gap-1">
      <UButton
        v-for="file in files"
        :key="file"
        variant="ghost"
        block
        class="justify-start"
        icon="i-lucide-file-text"
        :label="file"
        @click="router.visit(`/projects/${project.slug}/files/${file}`)"
      />
    </div>

    <UAlert
      v-else
      icon="i-lucide-file-plus"
      title="No files yet"
      description="Create a new Markdown file to get started."
      color="neutral"
    />

    <UModal v-model:open="showCreateModal">
      <template #content>
        <div class="p-6">
          <h2 class="mb-4 text-lg font-semibold text-gray-900 dark:text-white">Create New File</h2>
          <form @submit.prevent="createFile">
            <UFormField label="File name" class="mb-4">
              <UInput
                v-model="fileName"
                placeholder="e.g. getting-started.md"
                icon="i-lucide-file-text"
                autofocus
                required
              />
            </UFormField>
            <p class="mb-4 text-xs text-gray-500 dark:text-gray-400">
              .md extension will be added automatically if not provided.
            </p>
            <div class="flex justify-end gap-2">
              <UButton
                label="Cancel"
                color="neutral"
                variant="ghost"
                @click="showCreateModal = false"
              />
              <UButton type="submit" label="Create" :loading="creating" />
            </div>
          </form>
        </div>
      </template>
    </UModal>
  </div>
</template>
