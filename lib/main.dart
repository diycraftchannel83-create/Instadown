import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'pages/downloads_page.dart';
import 'pages/history_page.dart';
import 'pages/settings_page.dart';
void main(){WidgetsFlutterBinding.ensureInitialized();runApp(const InstaDownApp());}
class InstaDownApp extends StatelessWidget{const InstaDownApp({super.key});@override Widget build(BuildContext context)=>MaterialApp(title:'InstaDown',debugShowCheckedModeBanner:false,theme:ThemeData(colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xFFE1306C)),useMaterial3:true),darkTheme:ThemeData(colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xFFE1306C),brightness:Brightness.dark),useMaterial3:true),home:const MainShell());}
class MainShell extends StatefulWidget{const MainShell({super.key});@override State<MainShell> createState()=>_MainShellState();}
class _MainShellState extends State<MainShell>{int index=0;final pages=const[HomePage(),DownloadsPage(),HistoryPage(),SettingsPage()];@override Widget build(BuildContext context)=>Scaffold(body:IndexedStack(index:index,children:pages),bottomNavigationBar:NavigationBar(selectedIndex:index,onDestinationSelected:(v)=>setState(()=>index=v),destinations:const[NavigationDestination(icon:Icon(Icons.download_rounded),label:'Download'),NavigationDestination(icon:Icon(Icons.downloading_rounded),label:'Progress'),NavigationDestination(icon:Icon(Icons.history_rounded),label:'History'),NavigationDestination(icon:Icon(Icons.settings_rounded),label:'Settings')]));}
