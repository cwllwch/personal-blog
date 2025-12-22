let Hooks = {}

Hooks.CopyToClipboard = {
		mounted() {
				this.el.addEventListener("click", () => {
				const text = this.el.dataset.copy
						navigator.clipboard.writeText(text).then(() => {
								alert("Copied!")
						})
				})
		}
}

let liveSocket = new LiveSoocket("/live", Socket {
		hooks: Hooks,
		params: {_csrf_token: csrfToken}
})
