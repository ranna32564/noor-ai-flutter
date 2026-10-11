import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

const forest = Color(0xFF123B2C);
const emerald = Color(0xFF1E5B43);
const ivory = Color(0xFFF8F6EF);
const gold = Color(0xFFD8B56A);
const ink = Color(0xFF172820);
const muted = Color(0xFF78847C);
const apiBase = String.fromEnvironment('NOOR_API_BASE_URL', defaultValue: 'http://10.0.2.2:3000');

void main() => runApp(const NoorApp());

class NoorApp extends StatefulWidget {
  const NoorApp({super.key});
  @override State<NoorApp> createState() => _NoorAppState();
}
class _NoorAppState extends State<NoorApp> {
  bool bn = true;
  @override void initState() { super.initState(); SharedPreferences.getInstance().then((p) { if (mounted) setState(() => bn = p.getBool('noor_bn') ?? true); }); }
  void setLanguage(bool value) async { final p = await SharedPreferences.getInstance(); await p.setBool('noor_bn', value); if (mounted) setState(() => bn = value); }
  @override Widget build(BuildContext context) => MaterialApp(
    title: 'Noor AI', debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, scaffoldBackgroundColor: ivory,
      colorScheme: ColorScheme.fromSeed(seedColor: forest, primary: forest, surface: ivory),
      appBarTheme: const AppBarTheme(backgroundColor: ivory, foregroundColor: ink, elevation: 0, centerTitle: false),
      cardTheme: CardThemeData(color: Colors.white, elevation: 0.7, margin: const EdgeInsets.only(bottom: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
      navigationBarTheme: const NavigationBarThemeData(backgroundColor: Colors.white, indicatorColor: Color(0xFFE5EEE8), labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
    ),
    home: HomeShell(bn: bn, onLanguage: setLanguage),
  );
}

class HomeShell extends StatefulWidget {
  final bool bn; final ValueChanged<bool> onLanguage;
  const HomeShell({super.key, required this.bn, required this.onLanguage});
  @override State<HomeShell> createState() => _HomeShellState();
}
class _HomeShellState extends State<HomeShell> {
  int tab = 0;
  @override Widget build(BuildContext context) {
    final labels = widget.bn ? ['হোম','কুরআন','নূর AI','লাইব্রেরি','সেটিংস'] : ['Home','Quran','Ask Noor','Library','Settings'];
    return Scaffold(
      body: IndexedStack(index: tab, children: [
        PrayerPage(bn: widget.bn), QuranPage(bn: widget.bn), ChatPage(bn: widget.bn),
        LibraryPage(bn: widget.bn), SettingsPage(bn: widget.bn, onLanguage: widget.onLanguage),
      ]),
      bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (v) => setState(() => tab = v), destinations: [
        NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: labels[0]),
        NavigationDestination(icon: const Icon(Icons.menu_book_outlined), selectedIcon: const Icon(Icons.menu_book), label: labels[1]),
        NavigationDestination(icon: const Icon(Icons.auto_awesome_outlined), selectedIcon: const Icon(Icons.auto_awesome), label: labels[2]),
        NavigationDestination(icon: const Icon(Icons.bookmarks_outlined), selectedIcon: const Icon(Icons.bookmarks), label: labels[3]),
        NavigationDestination(icon: const Icon(Icons.tune_outlined), selectedIcon: const Icon(Icons.tune), label: labels[4]),
      ]),
    );
  }
}

Widget pageTitle(String title, String subtitle, {Widget? trailing}) => Padding(
  padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
  child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: ink, letterSpacing: -.5)),
    const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: muted, fontSize: 13)),
  ])), if (trailing != null) trailing]),
);
Widget premiumCard({required Widget child, Color color = Colors.white, EdgeInsets padding = const EdgeInsets.all(18)}) =>
  Container(width: double.infinity, padding: padding, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(22), boxShadow: const [BoxShadow(color: Color(0x0A172820), blurRadius: 18, offset: Offset(0, 5))]), child: child);
String tr(bool bn, String b, String e) => bn ? b : e;

