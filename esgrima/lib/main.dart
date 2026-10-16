import 'dart:math';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'comp.dart';
import 'firebase_options.dart';

Future<bool> ask(BuildContext c, String msg) async =>
    await showDialog<bool>(
        context: c,
        builder: (_) => AlertDialog(content: Text(msg), actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text('Cancelar')),
              FilledButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('Aceptar')),
            ])) ??
    false;

Widget card(String t, Widget w) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          w
        ])));

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? err;
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    FirebaseFirestore.instance.settings =
        const Settings(persistenceEnabled: true);
    await comp.init();
  } catch (e) {
    err = '$e';
  }
  runApp(EsgrimaApp(error: err));
}

class EsgrimaApp extends StatelessWidget {
  final String? error;
  const EsgrimaApp({super.key, this.error});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Competición de esgrima',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
            colorSchemeSeed: const Color(0xFFC0392B), useMaterial3: true),
        darkTheme: ThemeData(
            colorSchemeSeed: const Color(0xFFC0392B),
            brightness: Brightness.dark,
            useMaterial3: true),
        home: error != null
            ? Scaffold(
                appBar: AppBar(title: const Text('Error de Firebase')),
                body: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                        'No se pudo conectar con Firebase.\n\nRevisa que has ejecutado "flutterfire configure", activado Firestore y el acceso anónimo en Authentication.\n\n$error')))
            : const SplashScreen(),
      );
}

/* ===================== SPLASH ===================== */

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashState();
}

class _SplashState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const duracion =
      Duration(milliseconds: 3000); // tiempo total antes de pasar a la app
  late final AnimationController ctl =
      AnimationController(vsync: this, duration: duracion)..forward();
  late final Animation<double> zoom = Tween<double>(begin: 0.8, end: 1.0)
      .animate(CurvedAnimation(parent: ctl, curve: Curves.easeOutCubic));
  late final Animation<double> fade = CurvedAnimation(
      parent: ctl, curve: const Interval(0, 0.5, curve: Curves.easeIn));
  Timer? timer;

  @override
  void initState() {
    super.initState();
    timer = Timer(duracion, () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => const Home(),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
      ));
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF111418),
        body: Center(
            child: FadeTransition(
                opacity: fade,
                child: ScaleTransition(
                    scale: zoom,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Image.asset('assets/icon.png',
                          width: 140,
                          height: 140,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.sports_martial_arts,
                              size: 110,
                              color: Colors.white)),
                      const SizedBox(height: 20),
                      const Text('Sopre Games',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2)),
                    ])))),
      );
}

/* ===================== PANTALLA INICIAL ===================== */

class Home extends StatelessWidget {
  const Home({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: comp,
        builder: (c, _) {
          if (comp.code == null) return Landing();
          if (!comp.ready)
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          final Widget body = switch (comp.phase) {
            'setup' => SetupView(),
            'poules' => PoulesView(),
            'play' => PlayView(),
            _ => BracketView(),
          };
          return Scaffold(
            appBar: AppBar(title: Text('🤺 ${comp.code}'), actions: [
              Chip(
                  label: Text(comp.isOrg ? 'Organizador' : 'Participante'),
                  visualDensity: VisualDensity.compact),
              IconButton(
                  tooltip: 'Copiar código',
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: comp.code!));
                    ScaffoldMessenger.of(c).showSnackBar(
                        const SnackBar(content: Text('Código copiado')));
                  }),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'leave') {
                    if (await ask(c,
                        '¿Salir de esta competición? Podrás volver a entrar con el código.'))
                      comp.leave();
                  } else if (v == 'reset') {
                    if (await ask(c,
                        '¿Reiniciar la competición? Se borrarán poules y resultados (se mantienen los participantes).'))
                      comp.reset();
                  }
                },
                itemBuilder: (_) => [
                  if (comp.isOrg && comp.phase != 'setup')
                    const PopupMenuItem(
                        value: 'reset', child: Text('Reiniciar competición')),
                  const PopupMenuItem(value: 'leave', child: Text('Salir')),
                ],
              ),
            ]),
            body: SafeArea(child: body),
          );
        },
      );
}

class Landing extends StatefulWidget {
  const Landing({super.key});
  @override
  State<Landing> createState() => _LandingState();
}

