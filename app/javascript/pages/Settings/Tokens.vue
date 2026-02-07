<script setup>
import { ref, computed } from "vue"
import { router, usePage } from "@inertiajs/vue3"

const page = usePage()
const toast = useToast()

const tokens = computed(() => page.props.tokens || [])
const newToken = computed(() => page.props.newToken)

const showCreateModal = ref(false)
const tokenName = ref("")
const creating = ref(false)

const columns = [
  { accessorKey: "name", header: "Name" },
  { accessorKey: "tokenPrefix", header: "Token" },
  { accessorKey: "lastUsedAt", header: "Last Used" },
  { id: "status", header: "Status" },
  { id: "actions" },
]

function tokenStatus(token) {
  if (token.revokedAt) return "revoked"
  if (token.expiresAt && new Date(token.expiresAt) < new Date()) return "expired"
  return "active"
}

function formatDate(dateStr) {
  if (!dateStr) return "Never"
  return new Date(dateStr).toLocaleDateString("en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
  })
}

function createToken() {
  if (!tokenName.value.trim()) return
  creating.value = true
  router.post(
    "/settings/tokens",
    { name: tokenName.value },
    {
      onFinish: () => {
        creating.value = false
        showCreateModal.value = false
        tokenName.value = ""
      },
    },
  )
}

function revokeToken(token) {
  router.delete(`/settings/tokens/${token.id}`, {
    onSuccess: () => {
      toast.add({ title: "Token revoked", color: "success" })
    },
  })
}
</script>

<template>
  <div>
    <div class="mb-6 flex items-center justify-between">
      <h1 class="text-2xl font-bold">Personal Access Tokens</h1>
      <UButton icon="i-lucide-plus" label="New Token" @click="showCreateModal = true" />
    </div>

    <UAlert
      v-if="newToken"
      color="warning"
      icon="i-lucide-alert-triangle"
      title="Copy your token now"
      :description="`${newToken} — This token won't be shown again.`"
      class="mb-6"
    />

    <UCard>
      <UTable v-if="tokens.length" :columns="columns" :data="tokens">
        <template #name-cell="{ row }">
          <span :class="{ 'text-(--ui-text-dimmed)': tokenStatus(row.original) !== 'active' }">
            {{ row.original.name }}
          </span>
        </template>

        <template #tokenPrefix-cell="{ row }">
          <code
            class="rounded bg-(--ui-bg-elevated) px-2 py-0.5 font-mono text-sm"
            :class="{ 'text-(--ui-text-dimmed)': tokenStatus(row.original) !== 'active' }"
          >
            {{ row.original.tokenPrefix }}........
          </code>
        </template>

        <template #lastUsedAt-cell="{ row }">
          <span :class="{ 'text-(--ui-text-dimmed)': tokenStatus(row.original) !== 'active' }">
            {{ formatDate(row.original.lastUsedAt) }}
          </span>
        </template>

        <template #status-cell="{ row }">
          <UBadge
            v-if="tokenStatus(row.original) === 'revoked'"
            label="Revoked"
            color="error"
            variant="subtle"
          />
          <UBadge
            v-else-if="tokenStatus(row.original) === 'expired'"
            label="Expired"
            color="warning"
            variant="subtle"
          />
          <UBadge v-else label="Active" color="success" variant="subtle" />
        </template>

        <template #actions-cell="{ row }">
          <UButton
            v-if="tokenStatus(row.original) === 'active'"
            label="Revoke"
            color="error"
            variant="ghost"
            size="xs"
            @click="revokeToken(row.original)"
          />
        </template>
      </UTable>

      <div
        v-else
        class="flex flex-col items-center justify-center py-12"
      >
        <UIcon name="i-lucide-key" class="size-10 text-(--ui-text-dimmed)" />
        <p class="mt-3 font-medium">No tokens yet</p>
        <p class="mt-1 text-sm text-(--ui-text-muted)">Create a personal access token to authenticate Git operations.</p>
      </div>
    </UCard>

    <UModal v-model:open="showCreateModal">
      <template #content>
        <div class="p-6">
          <h2 class="mb-4 text-lg font-semibold">Create New Token</h2>
          <form @submit.prevent="createToken">
            <UFormField label="Token name" class="mb-4">
              <UInput
                v-model="tokenName"
                placeholder="e.g. My laptop"
                icon="i-lucide-tag"
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