class PrayerPage extends StatefulWidget {
  final bool bn; const PrayerPage({super.key, required this.bn});
  @override State<PrayerPage> createState() => _PrayerPageState();
}
class _PrayerPageState extends State<PrayerPage> {
  Timer? ticker; DateTime now = DateTime.now(); Map<String, DateTime> times = {}; String? error; bool hanafi = true; int method = 1; final Map<String,int> offsets = {};
  static const names = ['Fajr','Dhuhr','Asr','Maghrib','Isha'];
  @override void initState() { super.initState(); loadSettings(); ticker = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() => now = DateTime.now()); }); }
  @override void dispose() { ticker?.cancel(); super.dispose(); }
  Future<void> loadSettings() async { final p = await SharedPreferences.getInstance(); hanafi = p.getBool('noor_hanafi') ?? true; method = p.getInt('noor_method') ?? 1; for (final n in names) { offsets[n] = p.getInt('offset_$n') ?? 0; } await calculate(); }
  Future<void> calculate() async {
    try {
      final p = await SharedPreferences.getInstance();
      final lat = p.getDouble('noor_lat') ?? 26.3411; final lon = p.getDouble('noor_lon') ?? 88.5541;
      final c = Coordinates(lat, lon);
      final params = (method == 0 ? CalculationMethod.karachi : method == 1 ? CalculationMethod.muslim_world_league : CalculationMethod.egyptian).getParameters()
        ..madhab = hanafi ? Madhab.hanafi : Madhab.shafi;
      final d = DateComponents.from(now);
      final pt = PrayerTimes(c, d, params);
      final vals = <String,DateTime>{'Fajr':pt.fajr,'Dhuhr':pt.dhuhr,'Asr':pt.asr,'Maghrib':pt.maghrib,'Isha':pt.isha};
      for (final n in names) { vals[n] = vals[n]!.add(Duration(minutes: offsets[n] ?? 0)); }
      if (mounted) setState(() { times = vals; error = null; });
    } catch (_) { if (mounted) setState(() => error = tr(widget.bn,'নামাজের সময় গণনা করা যায়নি। সেটিংস পরীক্ষা করুন।','Could not calculate prayer times. Check settings.')); }
  }
  MapEntry<String,DateTime>? get next {
    for (final n in names) { final t = times[n]; if (t != null && t.isAfter(now)) return MapEntry(n,t); }
    if (times.isEmpty) return null;
    final tomorrow = DateTime(now.year,now.month,now.day+1);
    final c = Coordinates(26.3411,88.5541);
    final p = (method == 0 ? CalculationMethod.karachi : method == 1 ? CalculationMethod.muslim_world_league : CalculationMethod.egyptian).getParameters()..madhab = hanafi ? Madhab.hanafi : Madhab.shafi;
    return MapEntry('Fajr', PrayerTimes(c,DateComponents.from(tomorrow),p).fajr);
  }
  String countdown(DateTime t) { final d=t.difference(now); if (d.isNegative) return '--:--:--'; String two(int n)=>n.toString().padLeft(2,'0'); return '${two(d.inHours)}:${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}'; }
  Future<void> openPrayerSettings() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    await showModalBottomSheet(context: context, isScrollControlled: true, builder: (ctx) => StatefulBuilder(builder: (ctx, update) => Padding(
      padding: EdgeInsets.fromLTRB(20,20,20,MediaQuery.of(ctx).viewInsets.bottom+24),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr(widget.bn,'নামাজের সময় সেটিংস','Prayer time settings'),style: const TextStyle(fontSize:21,fontWeight:FontWeight.bold)),
        const SizedBox(height:12), Text(tr(widget.bn,'হিসাব পদ্ধতি','Calculation method')),
        DropdownButton<int>(value:method, isExpanded:true, items:[DropdownMenuItem(value:0,child:Text(tr(widget.bn,'করাচি (দক্ষিণ এশিয়া)','Karachi (South Asia)'))),DropdownMenuItem(value:1,child:const Text('Muslim World League')),DropdownMenuItem(value:2,child:const Text('Egyptian General Authority'))],onChanged:(v){if(v!=null)update(()=>method=v);}),
        SwitchListTile(contentPadding:EdgeInsets.zero,title:Text(tr(widget.bn,'হানাফি আসর','Hanafi Asr')),value:hanafi,onChanged:(v)=>update(()=>hanafi=v)),
        const Text('Manual adjustments (minutes)',style:TextStyle(fontWeight:FontWeight.w600)),
        ...names.map((n)=>Row(children:[Expanded(child:Text(n)),IconButton(onPressed:()=>update(()=>offsets[n]=(offsets[n]??0)-1),icon:const Icon(Icons.remove_circle_outline)),Text('${offsets[n]??0}',style:const TextStyle(fontWeight:FontWeight.bold)),IconButton(onPressed:()=>update(()=>offsets[n]=(offsets[n]??0)+1),icon:const Icon(Icons.add_circle_outline))])),
        FilledButton(onPressed:() async {await p.setBool('noor_hanafi',hanafi);await p.setInt('noor_method',method);for(final n in names){await p.setInt('offset_$n',offsets[n]??0);}if(ctx.mounted)Navigator.pop(ctx);await calculate();},child:Text(tr(widget.bn,'সেভ করুন','Save settings'))),
      ])),
    )));
  }
  @override Widget build(BuildContext context) {
    final nx = next;
    return SafeArea(child: RefreshIndicator(onRefresh:calculate, child: ListView(padding: const EdgeInsets.only(bottom:24), children: [
      pageTitle('Noor AI', tr(widget.bn,'পঞ্চগড়, বাংলাদেশ','Panchagarh, Bangladesh'), trailing: IconButton(onPressed:openPrayerSettings,icon:const Icon(Icons.tune))),
      Padding(padding: const EdgeInsets.symmetric(horizontal:16), child: premiumCard(color:forest, child: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Row(children:[Icon(Icons.nights_stay_outlined,color:gold,size:27),SizedBox(width:8),Text('Assalamu Alaikum',style:TextStyle(color:Colors.white70))]),
        const SizedBox(height:16),Text(tr(widget.bn,'পরবর্তী নামাজ','UPCOMING PRAYER'),style:const TextStyle(color:gold,fontSize:11,letterSpacing:1.6,fontWeight:FontWeight.bold)),
        const SizedBox(height:4),Text(nx?.key ?? '—',style:const TextStyle(color:Colors.white,fontSize:29,fontWeight:FontWeight.w800)),
        Text(nx == null ? '--:--' : DateFormat.jm().format(nx.value),style:const TextStyle(color:Colors.white70,fontSize:16)),
        const SizedBox(height:14),Text(nx == null ? '—' : countdown(nx.value),style:const TextStyle(color:gold,fontSize:34,fontWeight:FontWeight.w700,letterSpacing:1.3)),
        const SizedBox(height:8),Text(tr(widget.bn,'স্থানীয় মসজিদের সময়ের সঙ্গে মিলিয়ে নিন।','Calculated locally; compare with your local mosque timetable.'),style:const TextStyle(color:Colors.white70,fontSize:12)),
      ]))),
      Padding(padding:const EdgeInsets.fromLTRB(20,22,20,10),child:Row(children:[Expanded(child:Text(tr(widget.bn,'আজকের নামাজের সময়','Today’s prayer times'),style:const TextStyle(fontSize:19,fontWeight:FontWeight.w800))),IconButton(onPressed:calculate,icon:const Icon(Icons.refresh))])),
      if(error!=null) Padding(padding:const EdgeInsets.symmetric(horizontal:18),child:Text(error!,style:const TextStyle(color:Colors.red))),
      ...names.map((n){final t=times[n];final isNext=nx?.key==n;return Padding(padding:const EdgeInsets.symmetric(horizontal:16,vertical:4),child:premiumCard(padding:const EdgeInsets.symmetric(horizontal:16,vertical:13),child:Row(children:[Container(width:42,height:42,decoration:BoxDecoration(color:isNext?forest:const Color(0xFFE9EFE9),borderRadius:BorderRadius.circular(14)),child:Icon(Icons.mosque_outlined,color:isNext?gold:forest)),const SizedBox(width:12),Expanded(child:Text(n,style:TextStyle(fontWeight:isNext?FontWeight.w800:FontWeight.w600,fontSize:16))),Text(t==null?'--:--':DateFormat.jm().format(t),style:TextStyle(fontSize:16,fontWeight:FontWeight.bold,color:isNext?forest:ink))])));}),
      Padding(padding:const EdgeInsets.all(20),child:Text(tr(widget.bn,'হিসাব: স্থানীয়ভাবে গণনা করা সময়। পঞ্চগড়ের আনুমানিক স্থানাঙ্ক ও নির্বাচিত পদ্ধতি ব্যবহৃত। অফিসিয়াল মসজিদের লাইভ সময় নয়।','Method: locally calculated using approximate Panchagarh coordinates and your selected method. Not official/live mosque timings.'),style:const TextStyle(fontSize:12,color:muted))),
    ])));
  }
}