class _LandingState extends State<Landing> {
  final cc = TextEditingController();
  bool busy = false;

  Future<void> run(Future<void> Function() f) async {
    setState(() => busy = true);
    try {
      await f();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> orgDialog() async {
    final em = TextEditingController(), pw = TextEditingController();
    await showDialog(
        context: context,
        builder: (d) => AlertDialog(
              title: const Text('Cuenta de organizador'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: em,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email')),
                TextField(
                    controller: pw,
                    obscureText: true,
                    decoration: const InputDecoration(
                        labelText: 'Contraseña (mín. 6 caracteres)')),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(d),
                    child: const Text('Cancelar')),
                TextButton(
                    onPressed: () {
                      Navigator.pop(d);
                      run(() => comp.signInOrg(em.text.trim(), pw.text,
                          register: true));
                    },
                    child: const Text('Crear cuenta')),
                FilledButton(
                    onPressed: () {
                      Navigator.pop(d);
                      run(() => comp.signInOrg(em.text.trim(), pw.text));
                    },
                    child: const Text('Entrar')),
              ],
            ));
  }

  Future<void> join(String code) => run(() async {
        if (!await comp.join(code) && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('No existe ninguna competición con ese código.')));
        }
      });

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('🤺 Competición de esgrima')),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: ListView(
                    padding: const EdgeInsets.all(24),
                    shrinkWrap: true,
                    children: [
                      if (comp.lastCode != null) ...[
                        FilledButton.tonal(
                            onPressed: busy ? null : () => join(comp.lastCode!),
                            child: Text('Continuar con ${comp.lastCode}')),
                        const SizedBox(height: 16),
                      ],
                      if (comp.isLoggedOrg)
                        Row(children: [
                          Expanded(
                              child: Text('Organizador: ${comp.email}',
                                  overflow: TextOverflow.ellipsis)),
                          TextButton(
                              onPressed:
                                  busy ? null : () => run(comp.signOutOrg),
                              child: const Text('Cerrar sesión')),
                        ])
                      else
                        OutlinedButton(
                            onPressed: busy ? null : orgDialog,
                            child:
                                const Text('Soy organizador: iniciar sesión')),
                      const SizedBox(height: 8),
                      FilledButton(
                          onPressed: busy || !comp.isLoggedOrg
                              ? null
                              : () => run(comp.create),
                          child: const Text('Crear competición')),
                      const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Divider()),
                      TextField(
                          controller: cc,
                          textCapitalization: TextCapitalization.characters,
                          maxLength: 5,
                          decoration: const InputDecoration(
                              labelText: 'Código de la competición',
                              border: OutlineInputBorder())),
                      OutlinedButton(
                          onPressed: busy ? null : () => join(cc.text),
                          child: const Text('Unirme como participante')),
                      if (busy)
                        const Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: LinearProgressIndicator()),
                    ]))),
      );
}

/* ===================== PARTE 1: PARTICIPANTES ===================== */

class SetupView extends StatefulWidget {
  const SetupView({super.key});
  @override
  State<SetupView> createState() => _SetupState();
}

class _SetupState extends State<SetupView> {
  final nn = TextEditingController();
  int lvl = 5;

  void add() {
    final n = nn.text.trim();
    if (n.isEmpty) return;
    comp.addPlayer(n, lvl);
    nn.clear();
  }

