import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/farmer_helper_prefs.dart';
import '../utils/farmer_guide_access.dart';

/// Poznati fallbacki za ključeve vodiča ako .tr() vrati sirovi string.
const kFarmerGuideFallbacks = <String, Map<String, String>>{
  'guide_search_title': {'hr': 'Pretraga', 'de': 'Suche', 'en': 'Search'},
  'guide_search_body': {
    'hr': 'Ovdje upišite naziv da brzo pronađete hranu, sjeme ili strojeve.',
    'de': 'Geben Sie hier einen Namen ein, um schnell Lebensmittel, Saatgut oder Maschinen zu finden.',
    'en': 'Type a name here to quickly find food, seeds, or machinery.',
  },
  'guide_radius_title': {'hr': 'Udaljenost farme', 'de': 'Suchradius', 'en': 'Search radius'},
  'guide_radius_body': {
    'hr': 'Izaberite udaljenost u kilometrima kako biste vidjeli samo proizvode u vašoj blizini.',
    'de': 'Wählen Sie die Entfernung in Kilometern, um nur Produkte in Ihrer Nähe zu sehen.',
    'en': 'Choose a distance in kilometres to see only nearby products.',
  },
  'guide_categories_title': {'hr': 'Kategorije', 'de': 'Kategorien', 'en': 'Categories'},
  'guide_categories_body': {
    'hr': 'Kliknite na neku od ovih ikona kako biste filtrirali ponudu prema vrsti poljoprivrede.',
    'de': 'Klicken Sie auf eines dieser Icons, um das Angebot nach der Art der Landwirtschaft zu filtern.',
    'en': 'Tap an icon to filter the offer by type of agriculture.',
  },
  'guide_type_title': {'hr': 'Način uzgoja', 'de': 'Anbaumethode', 'en': 'Growing method'},
  'guide_type_body': {
    'hr': 'Ovdje odaberite želite li vidjeti isključivo provjerene organske proizvode ili sve.',
    'de': 'Wählen Sie hier aus, ob Sie ausschließlich biologische Produkte oder alles sehen möchten.',
    'en': 'Choose whether to see only certified organic products or everything.',
  },
  'guide_grid_title': {'hr': 'Ponuda na tržnici', 'de': 'Marktplatz-Angebot', 'en': 'Marketplace offer'},
  'guide_grid_body': {
    'hr': 'Ovdje vidite sve dostupne proizvode s točnim cijenama i preračunatim valutama.',
    'de': 'Hier sehen Sie alle verfügbaren Produkte mit genauen Preisen und umgerechneten Währungen.',
    'en': 'Here you see all available products with exact prices and converted currencies.',
  },
  'forum_title': {'hr': 'Agro Forum', 'de': 'Agro-Forum', 'en': 'Agro Forum'},
  'forum_empty_category': {
    'hr': 'Nema tema u ovoj kategoriji.',
    'de': 'Keine Themen in dieser Kategorie.',
    'en': 'No topics in this category.',
  },
  'forum_cat_greenhouse': {'hr': 'Plastenici', 'de': 'Gewächshäuser', 'en': 'Greenhouses', 'pl': 'Szklarnie', 'sv': 'Växthus'},
  'forum_cat_fruit': {'hr': 'Voćarstvo', 'de': 'Obstbau', 'en': 'Fruit growing', 'pl': 'Sadownictwo', 'sv': 'Fruktodling'},
  'forum_cat_vegetables': {'hr': 'Ratarstvo', 'de': 'Ackerbau', 'en': 'Field crops', 'pl': 'Uprawy polowe', 'sv': 'Fältgrödor'},
  'forum_cat_livestock': {'hr': 'Stočarstvo', 'de': 'Viehzucht', 'en': 'Livestock', 'pl': 'Hodowla zwierząt', 'sv': 'Djurhållning'},
  'forum_cat_machinery': {'hr': 'Mehanizacija', 'de': 'Maschinen', 'en': 'Mechanization', 'pl': 'Mechanizacja', 'sv': 'Mekanisering'},
  'guide_forum_categories_title': {
    'hr': 'Kategorije foruma',
    'de': 'Forum-Kategorien',
    'en': 'Forum categories',
    'pl': 'Kategorie forum',
  },
  'guide_forum_categories_body': {
    'hr': 'Izaberite temu (Plastenici, Voćarstvo, Ratarstvo...) kako biste vidjeli pitanja i savjete kolega.',
    'de': 'Wählen Sie ein Thema, um Fragen und Ratschläge von Kollegen zu sehen.',
    'en': 'Pick a topic to see questions and advice from fellow farmers.',
    'pl': 'Wybierz temat (Szklarnie, Sadownictwo, Uprawy polowe...), aby zobaczyć pytania i porady innych rolników.',
  },
  'guide_forum_add_title': {
    'hr': 'Novo pitanje',
    'de': 'Neue Frage',
    'en': 'New question',
    'pl': 'Nowe pytanie',
  },
  'guide_forum_add_body': {
    'hr': 'Kliknite ovdje ako želite postaviti novo pitanje ili započeti raspravu unutar zajednice.',
    'de': 'Klicken Sie hier, um eine neue Frage zu stellen oder eine Diskussion in der Community zu starten.',
    'en': 'Tap here to ask a new question or start a discussion in the community.',
    'pl': 'Kliknij tutaj, aby zadać nowe pytanie lub rozpocząć dyskusję w społeczności.',
  },
  'forum_new_topic': {
    'hr': 'Nova tema',
    'bs': 'Nova tema',
    'sr': 'Nova tema',
    'de': 'Neues Thema',
    'en': 'New topic',
    'it': 'Nuovo argomento',
    'fr': 'Nouveau sujet',
    'es': 'Nuevo tema',
  },
  'forum_publish_topic': {
    'hr': 'Objavi temu',
    'bs': 'Objavi temu',
    'sr': 'Objavi temu',
    'de': 'Thema veröffentlichen',
    'en': 'Publish topic',
    'it': 'Pubblica argomento',
    'fr': 'Publier le sujet',
    'es': 'Publicar tema',
  },
  'weather_location_missing': {
    'hr': 'Unesite lokaciju farme u profilu za vremensku prognozu.',
    'sr': 'Unesite lokaciju gazdinstva u profilu za vremensku prognozu.',
    'de': 'Bitte Farm-Standort im Profil eintragen für Wettervorhersage.',
    'pl': 'Wprowadź lokalizację gospodarstwa w profilu, aby zobaczyć prognozę pogody.',
    'sv': 'Ange gårdens plats i profilen för väderprognos.',
    'en': 'Set your farm location in profile for weather forecast.',
  },
  'weather_location_tap': {
    'hr': 'Dodirnite gumb ispod za uključivanje GPS-a',
    'bs': 'Dodirnite dugme ispod za uključivanje GPS-a',
    'sr': 'Dodirnite dugme ispod za uključivanje GPS-a',
    'de': 'Tippen Sie auf die Schaltfläche unten, um GPS zu aktivieren',
    'en': 'Tap the button below to enable GPS',
  },
  'weather_unavailable_tap': {
    'hr': 'Prognoza nije učitana. Pritisnite gumb za ažuriranje lokacije i ponovno učitavanje.',
    'bs': 'Prognoza nije učitana. Pritisnite dugme za ažuriranje lokacije i ponovno učitavanje.',
    'sr': 'Prognoza nije učitana. Pritisnite dugme za ažuriranje lokacije i ponovno učitavanje.',
    'de': 'Prognose konnte nicht geladen werden. Tippen Sie unten, um den Standort zu aktualisieren.',
    'en': 'Forecast could not be loaded. Tap below to update location and retry.',
  },
  'weather_action_gps_button': {
    'hr': 'Uključi GPS i učitaj prognozu',
    'bs': 'Uključi GPS i učitaj prognozu',
    'sr': 'Uključi GPS i učitaj prognozu',
    'de': 'GPS aktivieren & Prognose laden',
    'en': 'Enable GPS & load forecast',
  },
  'weather_action_retry_button': {
    'hr': 'Ažuriraj lokaciju i pokušaj ponovo',
    'bs': 'Ažuriraj lokaciju i pokušaj ponovo',
    'sr': 'Ažuriraj lokaciju i pokušaj ponovo',
    'de': 'Standort aktualisieren & erneut laden',
    'en': 'Update location & retry',
  },
  'weather_loading_hint': {
    'hr': 'Dohvaćamo vremenske podatke za vašu lokaciju...',
    'de': 'Wetterdaten für Ihren Standort werden abgerufen...',
    'en': 'Fetching weather data for your location...',
  },
  'weather_loading_action': {
    'hr': 'Učitavanje...',
    'de': 'Wird geladen...',
    'en': 'Loading...',
  },
  'weather_using_device_gps': {
    'hr': 'Prognoza prema vašoj trenutnoj GPS lokaciji',
    'de': 'Prognose basierend auf Ihrem aktuellen GPS-Standort',
    'en': 'Forecast based on your current GPS location',
  },
  'weather_simulation_badge': {
    'hr': 'Simulirana prognoza — stvarno vrijeme nakon povezivanja API-ja',
    'de': 'Simulierte Prognose — echtes Wetter nach API-Anbindung',
    'en': 'Simulated forecast — real weather after API is connected',
  },
  'weather_condition_sunny': {
    'hr': 'Sunčano',
    'bs': 'Sunčano',
    'sr': 'Sunčano',
    'de': 'Sonnig',
    'en': 'Sunny',
  },
  'weather_condition_cloudy': {
    'hr': 'Oblačno',
    'bs': 'Oblačno',
    'sr': 'Oblačno',
    'de': 'Bewölkt',
    'en': 'Cloudy',
  },
  'weather_condition_rainy': {
    'hr': 'Kiša',
    'bs': 'Kiša',
    'sr': 'Kiša',
    'de': 'Regen',
    'en': 'Rainy',
  },
  'weather_condition_storm': {
    'hr': 'Grmljavina',
    'bs': 'Grmljavina',
    'sr': 'Grmljavina',
    'de': 'Gewitter',
    'en': 'Storm',
  },
  'weather_premium_cta': {
    'hr': 'Aktiviraj Premium meteo-alarme (9,99 €/mj.)',
    'bs': 'Aktiviraj Premium meteo-alarme (9,99 €/mj.)',
    'sr': 'Aktiviraj Premium meteo-alarme (9,99 €/mj.)',
    'de': 'Premium Wetter-Warnungen aktivieren',
    'en': 'Activate Premium for urgent weather alerts',
  },
  'location_install_success': {
    'hr': 'Lokacija potvrđena. Dobrodošli u My Farmer!',
    'de': 'Standort bestätigt. Willkommen bei My Farmer!',
    'en': 'Location confirmed. Welcome to My Farmer!',
  },
  'guide_farmer_weather_title': {
    'hr': 'Agro prognoza',
    'sr': 'Agro prognoza',
    'de': 'Agro-Wetter',
    'pl': 'Prognoza agro',
    'sv': 'Agroprognos',
    'en': 'Agro forecast',
  },
  'guide_farmer_weather_body': {
    'hr': 'Ovdje ćete vidjeti prognozu i hitne alarme za nepogode čim unesete lokaciju farme u profilu.',
    'sr': 'Ovde ćete videti prognozu i hitne alarme za nepogode čim unesete lokaciju gazdinstva u profilu.',
    'de': 'Hier sehen Sie die Wettervorhersage und Notfallwarnungen, sobald Sie den Farm-Standort im Profil eintragen.',
    'pl': 'Tutaj zobaczysz prognozę i alerty o niepogodzie, gdy wprowadzisz lokalizację gospodarstwa w profilu.',
    'sv': 'Här ser du prognosen och varningar för oväder när du angett gårdens plats i profilen.',
    'en': 'Here you will see the forecast and severe weather alerts once you set your farm location in profile.',
  },
  'guide_farmer_list_title': {
    'hr': 'Upravljanje zalihama',
    'de': 'Bestandsverwaltung',
    'pl': 'Zarządzanie zapasami',
    'sv': 'Lagerhantering',
    'en': 'Stock management',
  },
  'guide_farmer_list_body': {
    'hr': 'Ovdje pratite svoje proizvode, dostupne kilograme i koristite switch za brzu oznaku [RASPRODANO].',
    'de': 'Hier überwachen Sie Ihre Produkte, verfügbare Kilos und nutzen den Switch für die schnelle Kennzeichnung [AUSVERKAUFT].',
    'pl': 'Tutaj śledzisz swoje produkty, dostępne kilogramy i używasz przełącznika do szybkiego oznaczenia [WYPRZEDANE].',
    'sv': 'Här följer du dina produkter, tillgängliga kilon och använder reglaget för att snabbt markera [SLUT].',
    'en': 'Track your products, available stock, and use the switch to quickly mark [SOLD OUT].',
  },
  'guide_farmer_add_title': {
    'hr': 'Novi oglas',
    'de': 'Neues Produkt',
    'pl': 'Nowe ogłoszenie',
    'sv': 'Ny annons',
    'en': 'New listing',
  },
  'guide_farmer_add_body': {
    'hr': 'Kliknite na ovaj plus da otvorite formu i unesete novi proizvod ili premium robu u dolasku.',
    'de': 'Klicken Sie auf dieses Plus, um das Formular zu öffnen und ein neues Produkt oder kommende Premium-Ware einzutragen.',
    'pl': 'Kliknij ten plus, aby otworzyć formularz i dodać nowy produkt lub nadchodzący artykuł premium.',
    'sv': 'Tryck på pluset för att öppna formuläret och lägga till en ny produkt eller kommande premiumartikel.',
    'en': 'Tap this plus to open the form and add a new product or premium upcoming item.',
  },
  'guide_profile_settings_title': {
    'hr': 'Jezik i valutna regija',
    'de': 'Sprache und Währungsregion',
    'sv': 'Språk och valutaregion',
    'en': 'Language and currency region',
  },
  'guide_profile_settings_body': {
    'hr':
        'Ovdje iz padajućih izbornika birate jezik aplikacije i valutnu regiju za preračun cijena na tržnici.',
    'de':
        'Wählen Sie hier in den Dropdown-Menüs die App-Sprache und die Währungsregion für die Preisumrechnung auf dem Marktplatz.',
    'sv':
        'Använd rullgardinsmenyerna här för att välja appspråk och valutaregion för marknadspriser.',
    'en':
        'Use the dropdown menus here to choose the app language and currency region for marketplace prices.',
  },
  'guide_profile_tabs_title': {
    'hr': 'Gornji izbornik',
    'de': 'Oberes Menü',
    'pl': 'Górne menu',
    'sv': 'Toppmeny',
    'en': 'Top menu',
  },
  'guide_profile_tabs_body': {
    'hr':
        "'Moj Profil' vam služi za upravljanje poslovnim podacima, dok 'Moja galerija' služi da podijelite lijepe trenutke sa zajednicom – pokažite ljepotu svog sela, predivan vrt, biljke, životinje i kućne ljubimce.",
    'de':
        "'Mein Profil' dient der Verwaltung Ihrer Geschäftsdaten, während 'Meine Galerie' dazu da ist, schöne Momente mit der Community zu teilen – zeigen Sie die Schönheit Ihres Dorfes, Ihren wunderschönen Garten, Pflanzen, Tiere und Haustiere.",
    'pl':
        "'Mój profil' służy do zarządzania danymi biznesowymi, a 'Galeria' do dzielenia się pięknymi chwilami ze społecznością — pokaż piękno swojej wioski, ogród, rośliny, zwierzęta i pupile.",
    'sv':
        'Min profil hanterar dina affärsuppgifter, medan Galleri låter dig dela vackra ögonblick med communityn — visa din by, trädgård, växter, djur och husdjur.',
    'en':
        'My Profile manages your business data, while My Gallery lets you share beautiful community moments – your village, garden, plants, animals, and pets.',
  },
  'vet_premium_activate_button': {
    'hr': '💎 Aktiviraj Premium Veterinar (9,99 €/mj)',
    'de': '💎 Premium Tierarzt aktivieren (9,99 €/Monat)',
    'cs': '💎 Aktivovat Premium Veterinář (9,99 €/měsíc)',
    'es': '💎 Activar Premium Veterinario (9,99 €/mes)',
    'en': '💎 Activate Veterinarian Premium (€9.99/mo)',
    'zh': '💎 激活兽医 Premium（¥78,42/月）',
    'uk': '💎 Активувати Premium ветеринара (429,57 ₴/міс.)',
    'ru': '💎 Активировать Premium ветеринара (979,02 ₽/мес.)',
    'hi': '💎 पशु चिकित्सक Premium सक्रिय करें (₹276,00/माह)',
    'id': '💎 Aktifkan Premium Dokter Hewan (Rp51.000/bln)',
    'sw': '💎 Washa Premium ya Daktari wa Mifugo (KSh433,55/mwezi)',
    'ar': '💎 تفعيل Premium طبيب بيطري (40,46 ر.س/شهر)',
    'it': '💎 Attiva Premium Veterinario (9,99 €/mese)',
    'tr': '💎 Veteriner Premium\'u etkinleştir (295,63 ₺/ay)',
  },
  'vet_patient_records': {
    'hr': 'Kartoteka pacijenata',
    'de': 'Patientenakte',
    'sv': 'Patientjournal',
    'cs': 'Kartotéka pacientů',
    'es': 'Historial de pacientes',
    'fr': 'Dossiers patients',
    'en': 'Patient records',
    'zh': '患者档案',
    'uk': 'Картотека пацієнтів',
    'ru': 'Картотека пациентов',
    'hi': 'रोगी रिकॉर्ड',
    'id': 'Rekam medis pasien',
    'sw': 'Rekodi za wagonjwa',
    'ar': 'سجلات المرضى',
    'it': 'Cartelle pazienti',
    'tr': 'Hasta kayıtları',
  },
  'vet_patient_records_btn_desc': {
    'hr': 'Terenska ambulanta i pristigli kartoni stoke od farmera',
    'de': 'Feldklinik und eingegangene Viehakten von Landwirten',
    'sv': 'Fältklinik och inkommande boskapsjournaler från bönder',
    'cs': 'Terénní ambulance a příchozí záznamy o dobytku od farmářů',
    'es': 'Clínica de campo y fichas de ganado recibidas de agricultores',
    'fr': 'Clinique de terrain et dossiers de bétail reçus des agriculteurs',
    'en': 'Field clinic and incoming livestock records from farmers',
    'zh': '现场诊所与来自农民的家畜档案',
    'uk': 'Польова амбулаторія та вхідні записи про худобу від фермерів',
    'ru': 'Полевая амбулатория и входящие записи о скоте от фермеров',
    'hi': 'क्षेत्र क्लिनिक और किसानों से आने वाले पशु रिकॉर्ड',
    'id': 'Klinik lapangan dan rekam ternak masuk dari petani',
    'sw': 'Kliniki ya uwanjani na rekodi za mifugo kutoka kwa wakulima',
    'ar': 'عيادة ميدانية وسجلات الماشية الواردة من المزارعين',
    'it': 'Ambulatorio sul campo e cartelle del bestiame dai agricoltori',
    'tr': 'Saha kliniği ve çiftçilerden gelen hayvan kayıtları',
  },
  'vet_my_pets': {
    'hr': 'Moji ljubimci',
    'de': 'Meine Haustiere',
    'sv': 'Mina husdjur',
    'cs': 'Moji mazlíčci',
    'es': 'Mis mascotas',
    'fr': 'Mes animaux',
    'en': 'My pets',
    'zh': '我的宠物',
    'uk': 'Мої улюбленці',
    'ru': 'Мои питомцы',
    'hi': 'मेरे पालतू',
    'id': 'Hewan peliharaan saya',
    'sw': 'Wanyama wangu',
    'ar': 'حيواناتي الأليفة',
    'it': 'I miei animali',
    'tr': 'Evcil hayvanlarım',
  },
  'vet_my_pets_btn_desc': {
    'hr': 'Do 10 privatnih kućnih ljubimaca (psi, mačke...)',
    'de': 'Bis zu 10 private Haustiere (Hunde, Katzen...)',
    'sv': 'Upp till 10 privata husdjur (hundar, katter...)',
    'cs': 'Až 10 soukromých mazlíčků (psi, kočky...)',
    'es': 'Hasta 10 mascotas privadas (perros, gatos...)',
    'fr': 'Jusqu\'à 10 animaux privés (chiens, chats...)',
    'en': 'Up to 10 private pets (dogs, cats...)',
    'zh': '最多 10 只私人宠物（狗、猫等）',
    'uk': 'До 10 приватних тварин (собаки, коти...)',
    'ru': 'До 10 частных животных (собаки, кошки...)',
    'hi': '10 निजी पालतू तक (कुत्ते, बिल्लियाँ...)',
    'id': 'Hingga 10 hewan peliharaan pribadi (anjing, kucing...)',
    'sw': 'Hadi wanyama 10 wa kibinafsi (mbwa, paka...)',
    'ar': 'حتى 10 حيوانات أليفة خاصة (كلاب، قطط...)',
    'it': 'Fino a 10 animali domestici privati (cani, gatti...)',
    'tr': '10\'a kadar özel evcil hayvan (köpek, kedi...)',
  },
  'vet_patient_records_subtitle': {
    'hr':
        'Digitalni prijem kartona od farmera, terenski nalazi i do 10 privatnih ljubimaca.',
    'de':
        'Digitaler Empfang von Farmer-Akten, Feldbefunde und bis zu 10 private Haustiere.',
    'en':
        'Digital farmer record intake, field findings, and up to 10 private pets.',
    'zh': '数字化接收农民档案、现场发现并最多 10 只私人宠物。',
  },
  'vet_patient_records_locked': {
    'hr':
        'Kartoteka pacijenata zaključana. Aktivirajte Premium Veterinar (9,99 €/mj) za digitalni prijem kartona, zlatnu značku i radar prve pomoći.',
    'de':
        'Patientenakte gesperrt. Aktivieren Sie Premium Tierarzt (9,99 €/Monat) für digitalen Empfang, goldenes Abzeichen und Erste-Hilfe-Radar.',
    'es':
        'Historial de pacientes bloqueado. Activa Premium Veterinario (9,99 €/mes) para recepción digital, insignia dorada y radar de primeros auxilios.',
    'fr':
        'Dossiers patients verrouillés. Activez Premium Vétérinaire (9,99 €/mois) pour la réception numérique, le badge doré et le radar de premiers secours.',
    'cs':
        'Kartotéka pacientů je uzamčena. Aktivujte Premium Veterinář (9,99 €/měsíc) pro digitální příjem, zlatý odznak a radar první pomoci.',
    'en':
        'Patient records locked. Activate Veterinarian Premium (€9.99/mo) for digital intake, golden badge, and First Aid radar.',
    'zh': '患者档案已锁定。激活兽医 Premium（¥78,42/月）以解锁数字化接收、黄金徽章和急救雷达。',
  },
  'vet_animals_subtitle': {
    'hr': 'Digitalni prijem kartona stoke i terenski nalazi',
    'de': 'Digitaler Empfang von Viehakten und Feldbefunde',
    'en': 'Digital livestock record intake and field findings',
  },
  'vet_animals_digital_intake': {
    'hr': 'Digitalni prijem kartona stoke',
    'de': 'Digitaler Empfang von Viehakten',
    'en': 'Digital livestock record intake',
  },
  'vet_tab_digital_intake': {
    'hr': 'Digitalni prijem kartona',
    'de': 'Digitaler Aktenempfang',
    'en': 'Digital record intake',
  },
  'vet_animals_digital_intake_desc': {
    'hr': 'Primajte i pregledavajte digitalne kartone koje farmeri dijele s vama.',
    'de': 'Empfangen und prüfen Sie digitale Akten, die Landwirte mit Ihnen teilen.',
    'en': 'Receive and review digital records farmers share with you.',
  },
  'vet_animals_digital_intake_body': {
    'hr':
        'Ovdje primate digitalne zdravstvene kartone stoke od farmera. Premium veterinar dobiva zlatnu značku i pojavljuje se u radaru prve pomoći.',
    'de':
        'Hier empfangen Sie digitale Viehgesundheitsakten von Landwirten. Premium-Tierärzte erhalten ein goldenes Abzeichen und erscheinen im Erste-Hilfe-Radar.',
    'en':
        'Receive digital livestock health records from farmers here. Premium vets get the golden badge and appear in the First Aid radar.',
  },
  'vet_animals_field_findings': {
    'hr': 'Terenski nalazi',
    'de': 'Feldbefunde',
    'en': 'Field findings',
  },
  'vet_animals_field_findings_desc': {
    'hr': 'Evidentirajte nalaze s terenskih pregleda i posjeta farmama.',
    'de': 'Dokumentieren Sie Befunde von Feldbesuchen und Hofbesuchen.',
    'en': 'Record findings from field exams and farm visits.',
  },
  'vet_animals_field_findings_body': {
    'hr':
        'Vodite terenske nalaze, fotografije i bilješke s posjeta stoci na farmama. Dostupno uz Premium Veterinar paket.',
    'de':
        'Führen Sie Feldbefunde, Fotos und Notizen von Hofbesuchen. Verfügbar mit dem Premium-Tierarzt-Paket.',
    'en':
        'Manage field findings, photos, and notes from farm visits. Available with the Veterinarian Premium package.',
  },
  'vet_field_report_add': {
    'hr': 'Novi terenski nalaz',
    'de': 'Neuer Feldbefund',
    'en': 'New field report',
  },
  'vet_field_report_empty': {
    'hr':
        'Još nema terenskih nalaza. Dodirnite + kako biste zabilježili posjet farmi, bilješke i fotografiju.',
    'de':
        'Noch keine Feldbefunde. Tippen Sie auf +, um einen Hofbesuch mit Notizen und Foto zu erfassen.',
    'en':
        'No field reports yet. Tap + to record a farm visit with notes and a photo.',
  },
  'vet_field_report_title_label': {
    'hr': 'Naslov nalaza',
    'de': 'Titel des Befunds',
    'en': 'Report title',
  },
  'vet_field_report_title_required': {
    'hr': 'Unesite naslov nalaza',
    'de': 'Bitte Titel eingeben',
    'en': 'Enter a report title',
  },
  'vet_field_report_farmer_label': {
    'hr': 'Farmer',
    'de': 'Landwirt',
    'en': 'Farmer',
  },
  'vet_field_report_select_farmer': {
    'hr': 'Odaberite farmera',
    'de': 'Landwirt auswählen',
    'en': 'Select farmer',
  },
  'vet_field_report_other_farmer': {
    'hr': 'Unesi drugog farmera',
    'de': 'Anderen Landwirt eingeben',
    'en': 'Enter another farmer',
  },
  'vet_field_report_farmer_required': {
    'hr': 'Odaberite ili unesite farmera',
    'de': 'Landwirt auswählen oder eingeben',
    'en': 'Select or enter a farmer',
  },
  'vet_field_report_notes_label': {
    'hr': 'Tekst bilješke',
    'de': 'Notiztext',
    'en': 'Notes',
  },
  'vet_field_report_photo_btn': {
    'hr': 'Uslikaj / dodaj fotografiju',
    'de': 'Foto aufnehmen / hinzufügen',
    'en': 'Take / add photo',
  },
  'vet_field_report_photo_camera': {
    'hr': 'Uslikaj kamerom',
    'de': 'Mit Kamera aufnehmen',
    'en': 'Take with camera',
  },
  'vet_field_report_photo_gallery': {
    'hr': 'Izaberi iz galerije',
    'de': 'Aus Galerie wählen',
    'en': 'Choose from gallery',
  },
  'vet_field_report_save': {
    'hr': 'Spremi terenski nalaz',
    'de': 'Feldbefund speichern',
    'en': 'Save field report',
  },
  'vet_field_report_saved': {
    'hr': 'Terenski nalaz je spremljen',
    'de': 'Feldbefund gespeichert',
    'en': 'Field report saved',
  },
  'guide_profile_identity_title': {
    'hr': 'Identitet farmera',
    'de': 'Farmer-Identität',
    'en': 'Farmer identity',
  },
  'guide_profile_identity_body': {
    'hr':
        "Ovdje stoji vaša profilna slika i ime. Narančasta značka 'Profesionalni Farmer' kupcima dokazuje da ste provjereni i ozbiljni proizvođač.",
    'de':
        "Hier finden Sie Ihr Profilbild und Ihren Namen. Das orangefarbene Abzeichen 'Professioneller Farmer' zeigt Käufern, dass Sie ein geprüfter und seriöser Produzent sind.",
    'en':
        "Your profile photo and name appear here. The orange 'Professional Farmer' badge shows buyers you are a verified, serious producer.",
  },
  'guide_profile_company_identity_title': {
    'hr': 'Identitet poduzeća',
    'de': 'Unternehmensidentität',
    'en': 'Business identity',
  },
  'guide_profile_company_identity_body': {
    'hr':
        'Ovdje stoji logotip i službeni naziv vašeg poduzeća. Zlatna poslovna značka kupcima i farmerima dokazuje da ste provjereni, sigurni i ovlašteni dobavljač repromaterijala.',
    'de':
        'Hier steht Ihr Firmenlogo und Name. Das goldene Business-Abzeichen zeigt Käufern und Landwirten, dass Sie ein verifizierter Lieferant sind.',
    'en':
        'Your company logo and official business name appear here. The gold business badge shows buyers and farmers that you are a verified, trusted supplier.',
  },
  'guide_profile_currency_title': {
    'hr': 'Trenutna valuta',
    'bs': 'Trenutna valuta',
    'sr': 'Trenutna valuta',
    'de': 'Aktuelle Währung',
    'en': 'Current currency',
    'pl': 'Aktualna waluta',
    'cs': 'Aktuální měna',
    'es': 'Moneda actual',
    'fr': 'Devise actuelle',
    'it': 'Valuta attuale',
    'sv': 'Aktuell valuta',
    'tr': 'Geçerli para birimi',
  },
  'guide_profile_currency_body': {
    'hr':
        'Zeleno polje pokazuje valutu u kojoj se prikazuju i preračunavaju sve cijene. Određuje je vaša lokacija (GPS/IP), ne jezik aplikacije — npr. u EU vidite € čak i s bosanskim ili hrvatskim sučeljem.',
    'bs':
        'Zeleno polje pokazuje valutu u kojoj se prikazuju i preračunavaju sve cijene. Određuje je vaša lokacija (GPS/IP), ne jezik aplikacije — npr. u EU vidite € čak i s bosanskim sučeljem.',
    'sr':
        'Zeleno polje pokazuje valutu za sve cijene. Određuje je lokacija (GPS/IP), ne jezik aplikacije — u dijaspori možete ručno odabrati BiH ili Srbiju iznad.',
    'de':
        'Das grüne Feld zeigt die Währung für alle Preise. Sie wird durch Ihren Standort (GPS/IP) bestimmt, nicht durch die App-Sprache — in der EU sehen Sie z. B. € auch bei bosnischer oder kroatischer Oberfläche.',
    'en':
        'The green field shows the currency used for all prices. It is set by your location (GPS/IP), not the app language — e.g. in the EU you see € even with Bosnian or Croatian UI.',
    'pl':
        'Zielone pole pokazuje walutę wszystkich cen. Ustala ją lokalizacja (GPS/IP), a nie język aplikacji — np. w UE widzisz € nawet z interfejsem bośniackim lub chorwackim.',
    'cs':
        'Zelené pole ukazuje měnu pro všechny ceny. Určuje ji vaše poloha (GPS/IP), ne jazyk aplikace — v EU např. uvidíte € i s bosenským nebo chorvatským rozhraním.',
    'es':
        'El campo verde muestra la moneda de todos los precios. La determina tu ubicación (GPS/IP), no el idioma de la app — p. ej. en la UE ves € incluso con interfaz bosnia o croata.',
    'fr':
        'Le champ vert indique la devise utilisée pour tous les prix. Elle est déterminée par votre position (GPS/IP), pas par la langue de l\'app — par ex. dans l\'UE vous voyez € même avec l\'interface bosniaque ou croate.',
    'it':
        'Il campo verde mostra la valuta usata per tutti i prezzi. È determinata dalla tua posizione (GPS/IP), non dalla lingua dell\'app — ad es. nell\'UE vedi € anche con interfaccia bosniaca o croata.',
    'sv':
        'Det gröna fältet visar valutan för alla priser. Den bestäms av din plats (GPS/IP), inte appspråket — t.ex. i EU ser du € även med bosnisk eller kroatisk gränssnitt. Köpare kan välja Sverige eller EU ovan.',
    'tr':
        'Yeşil alan tüm fiyatların para birimini gösterir. Uygulama dili değil, konumunuz (GPS/IP) belirler — örn. AB\'de Bosna veya Hırvat arayüzüyle bile € görürsünüz.',
  },
  'guide_profile_phone_title': {
    'hr': 'Broj telefona',
    'de': 'Telefonnummer',
    'en': 'Phone number',
  },
  'guide_profile_phone_body': {
    'hr':
        'Unesite broj na koji vas kupci mogu nazvati za dogovor narudžbe i brzu komunikaciju.',
    'de':
        'Geben Sie die Nummer ein, unter der Kunden Sie für Bestellungen und schnelle Rückfragen erreichen.',
    'en':
        'Enter the number buyers can call to arrange orders and reach you quickly.',
  },
  'guide_profile_address_title': {
    'hr': 'Adresa imanja',
    'de': 'Hofadresse',
    'en': 'Farm address',
  },
  'guide_profile_address_body': {
    'hr':
        'Upišite lokaciju farme kako bi vas kupci i aplikacija lakše pronašli na karti.',
    'de':
        'Tragen Sie den Standort Ihres Hofes ein, damit Kunden und die App Sie auf der Karte leichter finden.',
    'en':
        'Enter your farm location so buyers and the app can find you on the map.',
  },
  'guide_profile_paypal_title': {
    'hr': 'PayPal račun',
    'de': 'PayPal-Konto',
    'en': 'PayPal account',
  },
  'guide_profile_paypal_body': {
    'hr':
        'Opcionalno dodajte PayPal e-mail za brže i sigurnije online plaćanje od kupaca.',
    'de':
        'Fügen Sie optional Ihre PayPal-E-Mail für schnellere und sicherere Online-Zahlungen hinzu.',
    'en':
        'Optionally add your PayPal email for faster and safer online payments from buyers.',
  },
  'guide_profile_farm_number_title': {
    'hr': 'Broj gazdinstva',
    'de': 'Betriebsnummer',
    'en': 'Farm registration number',
  },
  'guide_profile_farm_number_body': {
    'hr':
        'Upišite BPG ili OPG broj koji potvrđuje vaše registrirano poljoprivredno gospodarstvo.',
    'de':
        'Geben Sie Ihre BPG- oder OPG-Nummer ein, die Ihren registrierten landwirtschaftlichen Betrieb bestätigt.',
    'en':
        'Enter your BPG or OPG number that confirms your registered farm business.',
  },
  'guide_profile_shop_hours_title': {
    'hr': 'Dostupnost i radno vrijeme',
    'de': 'Verfügbarkeit und Arbeitszeit',
    'en': 'Availability and working hours',
  },
  'guide_profile_shop_hours_body': {
    'hr':
        'Uključite dostupnost za narudžbe, odaberite radne dane i satnice kada ste na imanju i dostupni kupcima.',
    'de':
        'Schalten Sie die Bestellverfügbarkeit ein, wählen Sie Arbeitstage und Zeiten, an denen Sie auf dem Hof für Kunden erreichbar sind.',
    'en':
        'Turn order availability on, pick working days, and set the hours when you are on the farm for buyers.',
  },
  'guide_profile_availability_title': {
    'hr': 'Dostupnost',
    'de': 'Verfügbarkeit',
    'en': 'Availability',
  },
  'guide_profile_availability_body': {
    'hr':
        'Uključite ili isključite da li trenutno prihvaćate narudžbe od kupaca dok ste aktivni na farmi.',
    'de':
        'Schalten Sie hier um, ob Sie derzeit Bestellungen von Kunden annehmen, während Sie auf dem Hof aktiv sind.',
    'en':
        'Turn on or off whether you currently accept orders from buyers while active on the farm.',
  },
  'guide_profile_hours_title': {
    'hr': 'Radno vrijeme',
    'de': 'Arbeitszeit',
    'en': 'Working hours',
  },
  'guide_profile_hours_body': {
    'hr':
        'Ovdje definišete dane i sate kada ste dostupni za kupce i kada radite na imanju.',
    'de':
        'Hier definieren Sie die Tage und Zeiten, an denen Sie für Kunden erreichbar sind.',
    'en':
        'Define the days and hours when you are available for buyers and working on the farm.',
  },
  'guide_profile_min_order_title': {
    'hr': 'Minimalna narudžba',
    'de': 'Mindestbestellwert',
    'en': 'Minimum order',
  },
  'guide_profile_min_order_body': {
    'hr':
        'Postavite najmanji iznos u eurima koji kupac mora potrošiti da biste mu vi osobno spakovali i dostavili proizvode.',
    'de':
        'Legen Sie den Mindestbetrag in Euro fest, den ein Kunde ausgeben muss, damit Sie die Ware persönlich verpacken und liefern.',
    'en':
        'Set the minimum amount in euros a buyer must spend before you personally pack and deliver the products.',
  },
  'guide_profile_pickup_title': {
    'hr': 'Osobno preuzimanje',
    'de': 'Selbstabholung',
    'en': 'Personal pickup',
  },
  'guide_profile_pickup_body': {
    'hr':
        'Navedite dane i točne sate kada kupci mogu sami automobilom doći kod vas na imanje po svoje narudžbe.',
    'de':
        'Geben Sie die Tage und genauen Zeiten an, zu denen Kunden mit dem Auto direkt zu Ihrem Hof kommen können, um ihre Bestellungen abzuholen.',
    'en':
        'Specify the days and exact hours when buyers can drive to your farm themselves to pick up their orders.',
  },
  'guide_profile_delivery_info_title': {
    'hr': 'Dostava na adresu',
    'de': 'Lieferung nach Hause',
    'en': 'Home delivery',
  },
  'guide_profile_delivery_info_body': {
    'hr':
        'Ovdje upišite kratak tekstualni opis za kupce o tome kako i kada vršite lični prevoz robe (npr. kojim danima vozite).',
    'de':
        'Geben Sie hier eine kurze Beschreibung für Käufer ein, wie und wann Sie persönlich Waren liefern (z. B. an welchen Tagen Sie fahren).',
    'en':
        'Enter a short description for buyers about how and when you personally deliver goods (e.g. which days you drive).',
  },
  'guide_profile_delivery_zones_title': {
    'hr': 'Zone dostave',
    'de': 'Lieferzonen',
    'en': 'Delivery zones',
  },
  'guide_profile_delivery_zones_body': {
    'hr':
        'Ovdje određujete minimalni iznos narudžbe za svaku udaljenost kako biste znali kada vam se isplati lično sjesti u auto i odvesti robu kupcu unutar te zone.',
    'bs':
        'Ovdje određujete minimalni iznos narudžbe za svaku udaljenost kako biste znali kada vam se isplati lično sjesti u auto i odvesti robu kupcu unutar te zone.',
    'de':
        'Hier legen Sie den Mindestbestellwert für jede Entfernung fest, damit Sie wissen, wann es sich lohnt, persönlich ins Auto zu steigen und die Ware dem Kunden in dieser Zone zu bringen.',
    'en':
        'Set the minimum order amount for each distance so you know when it is worth driving personally to deliver within that zone.',
  },
  'guide_profile_land_title': {
    'hr': 'Satelitski radar',
    'de': 'Satelliten-Radar',
    'en': 'Satellite radar',
  },
  'guide_profile_land_body': {
    'hr':
        'Kliknite ovdje da otvorite satelitsku kartu, prstom ucrtate granice njive, besplatno izračunate hektare i pokrenete napredni Premium NIRS multispektralni nadzor zdravlja biljaka.',
    'de':
        'Klicken Sie hier, um die Satellitenkarte zu öffnen, Grenzen zu zeichnen, Hektar zu berechnen und die fortschrittliche Premium-NIRS-Multispektralüberwachung der Pflanzengesundheit zu starten.',
    'en':
        'Tap here to open the satellite map, draw field boundaries, calculate hectares for free, and start advanced Premium NIRS multispectral crop health monitoring.',
  },
  'land_nirs_advice_low': {
    'hr': 'Nizak NDVI — provjerite navodnjavanje, hranidbu i moguće bolesti na terenu.',
    'de': 'Niedriger NDVI — Bewässerung, Düngung und Krankheiten vor Ort prüfen.',
    'en': 'Low NDVI — check irrigation, nutrition and possible field diseases.',
  },
  'land_nirs_simulation_badge': {
    'hr': 'Simulacija — uključite stvarni API prije produkcije',
    'de': 'Simulation — Live-API vor Produktivstart aktivieren',
    'en': 'Simulation — enable live API before production',
  },
  'land_nirs_legend_title': {
    'hr': 'NDVI legenda',
    'de': 'NDVI-Legende',
    'en': 'NDVI legend',
  },
  'land_nirs_legend_good': {
    'hr': 'Odlično — gusta vegetacija',
    'de': 'Sehr gut — dichte Vegetation',
    'en': 'Good — dense vegetation',
  },
  'land_nirs_legend_moderate': {
    'hr': 'Umjereno — pratite parcelu',
    'de': 'Mäßig — Parzelle beobachten',
    'en': 'Moderate — monitor the plot',
  },
  'land_nirs_legend_low': {
    'hr': 'Slabo — moguć stres biljaka',
    'de': 'Schwach — möglicher Pflanzenstress',
    'en': 'Low — possible crop stress',
  },
  'land_nirs_advice_title': {
    'hr': 'Preporuka za parcelu',
    'de': 'Empfehlung für die Parzelle',
    'en': 'Recommendation for this plot',
  },
  'land_nirs_advice_good': {
    'hr': 'Vegetacija je u dobrom stanju. Nastavite redoviti nadzor jednom tjedno.',
    'de': 'Vegetation ist in gutem Zustand. Wöchentliche Kontrolle beibehalten.',
    'en': 'Vegetation is in good condition. Keep weekly monitoring.',
  },
  'land_nirs_advice_moderate': {
    'hr': 'Vegetacija je umjerena. Provjerite navodnjavanje u sljedećih 3–5 dana.',
    'de': 'Vegetation ist mäßig. Bewässerung in 3–5 Tagen prüfen.',
    'en': 'Vegetation is moderate. Check irrigation in the next 3–5 days.',
  },
  'land_nirs_advice_low_moisture': {
    'hr': 'Vlažnost tla je niska. Planirajte navodnjavanje u sljedećih 24–48 sati.',
    'de': 'Bodenfeuchtigkeit ist niedrig. Bewässerung in 24–48 Stunden planen.',
    'en': 'Soil moisture is low. Plan irrigation within 24–48 hours.',
  },
  'land_nirs_advice_high_moisture': {
    'hr': 'Tlo je vrlo vlažno. Odgodite navodnjavanje i pripazite na bolesti.',
    'de': 'Boden ist sehr feucht. Bewässerung verschieben und Krankheiten beobachten.',
    'en': 'Soil is very wet. Delay irrigation and watch for disease.',
  },
  'land_nirs_compare_title': {
    'hr': 'Usporedba s prethodnim skenom',
    'de': 'Vergleich mit vorherigem Scan',
    'en': 'Comparison with previous scan',
  },
  'land_nirs_compare_previous': {
    'hr': 'Prije',
    'de': 'Vorher',
    'en': 'Before',
  },
  'land_nirs_compare_current': {
    'hr': 'Sada',
    'de': 'Jetzt',
    'en': 'Now',
  },
  'land_nirs_compare_stable': {
    'hr': 'NDVI stabilan u odnosu na prethodni sken.',
    'de': 'NDVI stabil im Vergleich zum vorherigen Scan.',
    'en': 'NDVI stable compared to the previous scan.',
  },
  'land_nirs_compare_up': {
    'hr': 'NDVI porastao za {delta} — vegetacija se poboljšava.',
    'de': 'NDVI um {delta} gestiegen — Vegetation verbessert sich.',
    'en': 'NDVI increased by {delta} — vegetation is improving.',
  },
  'land_nirs_compare_down': {
    'hr': 'NDVI pao za {delta} — provjerite parcelu na terenu.',
    'de': 'NDVI um {delta} gesunken — Parzelle vor Ort prüfen.',
    'en': 'NDVI dropped by {delta} — inspect the plot in the field.',
  },
  'land_nirs_history_title': {
    'hr': 'Povijest skenova',
    'de': 'Scan-Verlauf',
    'en': 'Scan history',
  },
  'land_nirs_loading': {
    'hr': 'Učitavanje Sentinel-2 NIRS/NDVI podataka…',
    'de': 'Sentinel-2 NIRS/NDVI-Daten werden geladen…',
    'en': 'Loading Sentinel-2 NIRS/NDVI data…',
  },
  'guide_land_nirs_quota_title': {
    'hr': 'NIRS mjesečni limit',
    'de': 'NIRS-Monatslimit',
    'en': 'NIRS monthly limit',
  },
  'guide_land_nirs_quota_body': {
    'hr':
        'Ovdje pratite koliko vam je preostalo dostupnih NIRS satelitskih nadzora za ovaj mjesec unutar vašeg paketa. Povijest vaših iscrtanih parcela sustav čuva točno godinu dana.',
    'de':
        'Hier sehen Sie, wie viele NIRS-Satellitenüberwachungen Ihnen in diesem Monat in Ihrem Paket noch verbleiben. Der Verlauf Ihrer eingezeichneten Parzellen wird genau ein Jahr gespeichert.',
    'en':
        'Track how many NIRS satellite monitoring sessions remain this month in your package. The system keeps your drawn parcel history for exactly one year.',
  },
  'guide_profile_animals_title': {
    'hr': 'Moje životinje',
    'de': 'Meine Tiere',
    'en': 'My animals',
  },
  'guide_profile_animals_body': {
    'hr':
        'Uđite ovdje da otvorite digitalne medicinske kartone, pratite vakcinaciju stoke i vodite kompletnu evidenciju.',
    'de':
        'Klicken Sie hier, um digitale Krankenakten zu öffnen, Impfungen zu verfolgen und den gesamten Viehbestand zu verwalten.',
    'en':
        'Tap here to open digital health records, track vaccinations, and manage your full livestock registry.',
  },
  'guide_animals_list_title': {
    'hr': 'Popis stoke',
    'bs': 'Popis stoke',
    'de': 'Viehliste',
    'en': 'Animal list',
  },
  'guide_animals_list_body': {
    'hr':
        'Ovdje vidite sve vaše životinje razvrstane po vrstama, brojevima i kategorijama.',
    'bs':
        'Ovdje vidite sve vaše životinje razvrstane po vrstama, brojevima i kategorijama.',
    'de':
        'Hier sehen Sie all Ihre Tiere sortiert nach Art, Nummern und Kategorien.',
    'en':
        'Here you see all your animals sorted by species, numbers, and categories.',
  },
  'guide_animals_records_title': {
    'hr': 'Zdravstveni karton',
    'bs': 'Zdravstveni karton',
    'de': 'Gesundheitsakte',
    'en': 'Health record',
  },
  'guide_animals_records_body': {
    'hr':
        'Ovdje pratite važne podatke, preglede veterinara i povijest cijepljenja za svako pojedino grlo.',
    'bs':
        'Ovdje pratite važne podatke, preglede veterinara i povijest cijepljenja za svako pojedino grlo.',
    'de':
        'Hier überwachen Sie wichtige Daten, Tierarztuntersuchungen und den Impfverlauf für jedes einzelne Tier.',
    'en':
        'Track important data, vet check-ups, and vaccination history for each animal here.',
  },
  'guide_animals_add_title': {
    'hr': 'Unos životinje',
    'bs': 'Unos životinje',
    'de': 'Tier hinzufügen',
    'en': 'Add animal',
  },
  'guide_animals_add_body': {
    'hr':
        'Kliknite na ovaj zeleni plus kako biste otvorili formu i registrirali novo grlo u svoju bazu.',
    'bs':
        'Kliknite na ovaj zeleni plus kako biste otvorili formu i registrirali novo grlo u svoju bazu.',
    'de':
        'Klicken Sie auf dieses grüne Plus, um das Formular zu öffnen und ein neues Tier in Ihrer Datenbank zu registrieren.',
    'en':
        'Tap this green plus to open the form and register a new animal in your database.',
  },
  'guide_add_animal_photo_title': {
    'hr': 'Fotografija',
    'bs': 'Fotografija',
    'de': 'Tierfoto',
    'en': 'Photo',
  },
  'guide_add_animal_photo_body': {
    'hr':
        'Kliknite ovdje da uslikate životinju kamerom ili izaberete sliku iz galerije radi lakšeg prepoznavanja.',
    'bs':
        'Kliknite ovdje da uslikate životinju kamerom ili izaberete sliku iz galerije radi lakšeg prepoznavanja.',
    'de':
        'Klicken Sie hier, um das Tier mit der Kamera zu fotografieren oder ein Bild aus der Galerie auszuwählen.',
    'en':
        'Tap here to take a photo with the camera or pick an image from the gallery for easier identification.',
  },
  'guide_add_animal_identity_title': {
    'hr': 'Identitet životinje',
    'bs': 'Identitet životinje',
    'de': 'Tieridentität',
    'en': 'Animal identity',
  },
  'guide_add_animal_identity_body': {
    'hr':
        'Upišite ime životinje ili broj ušne markice, a ispod izaberite vrstu stoke iz padajućeg izbornika.',
    'bs':
        'Upišite ime životinje ili broj ušne markice, a ispod izaberite vrstu stoke iz padajućeg izbornika.',
    'de':
        'Geben Sie den Namen oder die Ohrmarkennummer ein und wählen Sie darunter die Tierart aus.',
    'en':
        'Enter the animal name or ear-tag number, then choose the livestock type from the dropdown below.',
  },
  'guide_add_animal_health_title': {
    'hr': 'Zdravstveni podaci',
    'bs': 'Zdravstveni podaci',
    'de': 'Gesundheitsdaten',
    'en': 'Health data',
  },
  'guide_add_animal_health_body': {
    'hr':
        'Unesite starost životinje, a u veliko polje upišite medicinske bilješke, povijest cijepljenja ili savjete veterinara.',
    'bs':
        'Unesite starost životinje, a u veliko polje upišite medicinske bilješke, povijest cijepljenja ili savjete veterinara.',
    'de':
        'Geben Sie das Alter des Tieres ein und tragen Sie in das große Feld medizinische Notizen oder Impfungen ein.',
    'en':
        'Enter the animal age and use the large field for medical notes, vaccination history, or vet advice.',
  },
  'guide_add_animal_documents_title': {
    'hr': 'Veterinarski dokumenti',
    'bs': 'Veterinarski dokumenti',
    'de': 'Tierarztunterlagen',
    'en': 'Vet documents',
  },
  'guide_add_animal_documents_body': {
    'hr':
        'Ovdje kliknite ako želite uslikati i priložiti papire od veterinara, knjižicu cijepljenja ili nalaze za ovu životinju.',
    'bs':
        'Ovdje kliknite ako želite uslikati i priložiti papire od veterinara, knjižicu cijepljenja ili nalaze za ovu životinju.',
    'de':
        'Klicken Sie hier, um Tierarztpapiere, Impfpässe oder Befunde für dieses Tier zu fotografieren und anzuhängen.',
    'en':
        'Tap here to photograph and attach vet papers, vaccination records, or medical reports for this animal.',
  },
  'guide_add_animal_save_title': {
    'hr': 'Spremanje podataka',
    'bs': 'Spremanje podataka',
    'de': 'Speichern',
    'en': 'Save data',
  },
  'guide_add_animal_save_body': {
    'hr':
        'Kliknite na ovaj gumb da trajno spremite podatke i otvorite digitalni zdravstveni karton životinje.',
    'bs':
        'Kliknite na ovaj gumb da trajno spremite podatke i otvorite digitalni zdravstveni karton životinje.',
    'de':
        'Klicken Sie auf diese Schaltfläche, um die Daten dauerhaft zu speichern und die digitale Krankenakte des Tieres zu öffnen.',
    'en':
        'Tap this button to permanently save the data and open the animal digital health record.',
  },
  'guide_ai_history_title': {
    'hr': 'Povijest skeniranja',
    'de': 'Scan-Verlauf',
    'en': 'Scan history',
    'pl': 'Historia skanów',
  },
  'guide_ai_history_body': {
    'hr':
        'Ovdje kliknite kako biste otvorili povijest svojih ranijih skeniranja. Sustav čuva vaše stare nalaze i prepoznate bolesti biljaka točno godinu dana.',
    'de':
        'Klicken Sie hier, um den Verlauf Ihrer früheren Scans zu öffnen. Das System speichert Ihre alten Befunde und erkannten Pflanzenkrankheiten genau ein Jahr lang.',
    'en':
        'Tap here to open your past scan history. The system keeps your old findings and recognized plant diseases for exactly one year.',
  },
  'guide_ai_quota_title': {
    'hr': 'Mjesečni limit',
    'de': 'Monatslimit',
    'en': 'Monthly limit',
  },
  'guide_ai_quota_body': {
    'hr':
        'Ovdje pratite koliko vam je preostalo dostupnih skeniranja za ovaj mjesec unutar vašeg paketa.',
    'de':
        'Hier können Sie sehen, wie viele verfügbare Scans Ihnen für diesen Monat in Ihrem Paket noch verbleiben.',
    'en':
        'Track how many available scans remain this month within your package.',
  },
  'guide_ai_image_window_title': {
    'hr': 'Prozor za fotografiju',
    'de': 'Fotofenster',
    'en': 'Photo window',
  },
  'guide_ai_image_window_body': {
    'hr':
        'Kliknite izravno na ovaj veliki prozor kako biste pokrenuli kameru i uslikali bolesni list ili odabrali sliku iz galerije telefona.',
    'de':
        'Tippen Sie direkt auf dieses große Fenster, um die Kamera zu starten und ein krankes Blatt zu fotografieren oder ein Bild aus der Galerie auszuwählen.',
    'en':
        'Tap this large window to open the camera and photograph a diseased leaf or pick an image from your gallery.',
  },
  'guide_ai_analyze_title': {
    'hr': 'Analiziraj fotografiju',
    'de': 'Foto analysieren',
    'en': 'Analyze photo',
  },
  'guide_ai_analyze_body': {
    'hr':
        'Nakon što učitate fotografiju, kliknite ovdje kako bi umjetna inteligencija u sekundi prepoznala bolest i ponudila vam točan lijek i rješenje.',
    'de':
        'Nachdem Sie ein Foto hochgeladen haben, klicken Sie hier, damit die KI die Krankheit in Sekunden erkennt und Ihnen die richtige Behandlung vorschlägt.',
    'en':
        'After uploading a photo, tap here for AI to recognize the disease in seconds and suggest the right treatment.',
  },
  'guide_community_feed_title': {
    'hr': 'Seoski zid',
    'de': 'Dorf-Pinnwand',
    'en': 'Village wall',
    'pl': 'Tablica wiejska',
    'fr': 'Mur du village',
    'es': 'Muro del pueblo',
    'it': 'cinta muraria',
    'cs': 'Vesnická zeď',
    'sv': 'Byvägg',
    'uk': 'Сільська стіна',
    'ru': 'Деревенская стена',
    'hi': 'गाँव की दीवार',
    'id': 'Dinding desa',
    'sw': 'Ukuta wa kijiji',
    'ar': 'جدار القرية',
    'tr': 'Köy duvarı',
    'zh': '乡村墙',
    'sr': 'Seoski zid',
  },
  'guide_community_feed_body': {
    'hr':
        'Ovdje pratite objave iz naše zajednice. Farmeri i kupci ovdje dijele prelijepe trenutke sela, slike svojih vrtova, biljaka i domaćih životinja.',
    'de':
        'Hier verfolgen Sie Beiträge aus unserer Gemeinschaft. Landwirte und Käufer teilen schöne Dorfmomente, Bilder ihrer Gärten, Pflanzen und Haustiere.',
    'en':
        'Follow posts from our community here. Farmers and buyers share beautiful village moments, pictures of their gardens, plants, and farm animals.',
    'pl':
        'Tutaj śledzisz posty ze społeczności. Rolnicy i kupujący dzielą się pięknymi chwilami z wsi, ogrodów i gospodarstw.',
    'fr':
        'Ici, vous suivez les publications de la communauté — de beaux moments de fermes et de jardins.',
    'es':
        'Aquí sigues las publicaciones de la comunidad — momentos bonitos de granjas y jardines.',
    'it':
        'Qui segui i post della community: momenti meravigliosi da fattorie e giardini.',
    'cs': 'Zde sledujete příspěvky komunity — krásné momenty z farem a zahrad.',
    'sv':
        'Här följer du inlägg från gemenskapen — vackra stunder från gårdar och trädgårdar.',
    'uk':
        'Тут ви стежите за публікаціями спільноти — гарними моментами з ферм і садів.',
    'ru':
        'Здесь вы следите за публикациями сообщества — красивыми моментами с ферм и садов.',
    'hi': 'यहाँ समुदाय की पोस्ट देखें — खेतों और बगीचों के सुंदर पल।',
    'id':
        'Di sini Anda mengikuti postingan komunitas — momen indah dari peternakan dan kebun.',
    'sw':
        'Hapa unafuatilia machapisho ya jumuiya — matukio mazuri kutoka mashamba na bustani.',
    'ar': 'هنا تتابع منشورات المجتمع — لحظات جميلة من المزارع والحدائق.',
    'tr':
        'Burada çiftliklerden ve bahçelerden güzel anlar içeren topluluk gönderilerini takip edeceksiniz.',
    'zh': '在这里关注社区帖子 — 农场和花园的美好时刻。',
    'sr':
        'Ovde pratite objave iz naše zajednice. Farmeri i kupci ovde dele prelepe trenutke sela, slike svojih vrtova, biljaka i domaćih životinja.',
  },
  'guide_community_add_post_title': {
    'hr': 'Podijeli trenutak',
    'de': 'Moment teilen',
    'en': 'Share a moment',
    'pl': 'Podziel się chwilą',
    'fr': 'Partager un moment',
    'es': 'Comparte un momento',
    'it': 'Condividi un momento',
    'cs': 'Sdílet moment',
    'sv': 'Dela ett ögonblick',
    'uk': 'Поділіться моментом',
    'ru': 'Поделиться моментом',
    'hi': 'पल साझा करें',
    'id': 'Bagikan momen',
    'sw': 'Shiriki tukio',
    'ar': 'شارك لحظة',
    'tr': 'Bir dakikanızı paylaşın',
    'zh': '分享瞬间',
    'sr': 'Podeli trenutak',
  },
  'guide_community_add_post_body': {
    'hr':
        'Kliknite na ovu ikonu kamere ako i vi želite uslikali i podijeliti lijep trenutak iz svog vrta, plastenika ili sela s cijelom zajednicom.',
    'de':
        'Tippen Sie auf dieses Kamera-Symbol, wenn Sie einen schönen Moment aus Ihrem Garten, Gewächshaus oder Dorf mit der ganzen Gemeinschaft teilen möchten.',
    'en':
        'Tap this camera icon if you want to capture and share a lovely moment from your garden, greenhouse, or village with the whole community.',
    'pl':
        'Kliknij ikonę aparatu, aby dodać zdjęcie z ogrodu, szklarni lub farmy i podzielić się nim ze społecznością.',
    'fr':
        'Appuyez sur l\'icône appareil photo pour partager une photo de votre jardin ou de votre ferme.',
    'es':
        'Pulsa el icono de la cámara para compartir una foto de tu jardín o granja.',
    'it':
        'Tocca l\'icona della fotocamera per condividere una foto del tuo giardino o della tua fattoria.',
    'cs':
        'Klepněte na ikonu fotoaparátu a sdílejte fotku ze své zahrady nebo farmy.',
    'sv':
        'Tryck på kameraikonen för att dela ett foto från din trädgård eller gård.',
    'uk': 'Натисніть на іконку камери, щоб поділитися фото свого саду чи ферми.',
    'ru': 'Нажмите на иконку камеры, чтобы поделиться фото своего сада или фермы.',
    'hi': 'अपने बगीचे या खेत की फ़ोटो साझा करने के लिए कैमरा आइकन टैप करें।',
    'id': 'Ketuk ikon kamera untuk membagikan foto kebun atau peternakan Anda.',
    'sw': 'Gusa ikoni ya kamera kushiriki picha ya bustani au shamba lako.',
    'ar': 'اضغط على أيقونة الكاميرا لمشاركة صورة حديقتك أو مزرعتك.',
    'tr':
        'Bahçenizin veya çiftliğinizin bir fotoğrafını paylaşmak için kamera simgesine dokunun.',
    'zh': '点击相机图标，分享您花园或农场的照片。',
    'sr':
        'Kliknite na ovu ikonu kamere ako i vi želite da uslikate i podelite lep trenutak iz svog vrta, plastenika ili sela sa celom zajednicom.',
  },
  'guide_community_pagination_title': {
    'hr': 'Navigacija objava',
    'de': 'Beitragsnavigation',
    'en': 'Post navigation',
    'pl': 'Nawigacja postów',
    'fr': 'Navigation des publications',
    'es': 'Navegación de publicaciones',
    'it': 'Posta navigazione',
    'cs': 'Navigace příspěvků',
    'sv': 'Inläggsnavigering',
    'uk': 'Навігація публікаціями',
    'ru': 'Навигация по публикациям',
    'hi': 'पोस्ट नेविगेशन',
    'id': 'Navigasi postingan',
    'sw': 'Urambazaji wa machapisho',
    'ar': 'تصفح المنشورات',
    'tr': 'Gönderi navigasyonu',
    'zh': '帖子导航',
    'sr': 'Navigacija objava',
  },
  'guide_community_pagination_body': {
    'hr':
        'Koristite ove brojeve na dnu kako biste se jednostavno prebacivali s jedne stranice seoskih objava na drugu.',
    'de':
        'Nutzen Sie diese Zahlen unten, um einfach von einer Seite Dorfbeiträge zur nächsten zu wechseln.',
    'en':
        'Use these numbers at the bottom to easily switch from one page of village posts to another.',
    'pl':
        'Użyj numerów na dole, aby przechodzić między stronami postów społeczności.',
    'fr':
        'Utilisez les numéros ci-dessous pour passer d\'une page de publications à l\'autre.',
    'es': 'Usa los números abajo para pasar de una página de publicaciones a otra.',
    'it':
        'Utilizza i numeri sottostanti per spostarti da una pagina di post all\'altra.',
    'cs': 'Pomocí čísel dole přepínáte stránky příspěvků.',
    'sv': 'Använd siffrorna längst ned för att bläddra mellan sidor med inlägg.',
    'uk': 'Використовуйте цифри внизу для переходу між сторінками публікацій.',
    'ru': 'Используйте цифры внизу для перехода между страницами публикаций.',
    'hi': 'पोस्ट पृष्ठों के बीच जाने के लिए नीचे संख्याएँ उपयोग करें।',
    'id': 'Gunakan angka di bawah untuk berpindah antar halaman postingan.',
    'sw': 'Tumia nambari chini kubadilisha kurasa za machapisho.',
    'ar': 'استخدم الأرقام في الأسفل للتنقل بين صفحات المنشورات.',
    'tr': 'Bir yayın sayfasından diğerine gitmek için aşağıdaki sayıları kullanın.',
    'zh': '使用下方的数字在不同页面的帖子之间切换。',
    'sr':
        'Koristite ove brojeve na dnu kako biste se jednostavno prebacivali sa jedne stranice seoskih objava na drugu.',
  },
  'farmer_welcome_title': {
    'hr': 'Zdravo! Ja sam tvoj Pomoćnik',
    'de': 'Hallo! Ich bin dein Assistent',
    'en': 'Hello! I am your assistant',
  },
  'farmer_welcome_body': {
    'hr':
        'Tu sam da te vodim kroz aplikaciju. Kada god ti zatreba objašnjenje na bilo kojem ekranu, samo klikni na moju ikonu u gornjem kutu.',
    'de':
        'Ich bin hier, um dich kroz die App zu führen. Wann immer du auf einem Bildschirm eine Erklärung brauchst, klicke einfach auf mein Icon in der oberen Ecke.',
    'en':
        'I am here to guide you through the app. Whenever you need an explanation on any screen, just tap my icon in the top corner.',
  },
  'farmer_welcome_start': {
    'hr': 'Krećemo na put!',
    'de': "Auf geht's!",
    'en': "Let's go!",
  },
  'paywall_pro_price': {
    'hr': '9,99 KM / 9,99 € mjesečno',
    'de': '9,99 KM / 9,99 € pro Monat',
    'en': '9.99 KM / €9.99 per month',
  },
  'land_premium_title': {
    'hr': 'Premium Pro Paket',
    'de': 'Premium Pro Paket',
    'en': 'Premium Pro Package',
  },
  'land_premium_desc': {
    'hr':
        'Aktivirajte Premium Pro za 9,99 € mjesečno. Do 50 parcela s punim NIRS/NDVI satelitskim nadzorom, Agro-Alarmi za nepogode iznad vaših njiva, do 500 životinja stoke s privitcima dokumenata i 60 AI skeniranja mjesečno!',
    'de':
        'Aktivieren Sie Premium Pro für 9,99 € im Monat. Bis zu 50 Parzellen mit vollem NIRS/NDVI-Satellitenmonitoring, Agro-Alarme für Unwetter über Ihren Feldern, bis zu 500 Nutztiere mit Dokumentenanhängen und 60 KI-Scans monatlich!',
    'en':
        'Activate Premium Pro for €9.99 per month. Up to 50 parcels with full NIRS/NDVI satellite monitoring, Agro-Alarms for severe weather over your fields, up to 500 livestock with document attachments, and 60 AI scans per month!',
  },
  'land_premium_activate': {
    'hr': 'Aktiviraj Premium Pro',
    'de': 'Premium Pro aktivieren',
    'en': 'Activate Premium Pro',
  },
  'land_profile_title': {
    'hr': 'Satelitsko mjerenje parcela',
    'bs': 'Satelitsko mjerenje parcela',
    'sr': 'Satelitsko merenje parcela',
    'de': 'Satellitenmessung von Parzellen',
    'en': 'Satellite parcel measurement',
    'tr': 'Uydu ile parsel ölçümü',
    'it': 'Misurazione parcelle via satellite',
    'fr': 'Mesure parcellaire par satellite',
    'es': 'Medición de parcelas por satélite',
    'pl': 'Pomiar działek satelitarny',
    'sv': 'Satellitmätning av skiften',
    'cs': 'Satelitní měření parcel',
    'ru': 'Спутниковое измерение участков',
    'uk': 'Супутникове вимірювання ділянок',
    'zh': '卫星地块测量',
    'ar': 'قياس القطع الأرضية بالأقمار الصناعية',
  },
  'land_profile_subtitle': {
    'hr': 'Ucrtajte granice vašeg zemljišta i izračunajte hektare',
    'bs': 'Ucrtajte granice vašeg zemljišta i izračunajte hektare',
    'sr': 'Iscrtajte granice vašeg zemljišta i izračunajte hektare',
    'de': 'Zeichnen Sie Grenzen und berechnen Sie die Hektar',
    'en': 'Draw your land boundaries and calculate hectares',
    'tr': 'Arazi sınırlarınızı çizin ve hektarları hesaplayın',
    'it': 'Disegna i confini del tuo terreno e calcola gli ettari',
    'fr': 'Tracez les limites de votre terrain et calculez les hectares',
    'es': 'Dibuja los límites de tu terreno y calcula los hectáreas',
    'pl': 'Narysuj granice swojego gruntu i oblicz hektary',
    'sv': 'Rita dina markgränser och beräkna hektar',
    'cs': 'Nakreslete hranice pozemku a vypočítejte hektary',
    'ru': 'Нарисуйте границы вашего земельного участка и рассчитайте гектары',
    'uk': 'Намалюйте межі вашої землі та розрахуйте гектари',
    'zh': '绘制土地边界并计算公顷面积',
    'ar': 'ارسم حدود أرضك واحسب الهكتارات',
  },
  'land_title': {
    'hr': 'Moje parcele',
    'bs': 'Moje parcele',
    'sr': 'Moje parcele',
    'de': 'Meine Parzellen',
    'en': 'My parcels',
  },
  'land_close_parcel': {
    'hr': 'Zatvori parcelu',
    'bs': 'Zatvori parcelu',
    'sr': 'Zatvori parcelu',
    'de': 'Parzelle schließen',
    'en': 'Close parcel',
  },
  'land_clear_all': {
    'hr': 'Očisti sve',
    'bs': 'Očisti sve',
    'sr': 'Obriši sve',
    'de': 'Alles löschen',
    'en': 'Clear all',
  },
  'land_draw_hint': {
    'hr': 'Ucrtajte najmanje 3 točke i zatvorite parcelu za izračun površine.',
    'bs': 'Ucrtajte najmanje 3 točke i zatvorite parcelu za izračun površine.',
    'sr': 'Iscrtajte najmanje 3 tačke i zatvorite parcelu za izračun površine.',
    'de': 'Zeichnen Sie mindestens 3 Punkte und schließen Sie die Parzelle, um die Fläche zu berechnen.',
    'en': 'Draw at least 3 points and close the parcel to calculate area.',
  },
  'land_save': {
    'hr': 'Spremi parcelu',
    'bs': 'Spremi parcelu',
    'sr': 'Sačuvaj parcelu',
    'de': 'Parzelle speichern',
    'en': 'Save parcel',
  },
  'land_saved_parcels': {
    'hr': 'Spremljene parcele',
    'bs': 'Spremljene parcele',
    'sr': 'Sačuvane parcele',
    'de': 'Gespeicherte Parzellen',
    'en': 'Saved parcels',
  },
  'land_tap_hint': {
    'hr': 'Dodirnite kartu da postavite točke. Povucite marker da precizno pomjerite granicu.',
    'de': 'Tippen Sie auf die Karte, um Punkte zu setzen. Ziehen Sie Marker, um Grenzen präzise anzupassen.',
    'en': 'Tap the map to place points. Drag markers to adjust boundaries precisely.',
  },
  'land_closed_hint': {
    'hr': 'Parcela je zatvorena. Povucite točke za finu korekciju granica.',
    'de': 'Parzelle ist geschlossen. Ziehen Sie Punkte, um Grenzen fein anzupassen.',
    'en': 'Parcel is closed. Drag points to fine-tune boundaries.',
  },
  'land_nirs_button': {
    'hr': 'Multispektralni NIRS/NDVI nadzor',
    'de': 'Multispektraler NIRS/NDVI-Monitor',
    'en': 'Multispectral NIRS/NDVI monitoring',
  },
  'land_map_compact_hint': {
    'hr': 'Dodirnite kartu za crtanje preko cijelog ekrana.',
    'de': 'Tippen Sie auf die Karte, um im Vollbild zu zeichnen.',
    'en': 'Tap the map to draw on full screen.',
  },
  'paywall_buyer_title': {
    'hr': 'Kupac Premium',
    'de': 'Käufer Premium',
    'en': 'Buyer Premium',
  },
  'paywall_buyer_price': {
    'hr': '1,99 KM / 1,99 € mjesečno',
    'de': '1,99 KM / 1,99 € pro Monat',
    'en': '1.99 KM / €1.99 per month',
  },
  'paywall_buyer_features': {
    'hr':
        'Rezervacija robe u dolasku u košarici, do 10 kućnih ljubimaca (psi, mačke...), 15 AI skeniranja mjesečno.',
    'de':
        'Vorbestellung in der Warenkorb, bis zu 10 Haustiere, 15 KI-Scans pro Monat.',
    'en':
        'Upcoming product reservation in cart, up to 10 pets, 15 AI scans per month.',
  },
  'paywall_hobby_title': {
    'hr': 'Hobi Farmer Premium',
    'de': 'Hobby-Farmer Premium',
    'en': 'Hobby Farmer Premium',
  },
  'paywall_hobby_price': {
    'hr': '3,99 KM / 3,99 € mjesečno',
    'de': '3,99 KM / 3,99 € pro Monat',
    'en': '3.99 KM / €3.99 per month',
  },
  'paywall_hobby_features': {
    'hr':
        'Satelitsko mjerenje parcela, NIRS/NDVI nadzor (20/mj), do 5 parcela, do 20 životinja, 30 AI skeniranja/mj, rezervacija u dolasku. Prodaja ostaje na 5 artikala.',
    'de':
        'Satelliten-Parzellenmessung, NIRS/NDVI-Monitoring (20/Monat), bis zu 5 Parzellen, bis zu 20 Tiere, 30 KI-Scans/Monat, Vorbestellung. Verkauf bleibt bei 5 Artikeln.',
    'en':
        'Satellite parcel measurement, NIRS/NDVI monitoring (20/mo), up to 5 parcels, 20 animals, 30 AI scans/mo, upcoming reservation. Selling stays at 5 products.',
  },
  'paywall_hobby_features_intro': {
    'hr': 'U pretplati je uključeno:',
    'bs': 'U pretplati je uključeno:',
    'sr': 'U pretplati je uključeno:',
    'de': 'Im Abo enthalten:',
    'en': 'Included in your subscription:',
    'pl': 'W subskrypcji:',
    'cs': 'V předplatném:',
    'es': 'Incluido en la suscripción:',
    'fr': 'Inclus dans l\'abonnement :',
    'it': 'Incluso nell\'abbonamento:',
  },
  'paywall_hobby_benefit_satellite': {
    'hr': 'Satelitsko mjerenje parcela — ucrtajte granice i izračunajte hektare',
    'bs': 'Satelitsko mjerenje parcela — ucrtajte granice i izračunajte hektare',
    'sr': 'Satelitsko merenje parcela — iscrtajte granice i izračunajte hektare',
    'de': 'Satelliten-Parzellenmessung — Grenzen zeichnen und Hektar berechnen',
    'en': 'Satellite parcel measurement — draw boundaries and calculate hectares',
    'pl': 'Pomiar działek satelitarny — narysuj granice i oblicz hektary',
    'cs': 'Satelitní měření parcel — nakreslete hranice a vypočítejte hektary',
    'es': 'Medición de parcelas por satélite — dibuja límites y calcula hectáreas',
    'fr': 'Mesure parcellaire par satellite — tracez les limites et calculez les hectares',
    'it': 'Misurazione parcelle via satellite — disegna i confini e calcola gli ettari',
    'tr': 'Uydu parsel ölçümü — sınırları çizin ve hektarları hesaplayın',
  },
  'paywall_hobby_benefit_nirs': {
    'hr': 'NIRS/NDVI satelitski nadzor — {count} učitavanja mjesečno',
    'de': 'NIRS/NDVI-Satellitenmonitoring — {count} Abrufe pro Monat',
    'en': 'NIRS/NDVI satellite monitoring — {count} loads per month',
  },
  'paywall_hobby_benefit_parcels': {
    'hr': 'Do {count} spremljenih parcela',
    'de': 'Bis zu {count} gespeicherte Parzellen',
    'en': 'Up to {count} saved parcels',
  },
  'paywall_hobby_benefit_animals': {
    'hr': 'Do {count} životinja u digitalnom kartonu',
    'de': 'Bis zu {count} Tiere im digitalen Karton',
    'en': 'Up to {count} animals in digital records',
  },
  'paywall_hobby_benefit_products': {
    'hr': 'Do {count} proizvoda u izlogu',
    'de': 'Bis zu {count} Produkte im Schaufenster',
    'en': 'Up to {count} products in your storefront',
  },
  'paywall_hobby_benefit_reservation': {
    'hr': 'Rezervacija robe u dolasku i plaćanje karticom',
    'de': 'Vorbestellung und Kartenzahlung im Warenkorb',
    'en': 'Upcoming product reservation and card checkout',
  },
  'paywall_pro_features_intro': {
    'hr': 'U pretplati je uključeno:',
    'bs': 'U pretplati je uključeno:',
    'sr': 'U pretplati je uključeno:',
    'de': 'Im Abo enthalten:',
    'en': 'Included in your subscription:',
    'pl': 'W subskrypcji:',
    'cs': 'V předplatném:',
    'es': 'Incluido en la suscripción:',
    'fr': 'Inclus dans l\'abonnement :',
    'it': 'Incluso nell\'abbonamento:',
    'tr': 'Aboneliğe dahil:',
  },
  'paywall_pro_benefit_satellite': {
    'hr': 'Satelitsko mjerenje parcela — ucrtajte granice i izračunajte hektare',
    'bs': 'Satelitsko mjerenje parcela — ucrtajte granice i izračunajte hektare',
    'sr': 'Satelitsko merenje parcela — iscrtajte granice i izračunajte hektare',
    'de': 'Satelliten-Parzellenmessung — Grenzen zeichnen und Hektar berechnen',
    'en': 'Satellite parcel measurement — draw boundaries and calculate hectares',
    'pl': 'Pomiar działek satelitarny — narysuj granice i oblicz hektary',
    'cs': 'Satelitní měření parcel — nakreslete hranice a vypočítejte hektary',
    'es': 'Medición de parcelas por satélite — dibuja límites y calcula hectáreas',
    'fr': 'Mesure parcellaire par satellite — tracez les limites et calculez les hectares',
    'it': 'Misurazione parcelle via satellite — disegna i confini e calcola gli ettari',
    'tr': 'Uydu parsel ölçümü — sınırları çizin ve hektarları hesaplayın',
  },
  'paywall_pro_benefit_nirs': {
    'hr': 'Puni NIRS/NDVI satelitski nadzor — {count} učitavanja mjesečno',
    'de': 'Volles NIRS/NDVI-Satellitenmonitoring — {count} Abrufe pro Monat',
    'en': 'Full NIRS/NDVI satellite monitoring — {count} loads per month',
  },
  'paywall_pro_benefit_parcels': {
    'hr': 'Do {count} spremljenih parcela s punim nadzorom',
    'de': 'Bis zu {count} gespeicherte Parzellen mit vollem Monitoring',
    'en': 'Up to {count} saved parcels with full monitoring',
  },
  'paywall_pro_benefit_animals': {
    'hr': 'Do {count} životinja s dokumentima u digitalnom kartonu',
    'de': 'Bis zu {count} Tiere mit Dokumenten im digitalen Karton',
    'en': 'Up to {count} animals with documents in digital records',
  },
  'paywall_pro_benefit_agro_alarms': {
    'hr': 'Agro-Alarmi za zdravlje usjeva i vremenske upozorenja',
    'de': 'Agro-Alarme für Pflanzengesundheit und Wetterwarnungen',
    'en': 'Agro-Alarms for crop health and weather alerts',
  },
  'paywall_pro_benefit_selling': {
    'hr': 'Neograničen broj proizvoda u izlogu — besplatna prodaja uključena',
    'de': 'Unbegrenzte Produkte im Schaufenster — kostenloser Verkauf inklusive',
    'en': 'Unlimited products in your storefront — free selling included',
  },
  'paywall_pro_title': {
    'hr': 'Profesionalni Farmer Premium Pro',
    'de': 'Professioneller Farmer Premium Pro',
    'en': 'Professional Farmer Premium Pro',
  },
  'paywall_pro_features': {
    'hr':
        '50 parcela s punim NIRS/NDVI nadzorom, Agro-Alarmi, do 500 životinja s dokumentima, 60 AI skeniranja/mj. Besplatna neograničena prodaja ostaje.',
    'de':
        '50 Parzellen mit vollem NIRS/NDVI, Agro-Alarme, bis zu 500 Tiere mit Dokumenten, 60 KI-Scans/Monat. Unbegrenzter kostenloser Verkauf bleibt.',
    'en':
        '50 parcels with full NIRS/NDVI, Agro-Alarms, up to 500 animals with documents, 60 AI scans/mo. Free unlimited selling remains.',
  },
  'premium_upcoming_title': {
    'hr': 'Premium — Rezervacija u dolasku',
    'de': 'Premium — Vorbestellung',
    'en': 'Premium — Upcoming reservation',
  },
  'premium_upcoming_desc': {
    'hr':
        'Aktivirajte Premium paket (Kupac 1,99 € ili Hobi 3,99 € mjesečno) kako biste rezervirali robu u dolasku i platili karticom u košarici.',
    'de':
        'Aktivieren Sie Premium (Käufer 1,99 € oder Hobby 3,99 €/Monat), um Ware in Vorbereitung zu reservieren und per Karte zu bezahlen.',
    'en':
        'Activate Premium (Buyer €1.99 or Hobby €3.99/month) to reserve upcoming products and pay by card in the cart.',
  },
  'land_parcel_limit_reached': {
    'hr': 'Dosegnut limit parcela za vaš paket. Nadogradite Premium za više parcela.',
    'de': 'Parzellenlimit für Ihr Paket erreicht. Upgraden Sie Premium für mehr Parzellen.',
    'en': 'Parcel limit reached for your plan. Upgrade Premium for more parcels.',
  },
  'land_parcel_limit_title': {
    'hr': 'Limit parcela',
    'de': 'Parzellenlimit',
    'en': 'Parcel limit',
  },
  'land_parcel_premium_required_hobby': {
    'hr':
        'Besplatno možete spremiti 1 parcelu. Za daljnje spremanje aktivirajte Hobi Farmer Premium — do {count} spremljenih parcela, satelitsko mjerenje i NIRS nadzor.',
    'de':
        'Kostenlos ist 1 Parzelle speicherbar. Für weitere Parzellen aktivieren Sie Hobby-Farmer Premium — bis zu {count} Parzellen, Satellitenmessung und NIRS.',
    'en':
        'You can save 1 parcel for free. To save more, activate Hobby Farmer Premium — up to {count} parcels, satellite measurement and NIRS monitoring.',
  },
  'land_parcel_premium_required_pro': {
    'hr':
        'Besplatno možete spremiti 1 parcelu. Za daljnje spremanje aktivirajte Pro Farmer Premium — do {count} spremljenih parcela s punim NIRS nadzorom.',
    'de':
        'Kostenlos ist 1 Parzelle speicherbar. Für weitere Parzellen aktivieren Sie Pro-Farmer Premium — bis zu {count} Parzellen mit vollem NIRS-Monitoring.',
    'en':
        'You can save 1 parcel for free. To save more, activate Pro Farmer Premium — up to {count} parcels with full NIRS monitoring.',
  },
  'land_parcel_limit_max': {
    'hr': 'Dosegnuli ste maksimum od {count} spremljenih parcela u vašem paketu.',
    'de': 'Sie haben das Maximum von {count} gespeicherten Parzellen in Ihrem Paket erreicht.',
    'en': 'You have reached the maximum of {count} saved parcels in your plan.',
  },
  'premium_pending_banner': {
    'hr': 'Premium pretplata čeka odobrenje licence od administratora. Besplatne funkcije ostaju aktivne.',
    'bs': 'Premium pretplata čeka odobrenje licence od administratora. Besplatne funkcije ostaju aktivne.',
    'sr': 'Premium pretplata čeka odobrenje licence od administratora. Besplatne funkcije ostaju aktivne.',
    'de': 'Premium-Abo wartet auf Admin-Freigabe der Lizenz. Kostenlose Funktionen bleiben aktiv.',
    'en': 'Premium subscription awaits admin license approval. Free features remain active.',
    'es': 'La suscripción Premium espera la aprobación de la licencia por el administrador. Las funciones gratuitas siguen activas.',
    'fr': "L'abonnement Premium attend l'approbation de la licence par l'administrateur. Les fonctionnalités gratuites restent actives.",
    'cs': 'Premium předplatné čeká na schválení licence administrátorem. Bezplatné funkce zůstávají aktivní.',
    'zh': '高级版订阅正在等待管理员批准许可证。免费功能仍然可用。',
    'sv': 'Premium-prenumerationen väntar på administratörens godkännande av licensen. Gratis funktioner förblir aktiva.',
    'uk': 'Premium-підписка очікує схвалення ліцензії адміністратором. Безкоштовні функції залишаються активними.',
    'ru': 'Premium-подписка ожидает одобрения лицензии администратором. Бесплатные функции остаются активными.',
    'hi': 'Premium सदस्यता व्यवस्थापक लाइसेंस अनुमोदन की प्रतीक्षा में है। मुफ़्त सुविधाएँ सक्रिय रहती हैं।',
    'id': 'Langganan Premium menunggu persetujuan lisensi admin. Fitur gratis tetap aktif.',
    'sw': 'Usajili wa Premium unasubiri idhini ya leseni kutoka kwa msimamizi. Vipengele vya bila malipo vinaendelea kuwa vinavyofanya kazi.',
    'ar': 'اشتراك Premium في انتظار موافقة المسؤول على الترخيص. الميزات المجانية تبقى نشطة.',
    'it': 'L\'abbonamento Premium attende l\'approvazione della licenza da parte dell\'amministratore. Le funzioni gratuite restano attive.',
    'tr': 'Premium abonelik yönetici lisans onayını bekliyor. Ücretsiz özellikler aktif kalır.',
  },
  'paywall_vet_title': {
    'hr': 'Veterinar Premium',
    'de': 'Tierarzt Premium',
    'pl': 'Premium Weterynarz',
    'sv': 'Premium Veterinär',
    'cs': 'Licence veterináře',
    'es': 'Licencia de veterinario',
    'fr': 'Premium Vétérinaire',
    'en': 'Veterinarian Premium',
    'zh': '兽医许可证',
  },
  'paywall_vet_price': {
    'hr': '9,99 € mjesečno',
    'bs': '9,99 € mjesečno',
    'de': '9,99 € pro Monat',
    'pl': '9,99 € miesięcznie',
    'sv': '111,89 kr per månad',
    'cs': '9,99 € měsíčně',
    'es': '9,99 € al mes',
    'fr': '9,99 € par mois',
    'en': '€9.99 per month',
    'zh': '¥78,42 / 月',
  },
  'paywall_vet_subscribe_button': {
    'hr': 'Pretplati me — 9,99 € / mj.',
    'bs': 'Pretplati me — 9,99 € / mj.',
    'de': 'Abonnieren — 9,99 € / Monat',
    'pl': 'Subskrybuj — 9,99 € / mies.',
    'sv': 'Prenumerera — 111,89 kr / mån',
    'cs': 'Předplatit — 9,99 € / měsíc',
    'es': 'Suscribirme — 9,99 € / mes',
    'fr': 'S\'abonner — 9,99 € / mois',
    'en': 'Subscribe — €9.99 / mo',
    'zh': '订阅 — ¥78,42 / 月',
  },
  'paywall_vet_features': {
    'hr': 'Premium Veterinar 9,99 €/mj uključuje:',
    'de': 'Premium Tierarzt 9,99 €/Monat beinhaltet:',
    'pl': 'Premium Weterynarz 9,99 €/mies. obejmuje:',
    'sv': 'Premium Veterinär 111,89 kr/mån inkluderar:',
    'cs': 'Premium Veterinář 9,99 €/měsíc zahrnuje:',
    'es': 'Premium Veterinario 9,99 €/mes incluye:',
    'fr': 'Premium Vétérinaire 9,99 €/mois inclut :',
    'en': 'Veterinarian Premium €9.99/mo includes:',
    'zh': '兽医 Premium ¥78,42/月 包括：',
  },
  'paywall_vet_features_intro': {
    'hr': 'U pretplati dolazi:',
    'bs': 'U pretplati dolazi:',
    'sr': 'U pretplati dolazi:',
    'de': 'In der Premium-Version enthalten:',
    'pl': 'W subskrypcji zawarte:',
    'sv': 'I prenumerationen ingår:',
    'cs': 'V předplatném je zahrnuto:',
    'es': 'Incluido en tu suscripción:',
    'fr': 'Inclus dans votre abonnement :',
    'en': 'Included in your subscription:',
    'zh': '订阅包含：',
    'uk': 'У вашій підписці включено:',
    'ru': 'В вашей подписке включено:',
    'hi': 'आपकी सदस्यता में शामिल:',
    'id': 'Termasuk dalam langganan Anda:',
    'sw': 'Inajumuishwa katika usajili wako:',
    'ar': 'يشمل اشتراكك:',
    'it': 'Incluso nel tuo abbonamento:',
    'tr': 'Aboneliğinize dahil:',
  },
  'paywall_vet_benefit_records': {
    'hr': 'Kartoteka pacijenata — rad s klijentima i terenski kartoni',
    'bs': 'Kartoteka pacijenata — rad s klijentima i terenski kartoni',
    'sr': 'Kartoteka pacijenata — rad sa klijentima i terenski kartoni',
    'de': 'Patientenakte — Arbeit mit Kunden und Feldakten',
    'pl': 'Kartoteka pacjentów — praca z klientami i karty terenowe',
    'sv': 'Patientjournal — arbete med klienter och fältjournaler',
    'cs': 'Kartotéka pacientů — práce s klienty a terénní záznamy',
    'es': 'Historial de pacientes — trabajo con clientes y fichas de campo',
    'fr': 'Dossiers patients — travail avec clients et fiches terrain',
    'en': 'Patient records — client work and field records',
    'zh': '患者档案（客户工作与现场记录）',
    'uk': 'Картотека пацієнтів — робота з клієнтами та польові записи',
    'ru': 'Картотека пациентов — работа с клиентами и полевые записи',
    'hi': 'रोगी रिकॉर्ड — ग्राहक कार्य और क्षेत्र रिकॉर्ड',
    'id': 'Rekam medis pasien — pekerjaan klien dan catatan lapangan',
    'sw': 'Rekodi za wagonjwa — kazi na wateja na rekodi za uwanjani',
    'ar': 'سجلات المرضى — عمل العملاء والسجلات الميدانية',
    'it': 'Cartelle pazienti — lavoro con clienti e registri sul campo',
    'tr': 'Hasta kayıtları — müşteriler ve saha kayıtları',
  },
  'paywall_vet_benefit_pets': {
    'hr': 'Moji ljubimci — evidencija do 10 privatnih životinja',
    'bs': 'Moji ljubimci — evidencija do 10 privatnih životinja',
    'sr': 'Moji ljubimci — evidencija do 10 privatnih životinja',
    'de': 'Meine Haustiere — bis zu 10 private Tiere',
    'pl': 'Moje zwierzęta — ewidencja do 10 prywatnych zwierząt',
    'sv': 'Mina husdjur — upp till 10 privata djur',
    'cs': 'Moji mazlíčci — evidence až 10 soukromých zvířat',
    'es': 'Mis mascotas — registro de hasta 10 animales privados',
    'fr': 'Mes animaux — jusqu\'à 10 animaux privés',
    'en': 'My pets — up to 10 private animals',
    'zh': '我的宠物（最多 10 只私人动物）',
    'uk': 'Мої улюбленці — облік до 10 приватних тварин',
    'ru': 'Мои питомцы — учёт до 10 частных животных',
    'hi': 'मेरे पालतू — 10 निजी जानवरों तक',
    'id': 'Hewan peliharaan saya — hingga 10 hewan pribadi',
    'sw': 'Wanyama wangu — hadi wanyama 10 wa kibinafsi',
    'ar': 'حيواناتي الأليفة — حتى 10 حيوانات خاصة',
    'it': 'I miei animali — fino a 10 animali privati',
    'tr': 'Evcil hayvanlarım — 10\'a kadar özel hayvan',
  },
  'paywall_vet_benefit_scanner': {
    'hr': 'AI Skener biljaka — 25 skeniranja mjesečno',
    'bs': 'AI Skener biljaka — 25 skeniranja mjesečno',
    'sr': 'AI Skener biljaka — 25 skeniranja mesečno',
    'de': 'KI-Pflanzenscanner — 50 Scans pro Monat',
    'pl': 'Skaner AI roślin — 50 skanów miesięcznie',
    'sv': 'AI-växtskanner — 50 skanningar per månad',
    'cs': 'AI skener rostlin — 50 skenů měsíčně',
    'es': 'Escáner IA de plantas — 50 escaneos al mes',
    'fr': 'Scanner IA des plantes — 50 scans par mois',
    'en': 'AI Plant Scanner — 50 scans per month',
    'zh': 'AI 植物扫描 — 每月 50 次',
    'uk': 'ШІ-сканер рослин — 50 сканувань на місяць',
    'ru': 'ИИ-сканер растений — 50 сканирований в месяц',
    'hi': 'AI पौधा स्कैनर — प्रति माह 15 स्कैन',
    'id': 'Pemindai AI Tanaman — 15 pemindaian per bulan',
    'sw': 'AI Kichanganuzi cha Mimea — skani 15 kwa mwezi',
    'ar': 'ماسح AI للنباتات — 50 عملية مسح/الشهر',
    'it': 'Scanner IA delle piante — 50 scansioni al mese',
    'tr': 'AI Bitki Tarayıcı — ayda 40 tarama',
  },
  'paywall_vet_benefit_pharmacy': {
    'hr': 'Puna apoteka — neograničena prodaja medicinskih artikala',
    'bs': 'Puna apoteka — neograničena prodaja medicinskih artikala',
    'sr': 'Puna apoteka — neograničena prodaja medicinskih artikala',
    'de': 'Volle Apotheke — unbegrenzter Verkauf medizinischer Artikel',
    'pl': 'Pełna apteka — nieograniczona sprzedaż artykułów medycznych',
    'sv': 'Fullständigt apotek — obegränsad försäljning av medicinska artiklar',
    'cs': 'Plná lékárna — neomezený prodej zdravotnického zboží',
    'es': 'Farmacia completa — venta ilimitada de productos médicos',
    'fr': 'Pharmacie complète — vente illimitée de produits médicaux',
    'en': 'Full pharmacy — unlimited medical product sales',
    'zh': '完整药房（医疗产品无限销售）',
    'uk': 'Повна аптека — необмежений продаж медичних товарів',
    'ru': 'Полная аптека — неограниченная продажа медицинских товаров',
    'hi': 'पूर्ण फार्मेसी — चिकित्सा उत्पादों की असीमित बिक्री',
    'id': 'Apotek lengkap — penjualan produk medis tak terbatas',
    'sw': 'Duka la dawa kamili — uuzaji usio na kikomo wa bidhaa za matibabu',
    'ar': 'صيدلية كاملة — مبيعات غير محدودة للمنتجات الطبية',
    'it': 'Farmacia completa — vendita illimitata di prodotti medici',
    'tr': 'Tam eczane — sınırsız tıbbi ürün satışı',
  },
  'paywall_vet_benefit_radar': {
    'hr': 'Zlatna značka i automatski lokacijski radar prve pomoći',
    'bs': 'Zlatna značka i automatski lokacijski radar prve pomoći',
    'sr': 'Zlatna značka i automatski lokacijski radar prve pomoći',
    'de': 'Gold-Abzeichen und automatischer Erste-Hilfe-Standortradar',
    'pl': 'Złota odznaka i automatyczny radar lokalizacji pierwszej pomocy',
    'sv': 'Guldmärke och automatisk radar för första hjälpen-plats',
    'cs': 'Zlatý odznak a automatický radar polohy první pomoci',
    'es': 'Insignia dorada y radar automático de ubicación de primeros auxilios',
    'fr': 'Badge doré et radar automatique de localisation des premiers secours',
    'en': 'Gold badge and automatic First Aid location radar',
    'zh': '黄金徽章与自动急救定位雷达',
    'uk': 'Золотий значок і автоматичний радар локації першої допомоги',
    'ru': 'Золотой значок и автоматический радар местоположения первой помощи',
    'hi': 'सुनहरा बैज और स्वचालित प्राथमिक चिकित्सा स्थान रडार',
    'id': 'Lencana emas dan radar lokasi pertolongan pertama otomatis',
    'sw': 'Beji ya dhahabu na rada ya kiotomatiki ya eneo la huduma ya kwanza',
    'ar': 'شارة ذهبية ورادار تلقائي لموقع الإسعافات الأولية',
    'it': 'Badge dorato e radar automatico della posizione del pronto soccorso',
    'tr': 'Altın rozet ve otomatik ilk yardım konum radarı',
  },
  'paywall_pharmacy_title': {
    'hr': 'Business agro-apoteka',
    'de': 'Business Agro-Apotheke',
    'en': 'Business agro-pharmacy',
  },
  'paywall_pharmacy_price': {
    'hr': '19,99 KM / 19,99 € mjesečno',
    'de': '19,99 KM / 19,99 € pro Monat',
    'en': '19.99 KM / €19.99 per month',
  },
  'paywall_pharmacy_features': {
    'hr':
        'Neograničen broj artikala, isticanje na vrhu tržnice i sponzorirane AI preporuke ispod AI Skenera.',
    'de':
        'Unbegrenzte Artikel, Top-Platzierung im Marketplace und gesponserte KI-Empfehlungen unter dem KI-Scanner.',
    'en':
        'Unlimited products, top Marketplace placement, and sponsored AI recommendations below the AI Scanner.',
  },
  'paywall_pharmacy_features_intro': {
    'hr': 'U pretplati dolazi:',
    'bs': 'U pretplati dolazi:',
    'sr': 'U pretplati dolazi:',
    'de': 'In der Premium-Version enthalten:',
    'pl': 'W subskrypcji zawarte:',
    'sv': 'I prenumerationen ingår:',
    'cs': 'V předplatném je zahrnuto:',
    'es': 'Incluido en tu suscripción:',
    'fr': 'Inclus dans votre abonnement :',
    'en': 'Included in your subscription:',
    'zh': '订阅包含：',
    'uk': 'У вашій підписці включено:',
    'ru': 'В вашей подписке включено:',
    'hi': 'आपकी सदस्यता में शामिल:',
    'id': 'Termasuk dalam langganan Anda:',
    'sw': 'Inajumuishwa katika usajili wako:',
    'ar': 'يشمل اشتراكك:',
    'it': 'Incluso nel tuo abbonamento:',
    'tr': 'Aboneliğinize dahil:',
  },
  'paywall_pharmacy_benefit_shop': {
    'hr':
        'Neograničena trgovina (Unos kompletnog asortimana proizvoda bez limita)',
    'de':
        'Unbegrenzter Shop (Eintragen des kompletten Sortiments ohne Limits)',
    'en':
        'Unlimited shop (Add your full product range without limits)',
  },
  'paywall_pharmacy_benefit_boost': {
    'hr':
        'Isticanje na vrhu (Vaši artikli imaju prednost na vrhu tržnice)',
    'de':
        'Hervorhebung oben (Ihre Artikel haben Vorrang auf dem Marktplatz)',
    'en':
        'Top placement (Your items get priority at the top of the marketplace)',
  },
  'paywall_pharmacy_benefit_scanner': {
    'hr': 'AI Skener biljaka — 50 skeniranja mjesečno',
    'bs': 'AI Skener biljaka — 50 skeniranja mjesečno',
    'sr': 'AI Skener biljaka — 50 skeniranja mesečno',
    'de': 'KI-Pflanzenscanner — 100 Scans pro Monat',
    'en': 'AI Plant Scanner — 100 scans per month',
    'pl': 'Skaner AI roślin — 100 skanów miesięcznie',
    'sv': 'AI-växtskanner — 100 skanningar per månad',
    'cs': 'AI skener rostlin — 100 skenů měsíčně',
    'es': 'Escáner IA de plantas — 100 escaneos al mes',
    'fr': 'Scanner IA des plantes — 100 scans par mois',
    'it': 'Scanner IA delle piante — 100 scansioni al mese',
    'tr': 'AI Bitki Tarayıcı — ayda 80 tarama',
    'zh': 'AI 植物扫描 — 每月 100 次',
    'uk': 'ШІ-сканер рослин — 100 сканувань на місяць',
    'ru': 'ИИ-сканер растений — 100 сканирований в месяц',
    'hi': 'AI पौधा स्कैनर — प्रति माह 30 स्कैन',
    'id': 'Pemindai AI Tanaman — 30 pemindaian per bulan',
    'sw': 'AI Kichanganuzi cha Mimea — skani 30 kwa mwezi',
    'ar': 'ماسح AI للنباتات — 50 عملية مسح/الشهر',
  },
  'paywall_pharmacy_benefit_ai': {
    'hr':
        'Sponzorirane AI preporuke (Preporuka vaših sredstava unutar AI Skenera bolesti)',
    'de':
        'Gesponserte KI-Empfehlungen (Empfehlung Ihrer Schutzmittel im KI-Krankheitsscanner)',
    'en':
        'Sponsored AI recommendations (Promotion of your products in the disease AI Scanner)',
  },
  'add_product_scan_barcode': {
    'hr': 'Skenirajte barkod proizvoda',
    'de': 'Produkt-Barcode scannen',
    'en': 'Scan product barcode',
  },
  'add_product_company_stock_label': {
    'hr': 'Dostupna količina (Zaliha):',
    'de': 'Verfügbare Menge (Lagerbestand):',
    'en': 'Available quantity (Stock):',
  },
  'add_product_company_price_label': {
    'hr': 'Cijena po jedinici mjere (€):',
    'de': 'Preis pro Maßeinheit (€):',
    'en': 'Price per unit of measure (€):',
  },
  'add_product_description_optional': {
    'hr': 'Opis (opcionalno)',
    'de': 'Beschreibung (optional)',
    'en': 'Description (optional)',
  },
  'add_product_detailed_description_label': {
    'hr': 'Dostupna specifikacija, sastav i uputa za primjenu',
    'de': 'Detaillierte Beschreibung, Zusammensetzung und Gebrauchsanweisung',
    'en': 'Available specification, composition and instructions for use',
  },
  'paywall_pharmacy_benefit_badge': {
    'hr':
        'Zlatna poslovna značka (Oznaka provjerenog i sigurnog dobavljača)',
    'de':
        'Gold-Business-Abzeichen (Kennzeichnung eines verifizierten Lieferanten)',
    'en':
        'Gold business badge (Mark of a verified and trusted supplier)',
  },
  'company_premium_activate_button': {
    'hr': 'Aktiviraj poslovnu pretplatu (19,99 €/mj)',
    'de': 'Business-Abo aktivieren (19,99 €/Monat)',
    'en': 'Activate business subscription (€19.99/mo)',
  },
  'company_b2b_analytics_title': {
    'hr': 'Analitika tržišta i potražnje',
    'de': 'Markt- und Nachfrageanalyse',
    'en': 'Market and demand analytics',
  },
  'company_b2b_analytics_subtitle': {
    'hr': 'B2B uvid u potražnju, regije i AI preporuke (19,99 €/mj)',
    'de': 'B2B-Einblick in Nachfrage, Regionen und KI-Empfehlungen (19,99 €/Monat)',
    'en': 'B2B insight into demand, regions and AI recommendations (€19.99/mo)',
  },
  'company_b2b_analytics_desc': {
    'hr':
        'Pratite potražnju po kategorijama, regionalne trendove i učinkovitost sponzoriranih AI preporuka vaših zaštitnih sredstava.',
    'de':
        'Verfolgen Sie die Nachfrage nach Kategorien, regionale Trends und die Wirksamkeit gesponserter KI-Empfehlungen Ihrer Schutzmittel.',
    'en':
        'Track category demand, regional trends, and the performance of sponsored AI recommendations for your products.',
  },
  'company_b2b_metric_demand': {
    'hr': 'Potražnja po kategorijama',
    'de': 'Nachfrage nach Kategorien',
    'en': 'Demand by category',
  },
  'company_b2b_metric_regions': {
    'hr': 'Regionalni trendovi tržišta',
    'de': 'Regionale Markttrends',
    'en': 'Regional market trends',
  },
  'company_b2b_metric_ai': {
    'hr': 'Učinkovitost AI preporuka',
    'de': 'Wirksamkeit der KI-Empfehlungen',
    'en': 'AI recommendation performance',
  },
  'company_b2b_detail_demand_body': {
    'hr':
        "Najveći promet na tržištu ovaj mjesec: 'Đubriva i stimulansi' (42%) i 'Zaštita bilja' (35%).",
    'de':
        "Größter Marktumsatz diesen Monat: 'Düngemittel und Stimulanzien' (42 %) und 'Pflanzenschutz' (35 %).",
    'en':
        "Highest marketplace turnover this month: 'Fertilizers and stimulants' (42%) and 'Plant protection' (35%).",
  },
  'company_b2b_detail_regions_body': {
    'hr':
        'U vašem radijusu pretrage, farmeri trenutno najviše pretražuju sjemenske hibride i sustave navodnjavanja kap po kap.',
    'de':
        'In Ihrem Suchradius suchen Landwirte derzeit vor allem Saatgut-Hybriden und Tropfbewässerungssysteme.',
    'en':
        'Within your search radius, farmers are currently searching most for seed hybrids and drip irrigation systems.',
  },
  'company_b2b_detail_ai_body': {
    'hr':
        'Vaš asortiman je prikazan 124 puta unutar AI Skenera bolesti kao sponzorirana preporuka. Ostvareno je 38 izravnih ulaza na vaše artikle.',
    'de':
        'Ihr Sortiment wurde 124 Mal im KI-Krankheitsscanner als gesponserte Empfehlung angezeigt. Es wurden 38 direkte Aufrufe Ihrer Artikel erzielt.',
    'en':
        'Your assortment was shown 124 times in the disease AI scanner as a sponsored recommendation. 38 direct visits to your products were generated.',
  },
  'company_b2b_detail_highlights': {
    'hr': 'Ključni pokazatelji',
    'de': 'Wichtige Kennzahlen',
    'en': 'Key metrics',
  },
  'company_b2b_stat_fertilizers': {
    'hr': 'Đubriva i stimulansi',
    'de': 'Düngemittel und Stimulanzien',
    'en': 'Fertilizers and stimulants',
  },
  'company_b2b_stat_plant_protection': {
    'hr': 'Zaštita bilja',
    'de': 'Pflanzenschutz',
    'en': 'Plant protection',
  },
  'company_b2b_stat_ai_impressions': {
    'hr': 'Prikaza u AI Skeneru',
    'de': 'Anzeigen im KI-Scanner',
    'en': 'AI scanner impressions',
  },
  'company_b2b_stat_ai_clicks': {
    'hr': 'Izravnih ulaza na artikle',
    'de': 'Direkte Artikelaufrufe',
    'en': 'Direct product visits',
  },
  'farmer_helper_close': {
    'hr': 'Zatvori',
    'de': 'Schließen',
    'en': 'Close',
  },
  'company_commercial_weather_alert': {
    'hr':
        'Komercijalni meteo-alarm: Pratite najave nepogoda u regiji kako biste na vrijeme prilagodili zalihe agrokemije i zaštitnih sredstava na skladištu.',
    'de':
        'Kommerzieller Wetteralarm: Beobachten Sie Unwetterwarnungen in der Region, um Lagerbestände für Agrochemie und Pflanzenschutzmittel rechtzeitig anzupassen.',
    'en':
        'Commercial weather alert: Monitor severe weather warnings in your region to adjust agrochemical and crop protection stock in time.',
  },
  'first_aid_title': {
    'hr': 'Prva pomoć — veterinarski radar',
    'de': 'Erste Hilfe — Tierarzt-Radar',
    'en': 'First aid — vet radar',
  },
  'first_aid_button': {
    'hr': 'Prva pomoć',
    'de': 'Erste Hilfe',
    'en': 'First aid',
  },
  'first_aid_no_vets': {
    'hr':
        'Nema dostupnih Premium veterinara u blizini. Ručno pretražite ime veterinara u glavnoj tražilici.',
    'de':
        'Keine Premium-Tierärzte in der Nähe. Suchen Sie manuell nach Namen in der Hauptsuche.',
    'en':
        'No nearby Premium vets. Search for a vet by name in the main search bar.',
  },
  'first_aid_favorite': {
    'hr': 'Označi kao omiljenog veterinara',
    'de': 'Als Lieblingstierarzt markieren',
    'en': 'Mark as favorite vet',
  },
  'first_aid_call': {
    'hr': 'Nazovi',
    'de': 'Anrufen',
    'en': 'Call',
  },
  'first_aid_chat': {
    'hr': 'Poruka',
    'de': 'Nachricht',
    'en': 'Message',
  },
  'vet_referral_title': {
    'hr': 'Slanje kartona veterinaru',
    'de': 'Akte an Tierarzt senden',
    'en': 'Send record to veterinarian',
  },
  'vet_referral_select_vet': {
    'hr': 'Odaberite veterinara (omiljeni ili iz radara blizine):',
    'de': 'Wählen Sie einen Tierarzt (Favorit oder aus der Nähe):',
    'en': 'Select a veterinarian (favorite or nearby radar):',
  },
  'vet_referral_memo_label': {
    'hr':
        'Opišite kratko simptome ili razlog slanja bolesne životinje (npr. povišena temperatura, odbija hranu...)',
    'de':
        'Beschreiben Sie kurz die Symptome oder den Grund für die Übersendung des kranken Tieres (z. B. erhöhte Temperatur, frisst nicht...)',
    'en':
        'Briefly describe symptoms or reason for sending the sick animal (e.g. fever, refusing food...)',
  },
  'vet_referral_memo_required': {
    'hr': 'Molimo opišite simptome ili razlog slanja.',
    'de': 'Bitte beschreiben Sie die Symptome oder den Grund.',
    'en': 'Please describe symptoms or reason for sending.',
  },
  'vet_referral_send': {
    'hr': 'Pošalji karton veterinaru',
    'de': 'Akte an Tierarzt senden',
    'en': 'Send record to vet',
  },
  'vet_referral_sent': {
    'hr': 'Karton je uspješno poslan veterinaru.',
    'de': 'Die Akte wurde erfolgreich an den Tierarzt gesendet.',
    'en': 'Medical record sent to the veterinarian.',
  },
  'vet_client_memo_title': {
    'hr': 'Napomena vlasnika',
    'de': 'Hinweis des Besitzers',
    'en': 'Owner note',
  },
  'vet_client_memo_empty': {
    'hr': 'Vlasnik nije dodao napomenu.',
    'de': 'Der Besitzer hat keinen Hinweis hinzugefügt.',
    'en': 'Owner did not add a note.',
  },
  'vet_intake_empty': {
    'hr':
        'Još nema pristiglih kartona. Kad vlasnik pošalje karton putem Prve pomoći, pojavit će se ovdje.',
    'de':
        'Noch keine eingegangenen Akten. Wenn ein Besitzer eine Akte über Erste Hilfe sendet, erscheint sie hier.',
    'en':
        'No incoming records yet. When an owner sends a record via First Aid, it will appear here.',
  },
  'vet_intake_search_hint': {
    'hr': 'Pretraži po životinji, vlasniku ili napomeni…',
    'de': 'Suche nach Tier, Besitzer oder Hinweis…',
    'en': 'Search by animal, owner, or note…',
  },
  'vet_intake_sort_label': {
    'hr': 'Sortiraj',
    'de': 'Sortieren',
    'en': 'Sort',
  },
  'vet_intake_sort_newest': {
    'hr': 'Najnovije',
    'de': 'Neueste',
    'en': 'Newest',
  },
  'vet_intake_sort_animal_az': {
    'hr': 'Životinja A–Z',
    'de': 'Tier A–Z',
    'en': 'Animal A–Z',
  },
  'vet_intake_sort_client_az': {
    'hr': 'Vlasnik A–Z',
    'de': 'Besitzer A–Z',
    'en': 'Owner A–Z',
  },
  'vet_intake_sort_unread': {
    'hr': 'Nepročitano',
    'de': 'Ungelesen',
    'en': 'Unread',
  },
  'vet_intake_count_total': {
    'hr': '{count} kartona',
    'de': '{count} Akten',
    'en': '{count} records',
  },
  'vet_intake_count_filtered': {
    'hr': 'Prikazano {visible} od {total}',
    'de': '{visible} von {total} angezeigt',
    'en': 'Showing {visible} of {total}',
  },
  'vet_intake_no_results': {
    'hr': 'Nema kartona za ovu pretragu. Pokušajte drugi pojam.',
    'de': 'Keine Akten für diese Suche. Anderen Begriff versuchen.',
    'en': 'No records match this search. Try another term.',
  },
  'vet_intake_page': {
    'hr': 'Stranica {current} od {total}',
    'de': 'Seite {current} von {total}',
    'en': 'Page {current} of {total}',
  },
  'vet_intake_page_range': {
    'hr': '{from}–{to} od {total}',
    'de': '{from}–{to} von {total}',
    'en': '{from}–{to} of {total}',
  },
  'vet_intake_prev_page': {
    'hr': 'Prethodna stranica',
    'de': 'Vorherige Seite',
    'en': 'Previous page',
  },
  'vet_intake_next_page': {
    'hr': 'Sljedeća stranica',
    'de': 'Nächste Seite',
    'en': 'Next page',
  },
  'profile_subscription_title': {
    'hr': 'Pretplata',
    'bs': 'Pretplata',
    'sr': 'Pretplata',
    'de': 'Abonnement',
    'en': 'Subscription',
  },
  'profile_subscription_inactive': {
    'hr': 'Nemate aktivnu pretplatu. Otključajte Premium značajke jednim dodirom.',
    'bs': 'Nemate aktivnu pretplatu. Otključajte Premium značajke jednim dodirom.',
    'sr': 'Nemate aktivnu pretplatu. Otključajte Premium funkcije jednim dodirom.',
    'de': 'Kein aktives Abo. Premium-Funktionen mit einem Tipp freischalten.',
    'en': 'No active subscription. Unlock Premium features in one tap.',
  },
  'profile_subscription_active': {
    'hr': 'Aktivno',
    'bs': 'Aktivno',
    'sr': 'Aktivno',
    'de': 'Aktiv',
    'en': 'Active',
  },
  'profile_subscription_subscribe': {
    'hr': 'Pretplati se',
    'bs': 'Pretplati se',
    'sr': 'Pretplati se',
    'de': 'Abonnieren',
    'en': 'Subscribe',
  },
  'profile_subscription_cancel': {
    'hr': 'Otkaži pretplatu',
    'bs': 'Otkaži pretplatu',
    'sr': 'Otkaži pretplatu',
    'de': 'Abo kündigen',
    'en': 'Cancel subscription',
  },
  'profile_subscription_cancel_title': {
    'hr': 'Otkaži pretplatu?',
    'bs': 'Otkaži pretplatu?',
    'sr': 'Otkaži pretplatu?',
    'de': 'Abo kündigen?',
    'en': 'Cancel subscription?',
  },
  'profile_subscription_cancel_body': {
    'hr':
        'Pretplatu možete otkazati u Google Play / App Store postavkama. Premium ostaje aktivan do kraja obračunskog razdoblja.',
    'bs':
        'Pretplatu možete otkazati u Google Play / App Store postavkama. Premium ostaje aktivan do kraja obračunskog razdoblja.',
    'sr':
        'Pretplatu možete otkazati u Google Play / App Store podešavanjima. Premium ostaje aktivan do kraja obračunskog perioda.',
    'de':
        'Sie können in den Google Play / App Store Einstellungen kündigen. Premium bleibt bis zum Ende des Abrechnungszeitraums aktiv.',
    'en':
        'You can cancel in Google Play / App Store settings. Premium stays active until the end of the billing period.',
  },
  'profile_subscription_cancel_confirm': {
    'hr': 'Nastavi na Play Store',
    'bs': 'Nastavi na Play Store',
    'sr': 'Nastavi na Play Store',
    'de': 'Weiter zum Play Store',
    'en': 'Continue to Play Store',
  },
  'profile_subscription_cancel_sim_hint': {
    'hr': 'U produkciji otvaranje Play Storea za otkazivanje pretplate.',
    'bs': 'U produkciji otvaranje Play Storea za otkazivanje pretplate.',
    'sr': 'U produkciji otvara Play Store za otkazivanje pretplate.',
    'de': 'In der Produktion öffnet sich die Play Store Abo-Verwaltung.',
    'en': 'In production this opens Play Store subscription management.',
  },
  'profile_subscription_cancel_failed': {
    'hr':
        'Nije moguće otvoriti upravljanje pretplatom. Pokušajte u Play Store → Pretplate.',
    'bs':
        'Nije moguće otvoriti upravljanje pretplatom. Pokušajte u Play Store → Pretplate.',
    'sr':
        'Nije moguće otvoriti upravljanje pretplatom. Pokušajte u Play Store → Pretplate.',
    'de':
        'Abo-Verwaltung konnte nicht geöffnet werden. Versuchen Sie Play Store → Abos.',
    'en':
        'Could not open subscription management. Try Play Store → Subscriptions.',
  },
  'vet_request_client': {
    'hr': 'Vlasnik',
    'de': 'Besitzer',
    'en': 'Owner',
  },
  'vet_response_form_title': {
    'hr': 'Stručni nalaz za vlasnika',
    'de': 'Fachlicher Befund für den Besitzer',
    'en': 'Professional report for owner',
  },
  'vet_response_field_label': {
    'hr':
        'Upišite stručni savjet, uputu za liječenje ili nalaz za vlasnika.',
    'de':
        'Geben Sie den medizinischen Rat, die Behandlungsanweisung oder den Befund für den Besitzer ein.',
    'en':
        'Enter professional advice, treatment instructions, or findings for the owner.',
  },
  'vet_response_field_hint': {
    'hr': 'Upišite nalaz ili uputu ovdje…',
    'de': 'Befund oder Anweisung hier eingeben…',
    'en': 'Enter your report or instructions here…',
  },
  'vet_response_required': {
    'hr': 'Molimo upišite nalaz ili uputu za vlasnika.',
    'de': 'Bitte geben Sie einen Befund oder eine Anweisung ein.',
    'en': 'Please enter a report or instructions for the owner.',
  },
  'vet_response_send': {
    'hr': 'Spremi i pošalji nalaz',
    'de': 'Befund speichern und senden',
    'en': 'Save and send report',
  },
  'vet_response_sent': {
    'hr': 'Nalaz je spremljen i poslan vlasniku.',
    'de': 'Befund wurde gespeichert und an den Besitzer gesendet.',
    'en': 'Report saved and sent to the owner.',
  },
  'vet_tab_patient_record': {
    'hr': 'Karton',
    'de': 'Akte',
    'en': 'Record',
  },
  'vet_tab_conversations': {
    'hr': 'Razgovori',
    'de': 'Unterhaltungen',
    'en': 'Messages',
  },
  'vet_conversations_empty': {
    'hr':
        'Još nema poslanih poruka. Napišite prvi nalaz na kartici Karton.',
    'de':
        'Noch keine Nachrichten gesendet. Schreiben Sie den ersten Befund unter Akte.',
    'en': 'No messages sent yet. Write the first report on the Record tab.',
  },
  'vet_conversations_filter_all': {
    'hr': 'Sve',
    'de': 'Alle',
    'en': 'All',
  },
  'vet_conversations_filter_important': {
    'hr': 'Važno',
    'de': 'Wichtig',
    'en': 'Important',
  },
  'vet_conversations_important_empty': {
    'hr': 'Nema označenih važnih poruka. Dodirnite zvjezdicu uz poruku.',
    'de': 'Keine wichtigen Nachrichten markiert. Tippen Sie auf den Stern.',
    'en': 'No important messages marked. Tap the star on a message.',
  },
  'vet_conversations_mark_important': {
    'hr': 'Označi kao važno',
    'de': 'Als wichtig markieren',
    'en': 'Mark as important',
  },
  'vet_conversations_unmark_important': {
    'hr': 'Ukloni oznaku važno',
    'de': 'Markierung entfernen',
    'en': 'Remove important mark',
  },
  'vet_owner_response_title': {
    'hr': 'Nalaz i uputa veterinara:',
    'de': 'Befund und Anweisung des Tierarztes:',
    'en': 'Veterinarian report and instructions:',
  },
  'vet_verified_badge': {
    'hr': 'Provjereni',
    'de': 'Verifiziert',
    'en': 'Verified',
  },
  'vet_search_results_title': {
    'hr': 'Veterinari (ručna pretraga)',
    'de': 'Tierärzte (manuelle Suche)',
    'en': 'Veterinarians (manual search)',
  },
  'scanner_sponsored_title': {
    'hr': 'Preporučeni proizvodi',
    'de': 'Empfohlene Produkte',
    'en': 'Recommended products',
    'pl': 'Polecane produkty',
  },
  'scanner_sponsored_desc': {
    'hr': 'Sponzorirane AI preporuke Business agro-apoteka ispod nalaza skenera.',
    'de': 'Gesponserte KI-Empfehlungen von Business-Agro-Apotheken unter dem Scan-Ergebnis.',
    'en': 'Sponsored AI recommendations from business agro-pharmacies below scan results.',
    'pl': 'Sponsorowane rekomendacje AI firm pod wynikiem skanowania.',
  },
  'scanner_topup_hint': {
    'hr': 'U svakom trenutku možete dokupiti dodatna skeniranja.',
    'sr': 'U svakom trenutku možete dokupiti dodatna skeniranja.',
    'de': 'Sie können jederzeit zusätzliche Scans nachkaufen.',
    'en': 'You can purchase additional scans at any time.',
    'pl': 'W każdej chwili możesz dokupić dodatkowe skany.',
    'it': 'Puoi acquistare scansioni aggiuntive in qualsiasi momento.',
    'fr': 'Vous pouvez acheter des scans supplémentaires à tout moment.',
    'es': 'Puedes comprar escaneos adicionales en cualquier momento.',
  },
  'scanner_quota_remaining': {
    'hr': 'Preostalo skenova ovaj mjesec: {remaining} / {limit}',
    'sr': 'Preostalo skenova ovaj mjesec: {remaining} / {limit}',
    'de': 'Verbleibende Scans diesen Monat: {remaining} / {limit}',
    'en': 'Scans remaining this month: {remaining} / {limit}',
    'pl': 'Pozostałe skany w tym miesiącu: {remaining} / {limit}',
  },
};