class QuranPage extends StatefulWidget { final bool bn; const QuranPage({super.key,required this.bn}); @override State<QuranPage> createState()=>_QuranPageState(); }
class _QuranPageState extends State<QuranPage> {
  List<dynamic> surahs=[]; bool loading=true; String query='';
  @override void didChangeDependencies(){super.didChangeDependencies();if(surahs.isEmpty&&loading)load();}
  Future<void> load()async{try{final s=await DefaultAssetBundle.of(context).loadString('assets/data/quran.json');final d=jsonDecode(s) as List<dynamic>;if(mounted)setState(()=>surahs=d);}catch(_){ }finally{if(mounted)setState(()=>loading=false);}}
  @override Widget build(BuildContext context){
    final q=query.toLowerCase().trim();
    final items=surahs.where((s){if(q.isEmpty)return true;return '${s['t']} ${s['bn']} ${s['en']} ${s['ar']} ${s['n']}'.toLowerCase().contains(q) || (s['v'] as List).any((v)=>'${v[0]} ${v[1]} ${v[2]}'.toLowerCase().contains(q));}).toList();
    return SafeArea(child:Column(children:[
      pageTitle(tr(widget.bn,'আল-কুরআন','The Quran'),tr(widget.bn,'আরবি, বাংলা ও ইংরেজি অর্থসহ অফলাইন পাঠ','Offline reading with Arabic, Bangla and English meanings')),
      Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:TextField(onChanged:(v)=>setState(()=>query=v),decoration:InputDecoration(prefixIcon:const Icon(Icons.search),hintText:tr(widget.bn,'সূরা, আয়াত বা শব্দ খুঁজুন','Search surah, ayah or keyword'),suffixIcon:query.isEmpty?null:IconButton(onPressed:()=>setState(()=>query=''),icon:const Icon(Icons.close))))),
      const SizedBox(height:10),
      Expanded(child:loading?const Center(child:CircularProgressIndicator()):items.isEmpty?Center(child:Text(tr(widget.bn,'কোনো ফলাফল পাওয়া যায়নি','No results found'))):ListView.builder(padding:const EdgeInsets.all(16),itemCount:items.length,itemBuilder:(ctx,i){final s=items[i] as Map<String,dynamic>;return Card(child:ListTile(leading:Container(width:42,height:42,decoration:BoxDecoration(color:const Color(0xFFE7EFE8),borderRadius:BorderRadius.circular(14)),alignment:Alignment.center,child:Text('${s['n']}',style:const TextStyle(color:forest,fontWeight:FontWeight.bold))),title:Text(widget.bn?'${s['t']} · ${s['bn']}':'${s['t']} · ${s['en']}',style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:Text('${(s['v'] as List).length} ayahs'),trailing:Text('${s['ar']}',textDirection:TextDirection.rtl,style:const TextStyle(fontSize:19)),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>SurahReader(surah:s,bn:widget.bn)))));})),
    ]));
  }
}
class SurahReader extends StatelessWidget {
  final Map<String,dynamic> surah;final bool bn;const SurahReader({super.key,required this.surah,required this.bn});
  @override Widget build(BuildContext context){final verses=surah['v'] as List<dynamic>;return Scaffold(appBar:AppBar(title:Text('${surah['t']} · ${surah['bn']}')),body:ListView.builder(padding:const EdgeInsets.all(16),itemCount:verses.length,itemBuilder:(c,i){final v=verses[i] as List<dynamic>;return premiumCard(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Text('${surah['n']}:${i+1}',style:const TextStyle(color:emerald,fontWeight:FontWeight.bold)),const SizedBox(height:12),Text('${v[0]}',textDirection:TextDirection.rtl,textAlign:TextAlign.right,style:const TextStyle(fontSize:27,height:1.9,fontFamily:'serif')),const SizedBox(height:10),Text('${bn?v[1]:v[2]}',style:const TextStyle(fontSize:15,height:1.7,color:ink)),Align(alignment:Alignment.centerRight,child:IconButton(onPressed:()async{final p=await SharedPreferences.getInstance();final key='${surah['n']}:${i+1}';final l=p.getStringList('noor_favorites')??[];if(!l.contains(key))l.add(key);await p.setStringList('noor_favorites',l);if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(tr(bn,'আয়াতটি পছন্দে রাখা হয়েছে','Ayah added to favorites'))));},icon:const Icon(Icons.bookmark_add_outlined,color:emerald))) ]),padding:const EdgeInsets.all(16));}));}
}

