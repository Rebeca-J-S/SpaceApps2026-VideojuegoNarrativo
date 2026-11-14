class_name DrawNode
extends Node2D
## Nodo de dibujo "placeholder": ejecuta una función de dibujo (Callable) cada frame.
## Permite montar escenarios con _draw() sin crear un script por cada decorado.
## Reemplazo por sprites: sustituir el DrawNode por un Sprite2D / AnimatedSprite2D.
##
##   var cielo := DrawNode.new(func(c: DrawNode) -> void: c.draw_rect(Rect2(0, 0, 640, 360), Color.BLACK))

var draw_fn: Callable
var animated := true
## Tiempo acumulado (útil para animar dentro de draw_fn).
var t := 0.0


func _init(fn: Callable = Callable(), is_animated: bool = true) -> void:
	draw_fn = fn
	animated = is_animated


func _process(delta: float) -> void:
	t += delta
	if animated:
		queue_redraw()


func _draw() -> void:
	if draw_fn.is_valid():
		draw_fn.call(self)
