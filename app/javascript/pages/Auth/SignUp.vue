<script setup>
import { ref } from "vue"
import { router, usePage } from "@inertiajs/vue3"

defineOptions({ layout: false })

const page = usePage()
const form = ref({
  name: "",
  email: "",
  password: "",
  password_confirmation: "",
})
const processing = ref(false)

function submit() {
  processing.value = true
  router.post("/users", { user: form.value }, {
    onFinish: () => {
      processing.value = false
    },
  })
}
</script>

<template>
  <div class="flex min-h-screen items-center justify-center bg-gray-50 dark:bg-gray-950 px-4">
    <div class="w-full max-w-sm space-y-6">
      <div class="text-center">
        <h1 class="text-2xl font-bold text-gray-900 dark:text-white">
          MarkdownForge
        </h1>
        <p class="mt-2 text-sm text-gray-600 dark:text-gray-400">
          Create your account
        </p>
      </div>

      <form class="space-y-4" @submit.prevent="submit">
        <UFormField label="Name" :error="page.props.errors?.name?.[0]">
          <UInput
            v-model="form.name"
            type="text"
            placeholder="Your name"
            icon="i-lucide-user"
            autofocus
            required
          />
        </UFormField>

        <UFormField label="Email" :error="page.props.errors?.email?.[0]">
          <UInput
            v-model="form.email"
            type="email"
            placeholder="you@example.com"
            icon="i-lucide-mail"
            required
          />
        </UFormField>

        <UFormField label="Password" :error="page.props.errors?.password?.[0]">
          <UInput
            v-model="form.password"
            type="password"
            placeholder="Choose a password"
            icon="i-lucide-lock"
            required
          />
        </UFormField>

        <UFormField label="Confirm password" :error="page.props.errors?.password_confirmation?.[0]">
          <UInput
            v-model="form.password_confirmation"
            type="password"
            placeholder="Confirm your password"
            icon="i-lucide-lock"
            required
          />
        </UFormField>

        <UButton type="submit" block :loading="processing">
          Sign up
        </UButton>
      </form>

      <p class="text-center text-sm text-gray-600 dark:text-gray-400">
        Already have an account?
        <a href="/users/sign_in" class="font-medium text-primary-600 hover:text-primary-500" @click.prevent="router.visit('/users/sign_in')">
          Sign in
        </a>
      </p>
    </div>
  </div>
</template>