String farmerGuideLangCode(BuildContext context) {
  final code = context.locale.languageCode;
  if (code == 'bs') return 'hr';
  if (code == 'sr') return 'sr';
  if (code == 'pl') return 'pl';
  if (code == 'es') return 'es';
  if (code == 'fr') return 'fr';
  if (code == 'cs') return 'cs';
  if (code == 'zh') return 'zh';
  if (code == 'sv') return 'sv';
  if (code == 'uk') return 'uk';
  if (code == 'ru') return 'ru';
  if (code == 'hi') return 'hi';
  if (code == 'id') return 'id';
  if (code == 'sw') return 'sw';
  if (code == 'ar') return 'ar';
  if (code == 'it') return 'it';
  if (code == 'tr') return 'tr';
  return code;
}

/// Prevedeni tekst vodiča — ako .tr() vrati sirovi ključ, koristi fallback po jeziku.
String farmerGuideTr(
  BuildContext context,
  String key, {
  Map<String, String>? fallbacks,
}) {
  final translated = key.tr();
  if (translated != key) return translated;
  final lang = farmerGuideLangCode(context);
  final resolved = fallbacks ?? kFarmerGuideFallbacks[key];
  return resolved?[lang] ?? resolved?['en'] ?? translated;
}

String farmerGuideStepLabel(BuildContext context, int current, int total) {
  final lang = farmerGuideLangCode(context);
  const fallbacks = {
    'hr': 'Korak',
    'bs': 'Korak',
    'de': 'Schritt',
    'en': 'Step',
  };
  final word = fallbacks[lang] ?? fallbacks['hr']!;
  return '$word $current / $total';
}

