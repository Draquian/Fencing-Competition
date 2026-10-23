import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Player {
  String id, name;
  int lvl;
  Set<String> avoid;
  Player(this.id, this.name, this.lvl, [Set<String>? a]) : avoid = a ?? {};
  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'lvl': lvl, 'avoid': avoid.toList()};
  factory Player.fromJson(Map j) =>
      Player(j['id'], j['name'], j['lvl'], Set<String>.from(j['avoid']));
}

class Stat {
  final String id;
  int v = 0, td = 0, tr = 0, pos = 0;
  Stat(this.id);
}

class GStat {
  final Stat s;
  final int pi;
  GStat(this.s, this.pi);
}

class Comp extends ChangeNotifier {
  // ---------- estado de la competición (sincronizado en Firestore) ----------
  String phase = 'setup'; // setup | poules | play | bracket
  int max = 7;
  List<Player> players = [];
  List<List<String>> poules = [];
  Map<String, Map<String, int>> res = {}; // resultados de poule
  Map<String, Map<String, int>> br = {}; // resultados de eliminatorias
  List<String> seeds = [];
  bool seeded = false;

  // ---------- sesión local ----------
  String? code, lastCode, uid, me;
  bool isOrg = false, ready = false;
  DocumentReference<Map<String, dynamic>>? _ref;
  StreamSubscription? _sub;

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('competitions');

  Player? P(String id) {
    for (final p in players) {
      if (p.id == id) return p;
    }
    return null;
  }

  String key(String a, String b) => a.compareTo(b) < 0 ? '${a}_$b' : '${b}_$a';
  bool conf(Player a, Player b) =>
      a.avoid.contains(b.id) || b.avoid.contains(a.id);

  // ===================== FIREBASE =====================
  Future<void> init() async {
    final a = FirebaseAuth.instance;
    // Recupera la sesión guardada (organizador con email, o participante anónimo)
    var u = await a.authStateChanges().first;
    u ??= (await a.signInAnonymously()).user;
    uid = u!.uid;
    final sp = await SharedPreferences.getInstance();
    lastCode = sp.getString('code');
  }

  bool get isLoggedOrg => FirebaseAuth.instance.currentUser?.isAnonymous == false;
  String? get email => FirebaseAuth.instance.currentUser?.email;

  /// Cuenta de organizador (email + contraseña): su identidad sobrevive a reinstalaciones y cambios de móvil.
  Future<void> signInOrg(String e, String p, {bool register = false}) async {
    final a = FirebaseAuth.instance;
    final cred = register
        ? await a.createUserWithEmailAndPassword(email: e, password: p)
        : await a.signInWithEmailAndPassword(email: e, password: p);
    uid = cred.user!.uid;
    notifyListeners();
  }

  Future<void> signOutOrg() async {
    final a = FirebaseAuth.instance;
    await a.signOut();
    uid = (await a.signInAnonymously()).user!.uid;
    notifyListeners();
  }

  static const _alpha = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  Map<String, dynamic> _data({bool results = false}) => {
        'phase': phase,
        'max': max,
        'players': players.map((p) => p.toJson()).toList(),
        // Firestore no admite listas de listas: cada poule va en un mapa
        'poules': [for (final g in poules) {'ids': g}],
        'seeds': seeds,
        'seeded': seeded,
        if (results) 'res': res,
        if (results) 'br': br,
      };

  void _apply(Map<String, dynamic> d) {
    phase = d['phase'] ?? 'setup';
    max = d['max'] ?? 7;
    players = [for (final p in (d['players'] ?? [])) Player.fromJson(p)];
    poules = [for (final g in (d['poules'] ?? [])) List<String>.from(g['ids'])];
    seeds = List<String>.from(d['seeds'] ?? []);
    seeded = d['seeded'] ?? false;
    res = _m(d['res'] ?? {});
    br = _m(d['br'] ?? {});
  }

  Map<String, Map<String, int>> _m(Map j) =>
      j.map((k, v) => MapEntry(k as String, Map<String, int>.from(v)));

  void _clear() {
    phase = 'setup';
    max = 7;
    players = [];
    poules = [];
    res = {};
    br = {};
    seeds = [];
    seeded = false;
  }

  /// Crea una competición nueva; este dispositivo pasa a ser el organizador.
  Future<void> create() async {
    if (!isLoggedOrg) throw 'Inicia sesión como organizador para crear una competición.';
    final rnd = Random.secure();
    for (var t = 0; t < 5; t++) {
      final c = List.generate(5, (_) => _alpha[rnd.nextInt(_alpha.length)]).join();
      final ref = _col.doc(c);
      if ((await ref.get()).exists) continue;
      _clear();
      await ref.set({
        ..._data(results: true),
        'owner': uid,
        'created': FieldValue.serverTimestamp(),
      });
      await _attach(c);
      return;
    }
    throw 'No se pudo generar un código. Inténtalo de nuevo.';
  }

