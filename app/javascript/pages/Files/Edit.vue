<script setup>
import { ref, shallowRef, computed, onMounted, onBeforeUnmount } from "vue"
import { usePage, router } from "@inertiajs/vue3"
import { EditorState } from "@codemirror/state"
import { EditorView, basicSetup } from "codemirror"
import { markdown } from "@codemirror/lang-markdown"
import { yCollab } from "y-codemirror.next"
import * as Y from "yjs"
import { Awareness, encodeAwarenessUpdate, applyAwarenessUpdate } from "y-protocols/awareness"
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
const previewVisible = ref(window.innerWidth >= 640)
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

// CodeMirror theme using Nuxt UI CSS variables (adapts to light/dark mode)
const editorTheme = EditorView.theme({
  "&": {
    fontSize: "14px",
  },
  "&.cm-focused": {
    outline: "none",
  },
  ".cm-scroller": {
    fontFamily: "ui-monospace, 'Cascadia Code', 'Source Code Pro', Menlo, Consolas, monospace",
    lineHeight: "1.6",
  },
  ".cm-content": {
    padding: "8px 0",
    caretColor: "var(--ui-primary)",
  },
  ".cm-line": {
    padding: "0 16px",
  },
  ".cm-cursor, .cm-dropCursor": {
    borderLeftColor: "var(--ui-primary)",
    borderLeftWidth: "2px",
  },
  "&.cm-focused > .cm-scroller > .cm-selectionLayer .cm-selectionBackground": {
    background: "color-mix(in srgb, var(--ui-primary) 25%, transparent)",
  },
  ".cm-selectionBackground": {
    background: "color-mix(in srgb, var(--ui-primary) 15%, transparent)",
  },
  ".cm-activeLine": {
    backgroundColor: "var(--ui-bg-accented)",
  },
  ".cm-gutters": {
    backgroundColor: "var(--ui-bg)",
    borderRight: "1px solid var(--ui-border)",
    color: "var(--ui-text-dimmed)",
  },
  ".cm-lineNumbers .cm-gutterElement": {
    padding: "0 8px 0 16px",
    fontSize: "12px",
  },
  ".cm-activeLineGutter": {
    backgroundColor: "var(--ui-bg-accented)",
  },
  ".cm-matchingBracket": {
    backgroundColor: "color-mix(in srgb, var(--ui-primary) 30%, transparent)",
    outline: "1px solid color-mix(in srgb, var(--ui-primary) 50%, transparent)",
  },
  ".cm-searchMatch": {
    backgroundColor: "color-mix(in srgb, var(--ui-warning) 30%, transparent)",
  },
  ".cm-searchMatch.cm-searchMatch-selected": {
    backgroundColor: "color-mix(in srgb, var(--ui-primary) 30%, transparent)",
  },
  ".cm-panels": {
    backgroundColor: "var(--ui-bg-elevated)",
    color: "var(--ui-text)",
  },
  ".cm-panels.cm-panels-top": {
    borderBottom: "1px solid var(--ui-border)",
  },
  ".cm-panels.cm-panels-bottom": {
    borderTop: "1px solid var(--ui-border)",
  },
  ".cm-tooltip": {
    backgroundColor: "var(--ui-bg-elevated)",
    border: "1px solid var(--ui-border)",
    borderRadius: "6px",
  },
})

// Y.js setup
const ydoc = new Y.Doc()
const ytext = ydoc.getText("content")
const undoManager = new Y.UndoManager(ytext)

// Awareness for collaborative cursors
const awareness = new Awareness(ydoc)
const CURSOR_COLORS = [
  { color: "#ef4444", colorLight: "#ef444433" },
  { color: "#f97316", colorLight: "#f9731633" },
  { color: "#eab308", colorLight: "#eab30833" },
  { color: "#22c55e", colorLight: "#22c55e33" },
  { color: "#06b6d4", colorLight: "#06b6d433" },
  { color: "#3b82f6", colorLight: "#3b82f633" },
  { color: "#8b5cf6", colorLight: "#8b5cf633" },
  { color: "#ec4899", colorLight: "#ec489933" },
]

const currentUser = page.props.currentUser
const userColor = CURSOR_COLORS[currentUser.id % CURSOR_COLORS.length]
awareness.setLocalStateField("user", { name: currentUser.name, ...userColor })

const activeUsers = ref([])