class ChatPage extends StatefulWidget { final bool bn;const ChatPage({super.key,required this.bn});@override State<ChatPage> createState()=>_ChatPageState(); }
class ChatMsg { final bool user;final String text;final String? image;ChatMsg(this.user,this.text,{this.image}); }
class _ChatPageState extends State<ChatPage> {
  final input=TextEditingController();final scroll=ScrollController();final picker=ImagePicker();final List<ChatMsg> msgs=[];XFile? image;bool busy=false;
  @override void initState(){super.initState();loadHistory();}
  Future<void> loadHistory() async {try{final p=await SharedPreferences.getInstance();final raw=p.getString('noor_chat_history');if(raw==null)return;final data=jsonDecode(raw) as List;if(mounted)setState(()=>msgs.addAll(data.map((x)=>ChatMsg(x['user']==true,'${x['text']??''}',image:x['image'] as String?))));}catch(_){}}
  Future<void> saveHistory() async {try{final p=await SharedPreferences.getInstance();await p.setString('noor_chat_history',jsonEncode(msgs.map((m)=>{'user':m.user,'text':m.text,'image':m.image}).toList()));}catch(_){}}
  @override void dispose(){input.dispose();scroll.dispose();super.dispose();}
  Future<void> pick()async{try{final x=await picker.pickImage(source:ImageSource.gallery,imageQuality:80,maxWidth:1600);if(x!=null)setState(()=>image=x);}catch(_){if(mounted)showMessage(tr(widget.bn,'ছবি নেওয়া যায়নি। অনুমতি পরীক্ষা করুন।','Could not pick image. Check photo permission.'));}}
  void showMessage(String s)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));
  Future<void> send()async{
    final q=input.text.trim();if((q.isEmpty&&image==null)||busy)return;
    final im=image;setState((){msgs.add(ChatMsg(true,q.isEmpty?tr(widget.bn,'ছবির জন্য ইসলামিক ক্যাপশন চাই','Please write an Islamic caption for this photo'):q,image:im?.path));input.clear();image=null;busy=true;});
    try{
      final p=await SharedPreferences.getInstance();final provider=p.getString('noor_provider')??'gemini';final key=p.getString('noor_key_$provider')??'';final model=p.getString('noor_model_$provider')??(provider=='gemini'?'gemini-2.5-flash':'openrouter/auto');
      if(key.isEmpty)throw Exception(tr(widget.bn,'সেটিংসে গিয়ে Gemini বা OpenRouter API key যোগ করুন।','Add a Gemini or OpenRouter API key in Settings first.'));
      String answer;
      const systemPrompt='You are Noor AI, an Islamic-only assistant. Politely decline unrelated requests. Never fabricate Quran text, Arabic religious text, hadith, references, grades or scholarly quotes. State uncertainty; note legitimate scholarly differences. For complex rulings advise a qualified scholar. Do not label an unknown ingredient Haram simply because it is absent from a database. For choking, breathing trouble or severe illness advise urgent medical help first. If image provided, create a respectful Islamic-style caption without inventing scripture.';
      final userPrompt=q.isEmpty?'Write a respectful Islamic social-media caption for this image.':q;
      String? b64;String mime='image/jpeg';if(im!=null){b64=base64Encode(await im.readAsBytes());mime=im.mimeType??(im.path.toLowerCase().endsWith('.png')?'image/png':'image/jpeg');}
      if(provider=='gemini'){
        final parts=<Map<String,dynamic>>[{'text':userPrompt}];if(b64!=null)parts.add({'inline_data':{'mime_type':mime,'data':b64}});
        final r=await http.post(Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/${Uri.encodeComponent(model)}:generateContent'),headers:{'content-type':'application/json','x-goog-api-key':key},body:jsonEncode({'systemInstruction':{'parts':[{'text':'$systemPrompt Answer in ${widget.bn?'Bangla':'the user’s language'}.'}]},'contents':[{'role':'user','parts':parts}],'generationConfig':{'temperature':0.25,'maxOutputTokens':1200}})).timeout(const Duration(seconds:60));
        final j=jsonDecode(r.body);if(r.statusCode<200||r.statusCode>=300)throw Exception(providerError(j,r.statusCode));answer=((j['candidates']?[0]?['content']?['parts'] as List? ?? []).map((x)=>x['text']??'').join('
')).trim();
      }else{
        final content=<Map<String,dynamic>>[{'type':'text','text':userPrompt}];if(b64!=null)content.add({'type':'image_url','image_url':{'url':'data:$mime;base64,$b64'}});
        final r=await http.post(Uri.parse('https://openrouter.ai/api/v1/chat/completions'),headers:{'content-type':'application/json','Authorization':'Bearer $key','HTTP-Referer':'https://noor-ai.app','X-Title':'Noor AI'},body:jsonEncode({'model':model,'messages':[{'role':'system','content':'$systemPrompt Answer in ${widget.bn?'Bangla':'the user’s language'}.'},{'role':'user','content':content}],'temperature':0.25})).timeout(const Duration(seconds:60));
        final j=jsonDecode(r.body);if(r.statusCode<200||r.statusCode>=300)throw Exception(providerError(j,r.statusCode));answer='${j['choices']?[0]?['message']?['content']??''}'.trim();
      }
      if(answer.isEmpty)throw Exception(tr(widget.bn,'AI কোনো উত্তর দেয়নি।','The provider returned an empty answer.'));
      if(mounted){setState(()=>msgs.add(ChatMsg(false,answer)));await saveHistory();}
    }catch(e){if(mounted){setState(()=>msgs.add(ChatMsg(false,'${tr(widget.bn,'অনুরোধ সম্পন্ন হয়নি: ','Request failed: ')}${e.toString().replaceFirst('Exception: ','')}')));await saveHistory();}}
    finally{if(mounted)setState(()=>busy=false);WidgetsBinding.instance.addPostFrameCallback((_){if(scroll.hasClients)scroll.animateTo(scroll.position.maxScrollExtent,duration:const Duration(milliseconds:250),curve:Curves.easeOut);});}
  }
  String providerError(dynamic j,int status){final m=j is Map?(j['error'] is Map?j['error']['message']:j['error']):null;return '${m??'HTTP $status'}';}
  @override Widget build(BuildContext context)=>SafeArea(child:Column(children:[
    pageTitle(tr(widget.bn,'Ask Noor AI','Ask Noor AI'),tr(widget.bn,'ইসলামিক প্রশ্ন, দোয়া ও ছবির ক্যাপশন','Islamic questions, duas and image captions'),trailing:IconButton(tooltip:'New chat',onPressed:()async{setState(()=>msgs.clear());final p=await SharedPreferences.getInstance();await p.remove('noor_chat_history');},icon:const Icon(Icons.add_comment_outlined))),
    if(msgs.isEmpty)Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:premiumCard(color:forest,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Icon(Icons.auto_awesome,color:gold,size:28),const SizedBox(height:10),Text(tr(widget.bn,'কী জানতে চাও?','How can I help?'),style:const TextStyle(color:Colors.white,fontSize:23,fontWeight:FontWeight.bold)),const SizedBox(height:6),Text(tr(widget.bn,'দোয়া, কুরআন, নামাজ, হালাল-হারাম বা একটি ছবি দিয়ে ইসলামিক ক্যাপশন চাও।','Ask about duas, Quran, salah, halal/haram or request a caption for a photo.'),style:const TextStyle(color:Colors.white70,height:1.5))]))),
    if(msgs.isEmpty)Padding(padding:const EdgeInsets.all(14),child:Wrap(spacing:8,runSpacing:8,children:[tr(widget.bn,'খাওয়ার দোয়া','Dua before eating'),tr(widget.bn,'রুকু ও সিজদা','Ruku and sujood'),tr(widget.bn,'জ্বর হলে কী করব?','What to do for fever?'),tr(widget.bn,'হালাল খাবার','Halal food')].map((s)=>ActionChip(label:Text(s),onPressed:()=>setState(()=>input.text=s)).toList()))),
    Expanded(child:ListView.builder(controller:scroll,padding:const EdgeInsets.all(14),itemCount:msgs.length,itemBuilder:(c,i){final m=msgs[i];return Align(alignment:m.user?Alignment.centerRight:Alignment.centerLeft,child:Container(constraints:BoxConstraints(maxWidth:MediaQuery.of(c).size.width*.86),margin:const EdgeInsets.only(bottom:10),padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:m.user?const Color(0xFFE3ECE5):Colors.white,borderRadius:BorderRadius.circular(18)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[if(m.image!=null)ClipRRect(borderRadius:BorderRadius.circular(12),child:Image.file(File(m.image!),height:160,width:230,fit:BoxFit.cover)),SelectableText(m.text,style:const TextStyle(height:1.5,color:ink)),if(!m.user)Align(alignment:Alignment.centerRight,child:IconButton(tooltip:'Copy',onPressed:()=>Clipboard.setData(ClipboardData(text:m.text)).then((_)=>showMessage(tr(widget.bn,'উত্তর কপি হয়েছে','Answer copied'))),icon:const Icon(Icons.copy_outlined,size:18))) ])));})),
    if(busy)const LinearProgressIndicator(minHeight:2),
    if(image!=null)Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:Row(children:[const Icon(Icons.image,color:emerald),Expanded(child:Text(image!.name,maxLines:1,overflow:TextOverflow.ellipsis)),IconButton(onPressed:()=>setState(()=>image=null),icon:const Icon(Icons.close))])),
    Padding(padding:const EdgeInsets.fromLTRB(12,6,12,12),child:Row(crossAxisAlignment:CrossAxisAlignment.end,children:[IconButton(onPressed:busy?null:pick,tooltip:'Attach image',icon:const Icon(Icons.add_photo_alternate_outlined,color:forest)),Expanded(child:TextField(controller:input,minLines:1,maxLines:4,onSubmitted:(_)=>send(),decoration:InputDecoration(hintText:tr(widget.bn,'ইসলাম সম্পর্কে প্রশ্ন করুন…','Ask an Islamic question…')))),const SizedBox(width:8),IconButton.filled(onPressed:busy?null:send,style:IconButton.styleFrom(backgroundColor:forest),icon:const Icon(Icons.arrow_upward))])),
  ]));
}