  @override
  Widget build(BuildContext context) {
    final n = comp.players.length;
    if (!comp.isOrg) {
      return ListView(padding: const EdgeInsets.all(12), children: [
        card(
            'Participantes ($n)',
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('El organizador está preparando la competición…'),
              const SizedBox(height: 8),
              for (final p in comp.players) Text('• ${p.name}'),
            ])),
      ]);
    }
    final k = n == 0 ? 0 : (n / comp.max).ceil();
    return ListView(padding: const EdgeInsets.all(12), children: [
      card(
          '1 · Participantes',
          Column(children: [
            Text('Código para los participantes: ${comp.code}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: TextField(
                      controller: nn,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                          hintText: 'Nombre',
                          border: OutlineInputBorder(),
                          isDense: true),
                      onSubmitted: (_) => add())),
              const SizedBox(width: 8),
              DropdownButton<int>(
                  value: lvl,
                  items: [
                    for (var i = 1; i <= 10; i++)
                      DropdownMenuItem(value: i, child: Text('Nv. $i'))
                  ],
                  onChanged: (v) => setState(() => lvl = v!)),
              IconButton.filled(onPressed: add, icon: const Icon(Icons.add)),
            ]),
            Row(children: [
              const Expanded(child: Text('Máx. tiradores por poule')),
              IconButton(
                  onPressed: comp.max > 2
                      ? () {
                          comp.max--;
                          comp.save();
                        }
                      : null,
                  icon: const Icon(Icons.remove)),
              Text('${comp.max}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              IconButton(
                  onPressed: comp.max < 20
                      ? () {
                          comp.max++;
                          comp.save();
                        }
                      : null,
                  icon: const Icon(Icons.add)),
            ]),
          ])),
      for (final p in comp.players)
        Card(
            child: ExpansionTile(
          key: PageStorageKey(p.id),
          title: Text(p.name),
          subtitle: Text(
              'Nivel ${p.lvl} · No quiere: ${p.avoid.isEmpty ? 'nadie' : p.avoid.length}'),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          children: [
            Row(children: [
              const Text('Nivel'),
              Expanded(
                  child: Slider(
                      value: p.lvl.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      label: '${p.lvl}',
                      onChanged: (v) {
                        p.lvl = v.round();
                        comp.refresh();
                      },
                      onChangeEnd: (_) => comp.save())),
            ]),
            if (comp.players.length > 1) ...[
              const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('No quiere que le toque:')),
              Wrap(spacing: 6, children: [
                for (final o in comp.players.where((o) => o.id != p.id))
                  FilterChip(
                      label: Text(o.name),
                      selected: p.avoid.contains(o.id),
                      onSelected: (s) {
                        s ? p.avoid.add(o.id) : p.avoid.remove(o.id);
                        comp.save();
                      }),
              ]),
            ],
            Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                    onPressed: () => comp.delPlayer(p.id),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Eliminar'))),
          ],
        )),
      const SizedBox(height: 8),
      Text('$n tiradores → $k poule${k == 1 ? '' : 's'}',
          textAlign: TextAlign.center),
      const SizedBox(height: 8),
      FilledButton(
          onPressed: n >= 2
              ? () {
                  comp.gen();
                  comp.phase = 'poules';
                  comp.save();
                }
              : null,
          child: const Text('Generar Poule')),
    ]);
  }
}

/* ===================== PARTE 2: POULES ===================== */

class PoulesView extends StatelessWidget {
  const PoulesView({super.key});
  @override
  Widget build(BuildContext context) {
    final multi = comp.poules.length > 1, org = comp.isOrg;
    return ListView(padding: const EdgeInsets.all(12), children: [
      card(
          '2 · Poules',
          Text(!org
              ? 'El organizador está ajustando las poules…'
              : multi
                  ? 'Niveles equilibrados. Usa el icono ⇄ para mover a un tirador a otra poule.'
                  : 'Una única poule con todos los tiradores.')),
      for (var pi = 0; pi < comp.poules.length; pi++)
        Builder(builder: (c) {
          final ids = comp.poules[pi];
          final sum = ids.fold<int>(0, (s, i) => s + (comp.P(i)?.lvl ?? 0));
          return card(
              'Poule ${pi + 1}',
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                    '${ids.length} tiradores · nivel total $sum · media ${(sum / ids.length).toStringAsFixed(1)}',
                    style: Theme.of(c).textTheme.bodySmall),
                for (final id in ids)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Row(children: [
                      Flexible(child: Text('${nm(id)} (${comp.P(id)?.lvl})')),
                      if (ids.any(
                          (o) => o != id && comp.conf(comp.P(id)!, comp.P(o)!)))
                        const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(Icons.warning_amber,
                                size: 16, color: Colors.orange)),
                    ]),
                    trailing: (multi && org)
                        ? PopupMenuButton<int>(
                            icon: const Icon(Icons.swap_horiz),
                            tooltip: 'Mover a otra poule',
                            onSelected: (j) => comp.move(id, j),
                            itemBuilder: (_) => [
                                  for (var j = 0; j < comp.poules.length; j++)
                                    if (j != pi)
                                      PopupMenuItem(
                                          value: j,
                                          child: Text('Mover a Poule ${j + 1}'))
                                ])
                        : null,
                  ),
              ]));
        }),
      if (org)
        Row(children: [
          OutlinedButton(
              onPressed: () {
                comp.phase = 'setup';
                comp.save();
              },
              child: const Text('← Volver')),
          const SizedBox(width: 8),
          OutlinedButton(
              onPressed: () {
                comp.gen();
                comp.save();
              },
              child: const Text('Regenerar')),
          const Spacer(),
          FilledButton(
              onPressed: () {
                comp.res = {};
                comp.phase = 'play';
                comp.save(results: true);
              },
              child: const Text('Empezar')),
        ]),
    ]);
  }
}

