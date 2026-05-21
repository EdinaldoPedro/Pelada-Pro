import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

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

// --- MODELOS ---

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

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'nota': nota.name,
      'isGoleiro': isGoleiro,
      'presente': presente,
    };
  }

  factory Jogador.fromMap(Map<String, dynamic> map) {
    return Jogador(
      nome: map['nome'],
      nota: Nota.values.firstWhere((e) => e.name == map['nota']),
      isGoleiro: map['isGoleiro'] ?? false,
      presente: map['presente'] ?? true,
    );
  }
}

class TimeSorteado {
  String nome;
  List<Jogador> jogadores;

  TimeSorteado({required this.nome, required this.jogadores});

  // Novo: ToMap para salvar no histórico
  Map<String, dynamic> toMap() => {
    'nome': nome,
    'jogadores': jogadores.map((j) => j.toMap()).toList(),
  };

  // Novo: FromMap para ler do histórico
  factory TimeSorteado.fromMap(Map<String, dynamic> map) => TimeSorteado(
    nome: map['nome'],
    jogadores: (map['jogadores'] as List).map((j) => Jogador.fromMap(j as Map<String, dynamic>)).toList(),
  );
}

// NOVO MODELO: Para controlar o limite de 5 e a data/hora
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
    times: (map['times'] as List).map((t) => TimeSorteado.fromMap(t as Map<String, dynamic>)).toList(),
  );
}

// --- ESTADO GLOBAL ---
List<Jogador> jogadoresCadastrados = [];
List<TimeSorteado> timesSalvosTorneio = [];
List<HistoricoSorteio> historicoSorteios = []; // NOVO: Guarda os 5 últimos sorteios

// --- TELA PRINCIPAL E CONTROLE DE ARQUIVOS ---



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
      final List<dynamic> decoded = jsonDecode(jogadoresJson);
      setState(() {
        jogadoresCadastrados = decoded.map((item) => Jogador.fromMap(item as Map<String, dynamic>)).toList();
        if (_tituloAtual == 'Cadastro de Jogadores') {
          _telaAtual = TelaCadastro(onDataChanged: () => setState(() {}));
        }
      });
    }
  }

  void _mudarTela(Widget tela, String titulo) {
    setState(() {
      _telaAtual = tela;
      _tituloAtual = titulo;
    });
    Navigator.pop(context);
  }

  // --- EXPORTAR ARQUIVO .CSV REAL ---
  Future<void> _exportarArquivoCSV() async {
    Navigator.pop(context);
    if (jogadoresCadastrados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum jogador para exportar!'), backgroundColor: Colors.orange),
      );
      return;
    }

    try {
      String conteudoCSV = "Nome,Nota,Goleiro,Presente\n";
      for (var j in jogadoresCadastrados) {
        conteudoCSV += "${j.nome},${j.nota.name},${j.isGoleiro},${j.presente}\n";
      }

      // Salva em uma pasta temporária para poder compartilhar
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/pelada_backup.csv';
      final file = File(path);
      await file.writeAsString(conteudoCSV);

      // Abre a janela nativa de compartilhamento (Drive, WhatsApp, Salvar nos Arquivos)
      await Share.shareXFiles([XFile(path)], text: 'Backup Pelada Pro');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao exportar: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // --- IMPORTAR ARQUIVO .CSV REAL ---
  Future<void> _importarArquivoCSV() async {
    Navigator.pop(context);
    try {
      // Abre o seletor de arquivos nativo do celular
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        String contents = await file.readAsString();

        List<String> linhas = contents.split('\n');
        List<Jogador> temporario = [];

        for (var linha in linhas) {
          if (linha.trim().isEmpty || linha.toLowerCase().startsWith('nome,')) continue;
          
          var partes = linha.split(',');
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
          });
          
          final prefs = await SharedPreferences.getInstance();
          final String encoded = jsonEncode(jogadoresCadastrados.map((j) => j.toMap()).toList());
          await prefs.setString('bd_jogadores', encoded);

          _mudarTela(TelaCadastro(onDataChanged: () => setState(() {})), 'Cadastro de Jogadores');
          
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${temporario.length} Jogadores restaurados com sucesso!'), backgroundColor: Colors.green),
          );
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('O arquivo CSV parece estar vazio ou no formato errado.'), backgroundColor: Colors.orange),
          );
        }
      }
    } catch (e) {
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
                  Text('Pelada Pro', style: TextStyle(color: Colors.white, fontSize: 24)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('Cadastro'),
              onTap: () => _mudarTela(TelaCadastro(onDataChanged: () => setState(() {})), 'Cadastro de Jogadores'),
            ),
            ListTile(
              leading: const Icon(Icons.shuffle),
              title: const Text('Sorteio'),
              onTap: () => _mudarTela(const TelaSorteio(), 'Definir Sorteio'),
            ),
            ListTile(
              leading: const Icon(Icons.emoji_events),
              title: const Text('Torneio'),
              onTap: () => _mudarTela(const TelaTorneio(), 'Organizar Campeonato'),
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.only(left: 16, top: 8, bottom: 8),
              child: Text('Banco de Dados (.csv)', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
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
      body: _telaAtual,
    );
  }
}

