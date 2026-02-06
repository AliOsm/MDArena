<script setup>
import { ref, computed } from "vue"
import { router, usePage } from "@inertiajs/vue3"

const page = usePage()
const projects = computed(() => page.props.projects || [])

const showCreateModal = ref(false)
const projectName = ref("")
const creating = ref(false)

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
      <h1 class="text-2xl font-bold text-gray-900 dark:text-white">Projects</h1>
      <UButton icon="i-lucide-plus" label="New Project" @click="showCreateModal = true" />
    </div>

    <div v-if="projects.length" class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
      <UCard
        v-for="project in projects"
        :key="project.id"
        class="cursor-pointer transition hover:ring-2 hover:ring-primary-500"
        @click="router.visit(`/projects/${project.slug}`)"
      >
        <div class="flex items-start justify-between">
          <h2 class="text-lg font-semibold text-gray-900 dark:text-white">
            {{ project.name }}
          </h2>
          <UBadge :label="project.role" :color="project.role === 'owner' ? 'primary' : 'neutral'" variant="subtle" />
        </div>
        <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
          {{ project.ownerName }}
        </p>
        <p class="mt-2 text-xs text-gray-400 dark:text-gray-500">
          Updated {{ formatDate(project.updatedAt) }}
        </p>
      </UCard>
    </div>

    <UAlert
      v-else
      icon="i-lucide-folder-plus"
      title="No projects yet"
      description="Create a new project to get started."
      color="neutral"
    />

    <UModal v-model:open="showCreateModal">
      <template #content>
        <div class="p-6">
          <h2 class="mb-4 text-lg font-semibold text-gray-900 dark:text-white">Create New Project</h2>
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
