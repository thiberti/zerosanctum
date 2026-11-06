extends CharacterBody2D

# --- Sinais (a HUD escuta estes) ---
signal vitalidade_mudou(atual: float, maxima: float)
signal energia_mudou(atual: float, maxima: float)
signal forma_mudou(nova_forma: Forma)

# --- Atributos ---
@export_group("Atributos")
@export var vitalidade_maxima: float = 100.0
@export var energia_maxima: float = 100.0

@export_group("Movimento")
@export var velocidade: float = 140.0
@export var forca_pulo: float = -330.0

@export_group("Ataque e Transformação")
@export var dano_ataque: float = 10.0
@export var duracao_ataque: float = 0.25
@export var custo_transformacao: float = 30.0
@export var duracao_transformacao: float = 8.0
@export var tempo_invulneravel: float = 0.8

enum Forma { HUMANO, ESPIRITO_LAMURIA }

var vitalidade_atual: float
var energia_atual: float
var forma_atual: Forma = Forma.HUMANO
var tempo_transformacao: float = 0.0
var atacando: bool = false
var invulneravel: bool = false
var olhando: float = 1.0 # 1 = direita, -1 = esquerda

# NOVO: controle da animação provisória
var escala_base: Vector2
var tempo_anim: float = 0.0
var estava_no_chao: bool = false

var gravidade: float = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var sprite: Sprite2D = $Sprite2D
@onready var area_ataque: Area2D = $AreaAtaque
@onready var colisao_ataque: CollisionShape2D = $AreaAtaque/CollisionShape2D
@onready var visual_ataque: ColorRect = $AreaAtaque/VisualAtaque # NOVO


func _ready() -> void:
	vitalidade_atual = vitalidade_maxima
	energia_atual = energia_maxima
	escala_base = sprite.scale # NOVO
	colisao_ataque.disabled = true
	area_ataque.body_entered.connect(_ao_acertar)
	vitalidade_mudou.emit(vitalidade_atual, vitalidade_maxima)
	energia_mudou.emit(energia_atual, energia_maxima)


func _physics_process(delta: float) -> void:
	# Gravidade
	if not is_on_floor():
		velocity.y += gravidade * delta

	# Movimento horizontal (travado durante o ataque)
	var direcao := Input.get_axis("mover_esquerda", "mover_direita")
	if atacando:
		velocity.x = move_toward(velocity.x, 0.0, velocidade)
	elif direcao != 0.0:
		velocity.x = direcao * velocidade
		olhando = signf(direcao)
		sprite.flip_h = olhando < 0.0
		area_ataque.scale.x = olhando
	else:
		velocity.x = move_toward(velocity.x, 0.0, velocidade)

	# Pulo
	if Input.is_action_just_pressed("pular") and is_on_floor() and not atacando:
		velocity.y = forca_pulo
		_efeito_escala(Vector2(0.8, 1.25)) # NOVO: estica ao pular

	# Ataque
	if Input.is_action_just_pressed("atacar") and not atacando:
		_atacar()

	# Transformação
	if Input.is_action_just_pressed("transformar"):
		if forma_atual == Forma.HUMANO:
			_transformar_em(Forma.ESPIRITO_LAMURIA)

	# Tempo da transformação
	if forma_atual != Forma.HUMANO:
		tempo_transformacao -= delta
		if tempo_transformacao <= 0.0:
			_reverter_para_humano()

	move_and_slide()
	_animar_sprite(delta) # NOVO


# NOVO: animação provisória por código
func _animar_sprite(delta: float) -> void:
	tempo_anim += delta
	var no_chao := is_on_floor()

	# Amassa ao pousar
	if no_chao and not estava_no_chao:
		_efeito_escala(Vector2(1.25, 0.75))
	estava_no_chao = no_chao

	if atacando:
		# Inclina o corpo para a frente durante o golpe
		sprite.rotation = lerp_angle(sprite.rotation, 0.3 * olhando, 0.4)
		sprite.position.y = 0.0
	elif no_chao and absf(velocity.x) > 10.0:
		# Balanço ao andar
		sprite.rotation = sin(tempo_anim * 16.0) * 0.08
		sprite.position.y = -absf(sin(tempo_anim * 16.0)) * 1.5
	else:
		# Parado: respiração leve
		sprite.rotation = lerp_angle(sprite.rotation, 0.0, 0.3)
		sprite.position.y = sin(tempo_anim * 3.0) * 0.8


func _efeito_escala(fator: Vector2) -> void:
	sprite.scale = escala_base * fator
	var tween := create_tween()
	tween.tween_property(sprite, "scale", escala_base, 0.15)


func _atacar() -> void:
	atacando = true
	colisao_ataque.set_deferred("disabled", false)
	# NOVO: risco visual da espadada que some rapidamente
	visual_ataque.visible = true
	visual_ataque.modulate.a = 0.9
	var tween := create_tween()
	tween.tween_property(visual_ataque, "modulate:a", 0.0, duracao_ataque)
	await get_tree().create_timer(duracao_ataque).timeout
	colisao_ataque.set_deferred("disabled", true)
	visual_ataque.visible = false # NOVO
	atacando = false


func _ao_acertar(corpo: Node2D) -> void:
	if corpo.has_method("receber_dano"):
		corpo.receber_dano(dano_ataque)


func _transformar_em(nova_forma: Forma) -> void:
	if energia_atual < custo_transformacao:
		return
	energia_atual -= custo_transformacao
	energia_mudou.emit(energia_atual, energia_maxima)
	forma_atual = nova_forma
	tempo_transformacao = duracao_transformacao
	sprite.modulate = Color(0.5, 0.25, 0.9) # aura roxa provisória
	forma_mudou.emit(forma_atual)


func _reverter_para_humano() -> void:
	forma_atual = Forma.HUMANO
	sprite.modulate = Color.WHITE
	forma_mudou.emit(forma_atual)


func receber_dano(quantidade: float) -> void:
	if invulneravel:
		return
	vitalidade_atual = maxf(vitalidade_atual - quantidade, 0.0)
	vitalidade_mudou.emit(vitalidade_atual, vitalidade_maxima)
	if vitalidade_atual <= 0.0:
		get_tree().call_deferred("reload_current_scene")
		return
	invulneravel = true
	sprite.self_modulate.a = 0.4
	await get_tree().create_timer(tempo_invulneravel).timeout
	sprite.self_modulate.a = 1.0
	invulneravel = false
