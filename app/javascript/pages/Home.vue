<script setup>
import { usePage } from "@inertiajs/vue3"

const page = usePage()
</script>

<template>
  <div>
    <h1 class="text-2xl font-bold text-gray-900 dark:text-white">
      Welcome, {{ page.props.currentUser?.name }}
    </h1>
    <p class="mt-2 text-gray-600 dark:text-gray-400">
      Your projects will appear here.
    </p>
  </div>
</template>
