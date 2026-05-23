import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;

// =============================================================================
// MODELOS
// =============================================================================

enum Nota { A, B, C, D, E }

class Jogador {
  String nome;
  Nota nota;
  bool isGoleiro;
  bool presente;

  Jogador({
    required this.nome,
    required this.nota,
    this.isGoleiro = false,
    this.presente = true,
  });

  Map<String, dynamic> toMap() => {
        'nome': nome,
        'nota': nota.name,
        'isGoleiro': isGoleiro,
        'presente': presente,
      };

  factory Jogador.fromMap(Map<String, dynamic> map) => Jogador(
        nome: map['nome'],
        nota: Nota.values.firstWhere((e) => e.name == map['nota']),
        isGoleiro: map['isGoleiro'] ?? false,
        presente: map['presente'] ?? true,
      );
}

class TimeSorteado {
  String nome;
  List<Jogador> jogadores;

  TimeSorteado({required this.nome, required this.jogadores});

  Map<String, dynamic> toMap() => {
        'nome': nome,
        'jogadores': jogadores.map((j) => j.toMap()).toList(),
      };

  factory TimeSorteado.fromMap(Map<String, dynamic> map) => TimeSorteado(
        nome: map['nome'],
        jogadores: (map['jogadores'] as List)
            .map((j) => Jogador.fromMap(j as Map<String, dynamic>))
            .toList(),
      );
}

class EstatisticasTime {
  TimeSorteado time;
  int pontos = 0;
  int jogos = 0;
  int vitorias = 0;
  int empates = 0;
  int derrotas = 0;
  int golsPro = 0;
  int golsContra = 0;

  int get saldoGols => golsPro - golsContra;

  EstatisticasTime({required this.time});

  Map<String, dynamic> toMap() => {
        'time': time.toMap(),
        'pontos': pontos,
        'jogos': jogos,
        'vitorias': vitorias,
        'empates': empates,
        'derrotas': derrotas,
        'golsPro': golsPro,
        'golsContra': golsContra,
      };

  factory EstatisticasTime.fromMap(Map<String, dynamic> map) {
    var e = EstatisticasTime(
        time: TimeSorteado.fromMap(map['time'] as Map<String, dynamic>));
    e.pontos = map['pontos'] ?? 0;
    e.jogos = map['jogos'] ?? 0;
    e.vitorias = map['vitorias'] ?? 0;
    e.empates = map['empates'] ?? 0;
    e.derrotas = map['derrotas'] ?? 0;
    e.golsPro = map['golsPro'] ?? 0;
    e.golsContra = map['golsContra'] ?? 0;
    return e;
  }
}

class GolLog {
  Jogador jogador;
  int minuto;
  bool isGolContra;

  GolLog({required this.jogador, required this.minuto, this.isGolContra = false});

  Map<String, dynamic> toMap() => {
        'jogador': jogador.toMap(),
        'minuto': minuto,
        'isGolContra': isGolContra,
      };

  factory GolLog.fromMap(Map<String, dynamic> map) => GolLog(
        jogador: Jogador.fromMap(map['jogador'] as Map<String, dynamic>),
        minuto: map['minuto'],
        isGolContra: map['isGolContra'] ?? false,
      );
}

class Partida {
  String id;
  EstatisticasTime timeA;
  EstatisticasTime timeB;
  int placarA = 0;
  int placarB = 0;
  List<GolLog> golsA = [];
  List<GolLog> golsB = [];
  bool encerrada = false;
  bool confirmada = false;

  Partida({
    required this.id,
    required this.timeA,
    required this.timeB,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'timeA': timeA.toMap(),
        'timeB': timeB.toMap(),
        'placarA': placarA,
        'placarB': placarB,
        'golsA': golsA.map((g) => g.toMap()).toList(),
        'golsB': golsB.map((g) => g.toMap()).toList(),
        'encerrada': encerrada,
        'confirmada': confirmada,
      };

  factory Partida.fromMap(Map<String, dynamic> map) {
    var p = Partida(
      id: map['id'],
      timeA: EstatisticasTime.fromMap(map['timeA'] as Map<String, dynamic>),
      timeB: EstatisticasTime.fromMap(map['timeB'] as Map<String, dynamic>),
    );
    p.placarA = map['placarA'] ?? 0;
    p.placarB = map['placarB'] ?? 0;
    p.golsA = (map['golsA'] as List?)
            ?.map((g) => GolLog.fromMap(g as Map<String, dynamic>))
            .toList() ??
        [];
    p.golsB = (map['golsB'] as List?)
            ?.map((g) => GolLog.fromMap(g as Map<String, dynamic>))
            .toList() ??
        [];
    p.encerrada = map['encerrada'] ?? false;
    p.confirmada = map['confirmada'] ?? false;
    return p;
  }
}

class HistoricoSorteio {
  String dataHora;
  List<TimeSorteado> times;

  HistoricoSorteio({required this.dataHora, required this.times});

  Map<String, dynamic> toMap() => {
        'dataHora': dataHora,
        'times': times.map((t) => t.toMap()).toList(),
      };

  factory HistoricoSorteio.fromMap(Map<String, dynamic> map) => HistoricoSorteio(
        dataHora: map['dataHora'],
        times: (map['times'] as List)
            .map((t) => TimeSorteado.fromMap(t as Map<String, dynamic>))
            .toList(),
      );
}

// =============================================================================
// ESTADO GLOBAL E PERSISTÊNCIA
// =============================================================================

List<Jogador> jogadoresCadastrados = [];
List<HistoricoSorteio> historicoSorteios = [];

// --- NOVO: MODELO DE PASTA DE TORNEIO E VARIÁVEIS ---
class Torneio {
  String id;
  String nome;
  String dataCriacao;
  int tipo; // 1: Série A, 2: Grupos, 3: Mata-mata
  int tempoPartidaMinutos; // NOVO: Guarda o tempo da partida
  bool idaERetorno;        // NOVO: Guarda se tem returno
  List<EstatisticasTime> tabelaGeral;
  List<List<EstatisticasTime>> grupos;
  List<Partida> partidas;

  Torneio({
    required this.id, 
    required this.nome, 
    required this.dataCriacao, 
    required this.tipo,
    this.tempoPartidaMinutos = 10,
    this.idaERetorno = false,
    List<EstatisticasTime>? tabelaGeral, 
    List<List<EstatisticasTime>>? grupos, 
    List<Partida>? partidas,
  }) : tabelaGeral = tabelaGeral ?? [],
       grupos = grupos ?? [],
       partidas = partidas ?? [];

  Map<String, dynamic> toMap() => {
    'id': id, 'nome': nome, 'dataCriacao': dataCriacao, 'tipo': tipo,
    'tempoPartidaMinutos': tempoPartidaMinutos, 'idaERetorno': idaERetorno,
    'tabelaGeral': tabelaGeral.map((e) => e.toMap()).toList(),
    'grupos': grupos.map((g) => g.map((e) => e.toMap()).toList()).toList(),
    'partidas': partidas.map((p) => p.toMap()).toList(),
  };

