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
  { key: "name", label: "Name" },
  { key: "token", label: "Token" },
  { key: "lastUsedAt", label: "Last Used" },
  { key: "status", label: "Status" },
  { key: "actions", label: "" },
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
      <h1 class="text-2xl font-bold text-gray-900 dark:text-white">Personal Access Tokens</h1>
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

    <UTable v-if="tokens.length" :columns="columns" :rows="tokens">
      <template #name-cell="{ row }">
        <span :class="{ 'text-gray-400 dark:text-gray-600': tokenStatus(row) !== 'active' }">
          {{ row.name }}
        </span>
      </template>

      <template #token-cell="{ row }">
        <code
          class="rounded bg-gray-100 px-2 py-0.5 font-mono text-sm dark:bg-gray-800"
          :class="{ 'text-gray-400 dark:text-gray-600': tokenStatus(row) !== 'active' }"
        >
          {{ row.tokenPrefix }}........
        </code>
      </template>

      <template #lastUsedAt-cell="{ row }">
        <span :class="{ 'text-gray-400 dark:text-gray-600': tokenStatus(row) !== 'active' }">
          {{ formatDate(row.lastUsedAt) }}
        </span>
      </template>

      <template #status-cell="{ row }">
        <UBadge
          v-if="tokenStatus(row) === 'revoked'"
          label="Revoked"
          color="error"
          variant="subtle"
        />
        <UBadge
          v-else-if="tokenStatus(row) === 'expired'"
          label="Expired"
          color="warning"
          variant="subtle"
        />
        <UBadge v-else label="Active" color="success" variant="subtle" />
      </template>

      <template #actions-cell="{ row }">
        <UButton
          v-if="tokenStatus(row) === 'active'"
          label="Revoke"
          color="error"
          variant="ghost"
          size="xs"
          @click="revokeToken(row)"
        />
      </template>
    </UTable>

    <UAlert
      v-else
      icon="i-lucide-key"
      title="No tokens yet"
      description="Create a personal access token to authenticate Git operations."
      color="neutral"
    />

    <UModal v-model:open="showCreateModal">
      <template #content>
        <div class="p-6">
          <h2 class="mb-4 text-lg font-semibold text-gray-900 dark:text-white">
            Create New Token
          </h2>
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
