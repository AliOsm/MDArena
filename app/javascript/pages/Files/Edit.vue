<script setup>
import { ref, shallowRef, onMounted, onBeforeUnmount } from "vue"
import { usePage, router } from "@inertiajs/vue3"
import { EditorState } from "@codemirror/state"
import { EditorView, basicSetup } from "codemirror"
import { markdown } from "@codemirror/lang-markdown"
import { yCollab } from "y-codemirror.next"
import * as Y from "yjs"
import { createConsumer } from "@rails/actioncable"
import MarkdownPreview from "@/components/MarkdownPreview.vue"

const page = usePage()
const project = page.props.project
const path = page.props.path
const initialContent = page.props.content
const headSha = page.props.headSha
const toast = useToast()

const editorContainer = ref(null)
const editorView = shallowRef(null)
const showPreview = ref(false)
const saving = ref(false)
const connectionStatus = ref("connecting")
const editorContent = ref(initialContent || "")
const fileChangedExternally = ref(false)

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
  subscription.send({ type: "update", update: base64, sender: String(ydoc.clientID) })
}

// Auto-save timer (60 seconds of inactivity)
let autoSaveTimer = null
const AUTO_SAVE_DELAY = 60_000

function resetAutoSaveTimer() {
  if (autoSaveTimer) clearTimeout(autoSaveTimer)
  autoSaveTimer = setTimeout(() => {
    if (subscription) {
      pendingSave = true
      subscription.send({ type: "save" })
      if (pendingSaveTimer) clearTimeout(pendingSaveTimer)
      pendingSaveTimer = setTimeout(() => {
        pendingSave = false
      }, 30_000)
    }
  }, AUTO_SAVE_DELAY)
}

function clearAutoSaveTimer() {
  if (autoSaveTimer) {
    clearTimeout(autoSaveTimer)
    autoSaveTimer = null
  }
}

// Listen for local Y.Doc updates and send to channel
ydoc.on("update", (update, origin) => {
  if (origin !== "remote") {
    sendUpdate(update)
    resetAutoSaveTimer()
  }

  // Sync editor content for preview
  editorContent.value = ytext.toString()
})

onMounted(() => {
  // Initialize CodeMirror with yCollab for real-time collaborative editing
  // Don't set doc: initialContent here — yCollab will populate the editor
  // from the Y.js sync received via the DocumentChannel to avoid duplication.
  const state = EditorState.create({
    doc: "",
    extensions: [basicSetup, markdown(), yCollab(ytext, null, { undoManager })],
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
          if (String(data.sender) !== String(ydoc.clientID)) {
            Y.transact(
              ydoc,
              () => {
                applyRemoteUpdate(data.update)
              },
              "remote",
            )
          }
        } else if (data.type === "saved") {
          saving.value = false
          toast.add({ title: "File saved", color: "success" })
        } else if (data.type === "file_changed") {
          if (pendingSave) {
            // This change was triggered by our own save — ignore it
            pendingSave = false
          } else {
            fileChangedExternally.value = true
            toast.add({
              title: "File changed externally",
              description:
                "This file was changed outside the editor. Please refresh to get the latest version.",
              color: "warning",
            })
          }
        }
      },
    },
  )
})

onBeforeUnmount(() => {
  clearAutoSaveTimer()
  if (pendingSaveTimer) clearTimeout(pendingSaveTimer)
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

let pendingSave = false
let pendingSaveTimer = null

function save() {
  if (!subscription) return
  saving.value = true
  pendingSave = true
  subscription.send({ type: "save" })

  // Suppress file_changed events for 30 seconds after save
  // since the commit is expected and not an external change
  if (pendingSaveTimer) clearTimeout(pendingSaveTimer)
  pendingSaveTimer = setTimeout(() => {
    pendingSave = false
  }, 30_000)
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

    <UAlert
      v-if="fileChangedExternally"
      color="warning"
      icon="i-lucide-alert-triangle"
      title="This file was changed outside the editor. Please refresh to get the latest version."
      class="mb-4"
    >
      <template #actions>
        <UButton
          label="Refresh"
          color="warning"
          variant="soft"
          @click="router.visit(`/projects/${project.slug}/files/${path}/edit`)"
        />
      </template>
    </UAlert>

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
