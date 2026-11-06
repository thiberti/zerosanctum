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
@export var alcance_ataque: float = 36.0
@export var custo_transformacao: float = 30.0
@export var duracao_transformacao: float = 8.0
@export var tempo_invulneravel: float = 0.8

enum Forma { HUMANO, ESPIRITO_LAMURIA }

# --- Spritesheet: células de 118x68, uma animação por linha ---
const SHEET := preload("res://assets/sprites/player/zero_sheet.png")
const LARGURA_QUADRO := 118
const ALTURA_QUADRO := 68
const COR_ESPIRITO := Color(1.8, 1.2, 2.4) # tom provisório da forma transformada

# nome: [linha, [colunas], fps, repetir]
const ANIMACOES := {
	"parado": [0, [0, 1, 2, 3], 5.0, true],
	"correr": [1, [0, 1, 2, 3, 4, 5], 12.0, true],
	"subir": [2, [2], 1.0, true],
	"cair": [2, [3], 1.0, true],
	"atacar": [3, [0, 1, 2, 3], 16.0, false],
	"dano": [4, [0, 1, 2], 9.0, false],
	"transformar": [5, [0, 1, 2, 3, 4], 8.0, false],
}

var vitalidade_atual: float
var energia_atual: float
var forma_atual: Forma = Forma.HUMANO
var tempo_transformacao: float = 0.0
var atacando: bool = false
var transformando: bool = false
var machucado: bool = false
var invulneravel: bool = false
var olhando: float = 1.0 # 1 = direita, -1 = esquerda

var gravidade: float = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var area_ataque: Area2D = $AreaAtaque
@onready var colisao_ataque: CollisionShape2D = $AreaAtaque/CollisionShape2D


func _ready() -> void:
	vitalidade_atual = vitalidade_maxima
	energia_atual = energia_maxima
	colisao_ataque.disabled = true
	colisao_ataque.position.x = alcance_ataque
	area_ataque.body_entered.connect(_ao_acertar)
	_montar_animacoes()
	vitalidade_mudou.emit(vitalidade_atual, vitalidade_maxima)
	energia_mudou.emit(energia_atual, energia_maxima)


func _montar_animacoes() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for nome in ANIMACOES:
		var dados: Array = ANIMACOES[nome]
		frames.add_animation(nome)
		frames.set_animation_speed(nome, dados[2])
		frames.set_animation_loop(nome, dados[3])
		for coluna in dados[1]:
			var tex := AtlasTexture.new()
			tex.atlas = SHEET
			tex.region = Rect2(
				coluna * LARGURA_QUADRO, dados[0] * ALTURA_QUADRO,
				LARGURA_QUADRO, ALTURA_QUADRO)
			frames.add_frame(nome, tex)
	sprite.sprite_frames = frames
	sprite.play("parado")


func _physics_process(delta: float) -> void:
	# Gravidade
	if not is_on_floor():
		velocity.y += gravidade * delta

	var travado := transformando or machucado

	# Movimento horizontal
	var direcao := 0.0
	if not travado:
		direcao = Input.get_axis("mover_esquerda", "mover_direita")
	if atacando or travado:
		velocity.x = move_toward(velocity.x, 0.0, velocidade)
	elif direcao != 0.0:
		velocity.x = direcao * velocidade
		_virar(signf(direcao))
	else:
		velocity.x = move_toward(velocity.x, 0.0, velocidade)

	if not travado:
		# Pulo
		if Input.is_action_just_pressed("pular") and is_on_floor() and not atacando:
			velocity.y = forca_pulo
		# Ataque
		if Input.is_action_just_pressed("atacar") and not atacando:
			_atacar()
		# Transformação
		if Input.is_action_just_pressed("transformar") and not atacando:
			if forma_atual == Forma.HUMANO:
				_transformar_em(Forma.ESPIRITO_LAMURIA)

	# Tempo da transformação
	if forma_atual != Forma.HUMANO:
		tempo_transformacao -= delta
		if tempo_transformacao <= 0.0:
			_reverter_para_humano()

	move_and_slide()
	_atualizar_animacao()


func _virar(sentido: float) -> void:
	olhando = sentido
	sprite.flip_h = olhando < 0.0
	colisao_ataque.position.x = alcance_ataque * olhando


func _tocar(nome: String) -> void:
	if sprite.animation != nome:
		sprite.play(nome)


func _atualizar_animacao() -> void:
	# "transformar" e "dano" são iniciadas nos próprios eventos
	if transformando or machucado:
		return
	if atacando:
		_tocar("atacar")
		return
	if is_on_floor():
		_tocar("correr" if absf(velocity.x) > 10.0 else "parado")
	else:
		_tocar("subir" if velocity.y < 0.0 else "cair")


func _atacar() -> void:
	atacando = true
	sprite.play("atacar") # reinicia a animação a cada golpe
	colisao_ataque.set_deferred("disabled", false)
	await get_tree().create_timer(duracao_ataque).timeout
	colisao_ataque.set_deferred("disabled", true)
	atacando = false


func _ao_acertar(corpo: Node2D) -> void:
	if corpo.has_method("receber_dano"):
		corpo.receber_dano(dano_ataque)


func _transformar_em(nova_forma: Forma) -> void:
	if energia_atual < custo_transformacao or transformando:
		return
	energia_atual -= custo_transformacao
	energia_mudou.emit(energia_atual, energia_maxima)
	transformando = true
	sprite.play("transformar")
	await sprite.animation_finished
	transformando = false
	forma_atual = nova_forma
	tempo_transformacao = duracao_transformacao
	sprite.modulate = COR_ESPIRITO
	forma_mudou.emit(forma_atual)


func _reverter_para_humano() -> void:
	forma_atual = Forma.HUMANO
	sprite.modulate = Color.WHITE
	forma_mudou.emit(forma_atual)


func receber_dano(quantidade: float) -> void:
	if invulneravel or transformando:
		return
	vitalidade_atual = maxf(vitalidade_atual - quantidade, 0.0)
	vitalidade_mudou.emit(vitalidade_atual, vitalidade_maxima)
	if vitalidade_atual <= 0.0:
		get_tree().call_deferred("reload_current_scene")
		return
	invulneravel = true
	machucado = true
	sprite.play("dano")
	sprite.self_modulate.a = 0.5
	await get_tree().create_timer(0.35).timeout
	machucado = false
	await get_tree().create_timer(maxf(tempo_invulneravel - 0.35, 0.0)).timeout
	sprite.self_modulate.a = 1.0
	invulneravel = false
