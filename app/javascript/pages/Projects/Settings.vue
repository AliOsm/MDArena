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
  { accessorKey: "userName", header: "Name" },
  { accessorKey: "userEmail", header: "Email" },
  { accessorKey: "role", header: "Role" },
  { id: "actions" },
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
    <!-- Breadcrumb -->
    <div class="mb-4 flex items-center gap-1 text-sm text-(--ui-text-muted)">
      <UButton
        variant="link"
        :label="project.name"
        @click="router.visit(`/projects/${project.slug}`)"
        class="p-0"
      />
      <UIcon name="i-lucide-chevron-right" class="size-3.5" />
      <span class="font-medium text-(--ui-text)">Settings</span>
    </div>

    <h1 class="mb-6 text-2xl font-bold">Project Settings</h1>

    <div class="space-y-6">
      <UCard>
        <template #header>
          <div class="flex items-center gap-2">
            <UIcon name="i-lucide-users" class="size-4 text-(--ui-text-muted)" />
            <span class="font-semibold text-sm">Members</span>
          </div>
        </template>

        <div class="overflow-x-auto">
        <UTable v-if="members.length" :columns="columns" :data="members">
          <template #role-cell="{ row }">
            <UBadge
              :label="row.original.role"
              :color="row.original.role === 'owner' ? 'primary' : 'neutral'"
              variant="subtle"
            />
          </template>

          <template #actions-cell="{ row }">
            <UButton
              v-if="row.original.userEmail !== page.props.currentUser?.email"
              label="Remove"
              color="error"
              variant="ghost"
              size="xs"
              @click="removeMember(row.original)"
            />
          </template>
        </UTable>
        </div>
      </UCard>

      <UCard>
        <template #header>
          <div class="flex items-center gap-2">
            <UIcon name="i-lucide-user-plus" class="size-4 text-(--ui-text-muted)" />
            <span class="font-semibold text-sm">Add Member</span>
          </div>
        </template>
        <form class="flex flex-col sm:flex-row sm:items-end gap-3" @submit.prevent="addMember">
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
      </UCard>
    </div>
  </div>
</template>
