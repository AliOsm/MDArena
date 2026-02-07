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
  <UApp>
    <div class="flex min-h-screen">
      <!-- Left panel: branding (hidden on small screens) -->
      <div
        class="hidden lg:flex lg:w-1/2 flex-col justify-between bg-gradient-to-br from-stone-950 via-red-950 to-stone-950 p-12 text-white"
      >
        <div>
          <div class="flex items-center gap-3">
            <UIcon name="i-lucide-swords" class="size-8" />
            <span class="text-2xl font-bold">MDArena</span>
          </div>
          <p class="mt-4 text-lg text-stone-400">Collaborative Markdown, powered by Git.</p>
        </div>

        <div class="space-y-6">
          <div class="flex items-start gap-3">
            <UIcon name="i-lucide-git-branch" class="size-5 mt-0.5 shrink-0 text-red-400" />
            <div>
              <p class="font-semibold">Git-backed versioning</p>
              <p class="text-sm text-stone-400">Every edit is a commit. Full history, always.</p>
            </div>
          </div>
          <div class="flex items-start gap-3">
            <UIcon name="i-lucide-users" class="size-5 mt-0.5 shrink-0 text-red-400" />
            <div>
              <p class="font-semibold">Real-time collaboration</p>
              <p class="text-sm text-stone-400">Edit together with conflict-free sync.</p>
            </div>
          </div>
          <div class="flex items-start gap-3">
            <UIcon name="i-lucide-terminal" class="size-5 mt-0.5 shrink-0 text-red-400" />
            <div>
              <p class="font-semibold">Clone over HTTPS</p>
              <p class="text-sm text-stone-400">Use your favorite tools. Push and pull like any repo.</p>
            </div>
          </div>
        </div>

        <p class="text-sm text-red-400">&copy; 2026 MDArena</p>
      </div>

      <!-- Right panel: form -->
      <div class="flex flex-1 items-center justify-center bg-(--ui-bg) px-4">
        <div class="w-full max-w-sm space-y-6">
          <div class="flex flex-col items-center gap-3">
            <div class="flex size-12 items-center justify-center rounded-xl bg-(--ui-primary)/10">
              <UIcon name="i-lucide-swords" class="size-6 text-(--ui-primary)" />
            </div>
            <div class="text-center">
              <h1 class="text-2xl font-bold">Create your account</h1>
              <p class="mt-1 text-sm text-(--ui-text-muted)">Get started with MDArena</p>
            </div>
          </div>

          <UCard>
            <form class="space-y-4" @submit.prevent="submit">
              <UFormField label="Name" :error="page.props.errors?.name?.[0]">
                <UInput
                  class="w-full"
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
                  class="w-full"
                  v-model="form.email"
                  type="email"
                  placeholder="you@example.com"
                  icon="i-lucide-mail"
                  required
                />
              </UFormField>

              <UFormField label="Password" :error="page.props.errors?.password?.[0]">
                <UInput
                  class="w-full"
                  v-model="form.password"
                  type="password"
                  placeholder="Choose a password"
                  icon="i-lucide-lock"
                  required
                />
              </UFormField>

              <UFormField label="Confirm password" :error="page.props.errors?.password_confirmation?.[0]">
                <UInput
                  class="w-full"
                  v-model="form.password_confirmation"
                  type="password"
                  placeholder="Confirm your password"
                  icon="i-lucide-lock"
                  required
                />
              </UFormField>

              <UButton type="submit" block :loading="processing">Sign up</UButton>
            </form>
          </UCard>

          <p class="text-center text-sm text-(--ui-text-muted)">
            Already have an account?
            <a
              href="/users/sign_in"
              class="font-medium text-(--ui-primary) hover:underline"
              @click.prevent="router.visit('/users/sign_in')"
            >
              Sign in
            </a>
          </p>
        </div>
      </div>
    </div>
  </UApp>
</template>
