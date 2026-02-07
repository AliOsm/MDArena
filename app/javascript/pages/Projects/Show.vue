<script setup>
import { ref, computed } from "vue"
import { router, usePage } from "@inertiajs/vue3"

const page = usePage()
const project = page.props.project
const files = computed(() => page.props.files || [])
const toast = useToast()

const showCreateModal = ref(false)
const fileName = ref("")
const creating = ref(false)
const copied = ref(false)

const cloneCommand = `git clone ${project.cloneUrl}`

const ownerAvatarUrl = computed(() =>
  project.ownerId
    ? `https://api.dicebear.com/9.x/notionists/svg?seed=${project.ownerId}`
    : null,
)

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

function copyCloneUrl() {
  navigator.clipboard.writeText(cloneCommand).then(() => {
    copied.value = true
    toast.add({ title: "Copied to clipboard", color: "success" })
    setTimeout(() => {
      copied.value = false
    }, 2000)
  })
}
</script>

<template>
  <div>
    <!-- Header -->
    <div class="mb-6 flex items-center justify-between">
      <div class="flex items-center gap-3">
        <UAvatar :src="ownerAvatarUrl" :label="project.ownerName?.[0]" size="lg" />
        <div>
          <h1 class="text-2xl font-bold">{{ project.name }}</h1>
          <p class="text-sm text-(--ui-text-muted)">{{ project.ownerName }}</p>
        </div>
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
          variant="soft"
          @click="router.visit(`/projects/${project.slug}/settings`)"
        />
        <UButton icon="i-lucide-plus" label="New File" @click="showCreateModal = true" />
      </div>
    </div>

    <!-- Clone URL -->
    <div class="mb-6">
      <div
        class="flex items-center gap-2 rounded-lg bg-(--ui-bg-elevated) border border-(--ui-border) px-3 py-2"
      >
        <UIcon name="i-lucide-terminal" class="size-4 shrink-0 text-(--ui-text-muted)" />
        <code class="flex-1 truncate text-sm font-mono text-(--ui-text-muted)">{{
          cloneCommand
        }}</code>
        <UButton
          :icon="copied ? 'i-lucide-check' : 'i-lucide-copy'"
          size="xs"
          variant="ghost"
          color="neutral"
          @click="copyCloneUrl"
        />
      </div>
      <p class="mt-1.5 text-xs text-(--ui-text-dimmed)">
        Use your email as username and your account password when prompted.
      </p>
    </div>

    <!-- File list -->
    <div v-if="files.length" class="rounded-lg border border-(--ui-border) divide-y divide-(--ui-border)">
      <button
        v-for="file in files"
        :key="file"
        class="flex w-full items-center gap-3 px-4 py-3 text-left transition hover:bg-(--ui-bg-elevated)"
        @click="router.visit(`/projects/${project.slug}/files/${file}`)"
      >
        <UIcon name="i-lucide-file-text" class="size-4 shrink-0 text-(--ui-text-muted)" />
        <span class="flex-1 text-sm font-medium">{{ file }}</span>
        <UIcon name="i-lucide-chevron-right" class="size-4 text-(--ui-text-dimmed)" />
      </button>
    </div>

    <!-- Empty state -->
    <div
      v-else
      class="flex flex-col items-center justify-center rounded-lg border border-dashed border-(--ui-border) py-16"
    >
      <UIcon name="i-lucide-file-plus" class="size-12 text-(--ui-text-dimmed)" />
      <p class="mt-3 font-medium">No files yet</p>
      <p class="mt-1 text-sm text-(--ui-text-muted)">Create a new Markdown file to get started.</p>
      <UButton icon="i-lucide-plus" label="New File" class="mt-4" @click="showCreateModal = true" />
    </div>

    <UModal v-model:open="showCreateModal">
      <template #content>
        <div class="p-6">
          <h2 class="mb-4 text-lg font-semibold">Create New File</h2>
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
            <p class="mb-4 text-xs text-(--ui-text-muted)">
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