/* ===================== PARTE 3: HOJA DE POULE ===================== */

class ScoreDialog extends StatefulWidget {
  final String a, b;
  final int? ia, ib;
  final int
      cap; // tocados para ganar por defecto: 5 en poule, 15 en eliminatorias
  final bool
      editTarget; // en eliminatorias se puede cambiar (1 a 15) en cada combate
  final bool existing;
  const ScoreDialog(
      {super.key,
      required this.a,
      required this.b,
      this.ia,
      this.ib,
      required this.cap,
      this.editTarget = false,
      required this.existing});
  @override
  State<ScoreDialog> createState() => _SDState();
}

class _SDState extends State<ScoreDialog> {
  String? w; // ganador
  int lp = 0; // tocados del perdedor
  late int target =
      widget.cap; // tocados necesarios para ganar (= puntos del ganador)

  @override
  void initState() {
    super.initState();
    final ia = widget.ia, ib = widget.ib;
    if (ia != null && ib != null) {
      w = ia > ib ? widget.a : widget.b;
      target = max(ia, ib);
      lp = min(ia > ib ? ib : ia, target - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loser = w == null ? null : (w == widget.a ? widget.b : widget.a);
    return AlertDialog(
      title: Text('Combate a $target tocados'),
      content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.editTarget) ...[
              Row(children: [
                const Expanded(child: Text('Tocados para ganar')),
                IconButton(
                    onPressed: target > 1
                        ? () => setState(() {
                              target--;
                              lp = min(lp, target - 1);
                            })
                        : null,
                    icon: const Icon(Icons.remove_circle_outline)),
                SizedBox(
                    width: 32,
                    child: Text('$target',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold))),
                IconButton(
                    onPressed:
                        target < 15 ? () => setState(() => target++) : null,
                    icon: const Icon(Icons.add_circle_outline)),
              ]),
              const SizedBox(height: 8),
            ],
            const Text('¿Quién ha ganado?'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final id in [widget.a, widget.b])
                ChoiceChip(
                    label: Text(nm(id)),
                    selected: w == id,
                    onSelected: (_) => setState(() => w = id)),
            ]),
            if (loser != null) ...[
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: Text('Tocados de ${nm(loser)}')),
                IconButton(
                    onPressed: lp > 0 ? () => setState(() => lp--) : null,
                    icon: const Icon(Icons.remove_circle_outline)),
                SizedBox(
                    width: 32,
                    child: Text('$lp',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold))),
                IconButton(
                    onPressed:
                        lp < target - 1 ? () => setState(() => lp++) : null,
                    icon: const Icon(Icons.add_circle_outline)),
              ]),
              Text('Resultado: ${nm(w)} $target – $lp ${nm(loser)}',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        if (widget.existing)
          TextButton(
              onPressed: () => Navigator.pop(context, <int>[]),
              child: const Text('Borrar')),
        FilledButton(
            onPressed: w == null
                ? null
                : () => Navigator.pop(
                    context, w == widget.a ? [target, lp] : [lp, target]),
            child: const Text('Guardar')),
      ],
    );
  }
}