  /// Entra en una competición existente (como participante, o como organizador si es el creador).
  Future<bool> join(String c) async {
    c = c.trim().toUpperCase();
    if (c.isEmpty) return false;
    final s = await _col.doc(c).get();
    if (!s.exists) return false;
    await _attach(c);
    return true;
  }

  Future<void> _attach(String c) async {
    await _sub?.cancel();
    ready = false;
    code = c;
    _ref = _col.doc(c);
    final sp = await SharedPreferences.getInstance();
    sp.setString('code', c);
    lastCode = c;
    me = sp.getString('me_$c');
    _sub = _ref!.snapshots().listen((s) {
      if (!s.exists) return;
      final d = s.data()!;
      _apply(d);
      isOrg = d['owner'] == uid;
      ready = true;
      notifyListeners();
    }, onError: (_) {});
    notifyListeners();
  }

  Future<void> leave() async {
    await _sub?.cancel();
    _sub = null;
    _ref = null;
    code = null;
    ready = false;
    isOrg = false;
    me = null;
    _clear();
    final sp = await SharedPreferences.getInstance();
    sp.remove('code');
    lastCode = null;
    notifyListeners();
  }

  void refresh() => notifyListeners();

  Future<void> setMe(String? id) async {
    me = id;
    final sp = await SharedPreferences.getInstance();
    id == null ? sp.remove('me_$code') : sp.setString('me_$code', id);
    notifyListeners();
  }

  /// Solo el organizador. Escribe la estructura (y opcionalmente todos los resultados).
  Future<void> save({bool results = false}) async {
    notifyListeners();
    if (!isOrg || _ref == null) return;
    try {
      await _ref!.update(_data(results: results));
    } catch (_) {}
  }

  /// Cualquier participante puede anotar o borrar un resultado (escritura puntual).
  void setResult(bool bracket, String k, Map<String, int>? v) {
    final m = bracket ? br : res;
    v == null ? m.remove(k) : m[k] = v;
    notifyListeners();
    _ref
        ?.update({
          FieldPath([bracket ? 'br' : 'res', k]): v ?? FieldValue.delete()
        })
        .catchError((_) {});
  }

  // ===================== PARTICIPANTES =====================
  void addPlayer(String name, int lvl) {
    players.add(Player('p${DateTime.now().microsecondsSinceEpoch}', name, lvl));
    save();
  }

  void delPlayer(String id) {
    players.removeWhere((p) => p.id == id);
    for (final p in players) {
      p.avoid.remove(id);
    }
    save();
  }

  // ===================== POULES =====================
  void gen() {
    final n = players.length, k = (n / max).ceil();
    final caps = List.generate(k, (i) => n ~/ k + (i < n % k ? 1 : 0));
    final rnd = Random();
    List<List<String>>? best;
    double bs = 1e9;
    for (var t = 0; t < 80; t++) {
      final ks = {for (final p in players) p.id: p.lvl + rnd.nextDouble() * .9};
      final ps = [...players]..sort((a, b) => ks[b.id]!.compareTo(ks[a.id]!));
      final g = List.generate(k, (_) => <String>[]);
      final sum = List<int>.filled(k, 0);
      for (final p in ps) {
        var c = [
          for (var i = 0; i < k; i++)
            if (g[i].length < caps[i]) i
        ];
        final ok = c.where((i) => !g[i].any((q) => conf(p, P(q)!))).toList();
        if (ok.isNotEmpty) c = ok;
        final kk = {for (final i in c) i: sum[i] / caps[i] + rnd.nextDouble() * .01};
        c.sort((i, j) => kk[i]!.compareTo(kk[j]!));
        g[c[0]].add(p.id);
        sum[c[0]] += p.lvl;
      }
      final av = [for (var i = 0; i < k; i++) sum[i] / caps[i]];
      var cf = 0;
      for (final a in g) {
        for (var i = 0; i < a.length; i++) {
          for (var j = i + 1; j < a.length; j++) {
            if (conf(P(a[i])!, P(a[j])!)) cf++;
          }
        }
      }
      final sc = av.reduce((x, y) => x > y ? x : y) - av.reduce((x, y) => x < y ? x : y) + 100 * cf;
      if (sc < bs) {
        bs = sc;
        best = g;
      }
    }
    poules = best!;
  }