  factory Torneio.fromMap(Map<String, dynamic> map) => Torneio(
    id: map['id'], nome: map['nome'], dataCriacao: map['dataCriacao'], tipo: map['tipo'],
    tempoPartidaMinutos: map['tempoPartidaMinutos'] ?? 10,
    idaERetorno: map['idaERetorno'] ?? false,
    tabelaGeral: (map['tabelaGeral'] as List?)?.map((e) => EstatisticasTime.fromMap(e as Map<String, dynamic>)).toList() ?? [],
    grupos: (map['grupos'] as List?)?.map((g) => (g as List).map((e) => EstatisticasTime.fromMap(e as Map<String, dynamic>)).toList()).toList() ?? [],
    partidas: (map['partidas'] as List?)?.map((p) => Partida.fromMap(p as Map<String, dynamic>)).toList() ?? [],
  );
}

List<String> sorteiosDisponiveisTorneio = []; // Guarda a dataHora dos sorteios ativados no troféu
List<Torneio> historicoTorneios = [];         // Guarda as pastas de torneios

Future<void> salvarTorneiosLocal() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList('bd_sorteios_disp', sorteiosDisponiveisTorneio);
  await prefs.setString('bd_torneios', jsonEncode(historicoTorneios.map((t) => t.toMap()).toList()));
}

Future<void> carregarTorneiosLocal() async {
  final prefs = await SharedPreferences.getInstance();
  sorteiosDisponiveisTorneio = prefs.getStringList('bd_sorteios_disp') ?? [];
  final tStr = prefs.getString('bd_torneios');
  if (tStr != null && tStr.isNotEmpty) {
    historicoTorneios = (jsonDecode(tStr) as List).map((t) => Torneio.fromMap(t as Map<String, dynamic>)).toList();
  }
}

EstatisticasTime? encontrarTimeNoTorneio(Torneio torneio, String nomeTime) {
  if (torneio.tipo == 1 || torneio.tipo == 3) {
    try { return torneio.tabelaGeral.firstWhere((t) => t.time.nome == nomeTime); } catch (_) { return null; }
  } else if (torneio.tipo == 2) {
    for (var grupo in torneio.grupos) {
      for (var t in grupo) { if (t.time.nome == nomeTime) return t; }
    }
  }
  return null;
}


// Variáveis Globais do Torneio
String? sorteioAtivoDataHora;
List<TimeSorteado> timesSalvosTorneio = [];
int faseTorneioGlobal = 0;
List<EstatisticasTime> tabelaGeralGlobal = [];
List<List<EstatisticasTime>> gruposGlobal = [];
List<Partida> listaPartidasTorneio = [];

void ordenarJogadores() {
  jogadoresCadastrados.sort(
      (a, b) => a.nome.trim().toLowerCase().compareTo(b.nome.trim().toLowerCase()));
}

Future<void> salvarTorneioLocal() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('bd_sorteio_ativo', sorteioAtivoDataHora ?? '');
  await prefs.setString(
      'bd_times_salvos', jsonEncode(timesSalvosTorneio.map((e) => e.toMap()).toList()));
  await prefs.setInt('bd_torneio_fase', faseTorneioGlobal);
  await prefs.setString(
      'bd_torneio_tabela', jsonEncode(tabelaGeralGlobal.map((e) => e.toMap()).toList()));
  await prefs.setString(
      'bd_torneio_grupos',
      jsonEncode(gruposGlobal
          .map((g) => g.map((e) => e.toMap()).toList())
          .toList()));
  await prefs.setString('bd_torneio_partidas',
      jsonEncode(listaPartidasTorneio.map((p) => p.toMap()).toList()));
}