Future<void> editBout(BuildContext c,
    {required String a, required String b, String? bkey}) async {
  final bracket = bkey != null;
  final r = bracket ? comp.br[bkey] : comp.res[comp.key(a, b)];
  final out = await showDialog<List<int>>(
      context: c,
      builder: (_) => ScoreDialog(
          a: a,
          b: b,
          ia: r?[a],
          ib: r?[b],
          cap: bracket ? 15 : 5,
          editTarget: bracket,
          existing: r != null));
  if (out == null) return;
  comp.setResult(bracket, bkey ?? comp.key(a, b),
      out.isEmpty ? null : {a: out[0], b: out[1]});
}

/// Hoja (matriz) + clasificación de una poule. La victoria se marca con "V".
class PouleTables extends StatelessWidget {
  final int pi;
  final bool showClass;
  const PouleTables(this.pi, {this.showClass = false, super.key});

  String cell(String a, String b) {
    final r = comp.res[comp.key(a, b)];
    if (r == null) return '';
    return r[a]! > r[b]! ? 'V' : '${r[a]}';
  }

  @override
  Widget build(BuildContext context) {
    final ids = comp.poules[pi], st = comp.stats(ids);
    const bold = TextStyle(fontWeight: FontWeight.bold);
    final sheet = DataTable(columnSpacing: 14, columns: [
      const DataColumn(label: Text('Tirador')),
      for (var i = 0; i < ids.length; i++) DataColumn(label: Text('${i + 1}')),
      const DataColumn(label: Text('V')),
    ], rows: [
      for (var i = 0; i < ids.length; i++)
        DataRow(cells: [
          DataCell(Text('${i + 1}. ${nm(ids[i])}')),
          for (final b in ids)
            DataCell(ids[i] == b
                ? Container(width: 22, height: 22, color: Colors.black12)
                : Text(cell(ids[i], b),
                    style: cell(ids[i], b) == 'V' ? bold : null)),
          DataCell(Text('${st[ids[i]]!.v}', style: bold)),
        ]),
    ]);
    final cls = comp.rank(ids);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      card(
          'Hoja de poule ${pi + 1}',
          SingleChildScrollView(
              scrollDirection: Axis.horizontal, child: sheet)),
      if (showClass)
        card(
            'Clasificación',
            SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(columnSpacing: 16, columns: const [
                  DataColumn(label: Text('Posición')),
                  DataColumn(label: Text('Tirador')),
                  DataColumn(label: Text('Victorias')),
                  DataColumn(label: Text('Tocados dados')),
                  DataColumn(label: Text('Tocados recibidos')),
                ], rows: [
                  for (final o in cls)
                    DataRow(cells: [
                      DataCell(Text('${o.pos}')),
                      DataCell(Text(nm(o.id))),
                      DataCell(Text('${o.v}')),
                      DataCell(Text('${o.td}')),
                      DataCell(Text('${o.tr}')),
                    ])
                ]))),
    ]);
  }
}

class PlayView extends StatefulWidget {
  const PlayView({super.key});
  @override
  State<PlayView> createState() => _PlayState();
}

class _PlayState extends State<PlayView> {
  int pi = 0;
  bool cls = false, init = false;