class LibraryPage extends StatefulWidget { final bool bn;const LibraryPage({super.key,required this.bn});@override State<LibraryPage> createState()=>_LibraryPageState(); }
class _LibraryPageState extends State<LibraryPage> {
  List<dynamic> duas=[];List<dynamic> adhkar=[];List<dynamic> titles=[];Map<String,dynamic> guide={};bool loading=true;String query='';int mode=0;
  @override void didChangeDependencies(){super.didChangeDependencies();if(loading&&duas.isEmpty)load();}
  Future<void> load()async{try{final b=DefaultAssetBundle.of(context);final d=jsonDecode(await b.loadString('assets/data/duas.json')) as List;final a=jsonDecode(await b.loadString('assets/data/adhkar.json')) as List;final t=jsonDecode(await b.loadString('assets/data/titles.json')) as List;final g=jsonDecode(await b.loadString('assets/data/guide.json')) as Map<String,dynamic>;if(mounted)setState(() { duas=d; adhkar=a; titles=t; guide=g; });}catch(_){}finally{if(mounted)setState(()=>loading=false);}}
  @override Widget build(BuildContext context){
    final list=<Map<String,dynamic>>[];
    if(mode==0){for(final d in duas){if(query.isEmpty||'${d['bn']} ${d['en']} ${d['kw']} ${d['bnM']} ${d['enM']}'.toLowerCase().contains(query.toLowerCase()))list.add(Map<String,dynamic>.from(d));}}
    else if(mode==5){for(final cat in adhkar){final id=(cat['id'] as num).toInt();final title=titles.length>=id?titles[id-1] as Map<String,dynamic>:{'bn':'যিকির বিভাগ $id','en':'Adhkar category $id'};final items=cat['i'] as List? ?? [];for(final entry in items){final ar='${entry['t']??''}';final hay='${title['bn']} ${title['en']} $ar'.toLowerCase();if(query.isEmpty||hay.contains(query.toLowerCase()))list.add({'bn':title['bn'],'en':title['en'],'ar':ar,'count':entry['c'],'src':'Hisn al-Muslim category $id'});}}}
    else {final group=mode==1?'foodHalal':mode==2?'foodHaram':mode==3?'actHalal':'actHaram';final all=(guide['HALAL'] as Map?)?[group] as List? ?? [];for(final x in all){if(query.isEmpty||'${x['bn']} ${x['en']}'.toLowerCase().contains(query.toLowerCase()))list.add(Map<String,dynamic>.from(x));}}
    return SafeArea(child:Column(children:[
      pageTitle(tr(widget.bn,'ইসলামিক লাইব্রেরি','Islamic Library'),tr(widget.bn,'দোয়া, যিকির ও প্রাথমিক হালাল-হারাম গাইড','Duas, adhkar and introductory halal/haram guide')),
      Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:TextField(onChanged:(v)=>setState(()=>query=v),decoration:InputDecoration(prefixIcon:const Icon(Icons.search),hintText:tr(widget.bn,'দোয়া বা বিষয় খুঁজুন','Search dua or topic')))),
      SizedBox(height:54,child:ListView(scrollDirection:Axis.horizontal,padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),children:[
        _filter(0,tr(widget.bn,'দোয়া','Duas')), _filter(5,tr(widget.bn,'যিকির','Adhkar')), _filter(1,tr(widget.bn,'হালাল খাবার','Halal food')), _filter(2,tr(widget.bn,'হারাম খাবার','Haram food')), _filter(3,tr(widget.bn,'হালাল কাজ','Halal actions')), _filter(4,tr(widget.bn,'হারাম কাজ','Haram actions')),
      ])),
      Expanded(child:loading?const Center(child:CircularProgressIndicator()):list.isEmpty?Center(child:Text(tr(widget.bn,'কোনো ফলাফল নেই','No results'))):ListView.builder(padding:const EdgeInsets.fromLTRB(16,4,16,20),itemCount:list.length,itemBuilder:(c,i){final d=list[i];return premiumCard(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Text('${widget.bn?d['bn']:d['en']}',style:const TextStyle(fontSize:17,fontWeight:FontWeight.bold,color:forest)),
        if((mode==0||mode==5)&&'${d['ar']??''}'.isNotEmpty)Padding(padding:const EdgeInsets.symmetric(vertical:12),child:Text('${d['ar']}',textDirection:TextDirection.rtl,textAlign:TextAlign.right,style:const TextStyle(fontSize:25,height:1.9))),
        if(mode==0)Text('${widget.bn?d['bnM']:d['enM']}',style:const TextStyle(height:1.5)),
        if(mode==5)Text('${tr(widget.bn,'পড়ার সংখ্যা','Repeat count')}: ${d['count']??1}',style:const TextStyle(color:muted,fontSize:12)),
        if(mode==0||mode==5)Padding(padding:const EdgeInsets.only(top:8),child:Text('${tr(widget.bn,'সূত্র/বিভাগ','Source/category')}: ${d['src']??tr(widget.bn,'সূত্র উল্লেখ নেই','Source not listed')}',style:const TextStyle(fontSize:12,color:muted))),
        if(mode!=0)Text(tr(widget.bn,'সাধারণ নির্দেশনা; পরিস্থিতি ও আলেমদের মতভেদ থাকতে পারে।','General guidance; context and scholarly differences may apply.'),style:const TextStyle(color:muted,fontSize:12)),
        if(d['ref']!=null)Text('Quran references: ${(d['ref'] as List).map((x)=>'${x[0]}:${x[1]}${x[2]==x[1]?'':'-${x[2]}'}').join(', ')}',style:const TextStyle(fontSize:12,color:muted)),
      ]));})),
      Padding(padding:const EdgeInsets.fromLTRB(16,0,16,8),child:Text(tr(widget.bn,'এই লাইব্রেরি প্রাথমিক অফলাইন কনটেন্ট; সব দোয়া/হাদিসের পূর্ণাঙ্গ বা চূড়ান্ত যাচাইকৃত তালিকা নয়।','This is an introductory offline library, not an exhaustive or fully scholar-reviewed corpus.'),style:const TextStyle(fontSize:11,color:muted))),
    ]));
  }
  Widget _filter(int i,String label)=>Padding(padding:const EdgeInsets.symmetric(horizontal:4),child:ChoiceChip(label:Text(label),selected:mode==i,onSelected:(_)=>setState(()=>mode=i),selectedColor:const Color(0xFFDDE9DF)));
}

