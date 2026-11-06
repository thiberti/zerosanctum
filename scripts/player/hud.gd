extends CanvasLayer

@onready var barra_vitalidade: ProgressBar = $Margem/Barras/BarraVitalidade
@onready var barra_energia: ProgressBar = $Margem/Barras/BarraEnergia


func conectar_jogador(jogador: Node) -> void:
	jogador.vitalidade_mudou.connect(_ao_vitalidade_mudar)
	jogador.energia_mudou.connect(_ao_energia_mudar)


func _ao_vitalidade_mudar(atual: float, maxima: float) -> void:
	barra_vitalidade.max_value = maxima
	barra_vitalidade.value = atual


func _ao_energia_mudar(atual: float, maxima: float) -> void:
	barra_energia.max_value = maxima
	barra_energia.value = atual