  @override
  Widget build(BuildContext context) {
    final n = comp.poules.length;
    if (!init && comp.me != null) {
      final j = comp.poules.indexWhere((g) => g.contains(comp.me));
      if (j >= 0) pi = j;
      init = true;
    }
    final cur = min(pi, n - 1);
    final ids = comp.poules[cur], bouts = comp.order(ids);
    final done =
        bouts.where((b) => comp.res[comp.key(b[0], b[1])] != null).length;
    final scheme = Theme.of(context).colorScheme;
    return ListView(padding: const EdgeInsets.all(12), children: [
      if (!comp.isOrg)
        card(
            '¿Quién eres?',
            DropdownButton<String>(
              isExpanded: true,
              value: comp.players.any((p) => p.id == comp.me) ? comp.me : null,
              hint: const Text('Selecciona tu nombre'),
              items: [
                for (var j = 0; j < n; j++)
                  for (final id in comp.poules[j])
                    DropdownMenuItem(
                        value: id, child: Text('${nm(id)}  ·  Poule ${j + 1}'))
              ],
              onChanged: (v) {
                comp.setMe(v);
                final j = comp.poules.indexWhere((g) => g.contains(v));
                if (j >= 0) setState(() => pi = j);
              },
            )),
      Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (n > 1)
              for (var j = 0; j < n; j++)
                ChoiceChip(
                    label: Text('Poule ${j + 1}'),
                    selected: j == cur,
                    onSelected: (_) => setState(() => pi = j)),
            FilterChip(
                label: const Text('Clasificación'),
                selected: cls,
                onSelected: (v) => setState(() => cls = v)),
            if (comp.isOrg)
              FilledButton(
                  onPressed: () async {
                    final p = comp.pendingBouts();
                    if (p > 0 &&
                        !await ask(context,
                            'Faltan $p combates por jugar. ¿Finalizar las poules igualmente?'))
                      return;
                    comp.finishPoules();
                  },
                  child: const Text('Finalizar poules')),
          ]),
      const SizedBox(height: 12),
      PouleTables(cur, showClass: cls),
      card(
          'Orden de combates · $done/${bouts.length}',
          Column(children: [
            for (var i = 0; i < bouts.length; i++)
              Builder(builder: (c) {
                final a = bouts[i][0],
                    b = bouts[i][1],
                    r = comp.res[comp.key(a, b)];
                final mine = comp.me != null && (a == comp.me || b == comp.me);
                String t = 'Pendiente';
                if (r != null)
                  t = '${r[a]! > r[b]! ? 'V' : r[a]} – ${r[b]! > r[a]! ? 'V' : r[b]}';
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                  tileColor: mine ? scheme.primaryContainer : null,
                  title: Text('${i + 1}. ${nm(a)} vs ${nm(b)}',
                      style:
                          TextStyle(fontWeight: mine ? FontWeight.bold : null)),
                  trailing: Text(t,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: r != null ? Colors.green : null)),
                  onTap: () => editBout(c, a: a, b: b),
                );
              }),
          ])),
    ]);
  }
}

/* ===================== PARTE 4: ELIMINATORIAS ===================== */

class PoulesResultPage extends StatelessWidget {
  const PoulesResultPage({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: comp,
      builder: (context, _) {
        final n = comp.poules.length;
        Widget page(int i) => ListView(
            padding: const EdgeInsets.all(12),
            children: [PouleTables(i, showClass: true)]);
        if (n == 1)
          return Scaffold(
              appBar: AppBar(title: const Text('Poule final')), body: page(0));
        return DefaultTabController(
            length: n,
            child: Scaffold(
                appBar: AppBar(
                    title: const Text('Poules finalizadas'),
                    bottom: TabBar(isScrollable: true, tabs: [
                      for (var i = 0; i < n; i++) Tab(text: 'Poule ${i + 1}')
                    ])),
                body: TabBarView(
                    children: [for (var i = 0; i < n; i++) page(i)])));
      });
}

class BracketView extends StatefulWidget {
  const BracketView({super.key});
  @override
  State<BracketView> createState() => _BracketState();
}

class _BracketState extends State<BracketView> {
  final ctrl = ScrollController();

