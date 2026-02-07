<script setup>
import { ref, shallowRef, computed, onMounted, onBeforeUnmount } from "vue"
import { usePage, router } from "@inertiajs/vue3"
import { EditorState } from "@codemirror/state"
import { EditorView, basicSetup } from "codemirror"
import { markdown } from "@codemirror/lang-markdown"
import { yCollab } from "y-codemirror.next"
import * as Y from "yjs"
import { createConsumer } from "@rails/actioncable"
import MarkdownPreview from "@/components/MarkdownPreview.vue"
import EditorLayout from "@/layouts/EditorLayout.vue"

defineOptions({ layout: EditorLayout })

const page = usePage()
const project = page.props.project
const path = page.props.path
const initialContent = page.props.content
const toast = useToast()

const editorContainer = ref(null)
const editorView = shallowRef(null)
const previewVisible = ref(true)
const saving = ref(false)
const connectionStatus = ref("connecting")
const editorContent = ref(initialContent || "")

let pendingSave = false
let pendingSaveTimer = null

const wordCount = computed(() => {
  const text = editorContent.value.trim()
  if (!text) return 0
  return text.split(/\s+/).length
})

const charCount = computed(() => editorContent.value.length)

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
            pendingSave = false
          } else {
            clearAutoSaveTimer()
            toast.add({
              title: "File updated externally, reloading...",
              color: "warning",
            })
            router.visit(`/projects/${project.slug}/files/${path}/edit`)
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
  <div class="flex flex-col flex-1 min-h-0">
    <!-- Toolbar -->
    <div
      class="relative z-50 flex h-12 shrink-0 items-center gap-2 border-b border-(--ui-border) bg-(--ui-bg-elevated) px-4"
    >
      <UButton
        icon="i-lucide-arrow-left"
        size="xs"
        variant="ghost"
        color="neutral"
        @click="router.visit(`/projects/${project.slug}/files/${path}`)"
      />

      <USeparator orientation="vertical" class="h-5" />

      <div class="flex items-center gap-1 text-sm text-(--ui-text-muted) min-w-0">
        <span class="truncate">{{ project.name }}</span>
        <UIcon name="i-lucide-chevron-right" class="size-3.5 shrink-0" />
        <span class="truncate font-medium text-(--ui-text)">{{ path }}</span>
      </div>

      <div class="ml-auto flex items-center gap-2">
        <UButton
          icon="i-lucide-save"
          label="Save"
          size="xs"
          :loading="saving"
          @click="save"
        />
        <UButton
          :icon="previewVisible ? 'i-lucide-panel-right-close' : 'i-lucide-panel-right-open'"
          size="xs"
          variant="ghost"
          color="neutral"
          @click="previewVisible = !previewVisible"
        />

        <USeparator orientation="vertical" class="h-5" />

        <div class="flex items-center gap-1.5">
          <UIcon
            name="i-lucide-wifi"
            class="size-4"
            :class="connectionStatus === 'connected' ? 'text-(--ui-success)' : 'text-(--ui-error)'"
          />
          <UBadge
            :color="connectionStatus === 'connected' ? 'success' : 'error'"
            variant="subtle"
            size="xs"
            :label="connectionStatus"
          />
        </div>
      </div>
    </div>

    <!-- Split pane editor/preview -->
    <UDashboardGroup storage-key="editor-split" class="flex-1 min-h-0">
      <UDashboardPanel id="editor-panel">
        <template #header>
          <div class="flex items-center justify-between w-full px-4 text-sm">
            <span class="font-medium text-(--ui-text-muted)">Editor</span>
            <span class="text-xs text-(--ui-text-dimmed)">
              {{ wordCount }} words &middot; {{ charCount }} chars
            </span>
          </div>
        </template>
        <template #body>
          <div
            ref="editorContainer"
            class="h-full [&_.cm-editor]:h-full [&_.cm-editor]:outline-none"
          />
        </template>
      </UDashboardPanel>

      <UDashboardPanel
        v-if="previewVisible"
        id="preview-panel"
        resizable
        :default-size="50"
        :min-size="25"
        :max-size="70"
      >
        <template #header>
          <div class="px-4 text-sm">
            <span class="font-medium text-(--ui-text-muted)">Preview</span>
          </div>
        </template>
        <template #body>
          <div class="p-6 overflow-auto h-full">
            <MarkdownPreview :content="editorContent" />
          </div>
        </template>
      </UDashboardPanel>
    </UDashboardGroup>
  </div>
</template>