  void move(String id, int to) {
    for (final g in poules) {
      g.remove(id);
    }
    poules[to].add(id);
    poules.removeWhere((g) => g.isEmpty);
    save();
  }

  List<List<String>> order(List<String> ids) {
    final a = <String?>[...ids];
    if (a.length.isOdd) a.add(null);
    final n = a.length;
    final out = <List<String>>[];
    for (var r = 0; r < n - 1; r++) {
      for (var i = 0; i < n ~/ 2; i++) {
        final x = a[i], y = a[n - 1 - i];
        if (x != null && y != null) out.add([x, y]);
      }
      a.insert(1, a.removeLast());
    }
    return out;
  }

  Map<String, Stat> stats(List<String> ids) {
    final st = {for (final i in ids) i: Stat(i)};
    for (var x = 0; x < ids.length; x++) {
      for (var y = x + 1; y < ids.length; y++) {
        final a = ids[x], b = ids[y], r = res[key(a, b)];
        if (r == null || r[a] == null || r[b] == null) continue;
        st[a]!.td += r[a]!;
        st[a]!.tr += r[b]!;
        st[b]!.td += r[b]!;
        st[b]!.tr += r[a]!;
        st[r[a]! > r[b]! ? a : b]!.v++;
      }
    }
    return st;
  }

  int h2h(String a, String b) {
    final r = res[key(a, b)];
    return r == null ? 0 : r[b]! - r[a]!;
  }

  List<Stat> rank(List<String> ids) {
    final st = stats(ids);
    final l = ids.map((i) => st[i]!).toList();
    l.sort((p, q) {
      var d = q.v - p.v;
      if (d != 0) return d;
      d = (q.td - q.tr) - (p.td - p.tr);
      if (d != 0) return d;
      return h2h(p.id, q.id);
    });
    for (var i = 0; i < l.length; i++) {
      l[i].pos = i + 1;
    }
    return l;
  }

  int pendingBouts() {
    var n = 0;
    for (final g in poules) {
      for (final b in order(g)) {
        if (res[key(b[0], b[1])] == null) n++;
      }
    }
    return n;
  }

  // ===================== ELIMINATORIAS =====================
  List<GStat> gRank() {
    final all = <GStat>[];
    for (var pi = 0; pi < poules.length; pi++) {
      for (final s in rank(poules[pi])) {
        all.add(GStat(s, pi));
      }
    }
    all.sort((a, b) {
      var d = b.s.v - a.s.v;
      if (d != 0) return d;
      d = (b.s.td - b.s.tr) - (a.s.td - a.s.tr);
      if (d != 0) return d;
      return a.pi == b.pi ? a.s.pos - b.s.pos : 0;
    });
    return all;
  }

  void finishPoules() {
    seeds = gRank().map((e) => e.s.id).toList();
    seeded = false;
    br = {};
    phase = 'bracket';
    save(results: true);
  }

  int get sizeB {
    var s = 2;
    while (s < seeds.length) {
      s *= 2;
    }
    return s;
  }

  List<int> seedOrder(int sz) {
    var a = [1];
    while (a.length < sz) {
      final m = a.length * 2;
      a = [for (final s in a) ...[s, m + 1 - s]];
    }
    return a;
  }

  List<String?> parts(int r, int i) {
    if (r == 0) {
      final o = seedOrder(sizeB);
      String f(int s) => s > seeds.length ? 'BYE' : seeds[s - 1];
      return [f(o[2 * i]), f(o[2 * i + 1])];
    }
    return [winner(r - 1, 2 * i), winner(r - 1, 2 * i + 1)];
  }

  String? winner(int r, int i) {
    final p = parts(r, i);
    if (p[0] == 'BYE') return p[1];
    if (p[1] == 'BYE') return p[0];
    final x = br['$r-$i'];
    if (x == null || p[0] == null || p[1] == null) return null;
    final a = x[p[0]], b = x[p[1]];
    if (a == null || b == null) return null;
    return a > b ? p[0] : p[1];
  }

  /// Perdedor de un combate de eliminatoria (null si hay BYE o aún no está decidido).
  String? loser(int r, int i) {
    final p = parts(r, i), w = winner(r, i);
    if (w == null || p.contains('BYE')) return null;
    return p[0] == w ? p[1] : p[0];
  }

  void reset() {
    phase = 'setup';
    poules = [];
    res = {};
    br = {};
    seeds = [];
    seeded = false;
    save(results: true);
  }
}

final comp = Comp();
String nm(String? id) =>
    id == null ? '—' : (id == 'BYE' ? 'BYE' : (comp.P(id)?.name ?? '?').toUpperCase());