  void seePoules() => Navigator.push(
      context, MaterialPageRoute(builder: (_) => const PoulesResultPage()));

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  Widget seeding() {
    final g = comp.gRank(), s = comp.seeds, org = comp.isOrg;
    return ListView(padding: const EdgeInsets.all(12), children: [
      card(
          '4 · Clasificación general',
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(org
                ? 'Por victorias, luego tocados dados − recibidos; en empate dentro de la misma poule, su posición. Los empates entre poules distintas (⚠) se ordenan a mano con las flechas.'
                : 'Esperando a que el organizador genere la tabla de eliminatorias…'),
            for (var i = 0; i < s.length; i++)
              Builder(builder: (c) {
                final o = g.firstWhere((e) => e.s.id == s[i]);
                final nx = i + 1 < s.length
                    ? g.firstWhere((e) => e.s.id == s[i + 1])
                    : null;
                final tie = nx != null &&
                    o.s.v == nx.s.v &&
                    o.s.td - o.s.tr == nx.s.td - nx.s.tr &&
                    o.pi != nx.pi;
                final d = o.s.td - o.s.tr;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${i + 1}. ${nm(s[i])}'),
                  subtitle: Text(
                      '${o.s.v}V · ${d > 0 ? '+' : ''}$d · Poule ${o.pi + 1}${tie ? '  ⚠ empate con el siguiente' : ''}'),
                  trailing: org
                      ? Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                              onPressed: i > 0
                                  ? () {
                                      final t = s[i];
                                      s[i] = s[i - 1];
                                      s[i - 1] = t;
                                      comp.save();
                                    }
                                  : null,
                              icon: const Icon(Icons.arrow_upward)),
                          IconButton(
                              onPressed: i < s.length - 1
                                  ? () {
                                      final t = s[i];
                                      s[i] = s[i + 1];
                                      s[i + 1] = t;
                                      comp.save();
                                    }
                                  : null,
                              icon: const Icon(Icons.arrow_downward)),
                        ])
                      : null,
                );
              }),
          ])),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (org)
          OutlinedButton(
              onPressed: () {
                comp.phase = 'play';
                comp.save();
              },
              child: const Text('← Volver a las poules')),
        OutlinedButton.icon(
            onPressed: seePoules,
            icon: const Icon(Icons.grid_on),
            label: const Text('Ver poules')),
        if (org)
          FilledButton(
              onPressed: () {
                comp.seeded = true;
                comp.br = {};
                comp.save(results: true);
              },
              child: const Text('Generar eliminatorias')),
      ]),
    ]);
  }

  String label(int sz, int r) {
    final n = sz >> r;
    return switch (n) {
      2 => 'Final',
      4 => 'Semifinales',
      8 => 'Cuartos',
      16 => 'Octavos',
      _ => 'Ronda de $n'
    };
  }

  Widget matchCard(int r, int i) {
    final p = comp.parts(r, i);
    final bye = p.contains('BYE');
    final res = comp.br['$r-$i'];
    final w = comp.winner(r, i);
    final mine = comp.me != null && p.contains(comp.me);
    Widget line(String? x) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(children: [
          Expanded(
              child: Text(nm(x),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight:
                          w != null && w == x && !bye ? FontWeight.bold : null,
                      color:
                          w != null && w == x && !bye ? Colors.green : null))),
          if (res != null && x != null && x != 'BYE' && res[x] != null)
            Text('${res[x]}'),
        ]));
    final canTap = !bye && p[0] != null && p[1] != null;
    return Opacity(
        opacity: bye ? .5 : 1,
        child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            shape: mine
                ? RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                        color: Theme.of(context).colorScheme.primary, width: 2))
                : null,
            child: InkWell(
                onTap: canTap
                    ? () => editBout(context, a: p[0]!, b: p[1]!, bkey: '$r-$i')
                    : null,
                child: Column(children: [
                  line(p[0]),
                  const Divider(height: 1),
                  line(p[1])
                ]))));
  }

  @override
  Widget build(BuildContext context) {
    if (!comp.seeded) return seeding();
    final sz = comp.sizeB, R = (log(sz) / ln2).round();
    const slot = 100.0;
    final ch = comp.winner(R - 1, 0);
    void go(double to) => ctrl.animateTo(to,
        duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    return ListView(padding: const EdgeInsets.all(12), children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton.icon(
            onPressed: () => go(0),
            icon: const Icon(Icons.first_page),
            label: const Text('Ir al principio')),
        OutlinedButton.icon(
            onPressed: () => go(ctrl.position.maxScrollExtent),
            icon: const Icon(Icons.last_page),
            label: const Text('Ir a la final')),
        OutlinedButton.icon(
            onPressed: seePoules,
            icon: const Icon(Icons.grid_on),
            label: const Text('Ver poules')),
      ]),
      const SizedBox(height: 8),
      if (ch != null)
        card(
            '🏆 Campeón',
            Text(nm(ch),
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold))),
      SingleChildScrollView(
          controller: ctrl,
          scrollDirection: Axis.horizontal,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var r = 0; r < R; r++)
              SizedBox(
                  width: 190,
                  child: Column(children: [
                    Text(label(sz, r),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(
                        height: slot * (sz >> 1),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              for (var i = 0; i < sz >> (r + 1); i++)
                                matchCard(r, i)
                            ])),
                  ])),
          ])),
      const SizedBox(height: 8),
      const Text(
          'Toca un combate para anotar el resultado. Los BYE pasan directamente a la siguiente ronda.'),
    ]);
  }
}