Future<void> carregarTorneioLocal() async {
  final prefs = await SharedPreferences.getInstance();
  sorteioAtivoDataHora = prefs.getString('bd_sorteio_ativo');

  final timesStr = prefs.getString('bd_times_salvos');
  if (timesStr != null && timesStr.isNotEmpty) {
    timesSalvosTorneio = (jsonDecode(timesStr) as List)
        .map((e) => TimeSorteado.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  faseTorneioGlobal = prefs.getInt('bd_torneio_fase') ?? 0;

  final tabStr = prefs.getString('bd_torneio_tabela');
  if (tabStr != null && tabStr.isNotEmpty) {
    tabelaGeralGlobal = (jsonDecode(tabStr) as List)
        .map((e) => EstatisticasTime.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  final grpStr = prefs.getString('bd_torneio_grupos');
  if (grpStr != null && grpStr.isNotEmpty) {
    gruposGlobal = (jsonDecode(grpStr) as List)
        .map((g) => (g as List)
            .map((e) => EstatisticasTime.fromMap(e as Map<String, dynamic>))
            .toList())
        .toList();
  }

  final partStr = prefs.getString('bd_torneio_partidas');
  if (partStr != null && partStr.isNotEmpty) {
    listaPartidasTorneio = (jsonDecode(partStr) as List)
        .map((e) => Partida.fromMap(e as Map<String, dynamic>))
        .toList();
  }
}

EstatisticasTime? encontrarTimeNaTabelaGlobal(String nomeTime) {
  if (faseTorneioGlobal == 1 || faseTorneioGlobal == 3) {
    try {
      return tabelaGeralGlobal.firstWhere((t) => t.time.nome == nomeTime);
    } catch (_) {
      return null;
    }
  } else if (faseTorneioGlobal == 2 || faseTorneioGlobal == 4) {
    for (var grupo in gruposGlobal) {
      for (var t in grupo) {
        if (t.time.nome == nomeTime) return t;
      }
    }
  }
  return null;
}

// =============================================================================
// MAIN
// =============================================================================

void main() {
  runApp(const PeladaApp());
}

class PeladaApp extends StatelessWidget {
  const PeladaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pelada App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

// =============================================================================
// PAINEL DA PARTIDA (MODAL INTERATIVO COM TEMPORIZADOR E GC)
// =============================================================================

class PainelPartidaModal extends StatefulWidget {
  final Torneio torneio;
  final Partida partida;
  final VoidCallback onGameUpdated;

  const PainelPartidaModal({super.key, required this.torneio, required this.partida, required this.onGameUpdated});

  @override
  State<PainelPartidaModal> createState() => _PainelPartidaModalState();
}

class _PainelPartidaModalState extends State<PainelPartidaModal> {
  Timer? _cronometro;
  late int _tempoRestante; // Agora ele recebe o valor dinâmico
  bool _rodando = false;

  @override
  void initState() {
    super.initState();
    // Inicia o relógio com o tempo escolhido nas configurações do Torneio
    _tempoRestante = widget.torneio.tempoPartidaMinutos * 60;
  }

  @override
  void dispose() {
    _cronometro?.cancel();
    super.dispose();
  }

  void _controlarCronometro() {
    if (_rodando) {
      _cronometro?.cancel();
    } else {
      if (_tempoRestante <= 0) return;
      _cronometro = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() {
          _tempoRestante--;
          if (_tempoRestante <= 0) {
            _cronometro?.cancel();
            _rodando = false;
          }
        });
      });
    }
    setState(() => _rodando = !_rodando);
  }

  String get _tempoFormatado {
    final min = (_tempoRestante ~/ 60).toString().padLeft(2, '0');
    final seg = (_tempoRestante % 60).toString().padLeft(2, '0');
    return '$min:$seg';
  }

  Future<void> _abrirPopUpGol(bool isTimeA) async {
    final partida = widget.partida;
    bool foiGolContra = false;
    Jogador? jogadorSelecionado;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            // Lógica GC: Lista o time adversário
            List<Jogador> jogadoresDisponiveis = [];
            if (foiGolContra) {
              jogadoresDisponiveis = isTimeA ? partida.timeB.time.jogadores : partida.timeA.time.jogadores;
            } else {
              jogadoresDisponiveis = isTimeA ? partida.timeA.time.jogadores : partida.timeB.time.jogadores;
            }

            return AlertDialog(
              title: Text('Gol do ${isTimeA ? partida.timeA.time.nome : partida.timeB.time.nome}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Foi Gol Contra (GC)?', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                      Switch(
                        value: foiGolContra,
                        activeColor: Colors.red,
                        onChanged: (val) {
                          setStateDialog(() {
                            foiGolContra = val;
                            jogadorSelecionado = null; 
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<Jogador>(
                    value: jogadorSelecionado,
                    decoration: const InputDecoration(labelText: 'Quem fez o gol?', border: OutlineInputBorder()),
                    items: jogadoresDisponiveis.map((j) => DropdownMenuItem(value: j, child: Text(j.nome))).toList(),
                    onChanged: (val) => setStateDialog(() => jogadorSelecionado = val),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: jogadorSelecionado == null
                      ? null
                      : () {
                          // Novo cálculo de minuto baseado no tempo da partida selecionado no menu!
                          final totalSegundos = widget.torneio.tempoPartidaMinutos * 60;
                          final minutosPassados = ((totalSegundos - _tempoRestante) ~/ 60) + 1;
                          
                          setState(() {
                            final gol = GolLog(jogador: jogadorSelecionado!, minuto: minutosPassados, isGolContra: foiGolContra);
                            if (isTimeA) {
                              partida.placarA++;
                              partida.golsA.add(gol);
                            } else {
                              partida.placarB++;
                              partida.golsB.add(gol);
                            }
                          });
                          Navigator.pop(ctx);
                        },
                  child: const Text('Confirmar Gol'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _finalizarEEnviarParaTabela() async {
    final p = widget.partida;
    bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Encerrar Partida?'),
        content: const Text('Tem certeza que deseja encerrar o jogo e atualizar a tabela?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Voltar')),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), onPressed: () => Navigator.pop(ctx, true), child: const Text('Encerrar')),
        ],
      ),
    );

    if (confirmar != true) return;
    _cronometro?.cancel();

    setState(() {
      _rodando = false; p.encerrada = true; p.confirmada = true;
      EstatisticasTime? tA = encontrarTimeNoTorneio(widget.torneio, p.timeA.time.nome);
      EstatisticasTime? tB = encontrarTimeNoTorneio(widget.torneio, p.timeB.time.nome);

      if (tA != null && tB != null) {
        tA.jogos++; tB.jogos++;
        tA.golsPro += p.placarA; tA.golsContra += p.placarB;
        tB.golsPro += p.placarB; tB.golsContra += p.placarA;

        if (p.placarA > p.placarB) { tA.pontos += 3; tA.vitorias++; tB.derrotas++; } 
        else if (p.placarB > p.placarA) { tB.pontos += 3; tB.vitorias++; tA.derrotas++; } 
        else { tA.pontos += 1; tB.pontos += 1; tA.empates++; tB.empates++; }
      }
    });

    salvarTorneiosLocal();
    widget.onGameUpdated();
    if (!mounted) return;
    Navigator.pop(context);
  }

  Widget _buildHistoricoGols(List<GolLog> gols) {
    if (gols.isEmpty) {
      return const Text('Nenhum gol ainda.', style: TextStyle(color: Colors.grey));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: gols.map((g) {
        final gc = g.isGolContra ? ' [GC]' : '';
        return Text('${g.jogador.nome} (${g.minuto}\')$gc');
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.partida;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel da Partida'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // --- PLACAR ---
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(p.timeA.time.nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('${p.placarA}', style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                    const Text('×', style: TextStyle(fontSize: 32, color: Colors.grey)),
                    Column(
                      children: [
                        Text(p.timeB.time.nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('${p.placarB}', style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: Colors.blue)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // --- TEMPORIZADOR ---
            Text(_tempoFormatado,
                style: TextStyle(fontSize: 55, fontWeight: FontWeight.bold, letterSpacing: 4, color: _rodando ? Colors.black : Colors.red)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    // Desabilita se estiver rodando OU se a partida já encerrou
                    onPressed: (_rodando || p.encerrada) ? null : () => setState(() => _tempoRestante = (_tempoRestante - 60).clamp(0, 5999))),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _rodando ? Colors.orange : Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(150, 44)),
                  icon: Icon(_rodando ? Icons.pause : Icons.play_arrow),
                  label: Text(_rodando ? 'Pausar' : 'Iniciar Tempo'),
                  onPressed: p.encerrada ? null : _controlarCronometro, // Trava o tempo
                ),
                IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: (_rodando || p.encerrada) ? null : () => setState(() => _tempoRestante += 60)),
              ],
            ),
            const SizedBox(height: 20),

            // --- BOTÕES DE GOL ---
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    icon: const Icon(Icons.sports_soccer),
                    label: Text('Gol ${p.timeA.time.nome}'),
                    onPressed: p.encerrada ? null : () => _abrirPopUpGol(true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                    icon: const Icon(Icons.sports_soccer),
                    label: Text('Gol ${p.timeB.time.nome}'),
                    onPressed: p.encerrada ? null : () => _abrirPopUpGol(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),

            // --- HISTÓRICO DE GOLS ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.timeA.time.nome, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      const SizedBox(height: 6),
                      _buildHistoricoGols(p.golsA),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.timeB.time.nome, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                      const SizedBox(height: 6),
                      _buildHistoricoGols(p.golsB),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            // --- BOTÃO ENCERRAR (Some se já estiver encerrada) ---
            if (!p.encerrada)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: Colors.red, foregroundColor: Colors.white),
                icon: const Icon(Icons.sports),
                label: const Text('ENCERRAR PARTIDA (Apito Final)'),
                onPressed: _finalizarEEnviarParaTabela,
              )
            else
              const Text('Partida Encerrada e Salva!',
                  style: TextStyle(fontSize: 18, color: Colors.green, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// TELA PRINCIPAL (NAVEGAÇÃO)
// =============================================================================

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  Widget _telaAtual = const TelaCadastro();
  String _tituloAtual = 'Cadastro de Jogadores';

  @override
  void initState() {
    super.initState();
    _carregarDadosIniciais();
  }

  Future<void> _carregarDadosIniciais() async {
    final prefs = await SharedPreferences.getInstance();

    final String? jogadoresJson = prefs.getString('bd_jogadores');
    if (jogadoresJson != null) {
      jogadoresCadastrados = (jsonDecode(jogadoresJson) as List)
          .map((item) => Jogador.fromMap(item as Map<String, dynamic>))
          .toList();
      ordenarJogadores();
    }

    // Carrega a memória do Torneio
    await carregarTorneioLocal();

    setState(() {
      if (_tituloAtual == 'Cadastro de Jogadores') {
        _telaAtual = TelaCadastro(onDataChanged: () => setState(() {}));
      }
    });
  }

  void _mudarTela(Widget tela, String titulo) {
    setState(() {
      _telaAtual = tela;
      _tituloAtual = titulo;
    });
    Navigator.pop(context);
  }

  Future<void> _exportarArquivoCSV() async {
    Navigator.pop(context);
    if (jogadoresCadastrados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Nenhum jogador para exportar!'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    try {
      String conteudoCSV = "Nome,Nota,Goleiro,Presente\n";
      for (var j in jogadoresCadastrados) {
        conteudoCSV += "${j.nome},${j.nota.name},${j.isGoleiro},${j.presente}\n";
      }

      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/pelada_backup.csv';
      final file = File(path);
      await file.writeAsString(conteudoCSV);

      await Share.shareXFiles([XFile(path)], text: 'Backup Pelada Pro');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao exportar: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _importarArquivoCSV() async {
    Navigator.pop(context);
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        String contents = "";

        // NOVO: Verifica se está na Web ou no Celular/Desktop
        if (kIsWeb) {
          if (result.files.single.bytes != null) {
            // Na Web, decodificamos os bytes da memória diretamente
            contents = utf8.decode(result.files.single.bytes!);
          } else {
            throw Exception('Não foi possível ler os dados do arquivo na Web.');
          }
        } else {
          // No Celular, lemos pelo caminho do arquivo
          if (result.files.single.path != null) {
            final file = File(result.files.single.path!);
            contents = await file.readAsString();
          } else {
            throw Exception('Caminho do arquivo não encontrado.');
          }
        }

        final linhas = contents.split('\n');
        final temporario = <Jogador>[];

        for (var linha in linhas) {
          if (linha.trim().isEmpty || linha.toLowerCase().startsWith('nome,')) continue;

          final partes = linha.split(',');
          if (partes.length >= 4) {
            temporario.add(Jogador(
              nome: partes[0].trim(),
              nota: Nota.values.firstWhere((e) => e.name == partes[1].trim()),
              isGoleiro: partes[2].trim() == 'true',
              presente: partes[3].trim() == 'true',
            ));
          }
        }

        if (temporario.isNotEmpty) {
          setState(() {
            jogadoresCadastrados = temporario;
            ordenarJogadores();
          });

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('bd_jogadores',
              jsonEncode(jogadoresCadastrados.map((j) => j.toMap()).toList()));

          _mudarTela(
            TelaCadastro(onDataChanged: () => setState(() {})),
            'Cadastro de Jogadores',
          );

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('${temporario.length} Jogadores restaurados com sucesso!'),
                backgroundColor: Colors.green),
          );
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('O arquivo CSV parece estar vazio ou no formato errado.'),
                backgroundColor: Colors.orange),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao importar arquivo: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tituloAtual),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.green),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.sports_soccer, size: 50, color: Colors.white),
                  SizedBox(height: 10),
                  Text('Pelada Pro',
                      style: TextStyle(color: Colors.white, fontSize: 24)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('Cadastro'),
              onTap: () => _mudarTela(
                TelaCadastro(key: UniqueKey(), onDataChanged: () => setState(() {})),
                'Cadastro de Jogadores',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.shuffle),
              title: const Text('Sorteio'),
              onTap: () => _mudarTela(TelaSorteio(key: UniqueKey()), 'Definir Sorteio'),
            ),
            ListTile(
              leading: const Icon(Icons.emoji_events),
              title: const Text('Torneio'),
              onTap: () =>
                  _mudarTela(TelaTorneio(key: UniqueKey()), 'Organizar Campeonato'),
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.only(left: 16, top: 8, bottom: 8),
              child: Text('Banco de Dados (.csv)',
                  style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('Salvar/Compartilhar .csv'),
              onTap: _exportarArquivoCSV,
            ),
            ListTile(
              leading: const Icon(Icons.download_rounded),
              title: const Text('Importar arquivo .csv'),
              onTap: _importarArquivoCSV,
            ),
          ],
        ),
      ),
      body: SafeArea(
        bottom: true,
        child: _telaAtual,
      ),
    );
  }
}

// =============================================================================
// TELA 1: CADASTRO
// =============================================================================

class TelaCadastro extends StatefulWidget {
  final VoidCallback? onDataChanged;
  const TelaCadastro({super.key, this.onDataChanged});

  @override
  State<TelaCadastro> createState() => _TelaCadastroState();
}

class _TelaCadastroState extends State<TelaCadastro> {
  final _nomeController = TextEditingController();
  Nota _notaSelecionada = Nota.C;
  bool _isGoleiro = false;

  Future<void> _salvarNoBancoLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'bd_jogadores',
        jsonEncode(jogadoresCadastrados.map((j) => j.toMap()).toList()));
    widget.onDataChanged?.call();
  }

  void _adicionarJogador() {
    if (_nomeController.text.trim().isEmpty) return;
    setState(() {
      jogadoresCadastrados.add(Jogador(
        nome: _nomeController.text.trim(),
        nota: _notaSelecionada,
        isGoleiro: _isGoleiro,
      ));
      ordenarJogadores();
      _nomeController.clear();
      _notaSelecionada = Nota.C;
      _isGoleiro = false;
    });
    _salvarNoBancoLocal();
    FocusScope.of(context).unfocus();
  }

  void _apagarJogador(int index) {
    setState(() => jogadoresCadastrados.removeAt(index));
    _salvarNoBancoLocal();
  }

  void _abrirPopUpEdicao(int index) {
    final jogador = jogadoresCadastrados[index];
    final editNomeController = TextEditingController(text: jogador.nome);
    Nota editNota = jogador.nota;
    bool editGoleiro = jogador.isGoleiro;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Editar Jogador'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: editNomeController,
                decoration: const InputDecoration(
                    labelText: 'Nome do Jogador', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Nota:'),
                  DropdownButton<Nota>(
                    value: editNota,
                    onChanged: (val) => setStateDialog(() => editNota = val!),
                    items: Nota.values
                        .map((n) => DropdownMenuItem(value: n, child: Text(n.name)))
                        .toList(),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Goleiro:'),
                  Switch(
                    value: editGoleiro,
                    activeColor: Colors.orange,
                    onChanged: (val) => setStateDialog(() => editGoleiro = val),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue, foregroundColor: Colors.white),
              onPressed: () {
                if (editNomeController.text.trim().isEmpty) return;
                setState(() {
                  jogadoresCadastrados[index].nome = editNomeController.text.trim();
                  jogadoresCadastrados[index].nota = editNota;
                  jogadoresCadastrados[index].isGoleiro = editGoleiro;
                  ordenarJogadores();
                });
                _salvarNoBancoLocal();
                Navigator.pop(ctx);
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = jogadoresCadastrados.length;
    final presentes = jogadoresCadastrados.where((j) => j.presente).length;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nomeController,
                          decoration: const InputDecoration(
                            labelText: 'Adicionar Novo Jogador',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      DropdownButton<Nota>(
                        value: _notaSelecionada,
                        onChanged: (val) => setState(() => _notaSelecionada = val!),
                        items: Nota.values
                            .map((n) => DropdownMenuItem(
                                value: n, child: Text("Nota ${n.name}")))
                            .toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Checkbox(
                          value: _isGoleiro,
                          onChanged: (val) => setState(() => _isGoleiro = val!)),
                      const Text('É Goleiro'),
                      const Spacer(),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green, foregroundColor: Colors.white),
                        onPressed: _adicionarJogador,
                        icon: const Icon(Icons.add),
                        label: const Text('Adicionar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Cadastrados: $total | Presentes: $presentes',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: jogadoresCadastrados.length,
              itemBuilder: (context, index) {
                final j = jogadoresCadastrados[index];
                return Card(
                  color: j.presente ? Colors.white : Colors.grey.shade200,
                  child: ListTile(
                    leading: Switch(
                      value: j.presente,
                      activeColor: Colors.green,
                      onChanged: (val) {
                        setState(() => j.presente = val);
                        _salvarNoBancoLocal();
                      },
                    ),
                    title: Text(
                      j.nome,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        decoration: j.presente ? null : TextDecoration.lineThrough,
                        color: j.presente ? Colors.black : Colors.grey,
                      ),
                    ),
                    subtitle: Text(
                      j.isGoleiro
                          ? 'Goleiro • Nota ${j.nota.name}'
                          : 'Linha • Nota ${j.nota.name}',
                      style: TextStyle(color: j.presente ? Colors.black54 : Colors.grey),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _abrirPopUpEdicao(index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _apagarJogador(index),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// TELA 2: SORTEIO
// =============================================================================

class TelaSorteio extends StatefulWidget {
  const TelaSorteio({super.key});

  @override
  State<TelaSorteio> createState() => _TelaSorteioState();
}

class _TelaSorteioState extends State<TelaSorteio> {
  int _qtdPorTime = 5;
  int _regraSorteio = 2;
  bool _considerarGoleiros = true;
  final Map<Nota, int> _notasManuais = {
    Nota.A: 1,
    Nota.B: 1,
    Nota.C: 1,
    Nota.D: 1,
    Nota.E: 0,
  };

  void _toggleTrofeu(HistoricoSorteio item) {
    setState(() {
      if (sorteiosDisponiveisTorneio.contains(item.dataHora)) {
        sorteiosDisponiveisTorneio.remove(item.dataHora);
      } else {
        sorteiosDisponiveisTorneio.add(item.dataHora);
      }
    });
    salvarTorneiosLocal();
  }

  @override
  void initState() {
    super.initState();
    _carregarHistoricoLocal();
  }

  

  Future<void> _carregarHistoricoLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final String? historicoJson = prefs.getString('bd_historico');
    if (historicoJson != null) {
      setState(() {
        historicoSorteios = (jsonDecode(historicoJson) as List)
            .map((item) => HistoricoSorteio.fromMap(item as Map<String, dynamic>))
            .toList();
      });
    }
  }

  Future<void> _salvarNoHistorico(List<TimeSorteado> times) async {
    if (historicoSorteios.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Limite de 5 sorteios atingido! Exclua um abaixo para salvar.'),
          backgroundColor: Colors.red));
      return;
    }
    final agora = DateTime.now();
    final dataHoraStr =
        "${agora.day.toString().padLeft(2, '0')}/${agora.month.toString().padLeft(2, '0')}/${agora.year} às ${agora.hour.toString().padLeft(2, '0')}:${agora.minute.toString().padLeft(2, '0')}";

    setState(() {
      historicoSorteios.insert(0, HistoricoSorteio(dataHora: dataHoraStr, times: times));
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'bd_historico', jsonEncode(historicoSorteios.map((h) => h.toMap()).toList()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Sorteio gravado com sucesso!'), backgroundColor: Colors.green));
  }

  void _ativarParaTorneio(HistoricoSorteio sorteio) {
    setState(() {
      sorteioAtivoDataHora = sorteio.dataHora;
      timesSalvosTorneio = sorteio.times;
      faseTorneioGlobal = 0; // Força reiniciar configs no torneio
      tabelaGeralGlobal.clear();
      gruposGlobal.clear();
      listaPartidasTorneio.clear();
    });
    salvarTorneioLocal();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Sorteio ATIVADO para o Torneio! Vá para a aba Torneio.'),
        backgroundColor: Colors.blue));
  }

  Future<void> _excluirDoHistorico(int index) async {
    if (sorteioAtivoDataHora == historicoSorteios[index].dataHora) {
      final confirmar = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 10),
            Text('Atenção!')
          ]),
          content: const Text(
              'Este é o sorteio ativo do seu Torneio. Excluí-lo irá resetar as tabelas. Deseja continuar?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Excluir')),
          ],
        ),
      );

      if (confirmar != true) return;

      setState(() {
        sorteioAtivoDataHora = null;
        timesSalvosTorneio.clear();
        faseTorneioGlobal = 0;
        tabelaGeralGlobal.clear();
        gruposGlobal.clear();
        listaPartidasTorneio.clear();
      });
      salvarTorneioLocal();
    }

    setState(() => historicoSorteios.removeAt(index));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'bd_historico', jsonEncode(historicoSorteios.map((h) => h.toMap()).toList()));
  }

  void _realizarSorteio() {
    final ativos = jogadoresCadastrados.where((j) => j.presente).toList();
    if (ativos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ative o status "Veio Hoje" de pelo menos um jogador!'),
          backgroundColor: Colors.orange));
      return;
    }

    final goleiros =
        _considerarGoleiros ? ativos.where((j) => j.isGoleiro).toList() : <Jogador>[];
    final linha = _considerarGoleiros
        ? ativos.where((j) => !j.isGoleiro).toList()
        : List<Jogador>.from(ativos);

    if (linha.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Não há jogadores de linha suficientes!'),
          backgroundColor: Colors.orange));
      return;
    }

    final qtdTimes = (linha.length / _qtdPorTime).ceil();
    final times = List.generate(
        qtdTimes, (i) => TimeSorteado(nome: 'Time ${i + 1}', jogadores: []));

    final capacidadesLinha = List.filled(qtdTimes, _qtdPorTime);
    final resto = linha.length % _qtdPorTime;
    if (resto != 0) capacidadesLinha[qtdTimes - 1] = resto;

    goleiros.shuffle();
    linha.shuffle();

    for (int i = 0; i < goleiros.length; i++) {
      times[i % qtdTimes].jogadores.add(goleiros[i]);
    }

    int indexTimeLinha = 0;
    int getQtdLinha(TimeSorteado t) => _considerarGoleiros
        ? t.jogadores.where((p) => !p.isGoleiro).length
        : t.jogadores.length;

    void alocarLinha(Jogador j) {
      int tentativas = 0;
      while (getQtdLinha(times[indexTimeLinha % qtdTimes]) >=
          capacidadesLinha[indexTimeLinha % qtdTimes]) {
        indexTimeLinha++;
        tentativas++;
        if (tentativas > qtdTimes) break;
      }
      times[indexTimeLinha % qtdTimes].jogadores.add(j);
      indexTimeLinha++;
    }

    if (_regraSorteio == 1) {
      for (var j in linha) alocarLinha(j);
    } else if (_regraSorteio == 2) {
      linha.sort((a, b) => a.nota.index.compareTo(b.nota.index));
      for (var j in linha) alocarLinha(j);
    } else {
      final linhaRestante = List<Jogador>.from(linha);
      for (int t = 0; t < qtdTimes; t++) {
        for (var nota in Nota.values) {
          final necessarios = _notasManuais[nota] ?? 0;
          for (int i = 0; i < necessarios; i++) {
            if (getQtdLinha(times[t]) >= capacidadesLinha[t]) break;
            final idx = linhaRestante.indexWhere((j) => j.nota == nota);
            if (idx != -1) times[t].jogadores.add(linhaRestante.removeAt(idx));
          }
        }
      }
      for (var j in linhaRestante) alocarLinha(j);
    }

    _mostrarResultado(times);
  }

  void _mostrarResultado(List<TimeSorteado> times) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Times Sorteados',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: times.length,
                itemBuilder: (context, index) {
                  final t = times[index];
                  return Card(
                    child: ExpansionTile(
                      initiallyExpanded: true,
                      title: Text(t.nome,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${t.jogadores.length} atletas'),
                      children: t.jogadores
                          .map((j) => ListTile(
                                title: Text(j.nome),
                                trailing: Text(j.isGoleiro && _considerarGoleiros
                                    ? 'Goleiro'
                                    : 'Nota: ${j.nota.name}'),
                              ))
                          .toList(),
                    ),
                  );
                },
              ),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.save_outlined),
              label: const Text('Salvar Sorteio na Memória'),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              onPressed: () {
                Navigator.pop(context);
                _salvarNoHistorico(times);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final presentes = jogadoresCadastrados.where((j) => j.presente).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Atletas Confirmados Hoje: $presentes',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                const Text('Jogadores por time: '),
                DropdownButton<int>(
                    value: _qtdPorTime,
                    onChanged: (val) => setState(() => _qtdPorTime = val!),
                    items: [3, 4, 5, 6, 7, 8, 9, 10, 11]
                        .map((n) => DropdownMenuItem(value: n, child: Text(n.toString())))
                        .toList())
              ]),
              Row(children: [
                const Text('Separar Goleiros?'),
                Checkbox(
                    value: _considerarGoleiros,
                    activeColor: Colors.green,
                    onChanged: (val) => setState(() => _considerarGoleiros = val!))
              ]),
            ],
          ),
          const Divider(),
          const Text('Regra de Sorteio:', style: TextStyle(fontWeight: FontWeight.bold)),
          RadioListTile(
              title: const Text('100% Aleatório'),
              value: 1,
              groupValue: _regraSorteio,
              onChanged: (val) => setState(() => _regraSorteio = val!)),
          RadioListTile(
              title: const Text('Equilibrado (Máquina Decide)'),
              value: 2,
              groupValue: _regraSorteio,
              onChanged: (val) => setState(() => _regraSorteio = val!)),
          RadioListTile(
              title: const Text('Manual (Definir Notas por Time)'),
              value: 3,
              groupValue: _regraSorteio,
              onChanged: (val) => setState(() => _regraSorteio = val!)),
          if (_regraSorteio == 3) ...[
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text('Quantidade de cada nota por time:')),
            ...Nota.values.map((n) => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Nota ${n.name}:'),
                    Row(children: [
                      IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: () => setState(() {
                                if (_notasManuais[n]! > 0)
                                  _notasManuais[n] = _notasManuais[n]! - 1;
                              })),
                      Text('${_notasManuais[n]}'),
                      IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () =>
                              setState(() => _notasManuais[n] = _notasManuais[n]! + 1))
                    ])
                  ],
                )),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              onPressed: _realizarSorteio,
              child: const Text('SORTEAR TIMES')),
          const SizedBox(height: 30),
          Text('Sorteios Salvos (${historicoSorteios.length}/5)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Divider(),
          if (historicoSorteios.isEmpty)
            const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                    child: Text('Nenhum sorteio salvo na memória.',
                        style: TextStyle(color: Colors.grey))))
          else
            ...List.generate(historicoSorteios.length, (index) {
              final item = historicoSorteios[index];
              final isAtivo = sorteiosDisponiveisTorneio.contains(item.dataHora);

              return Card(
                color: isAtivo ? Colors.orange.shade50 : Colors.green.shade50,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ExpansionTile(
                  leading: Icon(
                      isAtivo ? Icons.emoji_events : Icons.history_toggle_off,
                      color: isAtivo ? Colors.orange : Colors.green),
                  title: Text(item.dataHora + (isAtivo ? ' (Marcado)' : ''),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${item.times.length} Equipes criadas'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.emoji_events, color: isAtivo ? Colors.orange : Colors.grey),
                        tooltip: 'Disponibilizar para Torneio',
                        onPressed: () => _toggleTrofeu(item),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _excluirDoHistorico(index), // Mantenha sua função de excluir atual
                      ),
                    ],
                  ),
                  children: item.times.map((t) => ListTile(dense: true, title: Text(t.nome, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(t.jogadores.map((j) => j.nome).join(', ')))).toList(),
                ),
              );
            }),
        ],
      ),
    );
  }
}

