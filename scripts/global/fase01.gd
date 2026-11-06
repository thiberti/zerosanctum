extends Node2D

@onready var jogador: CharacterBody2D = $Player
@onready var hud: CanvasLayer = $HUD


func _ready() -> void:
	hud.conectar_jogador(jogador)
	# Reenvia os valores iniciais, pois o Player emitiu antes da HUD conectar
	jogador.vitalidade_mudou.emit(jogador.vitalidade_atual, jogador.vitalidade_maxima)
	jogador.energia_mudou.emit(jogador.energia_atual, jogador.energia_maxima)
