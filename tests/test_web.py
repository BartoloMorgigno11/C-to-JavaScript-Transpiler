"""Focused Flask endpoint tests that do not invoke the native toolchain."""

from __future__ import annotations

import importlib
import unittest
from unittest.mock import patch

web_app = importlib.import_module("web.app")
app = web_app.app


class RecordingLock:
    def __init__(self) -> None:
        self.entries = 0

    def __enter__(self) -> None:
        self.entries += 1

    def __exit__(self, *_args: object) -> None:
        return None


class WebEndpointTests(unittest.TestCase):
    def setUp(self) -> None:
        self.client = app.test_client()

    def test_empty_transpile_request_is_rejected(self) -> None:
        response = self.client.post("/api/transpile", json={"source": "  "})
        self.assertEqual(response.status_code, 400)
        self.assertFalse(response.get_json()["ok"])

    def test_artifact_route_rejects_path_traversal(self) -> None:
        response = self.client.get("/files/../../README.md")
        self.assertEqual(response.status_code, 404)

    def test_transpile_uses_the_shared_pipeline_lock(self) -> None:
        lock = RecordingLock()

        def fake_compile(_source, output, **_kwargs):
            output.write_text("console.log(1);", encoding="utf-8")
            output.with_suffix(".ast.json").write_text('{"ast": {}}', encoding="utf-8")
            return output

        with (
            patch.object(web_app, "PIPELINE_LOCK", lock),
            patch.object(web_app, "compile_to_js", side_effect=fake_compile),
        ):
            response = self.client.post("/api/transpile", json={"source": "int main() { return 0; }"})

        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.get_json()["ok"])
        self.assertEqual(lock.entries, 1)


if __name__ == "__main__":
    unittest.main()