awareness.on("change", () => {
  const users = []
  awareness.getStates().forEach((state, clientId) => {
    if (clientId !== ydoc.clientID && state.user) {
      users.push(state.user)
    }
  })
  activeUsers.value = users
})

function broadcastAwareness() {
  if (!subscription) return
  const update = encodeAwarenessUpdate(awareness, [ydoc.clientID])
  const base64 = btoa(String.fromCharCode(...update))
  subscription.send({ type: "awareness", update: base64, sender: String(ydoc.clientID) })
}

let awarenessDebounceTimer = null

awareness.on("update", ({ added, updated, removed }, origin) => {
  if (origin === "remote" || !subscription) return
  clearTimeout(awarenessDebounceTimer)
  awarenessDebounceTimer = setTimeout(broadcastAwareness, 50)
})

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
    extensions: [basicSetup, editorTheme, markdown(), yCollab(ytext, awareness, { undoManager })],
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
        broadcastAwareness()
      },

      disconnected() {
        connectionStatus.value = "disconnected"
      },

      received(data) {
        if (data.type === "sync") {
          Y.transact(
            ydoc,
            () => {
              applyRemoteState(data.state)
            },
            "remote",
          )
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
        } else if (data.type === "awareness") {
          if (String(data.sender) !== String(ydoc.clientID)) {
            const bytes = Uint8Array.from(atob(data.update), (c) => c.charCodeAt(0))
            applyAwarenessUpdate(awareness, bytes, "remote")
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
  if (awarenessDebounceTimer) clearTimeout(awarenessDebounceTimer)
  if (pendingSaveTimer) clearTimeout(pendingSaveTimer)
  if (subscription) {
    subscription.unsubscribe()
    subscription = null
  }
  consumer.disconnect()
  if (editorView.value) {
    editorView.value.destroy()
  }
  awareness.destroy()
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
  <!-- Toolbar - fixed at viewport top -->
  <div
    class="fixed top-0 inset-x-0 z-50 flex h-12 items-center gap-2 border-b border-(--ui-border) bg-(--ui-bg-elevated) px-4"
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
      <span class="hidden sm:inline truncate">{{ project.name }}</span>
      <UIcon name="i-lucide-chevron-right" class="hidden sm:block size-3.5 shrink-0" />
      <span class="truncate font-medium text-(--ui-text)">{{ path }}</span>
    </div>

    <div class="ml-auto flex items-center gap-2">
      <span class="hidden sm:inline text-xs text-(--ui-text-dimmed) tabular-nums">
        {{ wordCount }} words &middot; {{ charCount }} chars
      </span>

      <USeparator orientation="vertical" class="hidden sm:block h-5" />

      <UButton
        icon="i-lucide-save"
        size="xs"
        :loading="saving"
        @click="save"
      >
        <span class="hidden sm:inline">Save</span>
      </UButton>
      <UButton
        :icon="previewVisible ? 'i-lucide-eye-off' : 'i-lucide-eye'"
        size="xs"
        variant="ghost"
        color="neutral"
        @click="previewVisible = !previewVisible"
      >
        <span class="hidden sm:inline">Preview</span>
      </UButton>

      <USeparator orientation="vertical" class="h-5" />

      <div v-if="activeUsers.length" class="flex items-center -space-x-1.5">
        <UTooltip
          v-for="(user, i) in activeUsers.slice(0, 3)"
          :key="i"
          :text="user.name"
          :delay-duration="0"
          :content="{ side: 'bottom', sideOffset: 8, class: 'z-[60]' }"
        >
          <span
            class="inline-flex items-center justify-center size-6 rounded-full text-[10px] font-medium text-white ring-2 ring-(--ui-bg-elevated)"
            :style="{ backgroundColor: user.color }"
          >
            {{ user.name?.[0] }}
          </span>
        </UTooltip>
      </div>

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

  <!-- Split pane editor/preview - offset below toolbar -->
  <UDashboardGroup storage-key="editor-split" class="editor-top-offset">
    <UDashboardPanel id="editor-panel" :ui="{ root: 'min-h-0', body: 'p-0 sm:p-0' }">
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
      :ui="{ root: 'min-h-0', body: 'p-0 sm:p-0' }"
    >
      <template #body>
        <div class="p-6 overflow-auto h-full">
          <MarkdownPreview :content="editorContent" />
        </div>
      </template>
    </UDashboardPanel>
  </UDashboardGroup>
</template>
