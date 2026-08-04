const fs = require("fs");
const path = require("path");

const dir = path.join(__dirname, "..", "assets", "translations");

const byLocale = {
  hr: {
    add_product_title_new: "Novi proizvod",
    add_product_title_edit: "Uredi proizvod",
    add_product_name_label: "Naziv proizvoda",
    add_product_name_required: "Unesite naziv",
    add_product_price_required: "Unesite cijenu",
    add_product_submit_publish: "Objavi na prodavnicu",
    add_product_submit_save: "Spremi izmjene",
  },
  "hr-HR": null,
  "hr-BA": null,
  bs: {
    add_product_title_new: "Novi proizvod",
    add_product_title_edit: "Uredi proizvod",
    add_product_name_label: "Naziv proizvoda",
    add_product_name_required: "Unesite naziv",
    add_product_price_required: "Unesite cijenu",
    add_product_submit_publish: "Objavi na prodavnicu",
    add_product_submit_save: "Spremi izmjene",
  },
  sr: {
    add_product_title_new: "Novi proizvod",
    add_product_title_edit: "Uredi proizvod",
    add_product_name_label: "Naziv proizvoda",
    add_product_name_required: "Unesite naziv",
    add_product_price_required: "Unesite cenu",
    add_product_submit_publish: "Objavi u prodavnici",
    add_product_submit_save: "Sačuvaj izmene",
  },
  "sr-BA": null,
  "sr-RS": null,
  de: {
    add_product_title_new: "Neues Produkt",
    add_product_title_edit: "Produkt bearbeiten",
    add_product_name_label: "Produktname",
    add_product_name_required: "Bitte Produktname eingeben",
    add_product_price_required: "Bitte Preis eingeben",
    add_product_submit_publish: "Auf Marktplatz veröffentlichen",
    add_product_submit_save: "Änderungen speichern",
  },
  en: {
    add_product_title_new: "New product",
    add_product_title_edit: "Edit product",
    add_product_name_label: "Product name",
    add_product_name_required: "Enter product name",
    add_product_price_required: "Enter price",
    add_product_submit_publish: "Publish to marketplace",
    add_product_submit_save: "Save changes",
  },
  fr: {
    add_product_title_new: "Nouveau produit",
    add_product_title_edit: "Modifier le produit",
    add_product_name_label: "Nom du produit",
    add_product_name_required: "Saisissez le nom du produit",
    add_product_price_required: "Saisissez le prix",
    add_product_submit_publish: "Publier sur la marketplace",
    add_product_submit_save: "Enregistrer les modifications",
  },
  es: {
    add_product_title_new: "Nuevo producto",
    add_product_title_edit: "Editar producto",
    add_product_name_label: "Nombre del producto",
    add_product_name_required: "Introduzca el nombre del producto",
    add_product_price_required: "Introduzca el precio",
    add_product_submit_publish: "Publicar en el marketplace",
    add_product_submit_save: "Guardar cambios",
  },
  it: {
    add_product_title_new: "Nuovo prodotto",
    add_product_title_edit: "Modifica prodotto",
    add_product_name_label: "Nome prodotto",
    add_product_name_required: "Inserisci il nome del prodotto",
    add_product_price_required: "Inserisci il prezzo",
    add_product_submit_publish: "Pubblica sul marketplace",
    add_product_submit_save: "Salva modifiche",
  },
  pl: {
    add_product_title_new: "Nowy produkt",
    add_product_title_edit: "Edytuj produkt",
    add_product_name_label: "Nazwa produktu",
    add_product_name_required: "Wprowadź nazwę produktu",
    add_product_price_required: "Wprowadź cenę",
    add_product_submit_publish: "Opublikuj na marketplace",
    add_product_submit_save: "Zapisz zmiany",
  },
  cs: {
    add_product_title_new: "Nový produkt",
    add_product_title_edit: "Upravit produkt",
    add_product_name_label: "Název produktu",
    add_product_name_required: "Zadejte název produktu",
    add_product_price_required: "Zadejte cenu",
    add_product_submit_publish: "Publikovat na tržišti",
    add_product_submit_save: "Uložit změny",
  },
  ru: {
    add_product_title_new: "Новый продукт",
    add_product_title_edit: "Редактировать продукт",
    add_product_name_label: "Название продукта",
    add_product_name_required: "Введите название продукта",
    add_product_price_required: "Введите цену",
    add_product_submit_publish: "Опубликовать на маркетплейсе",
    add_product_submit_save: "Сохранить изменения",
  },
  uk: {
    add_product_title_new: "Новий продукт",
    add_product_title_edit: "Редагувати продукт",
    add_product_name_label: "Назва продукту",
    add_product_name_required: "Введіть назву продукту",
    add_product_price_required: "Введіть ціну",
    add_product_submit_publish: "Опублікувати на маркетплейсі",
    add_product_submit_save: "Зберегти зміни",
  },
  tr: {
    add_product_title_new: "Yeni ürün",
    add_product_title_edit: "Ürünü düzenle",
    add_product_name_label: "Ürün adı",
    add_product_name_required: "Ürün adını girin",
    add_product_price_required: "Fiyatı girin",
    add_product_submit_publish: "Pazara yayınla",
    add_product_submit_save: "Değişiklikleri kaydet",
  },
  ar: {
    add_product_title_new: "منتج جديد",
    add_product_title_edit: "تعديل المنتج",
    add_product_name_label: "اسم المنتج",
    add_product_name_required: "أدخل اسم المنتج",
    add_product_price_required: "أدخل السعر",
    add_product_submit_publish: "نشر في السوق",
    add_product_submit_save: "حفظ التغييرات",
  },
  hi: {
    add_product_title_new: "नया उत्पाद",
    add_product_title_edit: "उत्पाद संपादित करें",
    add_product_name_label: "उत्पाद का नाम",
    add_product_name_required: "उत्पाद का नाम दर्ज करें",
    add_product_price_required: "मूल्य दर्ज करें",
    add_product_submit_publish: "मार्केटप्लेस पर प्रकाशित करें",
    add_product_submit_save: "परिवर्तन सहेजें",
  },
  zh: {
    add_product_title_new: "新产品",
    add_product_title_edit: "编辑产品",
    add_product_name_label: "产品名称",
    add_product_name_required: "请输入产品名称",
    add_product_price_required: "请输入价格",
    add_product_submit_publish: "发布到市场",
    add_product_submit_save: "保存更改",
  },
  id: {
    add_product_title_new: "Produk baru",
    add_product_title_edit: "Edit produk",
    add_product_name_label: "Nama produk",
    add_product_name_required: "Masukkan nama produk",
    add_product_price_required: "Masukkan harga",
    add_product_submit_publish: "Terbitkan ke marketplace",
    add_product_submit_save: "Simpan perubahan",
  },
  sv: {
    add_product_title_new: "Ny produkt",
    add_product_title_edit: "Redigera produkt",
    add_product_name_label: "Produktnamn",
    add_product_name_required: "Ange produktnamn",
    add_product_price_required: "Ange pris",
    add_product_submit_publish: "Publicera på marknadsplatsen",
    add_product_submit_save: "Spara ändringar",
  },
  sw: {
    add_product_title_new: "Bidhaa mpya",
    add_product_title_edit: "Hariri bidhaa",
    add_product_name_label: "Jina la bidhaa",
    add_product_name_required: "Weka jina la bidhaa",
    add_product_price_required: "Weka bei",
    add_product_submit_publish: "Chapisha kwenye soko",
    add_product_submit_save: "Hifadhi mabadiliko",
  },
};

byLocale["hr-HR"] = byLocale.hr;
byLocale["hr-BA"] = byLocale.hr;
byLocale["sr-BA"] = byLocale.sr;
byLocale["sr-RS"] = byLocale.sr;

const fallback = byLocale.en;

for (const file of fs.readdirSync(dir)) {
  if (!file.endsWith(".json") || file.startsWith("patches")) continue;
  const locale = file.replace(".json", "");
  const keys = byLocale[locale] || fallback;
  const filePath = path.join(dir, file);
  const data = JSON.parse(fs.readFileSync(filePath, "utf8"));
  Object.assign(data, keys);
  const sorted = Object.fromEntries(Object.entries(data).sort(([a], [b]) => a.localeCompare(b)));
  fs.writeFileSync(filePath, JSON.stringify(sorted, null, 2) + "\n");
  console.log("patched", file);
}
