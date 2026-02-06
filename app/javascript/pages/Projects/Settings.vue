<script setup>
import { ref, computed } from "vue"
import { router, usePage } from "@inertiajs/vue3"

const page = usePage()
const toast = useToast()

const project = page.props.project
const members = computed(() => page.props.members || [])

const email = ref("")
const role = ref("editor")
const adding = ref(false)

const columns = [
  { key: "userName", label: "Name" },
  { key: "userEmail", label: "Email" },
  { key: "role", label: "Role" },
  { key: "actions", label: "" },
]

const roleOptions = [
  { label: "Editor", value: "editor" },
  { label: "Owner", value: "owner" },
]

function addMember() {
  if (!email.value.trim()) return
  adding.value = true
  router.post(
    `/projects/${project.slug}/memberships`,
    { email: email.value, role: role.value },
    {
      onFinish: () => {
        adding.value = false
        email.value = ""
        role.value = "editor"
      },
    },
  )
}

function removeMember(member) {
  router.delete(`/projects/${project.slug}/memberships/${member.id}`, {
    onSuccess: () => {
      toast.add({ title: "Member removed", color: "success" })
    },
  })
}
</script>

<template>
  <div>
    <div class="mb-2">
      <UButton
        variant="link"
        icon="i-lucide-arrow-left"
        :label="project.name"
        @click="router.visit(`/projects/${project.slug}`)"
      />
    </div>

    <h1 class="mb-6 text-2xl font-bold text-gray-900 dark:text-white">Project Settings</h1>

    <div class="mb-8">
      <h2 class="mb-4 text-lg font-semibold text-gray-900 dark:text-white">Members</h2>

      <UTable v-if="members.length" :columns="columns" :rows="members">
        <template #role-cell="{ row }">
          <UBadge
            :label="row.role"
            :color="row.role === 'owner' ? 'primary' : 'neutral'"
            variant="subtle"
          />
        </template>

        <template #actions-cell="{ row }">
          <UButton
            v-if="row.userEmail !== page.props.currentUser?.email"
            label="Remove"
            color="error"
            variant="ghost"
            size="xs"
            @click="removeMember(row)"
          />
        </template>
      </UTable>
    </div>

    <div
      class="rounded-lg border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-900"
    >
      <h2 class="mb-4 text-lg font-semibold text-gray-900 dark:text-white">Add Member</h2>
      <form class="flex items-end gap-3" @submit.prevent="addMember">
        <UFormField label="Email" class="flex-1">
          <UInput
            v-model="email"
            type="email"
            placeholder="user@example.com"
            icon="i-lucide-mail"
            required
          />
        </UFormField>
        <UFormField label="Role">
          <USelect v-model="role" :items="roleOptions" />
        </UFormField>
        <UButton type="submit" label="Add" icon="i-lucide-user-plus" :loading="adding" />
      </form>
    </div>
  </div>
</template>
