<script setup>
import { ref, computed } from "vue"
import { router, usePage } from "@inertiajs/vue3"

const page = usePage()
const allProjects = computed(() => page.props.projects || [])

const showCreateModal = ref(false)
const projectName = ref("")
const creating = ref(false)
const search = ref("")

const projects = computed(() => {
  if (!search.value.trim()) return allProjects.value
  const q = search.value.toLowerCase()
  return allProjects.value.filter((p) => p.name.toLowerCase().includes(q))
})

function formatDate(dateStr) {
  if (!dateStr) return ""
  return new Date(dateStr).toLocaleDateString("en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
  })
}

function createProject() {
  if (!projectName.value.trim()) return
  creating.value = true
  router.post(
    "/projects",
    { name: projectName.value },
    {
      onFinish: () => {
        creating.value = false
        showCreateModal.value = false
        projectName.value = ""
      },
    },
  )
}
</script>

<template>
  <div>
    <div class="mb-6 flex items-center justify-between">
      <h1 class="text-2xl font-bold">Projects</h1>
      <UButton icon="i-lucide-plus" label="New Project" @click="showCreateModal = true" />
    </div>

    <div v-if="allProjects.length" class="mb-6">
      <UInput
        v-model="search"
        icon="i-lucide-search"
        placeholder="Search projects..."
        class="max-w-sm"
      />
    </div>

    <div v-if="projects.length" class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
      <UCard
        v-for="project in projects"
        :key="project.id"
        class="cursor-pointer transition hover:ring-2 hover:ring-(--ui-primary)"
        @click="router.visit(`/projects/${project.slug}`)"
      >
        <div class="flex items-start gap-3">
          <div
            class="flex size-10 shrink-0 items-center justify-center rounded-lg bg-(--ui-primary)/10"
          >
            <UIcon name="i-lucide-folder" class="size-5 text-(--ui-primary)" />
          </div>
          <div class="min-w-0 flex-1">
            <div class="flex items-center justify-between gap-2">
              <h2 class="font-semibold truncate">{{ project.name }}</h2>
              <UBadge
                :label="project.role"
                :color="project.role === 'owner' ? 'primary' : 'neutral'"
                variant="subtle"
                size="xs"
              />
            </div>
            <p class="mt-0.5 text-sm text-(--ui-text-muted)">{{ project.ownerName }}</p>
            <p class="mt-1 text-xs text-(--ui-text-dimmed)">
              Updated {{ formatDate(project.updatedAt) }}
            </p>
          </div>
        </div>
      </UCard>
    </div>

    <div
      v-else-if="!allProjects.length"
      class="flex flex-col items-center justify-center rounded-lg border border-dashed border-(--ui-border) py-16"
    >
      <UIcon name="i-lucide-folder-plus" class="size-12 text-(--ui-text-dimmed)" />
      <p class="mt-3 font-medium">No projects yet</p>
      <p class="mt-1 text-sm text-(--ui-text-muted)">Create a new project to get started.</p>
      <UButton icon="i-lucide-plus" label="New Project" class="mt-4" @click="showCreateModal = true" />
    </div>

    <div
      v-else
      class="flex flex-col items-center justify-center rounded-lg border border-dashed border-(--ui-border) py-16"
    >
      <UIcon name="i-lucide-search-x" class="size-12 text-(--ui-text-dimmed)" />
      <p class="mt-3 font-medium">No matching projects</p>
      <p class="mt-1 text-sm text-(--ui-text-muted)">Try a different search term.</p>
    </div>

    <UModal v-model:open="showCreateModal">
      <template #content>
        <div class="p-6">
          <h2 class="mb-4 text-lg font-semibold">Create New Project</h2>
          <form @submit.prevent="createProject">
            <UFormField label="Project name" class="mb-4">
              <UInput
                v-model="projectName"
                placeholder="e.g. My Documentation"
                icon="i-lucide-folder"
                autofocus
                required
              />
            </UFormField>
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