class SettingsPage extends StatefulWidget { final bool bn;final ValueChanged<bool> onLanguage;const SettingsPage({super.key,required this.bn,required this.onLanguage});@override State<SettingsPage> createState()=>_SettingsPageState(); }
class _SettingsPageState extends State<SettingsPage> {
  String provider='gemini';final keys={'gemini':'','openrouter':''};final models={'gemini':'gemini-2.5-flash','openrouter':'openrouter/auto'};final controllers={'gemini':TextEditingController(),'openrouter':TextEditingController()};final visible={'gemini':false,'openrouter':false};final status={'gemini':'Not tested','openrouter':'Not tested'};final busy={'gemini':false,'openrouter':false};
  @override void initState(){super.initState();load();}
  @override void dispose(){for(final c in controllers.values){c.dispose();}super.dispose();}
  Future<void> load()async{final p=await SharedPreferences.getInstance();if(!mounted)return;setState((){provider=p.getString('noor_provider')??'gemini';for(final k in keys.keys){keys[k]=p.getString('noor_key_$k')??'';models[k]=p.getString('noor_model_$k')??models[k]!;controllers[k]!.text=keys[k]!;}});}
  Future<void> save(String k)async{final v=controllers[k]!.text.trim();if(v.isEmpty){message(tr(widget.bn,'API key ফাঁকা রাখা যাবে না।','API key cannot be empty.'));return;}final p=await SharedPreferences.getInstance();await p.setString('noor_key_$k',v);setState(()=>keys[k]=v);message(tr(widget.bn,'Key এই ডিভাইসে সেভ হয়েছে। এটি সংযোগ সফল হওয়ার প্রমাণ নয়।','Key saved on this device. This does not mean the connection succeeded.'));}
  Future<void> clear(String k)async{final yes=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text(tr(widget.bn,'API key মুছবেন?','Clear API key?')),content:Text(tr(widget.bn,'এই provider-এর সংরক্ষিত key মুছে যাবে।','The saved key for this provider will be deleted.')),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:Text(tr(widget.bn,'বাতিল','Cancel'))),FilledButton(onPressed:()=>Navigator.pop(c,true),child:Text(tr(widget.bn,'মুছুন','Clear')))]));if(yes!=true)return;final p=await SharedPreferences.getInstance();await p.remove('noor_key_$k');controllers[k]!.clear();setState(() { keys[k]=''; status[k]='Not tested'; });message(tr(widget.bn,'Key মুছে ফেলা হয়েছে।','Key cleared.'));}
  void message(String s)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));
  Future<void> test(String k)async{final key=controllers[k]!.text.trim().isNotEmpty?controllers[k]!.text.trim():keys[k]!;if(key.isEmpty){setState(()=>status[k]='FAILED · missing key');message(tr(widget.bn,'প্রথমে API key লিখুন।','Enter an API key first.'));return;}setState(() { busy[k]=true; status[k]='Testing…'; });try{http.Response r;if(k=='gemini'){r=await http.post(Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/${models[k]}:generateContent'),headers:{'content-type':'application/json','x-goog-api-key':key},body:jsonEncode({'contents':[{'parts':[{'text':'Reply with exactly: Noor AI connection test OK'}]}],'generationConfig':{'maxOutputTokens':20}})).timeout(const Duration(seconds:25));}else{r=await http.post(Uri.parse('https://openrouter.ai/api/v1/chat/completions'),headers:{'content-type':'application/json','Authorization':'Bearer $key','X-Title':'Noor AI'},body:jsonEncode({'model':models[k],'messages':[{'role':'user','content':'Reply with exactly: Noor AI connection test OK'}],'max_tokens':20})).timeout(const Duration(seconds:25));}final body=jsonDecode(r.body);if(r.statusCode>=200&&r.statusCode<300){final valid=k=='gemini'?(body['candidates'] is List&&(body['candidates'] as List).isNotEmpty):(body['choices'] is List&&(body['choices'] as List).isNotEmpty);if(!valid)throw Exception('Provider returned no valid response');if(mounted)setState(()=>status[k]='SUCCESS · live response received');}else{final err=body is Map?(body['error'] is Map?body['error']['message']:body['error']):null;throw Exception('HTTP ${r.statusCode}: ${err??'request failed'}');}}catch(e){if(mounted)setState(()=>status[k]='FAILED · ${e.toString().replaceFirst('Exception: ','')}');}finally{if(mounted)setState(()=>busy[k]=false);}}
  Future<void> activate(String k)async{if(keys[k]!.isEmpty){message(tr(widget.bn,'এই provider-এর key আগে সেভ করুন।','Save this provider key first.'));return;}final p=await SharedPreferences.getInstance();await p.setString('noor_provider',k);await p.setString('noor_model_$k',models[k]!);setState(()=>provider=k);message(tr(widget.bn,'Active provider বদলেছে।','Active provider changed.'));}
  @override Widget build(BuildContext context)=>SafeArea(child:ListView(padding:const EdgeInsets.only(bottom:24),children:[
    pageTitle(tr(widget.bn,'সেটিংস','Settings'),tr(widget.bn,'ভাষা, AI সংযোগ ও অ্যাপ পছন্দ','Language, AI connections and preferences')),
    Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:premiumCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(tr(widget.bn,'অ্যাপের ভাষা','App language'),style:const TextStyle(fontSize:17,fontWeight:FontWeight.bold)),const SizedBox(height:8),
      SegmentedButton<bool>(segments:const [ButtonSegment(value:true,label:Text('বাংলা')),ButtonSegment(value:false,label:Text('English'))],selected:{widget.bn},onSelectionChanged:(s)=>widget.onLanguage(s.first)),
    ]))),
    Padding(padding:const EdgeInsets.fromLTRB(16,10,16,6),child:Text(tr(widget.bn,'AI API সংযোগ কেন্দ্র','AI API connection center'),style:const TextStyle(fontSize:21,fontWeight:FontWeight.w800))),
    Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:premiumCard(color:const Color(0xFFFFF5DC),child:Text(tr(widget.bn,'নিরাপত্তা: API key এই ডিভাইসে SharedPreferences-এ রাখা হয়, যা production-এর জন্য নিরাপদ secret storage নয়। ব্যক্তিগত পরীক্ষার জন্যই ব্যবহার করুন। প্রকাশ্য অ্যাপের ক্ষেত্রে authenticated HTTPS backend ও server-side secrets ব্যবহার করুন।','Security: API keys are stored on this device using SharedPreferences, which is not secure secret storage for production. Use for personal development only. Public apps should use an authenticated HTTPS backend with server-side secrets.'),style:const TextStyle(fontSize:12,height:1.5,color:ink)))),
    for(final k in ['gemini','openrouter']) Padding(padding:const EdgeInsets.fromLTRB(16,8,16,4),child:premiumCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Container(width:44,height:44,decoration:BoxDecoration(color:const Color(0xFFE6EEE7),borderRadius:BorderRadius.circular(14)),child:Icon(k=='gemini'?Icons.auto_awesome:Icons.hub_outlined,color:forest)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(k=='gemini'?'Google Gemini':'OpenRouter',style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),Text(keys[k]!.isEmpty?tr(widget.bn,'Key সংরক্ষিত নেই','No key saved'):tr(widget.bn,'Key সংরক্ষিত','Key saved'),style:const TextStyle(color:muted,fontSize:12))])),if(provider==k)const Chip(label:Text('ACTIVE'),visualDensity:VisualDensity.compact)]),
      const SizedBox(height:12),TextField(controller:controllers[k],obscureText:!visible[k]!,autocorrect:false,enableSuggestions:false,decoration:InputDecoration(labelText:'${k=='gemini'?'Gemini':'OpenRouter'} API key',hintText:k=='gemini'?'AIza…':'sk-or-v1-…',suffixIcon:IconButton(onPressed:()=>setState(()=>visible[k]=!visible[k]!),icon:Icon(visible[k]! ? Icons.visibility_off : Icons.visibility)))),
      const SizedBox(height:10),TextFormField(initialValue:models[k],decoration:const InputDecoration(labelText:'Model ID'),onChanged:(v)=>models[k]=v.trim()),
      const SizedBox(height:10),Text(status[k]!,style:TextStyle(fontSize:12,color:status[k]!.startsWith('SUCCESS')?forest:status[k]!.startsWith('FAILED')?Colors.red:muted)),
      const SizedBox(height:8),Wrap(spacing:8,runSpacing:8,children:[
        OutlinedButton.icon(onPressed:busy[k]!?null:()=>save(k),icon:const Icon(Icons.save_outlined),label:Text(tr(widget.bn,'Key সেভ','Save key'))),
        OutlinedButton.icon(onPressed:busy[k]!?null:()=>test(k),icon:busy[k]!?const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.network_check),label:Text(tr(widget.bn,'সংযোগ পরীক্ষা','Test connection'))),
        FilledButton.icon(onPressed:()=>activate(k),icon:const Icon(Icons.check_circle_outline),label:Text(tr(widget.bn,'সক্রিয় করুন','Activate'))),
        TextButton.icon(onPressed:()=>clear(k),icon:const Icon(Icons.delete_outline),label:Text(tr(widget.bn,'Key মুছুন','Clear key'))),
      ]),
    ]))),
    Padding(padding:const EdgeInsets.symmetric(horizontal:20,vertical:10),child:Text(tr(widget.bn,'Gemini ও OpenRouter আলাদাভাবে পরীক্ষা হয়। সফল ফলাফল মানে provider থেকে বাস্তব HTTP response এসেছে। Model ID provider অনুযায়ী বদলাতে পারেন।','Gemini and OpenRouter are tested independently. SUCCESS means a real HTTP response was received. You can change the model ID for each provider.'),style:const TextStyle(color:muted,fontSize:12,height:1.5))),
    Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:premiumCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(tr(widget.bn,'নামাজের সময়','Prayer times'),style:const TextStyle(fontSize:17,fontWeight:FontWeight.bold)),const SizedBox(height:5),Text(tr(widget.bn,'পঞ্চগড়ের আনুমানিক স্থানাঙ্ক: 26.3411, 88.5541 · Asia/Dhaka (ফোনের স্থানীয় সময় ব্যবহৃত)। স্থানীয় মসজিদের সময়ের সঙ্গে যাচাই করুন।','Approximate Panchagarh coordinates: 26.3411, 88.5541 · Asia/Dhaka (uses device local time). Verify with your local mosque.'))] ))),
  ]));
}
