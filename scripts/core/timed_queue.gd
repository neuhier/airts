extends Node
class_name TimedQueue
## Generic, independent, time-based FIFO queue.
##
## This is the shared "Komponente" behind every parallel production/research
## queue in the economy system (HQ melee production, each buildable module's
## unit queue, and the Upgrade-Labor's research queue). It is deliberately
## payment-agnostic and item-content-agnostic: callers (typically
## `EconomyController`) are responsible for checking/deducting resources
## *before* calling `enqueue()`, and for reacting to `item_completed` (by
## spawning a unit, applying an upgrade, etc.). This keeps `TimedQueue`
## reusable for both "produces a unit" and "produces a research result"
## without needing two near-identical classes.
##
## Only the front item's timer runs; queued items behind it wait their turn
## — one item is processed at a time, exactly as required by the spec ("Es
## wird immer nur die vorderste Einheit prozessiert").

## Each item is a `Dictionary` and must contain at least a `"duration"` key
## (float, seconds). All other keys are opaque payload for the caller.
var queue: Array[Dictionary] = []

var _elapsed: float = 0.0

signal item_started(item: Dictionary)
signal item_completed(item: Dictionary)
## Emitted when `cancel_queue_item()` removes an item before it completed —
## callers use this to refund the item's cost (payment is out of scope here,
## same as `enqueue()`).
signal item_cancelled(item: Dictionary)
## Emitted whenever the queue transitions between empty/non-empty or a new
## item becomes the front item — convenient single hook for GUI refreshes.
signal queue_changed


func _process(delta: float) -> void:
	if queue.is_empty():
		return

	var front: Dictionary = queue[0]
	if _elapsed == 0.0:
		item_started.emit(front)

	_elapsed += delta
	if _elapsed >= float(front.get("duration", 0.0)):
		queue.pop_front()
		_elapsed = 0.0
		item_completed.emit(front)
		queue_changed.emit()


## Appends `item` to the back of the queue. Caller must have already
## handled affordability/payment — `TimedQueue` has no concept of cost.
func enqueue(item: Dictionary) -> void:
	queue.append(item)
	queue_changed.emit()


func size() -> int:
	return queue.size()


func is_busy() -> bool:
	return not queue.is_empty()


## Removes the item at `index`. If it was the front (currently building)
## item, progress resets to 0% so the next item starts fresh rather than
## inheriting the cancelled item's elapsed time.
func cancel_queue_item(index: int) -> void:
	if index < 0 or index >= queue.size():
		return
	var item: Dictionary = queue[index]
	queue.remove_at(index)
	if index == 0:
		_elapsed = 0.0
	item_cancelled.emit(item)
	queue_changed.emit()
