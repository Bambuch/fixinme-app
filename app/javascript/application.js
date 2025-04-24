// Configure your import map in config/importmap.rb. Read more:
// https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"


/* Hide page before loaded for testing purposes */
function showPage(event) {
  document.documentElement.style.visibility="visible"
}
document.addEventListener('turbo:load', showPage)


/* Turbo stream actions */
Turbo.StreamElement.prototype.enableElement = function(element) {
    element.removeAttribute("disabled")
    element.removeAttribute("aria-disabled")
    // 'tabindex' is not used explicitly, so removing it is safe
    element.removeAttribute("tabindex")
}

Turbo.StreamActions.disable = function() {
  this.targetElements.forEach((e) => {
    e.setAttribute("disabled", "disabled")
    e.setAttribute("aria-disabled", "true")
    e.setAttribute("tabindex", "-1")
  })
}

Turbo.StreamActions.enable = function() {
  this.targetElements.forEach((e) => { this.enableElement(e) })
}

Turbo.StreamActions.hide = function() {
  this.targetElements.forEach((e) => { e.style.display = "none" })
}

Turbo.StreamActions.close_form = function() {
  this.targetElements.forEach((e) => {
    /* Move focus if there's no focus or focus inside form being closed */
    const focused = document.activeElement
    if (!focused || (focused == document.body) || e.contains(focused)) {
      let nextForm = e.parentElement.querySelector(`#${e.id} ~ tr:has([autofocus])`)
      nextForm ??= e.parentElement.querySelector("tr:has([autofocus])")
      nextForm?.querySelector("[autofocus]").focus()
    }
    document.getElementById(e.getAttribute("data-form")).remove()
    if (e.hasAttribute("data-link")) {
      this.enableElement(document.getElementById(e.getAttribute("data-link")))
    }
    if (e.hasAttribute("data-hidden-row")) {
      document.getElementById(e.getAttribute("data-hidden-row")).removeAttribute("style")
    }
    e.remove()
  })
}


/* Items table drag and drop support */
function processKey(event) {
  if (event.key === "Escape") {
    event.preventDefault(); // Prevent default behavior for Escape key
    event.currentTarget.querySelector("a[name=cancel]")?.click();
  }
}
window.processKey = processKey;

var lastEnterTime;
function dragStart(event) {
  lastEnterTime = event.timeStamp;
  var row = event.currentTarget;
  row.closest("table").querySelectorAll("thead tr").forEach((tr) => {
    tr.toggleAttribute("hidden", true); // Ensure hidden attribute is set explicitly
  });
  event.dataTransfer.setData("text/plain", row.getAttribute("data-drag-path"));
  var rowRectangle = row.getBoundingClientRect();
  event.dataTransfer.setDragImage(row, event.clientX - rowRectangle.left, event.clientY - rowRectangle.top);
  event.dataTransfer.effectAllowed = "move"; // Ensure proper drag effect
}
window.dragStart = dragStart;

/*
* Drag tracking assumptions (based on FF 122.0 experience):
*   * Enter/Leave events at the same timeStamp may not be logically ordered
*     (e.g. E -> E -> L, not E -> L -> E),
*   * not every Enter event has corresponding Leave event, especially during
*     rapid pointer moves
* NOTE: sometimes Leave is not emitted when pointer goes fast over table
* and outside. This should probably be fixed in browser, than patched here.
*/
function dragEnter(event) {
  //console.log(event.timeStamp + " " + event.type + ": " + event.currentTarget.id);
  dragLeave(event);
  lastEnterTime = event.timeStamp;
  const id = event.currentTarget.getAttribute("data-drop-id");
  document.getElementById(id).classList.add("dropzone");
}
window.dragEnter = dragEnter;

function dragOver(event) {
  event.preventDefault();
}
window.dragOver = dragOver;

function dragLeave(event) {
  // Leave has been accounted for by Enter at the same timestamp, processed earlier
  if (event.timeStamp <= lastEnterTime) return;
  event.currentTarget.closest("table").querySelectorAll(".dropzone").forEach((tr) => {
    tr.classList.remove("dropzone");
  });
}
window.dragLeave = dragLeave;

function dragEnd(event) {
  dragLeave(event);
  event.currentTarget.closest("table").querySelectorAll("thead tr").forEach((tr) => {
    tr.toggleAttribute("hidden", false); // Ensure hidden attribute is removed explicitly
  });
}
window.dragEnd = dragEnd;

function drop(event) {
  event.preventDefault();

  var params = new URLSearchParams();
  var id_param = event.currentTarget.getAttribute("data-drop-id-param");
  var id = event.currentTarget.getAttribute("data-drop-id")?.split("_").pop();
  if (id_param && id) {
    params.append(id_param, id);

    fetch(event.dataTransfer.getData("text/plain"), {
      body: params,
      headers: {
        "Accept": "text/vnd.turbo-stream.html",
        "X-CSRF-Token": document.head.querySelector("meta[name=csrf-token]")?.content,
        "X-Requested-With": "XMLHttpRequest"
      },
      method: "POST"
    })
    .then(response => {
      if (!response.ok) throw new Error("Network response was not ok");
      return response.text();
    })
    .then(html => Turbo.renderStreamMessage(html))
    .catch(error => console.error("Error during drop operation:", error));
  }
}
window.drop = drop;
