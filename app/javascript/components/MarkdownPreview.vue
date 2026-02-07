<script setup>
import { computed } from "vue"
import MarkdownIt from "markdown-it"

const props = defineProps({
  content: {
    type: String,
    default: "",
  },
})

const md = new MarkdownIt({
  html: false,
  linkify: true,
  typographer: true,
})

const rendered = computed(() => md.render(props.content || ""))
</script>

<template>
  <div
    class="prose max-w-none dark:prose-invert prose-headings:font-semibold prose-a:text-(--ui-primary) prose-a:no-underline hover:prose-a:underline prose-code:rounded prose-code:bg-(--ui-bg-elevated) prose-code:px-1.5 prose-code:py-0.5 prose-code:before:content-none prose-code:after:content-none"
    v-html="rendered"
  />
</template>
