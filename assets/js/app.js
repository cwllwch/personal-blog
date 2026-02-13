import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import htmx from "../vendor/htmx.js"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

let Hooks = {}

Hooks.CopyToClipboard = {
		mounted() {
				this.el.addEventListener("click", () => {
				const text = this.el.dataset.copy
						navigator.clipboard.writeText(text)
				})
		}
}

let liveSocket = new LiveSocket("/live", Socket, {
  hooks: Hooks,
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken}
})

liveSocket.connect()

window.liveSocket = liveSocket
