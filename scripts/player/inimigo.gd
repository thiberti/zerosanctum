extends CharacterBody2D

@export var vida_maxima: float = 30.0
@export var velocidade: float = 40.0
@export var dano_contato: float = 10.0

var vida_atual: float
var direcao: float = -1.0
var gravidade: float = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var sprite: Sprite2D = $Sprite2D
@onready var sensor_chao: RayCast2D = $RayCast2D
@onready var area_dano: Area2D = $AreaDano

var cor_base: Color


func _ready() -> void:
	vida_atual = vida_maxima
	cor_base = sprite.modulate


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravidade * delta

	velocity.x = direcao * velocidade
	move_and_slide()

	# Vira ao bater na parede ou ao chegar na beira do chão
	if is_on_wall() or (is_on_floor() and not sensor_chao.is_colliding()):
		_virar()

	# Causa dano a quem estiver encostando (o jogador tem invulnerabilidade própria)
	for corpo in area_dano.get_overlapping_bodies():
		if corpo.has_method("receber_dano"):
			corpo.receber_dano(dano_contato)


func _virar() -> void:
	direcao *= -1.0
	sprite.flip_h = direcao > 0.0
	sensor_chao.position.x = 14.0 * direcao


func receber_dano(quantidade: float) -> void:
	vida_atual -= quantidade
	# Flash de dano
	sprite.modulate = Color(3, 3, 3)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", cor_base, 0.15)
	if vida_atual <= 0.0:
		queue_free()
