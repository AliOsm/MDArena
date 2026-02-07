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

        <p class="text-sm text-red-400">&copy; 2025 MDArena</p>
      </div>

      <!-- Right panel: form -->
      <div class="flex flex-1 items-center justify-center bg-(--ui-bg) px-4">
        <div class="w-full max-w-sm space-y-6">
          <div class="flex flex-col items-center gap-3">
            <div class="flex size-12 items-center justify-center rounded-xl bg-(--ui-primary)/10">
              <UIcon name="i-lucide-swords" class="size-6 text-(--ui-primary)" />
            </div>
            <div class="text-center">
              <h1 class="text-2xl font-bold">Welcome back</h1>
              <p class="mt-1 text-sm text-(--ui-text-muted)">Sign in to your account</p>
            </div>
          </div>

          <UCard>
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

              <UButton type="submit" block :loading="processing">Sign in</UButton>
            </form>
          </UCard>

          <p class="text-center text-sm text-(--ui-text-muted)">
            Don't have an account?
            <a
              href="/users/sign_up"
              class="font-medium text-(--ui-primary) hover:underline"
              @click.prevent="router.visit('/users/sign_up')"
            >
              Sign up
            </a>
          </p>
        </div>
      </div>
    </div>
  </UApp>
</template>