// --- TELA 1: CADASTRO ---

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
    final String encoded = jsonEncode(jogadoresCadastrados.map((j) => j.toMap()).toList());
    await prefs.setString('bd_jogadores', encoded);
    if (widget.onDataChanged != null) widget.onDataChanged!();
  }

  void _adicionarJogador() {
    if (_nomeController.text.trim().isEmpty) return;

    setState(() {
      jogadoresCadastrados.add(Jogador(
        nome: _nomeController.text.trim(),
        nota: _notaSelecionada,
        isGoleiro: _isGoleiro,
      ));
    });

    _nomeController.clear();
    setState(() {
      _notaSelecionada = Nota.C;
      _isGoleiro = false;
    });
    
    _salvarNoBancoLocal();
    FocusScope.of(context).unfocus();
  }

  void _apagarJogador(int index) {
    setState(() {
      jogadoresCadastrados.removeAt(index);
    });
    _salvarNoBancoLocal();
  }

  // --- NOVO: POP-UP DE EDIÇÃO ---
  void _abrirPopUpEdicao(int index) {
    final jogador = jogadoresCadastrados[index];
    
    // Controles locais apenas para o pop-up
    TextEditingController editNomeController = TextEditingController(text: jogador.nome);
    Nota editNota = jogador.nota;
    bool editGoleiro = jogador.isGoleiro;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        // StatefulBuilder é necessário para atualizar o estado *dentro* do Pop-up
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Editar Jogador'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: editNomeController,
                    decoration: const InputDecoration(labelText: 'Nome do Jogador', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Nota:'),
                      DropdownButton<Nota>(
                        value: editNota,
                        onChanged: (val) => setStateDialog(() => editNota = val!),
                        items: Nota.values.map((n) => DropdownMenuItem(value: n, child: Text(n.name))).toList(),
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
                  )
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context), // Cancela e fecha
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  onPressed: () {
                    if (editNomeController.text.trim().isEmpty) return;

                    // Salva as alterações
                    setState(() {
                      jogadoresCadastrados[index].nome = editNomeController.text.trim();
                      jogadoresCadastrados[index].nota = editNota;
                      jogadoresCadastrados[index].isGoleiro = editGoleiro;
                    });
                    
                    _salvarNoBancoLocal();
                    Navigator.pop(context); // Fecha o pop-up
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    int total = jogadoresCadastrados.length;
    int presentes = jogadoresCadastrados.where((j) => j.presente).length;

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
                        items: Nota.values.map((n) => DropdownMenuItem(value: n, child: Text("Nota ${n.name}"))).toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Checkbox(value: _isGoleiro, onChanged: (val) => setState(() => _isGoleiro = val!)),
                      const Text('É Goleiro'),
                      const Spacer(),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
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
            child: Text('Cadastrados: $total | Presentes: $presentes', 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green)),
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
                        setState(() { j.presente = val; });
                        _salvarNoBancoLocal();
                      },
                    ),
                    title: Text(
                      j.nome, 
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        decoration: j.presente ? null : TextDecoration.lineThrough,
                        color: j.presente ? Colors.black : Colors.grey,
                      )
                    ),
                    subtitle: Text(
                      j.isGoleiro ? 'Goleiro • Nota ${j.nota.name}' : 'Linha • Nota ${j.nota.name}',
                      style: TextStyle(color: j.presente ? Colors.black54 : Colors.grey),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _abrirPopUpEdicao(index), // CHAMA O POP-UP AQUI
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

// --- TELA 2: SORTEIO ---

class TelaSorteio extends StatefulWidget {
  const TelaSorteio({super.key});

  @override
  State<TelaSorteio> createState() => _TelaSorteioState();
}

class _TelaSorteioState extends State<TelaSorteio> {
  int _qtdPorTime = 5;
  int _regraSorteio = 2;
  bool _considerarGoleiros = true; // NOVO: Controle de goleiro
  
  final Map<Nota, int> _notasManuais = {Nota.A: 1, Nota.B: 1, Nota.C: 1, Nota.D: 1, Nota.E: 0};

  @override
  void initState() {
    super.initState();
    _carregarHistorico();
  }

  // Carrega os sorteios salvos do aparelho
  Future<void> _carregarHistorico() async {
    final prefs = await SharedPreferences.getInstance();
    final String? historicoJson = prefs.getString('bd_historico');
    if (historicoJson != null) {
      final List<dynamic> decoded = jsonDecode(historicoJson);
      setState(() {
        historicoSorteios = decoded.map((item) => HistoricoSorteio.fromMap(item as Map<String, dynamic>)).toList();
      });
    }
  }

  // Função para salvar o sorteio atual (Máximo 5)
  Future<void> _salvarNoHistorico(List<TimeSorteado> times) async {
    if (historicoSorteios.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Limite de 5 sorteios atingido! Exclua um antigo abaixo para salvar.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final agora = DateTime.now();
    final dataHoraStr = "${agora.day.toString().padLeft(2, '0')}/${agora.month.toString().padLeft(2, '0')}/${agora.year} às ${agora.hour.toString().padLeft(2, '0')}:${agora.minute.toString().padLeft(2, '0')}";

    setState(() {
      // insert(0, ...) coloca no início da lista, garantindo a ordem do mais recente primeiro
      historicoSorteios.insert(0, HistoricoSorteio(dataHora: dataHoraStr, times: times));
    });

    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(historicoSorteios.map((h) => h.toMap()).toList());
    await prefs.setString('bd_historico', encoded);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sorteio gravado com sucesso!'), backgroundColor: Colors.green),
    );
  }

  Future<void> _excluirDoHistorico(int index) async {
    setState(() {
      historicoSorteios.removeAt(index);
    });
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(historicoSorteios.map((h) => h.toMap()).toList());
    await prefs.setString('bd_historico', encoded);
  }

  void _realizarSorteio() {
    List<Jogador> ativos = jogadoresCadastrados.where((j) => j.presente).toList();

    if (ativos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ative o status "Veio Hoje" de pelo menos um jogador!'), backgroundColor: Colors.orange)
      );
      return;
    }

    // 1. Separa Goleiros e Linha logo no início com base no Checkbox
    List<Jogador> goleiros = _considerarGoleiros ? ativos.where((j) => j.isGoleiro).toList() : [];
    List<Jogador> linha = _considerarGoleiros ? ativos.where((j) => !j.isGoleiro).toList() : List.from(ativos);

    if (linha.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não há jogadores de linha suficientes!'), backgroundColor: Colors.orange)
      );
      return;
    }

    // 2. A quantidade de times e as capacidades são baseadas APENAS na LINHA
    int qtdTimes = (linha.length / _qtdPorTime).ceil();
    List<TimeSorteado> times = List.generate(qtdTimes, (i) => TimeSorteado(nome: 'Time ${i + 1}', jogadores: []));
    
    List<int> capacidadesLinha = List.filled(qtdTimes, _qtdPorTime);
    int resto = linha.length % _qtdPorTime;
    if (resto != 0) {
      capacidadesLinha[qtdTimes - 1] = resto; // O último time fica com a sobra exata da linha
    }

    goleiros.shuffle();
    linha.shuffle();

    // 3. Distribui os Goleiros primeiro (Um por time, não afeta o limite da linha)
    int indexTimeGoleiro = 0;
    for (var g in goleiros) {
      times[indexTimeGoleiro % qtdTimes].jogadores.add(g);
      indexTimeGoleiro++;
    }

    // 4. Função inteligente para distribuir a LINHA respeitando o limite
    int indexTimeLinha = 0;
    void alocarLinha(Jogador j) {
      int tentativas = 0;
      
      // Conta apenas a linha dentro do time para ver se bateu o limite
      int getQtdLinha(TimeSorteado t) => _considerarGoleiros ? t.jogadores.where((p) => !p.isGoleiro).length : t.jogadores.length;

      while (getQtdLinha(times[indexTimeLinha % qtdTimes]) >= capacidadesLinha[indexTimeLinha % qtdTimes]) {
        indexTimeLinha++;
        tentativas++;
        if (tentativas > qtdTimes) break; // Trava de segurança
      }
      times[indexTimeLinha % qtdTimes].jogadores.add(j);
      indexTimeLinha++;
    }

    // 5. Executa a regra escolhida apenas para a LINHA
    if (_regraSorteio == 1) { 
      // REGRA 1: 100% Aleatório
      for (var j in linha) {
        alocarLinha(j);
      }
    } else if (_regraSorteio == 2) { 
      // REGRA 2: Equilibrado (Máquina Decide)
      linha.sort((a, b) => a.nota.index.compareTo(b.nota.index)); // Do melhor pro pior
      
      for (var j in linha) {
        alocarLinha(j);
      }
    } else if (_regraSorteio == 3) { 
      // REGRA 3: Manual (Definir notas)
      for (var time in times) {
        int indexDoTime = times.indexOf(time);
        int capTime = capacidadesLinha[indexDoTime];
        
        for (var nota in Nota.values) {
          int necessarios = _notasManuais[nota] ?? 0;
          for (int i = 0; i < necessarios; i++) {
            int getQtdLinha() => _considerarGoleiros ? time.jogadores.where((p) => !p.isGoleiro).length : time.jogadores.length;
            if (getQtdLinha() >= capTime) break; // Trava se bater o limite da linha
            
            int idx = linha.indexWhere((j) => j.nota == nota);
            if (idx != -1) {
              time.jogadores.add(linha.removeAt(idx));
            }
          }
        }
      }
      // Pega a linha que sobrou da regra manual e distribui
      for (var j in linha) {
        alocarLinha(j);
      }
    }

    _mostrarResultado(times);
  }

  void _mostrarResultado(List<TimeSorteado> times) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text('Times Sorteados', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: times.length,
                  itemBuilder: (context, index) {
                    final t = times[index];
                    return Card(
                      child: ExpansionTile(
                        initiallyExpanded: true,
                        title: Text(t.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${t.jogadores.length} atletas'),
                        children: t.jogadores.map((j) => ListTile(
                          title: Text(j.nome),
                          trailing: Text(j.isGoleiro && _considerarGoleiros ? 'Goleiro' : 'Nota: ${j.nota.name}'),
                        )).toList(),
                      ),
                    );
                  },
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Salvar Sorteio'),
                      onPressed: () {
                        Navigator.pop(context);
                        _salvarNoHistorico(times);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.emoji_events),
                      label: const Text('Enviar ao Torneio'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                      onPressed: () {
                        setState(() { timesSalvosTorneio = times; });
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Times enviados para a aba Torneio!'))
                        );
                      },
                    ),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    int presentes = jogadoresCadastrados.where((j) => j.presente).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Atletas Confirmados Hoje: $presentes', 
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
          const SizedBox(height: 20),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('Jogadores por time: '),
                  DropdownButton<int>(
                    value: _qtdPorTime,
                    onChanged: (val) => setState(() => _qtdPorTime = val!),
                    items: [3, 4, 5, 6, 7, 8, 9, 10, 11].map((n) => DropdownMenuItem(value: n, child: Text(n.toString()))).toList(),
                  ),
                ],
              ),
              // NOVO COMPONENTE: Caixa de seleção para Goleiro
              Row(
                children: [
                  const Text('Separar Goleiros?'),
                  Checkbox(
                    value: _considerarGoleiros,
                    activeColor: Colors.green,
                    onChanged: (val) => setState(() => _considerarGoleiros = val!),
                  )
                ],
              )
            ],
          ),
          const Divider(),

          const Text('Regra de Sorteio:', style: TextStyle(fontWeight: FontWeight.bold)),
          RadioListTile(
            title: const Text('100% Aleatório'),
            value: 1,
            groupValue: _regraSorteio,
            onChanged: (val) => setState(() => _regraSorteio = val!),
          ),
          RadioListTile(
            title: const Text('Equilibrado (Máquina Decide)'),
            value: 2,
            groupValue: _regraSorteio,
            onChanged: (val) => setState(() => _regraSorteio = val!),
          ),
          RadioListTile(
            title: const Text('Manual (Definir Notas por Time)'),
            value: 3,
            groupValue: _regraSorteio,
            onChanged: (val) => setState(() => _regraSorteio = val!),
          ),

          if (_regraSorteio == 3) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text('Quantidade de cada nota por time:'),
            ),
            ...Nota.values.map((n) => Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Nota ${n.name}:'),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: () => setState(() {
                        if (_notasManuais[n]! > 0) _notasManuais[n] = _notasManuais[n]! - 1;
                      }),
                    ),
                    Text('${_notasManuais[n]}'),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => setState(() {
                        _notasManuais[n] = _notasManuais[n]! + 1;
                      }),
                    ),
                  ],
                )
              ],
            )),
          ],

          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            onPressed: _realizarSorteio,
            child: const Text('SORTEAR TIMES'),
          ),
          
          const SizedBox(height: 30),
          // NOVO PAINEL VISUAL: Histórico com os 5 slots e opção de apagar
          Text('Sorteios Salvos (${historicoSorteios.length}/5)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Divider(),
          if (historicoSorteios.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: Text('Nenhum sorteio salvo na memória.', style: TextStyle(color: Colors.grey))),
            )
          else
            ...List.generate(historicoSorteios.length, (index) {
              final item = historicoSorteios[index];
              return Card(
                color: Colors.green.shade50,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ExpansionTile(
                  leading: const Icon(Icons.history_toggle_off, color: Colors.green),
                  title: Text(item.dataHora, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${item.times.length} Equipes criadas'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _excluirDoHistorico(index),
                  ),
                  children: item.times.map((t) => ListTile(
                    dense: true,
                    title: Text(t.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(t.jogadores.map((j) => j.nome).join(', ')),
                  )).toList(),
                ),
              );
            }),
        ],
      ),
    );
  }
}

// --- TELA 3: TORNEIO ---

class TelaTorneio extends StatelessWidget {
  const TelaTorneio({super.key});

  @override
  Widget build(BuildContext context) {
    return timesSalvosTorneio.isEmpty
        ? const Center(child: Text('Nenhum time salvo. Vá no Sorteio primeiro e clique em Enviar ao Torneio.'))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: timesSalvosTorneio.length,
            itemBuilder: (context, index) {
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.shield, color: Colors.green),
                  title: Text(timesSalvosTorneio[index].nome),
                  subtitle: Text('${timesSalvosTorneio[index].jogadores.length} Jogadores carregados.'),
                  trailing: const Icon(Icons.check_circle, color: Colors.green),
                ),
              );
            },
          );
  }
}