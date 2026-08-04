#!/usr/bin/env python3
"""Generate Spanish translation patch from es_needs.json."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
NEEDS_PATH = ROOT / "assets" / "translations" / "patches" / "es_needs.json"
OUT_PATH = ROOT / "assets" / "translations" / "patches" / "es_patch.json"

TRANSLATIONS: dict[str, str] = {'registration_vet_fields_required': 'El veterinario debe introducir nombre, correo electrónico, contraseña, teléfono, '
                                     'dirección y número de licencia.',
 'registration_company_reg_required': 'La empresa debe introducir el número de registro.',
 'cart_total': 'Total',
 'cart_stock_insufficient': 'El agricultor ya no tiene la cantidad solicitada en stock. Las cantidades del carrito se '
                            'han ajustado.',
 'cart_delivery_min_remaining': 'Añade {amount} {currency} más para desbloquear la entrega',
 'cart_delivery_ready': 'Mínimo alcanzado ({amount} {currency}) — entrega aprobada',
 'scanner_new_photo': 'Nueva foto',
 'scanner_clear_photo': 'Borrar',
 'region_serbia': 'Serbia (RSD)',
 'first_aid_title': 'Primeros auxilios — radar veterinario',
 'first_aid_button': 'Primeros auxilios',
 'first_aid_no_vets': 'No hay veterinarios Premium cerca. Busque un veterinario por nombre en la barra de búsqueda '
                      'principal.',
 'first_aid_favorite': 'Marcar como veterinario favorito',
 'first_aid_call': 'Llamar',
 'first_aid_chat': 'Mensaje',
 'vet_referral_title': 'Enviar historial al veterinario',
 'vet_referral_select_vet': 'Seleccione un veterinario (favorito o del radar cercano):',
 'vet_referral_memo_label': 'Describa brevemente los síntomas o el motivo del envío del animal enfermo (p. ej., '
                            'fiebre, rechaza la comida...)',
 'vet_referral_memo_required': 'Describa los síntomas o el motivo del envío.',
 'vet_referral_send': 'Enviar historial al veterinario',
 'vet_referral_sent': 'Historial médico enviado al veterinario.',
 'vet_client_memo_title': 'Nota del propietario',
 'vet_client_memo_empty': 'El propietario no añadió una nota.',
 'vet_intake_empty': 'Aún no hay historiales entrantes. Cuando un propietario envíe un historial mediante Primeros '
                     'auxilios, aparecerá aquí.',
 'vet_intake_search_hint': 'Buscar por animal, propietario o nota…',
 'vet_intake_sort_label': 'Ordenar',
 'vet_intake_sort_newest': 'Más recientes',
 'vet_intake_sort_animal_az': 'Animal A–Z',
 'vet_intake_sort_client_az': 'Propietario A–Z',
 'vet_intake_sort_unread': 'No leídos',
 'vet_intake_count_total': '{count} historiales',
 'vet_intake_count_filtered': 'Mostrando {visible} de {total}',
 'vet_intake_no_results': 'Ningún historial coincide con esta búsqueda. Pruebe otro término.',
 'vet_intake_page': 'Página {current} de {total}',
 'vet_intake_page_range': '{from}–{to} de {total}',
 'vet_intake_prev_page': 'Página anterior',
 'vet_intake_next_page': 'Página siguiente',
 'vet_request_client': 'Propietario',
 'vet_response_form_title': 'Informe profesional para el propietario',
 'vet_response_field_label': 'Introduzca consejo profesional, instrucciones de tratamiento o hallazgos para el '
                             'propietario.',
 'vet_response_field_hint': 'Introduzca su informe o instrucciones aquí…',
 'vet_response_required': 'Introduzca un informe o instrucciones para el propietario.',
 'vet_response_send': 'Guardar y enviar informe',
 'vet_response_sent': 'Informe guardado y enviado al propietario.',
 'vet_tab_patient_record': 'Historial',
 'vet_tab_conversations': 'Mensajes',
 'vet_conversations_empty': 'Aún no se han enviado mensajes. Escriba el primer informe en la pestaña Historial.',
 'vet_conversations_filter_all': 'Todos',
 'vet_conversations_filter_important': 'Importantes',
 'vet_conversations_important_empty': 'No hay mensajes importantes marcados. Toque la estrella en un mensaje.',
 'vet_conversations_mark_important': 'Marcar como importante',
 'vet_conversations_unmark_important': 'Quitar marca de importante',
 'vet_owner_response_title': 'Informe e instrucciones del veterinario:',
 'vet_verified_badge': 'Verificado',
 'vet_search_results_title': 'Veterinarios (búsqueda manual)',
 'animals_photo_camera': 'Tomar con la cámara',
 'animals_photo_gallery': 'Elegir de la galería',
 'animals_attach_document': '📎 Añadir / fotografiar documento del animal',
 'animals_attach_document_hint': '(cartillas de vacunación, informes, facturas)',
 'animals_doc_take_photo': 'Fotografiar documento',
 'animals_doc_pick_file': 'Elegir archivo',
 'add_product_pack_contents': 'Contenido del paquete (p. ej., 30 unidades)',
 'add_product_pack_contents_hint': '30 unidades, bolsa de 5 kg...',
 'add_product_stock': 'Stock disponible',
 'add_product_stock_hint': 'Introduzca la cantidad aproximada que tiene en stock',
 'add_product_stock_required': 'Introduzca el stock disponible',
 'add_product_stock_invalid': 'Introduzca una cantidad válida (0 o más)',
 'vet_tab_digital_intake': 'Recepción digital de historiales',
 'vet_field_report_add': 'Nuevo informe de campo',
 'vet_field_report_empty': 'Aún no hay informes de campo. Toque + para registrar una visita a la granja con notas y '
                           'una foto.',
 'vet_field_report_title_label': 'Título del informe',
 'vet_field_report_title_required': 'Introduzca un título para el informe',
 'vet_field_report_farmer_label': 'Agricultor',
 'vet_field_report_select_farmer': 'Seleccionar agricultor',
 'vet_field_report_other_farmer': 'Introducir otro agricultor',
 'vet_field_report_farmer_required': 'Seleccione o introduzca un agricultor',
 'vet_field_report_notes_label': 'Notas',
 'vet_field_report_photo_btn': 'Tomar / añadir foto',
 'vet_field_report_photo_camera': 'Tomar con la cámara',
 'vet_field_report_photo_gallery': 'Elegir de la galería',
 'vet_field_report_save': 'Guardar informe de campo',
 'vet_field_report_saved': 'Informe de campo guardado',
 'roles_pdf_screen_title': 'Roles y suscripciones',
 'roles_pdf_profile_title': 'PDF: Roles y suscripciones',
 'roles_pdf_profile_subtitle': 'Gratis vs. de pago — resumen de todos los roles de la app',
 'company_catalog_import_success_detail': 'Importados {count} artículos ({inserted} nuevos, {updated} actualizados)',
 'company_catalog_csv_bad_headers': 'Formato de archivo no válido. Faltan columnas obligatorias: {columns}. Se '
                                    'esperaba: barkod, naziv, cijena, zaliha, jedinica.',
 'company_catalog_csv_empty_file': 'El archivo está vacío.',
 'company_catalog_csv_no_data_rows': 'El CSV no tiene filas de datos.',
 'company_catalog_csv_parse_failed': 'No se pudo leer el archivo como CSV.',
 'company_catalog_csv_row_price_error': 'Error en la fila {row}: El precio debe ser un número.',
 'company_catalog_csv_row_stock_error': 'Error en la fila {row}: El stock debe ser un número.',
 'company_catalog_csv_row_sku_empty': 'Error en la fila {row}: El SKU es obligatorio.',
 'company_catalog_csv_row_name_empty': 'Error en la fila {row}: El nombre es obligatorio.',
 'company_catalog_template_download': 'Descargar plantilla (.csv)',
 'company_catalog_template_downloaded': 'Plantilla lista — elija dónde guardarla',
 'company_catalog_template_download_failed': 'No se pudo descargar la plantilla.',
 'company_catalog_stock': 'Stock: {stock}',
 'company_commercial_weather_alert': 'Alerta meteorológica comercial: supervise las advertencias de tiempo severo en '
                                     'su región para ajustar a tiempo el stock de agroquímicos y productos '
                                     'fitosanitarios.',
 'add_product_ai_classifying': 'La AI está analizando la foto y sugiriendo una categoría…',
 'add_product_ai_category_detected': 'La AI seleccionó automáticamente la categoría del producto.',
 'add_product_subcategory': 'Subcategoría',
 'add_product_sku_label': 'SKU / Número de catálogo',
 'add_product_sku_required': 'Introduzca el código del artículo de su sistema de almacén.',
 'add_product_scan_barcode': 'Escanear código de barras del producto',
 'add_product_barcode_scan_hint': 'Apunte la cámara al código de barras EAN/UPC o al código QR en el envase.',
 'add_product_barcode_scanned': 'Código de barras escaneado: {code}',
 'add_product_company_stock_label': 'Cantidad disponible (Stock):',
 'add_product_company_price_label': 'Precio por unidad de medida (€):',
 'add_product_description_optional': 'Descripción (opcional)',
 'add_product_detailed_description_label': 'Especificación, composición e instrucciones de uso disponibles',
 'add_product_detailed_description_required': 'Introduzca una descripción detallada, composición e instrucciones de '
                                              'uso.',
 'paywall_title': 'My Farmer Premium',
 'paywall_benefit_chat': 'Chat',
 'premium_upcoming_title': 'Premium — Reserva anticipada',
 'premium_upcoming_desc': 'Active Premium (Comprador 1,99 € o Hobby 3,99 €/mes) para reservar productos próximos y '
                          'pagar con tarjeta en el carrito.',
 'land_parcel_limit_reached': 'Límite de parcelas alcanzado para su plan. Actualice a Premium para más parcelas.',
 'cart_payment_stripe': '💳 Tarjeta de crédito (Stripe)',
 'cart_payment_google_pay': '📱 Google Pay / Apple Pay',
 'cart_upcoming_digital_required': 'Los productos próximos requieren pago digital para asegurar y bloquear su reserva.',
 'cart_upcoming_card_required': 'Los productos próximos requieren pago con tarjeta para asegurar su reserva.',
 'product_upcoming_pro_only': '"Próximamente" solo está disponible para agricultores profesionales con una suscripción '
                              'Premium activa.',
 'product_upcoming_card_payment_hint': 'Las reservas deben pagarse únicamente con tarjeta (Stripe).',
 'order_badge_stripe': 'Tarjeta',
 'order_badge_google_pay': 'GOOGLE PAY',
 'order_badge_paypal': 'PAYPAL',
 'payment_stripe_confirm_title': 'Pago con Stripe',
 'payment_stripe_confirm_body': 'Confirme el pago con tarjeta de crédito a través de Stripe.',
 'payment_google_pay_confirm_body': 'Confirme el pago mediante Google Pay o Apple Pay (Stripe Native API).',
 'payment_stripe_confirm_done': 'Confirmar pago',
 'payment_paypal_confirm_title': 'Autorización de PayPal',
 'payment_paypal_confirm_body': 'Después de completar el pago con PayPal en su navegador, confirme aquí para bloquear '
                                'su reserva.',
 'payment_paypal_confirm_done': 'Pago con PayPal completado',
 'payment_simulation_confirm_body': 'Modo simulación: confirme el pago digital para completar el pedido.',
 'payment_simulation_confirm_button': 'Confirmar simulación',
 'payment_option_stripe_live_hint': 'Introduzca la tarjeta en la ventana de Stripe',
 'payment_option_paypal_live_hint': 'PayPal sandbox en el navegador',
 'payment_stripe_simulation_title': 'Stripe — simulación',
 'payment_stripe_simulation_body': 'Sin introducción de número de tarjeta — solo prueba, sin cargo real.\n'
                                   '\n'
                                   '{reason}\n'
                                   '\n'
                                   'Para prueba real: ejecute .\\scripts\\run_dev.ps1, establezca '
                                   'PAYMENT_SIMULATION=false, use la tarjeta de prueba 4242 4242 4242 4242.',
 'payment_google_pay_simulation_body': 'Sin cargo de Google Pay — solo prueba.\n\n{reason}',
 'payment_paypal_simulation_title': 'PayPal — simulación',
 'payment_paypal_simulation_body': 'Sin página de PayPal — solo prueba.\n\n{reason}',
 'payment_simulation_reason_flag': 'Motivo: PAYMENT_SIMULATION=true en la configuración.',
 'orders_items_title': 'Artículos del pedido:',
 'admin_reported_posts_title': 'Publicaciones denunciadas',
 'admin_reported_posts_empty': 'No hay publicaciones denunciadas.',
 'admin_report_dismiss': 'Mantener',
 'admin_report_delete': 'Eliminar permanentemente',
 'admin_report_dismissed': 'Denuncia descartada — publicación restaurada en la comunidad.',
 'admin_report_delete_title': '¿Eliminar publicación permanentemente?',
 'admin_report_delete_body': 'La publicación se eliminará permanentemente y el autor no podrá publicar en la '
                             'comunidad.',
 'admin_report_delete_confirm': 'Eliminar',
 'admin_report_deleted': 'Publicación eliminada y autor bloqueado.',
 'admin_report_count': 'Denuncias: {count}',
 'common_error': 'Error: {error}',
 'product_order_paypal_paid_success': '¡Pedido enviado! Pago con PayPal confirmado.',
 'product_order_digital_paid_success': '¡Pedido enviado! Pago digital confirmado.',
 'location_install_title': 'Ubicación requerida',
 'location_install_body': 'My Farmer usa GPS para mostrar precios y moneda del país en el que se encuentra. Sin '
                          'ubicación, alguien en la UE no podría usar precios africanos — y viceversa.',
 'location_install_enable': 'Activar ubicación GPS',
 'location_install_open_settings': 'Abrir ajustes de ubicación',
 'location_install_services_off': 'Los servicios de ubicación están desactivados. Active el GPS en los ajustes del '
                                  'teléfono.',
 'location_install_permission_denied': 'Permiso de ubicación denegado. Actívelo para continuar.',
 'location_install_gps_failed': 'No pudimos verificar su ubicación. Inténtelo de nuevo al aire libre.',
 'location_install_gps_required_pay': 'El GPS debe estar activado para suscribirse — los precios se basan en su '
                                      'ubicación real.',
 'profile_payment_methods_title': 'Métodos de pago',
 'profile_payment_methods_add': 'Añadir método de pago',
 'profile_payment_methods_empty': 'No hay métodos de pago guardados',
 'profile_payment_methods_empty_hint': 'Añada PayPal, una tarjeta o una cuenta bancaria — puede cambiarlos o '
                                       'eliminarlos en cualquier momento.',
 'profile_payment_methods_summary_empty': 'Añadir PayPal, tarjeta o IBAN',
 'profile_payment_methods_loading': 'Cargando…',
 'profile_payment_methods_saved': 'Método de pago guardado',
 'profile_payment_methods_default': 'Predeterminado',
 'profile_payment_methods_set_default': 'Establecer como predeterminado',
 'profile_payment_methods_delete_title': '¿Eliminar método de pago?',
 'profile_payment_methods_delete_body': 'Este método de pago se eliminará de su perfil. Puede añadirlo de nuevo en '
                                        'cualquier momento.',
 'profile_payment_methods_delete_confirm': 'Eliminar',
 'profile_payment_methods_add_paypal_hint': 'Correo donde recibe pagos de PayPal',
 'profile_payment_methods_add_card_hint': 'Tarjeta guardada para un pago más rápido',
 'profile_payment_methods_add_bank_hint': 'IBAN para transferencias bancarias',
 'profile_payment_methods_bank': 'Cuenta bancaria',
 'profile_payment_methods_bank_name': 'Nombre del banco',
 'profile_payment_methods_account_holder': 'Titular de la cuenta',
 'profile_payment_methods_save_card_title': 'Añadir tarjeta',
 'profile_payment_methods_save_card_hint': 'La tarjeta se almacena enmascarada (solo los últimos 4 dígitos)',
 'profile_payment_methods_card_security_hint': 'El número completo de la tarjeta y el CVC nunca se almacenan — solo '
                                               'los últimos 4 dígitos y la fecha de caducidad.',
 'profile_payment_methods_count_card': '{count} tarjeta(s)',
 'profile_payment_methods_count_bank': '{count} banco(s)',
 'guide_profile_payment_methods_title': 'Métodos de pago',
 'guide_profile_payment_methods_body': 'Gestione PayPal, tarjetas y cuentas bancarias en un solo lugar — añada, '
                                       'reemplace o elimine.',
 'profile_payment_methods_error_title': 'No se pudieron cargar los métodos de pago',
 'profile_payment_methods_error_permission': 'No tiene permiso para acceder a los métodos de pago. Inicie sesión de '
                                             'nuevo o espere unos minutos e inténtelo otra vez.',
 'profile_payment_methods_error_permission_hint': 'Si es desarrollador: despliegue las reglas de Firestore con '
                                                  'firebase deploy --only firestore:rules.',
 'profile_payment_methods_error_load': 'Algo salió mal al cargar. Compruebe su conexión e inténtelo de nuevo.',
 'profile_payment_methods_error_offline': 'No se puede conectar al servidor. Compruebe su conexión a internet e '
                                          'inténtelo de nuevo.',
 'profile_payment_methods_error_auth': 'Su sesión ha expirado. Cierre sesión e inicie sesión de nuevo.',
 'profile_payment_methods_error_retry': 'Intentar de nuevo',
 'profile_payment_methods_peer_hint': 'My Farmer no procesa pagos — introduzca los datos para que los compradores le '
                                      'paguen directamente (PayPal, IBAN). La plataforma no es responsable de los '
                                      'pagos entre usuarios.',
 'peer_payment_disclaimer': 'My Farmer no es intermediario de pagos. Usted acuerda y completa el pago directamente con '
                            'el vendedor. La plataforma no garantiza, verifica ni asume responsabilidad por pagos, '
                            'reembolsos o disputas.',
 'peer_payment_disclaimer_short': 'El pago es directamente entre comprador y vendedor. My Farmer no interviene en el '
                                  'cobro.',
 'peer_payment_accept_checkbox': 'Entiendo que My Farmer no es parte del pago y la responsabilidad recae únicamente '
                                 'entre el vendedor y yo.',
 'peer_payment_confirm_order': 'Enviar pedido',
 'peer_payment_amount': 'Importe a acordar: {amount}',
 'peer_payment_paypal_title': 'PayPal — directo al vendedor',
 'peer_payment_paypal_instruction': 'Pague al vendedor directamente en PayPal (fuera de la app):',
 'peer_payment_bank_title': 'Transferencia bancaria — directo al vendedor',
 'peer_payment_bank_instruction': 'Transfiera directamente al IBAN del vendedor:',
 'peer_payment_cash_title': 'Efectivo',
 'peer_payment_cash_instruction': 'Pague al vendedor en efectivo al recoger o en la entrega.',
 'peer_payment_option_paypal': 'PayPal al vendedor',
 'peer_payment_option_paypal_hint': 'Pague directamente al correo de PayPal del vendedor',
 'peer_payment_option_bank': 'Transferencia bancaria',
 'peer_payment_option_bank_hint': 'Pague directamente al IBAN del vendedor',
 'peer_payment_upcoming_required': 'Los productos próximos requieren pago directo al vendedor (PayPal o banco), no a '
                                   'través de la plataforma.',
 'peer_payment_multi_seller': 'Para varios vendedores a la vez, use efectivo o pida a cada vendedor por separado.',
 'peer_payment_seller_missing_title': 'El vendedor no tiene método de pago configurado',
 'peer_payment_seller_missing_paypal': 'El vendedor no ha añadido PayPal en Métodos de pago. Elija efectivo o '
                                       'transferencia bancaria, o contacte al vendedor.',
 'peer_payment_seller_missing_bank': 'El vendedor no ha añadido una cuenta bancaria. Elija PayPal o efectivo.',
 'peer_payment_order_success_paypal': '¡Pedido enviado! Pague al vendedor directamente en PayPal.',
 'peer_payment_order_success_bank': '¡Pedido enviado! Transfiera directamente al IBAN del vendedor.',
 'order_badge_direct_paypal': 'PAYPAL DIRECT',
 'legal_marketplace_terms_title': 'Términos de uso del marketplace',
 'legal_marketplace_terms_subtitle': 'My Farmer — intermediario de pedidos, no servicio de pago',
 'legal_terms_profile_title': 'Términos de uso del marketplace',
 'legal_terms_profile_subtitle': 'Pagos, responsabilidad y suscripciones',
 'legal_terms_read_link': 'Leer términos de uso',
 'legal_terms_footer': 'Al usar el marketplace de My Farmer acepta estos términos. Contacte con el soporte de la app '
                       'si tiene preguntas. Recomendamos revisar estos términos periódicamente.',
 'legal_terms_role_title': '1. Rol de la plataforma',
 'legal_terms_role_body': 'My Farmer es una plataforma digital para publicar productos, realizar pedidos y comunicarse '
                          'entre compradores y vendedores (agricultores, empresas). My Farmer no es el vendedor de los '
                          'productos del marketplace, ni un intermediario de pagos, banco o proveedor de servicios de '
                          'pago.',
 'legal_terms_payments_title': '2. Pagos entre usuarios',
 'legal_terms_payments_body': 'El pago de los productos del marketplace se acuerda y completa únicamente entre '
                              'comprador y vendedor (efectivo, PayPal, transferencia bancaria u otro método acordado). '
                              'My Farmer no recibe, retiene, enruta ni procesa dinero por pedidos de productos. La '
                              'plataforma no garantiza pagos, reembolsos ni resolución de disputas de pago.',
 'legal_terms_seller_title': '3. Responsabilidad del vendedor',
 'legal_terms_seller_body': 'El vendedor es responsable de la exactitud de precios, cantidades, calidad y entrega, de '
                            'los datos de pago válidos en su perfil y del cumplimiento de los pedidos. El vendedor es '
                            'el único responsable de impuestos, facturas y obligaciones legales relacionadas con la '
                            'venta.',
 'legal_terms_buyer_title': '4. Responsabilidad del comprador',
 'legal_terms_buyer_body': 'El comprador es responsable de verificar al vendedor y el producto, completar el pago '
                           'según lo acordado con el vendedor y de los datos correctos del pedido. Al confirmar un '
                           'pedido, el comprador acepta que My Farmer no es parte del pago.',
 'legal_terms_premium_title': '5. Suscripciones Premium (Google Play)',
 'legal_terms_premium_body': 'Premium y servicios similares de la plataforma se facturan por separado a través de '
                             'Google Play según los términos de Google. Esto no es un pago entre comprador y vendedor '
                             'por productos del marketplace.',
 'legal_terms_disputes_title': '6. Disputas y reclamaciones',
 'legal_terms_disputes_body': 'Las disputas sobre productos, entrega o pago se resuelven directamente entre comprador '
                              'y vendedor. My Farmer puede, pero no está obligado a, ayudar con la comunicación. La '
                              'plataforma no es responsable de daños derivados del pago o incumplimiento de contratos '
                              'entre usuarios.',
 'legal_terms_acceptance_title': '7. Aceptación',
 'legal_terms_acceptance_body': 'Al enviar un pedido o usar las opciones de pago en la app, confirma que ha leído y '
                                'entendido que My Farmer no tiene papel en el cobro entre usuarios, y renuncia a '
                                'reclamaciones contra la plataforma respecto a pagos del marketplace salvo donde la '
                                'ley exija lo contrario.',
 'profile_gallery_empty': 'Aún no hay fotos de la comunidad. Comparta la belleza del pueblo en el feed de la '
                          'Comunidad.',
 'unit_pak': 'paquete',
 'unit_pak_full': 'paquete (pak)',
 'product_available_stock': 'Stock disponible: {quantity}',
 'product_mark_sold_out': 'Marcar como agotado',
 'product_mark_available': 'El producto está disponible en el marketplace',
 'product_available_on_market': 'Visible para compradores — se puede pedir',
 'product_hidden_on_market': 'Oculto del marketplace — se muestra como [AGOTADO]',
 'product_buy_now': 'Comprar ahora',
 'product_reserve_ahead': 'Reservar con antelación',
 'product_upcoming_badge': 'Próximamente',
 'product_upcoming_toggle': 'Publicar como "Próximamente"',
 'product_upcoming_toggle_hint': 'El producto será visible con una cuenta atrás hasta la cosecha.',
 'product_upcoming_reserve_hint': 'Reservar con antelación — la cosecha está en planificación.',
 'harvest_countdown_prefix': 'Cosecha en:',
 'delivery_countdown_prefix': 'Entrega en:',
 'delivery_countdown_days': 'Llega en: {days} días',
 'delivery_countdown_hours': 'Llega en: {hours} h',
 'delivery_countdown_soon': 'Llegando pronto',
 'delivery_countdown_due': '¡Stock listo!',
 'delivery_date_label': 'Fecha prevista de entrega / importación',
 'delivery_manage_title': 'Gestionar entrega',
 'delivery_final_photo_instruction': 'Suba una foto del producto real en stock para pasarlo a venta regular.',
 'product_upcoming_delivery_badge': 'Próximamente',
 'product_upcoming_company_toggle': 'Publicar como "Próximamente" (importación/entrega)',
 'product_upcoming_company_toggle_hint': 'Las empresas pueden programar la entrega hasta {days} días antes.',
 'product_upcoming_company_premium_only': 'Próximamente para empresas requiere una suscripción Premium activa.',
 'product_upcoming_company_max_days': 'El plazo máximo de entrega es de {days} días.',
 'product_upcoming_farmer_max_days': 'El plazo máximo de cosecha es de {days} días.',
 'product_upcoming_delivery_reserve_hint': 'Reservar con antelación — el producto está en camino al almacén.',
 'harvest_countdown_days_hours': '{days}d {hours}h',
 'harvest_countdown_hours_minutes': '{hours}h {minutes}m',
 'harvest_countdown_minutes': '{minutes} min',
 'harvest_countdown_due': '¡Cosecha lista!',
 'harvest_manage_title': 'Gestionar cosecha',
 'harvest_manage_action': 'Gestionar cosecha',
 'harvest_date_label': 'Fecha y hora de la cosecha',
 'harvest_save_schedule': 'Guardar calendario de cosecha',
 'harvest_schedule_saved': 'Calendario de cosecha actualizado.',
 'harvest_update_development_photo': 'Añadir nueva foto del fruto en desarrollo',
 'harvest_complete_action': 'Finalizar cosecha y recoger',
 'harvest_complete_confirm_title': '¿Finalizar cosecha?',
 'harvest_complete_confirm_body': 'El producto se ocultará hasta que suba una foto real del cultivo cosechado.',
 'harvest_complete_success': 'Cosecha finalizada — suba la foto final.',
 'harvest_final_photo_alert': 'Fotografíe el producto cosechado real en un cajón para pasarlo a venta regular.',
 'harvest_awaiting_final_photo_short': 'Esperando foto final',
 'harvest_final_photo_instruction': 'Suba una foto del producto cosechado real en un cajón.',
 'harvest_final_photo_pick': 'Añadir foto final del producto cosechado',
 'harvest_final_photo_required': 'Seleccione la foto final antes de publicar.',
 'harvest_publish_final_photo': 'Publicar en venta regular',
 'harvest_final_photo_success': '¡El producto ya está disponible para comprar!',
 'weather_alert_title': '⚠️ Alerta meteorológica',
 'weather_alert_high_wind': '¡Viento fuerte ({wind} km/h)! Asegure invernaderos, redes y lonas antes de la tormenta.',
 'weather_alert_extreme_heat': '¡Calor extremo ({temp}°C)! Riegue temprano por la mañana y proteja cultivos sensibles.',
 'weather_alert_hail': 'Riesgo de granizo ({rain}% precipitación)! Cubra árboles frutales y hortalizas; use redes '
                       'antigranizo si es necesario.',
 'weather_alert_frost': 'Riesgo de heladas ({temp}°C)! Proteja plantas jóvenes y flores con plástico o agrotextil.',
 'weather_alert_storm': '¡Alerta de tormenta! Pause el trabajo de campo si es necesario, asegure lonas y proteja el '
                        'equipo.',
 'weather_alert_heavy_rain': 'Lluvia intensa ({rain}% precipitación)! Compruebe el drenaje, proteja cultivos y retrase '
                             'la pulverización.',
 'farmer_welcome_title': '¡Hola! Soy tu asistente',
 'farmer_welcome_body': 'Estoy aquí para guiarte por la app. Cuando necesites una explicación en cualquier pantalla, '
                        'toca mi icono en la esquina superior.',
 'farmer_welcome_start': '¡Empecemos!',
 'guide_marketplace_search_title': 'Búsqueda de productos',
 'guide_marketplace_search_body': 'Busque aquí rápidamente alimentos frescos, semillas o maquinaria agrícola.',
 'guide_marketplace_filters_title': 'Opciones de filtro',
 'guide_marketplace_filters_body': 'Use estos filtros para ordenar productos por distancia, tipo o método de cultivo.',
 'guide_marketplace_products_title': 'Productos',
 'guide_marketplace_products_body': 'Toque una tarjeta de producto para ver detalles, precio y realizar pedidos.',
 'guide_cart_payment_title': 'Pago',
 'guide_cart_payment_body': 'Elija cómo pagar. Los productos próximos requieren pago con tarjeta.',
 'guide_cart_delivery_title': 'Entrega',
 'guide_cart_delivery_body': 'Para cada agricultor, elija recogida en la granja o entrega a su dirección.',
 'guide_cart_checkout_title': 'Finalizar compra',
 'guide_cart_checkout_body': 'Revise el total y envíe su pedido con un toque.',
 'guide_add_product_image_title': 'Foto del producto',
 'guide_add_product_image_body': 'Añada una foto clara — los compradores ven la imagen primero.',
 'guide_add_product_details_title': 'Datos básicos',
 'guide_add_product_details_body': 'Introduzca nombre, descripción, categoría y otros datos del producto.',
 'guide_add_product_submit_title': 'Publicar',
 'guide_add_product_submit_body': 'Cuando todo esté listo, publique el producto en el marketplace.',
 'guide_product_name_title': 'Nombre del producto',
 'guide_product_name_body': 'Introduzca un nombre claro (p. ej., Miel casera) para que los compradores le encuentren '
                            'fácilmente.',
 'guide_product_price_title': 'Precio del producto',
 'guide_product_price_body': 'Introduzca el precio unitario. Nuestro sistema lo convierte automáticamente para '
                             'clientes extranjeros.',
 'guide_product_stock_title': 'Stock disponible',
 'guide_product_stock_body': 'Introduzca cuánto tiene en stock. La app reduce esto después de cada compra.',
 'guide_product_upcoming_title': 'Próximamente (Premium)',
 'guide_farmer_weather_title': 'Pronóstico agrícola',
 'guide_farmer_weather_body': 'Aquí verá el pronóstico y alertas de tiempo severo una vez configure la ubicación de su '
                              'granja en el perfil.',
 'guide_farmer_list_title': 'Gestión de stock',
 'guide_farmer_list_body': 'Controle sus productos, stock disponible y use el interruptor para marcar rápidamente '
                           '[AGOTADO].',
 'guide_farmer_add_title': 'Nuevo anuncio',
 'guide_farmer_add_body': 'Toque este más para abrir el formulario y añadir un producto nuevo o un artículo Premium '
                          'próximo.',
 'guide_profile_settings_title': 'Idioma y región de moneda',
 'guide_profile_settings_body': 'Use los menús desplegables aquí para elegir el idioma de la app y la región de moneda '
                                'para precios del marketplace.',
 'guide_profile_tabs_title': 'Menú superior',
 'guide_profile_tabs_body': 'Mi Perfil gestiona sus datos comerciales, mientras Mi Galería le permite compartir bellos '
                            'momentos de la comunidad: su pueblo, jardín, plantas, animales y mascotas.',
 'guide_profile_identity_title': 'Identidad del agricultor',
 'guide_profile_identity_body': 'Su foto de perfil y nombre aparecen aquí. La insignia naranja "Agricultor '
                                'profesional" muestra a los compradores que es un productor verificado y serio.',
 'guide_profile_company_identity_title': 'Identidad empresarial',
 'guide_profile_company_identity_body': 'Su logotipo y nombre comercial oficial aparecen aquí. La insignia dorada de '
                                        'empresa muestra a compradores y agricultores que es un proveedor verificado y '
                                        'de confianza.',
 'guide_profile_phone_title': 'Número de teléfono',
 'guide_profile_phone_body': 'Introduzca el número al que los compradores pueden llamar para acordar pedidos y '
                             'contactarle rápidamente.',
 'guide_profile_address_title': 'Dirección de la granja',
 'guide_profile_address_body': 'Introduzca la ubicación de su granja para que compradores y la app puedan encontrarle '
                               'en el mapa.',
 'guide_profile_paypal_title': 'Cuenta de PayPal',
 'guide_profile_paypal_body': 'Opcionalmente añada su correo de PayPal para pagos en línea más rápidos y seguros de '
                              'los compradores.',
 'guide_profile_land_title': 'Radar satelital',
 'guide_profile_land_body': 'Toque aquí para abrir el mapa satelital, dibujar límites de parcelas, calcular hectáreas '
                            'gratis e iniciar el monitoreo avanzado Premium NIRS multispectral de salud de cultivos.',
 'guide_profile_farm_number_title': 'Número de registro de la granja',
 'guide_profile_farm_number_body': 'Introduzca su número BPG u OPG que confirma su explotación agrícola registrada.',
 'guide_profile_shop_hours_title': 'Disponibilidad y horario laboral',
 'guide_profile_shop_hours_body': 'Active la disponibilidad de pedidos, elija días laborables y establezca las horas '
                                  'en las que está en la granja para los compradores.',
 'guide_profile_min_order_title': 'Pedido mínimo',
 'guide_profile_min_order_body': 'Establezca el importe mínimo en euros que un comprador debe gastar antes de que '
                                 'usted empaquete y entregue personalmente los productos.',
 'guide_profile_pickup_title': 'Recogida personal',
 'guide_profile_pickup_body': 'Indique los días y horas exactas en las que los compradores pueden ir a su granja a '
                              'recoger sus pedidos.',
 'guide_profile_delivery_info_title': 'Entrega a domicilio',
 'guide_profile_delivery_info_body': 'Introduzca una breve descripción para los compradores sobre cómo y cuándo '
                                     'entrega personalmente los productos (p. ej., qué días conduce).',
 'guide_profile_delivery_zones_title': 'Zonas de entrega',
 'guide_profile_delivery_zones_body': 'Establezca el importe mínimo de pedido para cada distancia para saber cuándo '
                                      'merece la pena ir personalmente a entregar en esa zona.',
 'guide_animals_list_title': 'Lista de animales',
 'guide_animals_list_body': 'Aquí ve todos sus animales ordenados por especie, números y categorías.',
 'guide_animals_records_title': 'Historial de salud',
 'guide_animals_records_body': 'Controle aquí datos importantes, revisiones veterinarias e historial de vacunación de '
                               'cada animal.',
 'guide_animals_add_title': 'Añadir animal',
 'guide_animals_add_body': 'Toque este más verde para abrir el formulario y registrar un animal nuevo en su base de '
                           'datos.',
 'guide_add_animal_photo_title': 'Foto',
 'guide_add_animal_photo_body': 'Toque aquí para tomar una foto con la cámara o elegir una imagen de la galería para '
                                'identificarlo más fácilmente.',
 'guide_add_animal_identity_title': 'Identidad del animal',
 'guide_add_animal_identity_body': 'Introduzca el nombre del animal o número de arete, luego elija el tipo de ganado '
                                   'en el menú desplegable.',
 'guide_add_animal_health_title': 'Datos de salud',
 'guide_add_animal_health_body': 'Introduzca la edad del animal y use el campo grande para notas médicas, historial de '
                                 'vacunación o consejo veterinario.',
 'guide_add_animal_documents_title': 'Documentos veterinarios',
 'guide_add_animal_documents_body': 'Toque aquí para fotografiar y adjuntar documentos veterinarios, cartillas de '
                                    'vacunación o informes médicos de este animal.',
 'guide_add_animal_save_title': 'Guardar datos',
 'guide_add_animal_save_body': 'Toque este botón para guardar permanentemente los datos y abrir el historial de salud '
                               'digital del animal.',
 'forum_cat_crops': 'Cultivos de campo',
 'forum_cat_mechanization': 'Mecanización',
 'land_title': 'Mis parcelas',
 'land_premium_title': 'Paquete Premium Pro',
 'land_premium_desc': 'Active Premium Pro por 9,99 € al mes. Hasta 50 parcelas con monitoreo satelital NIRS/NDVI '
                      'completo, Agro-Alarmas por tiempo severo sobre sus campos, hasta 500 cabezas de ganado con '
                      'documentos adjuntos y ¡60 escaneos AI al mes!',
 'land_premium_activate': 'Activar Premium Pro',
 'land_tap_hint': 'Toque el mapa para colocar puntos. Arrastre los marcadores para ajustar los límites con precisión.',
 'land_map_expand': 'Abrir mapa a pantalla completa',
 'land_map_minimize': 'Minimizar mapa',
 'land_map_compact_hint': 'Toque el mapa para dibujar a pantalla completa.',
 'land_close_parcel': 'Cerrar parcela',
 'land_nirs_button': 'Monitoreo multispectral NIRS/NDVI',
 'land_nirs_premium_title': 'Monitoreo satelital Premium',
 'land_nirs_premium_body': 'Este monitoreo satelital avanzado de salud de cultivos y humedad del suelo (NIRS/NDVI) '
                           'solo está disponible para miembros Premium. ¡Active Premium Pro y siga el estado de los '
                           'cultivos en vivo con datos del satélite Sentinel-2!',
 'land_nirs_coming_soon': 'El monitoreo NIRS/NDVI se abrirá para esta parcela. Datos Sentinel-2 próximamente.',
 'land_nirs_quota_remaining': 'Escaneos satelitales NIRS disponibles este mes: {remaining} / {limit}',
 'land_nirs_limit_monthly': 'Ha usado todos los escaneos satelitales NIRS de este mes.',
 'land_nirs_subscription_required': 'El monitoreo satelital NIRS requiere una suscripción Premium.',
 'land_nirs_close_parcel_first': 'Cierre la parcela primero antes de cargar el mapa NIRS/NDVI.',
 'land_nirs_load_title': 'Cargar mapa NIRS/NDVI',
 'land_nirs_load_body': '¿Cargar monitoreo NIRS/NDVI Sentinel-2 para la parcela cerrada? Cada carga usa 1 escaneo '
                        'mensual.',
 'land_nirs_load_success': 'El análisis NIRS/NDVI está listo. Vea los resultados en el mapa.',
 'land_nirs_results_title': 'Resultados NIRS/NDVI',
 'land_nirs_ndvi_mean': 'Índice NDVI promedio',
 'land_nirs_moisture': 'Humedad del suelo estimada',
 'land_nirs_health': 'Estado de la vegetación',
 'land_nirs_health_good': 'Excelente (vegetación densa)',
 'land_nirs_health_moderate': 'Moderado (requiere atención)',
 'land_nirs_health_low': 'Bajo (posible estrés del cultivo)',
 'land_nirs_scan_date': 'Fecha de captura satelital',
 'land_nirs_analysis_date': 'Análisis ejecutado a las',
 'land_nirs_cloud_cover': 'Cobertura nubosa en la escena',
 'land_nirs_cloud_cover_value': '{percent}%',
 'land_nirs_imagery_stale': 'Las imágenes satelitales tienen {days} días de antigüedad. Sentinel-2 revisita la misma '
                            'zona aproximadamente cada 5 días — vuelva a ejecutar más tarde para una escena más '
                            'reciente.',
 'land_nirs_basemap_note': 'El fondo satelital de Google Maps puede ser más antiguo que los datos de superposición '
                           'NIRS.',
 'land_nirs_source': 'Fuente de datos: {source}',
 'land_nirs_run_scan': 'Iniciar monitoreo NIRS/NDVI',
 'land_nirs_run_again': 'Recargar NIRS/NDVI',
 'land_nirs_no_scan_yet': 'Aún no hay escaneo NIRS/NDVI para esta parcela. Inicie el monitoreo con el botón de abajo.',
 'land_parcel_tap_open': 'Toque para abrir',
 'land_nirs_loading': 'Cargando datos NIRS/NDVI de Sentinel-2…',
 'land_nirs_simulation_badge': 'Simulación — active la API en vivo antes de producción',
 'land_nirs_legend_title': 'Leyenda NDVI',
 'land_nirs_legend_good': 'Excelente — vegetación densa',
 'land_nirs_legend_moderate': 'Moderado — monitorizar parcela',
 'land_nirs_legend_low': 'Bajo — posible estrés del cultivo',
 'land_nirs_advice_title': 'Recomendación de parcela',
 'land_nirs_advice_good': 'La vegetación está en buen estado. Continúe el monitoreo semanal.',
 'land_nirs_advice_moderate': 'La vegetación es moderada. Compruebe el riego y la densidad de siembra en 3–5 días.',
 'land_nirs_advice_low': 'NDVI bajo — compruebe riego, fertilización y posibles enfermedades del campo.',
 'land_nirs_advice_low_moisture': 'La humedad del suelo es baja. Planifique el riego en las próximas 24–48 horas.',
 'land_nirs_advice_high_moisture': 'El suelo está muy húmedo. Retrase el riego y vigile enfermedades relacionadas con '
                                   'la humedad.',
 'land_nirs_compare_title': 'Comparación con el escaneo anterior',
 'land_nirs_compare_previous': 'Antes',
 'land_nirs_compare_current': 'Ahora',
 'land_nirs_compare_up': 'El NDVI aumentó {delta} — la vegetación está mejorando.',
 'land_nirs_compare_down': 'El NDVI bajó {delta} — compruebe la parcela en el campo.',
 'land_nirs_compare_stable': 'NDVI estable respecto al escaneo anterior.',
 'land_nirs_history_title': 'Historial de escaneos',
 'guide_land_nirs_quota_title': 'Límite mensual NIRS',
 'guide_land_nirs_quota_body': 'Aquí puede ver cuántos escaneos satelitales NIRS quedan este mes. Sus parcelas '
                               'dibujadas se almacenan durante un año.',
 'land_clear_all': 'Borrar todo',
 'land_draw_hint': 'Dibuje al menos 3 puntos y cierre la parcela para calcular el área.',
 'land_closed_hint': 'La parcela está cerrada. Arrastre los puntos para afinar los límites.',
 'land_self_intersect': 'Las líneas se cruzan. Ajuste los puntos y cierre la parcela de nuevo.',
 'land_area_m2': 'Área (m²)',
 'land_area_ha': 'Área (ha)',
 'land_perimeter': 'Perímetro',
 'land_undo_point': 'Deshacer último punto',
 'land_clear': 'Borrar',
 'land_save': 'Guardar parcela',
 'land_save_title': 'Guardar parcela',
 'land_parcel_name': 'Nombre de la parcela',
 'land_unnamed_parcel': 'Parcela sin nombre',
 'land_save_success': 'Parcela guardada.',
 'land_min_points': 'Se requieren al menos 3 puntos.',
 'land_saved_parcels': 'Parcelas guardadas',
 'land_no_parcels': 'Aún no hay parcelas guardadas.',
 'scanner_quota_bonus': 'incluyendo {bonus} escaneos comprados',
 'paywall_pharmacy_benefit_scanner': 'Escáner de plantas AI — {count} escaneos al mes',
 'account_deletion_title': '¿Eliminar cuenta?',
 'account_deletion_confirm_body': 'Esto eliminará permanentemente su perfil, métodos de pago y anuncios.\n'
                                  '\n'
                                  'Si tiene una suscripción activa, su cuenta permanecerá hasta el final del periodo '
                                  'de facturación actual. Premium sigue activo hasta entonces; cancele la renovación '
                                  'por separado en Google Play si es necesario.\n'
                                  '\n'
                                  'Esta acción no se puede deshacer después de completar la eliminación.',
 'account_deletion_confirm_action': 'Eliminar cuenta',
 'account_deletion_tile_title': 'Eliminar cuenta',
 'account_deletion_tile_subtitle': 'Eliminar permanentemente su perfil y datos',
 'account_deletion_tile_pending': 'Eliminación programada',
 'account_deletion_pending_generic': 'Su cuenta está programada para eliminación después de que termine su '
                                     'suscripción.',
 'account_deletion_pending_until': 'Su cuenta se eliminará permanentemente el {date}. Hasta entonces puede seguir '
                                   'usando las funciones Premium que pagó.',
 'account_deletion_scheduled_snackbar': 'Cuenta programada para eliminación el {date}.',
 'account_deletion_failed': 'No se pudo eliminar la cuenta. Inténtelo de nuevo.',
 'account_deletion_already_requested': 'La eliminación de cuenta ya fue solicitada.',
 'account_deletion_admin_blocked': 'Las cuentas de administrador no se pueden eliminar desde la app.',
 'account_deletion_login_required': 'Inicie sesión de nuevo para eliminar su cuenta.',
 'privacy_policy_title': 'Política de privacidad',
 'privacy_policy_subtitle': 'Cómo My Farmer gestiona sus datos',
 'privacy_policy_intro': 'Esta política explica qué recopilamos, por qué lo usamos y sus derechos. My Farmer es una '
                         'plataforma de marketplace — los pagos entre compradores y vendedores no los procesamos '
                         'nosotros.',
 'privacy_policy_profile_title': 'Política de privacidad',
 'privacy_policy_profile_subtitle': 'Recopilación de datos, ubicación y sus derechos',
 'privacy_policy_open_web': 'Abrir versión en línea',
 'privacy_policy_web_failed': 'No se pudo abrir el enlace de la política de privacidad.',
 'privacy_policy_footer': 'Última actualización: julio de 2026. Podemos actualizar esta política; los cambios '
                          'significativos se mostrarán en la app.',
 'privacy_controller_title': '1. Responsable del tratamiento',
 'privacy_controller_body': 'My Farmer (com.myfarmer.network) opera esta app. Para solicitudes de privacidad '
                            'contáctenos en el correo indicado abajo.',
 'privacy_data_title': '2. Datos que recopilamos',
 'privacy_data_body': 'Cuenta: nombre, correo, teléfono, dirección, rol, datos de granja o empresa.\n'
                      '\n'
                      'Uso: productos, pedidos, mensajes de chat, historiales de animales, parcelas, historial de '
                      'escaneos, métodos de pago que guarda (correo de PayPal, dígitos enmascarados de tarjeta, '
                      'IBAN).\n'
                      '\n'
                      'Dispositivo: token FCM para notificaciones, ID de dispositivo para límites de escaneos de '
                      'prueba.\n'
                      '\n'
                      'Medios y sensores: fotos que sube, cámara para el escáner de plantas, GPS para precios del '
                      'marketplace y ubicación de la granja.',
 'privacy_purpose_title': '3. Por qué usamos los datos',
 'privacy_purpose_body': 'Para proporcionar el marketplace, chat, servicios veterinarios, escáner de plantas, '
                         'herramientas satelitales de parcelas, alertas meteorológicas, suscripciones Premium vía '
                         'Google Play y prevenir abusos. No vendemos sus datos personales.',
 'privacy_location_title': '4. Datos de ubicación',
 'privacy_location_body': 'El GPS se usa para mostrar productos cercanos, moneda/precios correctos para su región y '
                          'coordenadas de granja que elija compartir. Puede denegar el permiso de ubicación; algunas '
                          'funciones estarán limitadas.',
 'privacy_third_parties_title': '5. Servicios de terceros',
 'privacy_third_parties_body': 'Usamos Google Firebase (auth, base de datos, almacenamiento, push), Google Play / '
                               'RevenueCat (suscripciones), Google Maps, Open-Meteo (tiempo), Plant.id y Sentinel Hub '
                               '(vía nuestros servidores para escaneos y NIRS). Cada proveedor tiene sus propios '
                               'términos de privacidad.',
 'privacy_retention_title': '6. Conservación',
 'privacy_retention_body': 'Conservamos los datos mientras su cuenta esté activa. Cuando elimine su cuenta, los datos '
                           'personales se eliminan o anonimizan; algunos registros de pedidos pueden conservarse '
                           'brevemente para resolución de disputas. Las suscripciones activas retrasan la eliminación '
                           'completa hasta que termine el periodo pagado.',
 'privacy_rights_title': '7. Sus derechos',
 'privacy_rights_body': 'Puede acceder, corregir o eliminar sus datos. Use Perfil → Eliminar cuenta, o contáctenos. '
                        'Los usuarios de la UE tienen derechos GDPR incluyendo portabilidad de datos y oposición. '
                        'Puede presentar una reclamación ante su autoridad de control local.',
 'privacy_security_title': '8. Seguridad',
 'privacy_security_body': 'Los datos se transmiten por HTTPS y se almacenan en Firebase con reglas de acceso. Los '
                          'números de tarjeta de pago no se almacenan completos — solo los datos enmascarados que '
                          'introduce para perfiles de vendedor. Mantenga su contraseña confidencial.',
 'privacy_contact_title': '9. Contacto',
 'privacy_contact_body': 'Preguntas de privacidad: {email}',
 'registration_legal_consent_prefix': 'Acepto los',
 'registration_legal_consent_required': 'Acepte los Términos de uso y la Política de privacidad para registrarse.',
 'registration_legal_terms_link': 'Términos del marketplace',
 'registration_legal_privacy_link': 'Política de privacidad',
 'registration_legal_and': 'y',
 'beta_guide_screen_title': 'Guía de pruebas beta',
 'beta_guide_profile_title': 'Guía de pruebas beta',
 'beta_guide_profile_subtitle': 'Instrucciones para testers cerrados (PDF)'}

def main() -> None:
    with NEEDS_PATH.open(encoding="utf-8") as f:
        needs = json.load(f)

    missing = set(needs) - set(TRANSLATIONS)
    extra = set(TRANSLATIONS) - set(needs)
    if missing:
        raise SystemExit(f"Missing translations for {len(missing)} keys: {sorted(missing)[:5]}...")
    if extra:
        raise SystemExit(f"Extra translations for {len(extra)} keys: {sorted(extra)[:5]}...")

    output = {key: TRANSLATIONS[key] for key in needs}

    with OUT_PATH.open("w", encoding="utf-8") as f:
        json.dump(output, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print(f"Wrote {len(output)} keys to {OUT_PATH}")

    examples = list(output.items())[:3]
    print("Examples:")
    for k, v in examples:
        print(f"  {k}: {v}")


if __name__ == "__main__":
    main()
