<script setup>
import { ref, computed } from "vue"
import { router, usePage } from "@inertiajs/vue3"

const page = usePage()
const toast = useToast()

const user = computed(() => page.props.user)
const errors = computed(() => page.props.errors || {})

const name = ref(user.value.name)
const email = ref(user.value.email)
const currentPassword = ref("")
const password = ref("")
const passwordConfirmation = ref("")
const saving = ref(false)

function updateProfile() {
  saving.value = true
  const data = { name: name.value, email: email.value }

  if (password.value) {
    data.current_password = currentPassword.value
    data.password = password.value
    data.password_confirmation = passwordConfirmation.value
  }

  router.patch("/settings/profile", data, {
    onSuccess: () => {
      toast.add({ title: "Profile updated", color: "success" })
      currentPassword.value = ""
      password.value = ""
      passwordConfirmation.value = ""
    },
    onFinish: () => {
      saving.value = false
    },
  })
}
</script>

<template>
  <div class="mx-auto max-w-2xl">
    <h1 class="mb-6 text-2xl font-bold text-gray-900 dark:text-white">Profile Settings</h1>

    <form @submit.prevent="updateProfile">
      <div class="mb-8 space-y-4">
        <h2 class="text-lg font-semibold text-gray-900 dark:text-white">Account Information</h2>

        <UFormField label="Name" :error="errors.name?.[0]">
          <UInput
            v-model="name"
            placeholder="Your name"
            icon="i-lucide-user"
            class="w-full"
            required
          />
        </UFormField>

        <UFormField label="Email" :error="errors.email?.[0]">
          <UInput
            v-model="email"
            type="email"
            placeholder="your@email.com"
            icon="i-lucide-mail"
            class="w-full"
            required
          />
        </UFormField>
      </div>

      <div class="mb-8 space-y-4">
        <h2 class="text-lg font-semibold text-gray-900 dark:text-white">Change Password</h2>
        <p class="text-sm text-gray-500 dark:text-gray-400">
          Leave blank if you don't want to change your password.
        </p>

        <UFormField label="Current password" :error="errors.current_password?.[0]">
          <UInput
            v-model="currentPassword"
            type="password"
            placeholder="Enter current password"
            icon="i-lucide-lock"
            class="w-full"
          />
        </UFormField>

        <UFormField label="New password" :error="errors.password?.[0]">
          <UInput
            v-model="password"
            type="password"
            placeholder="Enter new password"
            icon="i-lucide-lock"
            class="w-full"
          />
        </UFormField>

        <UFormField label="Confirm new password" :error="errors.password_confirmation?.[0]">
          <UInput
            v-model="passwordConfirmation"
            type="password"
            placeholder="Confirm new password"
            icon="i-lucide-lock"
            class="w-full"
          />
        </UFormField>
      </div>

      <div class="flex justify-end">
        <UButton type="submit" label="Save Changes" icon="i-lucide-save" :loading="saving" />
      </div>
    </form>
  </div>
</template>
