<script setup>
import { ref, shallowRef, onMounted, onBeforeUnmount } from "vue"
import { usePage, router } from "@inertiajs/vue3"
import { EditorState } from "@codemirror/state"
import { EditorView, basicSetup } from "codemirror"
import { markdown } from "@codemirror/lang-markdown"
import * as Y from "yjs"
import { createConsumer } from "@rails/actioncable"
import MarkdownPreview from "@/components/MarkdownPreview.vue"

const page = usePage()
const project = page.props.project
const path = page.props.path
const initialContent = page.props.content
const headSha = page.props.headSha
const currentUserId = page.props.currentUser.id

const toast = useToast()

const editorContainer = ref(null)
const editorView = shallowRef(null)
const showPreview = ref(false)
const saving = ref(false)
const connectionStatus = ref("connecting")
const editorContent = ref(initialContent || "")

// Y.js setup
const ydoc = new Y.Doc()
const ytext = ydoc.getText("content")
const undoManager = new Y.UndoManager(ytext)

// Action Cable
let subscription = null
const consumer = createConsumer()

function applyRemoteUpdate(base64Update) {
  const bytes = Uint8Array.from(atob(base64Update), (c) => c.charCodeAt(0))
  Y.applyUpdate(ydoc, bytes)
}

function applyRemoteState(base64State) {
  const bytes = Uint8Array.from(atob(base64State), (c) => c.charCodeAt(0))
  Y.applyUpdate(ydoc, bytes)
}

function sendUpdate(update) {
  if (!subscription) return
  const base64 = btoa(String.fromCharCode(...update))
  subscription.send({ type: "update", update: base64, sender: String(currentUserId) })
}

// Listen for local Y.Doc updates and send to channel
ydoc.on("update", (update, origin) => {
  if (origin !== "remote") {
    sendUpdate(update)
  }

  // Sync editor content for preview
  editorContent.value = ytext.toString()
})

onMounted(() => {
  // Initialize CodeMirror with basic setup (yCollab integration comes in US-037)
  const state = EditorState.create({
    doc: initialContent || "",
    extensions: [
      basicSetup,
      markdown(),
      EditorView.updateListener.of((update) => {
        if (update.docChanged) {
          editorContent.value = update.state.doc.toString()
        }
      }),
    ],
  })

  editorView.value = new EditorView({
    state,
    parent: editorContainer.value,
  })

  // Subscribe to DocumentChannel
  subscription = consumer.subscriptions.create(
    { channel: "DocumentChannel", project_id: project.id, file_path: path },
    {
      connected() {
        connectionStatus.value = "connected"
      },

      disconnected() {
        connectionStatus.value = "disconnected"
      },

      received(data) {
        if (data.type === "sync") {
          applyRemoteState(data.state)
          connectionStatus.value = "connected"
        } else if (data.type === "update") {
          if (String(data.sender) !== String(currentUserId)) {
            Y.transact(ydoc, () => {
              applyRemoteUpdate(data.update)
            }, "remote")
          }
        }
      },
    },
  )
})

onBeforeUnmount(() => {
  if (subscription) {
    subscription.unsubscribe()
    subscription = null
  }
  consumer.disconnect()
  if (editorView.value) {
    editorView.value.destroy()
  }
  ydoc.destroy()
})

function save() {
  if (!editorView.value) return
  const content = editorView.value.state.doc.toString()
  saving.value = true

  router.patch(
    `/projects/${project.slug}/files/${path}`,
    {
      content,
      commit_message: `Update ${path}`,
      base_commit_sha: headSha,
    },
    {
      preserveScroll: true,
      onSuccess: () => {
        toast.add({
          title: "File saved",
          color: "success",
        })
      },
      onError: () => {
        toast.add({
          title: "Save failed",
          description:
            "The file may have been modified by someone else. Please refresh and try again.",
          color: "error",
        })
      },
      onFinish: () => {
        saving.value = false
      },
    },
  )
}
</script>

<template>
  <div>
    <div class="mb-6">
      <div class="mb-2 flex items-center gap-2 text-sm text-gray-500 dark:text-gray-400">
        <UButton
          variant="link"
          :label="project.name"
          @click="router.visit(`/projects/${project.slug}`)"
          class="p-0"
        />
        <span>/</span>
      </div>
      <h1 class="text-2xl font-bold text-gray-900 dark:text-white">{{ path }}</h1>
    </div>

    <div class="mb-4 flex flex-wrap items-center gap-2">
      <UButton icon="i-lucide-save" label="Save" :loading="saving" @click="save" />
      <UButton
        :icon="showPreview ? 'i-lucide-code' : 'i-lucide-eye'"
        :label="showPreview ? 'Editor' : 'Preview'"
        variant="soft"
        color="neutral"
        @click="showPreview = !showPreview"
      />
      <UButton
        icon="i-lucide-arrow-left"
        label="Back to file"
        variant="ghost"
        color="neutral"
        @click="router.visit(`/projects/${project.slug}/files/${path}`)"
      />
      <div class="ml-auto">
        <UBadge :color="connectionStatus === 'connected' ? 'success' : 'error'" variant="subtle">
          {{ connectionStatus }}
        </UBadge>
      </div>
    </div>

    <div
      v-show="!showPreview"
      ref="editorContainer"
      class="rounded-lg border border-gray-200 dark:border-gray-700 [&_.cm-editor]:min-h-[60vh] [&_.cm-editor]:outline-none"
    />

    <div v-show="showPreview" class="rounded-lg border border-gray-200 p-6 dark:border-gray-700">
      <MarkdownPreview :content="editorContent" />
    </div>
  </div>
</template>
