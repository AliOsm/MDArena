import "../css/application.css"

import { createApp, h } from "vue"
import { createInertiaApp } from "@inertiajs/vue3"
import ui from "@nuxt/ui/vue-plugin"
import AppLayout from "../layouts/AppLayout.vue"

createInertiaApp({
  resolve: (name) => {
    const pages = import.meta.glob("../pages/**/*.vue", { eager: true })
    const page = pages[`../pages/${name}.vue`]
    page.default.layout =
      page.default.layout === undefined ? AppLayout : page.default.layout
    return page
  },
  setup({ el, App, props, plugin }) {
    createApp({ render: () => h(App, props) })
      .use(plugin)
      .use(ui)
      .mount(el)
  },
})