/// Stabilna bijela kartica vodiča — uvijek unutar SafeArea, gumbi fiksno na dnu.
class FarmerGuideBubbleCard extends StatelessWidget {
  const FarmerGuideBubbleCard({
    super.key,
    required this.titleKey,
    required this.bodyKey,
    required this.stepNumber,
    required this.totalSteps,
    required this.onNext,
    required this.onClose,
  });

  final String titleKey;
  final String bodyKey;
  final int stepNumber;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final isLastStep = stepNumber >= totalSteps;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.48;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Material(
            color: Colors.white,
            elevation: 10,
            shadowColor: Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.shade100),
              ),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const FarmerHelperIcon(),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              farmerGuideTr(context, titleKey),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                              ),
                            ),
                            Text(
                              farmerGuideStepLabel(
                                context,
                                stepNumber,
                                totalSteps,
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: Text(
                        farmerGuideTr(context, bodyKey),
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: Colors.grey.shade800,
                        ),
                        textHeightBehavior: const TextHeightBehavior(
                          applyHeightToFirstAscent: true,
                          applyHeightToLastDescent: true,
                        ),
                      ),
                    ),
                  ),
                  FarmerGuideActions(
                    onClose: onClose,
                    onNext: onNext,
                    isLastStep: isLastStep,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Svijetla replika FAB-a iznad tamnog overlay-a — 100% čitljiva u koraku 3.
class FarmerGuideFabReplica extends StatelessWidget {
  const FarmerGuideFabReplica({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.green.shade700,
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Retro "Mali Farmer" — slamnati šešir, plavi tregersi i sjajni fenjer.
class FarmerHelperBadge extends StatelessWidget {
  const FarmerHelperBadge({
    super.key,
    this.compact = false,
  });

  final bool compact;

  static const strawHat = Color(0xFFE5AA70);
  static const overallsBlue = Color(0xFF4A90E2);
  static const skinTone = Color(0xFFF2D6B3);
  static const lanternGold = Color(0xFFFFD54F);

  @override
  Widget build(BuildContext context) {
    final farmerSize = compact ? 34.0 : 88.0;
    final lanternSize = compact ? 18.0 : 38.0;
    final faceSize = compact ? 14.0 : 34.0;

    return SizedBox(
      width: farmerSize + lanternSize * 0.55,
      height: farmerSize,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerLeft,
        children: [
          _FarmerCircle(
            size: farmerSize,
            faceSize: faceSize,
            compact: compact,
          ),
          Positioned(
            right: 0,
            bottom: farmerSize * 0.18,
            child: _GlowingLantern(size: lanternSize),
          ),
        ],
      ),
    );
  }
}

class _FarmerCircle extends StatelessWidget {
  const _FarmerCircle({
    required this.size,
    required this.faceSize,
    required this.compact,
  });

  final double size;
  final double faceSize;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(
          color: FarmerHelperBadge.strawHat,
          width: compact ? 1.5 : 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: compact ? 4 : 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipOval(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              height: size * 0.3,
              color: FarmerHelperBadge.strawHat,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: size * 0.78,
                  height: size * 0.07,
                  margin: EdgeInsets.only(bottom: size * 0.01),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4955E),
                    borderRadius: BorderRadius.circular(size * 0.02),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                color: FarmerHelperBadge.skinTone,
                alignment: Alignment.center,
                child: Icon(
                  Icons.face_rounded,
                  size: faceSize,
                  color: const Color(0xFF8D6E63),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              height: size * 0.34,
              color: FarmerHelperBadge.overallsBlue,
              child: Center(
                child: Container(
                  width: size * 0.12,
                  height: size * 0.18,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2F5F9E),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowingLantern extends StatelessWidget {
  const _GlowingLantern({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFFF8E1),
        border: Border.all(
          color: FarmerHelperBadge.lanternGold.withValues(alpha: 0.7),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.6),
            blurRadius: 12,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Icon(
        Icons.wb_incandescent_rounded,
        size: size * 0.62,
        color: FarmerHelperBadge.lanternGold,
      ),
    );
  }
}

/// Kompaktna ikona za AppBar — tamno-zeleni CircleAvatar s osobom i retro svjetiljkom.
class FarmerHelperIcon extends StatelessWidget {
  const FarmerHelperIcon({super.key});

  static const _darkGreen = Color(0xFF1B5E20);
  static const _goldYellow = Color(0xFFFFD54F);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _goldYellow.withValues(alpha: 0.45),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: CircleAvatar(
        radius: 18,
        backgroundColor: _darkGreen,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Icon(
              Icons.person,
              size: 18,
              color: _goldYellow,
              shadows: const [
                Shadow(
                  color: Color(0x66FFD54F),
                  blurRadius: 6,
                ),
              ],
            ),
            Positioned(
              right: -1,
              bottom: -1,
              child: Icon(
                Icons.wb_incandescent_rounded,
                size: 11,
                color: _goldYellow,
                shadows: const [
                  Shadow(
                    color: Color(0x99FFD54F),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Donji red gumba vodiča.
class FarmerGuideActions extends StatelessWidget {
  const FarmerGuideActions({
    super.key,
    required this.onClose,
    required this.onNext,
    this.isLastStep = false,
  });

  final VoidCallback onClose;
  final VoidCallback onNext;
  final bool isLastStep;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          TextButton(
            onPressed: onClose,
            child: Text(
              farmerGuideTr(
                context,
                'farmer_helper_close',
                fallbacks: const {
                  'hr': 'Zatvori',
                  'de': 'Schließen',
                  'en': 'Close',
                },
              ),
            ),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: onNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            ),
            child: Text(
              farmerGuideTr(
                context,
                isLastStep ? 'farmer_helper_done' : 'farmer_helper_next',
                fallbacks: isLastStep
                    ? const {'hr': 'Razumijem', 'de': 'Verstanden', 'en': 'Got it'}
                    : const {'hr': 'Dalje', 'de': 'Weiter', 'en': 'Continue'},
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Uvodni skočni prozor Pomoćnika — retro ikona i zaključani prijevodi s fallbackom.
class FarmerWelcomeDialog extends StatelessWidget {
  const FarmerWelcomeDialog({super.key});

  static Future<void> showIfNeeded(BuildContext context) async {
    try {
      final container = ProviderScope.containerOf(context);
      if (!FarmerGuideAccess.isGuideEnabledForContainer(container)) return;
    } catch (_) {
      // Nema ProviderScope-a — nastavi bez globalne blokade.
    }

    final seen = await FarmerHelperPrefs.hasSeenWelcome();
    if (seen || !context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const FarmerWelcomeDialog(),
    );
  }

  Future<void> _startJourney(BuildContext context) async {
    await FarmerHelperPrefs.markWelcomeSeen();
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.82;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: maxHeight,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.scale(
                          scale: 2.0,
                          child: const FarmerHelperIcon(),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          farmerGuideTr(context, 'farmer_welcome_title'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          farmerGuideTr(context, 'farmer_welcome_body'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _startJourney(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      farmerGuideTr(context, 'farmer_welcome_start'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
