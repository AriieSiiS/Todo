import copy
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import server


class ShoppingTests(unittest.TestCase):
    def setUp(self):
        self.state = {"shoppingItems": [], "householdItems": [{"id": "propio"}]}
        self.reader = patch.object(server, "load_state", side_effect=lambda: copy.deepcopy(self.state))
        self.writer = patch.object(server, "save_state", side_effect=self.save)
        self.reader.start()
        self.writer.start()
        self.addCleanup(self.reader.stop)
        self.addCleanup(self.writer.stop)

    def save(self, state):
        self.state = copy.deepcopy(state)

    def test_edicion_filtros_y_precios(self):
        item = server.create_shopping_item_impl({"name": "Tableta", "category": "Electrónica",
            "subcategory": "Tablets", "reference_price": 299, "target_price": 249,
            "source_url": "https://www.amazon.es/dp/prueba"})
        server.update_shopping_item_impl({"item_id": item["id"], "clear_target_price": True,
            "status": "comparing", "research_notes": "Comparar autonomía"})
        stored = server.list_shopping_items_impl({"subcategory": "Tablets"})[0]
        self.assertIsNone(stored["targetPrice"])
        self.assertEqual(stored["status"], "comparing")
        self.assertEqual(self.state["householdItems"], [{"id": "propio"}])
        self.assertEqual(server.list_shopping_items_impl({"subcategory": "Ratones"}), [])

    def test_validacion_antes_de_escribir(self):
        for extra in ({"target_price": -1}, {"reference_price": float("nan")},
                      {"source_url": "file:///algo"}, {"status": "inventado"}):
            with self.assertRaises(ValueError):
                server.create_shopping_item_impl({"name": "Tableta", "category": "Electrónica", **extra})
        self.assertEqual(self.state["shoppingItems"], [])

    def test_varias_opciones_se_guardan_y_se_conservan_al_editar(self):
        offers = [{"name": "Black", "source_url": "https://www.amazon.es/dp/B08R9R41SH"},
                  {"name": "Apollo", "source_url": "https://www.amazon.es/dp/B094D3XL55"}]
        item = server.create_shopping_item_impl({"name": "Desodorante AXE", "category": "Cuidado personal",
                                                "offers": offers})
        self.assertEqual(len(item.get("offers", [])), 2)
        updated = server.update_shopping_item_impl({"item_id": item["id"], "notes": "Comprar un pack"})
        self.assertEqual(updated["offers"][1]["sourceUrl"], offers[1]["source_url"])
        original = copy.deepcopy(self.state)
        with self.assertRaises(ValueError):
            server.update_shopping_item_impl({"item_id": item["id"], "offers":
                [{"name": "Inválido", "source_url": "file:///prueba"}]})
        self.assertEqual(self.state, original)

    def test_compras_nuevas_respetan_la_desagrupacion(self):
        first = server.create_shopping_item_impl({"name": "Proyector", "category": "Electrónica",
                                                "subcategory": "Proyectores"})
        self.state["shoppingItems"][0]["grouped"] = False
        next_item = server.create_shopping_item_impl({"name": "Otra opción", "category": "Electrónica",
                                                    "subcategory": "Proyectores"})
        self.assertFalse(next_item.get("grouped", True))
        edited = server.update_shopping_item_impl({"item_id": first["id"], "notes": "Nota nueva"})
        self.assertFalse(edited["grouped"])
        other = server.create_shopping_item_impl({"name": "Otra categoría", "category": "Otros",
                                                "subcategory": "Proyectores"})
        self.assertTrue(other.get("grouped", True))

    def test_imagen_independiente_del_inventario(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            from PIL import Image
            source = root / "producto.png"
            Image.new("RGB", (500, 500), "white").save(source)
            with patch.object(server, "shopping_directory", return_value=root / "compras"):
                item = server.create_shopping_item_impl({"name": "Ejemplo", "category": "Electrónica"})
                updated = server.set_shopping_item_image_impl({"item_id": item["id"], "source_file": str(source)})
                self.assertTrue((root / "compras" / updated["imagePath"]).is_file())
                server.delete_shopping_item_impl({"item_id": item["id"], "confirm": True})
                self.assertTrue(source.is_file())
                self.assertFalse((root / "compras" / updated["imagePath"]).exists())


if __name__ == "__main__":
    unittest.main()
