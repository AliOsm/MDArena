<script setup>
import { ref } from "vue"
import { router, usePage } from "@inertiajs/vue3"

defineOptions({ layout: false })

const page = usePage()
const form = ref({
  email: "",
  password: "",
})
const processing = ref(false)

function submit() {
  processing.value = true
  router.post("/users/sign_in", { user: form.value }, {
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
          Sign in to your account
        </p>
      </div>

      <form class="space-y-4" @submit.prevent="submit">
        <UFormField label="Email" :error="page.props.errors?.email">
          <UInput
            v-model="form.email"
            type="email"
            placeholder="you@example.com"
            icon="i-lucide-mail"
            autofocus
            required
          />
        </UFormField>

        <UFormField label="Password" :error="page.props.errors?.password">
          <UInput
            v-model="form.password"
            type="password"
            placeholder="Your password"
            icon="i-lucide-lock"
            required
          />
        </UFormField>

        <UButton type="submit" block :loading="processing">
          Sign in
        </UButton>
      </form>

      <p class="text-center text-sm text-gray-600 dark:text-gray-400">
        Don't have an account?
        <a href="/users/sign_up" class="font-medium text-primary-600 hover:text-primary-500" @click.prevent="router.visit('/users/sign_up')">
          Sign up
        </a>
      </p>
    </div>
  </div>
</template>
