import io
import json
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hybrid_ontology as ho
import wsgi_app


def _call_wsgi(method: str, path: str, query_string: str = ""):
    status_holder = {}
    headers_holder = {}

    def start_response(status, headers):
        status_holder["status"] = status
        headers_holder["headers"] = dict(headers)

    environ = {
        "REQUEST_METHOD": method,
        "PATH_INFO": path,
        "QUERY_STRING": query_string,
        "CONTENT_LENGTH": "0",
        "wsgi.input": io.BytesIO(b""),
    }
    raw = b"".join(wsgi_app.application(environ, start_response))
    code = int(status_holder["status"].split(" ", 1)[0])
    return code, headers_holder["headers"], raw


class FoodOnGraphVisualizerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.engine = ho.HybridFoodOnEngine()

    def test_01_children_map_populated(self):
        self.assertTrue(hasattr(self.engine, "children_map"))
        self.assertGreaterEqual(len(self.engine.children_map.get("FOODON:00001002", [])), 20)
        self.assertGreaterEqual(len(self.engine.children_map.get("FOODON:03412972", [])), 200)

    def test_02_graph_neighborhood_focus_and_edges_valid(self):
        g = self.engine.get_graph_neighborhood(
            curie="FOODON:00001002",
            ancestor_hops=6,
            child_depth=2,
            max_children=15,
        )
        self.assertTrue(g["success"])
        self.assertEqual(g["focus"]["id"], "FOODON:00001002")
        node_ids = {n["id"] for n in g["nodes"]}
        self.assertIn("FOODON:00001002", node_ids)
        self.assertIn("FOODON:00002403", node_ids)  # parent: food material
        self.assertGreater(len(g["edges"]), 10)
        for e in g["edges"]:
            self.assertIn(e["source"], node_ids)
            self.assertIn(e["target"], node_ids)

    def test_03_graph_expand_pagination(self):
        ex = self.engine.expand_graph_node("FOODON:03412972", limit=20, offset=0)
        self.assertTrue(ex["success"])
        self.assertGreaterEqual(ex["total_children"], 200)
        self.assertTrue(ex["has_more"])
        self.assertEqual(len(ex["children"]), 20)
        self.assertGreaterEqual(len(ex["edges"]), 20)

    def test_04_find_ontology_path_butter_to_whey(self):
        res = self.engine.find_ontology_path("FOODON:03310351", "FOODON:03315518")
        self.assertTrue(res["success"])
        self.assertTrue(res["connected"])
        path_ids = [n["id"] for n in res["path_nodes"]]
        self.assertEqual(path_ids[0], "FOODON:03310351")
        self.assertEqual(path_ids[-1], "FOODON:03315518")
        self.assertTrue(res["lca_id"])
        self.assertEqual(len(res["edges"]), len(path_ids) - 1)

    def test_05_wsgi_graph_endpoints_and_html(self):
        code, hdrs, raw = _call_wsgi("GET", "/foodon-graph")
        self.assertEqual(code, 200)
        self.assertIn("text/html", hdrs.get("Content-Type", ""))
        self.assertIn(b"FoodOn", raw)

        code2, _, raw2 = _call_wsgi("GET", "/api/v1/foodon/graph", "curie=FOODON:00001256&child_depth=1&max_children=12")
        self.assertEqual(code2, 200)
        d2 = json.loads(raw2.decode("utf-8"))
        self.assertTrue(d2["success"])
        self.assertEqual(d2["focus"]["id"], "FOODON:00001256")

        code3, _, raw3 = _call_wsgi("GET", "/api/v1/foodon/graph/expand", "curie=FOODON:03412972&limit=10&offset=0")
        self.assertEqual(code3, 200)
        d3 = json.loads(raw3.decode("utf-8"))
        self.assertTrue(d3["success"])
        self.assertEqual(len(d3["children"]), 10)

        code4, _, raw4 = _call_wsgi("GET", "/api/v1/foodon/graph/path", "from=FOODON:03310351&to=FOODON:03315518")
        self.assertEqual(code4, 200)
        d4 = json.loads(raw4.decode("utf-8"))
        self.assertTrue(d4["connected"])


if __name__ == "__main__":
    unittest.main()