/// =============================================================================
// TELA 3: TORNEIO (GERENCIADOR DE PASTAS)
// =============================================================================

class TelaTorneio extends StatefulWidget {
  const TelaTorneio({super.key});
  @override
  State<TelaTorneio> createState() => _TelaTorneioState();
}

class _TelaTorneioState extends State<TelaTorneio> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: Colors.green, foregroundColor: Colors.white),
              icon: const Icon(Icons.add),
              label: const Text('Criar Novo Campeonato'),
              onPressed: () async {
                if (historicoTorneios.length >= 5) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Limite de 5 campeonatos atingido. Exclua um.'), backgroundColor: Colors.red));
                  return;
                }
                if (sorteiosDisponiveisTorneio.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ative o ícone de troféu em algum Sorteio Salvo na aba Sorteio primeiro!'), backgroundColor: Colors.orange));
                  return;
                }
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const NovoTorneioScreen()));
                setState(() {});
              },
            ),
          ),
          const Divider(),
          Expanded(
            child: historicoTorneios.isEmpty
                ? const Center(child: Text('Nenhum torneio criado.', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: historicoTorneios.length,
                    itemBuilder: (ctx, idx) {
                      var t = historicoTorneios[idx];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          leading: const Icon(Icons.emoji_events, color: Colors.amber, size: 40),
                          title: Text(t.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${t.dataCriacao}\nFormato: ${t.tipo == 1 ? 'Série A' : t.tipo == 2 ? 'Grupos' : 'Mata-Mata'}'),
                          isThreeLine: true,
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () { setState(() => historicoTorneios.removeAt(idx)); salvarTorneiosLocal(); },
                          ),
                          onTap: () async {
                            await Navigator.push(context, MaterialPageRoute(builder: (_) => TorneioDetalhesScreen(torneio: t)));
                            setState(() {}); 
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// TELA DE CRIAÇÃO DE TORNEIO E ALGORITMO DE BERGER
class NovoTorneioScreen extends StatefulWidget {
  const NovoTorneioScreen({super.key});
  @override
  State<NovoTorneioScreen> createState() => _NovoTorneioScreenState();
}

class _NovoTorneioScreenState extends State<NovoTorneioScreen> {
  final _nomeController = TextEditingController();
  int _tipoSelecionado = 1;
  int _qtdGrupos = 2;
  String? _sorteioId;

  // Algoritmo de Berger (Todos contra todos justos, agora com Ida e Volta)
  void _gerarJogosPara(Torneio torneio, List<EstatisticasTime> baseTimes, bool idaERetorno) {
    List<EstatisticasTime?> times = List.from(baseTimes);
    if (times.length % 2 != 0) times.add(null);
    int numRounds = times.length - 1;
    int halfSize = times.length ~/ 2;
    int idJogo = torneio.partidas.length + 1;

    List<Partida> partidasIda = [];

    for (int round = 0; round < numRounds; round++) {
      for (int i = 0; i < halfSize; i++) {
        int a = i; int b = times.length - 1 - i;
        if (i == 0 && round % 2 != 0) { a = times.length - 1 - i; b = i; }
        if (times[a] != null && times[b] != null) {
          partidasIda.add(Partida(id: 'J$idJogo', timeA: times[a]!, timeB: times[b]!));
          idJogo++;
        }
      }
      times.insert(1, times.removeLast());
    }

    torneio.partidas.addAll(partidasIda);
    if (idaERetorno) {
      for (var p in partidasIda) {
        torneio.partidas.add(Partida(id: '${p.id}_R', timeA: p.timeB, timeB: p.timeA));
      }
    }
  }

  // NOVO: Menu de configuração que aparece antes de criar de fato
  void _mostrarMenuDeConfiguracao() {
    if (_nomeController.text.trim().isEmpty || _sorteioId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha o nome e selecione um sorteio!'), backgroundColor: Colors.orange));
      return;
    }

    int tempoSelecionado = 10;
    bool idaERetorno = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Configurações da Partida', textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Tempo de cada partida (minutos):', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(icon: const Icon(Icons.remove_circle, size: 30, color: Colors.red), onPressed: () => setStateDialog(() { if(tempoSelecionado > 1) tempoSelecionado--; })),
                  Text('$tempoSelecionado', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.add_circle, size: 30, color: Colors.green), onPressed: () => setStateDialog(() { tempoSelecionado++; })),
                ]
              ),
              const SizedBox(height: 20),
              if (_tipoSelecionado != 3) // Se for mata-mata, geralmente não tem ida e volta no mesmo painel
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Turno e Returno (Ida e Volta)?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  value: idaERetorno,
                  activeColor: Colors.blue,
                  onChanged: (val) => setStateDialog(() => idaERetorno = val),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(ctx);
                _criarTorneioFinal(tempoSelecionado, idaERetorno); // Chama a função real de criar
              },
              child: const Text('Confirmar e Gerar')
            )
          ],
        )
      )
    );
  }

  void _criarTorneioFinal(int tempoPartida, bool idaERetorno) {
    final sorteioBase = historicoSorteios.firstWhere((s) => s.dataHora == _sorteioId);
    final novoTorneio = Torneio(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      nome: _nomeController.text.trim(),
      dataCriacao: "${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')} às ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}",
      tipo: _tipoSelecionado,
      tempoPartidaMinutos: tempoPartida, // Salva o tempo
      idaERetorno: idaERetorno,          // Salva se tem returno
    );

    final timesCopiados = sorteioBase.times.map((t) => TimeSorteado.fromMap(t.toMap())).toList();

    if (_tipoSelecionado == 1) { // Série A
      novoTorneio.tabelaGeral = timesCopiados.map((t) => EstatisticasTime(time: t)).toList();
      _gerarJogosPara(novoTorneio, novoTorneio.tabelaGeral, idaERetorno);
    } else if (_tipoSelecionado == 2) { // Grupos
      final pool = List<TimeSorteado>.from(timesCopiados)..shuffle();
      novoTorneio.grupos = List.generate(_qtdGrupos, (_) => []);
      for (int i = 0; i < pool.length; i++) {
        novoTorneio.grupos[i % _qtdGrupos].add(EstatisticasTime(time: pool[i]));
      }
      for (var g in novoTorneio.grupos) {
        _gerarJogosPara(novoTorneio, g, idaERetorno);
      }
    } else if (_tipoSelecionado == 3) { // Mata-Mata
      novoTorneio.tabelaGeral = timesCopiados.map((t) => EstatisticasTime(time: t)).toList();
    }

    historicoTorneios.insert(0, novoTorneio);
    salvarTorneiosLocal();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final sorteiosDisponiveis = historicoSorteios.where((s) => sorteiosDisponiveisTorneio.contains(s.dataHora)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Novo Campeonato'), backgroundColor: Theme.of(context).colorScheme.inversePrimary),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nomeController,
              decoration: const InputDecoration(labelText: 'Nome do Campeonato', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _sorteioId,
              decoration: const InputDecoration(labelText: 'Sorteio Base (Times)', border: OutlineInputBorder()),
              items: sorteiosDisponiveis.map((s) => DropdownMenuItem(value: s.dataHora, child: Text(s.dataHora))).toList(),
              onChanged: (val) => setState(() => _sorteioId = val),
            ),
            if (sorteiosDisponiveis.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text('Nenhum sorteio com o troféu ativado na aba "Sorteio"!', style: TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 20),
            const Text('Formato da Disputa:', style: TextStyle(fontWeight: FontWeight.bold)),
            RadioListTile(title: const Text('Pontos Corridos (Série A)'), value: 1, groupValue: _tipoSelecionado, onChanged: (val) => setState(() => _tipoSelecionado = val!)),
            RadioListTile(title: const Text('Fase de Grupos'), value: 2, groupValue: _tipoSelecionado, onChanged: (val) => setState(() => _tipoSelecionado = val!)),
            RadioListTile(title: const Text('Mata-Mata'), value: 3, groupValue: _tipoSelecionado, onChanged: (val) => setState(() => _tipoSelecionado = val!)),
            if (_tipoSelecionado == 2) ...[
               const SizedBox(height: 10),
               Row(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   const Text('Quantidade de Grupos: '),
                   IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red), onPressed: () => setState((){ if(_qtdGrupos>2) _qtdGrupos--;})),
                   Text('$_qtdGrupos', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                   IconButton(icon: const Icon(Icons.add_circle, color: Colors.green), onPressed: () => setState((){ _qtdGrupos++;})),
                 ]
               )
            ],
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: Colors.blue, foregroundColor: Colors.white),
              // NOVO: Agora ele chama o menu de configuração ao invés de criar direto
              onPressed: _mostrarMenuDeConfiguracao,
              child: const Text('GERAR CAMPEONATO')
            )
          ]
        )
      )
    );
  }
}

