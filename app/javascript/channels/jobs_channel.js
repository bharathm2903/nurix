import consumer from "channels/consumer"

consumer.subscriptions.create("JobsChannel", {
  connected() {
    console.log("Connected to JobsChannel")
  },

  disconnected() {
    console.log("Disconnected from JobsChannel")
  },

  received(data) {
    console.log("Job update received:", data)
    
    // Update statistics if provided
    if (data.stats) {
      Object.keys(data.stats).forEach(key => {
        const element = document.getElementById(`stat-${key}`)
        if (element) {
          element.textContent = data.stats[key]
        }
      })
    }

    // Optionally reload the page to show updated job lists
    // In production, you'd update the DOM directly
    if (data.type === 'job_update') {
      // Small delay to batch updates
      if (this.reloadTimeout) {
        clearTimeout(this.reloadTimeout)
      }
      this.reloadTimeout = setTimeout(() => {
        location.reload()
      }, 2000)
    }
  }
});
