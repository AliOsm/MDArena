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
  <div class="prose prose-sm max-w-none dark:prose-invert" v-html="rendered" />
</template>