// TELA DE DETALHES (ABAS: JOGOS, CLASSIFICAÇÃO E ARTILHARIA)
class TorneioDetalhesScreen extends StatefulWidget {
  final Torneio torneio;
  const TorneioDetalhesScreen({super.key, required this.torneio});
  @override
  State<TorneioDetalhesScreen> createState() => _TorneioDetalhesScreenState();
}

class _TorneioDetalhesScreenState extends State<TorneioDetalhesScreen> {
  int _abaAtual = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.torneio.nome), backgroundColor: Theme.of(context).colorScheme.inversePrimary),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _abaAtual,
        onTap: (i) => setState(() => _abaAtual = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.sports_soccer), label: 'Jogos'),
          BottomNavigationBarItem(icon: Icon(Icons.format_list_numbered), label: 'Tabela'),
          BottomNavigationBarItem(icon: Icon(Icons.star), label: 'Artilharia'),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_abaAtual == 0) return _buildJogos();
    if (_abaAtual == 1) return _buildClassificacao();
    return _buildArtilharia();
  }

  Widget _buildJogos() {
    if (widget.torneio.partidas.isEmpty) return const Center(child: Text('Nenhuma partida gerada.', style: TextStyle(color: Colors.grey)));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.torneio.partidas.length,
      itemBuilder: (ctx, idx) {
        final p = widget.torneio.partidas[idx];
        return Card(
          color: p.encerrada ? Colors.green.shade50 : Colors.white,
          child: ListTile(
            title: Text('${p.timeA.time.nome}  ${p.placarA} × ${p.placarB}  ${p.timeB.time.nome}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
            subtitle: Text(p.encerrada ? 'Encerrada (Toque para ver detalhes)' : 'Toque para apitar o jogo', textAlign: TextAlign.center, style: TextStyle(color: p.encerrada ? Colors.green : Colors.grey)),
            // REMOVIDO: "p.confirmada ? null :" A partida agora SEMPRE abre ao clicar
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => PainelPartidaModal(torneio: widget.torneio, partida: p, onGameUpdated: () => setState(() {}))));
            },
          ),
        );
      },
    );
  }

  Widget _buildClassificacao() {
    if (widget.torneio.tipo == 3) return const Center(child: Text('Modo Mata-Mata: Em desenvolvimento...', style: TextStyle(fontSize: 18, color: Colors.grey)));
    
    if (widget.torneio.tipo == 1) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, 
          children: [
            const Padding(padding: EdgeInsets.all(16), child: Text('Série A', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))), 
            _construirTabela(widget.torneio.tabelaGeral),
            const SizedBox(height: 20),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Elencos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            _buildElencos(widget.torneio.tabelaGeral), // EXIBE OS JOGADORES
            const SizedBox(height: 20),
          ]
        )
      );
    } else {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: widget.torneio.grupos.length,
        itemBuilder: (ctx, idx) => Card(
          elevation: 2, 
          margin: const EdgeInsets.only(bottom: 20), 
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, 
            children: [
              Container(padding: const EdgeInsets.all(12), color: Colors.blue.shade100, child: Text('Grupo ${String.fromCharCode(65 + idx)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))), 
              _construirTabela(widget.torneio.grupos[idx]),
              const SizedBox(height: 10),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Elencos do Grupo', style: TextStyle(fontWeight: FontWeight.bold))),
              _buildElencos(widget.torneio.grupos[idx]), // EXIBE OS JOGADORES DO GRUPO
              const SizedBox(height: 10),
            ]
          )
        ),
      );
    }
  }

  // NOVO VISUAL DA TABELA
  Widget _construirTabela(List<EstatisticasTime> tabela) {
    final ordenada = List<EstatisticasTime>.from(tabela)..sort((a, b) { final p = b.pontos.compareTo(a.pontos); if (p != 0) return p; final s = b.saldoGols.compareTo(a.saldoGols); if (s != 0) return s; return b.golsPro.compareTo(a.golsPro); });
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 18, 
          headingRowColor: MaterialStateProperty.all(Colors.green.shade100),
          headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
          columns: const [
            DataColumn(label: Text('Time')), DataColumn(label: Text('P')), DataColumn(label: Text('J')), 
            DataColumn(label: Text('V')), DataColumn(label: Text('E')), DataColumn(label: Text('D')), 
            DataColumn(label: Text('GP')), DataColumn(label: Text('GC')), DataColumn(label: Text('SG'))
          ],
          rows: ordenada.map((est) => DataRow(cells: [
            DataCell(Text(est.time.nome, style: const TextStyle(fontWeight: FontWeight.bold))), 
            DataCell(Text('${est.pontos}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))), 
            DataCell(Text('${est.jogos}')), DataCell(Text('${est.vitorias}')), DataCell(Text('${est.empates}')), 
            DataCell(Text('${est.derrotas}')), DataCell(Text('${est.golsPro}')), DataCell(Text('${est.golsContra}')), 
            DataCell(Text('${est.saldoGols}', style: TextStyle(color: est.saldoGols >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold)))
          ])).toList(),
        ),
      ),
    );
  }

  // NOVA LISTA RETRÁTIL COM O NOME DOS JOGADORES
  Widget _buildElencos(List<EstatisticasTime> tabela) {
    return Column(
      children: tabela.map((est) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        color: Colors.green.shade50,
        child: ExpansionTile(
          leading: const Icon(Icons.shield, color: Colors.green),
          title: Text(est.time.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('${est.time.jogadores.length} jogadores'),
          children: est.time.jogadores.map((j) => ListTile(
            dense: true,
            title: Text(j.nome),
            trailing: Text(j.isGoleiro ? 'Goleiro' : 'Linha', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
          )).toList(),
        ),
      )).toList(),
    );
  }

  Widget _buildArtilharia() {
    Map<String, int> golsMap = {};
    for (var p in widget.torneio.partidas) {
      for (var g in p.golsA) { if (!g.isGolContra) golsMap[g.jogador.nome] = (golsMap[g.jogador.nome] ?? 0) + 1; }
      for (var g in p.golsB) { if (!g.isGolContra) golsMap[g.jogador.nome] = (golsMap[g.jogador.nome] ?? 0) + 1; }
    }

    var lista = golsMap.entries.map((e) => {'nome': e.key, 'gols': e.value}).toList();
    lista.sort((a, b) => (b['gols'] as int).compareTo(a['gols'] as int));

    if (lista.isEmpty) return const Center(child: Text('Nenhum gol marcado.', style: TextStyle(color: Colors.grey)));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: lista.length,
      itemBuilder: (ctx, idx) {
        final artilheiro = lista[idx];
        Color iconColor = Colors.grey;
        if (idx == 0) iconColor = Colors.amber; else if (idx == 1) iconColor = Colors.blueGrey; else if (idx == 2) iconColor = Colors.brown;
        return Card(
          child: ListTile(
            leading: Icon(Icons.star, color: idx < 3 ? iconColor : Colors.transparent),
            title: Text('${idx + 1}º - ${artilheiro['nome']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: Text('${artilheiro['gols']} Gols', style: const TextStyle(fontSize: 16, color: Colors.green)),
          ),
        );
      }
    );
  }
}
