# Manifiesto de importación de Ropa

Guardar este archivo como `manifest.json` junto a los PNG. Todos los nombres de `file` deben ser nombres simples dentro de la misma carpeta, nunca rutas absolutas ni subcarpetas.

```json
{
  "version": 1,
  "batchId": "armario-2026-07-15",
  "name": "Armario de julio",
  "items": [
    {
      "id": "cardigan-azul-geometrico",
      "file": "cardigan-azul-geometrico.png",
      "name": "Cárdigan azul geométrico",
      "category": "Cárdigans",
      "colors": ["azul marino", "blanco"],
      "material": "punto de grosor medio",
      "seasons": ["otoño", "invierno"],
      "occasions": ["diario", "informal"],
      "tags": ["frío", "geométrico", "cremallera"],
      "confidence": "alta",
      "sourceReferences": ["IMG_1284.jpg", "IMG_1289.jpg"]
    }
  ]
}
```

Campos obligatorios por prenda: `id`, `file`, `name` y `category`. Usar `confidence` con `alta`, `media` o `baja`. Las referencias de origen son solo nombres informativos: no se copian las fotografías originales a Todo.
